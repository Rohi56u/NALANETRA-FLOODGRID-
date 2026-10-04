"""Directed lumped storage with Manning-limited conveyance and explicit water balance."""

from math import isfinite, pi, sqrt


def manning_capacity(diameter_m, slope, roughness, blockage=0):
    if (
        not all(isfinite(v) for v in [diameter_m, slope, roughness, blockage])
        or diameter_m <= 0
        or slope < 0
        or roughness <= 0
        or not 0 <= blockage <= 1
    ):
        raise ValueError("Invalid conduit parameters")
    return (
        pi
        * diameter_m**2
        / 4
        * (diameter_m / 4) ** (2 / 3)
        * sqrt(slope)
        / roughness
        * (1 - blockage)
    )


def simulate(network, rainfall_mm_hr, step_seconds=300, blockage_override=None):
    if not isfinite(step_seconds) or step_seconds <= 0:
        raise ValueError("Time step must be positive and finite")
    nodes = {n["id"]: n for n in network["nodes"]}
    if not nodes or len(nodes) != len(network["nodes"]):
        raise ValueError("Supply uniquely named drainage nodes")
    for node in nodes.values():
        values = [
            node["catchment_m2"],
            node["storage_area_m2"],
            node["runoff_coefficient"],
        ]
        if (
            not all(isfinite(v) for v in values)
            or values[0] < 0
            or values[1] <= 0
            or not 0 <= values[2] <= 1
        ):
            raise ValueError("Invalid catchment/storage parameters")
    for edge in network["edges"]:
        if (
            edge["from"] not in nodes
            or edge["to"] is not None
            and edge["to"] not in nodes
        ):
            raise ValueError("Unknown drainage node")
    volume = {key: 0.0 for key in nodes}
    total_in, total_out, rows = 0.0, 0.0, []
    for index, intensity in enumerate(rainfall_mm_hr):
        if not isfinite(intensity) or intensity < 0:
            raise ValueError("Rainfall must be non-negative and finite")
        incoming = {
            key: intensity
            / 1000
            / 3600
            * n["catchment_m2"]
            * n["runoff_coefficient"]
            * step_seconds
            for key, n in nodes.items()
        }
        for key in volume:
            volume[key] += incoming[key]
        total_in += sum(incoming.values())
        remaining, delta, outflow = dict(volume), {key: 0.0 for key in nodes}, 0.0
        # Simultaneous transfers: downstream inflows can leave on the next step.
        for edge in network["edges"]:
            blockage = (
                edge["blockage"] if blockage_override is None else blockage_override
            )
            capacity = manning_capacity(
                edge["diameter_m"], edge["slope"], edge["roughness"], blockage
            )
            transfer = min(remaining[edge["from"]], capacity * step_seconds)
            remaining[edge["from"]] -= transfer
            delta[edge["from"]] -= transfer
            if edge["to"] is None:
                outflow += transfer
            else:
                delta[edge["to"]] += transfer
        for key in volume:
            volume[key] += delta[key]
        total_out += outflow
        rows.append(
            {
                "minute": (index + 1) * step_seconds / 60,
                "rain_mm_hr": intensity,
                "storage_m3": dict(volume),
                "depth_m": {
                    key: volume[key] / nodes[key]["storage_area_m2"] for key in nodes
                },
                "cumulative_inflow_m3": total_in,
                "cumulative_outflow_m3": total_out,
                "balance_error_m3": total_in - total_out - sum(volume.values()),
            }
        )
    return rows
