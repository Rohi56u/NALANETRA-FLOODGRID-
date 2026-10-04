"""Calculate charts and CSV from committed synthetic fixtures, without field impact claims."""

import csv
import json
from pathlib import Path
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from intelligence.forecast import run_demo
from backend.priority_engine import score_factors

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/assets"


def charts():
    OUT.mkdir(exist_ok=True)
    result = run_demo()
    rows = result["timeline"]
    clear = result["clear_drains_timeline"]
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 12,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "text.color": "#102a43",
            "axes.labelcolor": "#597184",
            "xtick.color": "#597184",
            "ytick.color": "#597184",
        }
    )
    fig, axes = plt.subplots(
        1, 2, figsize=(15, 6), gridspec_kw={"width_ratios": [1, 1.35]}
    )
    fig.patch.set_facecolor("#f6f9fb")
    minutes = [r["minute"] for r in rows]
    axes[0].bar(minutes, [r["rain_mm_hr"] for r in rows], width=4.5, color="#217caa")
    axes[0].set(
        xlabel="Scenario time (minutes)",
        ylabel="Rainfall input (mm/h)",
        title="01  ·  A committed rain sequence",
        ylim=(0, 80),
        xticks=[0, 30, 60, 90, 120, 150, 180],
    )
    axes[1].plot(
        minutes,
        [r["depth_m"]["N1"] for r in rows],
        color="#d97827",
        lw=3,
        label="Fixture blockage · N1",
    )
    axes[1].plot(
        minutes,
        [r["depth_m"]["N1"] for r in clear],
        color="#147d64",
        lw=3,
        label="Clear-drain comparison · N1",
    )
    axes[1].set(
        xlabel="Scenario time (minutes)",
        ylabel="Storage-equivalent depth at N1 (m)",
        title="02  ·  Same rain, different conveyance",
        xticks=[0, 30, 60, 90, 120, 150, 180],
    )
    axes[1].legend(loc="upper left", frameon=False)
    fig.suptitle(
        "The drainage experiment is inspectable",
        x=0.06,
        ha="left",
        fontsize=23,
        fontweight="bold",
    )
    fig.text(
        0.06,
        0.86,
        "Synthetic inputs · 3 connected storage nodes · Manning-limited flow · 180 minutes",
        color="#597184",
        fontsize=12,
    )
    fig.text(
        0.06,
        0.06,
        "Fixture results are not surveyed street flood depth, forecast accuracy or measured municipal impact.",
        color="#597184",
        fontsize=11,
    )
    fig.subplots_adjust(left=0.07, right=0.97, bottom=0.2, top=0.77, wspace=0.35)
    fig.savefig(OUT / "risk_experiment.png", dpi=160)
    plt.close(fig)
    factors = {"S": 0.5, "R": 0.5, "W": 0.5, "D": 0.5, "E": 1, "A": 0}
    score = score_factors(factors)
    fig, axis = plt.subplots(figsize=(13, 5))
    fig.patch.set_facecolor("#f6f9fb")
    values = list(score["weighted_contributions"].values())
    bars = axis.bar(
        list(factors),
        values,
        color=["#d97827", "#217caa", "#217caa", "#217caa", "#147d64", "#597184"],
        width=0.6,
    )
    axis.bar_label(bars, labels=[f"{v:g} points" for v in values], padding=6)
    axis.set_ylim(0, 20)
    axis.set_ylabel("Contribution to P-Score / 100")
    fig.suptitle(
        "Six factors. One explained response priority.",
        x=0.08,
        ha="left",
        fontsize=23,
        fontweight="bold",
    )
    axis.set_title(
        "Illustrative fixture: S/R/W/D = 0.5 · E = 1 · A = 0 → P = 50/100",
        loc="left",
        fontsize=12,
        pad=18,
    )
    fig.text(
        0.08,
        0.06,
        "No hidden emergency multiplier. Response-band escalation is a separate, exposed policy.",
        fontsize=11,
        color="#597184",
    )
    fig.subplots_adjust(left=0.08, right=0.97, bottom=0.2, top=0.72)
    fig.savefig(OUT / "priority_breakdown.png", dpi=160)
    plt.close(fig)
    with (ROOT / "data/demo/model_results.csv").open("w") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "minute",
                "rain_mm_hr",
                "blocked_N1_depth_m",
                "clear_N1_depth_m",
                "cumulative_inflow_m3",
                "cumulative_outflow_m3",
                "balance_error_m3",
            ],
        )
        writer.writeheader()
        for a, b in zip(rows, clear):
            writer.writerow(
                {
                    "minute": a["minute"],
                    "rain_mm_hr": a["rain_mm_hr"],
                    "blocked_N1_depth_m": a["depth_m"]["N1"],
                    "clear_N1_depth_m": b["depth_m"]["N1"],
                    "cumulative_inflow_m3": a["cumulative_inflow_m3"],
                    "cumulative_outflow_m3": a["cumulative_outflow_m3"],
                    "balance_error_m3": a["balance_error_m3"],
                }
            )
    summary = {
        "source": "Calculated from committed synthetic fixtures",
        "horizon_minutes": result["horizon_minutes"],
        "maximum_balance_error_m3": result["max_balance_error_m3"],
        "blocked_peak_N1_depth_m": max(r["depth_m"]["N1"] for r in rows),
        "clear_peak_N1_depth_m": max(r["depth_m"]["N1"] for r in clear),
        "illustrative_priority": score,
        "limitations": result["limitations"],
    }
    (ROOT / "data/demo/model_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n"
    )
    print("Rebuilt two figures and calculated fixture CSV/JSON.")


if __name__ == "__main__":
    charts()
