"""Actual photo-byte decoding and review cues, without invented AI accuracy."""

import hashlib
import warnings
from functools import lru_cache
from io import BytesIO
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, UnidentifiedImageError


@lru_cache(maxsize=2)
def _model(path):
    from ultralytics import YOLO

    return YOLO(path)


def screen_photo(data, weights=""):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(data)) as image:
                if (
                    image.format not in {"JPEG", "PNG"}
                    or image.width * image.height > 16_000_000
                ):
                    raise ValueError("Use JPEG/PNG with at most 16 megapixels")
                fmt = image.format
                rgb = np.asarray(image.convert("RGB"))
    except (
        UnidentifiedImageError,
        OSError,
        Image.DecompressionBombWarning,
        Image.DecompressionBombError,
    ):
        raise ValueError("Photo bytes could not be decoded") from None
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    lower = hsv[hsv.shape[0] // 2 :]
    mask = cv2.inRange(lower, np.array([5, 35, 30]), np.array([35, 230, 230]))
    result = {
        "sha256": hashlib.sha256(data).hexdigest(),
        "pixel_hash": hashlib.sha256(
            str(rgb.shape).encode() + rgb.tobytes()
        ).hexdigest(),
        "media_type": "image/jpeg" if fmt == "JPEG" else "image/png",
        "water_colour_fraction": round(float(np.count_nonzero(mask) / mask.size), 4),
        "review_required": True,
        "depth_estimate": None,
        "confidence": None,
        "model_status": "NOT_CONFIGURED",
        "objects": [],
        "limitations": "Colour cues are not verified water depth, scene truth or automatic fraud rejection",
    }
    if weights:
        path = Path(weights)
        if not path.is_file():
            result["model_status"] = "WEIGHTS_UNAVAILABLE"
        else:
            try:
                model = _model(str(path.resolve()))
                prediction = model.predict(rgb, verbose=False)[0]
                result["objects"] = [
                    {
                        "label": model.names[int(box.cls[0])],
                        "uncalibrated_score": float(box.conf[0]),
                    }
                    for box in prediction.boxes
                ]
                result["model_status"] = "LOCAL_WEIGHTS"
                result["weights_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            except (ImportError, OSError, RuntimeError):
                result["model_status"] = "MODEL_UNAVAILABLE"
    return result
