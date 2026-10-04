"""Observe persistence at the ASGI response boundary, before request cleanup."""

import asyncio
from datetime import timedelta
import json

import httpx
import pytest
from sqlalchemy import event, select
from sqlalchemy.exc import IntegrityError

from backend.database import Evidence, Incident, Report, utcnow
from conftest import login, photo_bytes


@pytest.mark.parametrize("commit_conflict", [False, True])
def test_report_receipt_requires_a_committed_transaction(client, commit_conflict):
    headers = login(client)
    request = httpx.Request(
        "POST",
        "http://testserver/api/v1/incidents/report",
        headers=headers,
        data={
            "client_id": "response-boundary-report",
            "location": "Synthetic receipt boundary check",
            "lat": "28.47",
            "lon": "77.04",
            "depth_tag": "knee",
            "captured_at": (utcnow() - timedelta(seconds=30)).isoformat(),
            "capture_source": "selected-map",
        },
        files={"photo": ("fixture.png", photo_bytes(), "image/png")},
    )
    body = request.read()
    messages, visible_reports = [], []
    session_class = client.app.state.sessions.class_

    def fail_commit(_session):
        raise IntegrityError("synthetic commit conflict", {}, Exception("conflict"))

    async def receive():
        return {"type": "http.request", "body": body, "more_body": False}

    async def send(message):
        messages.append(message)
        if message["type"] == "http.response.start":
            # A second session represents an immediate snapshot request from
            # another client. TestClient alone waits for dependency teardown.
            with client.app.state.sessions() as db:
                visible_reports.extend(db.scalars(select(Report.id)).all())

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "http",
        "path": "/api/v1/incidents/report",
        "raw_path": b"/api/v1/incidents/report",
        "query_string": b"",
        "root_path": "",
        "headers": [(name.lower(), value) for name, value in request.headers.raw],
        "client": ("127.0.0.1", 12345),
        "server": ("testserver", 80),
    }
    if commit_conflict:
        event.listen(session_class, "before_commit", fail_commit)
    try:
        asyncio.run(client.app(scope, receive, send))
    finally:
        if commit_conflict:
            event.remove(session_class, "before_commit", fail_commit)

    response = next(m for m in messages if m["type"] == "http.response.start")
    payload = json.loads(
        b"".join(
            m.get("body", b"") for m in messages if m["type"] == "http.response.body"
        )
    )
    with client.app.state.sessions() as db:
        if commit_conflict:
            assert response["status"] == 409
            assert not visible_reports
            assert not db.scalars(select(Incident)).all()
            assert not db.scalars(select(Evidence)).all()
            assert not list((client.app.state.settings.data_dir / "evidence").iterdir())
        else:
            assert response["status"] == 201
            assert visible_reports == [payload["report_id"]]
            assert (
                db.get(Report, payload["report_id"]).incident_id
                == payload["incident_id"]
            )
