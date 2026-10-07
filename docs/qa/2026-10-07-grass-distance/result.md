# Grass radius sweep (Task 2)

Windowed 1920x1080, no vsync, 8 s phases, seed 2697992464, `--grass-radius FULL,EDGE`.
Raw data: `/private/tmp/grass-radius/feel_<pair>.json` / `.frames.json`, screenshots `/private/tmp/grass-radius/shots_<pair>/`.
Single run per pair (noisy: run-to-run dt p95 differs by ~1-2 ms).

| pair | run_turn dt p50/p95 | run_turn proc p95/max | frames >10 ms proc (run_turn) | run proc max | run grass_pending max | run_turn pending max | grass tiles p50 (run) | static mem MB |
|---|---|---|---|---|---|---|---|---|
| 60,84 (base) | 19.8 / 24.5 | 4.9 / 9.5 | 0 | 13.7 | 5 | 3 | 61 | 4709 |
| 80,120 | 20.9 / 25.6 | **7.8** / 16.1 | 6 | 8.9 | 17 | 18 | 101 | 4102 |
| 90,140 | 21.2 / 23.9 | 4.5 / 7.0 | 0 | 5.8 | 12 | 15 | 140 | 3980 |
| 100,170 | 21.8 / 25.6 | 5.1 / 6.3 | 0 | 9.0 | 26 | 29 | 192 | 3979 |

Gates (vs baseline): run_turn dt p95 <= 26.0 ms; run_turn process p95 <= 6 ms; no new >10 ms process frame; run grass_pending max <= 6.

- 80,120: fails process p95 and has six >10 ms frames (likely a noisy run, but fails as measured).
- 90,140 and 100,170: pass all frame-time gates.
- Pending gate: every candidate fails (12 and 26 tiles vs 6). One grass worker cannot keep fill-in near the player at running speed.

## Chosen pair

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

By the stated rules 90,140 fails the frame-time gates, so the shipped default stays **60,84**. The sparse-dressing coupling still ships (`EnvironmentCommitQueue` grass/flower range = `GrassStreamer.GRASS_RADIUS + 6`), so any later radius change moves it with the ring. Screenshots (`baseline_60-84_pitch12_resweep.png` vs `candidate_90-140_pitch12_resweep.png`) confirm the owner's complaint: at 60,84 grass visibly ends on the distant left slope; at 90,140 it does not. Reaching 90,140 needs a cheaper commit path first (run_turn process hitches, fill-in lag) and is a follow-up. Try it at runtime with `--grass-radius 90,140` in the harness or `GrassStreamer.set_radii(90, 140)`.
