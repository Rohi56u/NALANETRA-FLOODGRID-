"""Original exact vector architecture and repository header; no generated facts."""

from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAVY, GREEN, ORANGE, BLUE, MUTED = "#102a43", "#147d64", "#d97827", "#217caa", "#597184"


def label(x, y, text, size=20, color=NAVY, weight=500):
    return f'<text x="{x}" y="{y}" font-family="DejaVu Sans,Arial,sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(text)}</text>'


def box(x, y, w, h, title, lines, color, fill):
    result = (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="{fill}" stroke="{color}" stroke-width="1.6"/>'
        + label(x + 20, y + 33, title, 20, color, 700)
    )
    for index, text in enumerate(lines):
        result += label(x + 20, y + 64 + index * 29, text, 16, MUTED)
    return result


def arrow(x1, y1, x2, y2, dashed=False, color=MUTED):
    return (
        f'<path d="M{x1},{y1} L{x2},{y2}" stroke="{color}" stroke-width="2.4" fill="none" marker-end="url(#arrow)"'
        + (' stroke-dasharray="7 6"' if dashed else "")
        + "/>"
    )


def build():
    out = ROOT / "docs/assets"
    out.mkdir(exist_ok=True)
    header = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 440"><rect width="1440" height="440" rx="24" fill="{NAVY}"/>'
        + label(65, 66, "NALANETRA FLOODGRID", 19, "#ddb568", 800)
        + label(65, 135, "From waterlogging reports", 44, "#ffffff", 800)
        + label(65, 194, "to accountable field response.", 44, "#ffffff", 800)
        + label(
            65,
            248,
            "Explainable triage · Shared workflow · Evidence-gated closure",
            22,
            "#bcd0df",
        )
    )
    steps = [
        "Report",
        "Officer review",
        "Priority / dispatch",
        "Field proof",
        "Officer closure",
    ]
    for index, title in enumerate(steps):
        x = 65 + index * 260
        header += (
            f'<rect x="{x}" y="300" width="236" height="60" rx="14" fill="#1b3a54" stroke="#47617a"/>'
            + label(x + 18, 337, title, 18, "#ffffff", 600)
        )
        if index < 4:
            header += f'<path d="M{x + 241},330 L{x + 255},330" stroke="#ddb568" stroke-width="2"/>'
    header += (
        label(
            65,
            407,
            "CONNECTED PROTOTYPE  /  REPRODUCIBLE FIXTURES  /  FIELD VALIDATION GATES",
            15,
            "#ddb568",
            600,
        )
        + "</svg>"
    )
    (out / "hero.svg").write_text(header)
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 1120"><defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="none" stroke="#597184" stroke-width="1.4"/></marker></defs><rect width="1600" height="1120" fill="#f6f9fb"/>'
    svg += label(60, 60, "NalaNetra system architecture", 34, NAVY, 800) + label(
        60,
        98,
        "Connected local workflow with explicit configuration and field-validation boundaries",
        18,
        MUTED,
    )
    for x, title in zip(
        [60, 450, 840, 1230],
        [
            "Citizen portal",
            "MCG officer portal",
            "Field response unit",
            "City overview",
        ],
    ):
        svg += box(
            x, 140, 310, 90, title, ["Authenticated role view"], GREEN, "#eff9f5"
        ) + arrow(x + 155, 230, x + 155, 278, color=GREEN)
    svg += box(
        60,
        282,
        1480,
        100,
        "Flutter / Dart · Material 3 · flutter_map",
        [
            "Hindi / English citizen reports · Officer queue / review · Crew missions / GPS captures"
        ],
        NAVY,
        "#ffffff",
    ) + arrow(800, 382, 800, 430, color=GREEN)
    svg += box(
        60,
        434,
        930,
        130,
        "FastAPI / Python · shared response workflow",
        [
            "Report → officer review → priority → dispatch → field proof → officer closure",
            "Revocable sessions · Retry identifiers · SLA ageing · Role-scoped records",
        ],
        GREEN,
        "#eff9f5",
    )
    svg += box(
        1030,
        434,
        510,
        130,
        "Photo screening / review cues",
        [
            "Actual photo-byte decoding · OpenCV",
            "Optional YOLO: evaluated local weights only",
        ],
        ORANGE,
        "#fff6ed",
    ) + arrow(1030, 499, 994, 499, color=ORANGE)
    for x in [285, 795, 1310]:
        svg += arrow(x, 564, x, 615)
    svg += box(
        60,
        620,
        450,
        168,
        "Response priority / risk modules",
        [
            "P = .30S + .20R + .15W + .15D + .10E + .10A",
            "Directed storage / Manning conveyance",
            "Timestamped radar and terrain modules",
        ],
        ORANGE,
        "#fff6ed",
    )
    svg += box(
        550,
        620,
        490,
        168,
        "Data / GIS / routing",
        [
            "PostgreSQL / PostGIS deployment schema",
            "SQLite local/test persistence adapter",
            "OSRM road alternatives + closure screening",
        ],
        BLUE,
        "#eef6fb",
    )
    svg += box(
        1080,
        620,
        460,
        168,
        "Evidence / notification workflow",
        [
            "Protected photos · GPS / capture time",
            "SHA-256 integrity · actor/action audit log",
            "Role-scoped updates · optional Firebase FCM",
        ],
        GREEN,
        "#eff9f5",
    )
    for x in [285, 795, 1310]:
        svg += arrow(x, 788, x, 852, True)
    svg += box(
        60,
        858,
        450,
        140,
        "Field validation gate",
        [
            "IMD access · surveyed DEM / drains",
            "Calibrated models · independent observations",
        ],
        ORANGE,
        "#ffffff",
    )
    svg += box(
        550,
        858,
        490,
        140,
        "Deployment configuration",
        [
            "PostGIS · road data / OSRM · HTTPS",
            "Operator access controls · backups / monitoring",
        ],
        BLUE,
        "#ffffff",
    )
    svg += box(
        1080,
        858,
        460,
        140,
        "Notification configuration",
        [
            "FCM credentials · registered device",
            "Provider acceptance ≠ confirmed delivery",
        ],
        GREEN,
        "#ffffff",
    )
    svg += (
        label(
            60,
            1050,
            "Solid links: connected local workflow. Dashed links: external configuration / validation work.",
            18,
            MUTED,
        )
        + label(
            60,
            1085,
            "P-Score prioritises response. Photo cues and route overlays are not accuracy or safety guarantees.",
            17,
            MUTED,
        )
        + "</svg>"
    )
    (out / "system_architecture.svg").write_text(svg)
    print("Rebuilt original repository header and architecture vectors.")


if __name__ == "__main__":
    build()
