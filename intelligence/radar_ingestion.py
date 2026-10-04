"""Timestamp-aware radar conversion; authorised live feed access is not bundled."""

from datetime import datetime, timezone
from math import isfinite


def reflectivity_to_rain(dbz):
    if not isfinite(dbz):
        raise ValueError("Reflectivity must be finite")
    return ((10 ** (dbz / 10)) / 200) ** (1 / 1.6)


def summarize_cells(cells, observed_at, now=None, max_age_minutes=15):
    now = now or datetime.now(timezone.utc)
    if observed_at.tzinfo is None:
        raise ValueError("Radar observation requires a timezone")
    age = (now - observed_at).total_seconds()
    if age < -60:
        raise ValueError("Radar observation cannot be in the future")
    if not cells:
        return {
            "status": "NO_DATA",
            "rain_mm_hr": None,
            "observed_at": observed_at.isoformat(),
        }
    if age > max_age_minutes * 60:
        return {
            "status": "STALE",
            "rain_mm_hr": None,
            "observed_at": observed_at.isoformat(),
        }
    return {
        "status": "OBSERVED_SAMPLE",
        "rain_mm_hr": max(reflectivity_to_rain(float(v)) for v in cells),
        "observed_at": observed_at.isoformat(),
        "method": "Marshall–Palmer Z=200R^1.6; local calibration required",
    }
