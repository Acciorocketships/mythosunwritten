# Grass radius sweep (Task 2)

Windowed 1920x1080, no vsync, 8 s phases, seed 2697992464, `--grass-radius FULL,EDGE`.
Raw data: `/private/tmp/grass-radius/feel_<pair>.json` / `.frames.json`, screenshots `/private/tmp/grass-radius/shots_<pair>/`.
Single run per pair (noisy: run-to-run dt p95 differs by ~1-2 ms).

| pair | run_turn dt p50/p95 | run_turn proc p95/max | frames >10 ms proc (run_turn) | run proc max | run grass_pending max | run_turn pending max | grass tiles p50 (run) | static mem MB (unreliable: varies run to run, not a gate) |
|---|---|---|---|---|---|---|---|---|
| 60,84 (base) | 19.8 / 24.5 | 4.9 / 9.5 | 0 | 13.7 | 5 | 3 | 61 | 4709 |
| 80,120 | 20.9 / 25.6 | **7.8** / 16.1 | 6 | 8.9 | 17 | 18 | 101 | 4102 |
| 90,140 | 21.2 / 23.9 | 4.5 / 7.0 | 0 | 5.8 | 12 | 15 | 140 | 3980 |
| 100,170 | 21.8 / 25.6 | 5.1 / 6.3 | 0 | 9.0 | 26 | 29 | 192 | 3979 |

Gates (vs baseline): run_turn dt p95 <= 26.0 ms; run_turn process p95 <= 6 ms; no new >10 ms process frame; run grass_pending max <= 6.

- 80,120: fails process p95 and has six >10 ms frames (likely a noisy run, but fails as measured).
- 90,140 and 100,170: pass all frame-time gates.
- Pending gate: every candidate fails (12 and 26 tiles vs 6). One grass worker cannot keep fill-in near the player at running speed.

## Chosen pair (SUPERSEDED by the re-sweep Decision below; the shipped pair is 60,84)

No pair passes every gate. Frame time is fine up to 100,170, so the frame-time-limited choice is **100,170** (largest), but it lags 26-29 tiles behind while running; 90,140 lags 12-15. Task 4 (second grass worker) is needed before adopting either; re-run this sweep for the pair after Task 4. (Memory fell vs baseline in later runs, so it is not a constraint.)

## Screenshots reviewed

`baseline_60-84_pitch12.png` and `candidate_100-170_pitch12.png` (this folder); all others under `/private/tmp/grass-radius/shots_*/` (pitches 3, 12.7 (saved as 12), 30).
At 60,84 the grass visibly ends on the distant left slope (bare green terrain, a visible edge about 80 m out). At 100,170 grass carpets the whole view to the horizon and the edge is not visible.

## Re-sweep with two workers

Same setup, each pair run twice, one at a time, after making the harness sample `pending_tiles()` every 10th frame (it sorts the whole ring and was inflating process time with the ring size). Raw: `/private/tmp/grass-radius2/`. Per run: run_turn dt p95 / run_turn process p95 / frames >10 ms process (run_turn) / run-phase grass_pending max.

| pair | run 1 | run 2 | mean dt p95 | run pending max |
|---|---|---|---|---|
| 60,84 (base) | 23.8 / 4.2 / 0 / 5 | 24.2 / 12.6 / 45 (one 221 ms hitch) / 5 | 24.0 | 5 |
| 90,140 | 24.0 / 8.9 / 11 / 16 | 28.9 / 6.4 / 1 / 12 | 26.5 (+2.5) | 16, 12 |
| 100,170 | 27.8 / 7.3 / 4 / 22 | 25.5 / 6.1 / 0 / 21 | 26.7 (+2.7) | 22, 21 |

