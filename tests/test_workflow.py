from datetime import timedelta
import json
from fastapi.testclient import TestClient
from backend.main import create_app
from backend.database import Evidence, User, utcnow
from backend.auth import hash_password
from conftest import login, submit, review_dispatch, upload_proof, photo_bytes


def on_site(client, crew, identifier):
    response = client.post(
        f"/api/v1/jobs/{identifier}/status",
        headers=crew,
        json={"status": "ON_SITE", "lat": 28.47, "lon": 77.04, "accuracy_m": 8},
    )
    assert response.status_code == 200, response.text


def complete(client):
    citizen = login(client)
    identifier = submit(client, citizen)
    officer, crew = review_dispatch(client, identifier)
    on_site(client, crew, identifier)
    assert upload_proof(client, crew, identifier, "before", 1).status_code == 201
    assert upload_proof(client, crew, identifier, "after", 2).status_code == 201
    response = client.post(
        f"/api/v1/incidents/{identifier}/closure",
        headers=officer,
        json={
            "approved": True,
            "note": "Both field captures checked against synthetic assignment.",
        },
    )
    assert response.status_code == 200, response.text
    return identifier, citizen, officer, crew


def test_full_shared_workflow_notifications_and_officer_audit(client):
    identifier, citizen, officer, crew = complete(client)
    for headers in [citizen, officer, crew]:
        snapshot = client.get("/api/v1/snapshot", headers=headers).json()
        assert snapshot["incidents"][0]["status"] == "CLOSED"
        assert len(snapshot["evidence"]) == 3
        assert snapshot["notifications"][0]["title"] == "Officer closure decision"
        assert all(
            n["push_status"] == "NOT_CONFIGURED" for n in snapshot["notifications"]
        )
    audit = client.get(f"/api/v1/incidents/{identifier}/audit", headers=officer).json()
    assert [a["action"] for a in audit] == [
        "REPORT_SUBMITTED",
        "OFFICER_REVIEW",
        "CREW_DISPATCHED",
        "ON_SITE",
        "FIELD_EVIDENCE_UPLOADED",
        "FIELD_EVIDENCE_UPLOADED",
        "CLOSURE_APPROVED",
    ]
    assert len(audit[-1]["details"]["after_sha256"]) == 64


def test_restart_persists_workflow_and_session(client, settings):
    identifier, citizen, _, _ = complete(client)
    with TestClient(create_app(settings)) as second:
        response = second.get("/api/v1/snapshot", headers=citizen)
        assert response.status_code == 200
        assert response.json()["incidents"][0]["id"] == identifier
        assert response.json()["incidents"][0]["status"] == "CLOSED"


def test_anonymous_and_citizen_privileges_denied(client):
    assert client.post("/api/v1/incidents/report").status_code == 401
    citizen = login(client)
    identifier = submit(client, citizen)
    for path, body in [
        ("dispatch", {"crew_id": "MCG-FC-001"}),
        ("closure", {"approved": True, "note": "Unauthorized attempt"}),
    ]:
        assert (
            client.post(
                f"/api/v1/incidents/{identifier}/{path}", headers=citizen, json=body
            ).status_code
            == 403
        )
    assert (
        client.get(f"/api/v1/incidents/{identifier}/audit", headers=citizen).status_code
        == 403
    )


def test_staff_self_registration_denied(client):
    assert (
        client.post(
            "/api/v1/auth/register",
            json={
                "role": "officer",
                "email": "new@example.test",
                "fullName": "Intruder",
                "password": "long-password-123",
            },
        ).status_code
        == 403
    )


def test_dispatch_requires_verification_and_available_issued_crew(client):
    citizen = login(client)
    identifier = submit(client, citizen)
    officer = login(client, "officer")
    assert (
        client.post(
            f"/api/v1/incidents/{identifier}/dispatch",
            headers=officer,
            json={"crew_id": "MCG-FC-001"},
        ).status_code
        == 409
    )
    review_dispatch(client, identifier)
    assert (
        client.post(
            f"/api/v1/incidents/{identifier}/dispatch",
            headers=officer,
            json={"crew_id": "MCG-FC-001"},
        ).status_code
        == 409
    )
    second = submit(client, citizen, key="second")
    assert (
        client.post(
            f"/api/v1/incidents/{second}/review",
            headers=officer,
            json={"note": "Photo manually reviewed"},
        ).status_code
        == 200
    )
    assert (
        client.post(
            f"/api/v1/incidents/{second}/dispatch",
            headers=officer,
            json={"crew_id": "MCG-FC-001"},
        ).status_code
        == 409
    )


