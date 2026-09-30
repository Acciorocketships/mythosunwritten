# September 27 judging pass: roofs (stream `roofs`)

## Proposed AGENTS.md paragraph

> September 27 roof closure (owner review, seed 2697992464, photos 1/2/4/5/10/11/13;
> towns 1260018864828801968:compact near (312,1056) and 85830433957479026:compact
> near (-216,1152)). Five root causes, fixed in the kit layer. (1) Joined wings:
> `KitRoofJunctions` is now the one branch rule, also inside a house (the
> designer calls it; `_join_cross_wing`/`cross_extension` are gone). A wing
> whose end meets a host of the same eave that spans its width becomes a
> branch: perpendicular branches run to the host's ridge line and are clipped
> there (`clip_min`/`clip_max`, honoured by `KitRoofMeshUnion`), so an
> equal-depth branch no longer pokes its open end out of the far slope (the
> "inverted dormer"); a narrower parallel neighbour (stepped roof) runs into the
> deeper one instead of laying both verges on a coplanar slope. Skywalk
> bridge-house roofs keep closed gables unless a host buries them. (2) Gable
> walls are trimmed only by another building's enclosed attic
> (`KitRoofMeshUnion.enclosed_volume`) or solid walls, never by a neighbour's
> padded skin volume or public headroom (`walls` entries flagged `open`); both
> had cut see-through holes (photo 1: the deck headroom box ate the gable's
> outer face). (3) Walking clearance over public floors is the player's
> `TraversalEnvelope.MIN_HEADROOM` (2.4 m), not the planner's two-band (6 m)
> headroom: the two-band box cut the flared eave of every roof over a
> deck/lane off at the wall line, leaving a see-through slot under the roof
> (photo 11; 282 eave pieces corpus-wide). (4) No roof wing is one module deep
> (`BuildingDesigner._absorb_slivers`): a strip joins the neighbouring
> rectangle or grows across its short side when the grown roof adds only crown
> cells or at most one module strip of free, non-forbidden air. Roof area over
> free air is a porch/loggia: `_porch_posts` puts a timber post (with stone
> footing) at every vertex of that air no wall touches, standing on the own
> floor or ground at most two storeys down, clear of reserved/public space and
> flights; a merge whose posts cannot stand is rejected, and a strip that still
> cannot join becomes a flat boarded roof (rail-less deck). (5) Secondary wings
> orient toward the main before the fit check (`_wing_axis`). Invariants,
> measured on realized union-trimmed pieces by `tests/fixtures/kit_roof_audit.gd`:
> every open wing end buried, every closed gable closed by outward-facing gable
> geometry unless enclosed, no one-module roof beside a deeper roof, every free
> corner of roof-sheltered air carries a post to the eave, no eave stripped of
> more than half its overhang by walking clearance. Corpus
> (`tests/harness/suntail/roof_defect_survey.gd`, 50 towns): exposed open ends
> 563/837 -> 0/610, gable ends with holes 258/4383 -> 4/4028, eaves cut open
> 282 -> 0, one-module roofs 379 -> 63 (beside a deeper roof 205 -> 32), roofs
> over free air 182, all posted. `test_september27_roofs` (red on the baseline).
> Open: 32 cross-house slivers, 4 residual gable samples, standalone lot
> houses still skip the mesh union. See
> `docs/qa/2026-09-27-judging/roofs/result.md`.

## Sites and reproduction

Before/after image sheets (`*_before_after.jpg`, left = baseline db59f0c8,
right = this branch) sit beside this file in the worktree; `docs/qa/**/*.jpg`
is gitignored, so they are local evidence only.


- Town A (photos 1, 2, 5): city seed 1260018864828801968, compact, world frame
  origin (310, 12.08, 1088), yaw 0 (`VillagePlan.warren_seed_for_cell`, super
  cell (0,1), settlement cell (13,44)).
- Town B (photos 4, 10, 11, 13): city seed 85830433957479026, compact, world frame
  origin (-222, 12.08, 1180), yaw 180 (super cell (-1,1), cell (-9,48)).
