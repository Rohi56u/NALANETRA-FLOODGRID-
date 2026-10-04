"""Six-factor response triage heuristic; weights require municipal calibration."""

from dataclasses import dataclass
from math import isfinite

SEVERITY_MAPPING = {
    "sidewalk": 0.125,
    "ankle": 0.25,
    "knee": 0.5,
    "waist": 0.75,
    "submerged": 1.0,
}
WEIGHTS = {"S": 0.30, "R": 0.20, "W": 0.15, "D": 0.15, "E": 0.10, "A": 0.10}


@dataclass
class IncidentMetrics:
    severity_level: str
    radar_rainfall_rate_mm_hr: float
    ward_criticality_index: float
    drainage_pipe_capacity: float  # Legacy name: interpreted as blockage/capacity loss.
    is_emergency_route: bool
    sla_hours_unaddressed: float


def score_factors(factors, severity=None):
    values = {}
    for key in WEIGHTS:
        value = float(factors.get(key, 0))
        if not isfinite(value):
            raise ValueError("Priority factors must be finite")
        values[key] = min(1, max(0, value))
    contributions = {
        key: round(100 * WEIGHTS[key] * value, 6) for key, value in values.items()
    }
    score = round(sum(contributions.values()), 1)
    band, sla = (
        ("CRITICAL", 30)
        if score >= 80
        else ("HIGH", 60)
        if score >= 60
        else ("MODERATE", 120)
        if score >= 40
        else ("LOW", 240)
    )
    override = severity in {"waist", "submerged"} and band in {"LOW", "MODERATE"}
    if override:
        band, sla = "CRITICAL", 30
    return {
        "priority_score": score,
        "band": band,
        "action_sla_minutes": sla,
        "factor_breakdown": values,
        "weighted_contributions": contributions,
        "dynamic_upgrade_override": override,
        "policy_note": "Deep-water policy elevates response band; weighted score is unchanged"
        if override
        else "No hidden score multiplier",
    }


def calculate_priority_score(metrics):
    if metrics.severity_level.lower() not in SEVERITY_MAPPING:
        raise ValueError("Unknown depth tag")
    return score_factors(
        {
            "S": SEVERITY_MAPPING[metrics.severity_level.lower()],
            "R": metrics.radar_rainfall_rate_mm_hr / 80,
            "W": metrics.ward_criticality_index,
            "D": metrics.drainage_pipe_capacity,
            "E": float(metrics.is_emergency_route),
            "A": metrics.sla_hours_unaddressed / 6,
        },
        metrics.severity_level.lower(),
    )
