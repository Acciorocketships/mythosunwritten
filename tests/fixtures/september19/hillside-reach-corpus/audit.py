"""Compare completed detached routing surveys; not an in-game acceptance gate."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs/qa/2026-09-19-manual/111-hillside-reach-corpus"
summary = {"candidate_cells": 147, "sources": 0, "stations": 0, "seeds": []}
for seed in (2697992464, 1, 9):
    before = json.loads((OUT / f"{seed}.json").read_text())
    after = json.loads((OUT / f"{seed}-terminal.json").read_text())
    reverse = json.loads((OUT / f"{seed}-terminal-reverse.json").read_text())
    assert after["routes"] == reverse["routes"], f"Query-order divergence: {seed}"
    assert not after["failures"] and not reverse["failures"]
    original = {row["source"]: row for row in before["routes"]}
    rows = after["routes"]
    assert all(len(row["station_hash"]) == 64 for row in rows)
    assert all(row["termination"] == "native_terminal" and row["rises"] == 0 for row in rows)
    summary["sources"] += len(rows)
    summary["stations"] += sum(row["nodes"] for row in rows)
    summary["seeds"].append({
        "seed": seed, "sources": len(rows), "before_counts": before["counts"],
        "after_counts": after["counts"], "query_order_equal": True,
        "changed_sources": [row["source"] for row in rows
                            if original[row["source"]] != {k: v for k, v in row.items() if k != "station_hash"}],
        "max_join_drop": max(row["max_drop"] for row in rows),
        "max_radius": max(row["max_radius"] for row in rows),
        "routes_revisiting_a_channel": sum(row["repeated_owners"] > 0 for row in rows),
    })

previous = json.loads((ROOT / "docs/qa/2026-09-19-manual/110-hillside-retained-network/source-hashes.json").read_text())
for name, expected in previous.items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, f"Pass 110 changed: {name}"
summary["production_water_and_pass110_sources_unchanged"] = True
(OUT / "audit.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
