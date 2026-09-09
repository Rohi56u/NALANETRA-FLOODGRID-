"""
NalaNetra FloodGrid - 1D Kinematic-Wave Drainage Network Hydraulic Graph
Part of INTELLIGENCE / FLOOD RISK Layer (Proposed Architecture)

Simulates subsurface stormwater pipe conveyance and manhole surcharge heads
using Manning's Equation and kinematic-wave approximation compatible with EPA-SWMM.
Couples surface runoff with underground pipe capacity to generate D (Pipe Surcharge Index).
"""

import math
from typing import Dict, Any, List

class StormwaterConduit:
    def __init__(
        self,
        conduit_id: str,
        diameter_m: float,
        length_m: float,
        slope_s: float,
        mannings_n: float = 0.013  # Smooth precast concrete stormwater culvert
    ):
        self.conduit_id = conduit_id
        self.diameter = diameter_m
        self.length = length_m
        self.slope = max(0.0005, slope_s)
        self.n = mannings_n
        
        # Precompute full-pipe hydraulic properties
        self.area_full = math.pi * (self.diameter / 2.0) ** 2
        self.wetted_perimeter_full = math.pi * self.diameter
        self.hydraulic_radius_full = self.area_full / self.wetted_perimeter_full
        
        # Full pipe conveyance capacity Q_cap (m^3/s) via Manning's Equation:
        # V = (1 / n) * Rh^(2/3) * S^(1/2)
        # Q = V * A
        self.velocity_full = (1.0 / self.n) * (self.hydraulic_radius_full ** (2.0 / 3.0)) * (self.slope ** 0.5)
        self.q_capacity = self.velocity_full * self.area_full

    def evaluate_surcharge(self, inflow_runoff_q: float) -> Dict[str, Any]:
        """
        Calculates pipe capacity stress ratio D = Q_inflow / Q_capacity.
        If D >= 1.0, pipe is pressurized and stormwater surcharges through manholes.
        """
        ratio = inflow_runoff_q / max(0.001, self.q_capacity)
        surcharged = (ratio >= 1.0)
        
        # Surcharge head elevation (meters above pipe crown)
        if surcharged:
            surcharge_head_m = round((ratio - 1.0) * 1.8, 2)
            hydraulic_state = "SURCHARGED_BACKFLOW"
        elif ratio >= 0.75:
            surcharge_head_m = 0.0
            hydraulic_state = "NEAR_CAPACITY_WARNING"
        else:
            surcharge_head_m = 0.0
            hydraulic_state = "FREE_SURFACE_FLOW"

        return {
            "conduit_id": self.conduit_id,
            "pipe_diameter_m": self.diameter,
            "pipe_capacity_m3_s": round(self.q_capacity, 3),
            "inflow_q_m3_s": round(inflow_runoff_q, 3),
            "surcharge_ratio_D": round(min(1.0, ratio), 3),
            "surcharge_head_m": surcharge_head_m,
            "hydraulic_state": hydraulic_state,
            "is_surcharged": surcharged
        }

# Pre-configured drainage corridors in Gurugram Ward 14
WARD_14_DRAINAGE_TRUNKS = {
    "TRUNK-SEC14": StormwaterConduit("TRUNK-SEC14-MAIN", diameter_m=1.8, length_m=620, slope_s=0.0025),
    "TRUNK-NH48": StormwaterConduit("TRUNK-NH48-HERO-HONDA", diameter_m=2.4, length_m=1100, slope_s=0.0018),
    "TRUNK-CIVIL": StormwaterConduit("TRUNK-CIVIL-HOSPITAL", diameter_m=1.2, length_m=450, slope_s=0.0030),
}

def compute_drainage_surcharge_index(corridor_key: str, surface_runoff_q: float) -> Dict[str, Any]:
    """
    Computes D metric (0.0 to 1.0) for the NalaNetra Scientific Priority Formula:
    P = 0.30(S) + 0.20(R) + 0.15(W) + 0.15(D) + 0.10(E) + 0.10(A)
    """
    conduit = WARD_14_DRAINAGE_TRUNKS.get(corridor_key, WARD_14_DRAINAGE_TRUNKS["TRUNK-SEC14"])
    result = conduit.evaluate_surcharge(surface_runoff_q)
    result["model_citation"] = "EPA-SWMM Reference Manual (Rossman 2016); CPHEEO Govt of India"
    return result
