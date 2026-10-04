"""Inspect fixture terrain shape; a depression is not measured flood depth."""

import json
from pathlib import Path
import numpy as np


def inspect_terrain(path):
    source = json.loads(Path(path).read_text())
    grid = np.asarray(source["elevation_m"], dtype=float)
    if grid.ndim != 2 or not np.isfinite(grid).all():
        raise ValueError("DEM must be a finite two-dimensional grid")
    depressions = []
    for row in range(1, grid.shape[0] - 1):
        for col in range(1, grid.shape[1] - 1):
            neighbours = [
                grid[row - 1, col],
                grid[row + 1, col],
                grid[row, col - 1],
                grid[row, col + 1],
            ]
            delta = min(neighbours) - grid[row, col]
            if delta > 0:
                depressions.append(
                    {"row": row, "column": col, "local_depression_m": float(delta)}
                )
    return {
        "source": source["source"],
        "synthetic": source["synthetic"],
        "shape": list(grid.shape),
        "local_depressions": depressions,
        "flood_depth_estimate": None,
    }
