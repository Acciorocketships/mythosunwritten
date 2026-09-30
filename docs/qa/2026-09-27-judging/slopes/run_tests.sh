#!/bin/bash
# Runs each listed GUT file headless and prints one summary line per file.
# usage: run_tests.sh OUTDIR test_a test_b ...
cd "$(dirname "$0")/../../../.."
out=$1; shift
mkdir -p "$out"
for t in "$@"; do
  /Applications/Godot.app/Contents/MacOS/Godot -d --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://tests/$t.gd -gexit > "$out/$t.log" 2>&1
  tests=$(grep -E "^Tests " "$out/$t.log" | tail -1 | awk '{print $NF}')
  pass=$(grep -E "^Passing Tests" "$out/$t.log" | tail -1 | awk '{print $NF}')
  fail=$(grep -E "^Failing Tests" "$out/$t.log" | tail -1 | awk '{print $NF}')
  err=$(grep -c "SCRIPT ERROR" "$out/$t.log")
  echo "$t tests=${tests:-?} pass=${pass:-?} fail=${fail:-0} script_errors=$err"
done