- Renders: `tests/harness/suntail/kit_town_review.gd --frame <world frame>
  --ground-y 12 --view ...` (flat ground, production kit payload). Photo cameras
  are the close camera: pivot = player + 3.2 m, eye = pivot + 8.2 m away from
  the crosshair, fov 75 (photo 1 uses a 4.5 m boom: the flat review stage has
  no collision to shorten it). Photo 10 has no crosshair hit; its roof (the
  landmark.02 gable end) is shown from two nearby cameras instead.
- Roof ownership was identified by tint/hide renders and a CPU ray pick against
  roof volumes (scratch tools, not versioned).

## Root causes, changes, evidence

### 1. Branch ends not buried (photos 2, 5; "inverted dormers", see-through mini gables)
Root cause: `KitRoofJunctions` extended a perpendicular branch by
`gap + ceil(depth/2)` modules and the designer by `cross_extension` clamped to
half the host depth, regardless of where the host's ridge is. With half-module
roof pieces the branch end landed half a module past the host ridge whenever
the host was as deep as the branch (or one module deep): the branch ridge stood
up to 1.5 m out of the host's far slope with its open end visible (photo 2
right house, house.000; photo 5 house.011's 1x1 arms on a 4x1 host). The
designer's `_join_cross_wing` additionally opened wings without checking that
the main spanned them.
Change: `KitRoofJunctions.join` is the single branch rule (designer calls it per
house, `KitVillageBuildings` for the town). `host_gap` requires the host to span
the branch's width and to be at least as deep (perpendicular) or strictly
deeper (parallel). `open_into` runs a perpendicular branch to the host ridge and
records `clip_*`; `KitRoofMeshUnion` truncates the wing's skin volume and clips
its own pieces at that plane (`clip_volumes`). Collinear merges carry the clip.
Evidence: `p2_dormer_triangle_before_after.jpg`, `p5_house011_*`.

### 2. Gable walls cut open by neighbouring volumes (photos 1, 13, 5)
Root cause: `KitRoofMeshUnion` trimmed every roof-role piece, gables included,
by every other roof's padded skin prism (+-1 m past its gables, 0.6 m past its
eaves) and by every `walls` box, including public route headroom. Where a gable
sat under a neighbour's overhang or beside a walkway, its panel was removed
although nothing enclosed that space: see-through holes, visible rafters. Photo
1: house.009's west gable faces the deck; the deck's headroom box removed the
gable's outer face (11 hole samples). Town 3:large shows maze_back.14's gable
with sky through it.
Change: gable pieces are trimmed only by other roofs' `enclosed_volume` (inside
their own walls, under their skin) and by solid wall boxes; route headroom boxes
carry `open = true` and never trim a gable (they still trim eaves hanging into a
lane).
Evidence: `p1_deck_gable_before_after.jpg`, `large3_gable_holes_before_after.jpg`.

### 3. Tiny roofs at the edge of big roofs (photos 4, 5, 10, 11)
Root cause: crowns are decomposed into rectangles and every rectangle got its
own roof. One-module strips (landmark nubs, U-shaped crowns, L arms) became
ridge-top-only roofs (1.62 m tall) perched at the edge of the main roof, often
with their gables pushed into it.
Design rule (new): no wing is one module deep. `_absorb_slivers` merges a strip
into the rectangle it shares an edge with (bounding box) or grows it across its
short side, scoring crown coverage first and sheltered air second; air cells
must be outside the storey and every own/other/public claim, pass `_roof_fits`,
and stay within one module strip (or the absorbed crown). A strip that still
cannot join the larger wing beside it becomes a railed terrace. Photo 4's 2x1
nub now extends the landmark roof by one module; house.011's U crown is one
4x2 roof sheltering its recessed front.
Evidence: `p4_tiny_edge_roof_*`, `p5_house011_front_*`, `p10_landmark_gable_end_*`.

### 4. Stepped roofs laid over each other (photo 13, circle 1)
Root cause: a narrow roof ending against a deeper parallel roof (house.000 ->
maze_back.00, shared eave line) kept both gables; the deeper roof's verge lay on
the narrow roof's coplanar slope and the two colours met in a seam.
Change: parallel branch (host strictly deeper and flanking): the narrow roof
opens into the deeper one, takes its colour, and the host's verge is trimmed
where it lies on the branch's slope. The deeper gable still rises above it.
Evidence: `p13_stepped_roofs_*`, `p13_front_gable_zoom_*` (right).

