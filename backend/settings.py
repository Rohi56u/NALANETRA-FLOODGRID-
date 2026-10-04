"""Explicit development and deployment configuration boundaries."""

import os
import secrets
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass
class Settings:
    data_dir: Path = field(
        default_factory=lambda: Path(os.getenv("NALA_DATA_DIR", ROOT / "var"))
    )
    database_url: str = field(default_factory=lambda: os.getenv("DATABASE_URL", ""))
    jwt_secret: str = field(default_factory=lambda: os.getenv("NALA_JWT_SECRET", ""))
    mode: str = field(default_factory=lambda: os.getenv("NALA_MODE", "local"))
    mail_mode: str = field(default_factory=lambda: os.getenv("NALA_MAIL_MODE", "file"))
    origins: str = field(
        default_factory=lambda: os.getenv(
            "NALA_CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080"
        )
    )
    osrm_url: str = field(default_factory=lambda: os.getenv("NALA_OSRM_URL", ""))
    yolo_weights: str = field(
        default_factory=lambda: os.getenv("NALA_YOLO_WEIGHTS", "")
    )
    fcm_credentials: str = field(
        default_factory=lambda: os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    )
    max_photo_bytes: int = 6 * 1024 * 1024

    def prepare(self):
        self.data_dir = Path(self.data_dir).resolve()
        self.data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        if self.mode not in {"local", "test", "deployment"}:
            raise ValueError("NALA_MODE must be local, test or deployment")
        if self.mode == "deployment":
            if len(self.jwt_secret) < 32 or not self.database_url.startswith(
                "postgresql"
            ):
                raise ValueError(
                    "Deployment requires PostgreSQL and a private JWT secret of at least 32 characters"
                )
            if self.mail_mode != "smtp" or any(
                not os.getenv(k)
                for k in [
                    "NALA_SMTP_HOST",
                    "NALA_SMTP_USER",
                    "NALA_SMTP_PASSWORD",
                    "NALA_SMTP_FROM",
                ]
            ):
                raise ValueError(
                    "Deployment requires complete SMTP verification configuration"
                )
        if not self.database_url:
            self.database_url = f"sqlite:///{self.data_dir / 'nalanetra.sqlite3'}"
        if not self.jwt_secret:
            path = self.data_dir / ".jwt-secret"
            if not path.exists():
                with os.fdopen(
                    os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w"
                ) as stream:
                    stream.write(secrets.token_urlsafe(48))
            self.jwt_secret = path.read_text().strip()
        return self