def test_off_site_and_invalid_transition_rejected(client):
    identifier = submit(client, login(client))
    _, crew = review_dispatch(client, identifier)
    for status, lat, lon in [
        ("WORK_IN_PROGRESS", 28.47, 77.04),
        ("ON_SITE", 28.5, 77.1),
    ]:
        result = client.post(
            f"/api/v1/jobs/{identifier}/status",
            headers=crew,
            json={"status": status, "lat": lat, "lon": lon, "accuracy_m": 8},
        )
        assert result.status_code in [409, 422]


def test_proof_requires_fresh_distinct_new_capture_pair(client):
    identifier = submit(client, login(client))
    officer, crew = review_dispatch(client, identifier)
    on_site(client, crew, identifier)
    assert (
        client.post(
            f"/api/v1/incidents/{identifier}/closure",
            headers=officer,
            json={"approved": True, "note": "No proofs attached"},
        ).status_code
        == 409
    )
    assert upload_proof(client, crew, identifier, "after", 2).status_code == 409
    assert (
        upload_proof(
            client,
            crew,
            identifier,
            "before",
            1,
            captured_at=(utcnow() - timedelta(hours=1)).isoformat(),
        ).status_code
        == 422
    )
    assert (
        upload_proof(client, crew, identifier, "before", 1, lat=28.6).status_code == 422
    )
    assert upload_proof(client, crew, identifier, "before", 1).status_code == 201
    assert upload_proof(client, crew, identifier, "after", 1).status_code == 422
    assert upload_proof(client, crew, identifier, "after", 0).status_code == 422
    assert upload_proof(client, crew, identifier, "after", 2).status_code == 201


def test_changed_storage_blocks_photo_access_and_closure(client):
    identifier = submit(client, login(client))
    officer, crew = review_dispatch(client, identifier)
    on_site(client, crew, identifier)
    assert upload_proof(client, crew, identifier, "before", 1).status_code == 201
    proof = upload_proof(client, crew, identifier, "after", 2).json()["evidence_id"]
    with client.app.state.sessions() as db:
        name = db.get(Evidence, proof).filename
    (client.app.state.settings.data_dir / "evidence" / name).write_bytes(b"changed")
    assert client.get(f"/api/v1/evidence/{proof}", headers=officer).status_code == 409
    assert (
        client.post(
            f"/api/v1/incidents/{identifier}/closure",
            headers=officer,
            json={"approved": True, "note": "Must be blocked by digest mismatch"},
        ).status_code
        == 409
    )


def test_rework_keeps_history_and_demands_new_after_proof(client):
    identifier = submit(client, login(client))
    officer, crew = review_dispatch(client, identifier)
    on_site(client, crew, identifier)
    upload_proof(client, crew, identifier, "before", 1)
    upload_proof(client, crew, identifier, "after", 2)
    result = client.post(
        f"/api/v1/incidents/{identifier}/closure",
        headers=officer,
        json={"approved": False, "note": "Cleanup incomplete; repeat work"},
    )
    assert result.json()["status"] == "WORK_IN_PROGRESS"
    snapshot = client.get("/api/v1/snapshot", headers=officer).json()
    assert len(snapshot["evidence"]) == 3 and snapshot["jobs"][0]["after_id"] is None
    assert upload_proof(client, crew, identifier, "after", 2).status_code == 422


def test_idempotent_retry_does_not_create_second_incident(client):
    citizen = login(client)
    assert submit(client, citizen) == submit(client, citizen)
    assert len(client.get("/api/v1/snapshot", headers=citizen).json()["reports"]) == 1


def test_nearby_reports_remain_separate_until_officer_merge(client):
    citizen = login(client)
    one = submit(client, citizen)
    two = submit(client, citizen, key="second")
    officer = login(client, "officer")
    snapshot = client.get("/api/v1/snapshot", headers=officer).json()
    assert len(snapshot["incidents"]) == 2
    assert any(r["grouping_candidates"] for r in snapshot["reports"])
    result = client.post(
        f"/api/v1/incidents/{two}/merge",
        headers=officer,
        json={
            "target_incident_id": one,
            "note": "Same fixture obstruction checked by officer",
        },
    )
    assert result.json()["report_count"] == 2
    assert len(client.get("/api/v1/snapshot", headers=citizen).json()["incidents"]) == 1


def other_citizen(client):
    with client.app.state.sessions.begin() as db:
        db.add(
            User(
                name="Other fixture citizen",
                email="other@example.test",
                phone="",
                role="citizen",
                verified=True,
                password_hash=hash_password("test-password-123"),
            )
        )
    session = client.post(
        "/api/v1/auth/login",
        json={"email": "other@example.test", "password": "test-password-123"},
    ).json()
    return {"Authorization": f"Bearer {session['accessToken']}"}


