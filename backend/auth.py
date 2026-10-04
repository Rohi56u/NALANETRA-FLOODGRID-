"""Salted passwords, persisted revocable sessions and rotating refresh tokens."""

import base64
import hashlib
import hmac
import secrets
import uuid
from datetime import timedelta
import jwt
from fastapi import HTTPException
from .database import AuthSession, User, aware, utcnow


def hash_password(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1)
    return (
        "scrypt$"
        + base64.b64encode(salt).decode()
        + "$"
        + base64.b64encode(digest).decode()
    )


def check_password(password, encoded):
    try:
        _, salt, expected = encoded.split("$")
        digest = hashlib.scrypt(
            password.encode(), salt=base64.b64decode(salt), n=16384, r=8, p=1
        )
        return hmac.compare_digest(digest, base64.b64decode(expected))
    except (TypeError, ValueError):
        return False


def digest_token(token):
    return hashlib.sha256(token.encode()).hexdigest()


def issue_session(db, user, settings):
    refresh = secrets.token_urlsafe(48)
    session = AuthSession(
        id=str(uuid.uuid4()),
        user_id=user.id,
        refresh_hash=digest_token(refresh),
        expires_at=utcnow() + timedelta(days=7),
    )
    db.add(session)
    db.flush()
    access = jwt.encode(
        {
            "sub": str(user.id),
            "sid": session.id,
            "role": user.role,
            "iss": "nalanetra",
            "aud": "nalanetra-app",
            "iat": utcnow(),
            "exp": utcnow() + timedelta(minutes=30),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )
    return {
        "accessToken": access,
        "refreshToken": refresh,
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "staffId": user.staff_id,
            "role": user.role,
        },
    }


def authenticate(db, bearer, settings):
    if not bearer or not bearer.startswith("Bearer "):
        raise HTTPException(401, "Sign in to continue")
    try:
        claims = jwt.decode(
            bearer[7:],
            settings.jwt_secret,
            algorithms=["HS256"],
            issuer="nalanetra",
            audience="nalanetra-app",
            options={"require": ["sub", "sid", "exp"]},
        )
        session, user = (
            db.get(AuthSession, claims["sid"]),
            db.get(User, int(claims["sub"])),
        )
        if (
            not session
            or session.revoked
            or session.user_id != int(claims["sub"])
            or aware(session.expires_at) <= utcnow()
            or not user
            or not user.verified
        ):
            raise ValueError("Session unavailable")
        return user, session
    except (jwt.PyJWTError, ValueError, TypeError, KeyError):
        raise HTTPException(401, "Session expired. Sign in again.") from None


def require_role(user, *roles):
    if user.role not in roles:
        raise HTTPException(403, "This role cannot perform that action")
