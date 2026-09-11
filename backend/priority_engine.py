"""
NalaNetra FloodGrid - Algorithmic Priority Engine
Implements the Scientific Multi-Variable Priority Formula for Urban Flood Triage
Mandated by SIH 2026 Problem Statement 26085 (Drainage and Rainfall Coupling)
"""

from typing import Dict, Any
from dataclasses import dataclass

@dataclass
class IncidentMetrics:
    severity_level: str          # 'ankle', 'knee', 'waist', 'submerged'
    radar_rainfall_rate_mm_hr: float # Doppler radar nowcast precipitation (IMD feed)
    ward_criticality_index: float    # 0.0 to 1.0 based on population & traffic density
    drainage_pipe_capacity: float    # 0.0 (empty) to 1.0 (surcharged / backflow)
    is_emergency_route: bool         # True if near hospital, school, or arterial corridor
    sla_hours_unaddressed: float     # Hours since report creation without dispatch

# Normalized severity weights
SEVERITY_MAPPING: Dict[str, float] = {
    'ankle': 0.25,
    'knee': 0.50,
    'waist': 0.75,
    'submerged': 1.00
}

def calculate_priority_score(metrics: IncidentMetrics) -> Dict[str, Any]:
    """
    Computes Incident Priority P-Score (0 to 100) using the Multi-Variable Hydrological Formula:
    P = 0.30(S) + 0.20(R) + 0.15(W) + 0.15(D) + 0.10(E) + 0.10(A)

    Weights:
      S (0.30) - Visual Ground Severity Depth
      R (0.20) - Doppler Radar Rainfall Nowcast Intensity (normalized 0-100 mm/hr)
      W (0.15) - Ward Criticality Index (economic & residential exposure)
      D (0.15) - Hydraulic Pipe Surcharge (drain capacity stress)
      E (0.10) - Emergency Route Multiplier (Hospital/Arterial 1.5x weight)
      A (0.10) - SLA Aging & Incident Accumulation Factor
    """
    # 1. Ground Truth Severity (S)
    s_val = SEVERITY_MAPPING.get(metrics.severity_level.lower(), 0.25)

    # 2. Doppler Radar Nowcast (R): normalized against 80 mm/hr extreme monsoon threshold
    r_val = min(1.0, metrics.radar_rainfall_rate_mm_hr / 80.0)

    # 3. Ward Criticality (W): bounded [0.0, 1.0]
    w_val = max(0.0, min(1.0, metrics.ward_criticality_index))

    # 4. Drainage Hydraulic Surcharge (D): bounded [0.0, 1.0]
    d_val = max(0.0, min(1.0, metrics.drainage_pipe_capacity))

    # 5. Emergency Corridor Multiplier (E): 1.0 if emergency route, else 0.0
    e_val = 1.0 if metrics.is_emergency_route else 0.0

    # 6. SLA Aging Factor (A): Escalates linearly up to 6 hours max
    a_val = min(1.0, metrics.sla_hours_unaddressed / 6.0)

    # Core Formula Calculation
    raw_p = (
        0.30 * s_val +
        0.20 * r_val +
        0.15 * w_val +
        0.15 * d_val +
        0.10 * e_val +
        0.10 * a_val
    )

    # Apply 1.5x multiplier boost if arterial emergency route (capped at 1.0)
    if metrics.is_emergency_route:
        raw_p = min(1.0, raw_p * 1.5)

    priority_score = round(raw_p * 100.0, 1)

    # Triage Band Categorization
    if priority_score >= 80.0:
        band = "CRITICAL"
        action_sla_minutes = 30
    elif priority_score >= 60.0:
        band = "HIGH"
        action_sla_minutes = 60
    elif priority_score >= 40.0:
        band = "MODERATE"
        action_sla_minutes = 120
    else:
        band = "LOW"
        action_sla_minutes = 240

    # Dynamic Severity Upgrade Check:
    # If ground visual evidence indicates 'waist' or 'submerged' while radar was mild,
    # trigger immediate priority escalation to override blind macro forecast.
    override_triggered = False
    if metrics.severity_level.lower() in ('waist', 'submerged') and band in ('LOW', 'MODERATE'):
        band = "CRITICAL"
        override_triggered = True
        action_sla_minutes = 30

    return {
        "priority_score": priority_score,
        "band": band,
        "action_sla_minutes": action_sla_minutes,
        "dynamic_upgrade_override": override_triggered,
        "factor_breakdown": {
            "S_ground_truth": round(s_val, 2),
            "R_radar_nowcast": round(r_val, 2),
            "W_ward_criticality": round(w_val, 2),
            "D_pipe_surcharge": round(d_val, 2),
            "E_emergency_route": round(e_val, 2),
            "A_sla_aging": round(a_val, 2)
        }
    }
