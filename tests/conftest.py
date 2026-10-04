from datetime import timedelta
from io import BytesIO
from PIL import Image, ImageDraw
import pytest
from fastapi.testclient import TestClient
from backend.main import create_app
from backend.settings import Settings
from backend.database import utcnow
from scripts.bootstrap_demo import seed_accounts, DEMO_PASSWORD


def photo_bytes(stage=0):
    image = Image.new("RGB", (320, 200), (36, 52, 70))
    draw = ImageDraw.Draw(image)
    draw.rectangle(
        (0, 100, 320, 200), fill=(165, 122, 60) if stage != 2 else (105, 112, 120)
    )
    draw.rectangle((35 + stage * 22, 30, 145 + stage * 22, 105), fill=(220, 228, 238))
    draw.line(
        (0, 195 - stage * 20, 300, 150 - stage * 18), fill=(245, 190, 65), width=9
    )
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


@pytest.fixture
def settings(tmp_path):
    return Settings(
        data_dir=tmp_path / "data",
        mode="test",
        jwt_secret="test-secret-with-at-least-32-characters",
    ).prepare()


@pytest.fixture
def client(settings):
    seed_accounts(settings)
    with TestClient(create_app(settings)) as instance:
        yield instance


def login(client, role="citizen"):
    staff = {"officer": "MCG-OF-001", "crew": "MCG-FC-001"}.get(role, "")
    response = client.post(
        "/api/v1/auth/login",
        json={
            "role": role,
            "email": f"{role}@example.test",
            "staffId": staff,
            "password": DEMO_PASSWORD,
        },
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['accessToken']}"}


def submit(client, citizen, key="fixture-report-1", lat=28.47, lon=77.04):
    response = client.post(
        "/api/v1/incidents/report",
        headers=citizen,
        data={
            "client_id": key,
            "location": "Synthetic test site",
            "lat": lat,
            "lon": lon,
            "depth_tag": "knee",
            "captured_at": (utcnow() - timedelta(seconds=30)).isoformat(),
            "capture_source": "gps",
            "accuracy_m": 8,
        },
        files={"photo": ("fixture.png", photo_bytes(0), "image/png")},
    )
    assert response.status_code == 201, response.text
    return response.json()["incident_id"]


def review_dispatch(client, identifier):
    officer = login(client, "officer")
    response = client.post(
        f"/api/v1/incidents/{identifier}/review",
        headers=officer,
        json={
            "approved": True,
            "severity": "knee",
            "rain_mm_hr": 40,
            "ward_criticality": 0.7,
            "blockage": 0.5,
            "emergency_route": True,
            "note": "Synthetic exercise: photo and depth tag reviewed; fixture context only.",
        },
    )
    assert response.status_code == 200, response.text
    response = client.post(
        f"/api/v1/incidents/{identifier}/dispatch",
        headers=officer,
        json={"crew_id": "MCG-FC-001"},
    )
    assert response.status_code == 200, response.text
    return officer, login(client, "crew")


def upload_proof(client, crew, identifier, kind, stage, **overrides):
    fields = {
        "kind": kind,
        "lat": 28.47,
        "lon": 77.04,
        "accuracy_m": 8,
        "captured_at": utcnow().isoformat(),
        "note": "Synthetic cleanup demonstration",
    }
    fields.update(overrides)
    return client.post(
        f"/api/v1/jobs/{identifier}/evidence",
        headers=crew,
        data=fields,
        files={"photo": ("fixture.png", photo_bytes(stage), "image/png")},
    )
