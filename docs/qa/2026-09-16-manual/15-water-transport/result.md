# P10 water transport: temporal follow-up

The earlier static current survey did not prove correct motion over time. A 60-second replay exposed two additional faults: the surface derivative could sample across a narrow minimum and infer the wrong local slope, and a wave front could retain its uphill direction while its transporting current turned downhill.

## Repair

`WaterCurrentField` now evaluates the local surface derivative over 5 cm, retaining the separate 1 m bank look-ahead. `WaterRippleSim` constrains both envelope velocity and crest direction using that same surface, then samples the midpoint of the time step to respond to bends before crossing them. `WaterSampler.current_frame_at` supplies velocity, gradient and bank direction together. Reusing the frame avoids evaluating the identical surface again for the crest.

This changes transport only. It does not remove the photographed hillside puddles, repair broad cliff spills, or change static water geometry.

## Evidence

The [deterministic trajectory probe](packet-flow-probe.json) follows actual production packets through saved P10 samplers for 1,800 steps at 30 Hz. Counts below use a 1 mm rise threshold.

| Version | Valid steps | Envelope rises | Carrier-reference rises | Largest envelope rise |
|---|---:|---:|---:|---:|
| Original before the W02 work | 110,763 | 16,754 | 15,573 | 75.55 mm |
| Earlier static-current correction | 110,689 | 339 | 630 | 8.76 mm |
| Current temporal correction | 110,721 | 28 | 8 | 1.39 mm |

The carrier reference combines envelope translation with phase travel along the packet direction; it is not an exhaustive tracking of every warped visible crest. Its largest remaining rise is 5.58 mm. Small finite-step crossings at sharp surface minima remain, so this is substantial improvement, not proof of universally downhill motion.

The final native Godot replay uses identical saved ReviewCam poses, frozen world geometry and controlled times. It rebuilds current attributes for 70,787 vertices across nine water meshes. There are 31 matched frames at the reported angle and eight additional timed pairs at ±8 degrees. Reviewed frames show the former broad fronts changing direction with the river; the source puddles and angular water coverage remain visibly wrong.

- [Before clip](before.mp4), [current clip](after-shared.mp4).
- Reported pose: [before](native-shared/before/P10_000.png), [current at 10 s](native-shared/after/P10_000.png), [current at 13 s](native-shared/after/P10_030.png).
- Nearby angle at 13 s: [before](native-shared/before/P10_390_8.png), [current](native-shared/after/P10_390_8.png).

## Tests and cost

The local-minimum and turning-crest tests first failed ([red](red.log)). The shared-read test separately reproduced 27 surface reads instead of 18 ([red](shared-red.log)). Final checks pass **20 tests / 22,346 assertions** across [focused transport/forces](shared-green.log), [actual mesh/CPU payload parity](payload.log), and [neighboring chunk current parity](border.log).

The [controlled CPU replay](cost.json) runs 900 updates in both forward and reversed version order, measuring the last 600. Shared frames reduce packet-update mean from approximately 9.03 ms to 6.55 ms (27.5%) relative to the same corrected algorithm with duplicate reads. All packet states across all 900 frames hash identically between those two versions. The older static correction costs approximately 2.24 ms: the new temporal correctness still costs about 4.31 ms more. Native `_process` timings also include texture upload and spawning; [those timings](native-shared/timings.json) are not a whole-game performance result. Performance remains open.

The first cost-harness attempt passed a detached sampler script of the wrong type and produced invalid empty-simulation measurements. It was corrected before the authoritative `cost.json`/`cost.log` run. No numbers from that failed attempt are used here.

## Reproduction and scope

- `tests/harness/september17_packet_flow_probe.gd`: 60-second packet trajectories.
- `tests/harness/september17_water_transport_cost.gd`: CPU comparison and full packet-state hashes.
- `tests/harness/september17_water_transport_qa.tscn -- --frozen --snapshot res://docs/qa/2026-09-16-manual/03-water-flow/production-final/world.scn --spot P10 --output res://docs/qa/2026-09-16-manual/15-water-transport/native-shared`: native timed replay.

The frozen scene contains its saved historical cliff dressing. It is not a fresh combined-world cliff/water acceptance run. General hydraulics, swimming, source placement, streaming and water art remain open.