### Skywalk bridge-houses
`_skywalk_mass` forced both roof ends open; where an endpoint house is lower the
open end was see-through (28 exposed samples per end in the corpus). Ends are
now closed gables (trimmed inside a taller endpoint's walls) unless a same-eave
host buries them.

## Coordinator follow-up (supported porch roofs, photo 11)

### A. Roofs over free air need support
Root cause: `_absorb_slivers` (first pass) let a merged roof shelter a
one-module strip of free air with nothing under its outer corner (the
landmark.02 corner of photo 10; 590 of 1000 lot roofs sheltered some air, all
unsupported). Change: `BuildingDesigner._porch_posts(mass, rect, eave)` returns
one `post` decor item (existing stone footing + stretched timber post, the
same vocabulary as projecting-room corner bearing) at every vertex of the
sheltered air that no wall of the storey below touches. A post stands on the
highest own floor below or the house ground band, at most two storeys down
(a porch, loggia or double-height veranda, never a stilt through a tower),
and every cell around it must be free of `forbidden` (public air, other
owners, retained structure), `covered` and `flight` (stairs, ramps, gate
flights) for its whole height. The sliver scorer rejects any merge whose posts
cannot stand; the unmergeable strip becomes a flat boarded roof (rail-less:
nothing reaches it, so it is not a railed terrace; the balcony-door test now
skips rail-less decks). A first version limited posts to one storey: 22
one-module lot roofs came back and 3-storey L crowns became doorless railed
decks, so the limit is two storeys.
Also fixed: `KitStandaloneHouse._dress_terraces` read `deck.open_edges`
directly; decks without that key crashed it.
Evidence: `p10_porch_posts_zoom.jpg` (two posts on the balcony under the
landmark corner), `lot_houses_porch_posts.jpg` (left baseline, right after:
porch posts under merged roofs).
Numbers: corpus roofs over free air unsupported: first pass 198/198, now 0/182
(the baseline merged no slivers, 0); lot houses (800): one-module roofs 438 -> 0, roofs
over air 502, all posted (test asserts it on 144 lot designs).

### B. Photo 11 (top-right circle)
Pixel comparison of the owner's frame with the baseline render
(`p11_eave_slot_owner_vs_render.jpg`, crop matched through the canvas and
camera scale): identical geometry. The roof is house.002's own 2x2 roof
(eave band 3) over its own storey; the storey below the eave is complete. The
gap is not free air under the roof: the eave piece was cut away. The deck in
front of the house is a public floor, and `KitVillageBuildings` added a
walking-headroom box of `WarrenVolumePlan.HEADROOM_BANDS` (2 bands = 6 m in the
world) over it; the house wall rises only one storey above the deck, so the
eave (flaring 0.6 m below the eave line, overhang 1 m) lay inside the box and
`KitRoofMeshUnion` stripped it to the wall line: the roof ended flush with the
wall top and one saw past the end of the wall into the space behind, under
the roof edge. CPU ray picks confirm: the pixels just left of the wall hit only
headroom boxes until the ground behind.
Change: walking clearance is the player's `TraversalEnvelope.MIN_HEADROOM`
(2.4 m world = 1.2 native m) above each public floor; an eave is trimmed only
where it would reach a walker's head (open boxes now also cut roofs whose eave
lies above them). The eave of house.002 now extends past the wall as on every
other roof (`p11_eave_slot_fixed.jpg`, rows: photo angle, ground-level front
view head vs after, landmark corner head vs after). Audit metric `eaves_cut`
(eave pieces losing more than half their overhang to walking clearance):
baseline 282, first pass 287, after 0 over 50 towns.

## Tests (red -> green)

`tests/test_september27_roofs.gd` (baseline 0/4, now 4/4):
- equal-depth branch buried at the host ridge (photo 2/5 geometry);
- stepped parallel wing runs into the deeper neighbour, no holes;
- crown slivers (three nub shapes) merge, no one-module roof, nub covered;
- both photo towns: tiny = 0, open_exposed = 0, gable_holes = 0,
  air_unsupported = 0, eaves_cut = 0;
