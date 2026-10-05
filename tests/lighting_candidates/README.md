# Lighting candidates

Pinned repositories and commits are recorded in `manifest.json`. These are review integrations, not automatically enabled editor plugins. All four can be rendered in `tests/harness/lighting_lab/lab.tscn` using `-- --mode <mode> --capture <absolute.png>`.

| Mode | Source | License | Adaptation / disposition |
|---|---|---|---|
| `screen` | ARez2/compositor-effect-lens-effects | MIT | Namespaced classes; Godot 4.5 scene UBO; runtime compilation to avoid headless import artifacts; renamed a function conflicting with Metal; dispatch bounds guard. Optional trial only. |
| `geometry` | joryleech/Godot-Fake-Lightweight-God-Rays | MIT | Original VisualShader and textures, adapted resource paths, placed on uncapped cones. Not enabled in the game. |
| `geometry-soft` | Geometry approach above | MIT inspiration | Separate analytic material with scene-depth fade, soft view/length edges. Still decorative: it does not query tree shadow maps. |
| `sixway` | TheAenema/Godot-Six-Way-Volumetric-Shader, Hamid Memar | CC BY 4.0 | Original shader with original procedural test maps; upstream demonstration textures are not distributed. |
| `sixway-soft` | Hamid Memar adaptation | CC BY 4.0 | `terrain/materials/six_way_mist.gdshader`: correct linear scene-depth fade, negative-Y channel, near/distance fades. Adopted as sparse biome wisps. |
| `raymarch` | MangoButtermilch/Godot-volumetric-renderer | MIT | Original performance-mode shader, generated 3D noise, tuned step/density/brightness. Optional trial; no scene-depth integration. |
| `native` | Godot Forward+ | Engine | Shadowed volumetric fog; adopted. |
| `selected` | Native + adapted six-way | Above | Combined comparison. `--twilight` shows lantern/orb contrast. |

Upstream source headers and licenses are preserved in each directory. The Godot 4.5 scene-data include is from `godotengine/godot` tag `4.5-stable` and covered by `ARez2/GODOT_LICENSE.txt`. ARez's retained headers additionally credit pink-arcana's compositor base and linked Shadertoy sources. No downloaded asset pack was needed: materials reuse the game's existing Meadow normal/SMA textures and lantern palette.
