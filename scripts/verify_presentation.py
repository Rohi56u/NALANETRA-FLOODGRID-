"""Verify every submitted presentation asset without modifying it."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify():
    lines = (ROOT / "docs/PRESENTATION_SHA256.txt").read_text().splitlines()
    expected = {
        name: digest for digest, name in (line.split("  ", 1) for line in lines)
    }
    actual = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (ROOT / "docs/slides").iterdir()
        if p.is_file()
    }
    if actual != expected:
        raise RuntimeError("Presentation asset mismatch")
    return True


if __name__ == "__main__":
    verify()
    print("All 8 presentation assets are unchanged.")
