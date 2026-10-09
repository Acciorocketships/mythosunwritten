# October 9 judging follow-up

The changes are ready for another visual judging pass. Remaining long-session hitches are recorded automatically; they are not all fixed.

| Feedback | Cause and change |
| --- | --- |
| Buried-looking birch | The short multi-stem variant reads as a buried sapling. Removed `meadow.birch_bush.03` in all three seasons from ambient spawning. |
| Loading regions / frozen character | Completed structures were held behind their chunk’s terrain work. Publish them earlier. Movement now stops before missing ground, while turning, sliding along the edge and retreating remain possible. Cold region generation can still take seconds. |
| Square loading boundary | Added progressively denser volumetric fog, rounded coverage corners and a matching distant fog continuation. |
| Screen-fixed tree blobs | The fade mask was attached to screen pixels. It now projects through each tree’s position, with matching mesh/card masks. |
| Uniform hillsides | Local formations are closer together and taller: 144 m spacing instead of 192 m, 24–44 m height range instead of 16–32 m. The existing ridges, passes and divided hollows become more prominent. |
| Noisy roofs | Four roof textures had no mipmaps. Added filtered distance levels, keeping the original base pixels, roof meshes and UVs. |
| Flat atmosphere / missing orbs | Shaders had not been removed, but global volumetric density was zero and most biomes had no orbs. Added editable biome atmosphere presets and orb populations in every biome, retaining the light budget. |

## Before and after

These are renderer captures, not edited mockups. Left/before and right/after use matching cameras within each pair. Terrain images show the actual tile geometry without water, vegetation or cliff dressing; roof and fog images isolate those effects in controlled scenes. They are not recreations of the entire attached screenshot.

| Local terrain: before | Local terrain: after |
| --- | --- |
| ![Before local relief](local/0_battle.png) | ![After local relief](local/1_battle.png) |

| Roof filtering: before | Roof filtering: after |
| --- | --- |
| ![Roof before mipmaps](roof_before.png) | ![Roof with mipmaps](roof_after.png) |

| Loading corner: before | Loading corner: after |
| --- | --- |
| ![Hard loading corner](frontier_before.png) | ![Soft loading corner](frontier_after.png) |

| Lighting: before | Lighting: after |
| --- | --- |
| ![Previous lighting](atmosphere_before.png) | ![Biome atmosphere](atmosphere_after.png) |

The lighting pair uses the camera reconstructed from the forest screenshot’s F3 coordinates (player 325.3,106.2,1205.7; crosshair 355.5,78.2,1254.0), on the new geography. Only atmosphere settings change between these two captures; the local terrain changes mean it cannot exactly reproduce the old landscape. This view checks ordinary lighting, not a promise of visible sunbeams in every camera direction.

## Next judging pass

Start the game normally with Godot .NET. Logging is automatic. Files appear in:

`~/Library/Application Support/Godot/app_userdata/Story/judging_logs/`

Each JSONL file records frame rates, worst frames, position, memory, pending grass/terrain, worker phase and callback timings for streaming, water and atmosphere. The final logger uses wall-clock intervals, so capped engine delta cannot hide a long stall. Unsupported GPU timestamps are `null`. A 180 ms injected stall was captured by `october9_logger_probe.gd`.

Tune `terrain/biome/visuals/*.tres` for each biome’s fog density/scattering, bloom, saturation, contrast, exposure and shadow opacity. `AtmosphereDirector` also exposes atmosphere/bloom strength. Standard/High enable volumetrics; Economical retains its cheaper fallback. Sun shafts depend on the sun direction and occluding geometry, so they will not appear in every view.

## Verification and limits

- Native terrain/reference and related focused tests: 16/16, 4,136 assertions.
- Rendered tree suite: 9/9, 314 assertions, including camera-turn alignment. The first smaller mask still looked too pixel-like; a 0.45 m mask passed the coverage/adjacency check.
- Atmosphere and streaming regression group: 23/23, 1,414 assertions. Final movement suite, including retreat from a teleport inside the guard band: 4/4, 18 assertions.
- Production-world movement guard stopped before an unloaded neighbour and allowed immediate retreat. This direct guard check is separate from the traversal below.
- All changed shader stages rendered successfully. Roof repair rereads every texture and verifies mipmaps plus identical base pixels.
- .NET build succeeded; NuGet’s audit endpoint was unavailable, producing one warning.

Five 60-second phases at 1920×1080, no vsync, M1 Pro, seed 2697992464, starting near (325,1205). Startup was 161 seconds. This is a final-build observation, **not a paired speedup benchmark**.

| Phase | Frame p50 / p95 | Main callbacks p95 | Frozen frames | Grass backlog max |
| --- | --- | --- | --- | --- |
| Idle | 41.22 / 49.15 ms | 4.24 ms | 0 | 0 |
| Turn | 42.23 / 58.59 ms | 6.40 ms | 0 | 0 |
| Run | 39.38 / 50.87 ms | 9.88 ms | 0 | 5 |
| Run + turn | 47.29 / 78.63 ms | 16.03 ms | 0 | 2 |
| Final idle | 47.06 / 59.92 ms | 11.79 ms | 0 | 0 |

Worst frame: 209 ms. Rendering work, resident nodes and memory increased as more chunks arrived (static memory peaked around 11.9 GB). Integration/collision work contributed some callback spikes; the GPU timestamp API returned zero on this backend, so these data do not isolate GPU cost. The route did not encounter the new boundary guard (zero blocks), so its zero freeze count is not proof of boundary behavior. The separate boundary tests cover that. Shutdown reported one leaked physics-body RID; no gameplay script or shader error was reported. Cold planning, rendering hitches and resource growth remain follow-up work. The new logger will make the next real playthrough diagnosable.

The logger changed from engine delta to wall time after the traversal; that correction was separately verified with the injected-stall probe. Full phase results: [traversal.json](traversal.json). Test evidence is saved alongside this report.

## Reproduce

Use `/Applications/Godot_mono.app/Contents/MacOS/Godot`, not the standard binary. Render captures stay local under the repository’s QA artifact policy.

```sh
Godot --path . res://tests/harness/october9_more_local_preview.tscn -- --seed 2697992464 --output docs/qa/2026-10-09-manual-pass/local
Godot --path . -s tests/harness/october9_frontier_review.gd
Godot --path . -s tests/harness/october9_logger_probe.gd
Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_october9_streaming_boundary.gd -gexit
Godot --path . res://tests/harness/frame_feel_profile.tscn -- --seed 2697992464 --x 325 --z 1205 --fixed-route --phase-seconds 60 --size 1920x1080 --no-vsync --report /tmp/oct9-traversal.json
```

Roof comparison requires the original textures:

```sh
mkdir -p /tmp/oct9-roof-before
for id in 173753758685fa88a5cb 19c539ddc9e7ae32cf6b 3939f12f65493ec760ed e373c53c6944687f9278; do
  git show "fc191313d:terrain/environment/textures/suntail_village_kit/$id.res" > "/tmp/oct9-roof-before/$id.res"
done
Godot --path . -s tests/harness/october9_graphics_review.gd
```
