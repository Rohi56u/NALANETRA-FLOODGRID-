"""Persistent, role-gated citizen reporting and municipal response API."""

from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from email.message import EmailMessage
import hashlib
import hmac
import json
import os
import re
import secrets
import smtplib
import uuid
from typing import Literal
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError
from .auth import (
    authenticate,
    check_password,
    digest_token,
    hash_password,
    issue_session,
    require_role,
)
from .database import (
    AuditEvent,
    AuthSession,
    Challenge,
    Device,
    Evidence,
    Incident,
    Job,
    Notification,
    Report,
    User,
    aware,
    connect,
    utcnow,
)
from .priority_engine import SEVERITY_MAPPING, score_factors
from .settings import ROOT, Settings
from .spatial_clustering import grouping_candidates, haversine_meters
from intelligence.yolo_photo_screening import screen_photo
from routing.osrm_engine import OSRMEngine
from security.sha256_verifier import verify_stored_file


class AuthInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    role: Literal["citizen", "officer", "crew"] = "citizen"
    fullName: str = Field("", max_length=100)
    email: str = Field("", max_length=254)
    phone: str = Field("", max_length=24)
    password: str = Field("", max_length=128)
    staffId: str = Field("", max_length=40)
    challengeId: int | None = None
    emailCode: str = Field("", max_length=10)
    refreshToken: str = Field("", max_length=200)
    userId: int | None = None


class ReviewInput(BaseModel):
    approved: bool = True
    severity: Literal["sidewalk", "ankle", "knee", "waist", "submerged"] | None = None
    rain_mm_hr: float | None = Field(None, ge=0, le=500)
    ward_criticality: float | None = Field(None, ge=0, le=1)
    blockage: float | None = Field(None, ge=0, le=1)
    emergency_route: bool | None = None
    note: str = Field(..., min_length=5, max_length=1200)


class DispatchInput(BaseModel):
    crew_id: str = Field(..., min_length=1, max_length=40)


class StateInput(BaseModel):
    status: Literal["ON_SITE", "WORK_IN_PROGRESS"]
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    accuracy_m: float = Field(..., gt=0, le=50)
    capture_source: Literal["gps", "demo-fixture"] = "gps"


class ClosureInput(BaseModel):
    approved: bool
    note: str = Field(..., min_length=5, max_length=1200)


class MergeInput(BaseModel):
    target_incident_id: str
    note: str = Field(..., min_length=5, max_length=1200)


class RouteInput(BaseModel):
    origin_lat: float = Field(..., ge=-90, le=90)
    origin_lon: float = Field(..., ge=-180, le=180)
    dest_lat: float = Field(..., ge=-90, le=90)
    dest_lon: float = Field(..., ge=-180, le=180)


def new_id(prefix):
    return f"{prefix}-{uuid.uuid4().hex}"


