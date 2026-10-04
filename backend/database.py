"""Persistent shared workflow records. SQLite locally; PostgreSQL for deployment."""

from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    JSON,
    Index,
    String,
    Text,
    UniqueConstraint,
    create_engine,
    event,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker


def utcnow():
    return datetime.now(timezone.utc)


def aware(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(254), unique=True)
    phone: Mapped[str] = mapped_column(String(24), default="")
    role: Mapped[str] = mapped_column(String(16))
    staff_id: Mapped[str | None] = mapped_column(String(40), unique=True, nullable=True)
    password_hash: Mapped[str] = mapped_column(Text)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)
    failed_logins: Mapped[int] = mapped_column(default=0)
    locked_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class AuthSession(Base):
    __tablename__ = "auth_sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    refresh_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)


class Challenge(Base):
    __tablename__ = "auth_challenges"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    code_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(default=0)
    consumed: Mapped[bool] = mapped_column(Boolean, default=False)


class Incident(Base):
    __tablename__ = "incidents"
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    location: Mapped[str] = mapped_column(String(200))
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    severity: Mapped[str] = mapped_column(String(16))
    status: Mapped[str] = mapped_column(String(32), default="SUBMITTED", index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    verified_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    factors: Mapped[dict] = mapped_column(JSON, default=dict)
    factor_sources: Mapped[dict] = mapped_column(JSON, default=dict)
    priority: Mapped[float] = mapped_column(Float, default=0)
    band: Mapped[str] = mapped_column(String(16), default="LOW")
    sla_minutes: Mapped[int] = mapped_column(default=240)


class Evidence(Base):
    __tablename__ = "evidence"
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    incident_id: Mapped[str] = mapped_column(ForeignKey("incidents.id"), index=True)
    uploaded_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    kind: Mapped[str] = mapped_column(String(16))
    sha256: Mapped[str] = mapped_column(String(64))
    pixel_hash: Mapped[str] = mapped_column(String(64))
    filename: Mapped[str] = mapped_column(String(80))
    media_type: Mapped[str] = mapped_column(String(30))
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    accuracy_m: Mapped[float | None] = mapped_column(Float, nullable=True)
    capture_source: Mapped[str] = mapped_column(String(20))
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    screening: Mapped[dict] = mapped_column(JSON)


class Report(Base):
    __tablename__ = "reports"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="report_idempotency"),
    )
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    client_id: Mapped[str] = mapped_column(String(80))
    incident_id: Mapped[str] = mapped_column(ForeignKey("incidents.id"), index=True)
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    notes: Mapped[str] = mapped_column(Text, default="")
    depth_tag: Mapped[str] = mapped_column(String(16))
    evidence_id: Mapped[str] = mapped_column(ForeignKey("evidence.id"))
    grouping_candidates: Mapped[list] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class Job(Base):
    __tablename__ = "jobs"
    incident_id: Mapped[str] = mapped_column(
        ForeignKey("incidents.id"), primary_key=True
    )
    crew_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    before_id: Mapped[str | None] = mapped_column(
        ForeignKey("evidence.id"), nullable=True
    )
    after_id: Mapped[str | None] = mapped_column(
        ForeignKey("evidence.id"), nullable=True
    )
    dispatched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    work_note: Mapped[str] = mapped_column(Text, default="")


# One active assignment per crew, enforced even if requests race.
Index(
    "one_active_job_per_crew",
    Job.crew_id,
    unique=True,
    sqlite_where=Job.closed_at.is_(None),
    postgresql_where=Job.closed_at.is_(None),
)


class AuditEvent(Base):
    __tablename__ = "audit_events"
    id: Mapped[int] = mapped_column(primary_key=True)
    actor_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    incident_id: Mapped[str | None] = mapped_column(String(40), nullable=True)
    action: Mapped[str] = mapped_column(String(60))
    details: Mapped[dict] = mapped_column(JSON)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Notification(Base):
    __tablename__ = "notifications"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    incident_id: Mapped[str] = mapped_column(ForeignKey("incidents.id"))
    title: Mapped[str] = mapped_column(String(160))
    body: Mapped[str] = mapped_column(Text)
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    push_status: Mapped[str] = mapped_column(String(30), default="NOT_CONFIGURED")


class Device(Base):
    __tablename__ = "devices"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    token: Mapped[str] = mapped_column(String(4096), unique=True)


def connect(url):
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+psycopg://", 1)
    engine = create_engine(
        url,
        connect_args={"check_same_thread": False, "timeout": 20}
        if url.startswith("sqlite")
        else {},
        pool_pre_ping=True,
    )
    if engine.dialect.name == "sqlite":

        @event.listens_for(engine, "connect")
        def sqlite_pragmas(dbapi, _):
            cursor = dbapi.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.close()

    Base.metadata.create_all(engine)
    return engine, sessionmaker(engine, expire_on_commit=False)
