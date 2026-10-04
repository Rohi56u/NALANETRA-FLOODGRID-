"""Issue known, fictional demo accounts only in local SQLite development."""

from sqlalchemy import select
from backend.auth import hash_password
from backend.database import User, connect
from backend.settings import Settings

DEMO_PASSWORD = "Demo-Only-2026!"
ACCOUNTS = [
    ("citizen", "Citizen Demo", "citizen@example.test", None),
    ("officer", "Officer Demo", "officer@example.test", "MCG-OF-001"),
    ("crew", "Crew Demo", "crew@example.test", "MCG-FC-001"),
]


def seed_accounts(settings):
    if settings.mode == "deployment" or not settings.database_url.startswith("sqlite"):
        raise ValueError("Demo accounts require local SQLite mode")
    engine, sessions = connect(settings.database_url)
    with sessions.begin() as db:
        for role, name, email, staff in ACCOUNTS:
            if not db.scalar(select(User.id).where(User.email == email)):
                db.add(
                    User(
                        name=name,
                        email=email,
                        phone="",
                        role=role,
                        staff_id=staff,
                        password_hash=hash_password(DEMO_PASSWORD),
                        verified=True,
                    )
                )
    engine.dispose()


if __name__ == "__main__":
    seed_accounts(Settings().prepare())
    print("LOCAL DEMO ONLY: keep the API bound to 127.0.0.1.")
    for role, _, email, staff in ACCOUNTS:
        print(f"{role}: {email}" + (f" | issued ID: {staff}" if staff else ""))
    print(f"Local fixture password: {DEMO_PASSWORD}")
