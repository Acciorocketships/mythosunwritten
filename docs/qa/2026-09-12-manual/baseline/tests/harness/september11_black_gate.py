"""Judge completed marked GPU replays; a fresh corrupt frame fails the gate."""
import argparse
import json
from pathlib import Path


def judge(rows, minimum_frames=1, first_tick=0):
    # The replay emits one initial frame at tick zero, then one per route tick.
    # Validate the marker independently of rounded camera-string lookup.
    stale = [r["frame"] for r in rows
             if r.get("rendered_tick") != first_tick + max(0, r["frame"] - 1)]
    corrupt = [r["frame"] for r in rows
               if r.get("invalid_rgb", r["invalid"]) > 0
               or r["black"] / r["samples"] > .02]
    counts_valid = all(r["samples"] == 9216 for r in rows)
    passed = len(rows) >= minimum_frames and counts_valid and not stale and not corrupt
    return {"passed": passed, "frames": len(rows), "minimum_frames": minimum_frames,
            "sample_counts_valid": counts_valid, "stale_or_missing_markers": stale,
            "corrupt_frames": corrupt,
            "max_black_samples": max((r["black"] for r in rows), default=0),
            "max_invalid_rgb_samples": max((r.get("invalid_rgb", r["invalid"])
                                             for r in rows), default=0)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--minimum-frames", type=int, default=1)
    parser.add_argument("--first-tick", type=int, default=0)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = judge(json.loads(args.input.read_text()), args.minimum_frames, args.first_tick)
    rendered = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n")
    print(rendered)
    raise SystemExit(0 if result["passed"] else 1)
