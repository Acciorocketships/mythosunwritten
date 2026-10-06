# Native roof derivation: first reconstruction rule

`PureVillageNativeRoof` takes ridge bay count and the supporting wall-top datum.
It derives both straight upper courses, both curved lower courses, their start/end
verges, ridge tiles and caps, and both complete curved/straight gable closures.
All modules retain their native dimensions and source materials. It does not load
a house prefab or copy a prefab-specific placement list. Changing length moves
all dependent end closures and generates the corresponding courses together.

The source family's 3 m ridge bay, 1.5 m upper run, 3 m upper rise and 125 mm
panel/gable seats are explicit interfaces. The gable pivot offset is axial and
must not be mirrored with its facing direction. Validated lengths are 1–8 bays;
this range is a construction limit, not a production town distribution. Long
unarticulated roofs remain contrary to the user's desired final architecture.

## Evidence

- 3 tests / 1954 assertions pass after formatting.
- House_1 roof/gables reconstructed from 2 bays and wall datum 3 m.
- Unchanged rule also reconstructs House_4 roof/gables with 3 bays. House_4 was
  inspected after the rule was written; this is a cross-reference validation,
  not a claim that a sealed blind holdout corpus has passed.
- Tests compare all selected mesh components one-to-one, triangle indices,
  world-space vertices (0.2 mm tolerance for source quaternion rounding), UVs,
  material names, albedo, metallic/roughness and albedo/normal/roughness texture
  paths. No missing or excess roof/gable mesh components.
- Matched native reference/reconstruction cameras: front oblique, reverse
  oblique, end, above. Only 5, 5, 6, 4 pixels respectively differ by more than
  8/255; mean per-channel differences below 0.0008/255.
- Novel 1- and 4-bay assemblies rendered from the same four directions.
  Inspected oblique/end/back/above views show continuous courses and closed
  gable ends. Roof-only fixtures intentionally omit supporting house walls.

## Scope and next work

This is one grammar family, not a complete building generator. It is deliberately
not connected to production: the native 3 m dimensions need a jointly reserved
building envelope and matching wall/floor grammar. Width/depth changes, junctions,
openings, dormers, towers, bearing structure, mixed-kit interfaces and full-house
reconstruction remain open. Do not substitute this elementary roof family for
rich production architecture or declare the October 1 goals complete.

Commands:

```
Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_pure_village_native_roof.gd -gexit
Godot --path . -s tests/harness/suntail/native_roof_grammar_review.gd -- --output /tmp/native-roof-review
```
