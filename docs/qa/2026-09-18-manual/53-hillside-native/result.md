# Hillside routing — native comparison and collateral audit

Investigation only. Production water and cliff geometry are unchanged in this pass. The current cliff revision remains [pass 51](../51-cliff-native-blend/result.md); the additional boulder-height experiment is [rejected](../52-cliff-root-scale/result.md).

This follows the [descending-source-band experiments](../../2026-09-17-manual/10-hillside-order/result.md). It compares production routing with the existing `terrace_order.gd` fixture, without the appended terminal connector that previously raised filled water unnecessarily. Both use ordinary `TerrainChunkMesher`, `WaterSurfaceBuilder`, and fresh field/terrain construction. The photographed P21 camera is solved from the September 16 player/crosshair coordinates; alternate headings and an elevated diagnostic view use the same geometry. This is an isolated native terrain/water scene, not the complete dressed game world or a player traversal.

## Route collateral

The ten-source neighborhood contains seven live sources. Six change their station count under the experiment. All seven experimental traces remain exact prefixes of their immutable raw route, including beds and widths. This diagnostic does not fingerprint every source-pool or pond field.

Two existing joins disappear: source (-3,-2) changes from 34 joined stations to 235 unjoined stations, and (-4,-1) changes from 100 joined stations to 221 unjoined stations. Source (-2,-2) changes from 58 stations to a join at its first station. These are material routing changes, not evidence that each new route is hydraulically wrong. None of the inspected old receivers is in the same source-height band; this corpus does not resolve the equal-band omission.

The reported incoming source (-2,-1) changes from 288 unjoined stations to 69 stations ending inside a retained downhill receiver. That local improvement cannot by itself justify promotion. Source-head ordering is a broad network rule: it prevents a river that begins lower from joining a river that begins higher, even when the latter is physically lower at the meeting point. A production solution needs to preserve valid local confluences, as well as finite discovery and query-order independence.

Evidence: `route-delta.json` and `route-delta.log`; reproducible with `tests/harness/september18_hillside_route_delta.gd`. Prior red-first missed-confluence evidence remains in the linked investigations. No new production fix or green invariant is claimed here.

## Native review

Both nine-chunk native runs finish successfully and save their generated geometry. The initial five optical images per run show black water in this isolated harness and are excluded from water-appearance judgment. The snapshot utility also emits its known runtime global-shader-query warning. These captures are not evidence of a production rendering defect.

Saved geometry is replayed with a shared lit opaque diagnostic water material, without regeneration. Five final diagnostic images per case retain identical camera construction; the four stored camera records compare exactly. The matched reported view and elevated overview are inspected. The diagnostic material reveals water coverage/geometry only; it does not establish refraction, waves, biome mood, or final game appearance. An earlier three-view unshaded baseline replay is retained but superseded by the lit pair.

The trial materially changes the reported landscape. The baseline has the old broad hillside water footprint; the candidate overview shows a substantially different bounded channel and raised banks. At the exact original camera, the candidate's newly raised native cliff occupies much of the view. This is not an acceptable matched local repair. Native collision rays confirm that the original actor position changes from **20 m to 32 m**; **9/9** surrounding physical samples change, by up to **12 m**. These are actual colliders from the saved fresh worlds, not inferred pixel heights. Water mesh totals across the nine chunks change from 197,874 to 59,143 triangles; reduced triangle count is not an acceptance metric or a performance claim.

The experiment is **not promoted**. Source-height ordering changes carving and the wider river network too much to resolve W01 on this evidence. A next approach must address local confluence relationships without globally discarding valid receivers solely because their sources began higher. Production water remains unchanged. The current cliff source and material still byte-match pass 51.

Reproduce generation with `tests/harness/september18_hillside_native.gd`; set `STORY_HILLSIDE_ORDER=terrace` and a distinct `--output=` for the experiment. Final diagnostic replays use `tests/harness/september18_hillside_replay.gd -- --source=... --output=... --spots=P21 --opaque-water`. `september18_hillside_snapshot_ground.gd` samples native collision from the two saved worlds. These are investigations, not production regression tests or a full water acceptance suite.
