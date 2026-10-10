# Full native projecting street-house derivation

`PureVillageJettyRoof` encodes the short-cornice roof family over a one-metre
projecting gable. Native three-metre courses, both cornices, short back verges,
long front verges, ridge and both gable closures all derive from the same length.
The source's fixed ridge-end fit and roof seat are preserved. Length changes do
not stretch source panels or move the room independently from its roof.

`PureVillageStreetHouse` joins that roof to the previous projecting-room rule,
a two-storey timber host, side rows, opening bays, foundation courses and corner
ownership. Two longitudinal bays reproduce the entire StreetHouse_1 prefab,
including its door, shutters, supports, beams and every roof/gable mesh. The
rule loads only modular assets; it does not load a reference house. Longer
forms insert full native middle bays and move all end assemblies together.

## Validation

- Reference suite: 6 tests / 6112 assertions pass, including full House_4 and
  full StreetHouse_1 plus the component roof comparisons. Every reference mesh
  is matched once; world vertices agree within 0.2 mm, triangle indices, UVs,
  material assignments, albedo/roughness/metallic and texture paths agree.
- Independent triangle coverage: 1 test / 348 assertions pass for 2-, 3-, and
  4-bay houses. Rays probe both roof planes including longitudinal module seams
  and the long front cap, both side walls at both storeys, and projecting floor
  boards. This is sampled geometric coverage, not a manifold/collision proof.
- Native source/reconstruction front, back, underside and overhead renders:
  1, 1, 8, 0 pixels differ by more than 8/255. Mean channel error <0.00083/255.
- Native 3-bay novel form inspected from the same four directions. Courses,
  projection and underside stay joined; all source modules retain their materials.

## Limits

This is a successful second full-house derivation, not the full grammar or town
redesign. The reference's plain side walls are deliberately reproduced for the
reconstruction gate; that does not make blank extended facades acceptable for
production sampling. This family must gain compatible openings/compound wings
before a broad city distribution. Source-authored asymmetries and fixed joint
fits are documented rather than silently normalized away.

No production rollout yet. Native envelope reservation, floor/interior collision,
player access, roof intersections, corner towers, other pack families, full
corpus/holdouts and town integration remain open. Longer specimens test assembly
consistency; they are not a new preference for long rectangular buildings.
