# September 29 town review — materials stream

Owner photos 3, 5 and 7 (seed 2697992464, Town A = city 1260018864828801968
compact, frame origin (306, 12.08, 1088), yaw 0). Photo cameras were rebuilt
from the F3 readouts with the close-camera rule (pivot = player + 3.2 m, boom
8.2 m through the crosshair, fov 75) and rendered with
`tests/harness/suntail/kit_town_review.gd --frame … --view …`; the three
renders reproduce the photographed geometry.

## 1. Stairs, ramps, rails and landings in a second timber family (photos 3, 5)

**What was wrong.** Every vertical public transition (flights, ramps, the
landing plates the builder owns, and their side guards) is one generated
collision mesh from `WarrenTransitionSurfaceBuilder`. The kit adapter
redraws legacy *instances* (`KitSubstitution`), but surface meshes passed
through untouched, so the renderer drew them with the legacy
`FeatureCommitQueue.transition_plank_material` (SFV plank swatches: pale
yellow) and the chunky generated 0.14 m guard beams, next to Suntail
`floor_2` decks and `wooden_railings_1` landing rails. The structural deck
skin under the kit boards likewise kept a flat legacy plank colour. Gate
approach flights (`build_gate_approach`) bypass the payload entirely and had
the same look.

**Fix (root cause: the kit layer did not own generated public timber).**
`KitSubstitution.redraw_public_surface` is the kit's rule for generated
public walking surfaces:
* the mesh keeps its exact vertices and collision (traversal authority),
  takes the kit deck board's own material (`material_asset_id`
  = `deck.board`), UVs scaled to the neighbouring deck's plank width, boards
  laid across a flight, and tangents for the deck's normal map;
* a flight's guard triangles leave the render (their collision stays) and
  the kit railing (`rail.low`, closing `rail.post`) is placed along each
  exposed top-rail span, sheared onto the slope (plumb posts, rails follow
  the flight, top at the guard's collision height).
`WarrenTransitionSurfaceBuilder._append_side_guards` now records the two
facts the kit needs: `guard_index_ranges` and `guard_spans` (top/foot line of
every exposed top-rail span). `KitSubstitution.apply` redraws transitions and
the structural skin; `VillageWarrenFabricSolver` redraws gate approaches and
adds their railings as world entries. The legacy (non-kit) render is
unchanged.

## 2. Timber truss arch embedded in the walls (photo 5)

**What was wrong.** `WarrenTunnelArches` (Sept 9) placed the SFV
`sfv.fabric.tunnel_arch.001` frame at every covered-passage mouth between two
masonry banks. In kit towns the frame sat inside the kit wall faces.

**Fix.** Removed per the owner: `WarrenTunnelArches.gd`, the
`SettlementFabricPlan.tunnel_arch_placements` channel (placements, asset
demand, construction signature) and the adapter asset demand. The frame was
computed after solid/void classification and reserved nothing, so no
reservation is left dangling; the bore, its ceiling closure
(`kit.tunnel-ceilings`) and the walk are unchanged. The superseded
`tests/test_september9_tunnel_arches.gd` is deleted. Path arches
(`sfv.entrance_arch.001` biome gates) are unchanged: they are road props kept
144 m from every village node, never part of a town payload; the test pins
that no arch/gate asset is in any town payload.

## 3. Ground stone course: two stone walls, jogs and offset posts (photo 7)

**What was wrong.** The photographed band is the retained massif's course
(`kit.retained`, flush `stone_wall`, sunk one band). Houses standing on it
count as terrain-bearing, so 40 % of them took a stone ground storey — the
deep masonry (`*_deep`, 0.2 m native proud since Sept 27). Result on the same
wall line: a flush course under a deep stone storey (0.4 m world jog), the
course's corner post and the storey's girth-grown corner post 0.26 m apart
("doubled posts"), two brick fields meeting at a ledge, and 12 m of stacked
stone. Survey (flush/deep pairs on one wall line): Town A 18, Town B 20,
3:standard 31, 7:standard 6, 4:large 13, 2:compact 26.

**Fix.** A house whose terrain storey stands on the podium (cells walled by
`kit.retained` / `kit.tunnel-ceilings`) is not given a stone ground storey
(`KitVillageBuildings._podium_cells`, `stone_chance` 0): the course is its
masonry base. Survey after: 0 in all six towns; the course reads as one
plinth under timber/plaster, stone stays low and sparse. The owner's other
photo-7 point (a sheer multi-storey outer face) belongs to the "edges" stream.

## Evidence (JPGs on disk only, this directory)

* `p3_before.jpg` / `p3_after.jpg`, `p5_before.jpg` / `p5_after.jpg`,
  `p7_before.jpg` / `p7_after.jpg`: photo-angle renders of Town A.
* `pair_*.jpg`: before|after street/orbit views of Town A, 3:standard,
  7:standard and 4:large (collateral check; no new artefact seen).

## Tests

* New `tests/test_september29_town_materials.gd` (5 towns): kit timber on every
  public walking surface + no legacy public/arch pieces; flight guard collision
  kept and kit railings drawn; no arch frame in a town; no flush/deep masonry
  jog. Red on the baseline (3 of 4 tests), green after.
* Focused regression files: see the table in the final report / commit.

## Open

* `.godot/warren_maze_mode_sweep.json` is fingerprinted against the fabric
  directory; any fabric edit (this one included) needs the mandatory corpus
  sweep re-run before `test_warren_maze_composition::test_corpus_composes`.
* The retained course still has one-cell outline jogs and narrow railed ledges
  where the house above steps back; that is outline/massing (edges stream).
* Live-world capture not re-run (8-10 min cold start); verified with the
  kit review harness at the production frame.