Runs are noisy (the baseline's own second run has a 221 ms hitch; `turn` p95 of 90,140 run 2 was 31.7 ms).

Gates: neither 90,140 nor 100,170 holds run_turn dt p95 within +1.5 ms of baseline (mean +2.5/+2.7), both have run_turn frames over 10 ms process in at least one run, and both fail run pending (the 2x-baseline fallback allows 10; they show 12-22). The second worker only moved pending from 12/26 to 12-16/21-22.

## Decision

By the stated rules 90,140 fails the frame-time gates, so the shipped default stays **60,84**. The sparse-dressing coupling still ships (`EnvironmentCommitQueue` grass/flower range = `GrassStreamer.GRASS_RADIUS + 6`), so any later radius change moves it with the ring. Screenshots (`baseline_60-84_pitch12_resweep.png` vs `candidate_90-140_pitch12_resweep.png`) confirm the owner's complaint: at 60,84 grass visibly ends on the distant left slope; at 90,140 it does not. Reaching 90,140 needs a cheaper commit path first (run_turn process hitches, fill-in lag) and is a follow-up. Try it at runtime with `--grass-radius 90,140` in the harness (applies to the whole world from the start). `GrassStreamer.set_radii(90, 140)` at runtime only affects tiles streamed afterwards; already-committed tiles keep their old extent, so set it before the world starts for a full effect.


Raw summary data (frames.json omitted): `data/` (`grass-radius` sweep and `grass-radius2` re-sweep).

## Ship measurement (90/140 vs 60/84, worker count)

Windowed 1920x1080, no vsync, 8 s phases, seed 2697992464, harness flags `--grass-radius`, new `--grass-workers`. Runs interleaved A B A B A B, then B2 x3, then the grassy site `--x -672 --z 672` (A B A B). Other work ran on the machine throughout (load averages below), so absolute ms are inflated; compare within the table. Raw: `data/ship/`.

Load at start of each run (1/5/15 min):
```
A 1 load: 7.99 8.26 10.05
B 1 load: 9.30 8.92 10.00
A 2 load: 16.73 10.88 10.56
B 2 load: 12.95 11.40 10.81
A 3 load: 16.80 12.99 11.49
B 3 load: 17.10 14.04 12.09
B2 1 load: 13.28 13.72 12.23
B2 2 load: 11.95 12.84 12.08
B2 3 load: 16.23 14.63 12.94
gA 1 load: 15.75 14.40 13.05
gB 1 load: 38.88 22.68 16.66
gA 2 load: 16.49 19.72 16.74
gB 2 load: 16.99 18.55 17.65
DONE
```

Cells: mean over runs. dt in ms. pend = grass tiles wanted but not yet built (p50 mean / max over runs); tiles = committed grass tiles p50.

| config | phase | dt p50 | dt p95 | dt p99 | process p95 | pend p50 / max | tiles p50 |
|---|---|---|---|---|---|---|---|
| A 60/84, 1 worker (spawn, 3 runs) | idle | 18.7 | 21.2 | 25.0 | 2.3 | 0 / 0 | 52 |
| A 60/84, 1 worker (spawn, 3 runs) | run | 20.4 | 23.8 | 27.7 | 11.5 | 7 / 11 | 55 |
| A 60/84, 1 worker (spawn, 3 runs) | run_turn | 22.2 | 26.4 | 32.3 | 12.2 | 1 / 10 | 59 |
| A 60/84, 1 worker (spawn, 3 runs) | turn | 21.0 | 24.5 | 26.8 | 1.7 | 0 / 0 | 52 |
| B 90/140, 1 worker (spawn, 3) | idle | 20.6 | 24.0 | 30.2 | 2.7 | 0 / 5 | 128 |
| B 90/140, 1 worker (spawn, 3) | run | 21.8 | 25.2 | 29.1 | 11.9 | 11 / 27 | 133 |
| B 90/140, 1 worker (spawn, 3) | run_turn | 23.9 | 29.3 | 34.6 | 15.5 | 19 / 32 | 130 |
| B 90/140, 1 worker (spawn, 3) | turn | 22.9 | 26.5 | 30.2 | 1.9 | 0 / 0 | 128 |
| B2 90/140, 2 workers (spawn, 3) | idle | 20.7 | 23.9 | 28.7 | 2.6 | 0 / 0 | 128 |
| B2 90/140, 2 workers (spawn, 3) | run | 21.9 | 25.6 | 29.3 | 12.1 | 8 / 19 | 136 |
| B2 90/140, 2 workers (spawn, 3) | run_turn | 23.7 | 29.0 | 36.3 | 15.2 | 8 / 24 | 143 |
| B2 90/140, 2 workers (spawn, 3) | turn | 22.6 | 26.1 | 29.5 | 1.9 | 0 / 0 | 128 |
| A at (-672,672) (2) | idle | 22.4 | 27.2 | 32.3 | 2.6 | 0 / 0 | 52 |
| A at (-672,672) (2) | run | 27.8 | 36.0 | 41.0 | 12.6 | 10 / 22 | 51 |
| A at (-672,672) (2) | run_turn | 28.2 | 35.5 | 42.5 | 15.1 | 21 / 24 | 40 |
| A at (-672,672) (2) | turn | 25.7 | 31.0 | 34.4 | 1.8 | 0 / 0 | 52 |
| B at (-672,672), 1 worker (2) | idle | 22.3 | 27.0 | 32.2 | 3.0 | 37 / 42 | 95 |
| B at (-672,672), 1 worker (2) | run | 27.0 | 34.7 | 40.8 | 9.4 | 36 / 48 | 108 |
| B at (-672,672), 1 worker (2) | run_turn | 27.8 | 34.0 | 39.0 | 8.3 | 49 / 55 | 94 |
| B at (-672,672), 1 worker (2) | turn | 25.6 | 30.3 | 35.1 | 2.4 | 29 / 32 | 103 |

Deltas at spawn (B - A): idle p95 +2.8, run p95 +1.4, run_turn p95 +2.9 (p99 +2.3), turn p95 +2.0 ms. The earlier sweep measured +2.5 under heavier load, so the cost is stable: about 2-3 ms, from more committed MultiMesh tiles (about 130 vs 55).

Workers: B2 vs B at spawn: run_turn dt p95 29.0 vs 29.3, p99 36.3 vs 34.6 (noise); run_turn pending p50 8 vs 19, max 24 vs 32; run pending p50 8 vs 11. Two workers shorten fill-in lag at no frame-time cost, so `GrassWorkQueue.WORKERS` is now 2 (a static var, overridable by the harness `--grass-workers N`).

Grassy site (-672, 672), one worker: B is not slower than A there within noise (one B run had load 38) but lags 36-49 tiles while idle/running; not re-run with two workers.

## Decision

Shipped: 90/140 m with 2 grass workers, at the owner request. Cost about +2 to +3 ms dt p95; running fill-in lag p50 8 tiles (19 with one worker). `keep_radius()` is 164 m; dressing grass/flower range follows GRASS_RADIUS + 6 = 146 m (EnvironmentCommitQueue.gd:118). `test_grass_streamer` ring count re-pinned 52 -> 132.
