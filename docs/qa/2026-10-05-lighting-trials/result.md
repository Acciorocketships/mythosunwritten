# Lighting implementation and candidate trials — October 5

Implemented in the existing a66d/story worktree. The previously merged foundation remains the base; this pass is not merged.

## Selected stack

- HDR output from the unshaded orb core, additive multiscale bloom above 1.4, brighter lantern glass and real local illumination. The original orb shader stayed near display brightness. Writing only EMISSION in this unshaded material did not fix the rendered result; writing HDR ALBEDO did. Native annulus luminance lift: 0.000 before, 0.05388 after, required >0.018.
- One light budget per rendered world, across streamed chunks: 8/20/32 active lights and 0/2/4 lantern shadows for Economical/Standard/High. Restores authored energy when a light returns; preserves source visibility; hysteresis discourages rapid swaps; separate preview worlds do not compete.
- Native shadowed fog, 144 m integration range, reduced ambient injection. Forest upper-layer weight 0.24→0.48 and sunlight scattering 2.2→4.5; lower ground layer stays at 4.5 m. The stronger 3× upper-layer / scattering 8 trial washed out the lake and was rejected.
- Hamid Memar's six-way lighting shader, repaired for Godot reverse-Z scene-depth fading and its negative-Y channel. Original procedural maps, maximum four sparse ground wisps per misty chunk, disabled on Economical, faded near the camera and past 50–75 m. Native volumes provide the continuous atmosphere; these quads only add local texture.
- Four blended directional shadow cascades with a larger share of detail near the camera, slightly tighter filtering, +10% saturation and slight contrast.
- Stronger wet-substrate roughness/specular response. Existing Meadow normal/SMA maps retained; damp bare rocks gain restrained clearcoat, while the contact/grass blend remains intact. No terrain geometry or asset placement changed.

## Candidate judgments

All four repositories were downloaded, pinned, licensed, integrated in the fixed-camera lab, and rendered with the Metal Forward+ backend. See `tests/lighting_candidates/manifest.json` and README for provenance and adaptations.

| Approach | Capture | Judgment |
|---|---|---|
| Native volumetrics | native.png | Best general integration: real light/shadow interaction, depth-aware medium. Keep. |
| ARez compositor rays / lens effects | screen.png, sun-screen.png | Runs after fixing import/Metal compatibility. Weak contribution at normal gameplay angle; screen-edge and sun-facing dependence. Keep available in the lab, not default. |
| joryleech geometry beams | geometry.png, geometry-tuned.png | Initial amplified-opacity cones were conspicuous; the material-default opacity was also tried. Neither solves full-length tree occlusion. Not selected for the general forest treatment. |
| Softened geometry adaptation | geometry-soft-final.png | Better edge/intersection fade; still decorative and not occluded along its whole length by trees. Do not use as proof of real tree-gap shafts. |
| Hamid Memar six-way | sixway.png, sun-sixway-soft.png | Useful low-cost local wisps. Adopt the depth-corrected, lower-density version alongside native fog. |
| Mango ray marcher | raymarch.png | Tuned down from the initial opaque/banded block. No scene-depth clipping or integration with the game's light/shadow system. Not a better general-purpose choice than native fog. |
| Combined selected trial | selected-twilight.png | Native fog, repaired six-way wisps, HDR orbs, real lantern glass/lights, local shadow budget. The isolated lab uses a simple floor and authored tree placements, not generated terrain. |

**Unresolved visual limit:** narrow cinematic canopy shafts remain weak at the normal tactical camera. Actual canopy-gap shadows and shadowed scattering work and pass native render checks; the geometry cones were not accepted as a substitute. This pass improves glow/local lighting more decisively than sun shafts.

## Evidence and limits

- Headless focused suite: 24 tests / 1519 assertions passed (budget, director, biome FX, field, orbs, lanterns).
- Native Metal suite: 5 tests / 20 assertions passed (bloom, canopy gaps, thin mist). Red-first logs retained for bloom and shared budget.
- Frozen production forest and twilight views captured at matched seed/camera; twilight orbit retains temporal history across 181 frames. Snapshot adapters explicitly refresh source energies, core shaders, and new wisps; the forest replay scales its old upper mist weight by 2 to match the new recipe.
- Before comparisons restore foundation environment settings and, for twilight, the original orb-core shader. They compare lighting on frozen geometry, not a fresh generation or a claim that every embedded material is rebuilt. `before-forest.png` predates the explicit old-core override and is only a grade/fog comparison.
- The packed production scenes report existing instantiate/teardown resource warnings in both before and after runs. Shader trials and native tests pass without shader compilation failures. The legacy town snapshot lacks required replay nodes and was rejected; the isolated lantern lab supplies the new lamp evidence.
- No full-world FPS claim: these captures force draws when background windows stall, and other Godot work was running concurrently. The complete historical terrain suite was not rerun for this rendering pass.
- PNGs and logs are local QA artifacts and may be ignored by Git. Keep this worktree until review is finished.

## Reproduce

Run Godot 4.5.1 Forward+ from this worktree:

```
Godot --path . tests/harness/lighting_lab/lab.tscn -- --mode sixway --capture /tmp/sixway.png
Godot --path . tests/harness/lighting_lab/lab.tscn -- --mode selected --twilight --capture /tmp/selected.png
Godot --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_luminous_sources.gd,res://tests/test_canopy_shadows.gd,res://tests/test_biome_mist_precision.gd -gexit
```

The default mode is control. Modes are baseline (legacy lab toggle, not a foundation comparison), control, native, geometry, geometry-soft, screen, sixway, sixway-soft, raymarch, combined (native + decorative beams), and selected (native + six-way). `--sun-facing` and `--low-camera` provide alternate angles. The original eight-image candidate batch shares one camera and common HDR-source control; the later selected twilight image additionally enables actual lantern glass and local-light shadows.
