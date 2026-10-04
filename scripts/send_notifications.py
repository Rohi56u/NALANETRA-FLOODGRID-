"""Operator-triggered outbox submission; never invoked by tests."""

from sqlalchemy import select
from backend.database import Device, Notification, connect
from backend.settings import Settings
from security.fcm_notifier import FCMNotifier


def main():
    config = Settings().prepare()
    notifier = FCMNotifier(config.fcm_credentials)
    if not config.fcm_credentials:
        raise SystemExit("FCM credentials are not configured; no notifications sent")
    engine, sessions = connect(config.database_url)
    with sessions.begin() as db:
        for note in db.scalars(
            select(Notification).where(
                Notification.push_status.in_(["PENDING", "RETRY_REQUIRED"])
            )
        ):
            tokens = db.scalars(
                select(Device.token).where(Device.user_id == note.user_id)
            ).all()
            results = [
                notifier.send(
                    token, note.title, note.body, {"incident_id": note.incident_id}
                )
                for token in tokens
            ]
            note.push_status = (
                "ACCEPTED_BY_FCM"
                if results and all(r == "ACCEPTED_BY_FCM" for r in results)
                else "RETRY_REQUIRED"
            )
    engine.dispose()
    print("Outbox processed; provider acceptance does not confirm device delivery.")


if __name__ == "__main__":
    main()
