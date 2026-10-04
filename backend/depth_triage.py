"""Depth tags are citizen claims until reviewed; photo bytes supply review cues."""

from intelligence.yolo_photo_screening import screen_photo
from .priority_engine import SEVERITY_MAPPING


def triage_depth_tag(tag):
    tag = tag.lower()
    if tag not in SEVERITY_MAPPING:
        raise ValueError("Unknown depth tag")
    return {
        "depth_tag": tag,
        "severity": SEVERITY_MAPPING[tag],
        "review_required": True,
    }


__all__ = ["screen_photo", "triage_depth_tag"]
