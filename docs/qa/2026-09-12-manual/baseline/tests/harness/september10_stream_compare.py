"""Summarize the real teleport lifecycle without inferring success from timing alone."""
import collections
import json
import re
import sys
from pathlib import Path

def point(value):
    return tuple(map(float, re.findall(r"-?\d+(?:\.\d+)?", value)))

def summarize(path):
    report = json.loads(path.read_text())
    events = [json.loads(line) for line in Path(str(path) + ".events.jsonl").read_text().splitlines()]
    # The final report can contain events after the last one-second log flush.
    # Merge those real records without changing the original trace files.
    by_serial = {event["serial"]: event for event in events}
    for event in report.get("streaming", {}).get("recent_events", []):
        by_serial[event["serial"]] = event
    events = [by_serial[serial] for serial in sorted(by_serial)]
    samples = [json.loads(line) for line in Path(str(path) + ".jsonl").read_text().splitlines()]
    starts = [event for event in events if event["event"] == "start"]
    completions = [event for event in events if event["event"] == "complete"]
    obsolete_ms = 0
    for a, b in zip(samples, samples[1:]):
        active = a["active"]
        if not active:
            continue
        x, _, z = point(a["position"])
        cx, cz = point(active["chunk"])
        if max(abs(cx - (x // 192)), abs(cz - (z // 192))) > 5:
            obsolete_ms += b["msec"] - a["msec"]
    return {
        "source": str(path), "status": report["status"],
        "startup_seconds": report["startup_msec"] / 1000,
        "visits": report["visits"],
        "lifecycle_events": len(events),
        "missing_event_serials": sum(b["serial"] - a["serial"] - 1 for a, b in zip(events, events[1:])),
        "sampled_obsolete_active_seconds": obsolete_ms / 1000,
        "cancellations": dict(collections.Counter(e.get("reason", "unknown") for e in events if e["event"] == "cancel")),
        "counts": report.get("streaming", {}).get("counts", {}),
        "slowest_jobs": sorted(completions, key=lambda e: e["job_msec"], reverse=True)[:10],
        "longest_queue_waits": sorted(starts, key=lambda e: e.get("queue_wait_msec", 0), reverse=True)[:10],
        "peak_static_memory_bytes": max(s["memory"] for s in samples),
        "final_cache": report.get("streaming", {}).get("field_cache", {}),
    }

if __name__ == "__main__":
    output = Path(sys.argv[1])
    results = [summarize(Path(name)) for name in sys.argv[2:]]
    output.write_text(json.dumps(results, indent=2) + "\n")
    for row in results:
        print(Path(row["source"]).name, "startup", row["startup_seconds"], "obsolete", row["sampled_obsolete_active_seconds"])
        for visit in row["visits"]:
            if "walk_meters" in visit:
                print(visit["index"], "ready", visit.get("ready_msec"), "meters", round(visit["walk_meters"], 3), "frozen", round(visit["walk_frozen_seconds"], 3))
