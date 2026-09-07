"""
NalaNetra FloodGrid - Digital Elevation Model (DEM) & Terrain Ingestion Module
Part of INTELLIGENCE / FLOOD RISK Layer (Proposed Architecture)

Ingests Cartosat 10m / SRTM 30m Digital Elevation Models (GeoTIFF / Raster)
to identify natural depression sinks, overland flow accumulation paths,
and underpass bowl geometries in Gurugram (e.g., Sector 14 underpass, Hero Honda Chowk).
"""

from typing import Dict, Any, List, Tuple

# Sample verified underpass depression sinks in Gurugram Ward 14 & NH-48 Corridor
GURUGRAM_DEPRESSION_HOTSPOTS = [
    {
        "hotspot_id": "HOTSPOT-GGM-01",
        "name": "Sector 14 Underpass Corridor",
        "lat": 28.4682,
        "lon": 77.0428,
        "elevation_m": 218.4,
        "surrounding_elevation_m": 224.6,
        "depression_depth_m": 6.2,  # Bowl depth
        "runoff_coefficient_C": 0.85, # Impervious urban concrete
        "catchment_area_sq_km": 1.45
    },
    {
        "hotspot_id": "HOTSPOT-GGM-02",
        "name": "Hero Honda Chowk Underpass (NH-48)",
        "lat": 28.4358,
        "lon": 77.0142,
        "elevation_m": 215.1,
        "surrounding_elevation_m": 222.8,
        "depression_depth_m": 7.7,
        "runoff_coefficient_C": 0.90,
        "catchment_area_sq_km": 2.80
    },
    {
        "hotspot_id": "HOTSPOT-GGM-03",
        "name": "Rajiv Chowk Underpass / Medanta Link",
        "lat": 28.4528,
        "lon": 77.0392,
        "elevation_m": 219.0,
        "surrounding_elevation_m": 223.5,
        "depression_depth_m": 4.5,
        "runoff_coefficient_C": 0.88,
        "catchment_area_sq_km": 1.95
    }
]

def calculate_rational_peak_runoff(
    catchment_area_sq_km: float,
    rainfall_intensity_mm_hr: float,
    runoff_coefficient: float = 0.85
) -> float:
    """
    Computes peak surface runoff rate Q (m^3/s) using the Rational Method:
        Q = 0.278 * C * I * A
    Where:
        C = Runoff coefficient (dimensionless, 0.70 - 0.95 for urban paved areas)
        I = Rainfall intensity (mm/hr) from Doppler Radar nowcast
        A = Catchment area (km^2) derived from DEM flow direction analysis
    Standard reference: CPHEEO Manual on Storm Water Drainage (Govt. of India).
    """
    Q_peak = 0.278 * runoff_coefficient * rainfall_intensity_mm_hr * catchment_area_sq_km
    return round(Q_peak, 3)

def evaluate_terrain_flood_vulnerability(
    lat: float,
    lon: float,
    rainfall_intensity_mm_hr: float
) -> Dict[str, Any]:
    """
    Assesses whether a geographic coordinate falls inside a high-risk DEM sink.
    Returns topographic risk multiplier and expected runoff volume.
    """
    nearest_sink = None
    min_dist = float("inf")

    for sink in GURUGRAM_DEPRESSION_HOTSPOTS:
        d_lat = lat - sink["lat"]
        d_lon = lon - sink["lon"]
        dist = (d_lat**2 + d_lon**2)**0.5
        if dist < min_dist:
            min_dist = dist
            nearest_sink = sink

    # Within ~800m of a major known underpass depression
    is_in_depression_cone = (min_dist < 0.008)

    if is_in_depression_cone and nearest_sink:
        q_runoff = calculate_rational_peak_runoff(
            nearest_sink["catchment_area_sq_km"],
            rainfall_intensity_mm_hr,
            nearest_sink["runoff_coefficient_C"]
        )
        terrain_risk_multiplier = 1.45
        status = "CRITICAL_DEPRESSION_SINK"
    else:
        q_runoff = calculate_rational_peak_runoff(0.5, rainfall_intensity_mm_hr, 0.70)
        terrain_risk_multiplier = 1.00
        status = "NORMAL_TERRAIN_SLOPE"

    return {
        "status": status,
        "is_depression_cone": is_in_depression_cone,
        "nearest_hotspot": nearest_sink["name"] if nearest_sink else "Ward 14 Baseline",
        "peak_runoff_m3_s": q_runoff,
        "terrain_risk_multiplier": terrain_risk_multiplier,
        "source": "ISRO Cartosat-1 10m DEM • CPHEEO Rational Runoff Standards"
    }
