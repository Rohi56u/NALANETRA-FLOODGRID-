"""Optional FCM adapter. Provider acceptance is not proof of device delivery."""

import os


class FCMNotifier:
    def __init__(self, credentials=None):
        self.credentials = credentials or os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS", ""
        )

    def send(self, token, title, body, data=None):
        if not self.credentials:
            return "NOT_CONFIGURED"
        try:
            import firebase_admin
            from firebase_admin import credentials, messaging

            try:
                app = firebase_admin.get_app("nalanetra")
            except ValueError:
                app = firebase_admin.initialize_app(
                    credentials.Certificate(self.credentials), name="nalanetra"
                )
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(title=title, body=body),
                    data=data or {},
                ),
                app=app,
            )
            return "ACCEPTED_BY_FCM"
        except (ImportError, OSError, ValueError):
            return "ERROR"
        except Exception:
            return "RETRY_REQUIRED"
