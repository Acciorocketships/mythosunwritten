# October 9 evening judging pass

The 16:12–16:33 playthrough was recorded. The fixes below address measured stalls, blown highlights, the remaining short birch variant, and missing local atmosphere. **Water containment remains unresolved; the unsuccessful carving experiment is not included in the game.**

| Area | Cause and change |
|---|---|
| Periodic water hitch | A full 65,536-entry wave-frame cache was discarded on one miss. It now replaces one entry at a time. A controlled full-cache boundary measurement fell from 20–23 ms to 8–12 microseconds, with identical sampled frames. This is one component of the observed water stalls, not proof that every 220 ms water hitch is gone. |
| Travel/eviction hitch | Large frozen water data could lose its final reference while deleting a scene node or replacing ripple samplers. Those owners now hand it to a worker after their calling frame returns. One measured Water-node destruction took 35 ms before; no Water-node deletion exceeded 1 ms in the follow-up. Terrain and feature eviction each detach at most one chunk per frame. |
| Scene growth | The detailed ring now covers 5×5 chunks instead of 7×7, with one extra eviction ring. This reduces accumulated distant geometry and memory, at the cost of a shorter fog-covered horizon. Inspector settings remain available. |
| Missing orbs and local mist | Publishing a newly attached chunk made the pending-result cleanup remove it before its remaining atmosphere steps ran. Active integration now retains ownership until all steps finish. The inspected nine-chunk forest went from zero local lights to 46. Existing light/shadow budgets still apply. |
| Blown-out bloom | Normalized the glow levels, lowered glow strength and bloom, raised the HDR threshold, and added filmic highlight headroom. Pale walls and ground retain detail; emissive lights still glow. |
| Forest atmosphere | Reduced forest/marsh/wetland ambient light by different amounts and increased forest/marsh volumetric density. Existing shadowed sun scattering, local mist, lamps and orbs can now work together. Parameters remain editable per biome. |
| “Embedded” sapling | The photographed asset is `meadow.birch_bush.04`, not variant 03 removed in the previous pass. Its root was only 7 cm above the terrain, but the compact, low-branched shape reads as a buried tree. Removed variant 04 in all seasons. |

## Screenshots

Same camera and scene, changing the lighting settings only:

| Before | After |
|---|---|
| ![Blown highlights](/Users/ryko/story/docs/qa/2026-10-09-evening-pass/town-before.png) | ![Retained wall and ground detail](/Users/ryko/story/docs/qa/2026-10-09-evening-pass/town-after.png) |

| Sapling before | Sapling after |
|---|---|
| ![Short birch variant before](/Users/ryko/story/docs/qa/2026-10-09-evening-pass/sapling-before.png) | ![Low bush replacement after](/Users/ryko/story/docs/qa/2026-10-09-evening-pass/sapling-after.png) |

The short, white-trunked variant is gone; ordinary low bushes remain. Restored orb and forest atmosphere:

![Restored orb lighting and darker forest](/Users/ryko/story/docs/qa/2026-10-09-evening-pass/forest-glow.png)

Images are local QA artifacts, not checked into Git.

## What the playthrough log establishes

Source: `user://judging_logs/judging-2026-10-09T16-12-12.jsonl`; 1,279 seconds, 1,251 summary records. It contains 912 recorded frames of at least 50 ms, including 804 during seconds when the player was not frozen. Peak engine-reported static memory was 13,206 MiB (12.9 GiB) on a 16 GiB machine. Representative costs were 220 ms in water packets and 132–152 ms in chunk eviction. A 736 ms frame had only 3.5 ms of measured process callbacks and 1.8 ms of physics; its remaining time is not attributable from that log. GPU timestamp queries returned no useful measurement.

Memory pressure is a plausible contributor, not a proven diagnosis of those unaccounted stalls. The logger now additionally records available system memory, water sampler/cache counts, and separate light, ground-map, mood, underwater and frontier timings. Logging remains automatic.

## Water investigation, deliberately not shipped

At the photographed hillside, river source `(0,2)` doubles back near a lower river from `(-1,0)`. Excavation from nearby lower reaches can remove the upper channel's downhill bank. The water solver then maintains projected flowing water over that exposed slope. This is more than a cosmetic water shader issue.

Tried nearest-cross-section ownership, a U-shaped section with a dry shoulder, and fading broad-bank excavation on steep ground. Native/GDScript parity passed, but the live capture still showed water draping over the hillside; terrain also rose significantly at the photographed camera. Restored the original carving implementation. The rejected patch, regression fixtures and sampled transects are retained in `rejected-water/` for continuation. A proper solution must reconcile overlapping river topology, carved banks and transverse hydraulic levels together, without drying up the channel at ledges.

The old `test_october9_river_depth` pinned location also fails on unchanged commit `249fd19b3`: its nearest current river is about 94 m away after the earlier landform changes. It is not evidence of a regression introduced by this pass and was not silently re-pinned.

## Validation

- Focused cache, reference-lifetime, retirement queue and incremental-atmosphere regressions: 5 tests, 117 assertions passed.
- Atmosphere, biome blending, local-light budgets, orbs, lanterns and water-current checks: 21 tests, 1,490 assertions passed.
- Stored ripple replay retained its exact surface digest in four runs.
- .NET build: zero errors; existing NuGet vulnerability-feed warning due unavailable network access.
- Movement profile and final captures: see the accompanying evidence files.

Reproduction (use the .NET binary):

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --log-file /tmp/evening-feel-engine.log res://tests/harness/frame_feel_profile.tscn -- --seed 2697992464 --phase-seconds 45 --fixed-route --return-to-start --profile-callbacks --report /tmp/evening-feel.json --size 1600x900 --no-vsync --x 679 --z 1539
```

The radius comparison adds `--terrain-radius 2`. The harness records full wall-clock frame times, callback timings, memory, .NET collection counts and cumulative GC pause duration. Background machine load is not controlled, so these runs are diagnostic rather than a reliable FPS improvement claim.


### Extended movement result

Both runs exercised idle, turning, running, running while turning, final idle, and returning to the starting pose (45 seconds each; about 4.5 minutes after startup). Neither run froze the player. On return to the same pose, the smaller ring used **8,233 MiB versus 11,315 MiB** (27% less), and frame-time p95 was 43.23 versus 54.85 ms. Peak memory over the full smaller-ring run was 8,969 MiB. Its worst frame was 212 ms versus 1,567 ms in the larger-ring run. However, moving-phase median/p95 times were worse in the second run under changing background load, so **this is not a demonstrated across-the-board FPS improvement**. Occasional hitches remain, and the smaller ring's settled median was still about 38 ms at this forest pose.

The worst large-ring pauses were mostly outside measured callbacks and did not coincide with equivalent .NET GC pauses (the 1,567 ms frame had no increment in cumulative GC pause time). This rules out attributing that event to the managed collector. The new automatic logger now captures those GC counters too. Follow-up should profile render/server synchronization and OS memory pressure under a controlled long session; do not assume that the targeted cache/retirement fixes explain every pause.
