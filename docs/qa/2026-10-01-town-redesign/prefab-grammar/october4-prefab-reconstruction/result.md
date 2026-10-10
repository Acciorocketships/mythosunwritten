# October 4: exact Pure Village reconstruction corpus

The exporter now reconstructs **47 of 49** original Pure Village houses completely
from independently loaded architectural modules. The earlier name-driven exporter
completed 44. Renamed finials in House_11c, StreetHouse_6 and StreetHouse_7 account
for the increase. Geometry coverage alone had already reported 47; this pass
proves complete posed assemblies, rather than merely finding matching meshes.

`stock_match` aligns complete stock by its measured geometry and then proves every
child's relative pose. It preserves explicit source material overrides. Matching
only a door leaf cannot import the rest of a door-and-frame assembly. The normal
named-module path remains unchanged; this is a fallback for unmatched mesh nodes.
The exporter accepts either one house or a directory for a reproducible corpus.

## Verification

- Python extraction/inventory tests: 11 passed, including renamed mirrored stock,
  explicit material overrides, extra-frame rejection and inconsistent child poses.
- Godot focused reconstruction: House_16c and House_11c, 2 tests / 4,993 assertions.
- Full engine corpus: 47 complete examples, **5,637 meshes and 7,377,955 vertices**,
  zero failed reconstructions. Compares each original/reconstructed mesh's world
  vertices and normals, UVs, indices, active materials and bounds. Every source
  mesh is consumed once; generated extras or missing source meshes fail.
- House_11c source/reconstructed front and back views inspected. Differences are
  100 / 95 pixels out of 1,440,000, at most 4/255 per channel. The complete native
  roof, finial, corner supports and facade survive the stock reconstruction.

## Reproduction

```sh
python tools/building_grammar/export_prefab_derivation.py \
  assets/PureVillage/Models/Houses --output /tmp/pure-corpus-derived.json
# Exit 1 is expected while two explicitly incomplete examples remain.
Godot --headless --path . -s tests/harness/suntail/native_prefab_corpus_probe.gd -- \
  --input /tmp/pure-corpus-derived.json --output /tmp/native-corpus.json
Godot --path . -s tests/harness/suntail/native_prefab_reconstruction_review.gd -- \
  --output /tmp/native-finial-review
```

## Remaining work

House_6b and StreetHouse_8c have three separate door-leaf instances and six glazing
quads not represented as standalone modular stock. They remain explicitly
incomplete, not silently dropped. Suntail reconstruction, additional randomized
connection rules, and admitting further complete families into town planning are
still open. This expands the verified source examples; it does not register all
47 as production town variants or establish visual quality of arbitrary sampling.

Separately, rotating the outstanding photo-town roof was measured and rejected:
it clears the eave by putting the closing gable wall through the stair headroom.
The raw result is saved in `rejected-roof-axis.txt`; production was not changed.
That corner repair and the wider October 1 redesign remain open.
