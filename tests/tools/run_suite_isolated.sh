#!/bin/zsh
# Run every tests/test_*.gd file in its own Godot process (GUT, headless) and
# write one summary line per file. Isolated runs avoid the full-suite
# truncation seen around the heightfield tests. At most PAR processes run at
# once (tracked by PID; `jobs` cannot be counted inside $(...)), and a new one
# starts only while the system reports at least MIN_FREE_PCT percent free
# memory, so parallel runs cannot push a 16 GB machine into swap.
# usage: tests/tools/run_suite_isolated.sh <outfile> [parallelism] [glob] [repo]
set -u
repo=${4:-${0:A:h:h:h}}
out=$1
par=${2:-3}
glob=${3:-tests/test_*.gd}
min_free=${MIN_FREE_PCT:-35}
godot=/Applications/Godot.app/Contents/MacOS/Godot
: > "$out"
cd "$repo"
free_pct() {
	memory_pressure | awk -F': ' '/free percentage/ {gsub("%","",$2); print $2}'
}
run_one() {
	local f=$1
	local r
	r=$("$godot" --headless --path "$repo" -s addons/gut/gut_cmdln.gd -gtest=res://$f -gexit 2>&1)
	local t=$(print -r -- "$r" | grep -E '^Tests ' | grep -oE '[0-9]+' | head -1)
	local p=$(print -r -- "$r" | grep -E '^Passing Tests' | grep -oE '[0-9]+' | head -1)
	local fl=$(print -r -- "$r" | grep -E '^Failing Tests' | grep -oE '[0-9]+' | head -1)
	local e=$(print -r -- "$r" | grep -c 'SCRIPT ERROR')
	print -r -- "$f tests=${t:-?} pass=${p:-?} fail=${fl:-0} script_errors=$e" >> "$out"
}
typeset -a files pids live
files=(${~glob})
for f in $files; do
	while true; do
		live=()
		for pid in $pids; do kill -0 $pid 2>/dev/null && live+=($pid); done
		pids=($live)
		(( ${#pids} < par )) && (( $(free_pct) >= min_free )) && break
		sleep 2
	done
	run_one "$f" &
	pids+=($!)
done
wait
sort -o "$out" "$out"