def create_app(settings=None):
    settings = (settings or Settings()).prepare()
    engine, sessions = connect(settings.database_url)
    evidence_dir = settings.data_dir / "evidence"
    evidence_dir.mkdir(exist_ok=True, mode=0o700)

    @asynccontextmanager
    async def lifespan(app):
        yield
        engine.dispose()

    app = FastAPI(
        title="NalaNetra FloodGrid",
        version="2.0.0",
        lifespan=lifespan,
        description="Report → officer review → priority → dispatch → field proof → officer closure. Risk estimates and photo cues require validation.",
    )
    app.state.settings, app.state.sessions, app.state.engine = (
        settings,
        sessions,
        engine,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[s.strip() for s in settings.origins.split(",") if s.strip()],
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization", "Content-Type"],
    )

    def get_db():
        # Function scope commits or rolls back before an HTTP receipt is sent.
        with sessions() as db:
            db.info["new_files"] = []
            try:
                yield db
                db.commit()
            except Exception as error:
                db.rollback()
                for path in db.info["new_files"]:
                    path.unlink(missing_ok=True)
                if isinstance(error, IntegrityError):
                    raise HTTPException(
                        409, "Concurrent or duplicate update. Refresh and retry."
                    ) from None
                raise

    def current_user(
        db=Depends(get_db, scope="function"), authorization: str | None = Header(None)
    ):
        return authenticate(db, authorization, settings)[0]

    def audit(db, user, action, incident=None, **details):
        db.add(
            AuditEvent(
                actor_id=user.id, incident_id=incident, action=action, details=details
            )
        )

    def incident_for(db, identifier, user, lock=False):
        query = select(Incident).where(Incident.id == identifier)
        incident = db.scalar(query.with_for_update() if lock else query)
        if not incident:
            raise HTTPException(404, "Incident not found")
        if user.role == "citizen" and not db.scalar(
            select(Report.id).where(
                Report.incident_id == identifier, Report.user_id == user.id
            )
        ):
            raise HTTPException(404, "Incident not found")
        if user.role == "crew":
            job = db.get(Job, identifier)
            if not job or job.crew_id != user.id:
                raise HTTPException(404, "Assignment not found")
        return incident

    def rescore(incident):
        factors = dict(incident.factors)
        factors["A"] = min(
            1, max(0, (utcnow() - aware(incident.created_at)).total_seconds() / 21600)
        )
        result = score_factors(factors, incident.severity)
        incident.factors = result["factor_breakdown"]
        incident.priority, incident.band, incident.sla_minutes = (
            result["priority_score"],
            result["band"],
            result["action_sla_minutes"],
        )
        return result

    def serialize_incident(db, incident):
        result = (
            rescore(incident)
            if incident.status not in {"CLOSED", "REJECTED"}
            else score_factors(incident.factors, incident.severity)
        )
        return {
            "id": incident.id,
            "location": incident.location,
            "lat": incident.lat,
            "lon": incident.lon,
            "severity": incident.severity,
            "status": incident.status,
            "created_at": aware(incident.created_at).isoformat(),
            "updated_at": aware(incident.updated_at).isoformat(),
            "factor_sources": incident.factor_sources,
            "verified_by_officer": incident.verified_by is not None,
            "report_count": len(
                db.scalars(
                    select(Report.id).where(Report.incident_id == incident.id)
                ).all()
            ),
            **result,
        }

    def notify(db, incident, title, body):
        ids = set(
            db.scalars(
                select(Report.user_id).where(Report.incident_id == incident.id)
            ).all()
        )
        ids.update(
            db.scalars(
                select(User.id).where(User.role == "officer", User.verified.is_(True))
            ).all()
        )
        job = db.get(Job, incident.id)
        if job:
            ids.add(job.crew_id)
        for identifier in ids:
            device = db.scalar(select(Device.id).where(Device.user_id == identifier))
            db.add(
                Notification(
                    user_id=identifier,
                    incident_id=incident.id,
                    title=title,
                    body=body,
                    push_status="PENDING"
                    if settings.fcm_credentials and device
                    else "NOT_CONFIGURED",
                )
            )

    def challenge_for(db, user):
        recent = db.scalar(
            select(Challenge)
            .where(Challenge.user_id == user.id)
            .order_by(Challenge.id.desc())
        )
        if recent and aware(recent.expires_at) - timedelta(
            minutes=10
        ) > utcnow() - timedelta(seconds=60):
            raise HTTPException(429, "Wait 60 seconds before requesting another code")
        for previous in db.scalars(
            select(Challenge).where(
                Challenge.user_id == user.id, Challenge.consumed.is_(False)
            )
        ):
            previous.consumed = True
        code = f"{secrets.randbelow(1_000_000):06d}"
        challenge = Challenge(
            user_id=user.id,
            code_hash=hmac.new(
                settings.jwt_secret.encode(), code.encode(), hashlib.sha256
            ).hexdigest(),
            expires_at=utcnow() + timedelta(minutes=10),
        )
        db.add(challenge)
        db.flush()
        if settings.mail_mode == "file" and settings.mode != "deployment":
            directory = settings.data_dir / "mail-outbox"
            directory.mkdir(exist_ok=True, mode=0o700)
            path = directory / f"challenge-{challenge.id}.json"
            with os.fdopen(
                os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w"
            ) as stream:
                json.dump(
                    {
                        "to": user.email,
                        "code": code,
                        "expires_at": challenge.expires_at.isoformat(),
                    },
                    stream,
                )
            db.info["new_files"].append(path)
            channels = ["local-file (development only)"]
        elif settings.mail_mode == "smtp":
            message = EmailMessage()
            message["From"], message["To"], message["Subject"] = (
                os.environ["NALA_SMTP_FROM"],
                user.email,
                "NalaNetra verification code",
            )
            message.set_content(
                f"Your verification code is {code}. It expires in 10 minutes."
            )
            try:
                with smtplib.SMTP(
                    os.environ["NALA_SMTP_HOST"],
                    int(os.getenv("NALA_SMTP_PORT", "587")),
                    timeout=10,
                ) as smtp:
                    smtp.starttls()
                    smtp.login(
                        os.environ["NALA_SMTP_USER"], os.environ["NALA_SMTP_PASSWORD"]
                    )
                    smtp.send_message(message)
            except (OSError, smtplib.SMTPException, KeyError):
                raise HTTPException(
                    503, "Verification mail unavailable; contact the administrator"
                ) from None
            channels = ["email"]
        else:
            raise HTTPException(503, "Verification delivery is not configured")
        return {
            "challengeId": challenge.id,
            "userId": user.id,
            "expiresInSeconds": 600,
            "channels": channels,
        }

    @app.get("/", include_in_schema=False)
    def home():
        return FileResponse(ROOT / "backend/web/index.html")

    @app.get("/api/v1/health", tags=["System"])
    def health(db=Depends(get_db, scope="function")):
        db.execute(text("SELECT 1"))
        return {
            "status": "ONLINE",
            "version": "2.0.0",
            "mode": settings.mode,
            "persistence": engine.dialect.name,
            "risk_data": "SYNTHETIC_FIXTURE",
            "routing": "OSRM_CONFIGURED" if settings.osrm_url else "NOT_CONFIGURED",
            "push": "FCM_CONFIGURED" if settings.fcm_credentials else "NOT_CONFIGURED",
        }

    @app.post("/api/v1/auth/{procedure}", tags=["Authentication"])
    def auth_endpoint(
        procedure: str, data: AuthInput, db=Depends(get_db, scope="function")
    ):
        email = data.email.strip().lower()
        if procedure == "register":
            if data.role != "citizen":
                raise HTTPException(
                    403, "Staff accounts are issued by an administrator"
                )
            if (
                not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email)
                or len(data.password) < 12
                or not data.fullName.strip()
            ):
                raise HTTPException(
                    422,
                    "Provide name, valid email and a password of at least 12 characters",
                )
            if db.scalar(select(User.id).where(User.email == email)):
                raise HTTPException(
                    409,
                    "Account already exists. Sign in or request a verification code.",
                )
            user = User(
                name=data.fullName.strip(),
                email=email,
                phone=data.phone,
                role="citizen",
                password_hash=hash_password(data.password),
            )
            db.add(user)
            db.flush()
            return challenge_for(db, user)
        if procedure == "verify":
            challenge = db.get(Challenge, data.challengeId)
            if (
                not challenge
                or challenge.consumed
                or aware(challenge.expires_at) <= utcnow()
                or challenge.attempts >= 5
            ):
                raise HTTPException(400, "Verification code expired or unavailable")
            user = db.get(User, challenge.user_id)
            if user.role != data.role:
                raise HTTPException(403, "Verification role mismatch")
            challenge.attempts += 1
            expected = hmac.new(
                settings.jwt_secret.encode(), data.emailCode.encode(), hashlib.sha256
            ).hexdigest()
            if not hmac.compare_digest(expected, challenge.code_hash):
                db.commit()
                raise HTTPException(400, "Incorrect verification code")
            challenge.consumed, user.verified = True, True
            audit(db, user, "ACCOUNT_VERIFIED")
            return issue_session(db, user, settings)
        if procedure == "login":
            user = db.scalar(select(User).where(User.email == email))
            if user and user.locked_until and aware(user.locked_until) > utcnow():
                raise HTTPException(429, "Too many attempts. Try again in 15 minutes.")
            matched = bool(
                user
                and user.role == data.role
                and check_password(data.password, user.password_hash)
            )
            if data.role != "citizen":
                matched = matched and bool(user and user.staff_id == data.staffId)
            if not matched:
                if user:
                    user.failed_logins += 1
                    if user.failed_logins >= 5:
                        user.locked_until = utcnow() + timedelta(minutes=15)
                    db.commit()
                raise HTTPException(401, "Invalid account credentials")
            if not user.verified:
                raise HTTPException(403, "Verify your account before signing in")
            user.failed_logins, user.locked_until = 0, None
            audit(db, user, "LOGIN")
            return issue_session(db, user, settings)
        if procedure == "refresh":
            session = db.scalar(
                select(AuthSession)
                .where(AuthSession.refresh_hash == digest_token(data.refreshToken))
                .with_for_update()
            )
            if not session or session.revoked or aware(session.expires_at) <= utcnow():
                raise HTTPException(401, "Refresh session expired")
            user = db.get(User, session.user_id)
            if not user or not user.verified or user.role != data.role:
                raise HTTPException(403, "Session role mismatch")
            session.revoked = True
            return issue_session(db, user, settings)
        if procedure in {"resend", "resendByEmail"}:
            user = (
                db.get(User, data.userId)
                if data.userId
                else db.scalar(select(User).where(User.email == email))
            )
            if not user or user.role != data.role or user.verified:
                raise HTTPException(400, "Unverified account not found")
            return challenge_for(db, user)
        raise HTTPException(404, "Authentication operation not found")

    @app.post("/api/v1/auth-logout", tags=["Authentication"])
    def logout(
        db=Depends(get_db, scope="function"), authorization: str | None = Header(None)
    ):
        user, session = authenticate(db, authorization, settings)
        session.revoked = True
        audit(db, user, "LOGOUT")
        return {"success": True}

    async def read_photo(photo):
        data = await photo.read(settings.max_photo_bytes + 1)
        if len(data) > settings.max_photo_bytes:
            raise HTTPException(413, "Photo must be at most 6 MiB")
        try:
            return data, screen_photo(data, settings.yolo_weights)
        except ValueError as error:
            raise HTTPException(422, str(error)) from None

    def store_evidence(
        db,
        user,
        incident,
        kind,
        data,
        screening,
        lat,
        lon,
        captured_at,
        accuracy,
        source,
    ):
        identifier = new_id("EVD")
        name = identifier + (
            ".jpg" if screening["media_type"] == "image/jpeg" else ".png"
        )
        path = evidence_dir / name
        with os.fdopen(
            os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb"
        ) as stream:
            stream.write(data)
        db.info["new_files"].append(path)
        record = Evidence(
            id=identifier,
            incident_id=incident.id,
            uploaded_by=user.id,
            kind=kind,
            sha256=screening["sha256"],
            pixel_hash=screening["pixel_hash"],
            filename=name,
            media_type=screening["media_type"],
            lat=lat,
            lon=lon,
            captured_at=captured_at,
            accuracy_m=accuracy,
            capture_source=source,
            screening=screening,
        )
        db.add(record)
        db.flush()
        return record

    @app.post("/api/v1/photos/screen", tags=["Citizen reports"])
    async def photo_screen(photo: UploadFile = File(...), user=Depends(current_user)):
        _, result = await read_photo(photo)
        return result

    @app.post("/api/v1/incidents/report", tags=["Citizen reports"], status_code=201)
    async def report_incident(
        photo: UploadFile = File(...),
        client_id: str = Form(..., min_length=1, max_length=80),
        location: str = Form(..., min_length=1, max_length=200),
        lat: float = Form(..., ge=-90, le=90),
        lon: float = Form(..., ge=-180, le=180),
        depth_tag: str = Form(...),
        notes: str = Form("", max_length=1200),
        captured_at: datetime = Form(...),
        accuracy_m: float | None = Form(None, gt=0, le=10000),
        capture_source: Literal["gps", "selected-map"] = Form("selected-map"),
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "citizen")
        if depth_tag.lower() not in SEVERITY_MAPPING or not location.strip():
            raise HTTPException(422, "Provide a location and known depth tag")
        depth_tag = depth_tag.lower()
        if (
            captured_at.tzinfo is None
            or not -60 <= (utcnow() - captured_at).total_seconds() <= 86400
        ):
            raise HTTPException(
                422,
                "Photo capture needs a timezone and must be within the last 24 hours",
            )
        data, screening = await read_photo(photo)
        db.scalar(select(User).where(User.id == user.id).with_for_update())
        previous = db.scalar(
            select(Report).where(
                Report.user_id == user.id, Report.client_id == client_id
            )
        )
        if previous:
            proof = db.get(Evidence, previous.evidence_id)
            if (
                proof.sha256 != screening["sha256"]
                or previous.lat != lat
                or previous.lon != lon
                or previous.depth_tag != depth_tag
            ):
                raise HTTPException(
                    409, "The retry identifier belongs to another report"
                )
            return {
                "success": True,
                "report_id": previous.id,
                "incident_id": previous.incident_id,
                "idempotent_replay": True,
            }
        active = db.scalars(
            select(Incident).where(Incident.status.notin_(["CLOSED", "REJECTED"]))
        ).all()
        candidates = grouping_candidates(lat, lon, active)
        incident = Incident(
            id=new_id("INC"),
            location=location.strip(),
            lat=lat,
            lon=lon,
            severity=depth_tag,
            factors={
                "S": SEVERITY_MAPPING[depth_tag],
                "R": 0,
                "W": 0,
                "D": 0,
                "E": 0,
                "A": 0,
            },
            factor_sources={
                "S": "citizen depth tag; awaiting officer review",
                "R": "unavailable",
                "W": "unavailable",
                "D": "unavailable",
                "E": "unavailable",
                "A": "server elapsed time",
            },
        )
        db.add(incident)
        db.flush()
        rescore(incident)
        evidence = store_evidence(
            db,
            user,
            incident,
            "citizen",
            data,
            screening,
            lat,
            lon,
            captured_at,
            accuracy_m,
            capture_source,
        )
        report = Report(
            id=new_id("RPT"),
            user_id=user.id,
            client_id=client_id,
            incident_id=incident.id,
            lat=lat,
            lon=lon,
            notes=notes,
            depth_tag=depth_tag,
            evidence_id=evidence.id,
            grouping_candidates=candidates,
        )
        db.add(report)
        db.flush()
        audit(
            db,
            user,
            "REPORT_SUBMITTED",
            incident.id,
            report_id=report.id,
            evidence_sha256=evidence.sha256,
            grouping_candidates=candidates,
        )
        notify(
            db,
            incident,
            "Report received",
            "Awaiting officer verification. Photo screening provides review cues only.",
        )
        return {
            "success": True,
            "report_id": report.id,
            "incident_id": incident.id,
            "grouping_candidates": candidates,
            "status": "SUBMITTED",
            "screening": screening,
            "triage": rescore(incident),
        }

    @app.post("/api/v1/incidents/{identifier}/review", tags=["Officer workflow"])
    def review(
        identifier: str,
        data: ReviewInput,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "officer")
        incident = incident_for(db, identifier, user, lock=True)
        if incident.status not in {"SUBMITTED", "VERIFIED"}:
            raise HTTPException(409, "Review is available before dispatch")
        if not data.note.strip():
            raise HTTPException(422, "Add a review note")
        if not data.approved:
            incident.status = "REJECTED"
        else:
            incident.severity = data.severity or incident.severity
            factors, sources = dict(incident.factors), dict(incident.factor_sources)
            factors["S"], sources["S"] = (
                SEVERITY_MAPPING[incident.severity],
                "officer reviewed depth tag",
            )
            for key, value in {
                "R": None if data.rain_mm_hr is None else min(1, data.rain_mm_hr / 80),
                "W": data.ward_criticality,
                "D": data.blockage,
                "E": None
                if data.emergency_route is None
                else float(data.emergency_route),
            }.items():
                if value is not None:
                    factors[key], sources[key] = (
                        value,
                        "officer entered; see review audit note",
                    )
            incident.factors, incident.factor_sources = factors, sources
            incident.verified_by, incident.status = user.id, "VERIFIED"
            rescore(incident)
        incident.updated_at = utcnow()
        audit(
            db,
            user,
            "OFFICER_REVIEW",
            identifier,
            approved=data.approved,
            note=data.note,
            factors=incident.factors,
            sources=incident.factor_sources,
        )
        notify(
            db,
            incident,
            "Officer review completed",
            f"Report status: {incident.status}",
        )
        return serialize_incident(db, incident)

    @app.post("/api/v1/incidents/{identifier}/merge", tags=["Officer workflow"])
    def merge(
        identifier: str,
        data: MergeInput,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "officer")
        if identifier == data.target_incident_id:
            raise HTTPException(422, "Choose a different incident")
        source, target = (
            incident_for(db, identifier, user, True),
            incident_for(db, data.target_incident_id, user, True),
        )
        if source.status not in {"SUBMITTED", "VERIFIED"} or target.status not in {
            "SUBMITTED",
            "VERIFIED",
        }:
            raise HTTPException(409, "Only open reports before dispatch can be merged")
        if (
            haversine_meters(source.lat, source.lon, target.lat, target.lon) > 150
            or abs(
                (aware(source.created_at) - aware(target.created_at)).total_seconds()
            )
            > 21600
        ):
            raise HTTPException(
                422, "Grouping requires a 150 m radius and six-hour window"
            )
        for report in db.scalars(select(Report).where(Report.incident_id == source.id)):
            report.incident_id = target.id
        for proof in db.scalars(
            select(Evidence).where(Evidence.incident_id == source.id)
        ):
            proof.incident_id = target.id
        source.status, source.updated_at = "REJECTED", utcnow()
        if SEVERITY_MAPPING[source.severity] > SEVERITY_MAPPING[target.severity]:
            target.severity, target.status, target.verified_by = (
                source.severity,
                "SUBMITTED",
                None,
            )
            target.factors = {**target.factors, "S": SEVERITY_MAPPING[source.severity]}
            target.factor_sources = {
                **target.factor_sources,
                "S": "merged citizen claim; officer re-review required",
            }
        target.updated_at = utcnow()
        db.flush()
        audit(
            db,
            user,
            "REPORTS_MERGED",
            target.id,
            source_incident=source.id,
            note=data.note,
        )
        notify(
            db,
            target,
            "Reports grouped after officer review",
            "The report remains linked to its original evidence.",
        )
        return serialize_incident(db, target)

    @app.post("/api/v1/incidents/{identifier}/dispatch", tags=["Officer workflow"])
    def dispatch(
        identifier: str,
        data: DispatchInput,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "officer")
        incident = incident_for(db, identifier, user, True)
        if (
            incident.status != "VERIFIED"
            or incident.verified_by is None
            or db.get(Job, identifier)
        ):
            raise HTTPException(
                409, "Dispatch requires an officer-verified, unassigned incident"
            )
        crew = db.scalar(
            select(User)
            .where(
                User.staff_id == data.crew_id,
                User.role == "crew",
                User.verified.is_(True),
            )
            .with_for_update()
        )
        if not crew:
            raise HTTPException(422, "Choose an issued crew account")
        if db.scalar(
            select(Job).where(Job.crew_id == crew.id, Job.closed_at.is_(None))
        ):
            raise HTTPException(409, "Crew already has an active assignment")
        db.add(Job(incident_id=identifier, crew_id=crew.id))
        incident.status, incident.updated_at = "DISPATCHED", utcnow()
        db.flush()
        audit(db, user, "CREW_DISPATCHED", identifier, crew_id=crew.staff_id)
        notify(
            db,
            incident,
            "Crew assigned",
            "Field response requires before/after evidence and officer closure review.",
        )
        return serialize_incident(db, incident)

    @app.post("/api/v1/jobs/{identifier}/status", tags=["Field response"])
    def status(
        identifier: str,
        data: StateInput,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "crew")
        incident = incident_for(db, identifier, user, True)
        if data.capture_source == "demo-fixture" and settings.mode == "deployment":
            raise HTTPException(
                422, "Synthetic GPS fixes are disabled in deployment mode"
            )
        expected = "DISPATCHED" if data.status == "ON_SITE" else "ON_SITE"
        if incident.status != expected:
            raise HTTPException(409, "Invalid field status transition")
        if haversine_meters(data.lat, data.lon, incident.lat, incident.lon) > 50:
            raise HTTPException(422, "Confirm arrival within 50 m of the incident")
        incident.status, incident.updated_at = data.status, utcnow()
        audit(
            db,
            user,
            data.status,
            identifier,
            lat=data.lat,
            lon=data.lon,
            accuracy_m=data.accuracy_m,
            metadata_trust="device-asserted; officer review required",
        )
        notify(db, incident, "Field status updated", data.status)
        return serialize_incident(db, incident)

    @app.post(
        "/api/v1/jobs/{identifier}/evidence", tags=["Field response"], status_code=201
    )
    async def field_evidence(
        identifier: str,
        photo: UploadFile = File(...),
        kind: Literal["before", "after"] = Form(...),
        lat: float = Form(..., ge=-90, le=90),
        lon: float = Form(..., ge=-180, le=180),
        accuracy_m: float = Form(..., gt=0, le=50),
        captured_at: datetime = Form(...),
        capture_source: Literal["gps", "demo-fixture"] = Form("gps"),
        note: str = Form("", max_length=1200),
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "crew")
        incident = incident_for(db, identifier, user, True)
        job = db.get(Job, identifier)
        if capture_source == "demo-fixture" and settings.mode == "deployment":
            raise HTTPException(
                422, "Synthetic GPS fixes are disabled in deployment mode"
            )
        if incident.status not in {"ON_SITE", "WORK_IN_PROGRESS"}:
            raise HTTPException(409, "Mark on site before recording field proof")
        if (
            captured_at.tzinfo is None
            or not -60 <= (utcnow() - captured_at).total_seconds() <= 900
        ):
            raise HTTPException(
                422,
                "Field capture requires a timezone and a timestamp within 15 minutes",
            )
        if (
            captured_at < aware(job.dispatched_at) - timedelta(seconds=60)
            or haversine_meters(lat, lon, incident.lat, incident.lon) > 50
        ):
            raise HTTPException(
                422, "Capture fresh field evidence at the dispatched incident"
            )
        data, screening = await read_photo(photo)
        previous = db.scalars(
            select(Evidence).where(Evidence.incident_id == identifier)
        ).all()
        if any(
            e.sha256 == screening["sha256"] or e.pixel_hash == screening["pixel_hash"]
            for e in previous
        ):
            raise HTTPException(
                422,
                "Capture a new field photo; an existing image cannot be reused as proof",
            )
        if kind == "after" and (
            not job.before_id
            or captured_at <= aware(db.get(Evidence, job.before_id).captured_at)
        ):
            raise HTTPException(409, "A prior crew before-photo is required first")
        if kind == "before" and job.before_id:
            raise HTTPException(409, "Before-photo already recorded")
        if kind == "after" and not note.strip():
            raise HTTPException(422, "Add a work note with the after-photo")
        proof = store_evidence(
            db,
            user,
            incident,
            kind,
            data,
            screening,
            lat,
            lon,
            captured_at,
            accuracy_m,
            capture_source,
        )
        if kind == "before":
            job.before_id = proof.id
        else:
            job.after_id, job.work_note = proof.id, note.strip()
            incident.status = "AWAITING_REVIEW"
        incident.updated_at = utcnow()
        audit(
            db,
            user,
            "FIELD_EVIDENCE_UPLOADED",
            identifier,
            kind=kind,
            evidence_id=proof.id,
            sha256=proof.sha256,
            metadata_trust="device-asserted; officer review required",
        )
        notify(
            db,
            incident,
            "Field photo proof uploaded",
            "Officer closure review required"
            if kind == "after"
            else "Before-photo recorded",
        )
        return {
            "evidence_id": proof.id,
            "sha256": proof.sha256,
            "status": incident.status,
        }

    @app.post("/api/v1/incidents/{identifier}/closure", tags=["Officer workflow"])
    def closure(
        identifier: str,
        data: ClosureInput,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "officer")
        incident, job = (
            incident_for(db, identifier, user, True),
            db.get(Job, identifier),
        )
        if (
            incident.status != "AWAITING_REVIEW"
            or not job
            or not job.before_id
            or not job.after_id
        ):
            raise HTTPException(
                409, "Before/after crew proof and officer review are required"
            )
        before, after = db.get(Evidence, job.before_id), db.get(Evidence, job.after_id)
        if before.pixel_hash == after.pixel_hash or any(
            not verify_stored_file(evidence_dir / e.filename, e.sha256)
            for e in [before, after]
        ):
            raise HTTPException(409, "Evidence integrity check failed; closure blocked")
        if data.approved:
            rescore(incident)
            incident.status, job.closed_at = "CLOSED", utcnow()
        else:
            incident.status, job.after_id = "WORK_IN_PROGRESS", None
        incident.updated_at = utcnow()
        audit(
            db,
            user,
            "CLOSURE_APPROVED" if data.approved else "REWORK_REQUESTED",
            identifier,
            note=data.note,
            before_sha256=before.sha256,
            after_sha256=after.sha256,
        )
        notify(
            db,
            incident,
            "Officer closure decision",
            "Verified and closed" if data.approved else "Further field work requested",
        )
        return serialize_incident(db, incident)

    @app.get("/api/v1/evidence/{identifier}", tags=["Evidence"])
    def evidence_file(
        identifier: str,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        proof = db.get(Evidence, identifier)
        if not proof:
            raise HTTPException(404, "Evidence not found")
        incident_for(db, proof.incident_id, user)
        if (
            user.role == "citizen"
            and proof.kind == "citizen"
            and proof.uploaded_by != user.id
        ):
            raise HTTPException(404, "Evidence not found")
        path = evidence_dir / proof.filename
        if not verify_stored_file(path, proof.sha256):
            raise HTTPException(409, "Evidence integrity check failed")
        return FileResponse(
            path,
            media_type=proof.media_type,
            headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"},
        )

    @app.get("/api/v1/snapshot", tags=["Shared state"])
    def snapshot(user=Depends(current_user), db=Depends(get_db, scope="function")):
        query = select(Incident).where(Incident.status != "REJECTED")
        if user.role == "citizen":
            query = query.where(
                Incident.id.in_(
                    select(Report.incident_id).where(Report.user_id == user.id)
                )
            )
        elif user.role == "crew":
            query = query.where(
                Incident.id.in_(select(Job.incident_id).where(Job.crew_id == user.id))
            )
        incidents = db.scalars(query).all()
        identifiers = [i.id for i in incidents]
        rq, eq = (
            select(Report).where(Report.incident_id.in_(identifiers)),
            select(Evidence).where(Evidence.incident_id.in_(identifiers)),
        )
        if user.role == "citizen":
            rq = rq.where(Report.user_id == user.id)
            eq = eq.where(
                (Evidence.kind != "citizen") | (Evidence.uploaded_by == user.id)
            )
        reports, evidence = db.scalars(rq).all(), db.scalars(eq).all()
        jobs = db.scalars(select(Job).where(Job.incident_id.in_(identifiers))).all()
        notes = db.scalars(
            select(Notification)
            .where(Notification.user_id == user.id)
            .order_by(Notification.id.desc())
            .limit(50)
        ).all()
        roster = (
            db.scalars(
                select(User).where(User.role == "crew", User.verified.is_(True))
            ).all()
            if user.role == "officer"
            else []
        )
        return {
            "server_time": utcnow().isoformat(),
            "role": user.role,
            "incidents": sorted(
                [serialize_incident(db, i) for i in incidents],
                key=lambda i: i["priority_score"],
                reverse=True,
            ),
            "reports": [
                {
                    "id": r.id,
                    "client_id": r.client_id,
                    "incident_id": r.incident_id,
                    "lat": r.lat,
                    "lon": r.lon,
                    "notes": r.notes,
                    "depth_tag": r.depth_tag,
                    "evidence_id": r.evidence_id,
                    "created_at": aware(r.created_at).isoformat(),
                    "reporter_name": db.get(User, r.user_id).name,
                    "grouping_candidates": r.grouping_candidates,
                }
                for r in reports
            ],
            "evidence": [
                {
                    "id": e.id,
                    "incident_id": e.incident_id,
                    "kind": e.kind,
                    "sha256": e.sha256,
                    "url": f"/api/v1/evidence/{e.id}",
                    "lat": e.lat,
                    "lon": e.lon,
                    "accuracy_m": e.accuracy_m,
                    "capture_source": e.capture_source,
                    "captured_at": aware(e.captured_at).isoformat(),
                    "uploaded_at": aware(e.uploaded_at).isoformat(),
                    "screening": e.screening,
                }
                for e in evidence
            ],
            "jobs": [
                {
                    "incident_id": j.incident_id,
                    "crew_id": db.get(User, j.crew_id).staff_id,
                    "before_id": j.before_id,
                    "after_id": j.after_id,
                    "work_note": j.work_note,
                    "dispatched_at": aware(j.dispatched_at).isoformat(),
                    "closed_at": aware(j.closed_at).isoformat()
                    if j.closed_at
                    else None,
                }
                for j in jobs
            ],
            "crew": [{"id": m.staff_id, "name": m.name} for m in roster],
            "notifications": [
                {
                    "id": n.id,
                    "incident_id": n.incident_id,
                    "title": n.title,
                    "body": n.body,
                    "at": aware(n.at).isoformat(),
                    "push_status": n.push_status,
                }
                for n in notes
            ],
        }

    @app.get("/api/v1/incidents/heatmap", tags=["GIS"])
    def heatmap(user=Depends(current_user), db=Depends(get_db, scope="function")):
        require_role(user, "officer")
        incidents = db.scalars(
            select(Incident).where(Incident.status.notin_(["CLOSED", "REJECTED"]))
        ).all()
        return {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "geometry": {"type": "Point", "coordinates": [i.lon, i.lat]},
                    "properties": serialize_incident(db, i),
                }
                for i in incidents
            ],
        }

    @app.get("/api/v1/incidents/{identifier}/audit", tags=["Evidence"])
    def audit_history(
        identifier: str,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "officer")
        incident_for(db, identifier, user)
        return [
            {
                "id": e.id,
                "action": e.action,
                "actor_role": db.get(User, e.actor_id).role,
                "at": aware(e.at).isoformat(),
                "details": e.details,
            }
            for e in db.scalars(
                select(AuditEvent)
                .where(AuditEvent.incident_id == identifier)
                .order_by(AuditEvent.id)
            )
        ]

    @app.post("/api/v1/routes", tags=["Routing"])
    def route(
        data: RouteInput,
        user=Depends(current_user),
        db=Depends(get_db, scope="function"),
    ):
        require_role(user, "officer", "crew")
        hazards = [
            {"incident_id": i.id, "lat": i.lat, "lon": i.lon, "radius_m": 150}
            for i in db.scalars(
                select(Incident).where(
                    Incident.status.notin_(["CLOSED", "REJECTED"]),
                    Incident.severity.in_(["waist", "submerged"]),
                )
            )
        ]
        return OSRMEngine(settings.osrm_url).calculate_route(
            (data.origin_lat, data.origin_lon), (data.dest_lat, data.dest_lon), hazards
        )

    @app.get("/api/v1/risk/demo", tags=["Risk model"])
    def risk_demo(user=Depends(current_user)):
        from intelligence.forecast import run_demo

        return run_demo()

    @app.post("/api/v1/devices", tags=["Notifications"])
    def device(
        data: dict, user=Depends(current_user), db=Depends(get_db, scope="function")
    ):
        token = data.get("token", "")
        if not isinstance(token, str) or not 20 <= len(token) <= 4096:
            raise HTTPException(422, "Invalid FCM device token")
        existing = db.scalar(select(Device).where(Device.token == token))
        if existing and existing.user_id != user.id:
            raise HTTPException(
                409, "Device token already associated with another account"
            )
        if not existing:
            db.add(Device(user_id=user.id, token=token))
        return {
            "registered": True,
            "push_status": "CONFIGURED"
            if settings.fcm_credentials
            else "NOT_CONFIGURED",
        }

    return app


app = create_app()
