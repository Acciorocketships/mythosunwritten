"""Summarize a completed GUT log and compare named failures with consolidation."""
import argparse
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("log", type=Path)
parser.add_argument("--exit-code", type=int, required=True)
parser.add_argument("--snapshot", type=Path, required=True)
parser.add_argument("--output", type=Path, default=Path("docs/qa/2026-09-10-tactical/full-suite.json"))
args = parser.parse_args()
text = re.sub(r"\x1b\[[0-9;]*m", "", args.log.read_text())
assert "= Run Summary" in text, "The suite has not completed"
summary = text.rsplit("Totals\n------", 1)[1]
failures = {}
script = test = None
for line in text.splitlines():
    if line.startswith("res://tests/"):
        script = line.strip()
    match = re.match(r"\s*[*-] (test_\S+)", line)
    if match:
        test = match.group(1)
    if "[Failed]" in line and script and test:
        failures.setdefault(script, set()).add(test)
base = json.loads(Path("docs/qa/consolidation-tests-2026-09-10.json").read_text())
baseline = {(s, t) for s, tests in base["failing_tests"].items() for t in tests}
actual = {(s, t) for s, tests in failures.items() for t in tests}
report = {
    "base_commit": "f3203d96",
    "process_exit_code": args.exit_code,
    "source_note": "Full suite ran from a frozen feature copy. The subsequent physical-floor guard, live-source-uniform synchronization and return-to-centre orbit guard have their own final focused and GPU checks.",
    "failing_tests": {s: sorted(tests) for s, tests in sorted(failures.items())},
    "new_failing_tests": sorted(actual - baseline),
    "baseline_failures_not_observed": sorted(baseline - actual),
}
for key, label in (("scripts", "Scripts"), ("tests", "Tests"), ("passed", "Passing Tests"),
                   ("failed", "Failing Tests"), ("pending", "Risky/Pending")):
    match = re.search(rf"^{label}\s+(\d+)", summary, re.M)
    report[key] = int(match.group(1)) if match else 0
match = re.search(r"^Asserts\s+(\d+)(?:/(\d+))?", summary, re.M)
if match:
    report["passing_assertions"] = int(match.group(1))
    report["total_assertions"] = int(match.group(2) or match.group(1))
match = re.search(r"^Time\s+([\d.]+)s", summary, re.M)
report["elapsed_seconds"] = float(match.group(1))
report["frozen_source_sha256"] = {}
for path in [Path("characters/character.gd"), Path("characters/character.tscn"),
             Path("characters/animations/DirectionalAnimationTree.tres"),
             *sorted(Path("scripts/camera").glob("*")),
             *sorted(Path("scripts/controllers").glob("*.gd"))]:
    if path.is_file() and path.suffix != ".uid":
        report["frozen_source_sha256"][str(path)] = hashlib.sha256((args.snapshot / path).read_bytes()).hexdigest()
args.output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({k: v for k, v in report.items() if k not in ("frozen_source_sha256", "failing_tests")}))
