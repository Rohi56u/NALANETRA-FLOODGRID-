"""Proximity suggests grouping; only an officer can merge incidents."""

from math import asin, cos, radians, sin, sqrt
from .database import aware, utcnow


def haversine_meters(lat1, lon1, lat2, lon2):
    x, y = radians(lat2 - lat1), radians(lon2 - lon1)
    a = sin(x / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(y / 2) ** 2
    return 6371000 * 2 * asin(min(1, sqrt(max(0, a))))


def grouping_candidates(lat, lon, incidents, now=None):
    now = now or utcnow()
    result = []
    for incident in incidents:
        age = (now - aware(incident.created_at)).total_seconds()
        distance = haversine_meters(lat, lon, incident.lat, incident.lon)
        if (
            incident.status not in {"CLOSED", "REJECTED"}
            and 0 <= age <= 21600
            and distance <= 150
        ):
            result.append(
                {
                    "incident_id": incident.id,
                    "distance_m": round(distance, 1),
                    "review_required": True,
                }
            )
    return sorted(result, key=lambda item: item["distance_m"])
