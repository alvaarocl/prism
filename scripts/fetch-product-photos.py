#!/usr/bin/env python3
"""Fetch optional manufacturer reference images at build time, never at runtime."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "assets/product-photos.json").read_text())
cache = Path.home() / "Library/Caches/prism-product-photos"
destination = Path(sys.argv[1])
cache.mkdir(parents=True, exist_ok=True)
destination.mkdir(parents=True, exist_ok=True)
if os.environ.get("PRISM_PRODUCT_PHOTOS", "1") == "0":
    print("Product photos disabled; the interface uses system icons.")
    sys.exit(0)
for photo in manifest:
    local = cache / photo["file"]
    if not local.exists():
        temporary = local.with_suffix(local.suffix + ".download")
        result = subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                                 "--max-time", "15", "--user-agent", "Mozilla/5.0",
                                 photo["url"], "--output", str(temporary)])
        if result.returncode != 0 or not temporary.exists() or temporary.stat().st_size < 1000:
            temporary.unlink(missing_ok=True)
            print("Photo unavailable, keeping icon:", photo["model"])
            continue
        temporary.replace(local)
    (destination / photo["file"]).write_bytes(local.read_bytes())
(destination / "sources.json").write_text(json.dumps(manifest, indent=2))