- (follow-up) lot designs (3 sizes x 4 dirs x 12 seeds): every roof over free
  air is posted, and porch roofs still occur.
Red check of the follow-up: on the first-pass commit (1c506d29/289af28e) the
photo-town test fails (house.011 unposted air, house.002 / house.009 eaves
cut) and the lot test fails on most designs.
Updated pins: `test_kit_roof_junctions` (branch now reaches the host ridge:
extend 3 + clip 2.0 instead of the old extend 2); `test_town_architecture`
crown collision probes moved off module seams (the merged roofs put exact
instance boundaries under the old probes; Godot's ray kernel is ambiguous
there, as the junction test already notes), and the cross-gable test now
checks several lot sizes and asserts it checked something (it had gone vacuous).
Unchanged and passing on both trees: test_building_kit 8/8, test_town_depth 4/4,
test_town_layout_field 6/6, test_town_canopies 2/2, test_town_closures 4/4,
test_town_court_enclosure 2/2, test_september22_roof_gables 1/1,
test_september22_roof_joins 4/4, test_warren_roof_profiles 2/2,
test_village_frame 3/3, test_september19_prefab_stair_guards 2/2.

## Corpus statistics

`roof_defect_survey.gd` (seeds 1-12 x 4 scales + 2 photo towns; audit on the
realized union output; baseline run on a clone with only the audit plumbing):

| metric | baseline db59f0c8 | after |
|---|---|---|
| roofs | 2610 | 2319 |
| open ends exposed / open ends | 563 / 837 | 0 / 610 |
| closed gables with holes / gables | 258 / 4383 | 4 / 4028 |
| one-module roofs | 379 | 63 |
| ... beside a deeper roof | 205 | 32 |
| roofs over free air / unsupported | 0 / 0 | 182 / 0 |
| eaves stripped by walking clearance | 282 | 0 |

Per-town table: `survey.txt`; remaining cases: `survey_after_examples.txt`.
Lot houses (`KitStandaloneHouse`, not in production): 800 designs, one-module
roofs 438 -> 0; 502 of 980 roofs shelter some air, all on posts; multi-wing
crowns 544 -> 118.

## Falsification

- Same-angle before/after renders for photos 1, 2, 4, 5, 11, 13 plus photo 10's
  gable end from two cameras and house.011 from the front (jpgs here).
- Other towns: orbit/overview renders of 2:standard, 6:large, 1:grand,
  9:compact (`collateral_orbits_*`): no new holes or floating pieces seen; fewer
  perched roofs, joined roofs now share a colour. Lot-house gallery
  (`lot_houses_*`): tiny side roofs gone, roofs extend over terraces.
- The first gable-hole metric counted any projected triangle as cover and so
  missed photo 1 (only the outer face was cut); it now counts outward-facing
  triangles only, and samples avoid exact band/module boundaries (a sample on a
  shared storey-box face produced a false hole).
- Rejected intermediate: letting a sliver grow into air one axis at a time left
  2x1 strips grown into air that could no longer merge; growth must now produce
  a proper (>= 2 deep) rectangle and air is counted only once.

## Remaining / open

- 32 one-module roofs remain beside another house's deeper roof: crowns that
  are one module wide as a whole (narrow houses, bridge-houses) standing next
  to another house's roof; the rule acts within one crown only.
- 4 closed gables keep a few uncovered samples (landmark/maze_back ends); not
  individually diagnosed.
- A gable panel standing over a porch strip is now carried by posts, but the
  wall line under it stays open (it reads as a gabled porch).
- `KitStandaloneHouse` (hamlet lots, not produced by `VillagePlan`) does not run
  `KitRoofMeshUnion`, so its branch clips are ignored there (as before).
- Collateral renders show a tall white wall slab without a roof in town
  2:standard (present on the baseline too); not investigated here.
- The half-module verge overhang (authentic to the Suntail House_1 replica)
  still shows rafter undersides from low angles; not changed.
- `KitRoofJunctions` gained a `class_name`: run `--import` after merging. No
  kit asset or roof-geometry rebake was needed.
