# October 4: all Pure Village prefabs reconstruct from stock

The missing storefront pieces were already supplied by the pack. Door leaves live
in `Models/Doors`, and the complete glazed storefront lives in
`Models/Structures/StoreFacade2.glb`. Restricting the inventory to `Architecture`
missed them. The exporter now accepts multiple stock directories and records an
explicit `module_source` on each part; the reconstruction oracle uses that path.
No glass mesh, texture, or substitute door was invented.

Adding Structures revealed a real source variant: House_16c modifies the stock
HouseStairs3 assembly. Replacing it wholesale fails the geometry/pose proof. The
exporter now descends a nonmatching assembly and independently proves each child.
It retains the authored stone block and two stair pieces instead of dropping the
assembly or accepting the wrong stock structure. Mesh-bearing mismatches still
remain incomplete unless their own geometry can be proved.

## Evidence

- Python inventory/extraction: **13 tests pass**, including the actual modified
  staircase and both complete storefront instances with explicit source paths.
- Godot focused reconstructions: **3 tests / 7,861 assertions**, covering House_16c,
  House_11c, House_6b and StreetHouse_8c.
- Engine corpus: **49/49 houses, 5,905 meshes, 7,704,699 vertices** reconstructed
  with matching world vertices, normals, UVs, indices and active materials; no
  omitted or duplicated source mesh. The initial run proves 48; the new staircase
  fallback proves the remaining House_16c. Both raw runs and their combined report
  are saved. The final exporter is checked against these exact verified inputs.
- House_6b front/back native renders inspected against matching source cameras.
  Pixel differences: 86 / 43 of 1,440,000 pixels; maximum 5 / 3 channel values out
  of 255. Storefront glazing, door leaves, paired dormers and roof joins survive.

The same complete-corpus command from the preceding review now exits successfully:

```sh
python tools/building_grammar/export_prefab_derivation.py \
  assets/PureVillage/Models/Houses --output /tmp/pure-corpus-all.json
Godot --headless --path . -s tests/harness/suntail/native_prefab_corpus_probe.gd -- \
  --input /tmp/pure-corpus-all.json --output /tmp/native-corpus-all.json
```

The visual harness accepts `--fixture` for either storefront fixture.

## Scope still open

This completes source reconstruction coverage for Pure Village, not randomized
production admission of every example. Safe connection variation, party-wall
context, native terrain/entrance support, and whole-town quality still need work.
Existing production sampling is unchanged by these exporter/oracle changes.

An initial read-only Suntail extraction including furniture reaches five complete
houses; House_2/5/8 retain a Cupboard_1 assembly mismatch. Engine verification and
the reason for that changed internal pose remain open. Its raw initial report is
saved separately. The roof–stair corner repair and broader redesign remain open.

Follow-up inspection of Suntail House_2 identifies a drawer state: the cupboard
body is unchanged, while child `Cupboard_1_Box` moves along local Z from
0.3322172165 to 0.4930000007 (0.1607827842 m). Its local Y remains 0.4810000062.
A bounded drawer-slide rule can represent this source variant; arbitrary mesh
pose replacement is unnecessary. The other two houses still need comparison.
