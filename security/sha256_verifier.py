"""SHA-256 verifies stored bytes; it does not establish scene truth or authorise closure."""

import hashlib
import hmac
from pathlib import Path


def verify_stored_file(path, expected):
    try:
        return hmac.compare_digest(
            hashlib.sha256(Path(path).read_bytes()).hexdigest(), expected
        )
    except OSError:
        return False
