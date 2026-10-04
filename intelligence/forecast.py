"""Committed three-hour fixture experiment, not a live city forecast."""

import csv
import json
from pathlib import Path
from .dem_processor import inspect_terrain
from .drainage_graph import simulate

DATA = Path(__file__).resolve().parents[1] / "data/demo"


def run_demo():
    network = json.loads((DATA / "drainage_network.json").read_text())
    with (DATA / "rainfall.csv").open() as stream:
        rain = [float(r["rain_mm_hr"]) for r in csv.DictReader(stream)]
    rows = simulate(network, rain)
    return {
        "status": "SYNTHETIC_FIXTURE",
        "horizon_minutes": len(rows) * 5,
        "source": "Team-authored deterministic inputs; not IMD or municipal observations",
        "model": "Directed lumped storage / Manning-limited conveyance",
        "terrain": inspect_terrain(DATA / "terrain.json"),
        "timeline": rows,
        "clear_drains_timeline": simulate(network, rain, blockage_override=0),
        "max_balance_error_m3": max(abs(r["balance_error_m3"]) for r in rows),
        "limitations": [
            "No local calibration",
            "No backflow or two-dimensional flood spread",
            "No observed ground truth",
            "No live radar feed",
        ],
    }
