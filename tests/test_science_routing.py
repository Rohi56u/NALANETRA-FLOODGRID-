from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
import httpx
import pytest
from backend.priority_engine import (
    IncidentMetrics,
    calculate_priority_score,
    score_factors,
)
from backend.spatial_clustering import grouping_candidates
from intelligence.radar_ingestion import summarize_cells
from intelligence.forecast import run_demo
from intelligence.yolo_photo_screening import screen_photo
from routing.osrm_engine import OSRMEngine, choose_route, route_intersections
from security.fcm_notifier import FCMNotifier
from conftest import photo_bytes


def test_priority_matches_six_factor_formula_no_extra_multiplier():
    result = calculate_priority_score(IncidentMetrics("knee", 40, 0.5, 0.5, True, 0))
    assert result["priority_score"] == 50
    assert result["factor_breakdown"] == {
        "S": 0.5,
        "R": 0.5,
        "W": 0.5,
        "D": 0.5,
        "E": 1,
        "A": 0,
    }


@pytest.mark.parametrize("value", [-100, 0, 0.5, 1, 200])
def test_priority_is_bounded(value):
    assert 0 <= score_factors({key: value for key in "SRWDEA"})["priority_score"] <= 100


def test_nonfinite_factors_fail_and_deepwater_policy_preserves_score():
    with pytest.raises(ValueError):
        score_factors({"S": float("nan")})
    result = calculate_priority_score(IncidentMetrics("waist", 0, 0, 0, False, 0))
    assert (
        result["priority_score"] == 22.5
        and result["band"] == "CRITICAL"
        and result["dynamic_upgrade_override"]
    )


def test_closed_old_future_and_distant_incidents_are_not_candidates():
    now = datetime.now(timezone.utc)
    incidents = [
        SimpleNamespace(
            id="closed", lat=28.47, lon=77.04, status="CLOSED", created_at=now
        ),
        SimpleNamespace(
            id="old",
            lat=28.47,
            lon=77.04,
            status="VERIFIED",
            created_at=now - timedelta(hours=7),
        ),
        SimpleNamespace(
            id="future",
            lat=28.47,
            lon=77.04,
            status="VERIFIED",
            created_at=now + timedelta(hours=1),
        ),
        SimpleNamespace(
            id="far", lat=28.5, lon=77.1, status="VERIFIED", created_at=now
        ),
        SimpleNamespace(
            id="valid", lat=28.47, lon=77.04, status="VERIFIED", created_at=now
        ),
    ]
    assert [
        r["incident_id"] for r in grouping_candidates(28.47, 77.04, incidents, now)
    ] == ["valid"]


def test_stale_and_missing_radar_are_not_zero_risk():
    now = datetime.now(timezone.utc)
    assert summarize_cells([], now)["rain_mm_hr"] is None
    assert summarize_cells([40], now - timedelta(hours=1))["status"] == "STALE"
    assert summarize_cells([40], now)["rain_mm_hr"] > 0


def test_network_model_conserves_water_and_reports_terrain_only():
    result = run_demo()
    assert result["status"] == "SYNTHETIC_FIXTURE" and result["horizon_minutes"] == 180
    assert result["max_balance_error_m3"] < 1e-8
    assert all(
        v >= -1e-10 for row in result["timeline"] for v in row["storage_m3"].values()
    )
    assert result["terrain"]["flood_depth_estimate"] is None


def test_photo_screening_reads_actual_pixels_without_depth_or_accuracy_claim():
    result = screen_photo(photo_bytes())
    assert (
        result["depth_estimate"] is None
        and result["confidence"] is None
        and result["review_required"]
    )
    assert 0 <= result["water_colour_fraction"] <= 1
    with pytest.raises(ValueError):
        screen_photo(b"not-image")


def test_full_segment_detects_hazard_close_to_route_start():
    assert route_intersections(
        [[77, 28], [77.1, 28]],
        [{"incident_id": "start", "lat": 28, "lon": 77.001, "radius_m": 150}],
    ) == ["start"]


def test_osrm_alternative_and_all_blocked_results():
    direct = {
        "distance": 1000,
        "duration": 100,
        "geometry": {"coordinates": [[77, 28], [77.1, 28]]},
    }
    detour = {
        "distance": 1600,
        "duration": 160,
        "geometry": {"coordinates": [[77, 28], [77, 28.02], [77.1, 28.02], [77.1, 28]]},
    }
    hazards = [{"incident_id": "blocked", "lat": 28, "lon": 77.05, "radius_m": 150}]
    assert choose_route([direct, detour], hazards)["route"]["distance"] == 1600
    assert choose_route([direct], hazards)["status"] == "NO_RECOMMENDATION"

    def respond(request):
        assert (
            request.url.params["geometries"] == "geojson"
            and request.url.params["steps"] == "true"
        )
        return httpx.Response(200, json={"code": "Ok", "routes": [direct, detour]})

    assert (
        OSRMEngine(
            "https://osrm.example.test", httpx.MockTransport(respond)
        ).calculate_route((28, 77), (28, 77.1), hazards)["routes_screened"]
        == 2
    )


def test_missing_routing_and_notification_configuration_are_explicit():
    assert (
        OSRMEngine("").calculate_route((28, 77), (28, 77.1), [])["status"]
        == "PROVIDER_NOT_CONFIGURED"
    )
    assert FCMNotifier().send("token", "title", "body") == "NOT_CONFIGURED"


def test_presentation_is_unchanged():
    from scripts.verify_presentation import verify

    assert verify()
