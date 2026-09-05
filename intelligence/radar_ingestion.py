"""
NalaNetra FloodGrid - IMD Doppler Weather Radar (DWR) Ingestion Engine
Part of INTELLIGENCE / FLOOD RISK Layer (Proposed Architecture)

Converts precipitation reflectivity (Z in dBZ) to quantitative rain rate (R in mm/hr)
using the Marshall-Palmer convective calibration formula:
    Z = a * R^b  =>  Z = 200 * R^1.6
Grounded in peer-reviewed radar meteorology (Chandrasekar & Bringi, IMD Mausam).
"""

import math
from typing import Dict, Any, List, Tuple

# Marshall-Palmer standard tropical/monsoon convective constants
MARSHALL_PALMER_A = 200.0
MARSHALL_PALMER_B = 1.6

# IMD Aya Nagar & Palam Radar specifications
RADAR_COORDINATES = {
    "Aya_Nagar_DWR": (28.4722, 77.1264),
    "Palam_DWR": (28.5833, 77.0833),
}

def dbz_to_rain_rate(dbz: float) -> float:
    """
    Converts radar reflectivity factor dBZ to linear rain rate R (mm/hr).
    dBZ = 10 * log10(Z)
    Z = 10^(dBZ / 10)
    R = (Z / a)^(1 / b)
    """
    if dbz <= 0:
        return 0.0
    
    # Cap extreme hail contamination at 65 dBZ
    dbz_clamped = min(65.0, max(0.0, dbz))
    z_linear = 10.0 ** (dbz_clamped / 10.0)
    
    rain_rate = (z_linear / MARSHALL_PALMER_A) ** (1.0 / MARSHALL_PALMER_B)
    return round(rain_rate, 2)

def extract_ward_nowcast_intensity(
    ward_bounds: Tuple[float, float, float, float], # min_lat, min_lon, max_lat, max_lon
    radar_radial_grid: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """
    Aggregates sub-kilometer radar reflectivity cells over Gurugram Ward 14
    to provide the normalized rainfall rate R for the NalaNetra P-Score Engine.
    """
    min_lat, min_lon, max_lat, max_lon = ward_bounds
    matching_rates = []

    for cell in radar_radial_grid:
        lat = cell.get("lat", 0.0)
        lon = cell.get("lon", 0.0)
        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
            dbz = cell.get("dbz", 0.0)
            rate = dbz_to_rain_rate(dbz)
            matching_rates.append(rate)

    if not matching_rates:
        # Default baseline if radar feed is clear or zero echo
        mean_rate = 0.0
        peak_rate = 0.0
    else:
        mean_rate = sum(matching_rates) / len(matching_rates)
        peak_rate = max(matching_rates)

    # Classify nowcast severity band
    if peak_rate >= 50.0:
        alert = "EXTREME_CLOUD_BURST"
    elif peak_rate >= 30.0:
        alert = "HEAVY_MONSOON_DOWNPOUR"
    elif peak_rate >= 15.0:
        alert = "MODERATE_WATERLOGGING_RISK"
    else:
        alert = "NORMAL_CLEAR"

    return {
        "status": "RADAR_NOWCAST_SYNTHESIZED",
        "station": "IMD Aya Nagar / Palam S-Band DWR",
        "mean_rain_rate_mm_hr": round(mean_rate, 2),
        "peak_rain_rate_mm_hr": round(peak_rate, 2),
        "cells_sampled": len(matching_rates),
        "nowcast_alert_level": alert,
        "citation": "Marshall & Palmer (1948); Chandrasekar & Bringi (2001); IMD Mausam Standards"
    }
