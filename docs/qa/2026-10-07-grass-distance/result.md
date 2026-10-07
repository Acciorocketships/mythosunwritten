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
