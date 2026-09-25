# Photo 11: unified spirit orbs

Accepted for the photographed scene and the measured views. The separate terrain-loading issue in this photo remains open.

## Cause and alternatives

Production had two different render paths. `BiomeAtmosphereField.points.fireflies` became a GPU particle emitter, with up to five overlapping sprites per canonical anchor and no ground light. `data.orbs` became a moving `SpiritOrb` with a 3.2 m additive sprite and attached omni light. The small particles visibly remain in place throughout the before replay. Changing the large sprite alone could not repair them.

Considered adding a light node to every particle, retaining two shader motion implementations, or sharing one analytic motion and appearance with batched small geometry. Chose the latter: preserve every canonical ground/water anchor, render one small orb there, and bound the nearby light allocation. No new biome placement samples or terrain queries.

## Change

Both sizes use `SpiritOrb.offset_at`, the same warm palette, real spherical core geometry, and a soft radial halo. The core shader shades its actual world-space normals; its luminous output goes through ALBEDO because these are unshaded materials. Diameters are 0.22/0.36 m and halos 1.1/1.8 m. Close and side views show a rounded, cream-colored surface rather than the former uniform disc. The large halo is substantially less intense; the small halo is stronger than before.

Large orbs keep their shared moving parent. Small orbs use two MultiMeshes per chunk. Up to sixteen nearby shadow-free lights are allocated on demand in each chunk, following the same instance centres. Small lights fade at 35–50 m; distant chunks release the pool and skip geometry updates. Revisiting a resident chunk evaluates its current absolute motion time instead of restarting its phase. Ordinary firefly placement counts remain unchanged (548 anchors and 20 large orbs in the nine-chunk fixture).

## Iteration and verification

- The initial regression failed four assertions: old small emitter still present, no small adapter, no large spherical core, excessive large halo (`red.txt`).
- The first replay candidate darkened the scene. Isolation found an error in the QA replacement payload: a resized Color array defaulted to opaque black, creating black mist. Explicit transparent initialization repaired the harness; production fog was not changed. Those images in `timed-after` are rejected evidence.
- A subsequent core was too white. Reduced its radiance to retain visible spherical shading; final images are `timed-after3` and the live production `after` directory.
- Six production before/after pairs use identical reconstructed camera metadata. All six full views and differences were inspected in `production-review.png`.
- Sixteen timed pairs (four views at 0/5/10/20 seconds) reuse the identical frozen real-world scene, source anchors, shader clock and cameras. All full frames and pixel differences were inspected in the four `*_review.png` sheets. Small orbs move visibly; the original large movement is preserved. No terrain or tree displacement is introduced.
- Rendered small-core centroids agree with native projected centres to 0.50–0.83 pixels in every timed frame (`centroids.json`), separately verifying visible movement rather than only node transforms.
- Three lights-disabled subtractions verify real grass/ground illumination. The small close view has 380,943 pixels gaining more than three channel levels, maximum 29/255; the large close view peaks at 60/255. These are whole-frame light-contribution measurements, not claims that every changed pixel belongs to the target orb. The inspected differences show the local ground patch beneath each target (`ground-light-review.png`).
- Eleven native tests pass 2,606 assertions, including actual MultiMesh centre/light registration over sixty seconds, bounded drift, forty repeated distant visits, light-pool release and preserved revisit phase (`native-green.txt`).
- The broader six-script headless run passes 24 tests / 1,980 assertions; its one pending test explicitly requires native MultiMesh readback and passes in the native run above (`focused-green.txt`).

## Rendering cost and limits

Three matched uncapped views, 150 warm-up frames and 300 measured frames each:

| View | Before median / p95 ms | After median / p95 ms | Nodes before / after | Omni nodes before / after |
| --- | --- | --- | --- | --- |
| Photo | 14.713 / 15.047 | 15.551 / 16.033 | 2,379 / 2,467 | 31 / 57 |
| Offset east | 14.123 / 14.733 | 14.729 / 15.203 | 2,379 / 2,469 | 31 / 59 |
| Offset southwest | 15.124 / 15.679 | 15.480 / 15.971 | 2,379 / 2,472 | 31 / 62 |

The additional illumination and geometry cost 0.36–0.84 ms/frame in this comparison, with only 26–31 additional omni nodes instead of hundreds of per-anchor lights. Render CPU medians remain 1.14–1.25 ms. Metal's GPU timer returns zero and is unavailable, not evidence of zero GPU cost. The earlier `performance-before`/`performance-after` comparison was refresh-limited; `performance-before2`/`performance-after2` is the uncapped measurement. These local comparisons are not universal performance guarantees.

The frozen render fixture emits duplicate external-node-reference warnings and resource-retention diagnostics on teardown in both baseline and candidate. Native focused tests and the production capture finish cleanly. This result does not claim global shutdown health.

F3 coordinates are rounded player/crosshair pins, so matched reconstructions cannot recover the original full-precision camera. The original photo also contains unloaded terrain; completed ground in both regenerated views does not establish a streaming fix. Water, repeated travel, grass latency and city generation remain separate pending work.

## Reproduction

Use `/Applications/Godot.app/Contents/MacOS/Godot`, always with a writable `--log-file`.

- Live camera replay: `res://tests/harness/september10_reported_qa.tscn -- --spot 11_orbs_streaming --output <directory>`.
- Frozen original scene: `res://tests/harness/september10_orb_fixture.tscn`, captured before the implementation. It retains original anchor metadata and a SHA-256 in timed evidence.
- Timed replay: `res://tests/harness/september10_orb_replay.tscn -- <fixture/world.scn> <output> [--before]`.
- Frame timing: `res://tests/harness/september10_orb_performance.tscn -- <fixture/world.scn> <output> [--before]`.
- Pixel differences: bundled Python runs `tests/harness/september10_pixel_diff.py <before> <after> <output>`.
