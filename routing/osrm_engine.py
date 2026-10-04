"""OSRM road geometry with full-segment screening of known closure buffers."""

from math import cos, radians
import httpx


def route_intersections(coordinates, hazards):
    blocked = []
    for hazard in hazards:
        scale_x, scale_y = 111320 * cos(radians(hazard["lat"])), 111320
        points = [
            ((p[0] - hazard["lon"]) * scale_x, (p[1] - hazard["lat"]) * scale_y)
            for p in coordinates
        ]
        hit = False
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            dx, dy = bx - ax, by - ay
            length = dx * dx + dy * dy
            t = 0 if length == 0 else max(0, min(1, -(ax * dx + ay * dy) / length))
            if (ax + t * dx) ** 2 + (ay + t * dy) ** 2 <= hazard.get(
                "radius_m", 150
            ) ** 2:
                hit = True
                break
        if hit:
            blocked.append(hazard["incident_id"])
    return blocked


def choose_route(routes, hazards):
    candidates, rejected = [], []
    for route in routes:
        coordinates = route.get("geometry", {}).get("coordinates", [])
        if len(coordinates) < 2:
            continue
        conflicts = route_intersections(coordinates, hazards)
        if conflicts:
            rejected.append(
                {"blocked_by": conflicts, "distance_m": route.get("distance")}
            )
        else:
            candidates.append(route)
    if not candidates:
        return {
            "status": "NO_RECOMMENDATION",
            "route": None,
            "rejected_routes": rejected,
            "reason": "All returned alternatives are blocked or have no usable geometry; choose a staging point with the dispatcher",
        }
    return {
        "status": "RECOMMENDED",
        "route": min(candidates, key=lambda r: r["duration"]),
        "rejected_routes": rejected,
        "limitations": "Known-closure overlay only; no guarantee of flood-free travel or complete alternative coverage",
    }


class OSRMEngine:
    def __init__(self, base_url="", transport=None):
        self.base_url, self.transport = base_url.rstrip("/"), transport

    def calculate_route(self, origin, destination, hazards):
        if not self.base_url:
            return {
                "status": "PROVIDER_NOT_CONFIGURED",
                "provider": "OSRM",
                "route": None,
            }
        coordinates = f"{origin[1]},{origin[0]};{destination[1]},{destination[0]}"
        try:
            with httpx.Client(transport=self.transport, timeout=15) as client:
                response = client.get(
                    f"{self.base_url}/route/v1/driving/{coordinates}",
                    params={
                        "alternatives": "true",
                        "geometries": "geojson",
                        "overview": "full",
                        "steps": "true",
                    },
                )
                response.raise_for_status()
                data = response.json()
            if data.get("code") != "Ok":
                return {
                    "status": "NO_RECOMMENDATION",
                    "provider": "OSRM",
                    "route": None,
                    "reason": "Provider returned no road route",
                }
            routes = data.get("routes", [])
            return {
                **choose_route(routes, hazards),
                "provider": "OSRM",
                "routes_screened": len(routes),
            }
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            return {
                "status": "PROVIDER_UNAVAILABLE",
                "provider": "OSRM",
                "route": None,
                "reason": "No road geometry is invented on provider failure",
            }