def test_unrelated_accounts_and_unassigned_crew_cannot_access_evidence(client):
    submit(client, login(client))
    other = other_citizen(client)
    officer = login(client, "officer")
    assert client.get("/api/v1/snapshot", headers=other).json()["reports"] == []
    proof = client.get("/api/v1/snapshot", headers=officer).json()["evidence"][0]["id"]
    for headers in [other, login(client, "crew")]:
        assert (
            client.get(f"/api/v1/evidence/{proof}", headers=headers).status_code == 404
        )
    assert client.get(f"/api/v1/evidence/{proof}").status_code == 401


def test_merged_incident_keeps_other_citizens_raw_photos_private(client):
    citizen = login(client)
    one = submit(client, citizen)
    other = other_citizen(client)
    two = submit(client, other, key="other-report")
    officer = login(client, "officer")
    other_proof = client.get("/api/v1/snapshot", headers=other).json()["evidence"][0][
        "id"
    ]
    result = client.post(
        f"/api/v1/incidents/{two}/merge",
        headers=officer,
        json={"target_incident_id": one, "note": "Same obstruction checked by officer"},
    )
    assert result.status_code == 200
    assert len(client.get("/api/v1/snapshot", headers=citizen).json()["evidence"]) == 1
    assert (
        client.get(f"/api/v1/evidence/{other_proof}", headers=citizen).status_code
        == 404
    )


def test_refresh_rotates_and_logout_revokes_session(client):
    session = client.post(
        "/api/v1/auth/login",
        json={"email": "citizen@example.test", "password": "Demo-Only-2026!"},
    ).json()
    old = {"Authorization": f"Bearer {session['accessToken']}"}
    fresh = client.post(
        "/api/v1/auth/refresh", json={"refreshToken": session["refreshToken"]}
    ).json()
    assert client.get("/api/v1/snapshot", headers=old).status_code == 401
    assert (
        client.post(
            "/api/v1/auth/refresh", json={"refreshToken": session["refreshToken"]}
        ).status_code
        == 401
    )
    current = {"Authorization": f"Bearer {fresh['accessToken']}"}
    assert client.post("/api/v1/auth-logout", headers=current).status_code == 200
    assert client.get("/api/v1/snapshot", headers=current).status_code == 401


def test_verification_challenge_limits_and_single_use(client):
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "fullName": "Test Citizen",
            "email": "test@example.test",
            "password": "unique-password-123",
        },
    ).json()
    challenge = registered["challengeId"]
    code = json.loads(
        (
            client.app.state.settings.data_dir
            / "mail-outbox"
            / f"challenge-{challenge}.json"
        ).read_text()
    )["code"]
    assert (
        client.post(
            "/api/v1/auth/verify", json={"challengeId": challenge, "emailCode": "bad"}
        ).status_code
        == 400
    )
    assert (
        client.post(
            "/api/v1/auth/verify", json={"challengeId": challenge, "emailCode": code}
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/api/v1/auth/verify", json={"challengeId": challenge, "emailCode": code}
        ).status_code
        == 400
    )


def test_failed_login_lock_is_persistent(client):
    for _ in range(5):
        assert (
            client.post(
                "/api/v1/auth/login",
                json={"email": "citizen@example.test", "password": "incorrect"},
            ).status_code
            == 401
        )
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "citizen@example.test", "password": "Demo-Only-2026!"},
        ).status_code
        == 429
    )


def test_bad_image_future_time_and_empty_after_note_rejected(client):
    citizen = login(client)
    fields = {
        "client_id": "invalid",
        "location": "Test",
        "lat": 28.47,
        "lon": 77.04,
        "depth_tag": "knee",
        "captured_at": utcnow().isoformat(),
    }
    assert (
        client.post(
            "/api/v1/incidents/report",
            headers=citizen,
            data=fields,
            files={"photo": ("fake.jpg", b"not-an-image", "image/jpeg")},
        ).status_code
        == 422
    )
    fields["captured_at"] = (utcnow() + timedelta(days=2)).isoformat()
    assert (
        client.post(
            "/api/v1/incidents/report",
            headers=citizen,
            data=fields,
            files={"photo": ("fixture.png", photo_bytes(), "image/png")},
        ).status_code
        == 422
    )
    identifier = submit(client, citizen)
    _, crew = review_dispatch(client, identifier)
    on_site(client, crew, identifier)
    upload_proof(client, crew, identifier, "before", 1)
    before_count = len(
        list((client.app.state.settings.data_dir / "evidence").iterdir())
    )
    assert (
        upload_proof(client, crew, identifier, "after", 2, note="").status_code == 422
    )
    assert (
        len(list((client.app.state.settings.data_dir / "evidence").iterdir()))
        == before_count
    )
