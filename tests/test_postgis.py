"""Optional integration checks against an explicitly named, disposable CI database."""

import os
from urllib.parse import urlparse

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from backend.auth import hash_password
from backend.database import User
from backend.main import create_app
from backend.settings import Settings
from scripts.bootstrap_demo import ACCOUNTS, DEMO_PASSWORD
from test_workflow import complete


@pytest.fixture(scope="module")
def pg_client(tmp_path_factory):
    url = os.getenv("NALA_TEST_DATABASE_URL", "")
    if not url:
        pytest.skip("Requires the disposable nalanetra_test PostGIS service")
    if urlparse(url).path != "/nalanetra_test":
        pytest.fail(
            "Integration tests only accept the disposable nalanetra_test database"
        )
    settings = Settings(
        data_dir=tmp_path_factory.mktemp("postgis-evidence"),
        database_url=url,
        mode="test",
        jwt_secret="ci-test-secret-with-at-least-32-characters",
    ).prepare()
    application = create_app(settings)
    with application.state.sessions.begin() as session:
        for role, name, email, staff in ACCOUNTS:
            session.add(
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
    with TestClient(application) as client:
        yield client


def test_shared_workflow_with_postgres_transactions(pg_client):
    identifier, citizen, officer, crew = complete(pg_client)
    for headers in [citizen, officer, crew]:
        response = pg_client.get("/api/v1/snapshot", headers=headers)
        assert response.status_code == 200
        assert response.json()["incidents"][0]["id"] == identifier
        assert response.json()["incidents"][0]["status"] == "CLOSED"


def test_postgis_schema_geometry_and_spatial_query(pg_client):
    with pg_client.app.state.engine.connect() as connection:
        assert connection.scalar(text("SELECT postgis_version()"))
        point = connection.execute(
            text(
                "SELECT ST_X(geom), ST_Y(geom), ST_SRID(geom) FROM incident_geometry LIMIT 1"
            )
        ).one()
        assert point == pytest.approx((77.04, 28.47, 4326))
        count = connection.scalar(
            text("""SELECT count(*) FROM incidents WHERE ST_DWithin(
            ST_SetSRID(ST_MakePoint(lon,lat),4326)::geography,
            ST_SetSRID(ST_MakePoint(77.04,28.47),4326)::geography,150)""")
        )
        assert count == 1
        index = connection.scalar(
            text(
                "SELECT indexdef FROM pg_indexes WHERE indexname='one_active_job_per_crew'"
            )
        )
        assert "UNIQUE" in index and "closed_at IS NULL" in index
        connection.execute(
            text("""INSERT INTO flood_polygons(geom,source,observed_at,valid_until,synthetic)
            VALUES(ST_Multi(ST_GeomFromText(
            'POLYGON((77.03 28.46,77.05 28.46,77.05 28.48,77.03 28.48,77.03 28.46))',4326)),
            'synthetic CI polygon',now(),now()+interval '15 minutes',TRUE)""")
        )
        assert connection.scalar(
            text("""SELECT ST_Intersects(geom,
            ST_SetSRID(ST_MakePoint(77.04,28.47),4326)) FROM flood_polygons LIMIT 1""")
        )
        # The test polygon is rolled back; this does not ingest municipal field data.
        connection.rollback()
