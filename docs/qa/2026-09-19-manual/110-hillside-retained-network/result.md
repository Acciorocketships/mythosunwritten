# Hillside water: retained channels and reach-based flow study

Investigation only. No production water, terrain or cliff code changes. P04's railing repair is separately verified in [pass 109](../109-rail-wall-joint/result.md). W01 remains open.

## Current production network

The seven live sources in the ten-cell review neighborhood were queried in both orders. Both surveys are identical. The four existing joins still meet their receivers' final depth-two traces. Three other traces touch retained receiving water but are excluded by random priority; two of those contacts are strictly downhill.

The photographed source (-2,-1) first reaches receiver (-3,-4) at incoming station 43 / receiver station 285. Their beds are 23.5 m / -0.5 m and the separation is 15.58 m inside the receiver's 24.75 m half-width. The receiver itself has an earlier missed join at station 33 into (-2,-5). Simply cutting both traces at those joins would remove station 285, invalidating the photographed river's destination. Moreover, the original high river receives sources (-3,-2) and (-2,-2) at its stations 133 and 106; cutting it at 43 also removes their receiving reaches.

This confirms the representation problem: a channel reach can lose its original upstream source and still receive another tributary farther down. Resolving only whole source-owned prefixes cannot express that case by changing source priority alone. See `forward.json` and `reverse.json`.

## Detached reach experiment

`reach_study.gd` follows raw channel stations, selecting a physically lower overlapping station or stable higher priority at exactly equal bed height. A source can continue through the downstream portion of another raw channel even when that channel's own source diverted upstream. No recursive resolved-source lookup occurs; the raw-neighbor indexes are finite. This is a candidate topology model, not a replacement production planner.

The reported source follows 44 of its own stations, joins receiver station 285, and reaches that raw channel's terminal basin at station 304. Its composed route contains 64 stations over 759.58 m. Meanwhile, the receiver's own source diverts elsewhere. Those different source paths coexist without deleting the newly supplied downstream reach. Source (-3,-2) still supplies station 133 of the old upper channel. Source (-2,-2) instead meets a much lower raw channel immediately at its source; that large new drop is specifically unverified hydraulically and visually.

All seven reviewed routes finish at existing raw terminal basins in forward and reverse query order. All 1,326 station records match exactly across orders and have zero rising bed steps. Two synthetic tests / 16 assertions cover a newly supplied tail after source diversion, equal-level precedence and reversed query order. These establish limited graph behavior, not water appearance or simulation correctness.

## Bound correction and remaining work

The first experiment reused the raw source-centred 2,400 m radius. It cut one composed route before its basin; those results are retained as `source-radius-*.json` and are not accepted terminals. The final study uses the original maximum river arc budget (360 × 12 m = 4,320 m), including lateral join distances, and retains the 360-station work cap. All seven finish within both budgets. One reaches 2,628.07 m from its source, so a production integration must enlarge source-discovery bounds consistently. Reusing the old discovery halo would omit real reaches at owner boundaries.

Before integration, resolve and verify:

1. End-of-budget semantics across a broader source corpus. The study reports exhaustion explicitly; it does not invent a terminal pond or silently fall back to the old route.
2. Complete finite source discovery, source-pool/terminal-pond ownership, land-bar lineage, shared downstream reach deduplication and query-order independence. Longer potential reach will affect discovery cost.
3. Several short switches between overlapping raw channels remain. Strict descent prevents a graph cycle but does not prove a pleasing channel shape or sensible current.
4. Shared native terrain construction and the filled hydraulic surface, especially the 24 m reported junction drop and the 52 m source-level jump for (-2,-2). Monotone planned beds alone did not prove good water in earlier experiments.
5. Matched fresh P10/P21 views, surrounding channels and physical support, followed by broader water controls and performance measurement.

Reproduce current-network diagnostics with `tests/fixtures/september19/hillside-retained-network/probe.gd`; reproduce the experiment with `reach_probe.gd`. Both accept `-- --reverse`. The experimental tests remain in the same fixture folder and are deliberately labelled as study coverage. Production WaterPlan is unchanged; its current hash and fixture hashes are recorded alongside the logs.
