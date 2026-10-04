"""Operator-only staff issuance; passwords are read privately, not through CLI arguments."""

import argparse
import getpass
from backend.auth import hash_password
from backend.database import User, connect
from backend.settings import Settings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", required=True, choices=["officer", "crew"])
    parser.add_argument("--staff-id", required=True)
    parser.add_argument("--email", required=True)
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    password = getpass.getpass("New staff password (at least 12 characters): ")
    if len(password) < 12 or password != getpass.getpass("Repeat password: "):
        raise SystemExit("Password too short or confirmation mismatch")
    engine, sessions = connect(Settings().prepare().database_url)
    with sessions.begin() as db:
        db.add(
            User(
                name=args.name,
                email=args.email.lower().strip(),
                phone="",
                role=args.role,
                staff_id=args.staff_id,
                password_hash=hash_password(password),
                verified=True,
            )
        )
    engine.dispose()
    print("Issued staff account.")


if __name__ == "__main__":
    main()
