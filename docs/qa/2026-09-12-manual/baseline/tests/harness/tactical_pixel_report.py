"""Compare deterministic tactical captures; run with Pillow and NumPy available."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops

parser = argparse.ArgumentParser()
parser.add_argument("--renders", type=Path, default=Path(".artifacts/tactical"))
parser.add_argument("--report", type=Path, default=Path("docs/qa/2026-09-10-tactical/pixel-checks.json"))
args = parser.parse_args()
original = Image.open(args.renders / "bubble_before.png").convert("RGB")
results = {}
for name in ("bubble_zero_fade", "bubble_restored", "bubble_after"):
    current = Image.open(args.renders / f"{name}.png").convert("RGB")
    delta = np.abs(np.asarray(original).astype(int) - np.asarray(current).astype(int))
    results[name] = {
        "changed_pixels": int(np.count_nonzero(np.any(delta, axis=2))),
        "maximum_channel_difference": int(delta.max()),
    }
after = Image.open(args.renders / "bubble_after.png").convert("RGB")
for name, rect in (
    ("far_batch_object", (1000, 415, 1180, 620)),
    ("floor_left", (0, 300, 300, 800)),
):
    results[name] = {"changed_bounds": ImageChops.difference(original.crop(rect), after.crop(rect)).getbbox()}
assert results["bubble_zero_fade"]["maximum_channel_difference"] <= 2
assert results["bubble_restored"]["changed_pixels"] == 0
assert results["far_batch_object"]["changed_bounds"] is None
assert results["floor_left"]["changed_bounds"] is None
args.report.write_text(json.dumps(results, indent=2) + "\n")
frames = [Image.open(path).convert("RGB") for path in sorted(args.renders.glob("gaits_*.png"))]
if frames:
    frames[0].save(args.renders / "directional-gaits.gif", save_all=True,
                   append_images=frames[1:], duration=33, loop=0)
print(json.dumps(results))
