# October 4 — complete Suntail source reconstruction

All eight original Suntail houses now have complete stock derivations and pass
independent Godot reconstruction: **3,003 meshes / 883,306 vertices**, including
matching normals, UVs, indices and source material bindings. No source mesh is
omitted or duplicated. This complements the prior 49/49 Pure Village result.

The three missing instances were Cupboard_1 drawers. House_2, House_5 and House_8
use local-Z extensions of 0.1607827842, 0.1627827883 and 0.1747828126 metres.
The cupboard body, drawer geometry, orientation and local X/Y are unchanged.
The exporter now recognizes a single bounded sliding joint: it requires exactly
the named body/drawer hierarchy, proves every mesh and relative transform after
posing, and allows only outward local-Z travel up to half the measured drawer
depth (0.592047 m). It still rejects changed geometry, rotations, scale, lateral
motion, reverse travel and extra/missing children. This is an authored mechanical
connection rule, not arbitrary per-mesh pose substitution.

The extraction oracle applies that joint to the independently loaded native
stock before comparing the entire building. Production town admission has not
changed; complete source coverage is not a claim that all eight families are
randomly sampled in towns.

## Validation

- Python inventory/derivation suite: **15 tests pass**, including a portable
  raw-GLB cupboard fixture with changed-geometry and hierarchy negative controls.
- Existing Pure Village engine regression: **3 tests / 7,861 assertions pass**.
- Suntail engine corpus: **8/8 pass**, saved in engine-corpus.json. All 160 staged
  model files have identical SHA-256 hashes to the original files (source-hashes.json).
- House_2 matching front/back source and reconstructed renders inspected.
  Front: 25 changed pixels, maximum channel difference 3/255. Back: 15 pixels,
  maximum difference 6/255. Exterior overhangs, roof valleys, dormers and entrance
  remain faithful. Source-export materials are identical on both, not final game
  material/art acceptance.

External sources were staged unchanged in `/tmp/suntail-prefab-oracle` with the
pack's textures, then imported as a standalone temporary Godot project. Direct
runtime loading from the original project was rejected as verification because
its texture import sidecars pointed at unavailable cache files in this checkout.
The isolated import and final corpus have no missing source-model/texture errors.
The sandbox disallowed unrelated editor-settings writes during import; those
settings are not needed by the oracle. No original pack files were changed.

## Remaining work

Only three Pure Village architectural families are currently admitted to the
production grammar. Additional architectural families need connection variation,
complete planner reservations, entrance/terrain support, collision and native
visual review before admission. The wider town redesign remains open.
