# Authored collision overrides

This directory is reserved for collision-only Godot scenes used by a manifest
`collision_source` entry when none of the reviewed single-shape profiles can
represent an asset well. Author only simple convex primitives in the source
scene's native coordinates; the bake composes the manifest scale and pivot
exactly once.

Reviewed KayKit tree and rock proxies currently use the original wrapper scenes
under `terrain/gltf/` as bake-only collision sources. LPFV nature and the first
KayKit rock use generated single-shape profiles. No runtime asset depends on a
collision-source scene.
