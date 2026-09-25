# Downhill current correction — verification in progress

P10's baseline sampler had 408 uphill currents among 3,052 wet moving samples. River trace tangents could disagree with the final water surface, and correcting grid vertices alone left uphill results after interpolation.

`WaterCurrentField` now respects the local surface grade and bank constraints. `WaterSampler.velocity_at` projects after interpolation; `WaterSkin` writes the same sampler result into rendered current payloads. Retained native fill halo samples keep derivatives continuous across chunk edges.

The fresh `production-final/flow-report.json` survey contains 12,348 samples and zero uphill currents. The actual skin payload comparison passes 22,246 assertions; adjacent sampler parity passes three assertions. The broader water/current/immersion and then-current cliff run passed 28 tests / 5,318 assertions in `../focused-final.log` (that cliff candidate was subsequently rejected visually and is not accepted by this test count).

Status remains candidate pending timed crest-travel judgment. This repairs current direction; it does not repair hillside source topology, unwanted spill, shoreline geometry or water distribution. Those remain W01/W03/W04.

## Temporal follow-up

The static survey below did not establish correct packet travel. The [September 17 temporal follow-up](../15-water-transport/result.md) reproduces and repairs additional local-slope and turning-crest errors, records native timed frames, and explicitly retains residual and performance limits.
