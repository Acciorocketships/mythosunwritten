# October 1 town redesign — work log

Status: implementation and iterative acceptance active; see the latest entries
for production-player/reentry proof and the expanded architectural refinement.
Plan: `docs/superpowers/plans/2026-10-01-town-redesign.md`.

## Baseline

- Revision `b8e130d9`, Godot 4.5.1.
- This isolated checkout initially lacked ignored GUT files and script UIDs.
  Copied GUT and existing-script UIDs from the primary checkout and reimported.
  No primary-checkout code was changed. Initial UID-warning-induced test
  failures are environment setup failures, not town regressions.
- `test_kit_roof_junctions.gd`: 8/8, 11,995 assertions, 4.433 seconds after setup.
- Photo world seed 2697992464; town seed 1260018864828801968; production size
  0.00000000498071 (effectively compact).
- Current production frame, independently obtained through
  `tests/harness/layout_judging/production_frame.gd -- 0,1`:
  `0,0,2.6666667,0,2,0,-2.6666667,0,0,306,12.08,1088`.
  The September 29 origin still applies but its yaw does not. Early renders
  in `before/` and `photo-before/` used the old yaw and are not matched evidence.
- `photo-before-current-frame/` uses the correct frame. The p2 render reproduces
  the photographed two roof ends protruding into the raised passage. Ground is
  the harness's flat stage; these images judge construction, not world terrain,
  grass, lighting or the complete streamed game.
- The two relevant roofs are rectangles `(-2,-4;4,2)` and `(4,-4;2,2)`, both
  ridge-axis X, eave band 2. Their gable planes bound a four-native-metre walk;
  each emits another native metre of verge (two world metres).
- The existing triangle union removes roof fragments in minimum walker
  headroom. It does not prevent the much larger roof ends visibly narrowing
  the elevated passage above that envelope. The repair must fit the roof end
  and its barge trim together, preserving closed gables.

## Reproduction

Use `/Applications/Godot.app/Contents/MacOS/Godot --path <this checkout>` with
`-s res://tests/harness/suntail/kit_town_review.gd --` and:

```
--cities 1260018864828801968:compact --production-size --views top
--frame 0,0,2.6666667,0,2,0,-2.6666667,0,0,306,12.08,1088 --ground-y 12
--photo p1:289,14.2,1089.3:317,20.3,1089.9
--photo p2:312.4,20.3,1096.9:319,19,1097
--photo p3:374.4,22.9,1030:352.5,12,1055
--output docs/qa/2026-10-01-town-redesign/photo-before-current-frame
```

`--photo` derives pitch from the player-pivot/crosshair ray and uses
`ReviewCam.solve_cam` for azimuth, with the current close-camera boom/pivot.
It does not simulate a collision-shortened boom. Original capture p2 is the
September 30 image, regardless of attachment order.

## Asset survey (preliminary, not approved integration)

`tools/environment_bake/survey_modular_pack.py` reads glTF node hierarchies and
transformed accessor bounds without loading renderer resources. The installed
Pure Village copy contains 1,909 models: 1,238 Architecture, 63 BigModules,
49 Houses, 49 HouseWarp, 75 Doors, 105 Props, 82 Furniture, 55 Garden, 51 Plants,
31 Structures, 9 Trees, and three other entries. This differs from its README.

`pure-village-measurements.json` retains selected measured examples and a
70-piece assembled-house hierarchy for learning placement rules. Full survey
is reproducible with the script (local scratch `/tmp/story-pure-village-survey.json`).
Bounds are transformed bounding boxes, not exact contacts. Examples:

- `Wall_Start_30x20_2`: about 3.309 × 2.227 × 0.407 m, 726 triangles.
  The README's suggestion that suffix numbers denote centimetres must not
  drive scaling: this is approximately a 3 m × 2 m nominal panel.
- `Window_8_1`: about 3.145 × 3.235 × 0.673 m, 5,078 triangles.
- `House_1`: about 7.595 × 11.403 × 7.751 m, 70 pieces, 66,149 triangles.

Do not map this pack blindly onto Suntail's 2 m × 3 m module convention.
Still required: native module joins, openings and corner gallery, collision,
material matching, bake manifest, and real mixed-kit buildings.

## First repair: raised-walk roof ends

The new photo regression failed on 1,110 native vertices protruding beyond the
two gable facades. `KitRoofJunctions.fit_public_verges` now reads final public
surface claims, after roof joins, and shortens closed roof ends beside walks
at their eave height or above. Ground-level streets keep their overhangs and
open roof branches keep their host overlap. Barge boards move with the shortened
end. The existing exact triangle union applies the end plane to rendering and
collision together; gable walls remain closed.

Validation so far:

- Photo regression: 1,110 protruding vertices → 0; gable holes remain 0.
- Four focused suites: **24/24 tests, 12,249 assertions**, 133.709 s:
  October 1 roof verges, roof junctions, September 29 skywalks and roof variety.
- Tests include both ridge axes, preservation of ground-level overhangs and
  open branch joins, and equality of final mesh/collision faces.
- `photo-after/*_p2.png` inspected against `photo-before-current-frame/*_p2.png`:
  the passage opens along the gable faces instead of retaining the two large
  wooden projections. P1 and a nearby ground-level street were inspected too.
  Additional orbit/street captures are saved for further review.
- Local town construction time is 2.322 s in the candidate visual harness;
  this is one diagnostic run, not a controlled performance claim.
- Full isolated sweep was stopped after exposing missing ignored character
  assets in this checkout (`knight`, `rogue`, `ranger`, `mage` dependencies).
  The partial summary is `partial-suite.txt`; it is not full-suite acceptance.
  The focused town suites do have their baked runtime dependencies and passed.
  The isolated runner now disables background niceness (denied by the sandbox),
  selects a writable engine log (avoiding Godot's user-log rotation crash), and
  retains per-file raw output for diagnosis.

This accepts the photographed roof-end correction at the focused-test level.
It does not yet certify every misplaced prop, stair clearance, or roof
intersection in generated towns, and it does not complete the redesign.

## Next work

1. Extend the remaining public-clearance audit to exact final flight geometry
   and props, without replacing the verified roof-end design fix with a larger
   headroom cut that opens attics.
2. Finish the curated Pure Village modular gallery. Six complete native houses
   and the initial props row were captured in `pure-lineup/`; `house_0.png` was
   inspected. The all-category legacy lineup was stopped during garden loading
   and is not accepted asset-wide evidence.
3. Prove facade assemblies and mixed-pack contacts before enabling a second kit
   in production. The measured source includes nominal 2×3 m plain-wall stock,
   while many opening panels are nominal 3×3 m; their joins need an explicit
   adapter rather than assuming every panel is interchangeable.
4. Continue the remaining layout, skywalk, fortification and dressing stages
   in the implementation plan. No changes to those production systems have
   been made in this first repair.

## Finished walking surfaces and facade studies

The next roof-clearance regression sampled finished stair tops, rather than
route bands: 11 samples lacked the full headroom volume before the change.
`KitPublicClearance` now constructs convex walking-air prisms from actual
public floor/ramp/tread triangles and exterior gate approaches. Guard tops,
vertical faces and undersides do not contribute. Roof union consumes these
prisms; its existing rule still prevents public air from cutting gable walls.

- Five focused suites: **26/26 tests, 12,257 assertions**, 91.914 seconds.
  This includes both October 1 files, roof junctions, September 29 skywalks
  and roofline variety. A synthetic slope test checks top/bottom/side bounds
  and exclusion of guards and undersides.
- `finished-clearance/*_p2.png` inspected: the roof-end repair remains closed
  and the passage stays clear. Three nearby street captures also saved.
- This does not yet prove clearance of every rigid decoration.

Pure Village native and baked module studies are in `pure-modules/` and
`pure-baked-modules/`. The initial six-panel manifest is self-contained at
runtime, with measured descriptors and triangle collision. Nominal 3 m opening
panels are cropped to the common 2 m width; their openings are not rescaled.
The native 2 m plain panels receive their measured pivot correction. Stone
arches, sills, shutter depth and native materials survive the bake.

`PureVillageBuildingKit` is an explicit candidate facade family with Suntail
roofs and structural timber. It is **not selected by production towns yet**.
The unframed candidate left plaster joints and large uninterrupted wall areas;
separate panel-joint posts and head beams now close and articulate these faces.
These optional kit roles leave Suntail assembly unchanged. The first complete
building views were reviewed, then rebuilt with framing under
`pure-buildings-framed/`; `b00_a.png` was compared with `pure-buildings/b00_a.png`.
The framed result reads more coherently, but closed shutters are too repetitive
and mixed-neighbour/stone-corner/player-scale acceptance remains outstanding.

- Candidate kit + existing kit suite: **10/10 tests, 563 assertions**, 10.352 s.
- Tests cover catalogue availability, exact two-metre joining width, collision
  presence, common world metric and one timber per internal panel seam.
- A catalogue ordering error introduced while minimizing generated index churn
  was fixed before the successful test and render runs. Entries must remain
  strictly sorted by asset ID.
- Six facade modules currently share about 97 MB of baked lossless textures;
  performance/texture-budget review remains necessary before release.
- Still needed: open-window variants, native roof grammar, broader Pure Village
  decoration selection, whole-town style selection and mixed-pack validation.

## Mixed-family production candidate

The facade candidate now participates in `KitVillageBuildings.build` by default.
`TownBuildingStyles` chooses one family for each merged house, using a separate
stable town mix (20–80% Pure Village expectation) and a house key. Neither world
coordinates nor the reported seed receive special production treatment. Public
feature masses keep the shared Suntail construction vocabulary. An explicit
`mixed_styles=false` build argument supports baseline comparisons.

The native window study (`pure-open/open_windows_front.png`) selected the small
recessed leaded window and tall arched opening. Eight facade panels are baked;
a house chooses one open-window family and uses closed shutters as a minority.
All use the common 2 m module, 3 m storey and structural contact datums. Roof
union now reads `BuildingKit.roof_geometry_path`, which the active roof family
owns; this hybrid deliberately still uses Suntail roof geometry.

Evidence:

- Six suites pass **28/28 tests, 13,024 assertions**, 52.031 seconds: Pure Village,
  existing building kit, finished clearance, roof verges, roof junctions and
  September 29 build-order determinism.
- A subsequent production ownership test plus the Pure Village tests pass
  **4/4, 739 assertions**, 9.828 seconds. The actual reported town contains both
  families; every ordinary facade panel agrees with its merged house's family.
- `mixed-town/` repeats the correct production frame and photo p2, plus street
  and overhead views. P2, street1 and overview inspected. Roof clearance remains
  visibly open; the nearby Pure Village masonry carries projecting stone
  surrounds beside the original timber family.
- `mixed-holdout/` captures seed 7/standard and 38/large. Street2 of both was
  inspected and provides useful mixed-frontage evidence. Street0 of seed 7 and
  street1 of seed 38 were camera-occluded close-ups and do not establish broader
  acceptance. All captures completed without script errors.
- Eight panels currently share 124 MB of lossless baked textures. Cost reduction
  and renderer profiling remain open. No claim of full-pack roof integration,
  all-neighbour clearance, or completed facade acceptance is made yet.

## Layout baseline before the next stage

`tests/harness/suntail/town_open_space_probe.gd` records twelve source plans in
`open-space-baseline.json`: seeds 7, 10, 38 and 1260018864828801968 at compact,
standard and large anchors. Six have no clearing (38 and the reported town at
all three sizes). Of the 45 sampled clearing-core cells, two are still massif
columns and one carries a final plot. This demonstrates both missing spatial
variety and the lack of an explicit reservation contract. Merely increasing
clearing strength would not fix the current single-connected-solid assumption
or preserve disconnected small-house sites. The next implementation must carry
open-space purpose/ownership and separate walking connectivity from solid mass.

## Open-space implementation iterations (not accepted)

`WarrenTownOpenSpaces` now creates explicit, seeded purpose-bearing circles
before boring. `WarrenMassif.open_spaces` and the derived volume retain their
geometry and intended use. Tests verify reserved cells never acquire plots.
This is foundational work, not completed layout acceptance: detached sites,
public access to courts and their dressing are still missing.

Iterations and evidence:

1. Unbuffered circles around protected crown/shoulder lines introduced useful
   gaps, but broke the reported compact town's perimeter lane, lost a landmark
   and reduced the platform population. Rejected. Images `open-layout/` and
   data `open-space-candidate.json` belong to that rejected candidate.
2. Fit circles inside the existing outer margin and away from the platform,
   which is now sampled before court removal. Existing edge/platform behavior
   passed, but only four reserved cells survived the initial four-town corpus.
   Rejected as insufficient progress toward useful open space.
3. Move circle candidates inward between shoulders. The twelve-town probe
   reports 16 reserved spaces / 61 cells / zero plot intrusions
   (`open-space-v3.json`). Two integration tests pass (665 assertions), but
   treating every court as a new rim lowered the surrounding massif; seed
   9/standard exhausted its spine DFS at 40,015 visits. Rejected.
4. Current work separates `height_domain` / `outer_ring_domain` from reserved
   construction air. Terrace heights are formed on the original outer town
   footprint, then court columns are removed; edge-height rules retain the
   original outer-ring distance. The seed-9 spine builds again and all four
   skywalk tests pass. The edge/platform/skywalk/integration run is **16/18**,
   with a missing landmark (6 vs the established floor 7) and an expected old
   non-platform signature mismatch still unresolved. A further massif run is
   **18/20**: old rim metrics count the newly declared interior court walls,
   including a 16-band face. Do not simply lower these tests: judge court
   scale, wall height, access and ground support before deciding which metrics
   should distinguish interior courts from the external town boundary.

The declared-hole test now permits *declared* courts while still forbidding
accidental punctures. No landmark threshold or frozen town hash has been
weakened/re-pinned. The new preservation test checks that unfortified massifs
retain heights and outer-ring distances around courts. Current v4 images are
under `open-layout-v4/`; earlier v3 overhead was inspected and showed green
voids within dense building districts, but does not approve v4 or court access.

Next: resolve court access and meaningful dimensions alongside low satellite
sites, retain landmark opportunities, inspect v4 ground-level court walls,
then repeat edge/skywalk and wider production build checks before acceptance.

## Low-neighbourhood experiment and next structural change

The v5 experiment widened each Gaussian's low skirt (independent seeded width)
and restricted at-grade courts to low surroundings. It passed the three new
reservation/preservation tests (3,552 assertions, 12.131 s), and the large-38
render in `open-lowlands/` showed more green breaks and low houses. The wider
regression rejects it: broad flat regions, missing spine plans on the reported
compact town and 3/standard, and a missing perimeter lane on 6/large. Large-38
also lost all source tunnel cells. Data: `open-space-v5.json`. The apron
expansion and low-only placement filter have been REMOVED from production;
these images and probe results are rejected-study evidence, not the current
accepted result. No thresholds were lowered.

The next change must separate route domain from building mass. Currently a
reserved court deletes a massif column, and `slot_is_borable` rejects any route
there because `has_column` is false. Thus a green is a hole the route planner
cannot cross, rather than walkable ground. A useful implementation path is an
explicit reserved-ground column kind: ground datum and open-sky walking domain,
no rock above ground and no plots, carried through the volume envelope as air.
This requires coordinated contracts in massif records, slot admission,
`solid_at`/`rock_shoulder`, plot blocking/admission, and derived volume heights.
Keep painted route strips separate from the remaining reserved ground so this
does not pave the whole green. Tests must prove route access, empty building
volume, preserved ground support, and unchanged occupied clearances; then tune
court-facing building heights without lowering unrelated massif peaks.


### Reserved ground route domain and local descent (October 1 continuation)

Implemented an explicit `reserved_ground` column record. It remains available
for a ground-level route, forbids elevated boring and all plot kinds, and has
no derived rock shoulder. Volume compilation retains its route envelope but
subtracts all above-ground mass. Tests inspect both `source.solid_at` and
`volume.has_mass`; they also test ground/elevated route eligibility with an
empty excavation (a finished route correctly refuses a second bore).

The first version preserved the whole surrounding envelope and passed the
three focused tests (1,832 assertions), but exposed tall faces at its circles.
Native `open-domain/38_large_overview.png` is a rejected layout: dense roof
blocks and a tall, nearly continuous frontage. Restricting circles to existing
low shoulders removed the cliff regressions (17/17 massif tests) but produced
only nine reserved cells in the four standard towns, below the useful-space
sample floor. Neither candidate is accepted as the final spacing design.

Current construction caps nearby envelope heights by four bands per Manhattan
step away from a reserved green. The sampler protects the upper 20% of the
original height envelope against this descent. This local rule preserves the
high massif and does not reinterpret every court edge as the global outer rim.
The focused plus massif suites pass 20/20, 14,710 assertions before the minimum
space-size follow-up. The test now demands preservation of the high massif,
not byte-identical low frontage that the new descent deliberately changes.
No existing maximum-step, cliff-face or landmark-count threshold was lowered.

`open-space-v7.json`: twelve towns all build, 18 spaces / 56 cells, 19 ground
passage cells within reservations, zero plot intrusions, 37 tunnel cells.
`open-local-grade` native renders inspected at overview and player height:
architecture is still too dense to approve the complete redesign, and grass,
trees and context props have not yet been added. The edge/skywalk/platform
suites pass 14/16: landmark total 6 instead of 7, and the historical unmodified
plain-town signature changes (expected from a layout change, not yet repinned).
All four skywalk tests and the substantive platform tests pass.

A follow-up now requires at least four occupied-domain columns per green,
rather than accepting one-cell nicks. This is a general usable-area rule,
not a reported-seed exception. The combined regression is currently running
in `/tmp/open-useful-greens.log`; its focused three tests and all seventeen
massif tests pass so far. Final regression results and a render of this exact
version still need review. The open-space sampler/route-domain design remains
under iteration; detached satellite houses and dressing remain outstanding.

Minimum-size follow-up result: 35/36 tests pass, 15,755/15,756 assertions
(`/tmp/open-useful-greens.log`, 62.267 s). All six platform tests now pass,
including the old no-platform signature without changing its pin. The only
failure is the landmark aggregate (6 < 7). The photographed compact town has
its asset again; the four-town census is 1, 1, 3, 1 landmarks respectively,
so 6/large is now the relevant candidate. Its three greens reserve 12, 7 and
4 columns. Audit via `/tmp/story-landmark-open-probe.gd` shows the reservations
and asset ids; candidate site availability must be reconciled with this larger
gap budget rather than weakening the test.

Native exact-version renders are in `open-useful/`. The 38/large overview was
inspected: the silhouette and frontages still need the detached/small-lobe
work, and these undecorated openings alone do not meet the owner's reference.
The native harness completes both towns. This is a tested construction
foundation, not an accepted final art result. No background renderer or suite
is intentionally left running at this checkpoint.

### Ground vegetation clearance (next continuation)

The previous turn made implementation and verification progress. Inspection of
production found a separate reason all town ground remained bare: the broad
`VillageWarrenFabricSolver` clearance envelope is read by the grass field's
point-distance mask. Natural surface alone cannot restore grass through that
reservation.

Production now publishes physical clearance from the sealed solid, walk and
guard occupancy alongside the unchanged broad envelope. Ambient placement
continues to respect that envelope. Grass instead queries its complete patch
footprint against physical clearance, ignoring envelope-only reservations.
This also prevents outer blades crossing walls when the root itself is clear.
`FeatureGroundField`/`FeatureContext.clearance_at` can distinguish these two
kinds for callers and diagnostics; default behavior stays conservative.

Validation: `test_october1_town_ground` plus the complete `test_grass_field`
suite pass 27/27, 688 assertions (12.889 s). New grass qualification coverage
proves acceptance inside an otherwise empty town envelope and rejection when
a nearby wall intersects only the grass footprint. A generated 10/large town
also exercises the real compiled occupancy projection in a dedicated test;
see `/tmp/town-ground-real.log` for its result. Ground paint remains the
existing actual terrain-street projection. Variable tree density, contextual
props, native-world vegetation renders and performance judgment remain open.
This change does not claim the complete ground/dressing stage is finished.

### Seeded ground dressing and tree profiles

Implemented `TownGroundDressing` after terrain grading and road connection in
production. It consumes the explicit reserved spaces, rolls an independent
woodland density with a true-zero urban share, and proposes trees plus
purposeful groups (seating, anvil/barrel workyards, tent/barrel market corners,
fire/bench gathering points). It uses catalog dimensions in world metres,
checks the entire occupied-domain footprint, rejects wet/uneven ground and
paths, reserves groups atomically, publishes clearance and solid occupancy,
and retains source asset collision. Initial families are LPFV, Suntail and
SFBP; surveying/baking decorations from the other new packs is still open.

The first whole-canopy 2D clearance rejected every tree in 6/large. Measured
the two LPFV meshes as conservative triangle bounds in 2 m height bands:
`TownTreeProfiles.gd`, reproducible with
`tools/environment_bake/survey_town_tree_profiles.gd`. Roots now use physical
ground clearance while every canopy band checks real solid/walk/headroom
volumes in 3D. Grass is excluded only by the root footprint; competing props
still conservatively keep out of the full canopy projection. This permits
one tree in the reviewed 6/large town. It is not yet a heavily wooded result.

Native images: `dressing-first` (10/large: two groups, four props; 38/large:
no fitting group, both urban rolls), `dressing-wooded` (rejected zero-tree
candidate), `dressing-canopy` (one tree, exposed white foliage tint bug),
`dressing-tinted` (correct biome tint, inspected overview). The trees use the
same world-seeded biome tint function as ambient trees. The reference's richer
foliage, more complete dressing, grass-rendered native world review and more
wooded layout remain unfinished. The harness ground here is still a flat
review plane, not the production grass field.

Fixed a separate runtime-demand omission found during integration:
`VillageProgram.compile` now registers both Pure Village opening families and
all dressing ids, including measured bounds. The earlier kit-only tests did
not cover production asset warming. Dedicated coverage now does.

Tests: `test_october1_town_dressing` passes 5/5, 472 assertions before the final
wooded-case substitution; it verifies true-zero/dense seed variation, catalog
geometry/collision, atomic obstruction rejection and grounding, actual groups
in generated greens, and production registration of both kit families. Final
combined dressing/ground run is `/tmp/dressing-verified.log`; the generated
wooded case reports one tree and one two-prop group and checks foliage tint.
The work remains an implementation candidate, not final visual acceptance.

### Small-lobe house sites and garden territory

The previous continuation made concrete dressing/runtime-registration progress.
This continuation implements the missing distinction between independent small
Gaussian bumps and merged massifs. `_classify_lobes` compares lobe area to the
crown and evaluates overlap against the original mixture. Small independent
lobes receive one/two-storey house metadata; the crown and overlapping lobes
remain massifs. Source plots and kit landmark caps share the ground-relative
house height limit. These columns permit ground routing only; unbuilt small
house territory retains no tall rock shoulder.

Rejected iteration: lowering the Gaussian amplitudes shrank the entire
planning footprint, dropped landmarks to two and introduced a rim regression.
The original amplitude/connected envelope now remains intact. A briefly tried
massif-only denominator did not pass the anti-slab test and was reverted;
no threshold was weakened. The current plateau diagnostic excludes declared
reserved-ground air from connected *solid* plateaus, because the route envelope
is not masonry. Existing numeric plateau limits remain unchanged.

Suitable house lobes now reserve a 2x2 core before boring. Other eligible lobe
columns become garden ground (explicit `kind = garden` reservations). Local
descent cannot lower the high massif. House cores stay out of boring, then the
ordinary plot partition supplies addressed houses. New tests check actual
occupied cores and real door walk cells across four generated large towns.
The platform footprint and two-column approach band take priority: without
that protection 3/compact lost its upper town, a rejected regression.

Validation before the platform protection: 23/23 lobe/open-space/massif tests,
18,870 assertions. After protection and the leafy tree change: 15/15 lobe,
platform and dressing tests, 1,549 assertions (`/tmp/lobe-platform-fixed.log`).
All four site tests and all six platform tests pass. The prior broad garden
candidate passed the four skywalk tests but still dropped landmark counts
(2 vs floor 7); landmark co-planning remains open. Do not claim this layout
stage fully accepted or repin that floor.

Native inspected views: `lobe-hierarchy` (low-height metadata only),
`lobe-gardens` (cores plus gardens), `lobe-leafy` (platform protection and leafy
LPFV 01/02 trees). LPFV 03 is a bare-branched tree and was removed from this
leafy garden mix; the measured-band generator and profiles now cover 01/02.
12/compact renders three leafy trees and a two-prop group; 6/large's CPU
construction check admits four trees and two groups. These are improvements
but not yet the requested heavily wooded town or full store-reference dressing.
The flat harness does not validate production grass/terrain joins.

### Landmark priority experiment (rejected)

Reserving the largest independent small lobe for a prefab restored one asset
in each of the four landmark review towns, but still missed the existing
aggregate floor (4 vs 7) and reduced occupied small-house sites to two in the
new corpus. Native `landmark-priority/3_standard_overview.png` was inspected:
the town remained a dense wall of roofs, with a peripheral prefab consuming
space without improving the garden composition. The whole-lobe reservation
was removed; no regression threshold was changed. Measured footprint
co-planning remains open. Test evidence: `/tmp/landmark-lobe-tests.log`.

### Additional-pack dressing, assembly and access

Added eight baked runtime assets from Alchemy, Crafting, Fantasy Market,
Forge, Tavern/Kitchen and Interior packs. `town_props.json` is the bake
manifest; baked provenance records source paths, measurements and budgets.
Selected source/import dependencies were copied from the primary checkout
without modifying it. Runtime uses only baked resources. Raygeas is the
Suntail source family, not a separate architectural style.

Inspected every asset in `props-lineup`, then repaired and re-rendered:
- Alchemy cauldron: imported material was missing its atlas. Explicit source
  atlas fallback restores the authored black/gold finish.
- Bakery: the named stall was only a canopy. Added the matching oven/counter
  assembly with its measured foot offset; native triangle collision leaves
  the space between the canopy posts open.
- Forge: the stand asset already includes its anvil. Rejected an accidental
  double-anvil composition; final source is the complete native stand.
- Herbalist workstation, vegetable vendor, furnished tavern table and both
  benches were judged usable as supplied. Final lineup: `props-lineup-final`.

The dressed spaces choose purposeful groups: workyards get forge or herbalist
uses, markets get assembled vendors, courtyards get a furnished table, greens
get seating or camps. New assets register automatically through the same
VillageProgram runtime-demand path. Existing tents/campfires remain available.
Trees and prop choices now have independent per-space seeded streams.

Rotated group testing exposed false self-conflicts from world-axis bounding
boxes. Prop clearance now uses the exact oriented projection of the measured
box; domain/terrain checks retain conservative outer bounds. No collision or
path-clearance rule was disabled. Group proposals still commit atomically.
Vendor fronts choose a ground street through a player-width approach that
misses solid/guard volumes at walking height. A street across a wall is no
longer treated as an accessible frontage. Added tests for blocked and alternate
approaches, real group fits over varied rotations, and use of every new pack.

Validation: final dressing/ground suite 11/11 tests, 661 assertions, 27.1 s
(`/tmp/dressing-streams-tests.log`). Bake budgets pass. Added runtime payload:
about 12 MiB meshes, 476 KiB collisions and 316 KiB textures. Largest assemblies
are the vegetable vendor (47,217 triangles) and herbalist (34,106); these are
bounded per-green contextual choices, not ambient scatter.

Native generated reviews: `new-pack-dressing` (6/large, 10/large, 12/compact),
`dressing-closeups`, `dressing-above`, `dressing-access`, and `dressing-final`.
The first closeup cameras sometimes landed behind walls; overhead views expose
the actual placements. Seating, forge, camp and furnished-table placements were
inspected beside houses and roads. These harness views still use a flat review
plane: production grass, terrain joins, heavily wooded towns and complete
finished-mesh clearance remain open, as does full-world performance acceptance.

### Skywalk attrition baseline for the next structural pass

Added `tests/harness/suntail/town_skywalk_attrition.gd`: eight seeds across
compact/standard/large, 24 towns. The retained tunnel corpus has 25 cells:
6 accepted room covers, 10 without an adjacent compatible storey, 5 without
both jambs, 2 missing crowns and 2 already carrying plots. The bridge carver
seeds only 9 spans; 789 evaluated candidates fail the upper-neighborhood proof,
191 lack two ground-borne endpoint houses, with further platform, interval and
compound conflicts. Evidence `/tmp/skywalk-audit2.log`. These counts are a
baseline, not a restored-skywalk claim. Structural co-planning remains open.

Final independent-stream native review inspected: 6/large has three trees,
three groups/five props; 12/compact has one tree, three groups/five props.
The herbalist/cauldron pairing and furnished table are grounded and clear in
close views, and the overhead camp view shows free approach space. This remains
sparse vegetation; it does not satisfy the heavily wooded end of the request.

### October 1 structural follow-up: validate final covers, reserve bridges earlier

Rejected a one-storey tunnel-host extension experiment. It increased source
cover proposals from 6 to 10 across the 24-town survey, but a stronger check of
finished room cells found that none of its four new covers survived whole.
Two apparent historical-test regressions also reproduce with that experiment
disabled. Floating-mass checks alone were insufficient: releasing an unbuilt
cover also passes them. The growth rule has been removed; its native views in
`tunnel-hosts` are diagnostic only, not acceptance evidence.

The investigation found a separate reservation bug: `maze.over.*` protected
covers from primary composition but was not recognized by residual infill.
Residual rooms could therefore consume part of a rejected cover. Covers now
use the shared skywalk reservation namespace; only their directed room pass
may consume it. `test_october1_tunnel_hosts.gd` checks full storey occupancy
(all eight fine cells or none), actual positive covers and floating masses
across six towns, plus reservation ownership: 2 tests / 33 assertions pass
(`/tmp/cover-reservation.log`). A late retry after residual infill did not
restore covers and was removed.

Current candidate: select supported bridge compounds after the spine and
market but before the perimeter/optional streets. Preserve their endpoint
columns and one proved adjoining storey per end. Later selection retains the
same proofs and can add disjoint compounds; the shared boring rule respects
the reserved bearings and occupied span bands. The first 24-town composed
survey produces 14 source spans and 10 built bridge houses, all with zero
floating masses (`/tmp/early-built.log`). Source-only baseline was 9 spans.
Final baseline composition comparison and two endpoint-bearing failures in
the wider carving suite are under investigation; this candidate is not yet
accepted. No restoration claim rests on source counts alone.

Early-reservation follow-up: the finished baseline has **8** bridge houses
(`/tmp/baseline-bridge-built.log`), versus **10** in the candidate: 9/standard
1→2, reported-seed/large 2→3. The newly added finished-composition regression
requires those five actual bridges together and zero floating masses.

Resolved both new endpoint issues without weakening a bearing check. Endpoint
columns now stay reserved even if an earlier public surface shares their column;
a gate search checks its initial candidate, not only subsequent steps. Its
previous first step could bore straight into a reserved endpoint. Reserved
open-space columns also no longer impersonate solid masonry merely because
the route-planning envelope gives them a virtual height. Lookouts respect the
same span/bearing reservations. Diagnostic instrumentation has been removed.

Current structural validation: 19/20 tests, 1,668/1,669 assertions
(`/tmp/early-verified.log`). The sole failure is the unchanged source-retention
proxy (0.52529 vs 0.55, also red with the old carver); all bridge bearing,
whole-cover, skywalk, floating-mass and restored-count checks pass. Open-space,
lobe and platform suite: 12/13, 6,260/6,261 assertions; only the old plain-town
layout hash changed. Re-pinned that exact signature with its history because
the redesign intentionally changes ordinary towns too; retained explicit
zero-platform and repeated-generation checks. The remaining density proxy is
still open, not silently lowered.

Native review `early-bridges` and `early-bridges-close`: inspected two
9/standard underpasses, the large town overview and street approaches. The
new rooms have closed soffits and join their host buildings. Corrected the
review camera to stand on the actual preceding street cell; extrapolating
backwards from a turn had put one camera inside a house. Ground is still the
flat harness plane. More density/holdout review, full-world traversal and
remaining architectural, vegetation and fortification work are not complete.

Final composed rerun after the bearing/gate/green corrections:
`/tmp/early-built-final.log`, all 24 towns build, **14 proposed / 12 built**
bridge houses versus baseline **9 proposed / 8 built**. All 24 floating audits
are zero. Additional built changes after the first candidate: 7/compact gains
one and 10/standard gains a second. The exact plain-town signature and repeat
check pass (1 test / 4 assertions); the final focused bearing test passes
(1 test / 50 assertions). This is verified structural progress, not completion
of all town-redesign gates.

Chimney clearance follow-up: the reported large town had two measured mesh
conflicts, the body and cap of one stack crossing a raised walkway. Roof-detail
geometry is now baked alongside the roofs (29 assets; roughly 13 KB added).
The union pass moves each rigid stack together to the nearest clear position
on its own ridge, or omits the entire optional stack if no position fits.
It never clips individual chimney triangles. Render and collision instances
therefore share the same move. Three reviewed towns retain all 66 chimney
pieces with zero measured public-air conflicts; the large town moves one
stack and omits none. Native matched passage view in `chimney-clearance`
confirms that the former obstruction is gone. Inspection of the relocated
stack's roof contact remains part of the next visual review.

The old photo-verge test became vacuous after town layout changes. Its source
layout is now frozen from baseline b8e130d9 (original field, massif builder,
carver and site planner), then passed through current composition and kit
assembly. Fixture: `tests/fixtures/october1-photo-roofs-source.txt`; source
signature 022c68bbb02e8026d2a281ff87a95caf9f2571ffd02cee6ec603411331bf193e.
Optional massif/profile state in the frozen-source reader preserves that
continuous size profile. All temporary baseline substitutions were restored.
The photographed roofs are once again present and checked. Combined roof
verge, rigid detail and finished public-clearance suite passes 9 tests /
221 assertions (`/tmp/october-roof-combined.log`, 25.1 seconds).

Next vegetation investigation: placement currently reserves a whole canopy
footprint against subsequent trees, preventing overlapping crowns. A wooded
appearance needs separate trunk clearance and crown/building clearance, not
just a higher random density. No tree clearance relaxation has been applied
yet; heavily wooded town acceptance remains open.

Vegetation candidate: retain measured trunk/low-branch separation, but permit
crown-to-crown overlap only when both measured height bands start at least
4 m above the higher root datum. Building and public occupancy checks stay
unchanged. Full canopy reservations still exclude prop groups; explicit
per-tree band records allow only other trees to share upper crown space.
Nine dressing tests / 654 assertions pass (`/tmp/grove-crowns.log`), including
actual overlapping measured crowns, rejected intersecting trunks, and a
rejected crown through an upper room. Native `grove-crowns/6_large_overview`
still shows only three trees, so this is not accepted as the heavily wooded
endpoint. A high-woodland six-town capacity survey is running to distinguish
insufficient reserved ground from overly sparse candidate sampling.

The capacity survey confirmed poor acceptance of a single sampled tree form.
Each eligible planting cell now tries up to four measured forms/positions,
while retaining at most one tree. Prop groups are placed first within each
space, then trees use its remainder. This preserves useful social/work areas
instead of spending their ground on foliage. Six high-woodland large towns
(seeds 13, 21, 23, 34, 52, 60, selected by woodland > .85) change from
4/2/1/9/0/4 trees to 10/13/5/15/0/7: 20→50 trees. All 23 previously admitted
prop groups remain. Final nine dressing tests / 654 assertions pass
(`/tmp/grove-final-tests.log`); survey `/tmp/grove-props-first.log`.

Intermediate native `grove-retries` overviews show coherent groups around
cottages but still concentrate trees at the town edge. They do not establish
a wooded interior, and seed 52 remains treeless despite its high woodland
roll. Final prop-first native review is saved under `grove-final`. Full-world
grass, interior green capacity and wooded-endpoint judgment remain open;
these flat-plane renders are not production-ground acceptance.

Inspected final 13/large dressing close view and 21/large overview: props
remain grounded with room around them, and separated trunks support the
larger cottage-edge groves. The flat harness remains visibly bare. The next
layout issue is concrete: `WarrenTownOpenSpaces.sample` currently samples
centres only at .65–1.35 times the town radius, in addition to crown/backbone
exclusions. That radial sampling biases greens toward the perimeter. Any
interior-clearing revision must keep crown heights and connectivity tests,
and be assessed across holdout seeds rather than forcing this showcase.

Interior-green investigation (candidate, not accepted): broadening the radial
sampling interval from .65–1.35 to .30–1.20 alone gave no benefit: 40 large
towns still had 16 interior greens, with reserved area shrinking 295→275
cells. A subsequent first-site preference requires four cells at least two
rings inside the original boundary for the first half of the search; it
falls back to edge sites when no safe interior site fits. Existing crown,
spanning-tree and platform exclusions remain. This yields 25 interior greens
(vs 16), 49 total spaces (vs 53), and 280 cells (vs 295).

Seven open-space/lobe tests pass. The broader 10-test run has two failures:
source cover presence falls to zero in its six-town sample, and finished
bridge houses in the two-town restoration check fall 5→4. The candidate is
not accepted on the green metric alone. A full 24-town composed skywalk
survey is running (`/tmp/interior-skywalk-corpus.log`) to distinguish a corpus
regression from redistribution among particular seeds. Native candidate
views are under `interior-preference`; the 8/large overview was inspected.
They do not establish wooded interiors (8 and 38 roll urban vegetation).

Completed inward-range candidate audits: 24-town finished bridge count falls
12→8 (`/tmp/interior-skywalk-corpus.log`), with no floating masses; six-town
woodland count falls 50→39. Rejected the radial-range change. The next
candidate restores the original .65–1.35 range and keeps only the first-site
interior preference. Current verification processes: `/tmp/interior-only-tests.log`
(10 structural tests) and `/tmp/interior-preference-only.log` (40-town field
comparison). No failing thresholds have been reduced or signatures re-pinned.

Preference-only field result: interior greens 16→25, total spaces 53→52,
reserved cells 295→304. Its 10-test run still has the two cover-presence /
bridge-count failures (8 pass; 5,716/5,718 assertions); the massif, reserved
volume and small-house checks pass. Full preference-only composition and
woodland surveys are now live: `/tmp/interior-only-skywalk.log` (session
19442) and `/tmp/interior-only-woodland.log` (session 89511). Keep this
candidate explicitly unaccepted pending those results and further joint
layout/skywalk work. Original sampler remains recoverable at
`/tmp/open-spaces-before-interior.gd`.

Preference-only validation completed: the established 24-town corpus keeps
12 finished bridge houses, all floating audits zero; bridges redistribute
between individual seed layouts. The six wooded towns now hold 51 trees
(previously 50) and all 23 prop groups. New source covers in 7/compact and
9/compact build all eight expected room cells each; both 9/large covers
remain wholly absent, never partial (`/tmp/interior-cover-check.log`).

Expanded the bridge regression from two particular seed layouts to the
established 24-town corpus, with its full 12-built-bridge floor (baseline
before early reservation: 8). The whole-cover regression retains all its
old seeds and adds the two new positive cases. Added the 40-town interior
reservation check (16 before; 25 now). Combined 7 tests / 5,333 assertions
pass in 115.4 s (`/tmp/interior-expanded-tests.log`). This retains the
preference-only implementation, not the rejected radial-range experiment.

Native `interior-only` 23/large overview and 7/compact passage were inspected.
Corrected another review-camera error: fine-grid X/Z coordinates name cell
centres, so the centre of the macro column's two cells is `2*c + .5`, not
`2*c + 1`. The old camera was half a fine cell sideways from the actual
street. Corrected close views of both complete covers are being rendered
under `interior-passages`. Full-world grassy interiors and artistic stage
acceptance remain open.

Corrected native close review: 7/compact tunnel view shows a closed timber
soffit spanning the street and grounded wall faces beneath it; 9/compact
street approach is unobstructed at the corrected camera. These are visual
checks of the newly located cases, alongside the complete-cell proof. The
plain-town deterministic signature remains unchanged and passes (1 test /
4 assertions; `/tmp/interior-platform-signature.log`).

Next architecture investigation: Pure Village's reference House_1 composes
`Roof_Base_30x30_1` and `Roof_Curved_30x30_1` at the same transforms, with
separate Start/End verge modules and `Roof_Top30_*` ridge pieces. Its source
roof eave is y=6.125 and ridge y=9.125 over a 3 m half-span. This is a layered
native roof assembly, not a drop-in substitution for the current Suntail
2 m run / 3 m rise. Verify those native joins in a dedicated study before
changing production roof roles. Current Pure Village integration remains
facades on the shared Suntail roof/structure grammar; that limitation is
still open and has not been represented as full native-kit completion.

Pure Village roof study completed: added `pure_village_roofs.gd`, measured
11 native modules (`pure-roof-modules.json`), and inspected separate upper,
curved, complete and closed-end renders. Corrected the previous interpretation:
the two source pieces at y=6.125 are successive upper/lower courses sharing
a seam, not overlapping layers; the actual eave is near y=3.598. Matching
`Wall_CutBendDown` and `Wall_Cut` panels close their respective profiles.
See `pure-roof-grammar.md` for source transforms and integration constraints.
Native rendering completed without script errors; source resource UID
warnings resolved through their supplied paths. No production roof-role swap
has been made before reconciling the differing module/run dimensions.

Pure Village roof adapter implementation (opt-in study, not production):
reference House_10 supplies a straight-course / short-curved-cornice family
that shares the existing three-metre row rise. Baked native slope, eave,
paired odd-depth top, ridge, gable halves and native start/end pieces: 15
new roof/gable assets, plus the existing eight facade assets. Regular roof
runs normalize 1.5→2 m, while ridgewise stock is clipped to two metres.
The separate long curved House_1 profile remains a later style; no unequal-
course-height change was made to the production roof metric.

`PureVillageBuildingKit.roof_study()` selects the new family explicitly.
`BuildingKit.roof_edge_caps` expresses its actual grammar: complete strips
at bay centres, separate native caps at end walls. Legacy kits retain their
boundary-centred strips. `BuildingKitAssembler` selects oriented start/end
pieces on both axes, including odd-depth top and ridge. Suntail regressions
pass 16 tests / 12,449 assertions; initial end orientation/asset checks pass
2 tests / 101 assertions.

Native gallery iterations found and corrected two errors rather than
accepting the first render. In `pure-roof-adapter`, Suntail verge boards did
not follow the native roof. `pure-roof-native-ends` incorrectly replaced a
whole boundary strip with a narrow cap and left holes. `pure-roof-spaced`
uses whole bays plus caps; the inspected b01 close view closes those holes.
The roof coverage regression explicitly detects the rejected assembly using
RoofTiles triangles (not rafters). Initial 31-ray coverage passes. Expanded
both-axis/even-and-odd-depth coverage found a remaining narrow ridge gap:
the slope run had been widened but the native ridge cap had not. Its Z scale
now follows the same 4/3 normalization. The fresh asset bake and 27-asset worker geometry bake completed. The expanded
coverage matrix passes on the rebuilt geometry: 3 tests / 109 assertions,
including both axes, depths four and five, and a rejected-assembly control
(`/tmp/pure-ridge-verified.log`).

Known follow-ups before rollout: mixed-kit roof-union geometry loading and
per-family bounds, dormers, full public-clearance/roof-junction checks,
material/palette judgment and texture budget (Pure Village baked texture
folder is now 171 MiB, previously ~124 MiB). No production roof family was
enabled prematurely. Catalog resource IDs remain stable (31 new descriptors
in total across this redesign); native geometry is worker-readable.

October 2 continuation — native roof integration and contact checks:

- `KitRoofMeshUnion.prepare/append` now accept each wing's own kit, load
  each distinct worker geometry file once, and use the owning kit for its
  roof/enclosure/clip volumes and chimney positioning. `KitVillageBuildings`
  passes and returns that mapping. Shared catalog IDs retain their common
  geometry. This fixes the otherwise silent bypass of Pure Village triangles
  in a mixed-pack town. Production family selection remains unchanged.
- Added a measured native `Window_Roof_1_1` dormer/cornice assembly. It replaces
  a complete roof bay, preserving glazing; width is normalized 3→2 m and run
  1.5→2 m. The study no longer substitutes a plain eave for a requested dormer.
  Pack totals: eight facade + sixteen roof/gable assets; 28 worker-geometry
  entries including shared details. Catalog has 32 new descriptors across the
  redesign. Texture folder is 172 MiB; runtime budget review remains open.
- Six Pure/Pure, Pure/Suntail and Suntail/Pure crossing and stepped junction
  cases pass collision-ray closure. Mixed public-strip clipping preserves
  exact render/collision correspondence for both families. Native renders
  `pure-roof-junctions` show the joins; inspected both mixed crossing views
  and the Pure/Pure stepped view. These are small composition fixtures, not
  full-town acceptance.
- Close view `pure-roof-dormers/b01_roof.png` exposed a narrow peak slit missed
  by the original quarter/half-metre sampling. Centimetre sampling first
  failed with 28 misses on the odd-depth roof. The ridge's transverse fit is
  now 1.5 (slope run remains 4/3), and the native top rise is 1.5 m.
- Vertical rays alone still falsely accepted a visible oblique slit: they
  could hit the back face of the far roof. A camera-ray probe identified it;
  the regression now counts front-facing tile surfaces and checks oblique
  sightlines on both sides. It reproduced 104 misses on depth-three / +Z.
  Native odd ridge lift 0.24 m seats the cap skirt 0.06 m lower against the
  half-height course. Default kit lifts remain 0.3/0.19 m (Suntail unchanged).
  All eight native-roof tests now pass, 136 assertions, including dormer
  coverage, dense course sampling, oblique closure and mixed intersections
  (`/tmp/pure-oblique-green.log`). Final close view in `pure-roof-seated`
  confirms the background line is gone and the dormer remains complete.
- The existing generated-town chimney test's required move became stale when
  interior greens changed that seed's houses. Preserved the obstructed source
  as `tests/fixtures/october1-chimney-source.txt` from the pre-interior-preference
  planner (source signature ed24845b6afc19185e41961f061f004a47b9777d4a7f0549ad90a6a8cf4c1aa3).
  The current planner was restored immediately after capture. The frozen
  regression still requires a real relocation with no omission, while the
  live generated town independently checks every remaining stack and variety.
  All three chimney tests pass / 100 assertions (`/tmp/chimney-frozen-tests.log`).

Remaining roof rollout gates: complete-town clearance/collision and native
roof envelopes (the current roof-volume skin/overhang constants originated
with Suntail), final palette/material judgment, and runtime texture cost.
The larger flared House_1 grammar remains a separate optional family. Facade
articulation, fortified rings, full-world grass/trees, and broad town quality
acceptance also remain open; this does not complete the redesign.

Combined final roof regression: 27/27 tests, 12,685 assertions, 91.3 s
(`/tmp/pure-final-regression.log`); building-kit, native roof, roof-junction
and chimney suites. `git diff --check` passes. No production roof-family
selection change was made in this continuation.

October 2 full-town native roof pass:

- Added `--pure-roofs` to `kit_town_review`; rendered complete native-kit
  7/compact streets and the reported city seed / large. The former's inspected
  street view shows native stone reveals, timber/window relief and coherent
  roof undersides at player height (`pure-native-town/7_compact_street0.png`).
- Six comparison builds (Suntail and Pure for 7/compact, 9/standard,
  1260018864828801968/large) exposed four native gable holes in the large town.
  The focused `test_public_verge_fit_keeps_the_native_gable_face` reproduced
  the failure. `KitRoofMeshUnion` now separates gable clip planes: branch/host
  clips still apply, while an own verge shortening cannot strip the facade.
  Native plaster fronts were independently measured at local Z=0.125, matching
  their +0.032 anchor and the common 0.157 wall face. No facade offset fudge.
- Recheck: all three native towns have zero gable holes, exposed open ends,
  or unsupported roof corners. The larger town still has the same one tiny
  roof and two supported air roofs as Suntail. New full-town regression:
  `test_october1_native_town_roofs.gd`, 18 assertions passing / 45.7 s
  (`/tmp/native-town-regression.log`). Native and original-photo roof suites:
  14 tests / 286 assertions passing (`/tmp/native-gable-green.log`).
- Updated the geometric audit to load each roof's own kit and use that kit's
  enclosure/section metric. Native study accepts a facade style seed so later
  production selection can preserve seeded opening variety.
- Remaining native eave audit flag is specifically the separate end cap
  `pure_village.roof.eave.end` at native (-8,6,20), house.004/k0035, roof
  Rect2i(-4,10,6,2), axis X, eave band 4. Do not dismiss it as a regular-bay
  failure or simply relax the threshold. Render `pure-native-eave` includes
  its close front view. That view also exposes a partly roof-occluded window
  near the adjoining taller house; crowded facade/roof composition still
  needs repair before native rollout. The attempted reverse camera lies
  inside another building and is NOT useful acceptance evidence.
- Probe logs: `/tmp/native-town-roof-probe.log` (before),
  `/tmp/native-town-roof-recheck.log` (after), `/tmp/native-eave-detail.log`.
  Production `TownBuildingStyles` still selects the facade adapter with
  Suntail roofs; no premature native-roof rollout. Other redesign scope stays
  open as listed above.

October 2 finished facade contacts (native roof continuation):

- Added worker-pure `KitFacadeRoofContacts`: measured opening envelopes are
  tested against attic volumes and finished authored roof triangles. The
  latter matters for Pure Village's curved cornice, which lies outside the
  simple attic envelope. Cut-away roof triangles cannot remove a clear window.
  Only exposed window/bay slots participate; door reservations stay intact.
- First try another complete window from the same kit/material family. If
  none fits, use the corresponding plain panel and withdraw its window box.
  `BuildingKitAssembler` honors the selected per-edge opening asset. This
  prevents buried windows without moving buildings or altering circulation.
- The first native close render still showed a low arched window crossed by
  a raised deck. Finished public floor triangles now participate too, sharing
  the same floor/approach sources as `KitPublicClearance`. Headroom air and
  guard tops do not count as solid floor. The final close view
  `pure-facade-floors/1260018864828801968_large_eave_front.png` was inspected:
  both the roof-occluded upper opening and deck-buried arch are corrected.
- Corrected an independent source-adapter crop: Window_12_3's window is
  off-centre. Its old symmetric crop shortened the real Window_1 frame from
  0.8216 m to 0.5902 m. A measured X=0.4 pivot adjustment preserves its full
  width inside the 2 m plaster panel, without stretching it. Re-baked that
  asset, minimized the catalog index, and baked nine opening envelopes into
  `geometry/window_openings.bin`. Source/bake authority remains in the manifest.
- Cache roof realization once per immutable build context, and reuse it for
  facade contacts and final payload emission. World mapping deep-copies the
  cached native geometry; ordinary mutable audit contexts do not cache. Native
  city harness generation samples were 33.3 s with duplicate clipping, 19.7 s
  after caching, and 18.9 s including floor fitting (individual samples, not a
  performance benchmark). Final city: 160 blocked windows, 38 fitting variants,
  3,972 instances. The roof-only intermediate retained 254 flat windows,
  29 bays and 60 doors; the final floor-aware pass needs its own corpus count.
- Focused facade suite: 9/9 tests, 98 assertions
  (`/tmp/facade-floor-tests.log`), covering all opening metadata, retained full
  source window, same-kit alternatives, narrow centre contacts, all cardinal
  orientations, floor mapping/guards, curved native cornices and cache/collision
  integrity. Before adding floor contacts, combined facade/Pure/roof junction/
  original-photo/native-town/build-order regression: 26 tests, 12,855 assertions
  passed (`/tmp/facade-final-regression.log`). Floor-aware broader check: 14/14 tests, 127 assertions, 59.3 s passed
  (`/tmp/facade-floor-regression.log`), including public clearance, full native
  towns and generation-order determinism.

This fixes real facade intersections; it is not acceptance of every facade's
visual depth. The newly plain panels, native eave-end warning, native roof
volume constants, texture cost and production mixed-roof rollout remain to be
judged, along with the other open redesign scope above.

Native cornice investigation after facade acceptance:

- The flagged end cap spans native X=-8.746..-7.313, Y=5.215..9.112,
  Z=18.925..22.0. A derived landing at Y=4.525 reserves headroom to 5.725;
  an adjacent rising ramp also reaches its front lip. The low cornice thus
  conflicts even though the nominal eave is Y=6.0.
- Tried a per-family 0.785 m eave-drop rule, lower/diagonal verge detection,
  and finished-air bounds for derived landings. Gable and original-photo
  tests passed, but the end-cap warning remained even when its baseline was
  measured after planned fitting. The problem also affects the forward lip,
  so shortening the gable verge alone is not sufficient. Reverted this
  incomplete geometry change and the audit-baseline experiment. The audit's
  original threshold remains unchanged. No source roof shape was flattened
  or distorted to evade the test.
- `/tmp/native-eave-contact.log` records the actual public cutter planes;
  `/tmp/native-finished-corner-probe.log` records the rejected fit's unchanged
  eave count. Close walking views are in `pure-cornice-close` for further
  inspection. Native roof selection remains opt-in pending this geometry gate.
- Inspected both close cornice renders (`cap_walk`, `cap_front`). They reveal
  a long horizontal split through the curved lip and clipped bracket remnants,
  not merely a statistical end-cap warning. This fails visual acceptance.
  The next candidate should choose a complete compatible tight/straight eave
  assembled from native pack parts where the flared cornice cannot fit; do
  not accept these disconnected pieces or merely suppress their audit count.
  An unchanged native family remains available where its whole cornice fits.
  Any alternative must preserve gable closure, course seams, dormers and exact
  collision correspondence, and be rechecked in the same walking cameras.

October 2 complete eave/dormer fit iteration:

- Added `KitRoofEaveFits`: only families with a complete tight-eave role can
  select it, and only when actual authored eave triangles meet public headroom.
  Four wings of the large native city select the tight family. The native
  straight course and its own end caps replace the whole cornice course;
  clear roofs retain their curved cornice. Selection is deterministic and
  idempotent. Production Suntail/facade-only families have no such role and
  bypass this work.
- Matched `pure-tight-eaves` close walking/front views were inspected. The
  long slit and disconnected cornice/bracket remnants in `pure-cornice-close`
  are gone; the replacement is a complete roof course with a continuous
  planked underside. No audit threshold was changed.
- A matching native tight dormer was baked from `Window_Roof_1_1` without the
  optional BottomCurved piece. Both profiles preserve requested dormers and
  pass roof-bay closure. Catalog now has 25 Pure assets (8 facades, 17 roof/
  gable); minimized index has 33 new descriptors including the 8 town props;
  worker roof geometry has 29 entries including shared details.
- The original eave warning is resolved, but the unchanged overhang-area
  metric now flags three small straight-course/front-cap pieces at the
  landmark's raised landing (native X=8,9,11, Y=6, Z=0). Its walking surface
  is Y=6.025. Their shallow front overhang is cut back; the inspected
  `pure-fitted-dormers/landing_corner` view shows a continuous roof there.
  Do not report a zero eave-cut corpus or silently exempt the tight family.
- That inspection exposed a separate dormer window cut by landing headroom.
  `KitRoofDormerFits` now reserves the full measured opening, keeps clear
  original bays first, and relocates blocked dormers to the nearest clear bay
  with the original two-bay spacing. It uses complete native assemblies;
  when no bay fits, the whole dormer becomes a plain roof course. It also
  checks other logical roof volumes and solid walls, never its own attic.
  Opening metadata now includes both native and both Suntail dormer assets.
- Large native city: 24 dormers checked, 2 moved, 1 wholly omitted; the flagged
  landmark retains both, with its first moving from bay 5 to 6. Matched
  `pure-fitted-dormers/landing_corner` was inspected: the clipped glass block
  is gone and both dormers read as complete windows. Four tight wings, 154
  blocked facade openings, 41 fitting alternatives, 3,978 instances; sampled
  harness generation 18.6 s. This is still a flat-ground study, not production
  world/performance acceptance.
- Focused fit suites: 5 tests / 141 assertions pass
  (`/tmp/dormer-fits-tests.log`). Broader native closure, contacts, original
  roof photos, chimney and build-order regression: 35 tests / 659 assertions
  pass, 129.4 s (`/tmp/roof-fit-regression.log`). Tight courses are ray-tested
  on both axes and even/odd depths; both dormer profiles retain glazing and
  close their roof bays. Additional independent final-geometry check passes: the three complete
  native towns retain the full area of every realized glazing/window-material
  surface after roof union (23 assertions, `/tmp/native-window-area.log`).
- Texture rollout gate is now measured: all 44 texture resources in the Pure
  bake are reachable from current kit materials (including both facade opening
  families). Decoded image data totals 659 MiB: 41 at 2048x2048 and 3 at
  128x2048, none with mipmaps. This is decoded pixel storage, not a GPU-memory
  profiler result. `pure-texture-budget.json` includes both the directory
  inventory and actual material reachability. A texture compression/mipmap
  pass with matched near/far renders is required before broad native rollout.

October 2 Pure Village texture rollout gate:

- Added an explicit per-manifest texture policy to environment baker v39,
  retaining legacy lossless defaults for other manifests. Pure Village now
  uses Basis Universal, mipmaps and the normal-map encoding hint. Dimensions
  are unchanged: 41 maps at 2048x2048 and three at 128x2048. Encoding settings
  participate in generated texture identities; normal mipmaps are renormalized.
  Per-asset provenance records the policy, including partial-bake cases.
- The encoder retains compressed source buffers only in the bake process;
  saved texture resources do not request an extra runtime source-buffer copy.
  Basis was chosen after a same-image probe: full-size planks with mips,
  5,592,432-byte compressed payload; sampled RGB RMSE 0.002842 versus 0.003113
  for BPTC, encode 2.39 s versus 6.40 s. These are one-image measurements.
  API/portability reference: https://docs.godotengine.org/en/4.5/classes/class_portablecompressedtexture2d.html
- Full 25-asset pack rebaked, catalog IDs minimized, and 29 worker roof entries
  regenerated. The same 44 reachable maps now have 219.668 MiB of compressed
  image payload INCLUDING mipmaps, versus 659 MiB without mipmaps: a 66.7%
  reduction while retaining texel dimensions. This measures image payload,
  not whole-game GPU allocation. Budget evidence contains the before/after
  active-material inventories in `pure-texture-budget.json`.
- Matching native close/overview images in `pure-compressed-textures` were
  inspected against `pure-fitted-dormers`. The opening/wood/plaster detail and
  palette remain coherent; roof detail filters smoothly at distance. The same
  city payload has 3,978 instances and identical roof/detail audit counts.
  Geometry and style selection did not change during this texture pass.
- New texture-budget regression checks all 44 maps, source dimensions,
  mipmaps, portable encoding, compressed payload and runtime buffer flags.
  Texture/facade tests: 5/5, 971 assertions (`/tmp/pure-texture-tests.log`).
  Native roof, complete native towns (including finished glazing area) and
  texture budget: 12/12, 527 assertions (`/tmp/compressed-roof-tests.log`).
- Removed the 44 superseded generated textures only after proving they were
  untracked, absent from the active material graph, and referenced by no
  material in the catalog directories. Recoverable copy:
  `/tmp/october1-pure-precompression-textures.tar`. Current texture folder is
  145 MiB on disk; historical precompression names remain only as QA evidence.

The texture sub-gate is accepted at these measured settings. Native mixed-roof
rollout, remaining geometry envelope/clearance review, and the full redesign's
layout, fortified-ring, world-ground and traversal gates remain open.

October 2 complete mixed-roof corpus and holdout review:

- Added an explicit native-roof study option to `TownBuildingStyles.for_house`
  and `KitVillageBuildings.build`, exposed as `kit_town_review --mixed-roofs`.
  It uses the same seeded per-merged-house family choice and opening-family
  roll as production. Production defaults are still facade-only until final
  mixed-roof art/clearance acceptance; this option does not change town layout.
- Eight mixed builds: 7/compact, 9/standard, 1260018864828801968/large,
  13/large, 21/standard, 34/compact, 52/large, 60/standard. Every town has both
  roof families, valid payloads, zero gable holes, zero exposed open wing ends
  and zero unsupported roof corners. Probe: `/tmp/mixed-town-roof-probe.log`.
- Expanded complete-town regression includes four actual mixed towns and
  proves per-wing native asset ownership plus final glazing/window-material
  area after union. Pure-only original three-town minimum roof count stays
  >20; the mixed holdout includes 34/compact's legitimate 17 roofs and uses
  >10 to reject isolated fixtures. Two full-corpus tests / 1,210 assertions
  pass (`/tmp/mixed-town-tests.log`).
- Inspected `mixed-native-roofs` large overview and compact street0: distinct
  native blue-tile and warm Suntail roof families share construction datums;
  native stone openings have clear geometric reveals and protruding surrounds
  at street height. This remains a flat-ground harness, not world-grass proof.
- Holdout 13/large has five eave-overhang warnings with native roofs versus
  one using its original Suntail roofs (`/tmp/mixed-roof-baseline.log`). The
  warnings concern house.031's roof junction beside a same-level raised walk.
  Matched `holdout13-false` / `holdout13-true` walking and wide images were
  inspected. The tight native courses remain continuous; no long split like
  the rejected curved cornice. Keep these diagnostic counts visible.
- The wide view exposes a conspicuous native ridge/end detail at a shortened
  verge. Investigated an apparent handedness problem: rejected that diagnosis.
  Ridge yaw is 3PI/2 (not PI/2), so its existing Start/End choice is correct.
  Added ridge caps to the outward-facing end-course test; 48 assertions pass
  (`/tmp/ridge-handed-red.log`, despite that exploratory log's name). No
  orientation code changed. The next check is the actual clipped end cap:
  measured native Start X=-0.8..0.05359 and End X=0..0.79499 versus a fitted
  0.157 m verge. Investigate retaining a complete cap at the shortened end,
  without exposing its internal cross-section or overlapping the regular
  ridge course. Do not weaken the audit to hide this visible detail.

Mixed roofs are implemented as a reviewable candidate with broad geometric
proof, but production enablement remains pending that end-detail judgment and
remaining integration gates. The full redesign scope and open stages remain
unchanged.


### October 2 — complete native ridge caps at shortened verges

- Native Start/End caps now move inward by their measured outward reach when
  a public verge is shortened. The regular ridge course ends at the new cap
  seam, preserving the source overlap; neither cap is stretched. Suntail and
  unrestricted native ends retain their original assembly.
- The focused whole-cap test initially found two remaining cuts (one Start
  per axis). Diagnostic bounds proved float32 cancellation in the FAR-sized
  clip box: the intended -0.157 m plane became -0.15625 m. `clip_volumes` now
  preserves the original scalar cut coordinate in its plane. No clearance
  tolerance was weakened.
- Both axes preserve both complete caps; dense front-facing rays across the
  finished cap/course seams find no holes. The counterfactual without cap
  fitting still reproduces both cuts. Focused test: 10 assertions pass,
  `/tmp/ridge-fixed.log`.
- Inspected `holdout13-ridge-final/13_large_edge_wide.png`: native end ornament
  and continuous ridge tiles remain; the former sliced cross-section is gone.
  This is a flat-ground architectural review, not evidence of finished world
  vegetation or traversal. Broader regression is recorded below when complete.


### October 2 — native mixed roofs enabled in production

- Cap/roof regression: 25 tests / 1,671 assertions pass in 131.745 s
  (`/tmp/ridge-regression.log`): native grammar, whole-town mixed roofs,
  eave/dormer fitting, the photographed verge and build-order determinism.
- Enabled native roofs in the default `TownBuildingStyles.for_house` and
  `KitVillageBuildings.build` paths. Each selected Pure Village house now uses
  its measured native roof family. The seeded family selection is unchanged;
  ordinary Suntail houses keep their original roofs. The explicit false
  argument retains the earlier mixed-facade/Suntail-roof comparison.
- The review harness follows the production default. `--legacy-roofs` renders
  the earlier roof baseline; `--pure-roofs` remains the all-Pure grammar view.
  The former `--mixed-roofs` invocation now matches ordinary default output.
- Updated the frozen photo oracle to load each roof's own geometry kit; it
  must not silently skip native roof assets. The mixed holdout test now calls
  the default production API, and style tests require native roofs on selected
  Pure houses.
- Production-path regression: 24 tests / 2,213 assertions pass in 104.25 s
  (`/tmp/production-native-roofs.log`), covering family consistency, native/mixed
  whole towns, photo clearance, finished stair air, facade contacts and build
  order. No threshold was lowered.
- Added an independent polygon-intersection audit for finished roof skins,
  trims and chimney details against the actual public-air volumes. Initial
  broad classification found 131 gable-face contacts (1.3448 native m²) in
  13/large and zero skin/trim contacts. Gables are facade boundaries: the
  bare floor extends to the wall datum behind their relief. The audit now
  reports these separately as `gable_contacts` / `gable_area`; it does NOT
  claim full character clearance or erase gable geometry to make a count zero.
  Actual-player traversal remains an explicit integration gate.

- Finished-air audit passes (1 test / 7 assertions, 26.239 s,
  `/tmp/mixed-air-final.log`). In 13/large, untrimmed native/legacy roof skins
  contain 496 intersecting triangles (7.3387 native m²); finished geometry has
  zero. 7/compact already needs no such cuts. Finished triangles examined:
  561,894 and 649,548 respectively. Gable contacts remain separately visible.
- Default-path renders (no native-roof flag) inspected in
  `production-native-roofs`: 7/compact and 13/large, overview and street0 each.
  Both roof palettes appear coherently by building, native recessed/protruding
  stone windows read at street scale, and Suntail keeps its warm roofs. These
  views also reinforce the outstanding work: large bare retaining faces,
  coarse painted ground, greenery in the actual world and tier/skywalk design.
  Do not use this roof acceptance to close those goals.
- `git diff --check` passes. All changes remain uncommitted in this worktree.

Next implementation focus: finish the structural/layout goals (landmark
reservations, useful supported crossings, procedural fortified tiers), then
world-ground vegetation and traversal/performance acceptance. Native roof
production integration is now implemented; it no longer waits behind an
opt-in review flag.

### October 2 — landmark admission diagnosis before structural redesign

Revalidated the outstanding landmark regression against current production
source planning. `landmark-admission-census.json` records all four towns and
per-quota outcomes: admitted 1, 1, 0, 0 (quotas 6, 5, 8, 9). This is still below
the established aggregate floor 7; that floor remains unchanged.

Added per-door-lane refusal detail to `WarrenPlotReservations` without changing
admission behavior or the historical per-site tally. It distinguishes exact
door access, body/public-air conflicts, green versus competing-envelope claims,
grid extent, missing bearing, cross-plinth bearing and the low citadel band.
Reusable command: Godot `--headless --path . -s
res://tests/harness/suntail/landmark_site_audit.gd` (explicit `--log-file` as usual).
The harness also accepts `--cities seed:profile,...`.

Experiments performed and fully reverted:

- 3×3 small-house cores instead of 2×2: no landmark recovery (still 1,1,0,0).
  Do not simply make every detached house larger.
- Permit the clearance halo over reserved green but forbid actual bearing on
  that green: no recovery. The next spatial constraint still rejects it.
- Combine that change with a height-aware citadel-foot allowance (a landmark
  whose complete measured top fits below the local wall): 1,1,0,1. This is a
  partial recovery, not the required co-planning, and was not retained.

New evidence: 3/standard's first quota sees 18 envelope/green refusals and
2 citadel-foot refusals. 6/large sees 4 envelope/green, 13 actual body/public-air,
2 citadel-foot and 19 cross-plinth bearing refusals. The two compact towns are
instead constrained by grid extent and already-claimed envelope. Thus a global
footprint-size or halo-tolerance change does not solve the regression. Coordinate
measured landmark sites and their street approaches with open-space and
fortification planning; preserve room for the requested gardens and small
houses. Do not consume an entire lobe as the earlier rejected experiment did.

Diagnostic-only final state passes the minimum-modification asset-site oracle
(1 test / 27 assertions, `/tmp/landmark-diagnostics-tests.log`) and
`git diff --check`. No visual acceptance is claimed for this diagnostic turn;
production layout behavior is unchanged. The preceding goal turn was progress
(native roofs enabled and verified), and this turn adds authoritative refusal
evidence that narrows the next structural implementation.

### October 2 — preserve selected landmark bodies through later carving

The previous turn was progress: it isolated admission failures. This turn
traced stage attrition. Early sealed-street preview finds 1,1,0,2 legal assets
in the four regression towns; final reservation had 1,1,0,0. In 6/large the
ground site's five footprint cells were later bored at band 0, and an upper
site lost its supporting band below floor 4. Merely extending soft frontage
holds or the perimeter detour did not preserve them; those experiments were
reverted.

Implemented `WarrenExcavation.landmark_reservations`: explicit body bands plus
the bearing band for each actually selected preview asset. The common boring
predicate now respects these reservations, including secondary gate searches
(which did not consult soft frontage). Terminal terraces respect the same
bands. Daylight opening of a lower street stops at a reserved upper footing,
just as it does for a supported skywalk. Reservations are copied by the
existing excavation-copy paths. No seed-specific production rule was added.

Results:
- Source census now 1,1,0,2: both 6/large sites survive. Four-town total 4,
  still short of the existing 7; no threshold repinned.
- New reservation tests and complete open-space tests: 6 tests / 5,303
  assertions pass (`/tmp/landmark-reservation-tests.log`). They check all held
  cells against final carved mass and show that a reservation above a bore
  does not ban the entire column.
- Existing edge suite: 5/6 pass, 65/66 assertions. Only the known aggregate
  landmark shortfall remains (4 < 7); all rim height/rampart rules pass.
- Built and inspected `landmarks-retained/6_large_overview.png`. The upper
  district and dispersed lower houses remain, with the two landmarks restored.
  This is an overview architecture check, not a complete foot-level access or
  greenery acceptance. The blank plinth faces still need the fortification work.
- Structural tunnel/platform/small-lobe regression running as session 25466,
  `/tmp/landmark-structural-check.log`; inspect completion before accepting the
  broader interaction. Next: create viable measured landmark sites earlier in
  the field/open-space/fortification composition, especially 3/standard, without
  spending the user-requested gaps or detached-house gardens.

### October 2 — fit complete landmark envelopes beside greens and citadels

Previous goal turn was implementation progress. Its live structural job
finished: 12/13 tests, 1,156/1,157 assertions, 194.717 s. Tunnel/skywalk and
small-lobe tests passed; platform test found an admitted asset footprint
extending above the low district's height cap in 27/large. This was a real
admission hole: the bearing box alone did not cover every logical plot column.

Added full-footprint height admission before site selection and in the
realisation mirror. A landmark's complete top must fit below the local citadel
cap on every footprint column. Separately, a measured roof-clearance envelope
may extend over green reservations, but the actual bearing may never occupy
reserved green. Low landmarks can stand at a citadel foot only when their
complete height fits. Other buildings' competing claims still block the halo.
Together with the prior hard carving reservations, this restores 3/standard's
first landmark without spending its garden. The invalid upper site in 6/large
is correctly refused. Current census is 1,1,1,1: total 4, still below 7.

The new previous-turn test's literal expectation of two sites in 6/large was
based on the invalid upper admission. Replaced it with the stronger actual
reservation contract: publish `audit.preselected_landmarks`, require a nonempty
selection, then require each exact valid footprint/floor to survive final
partition, and no carved cell in any committed body/footing. The established
seven-landmark corpus floor is unchanged and remains red. No claim that a
smaller distribution satisfies the redesign.

Validation:
- New landmark contracts: 4 tests / 29 assertions pass, including green halo
  versus physical bearing and complete low/tall citadel envelopes.
- Open-space and platform tests pass in the combined run; its only failure
  was the now-replaced invalid two-site expectation. Result before replacing
  that test: 13/14, 6,128/6,129 assertions (`/tmp/landmark-fitted-tests.log`).
- Minimum-modification site oracle: 31 assertions pass.
- Edge suite: 5/6, 63/64 assertions; only the known 4 < 7 landmark shortfall.
- Inspected `landmarks-fitted/3_standard_overview.png`: complete fortified
  upper district and lower buildings; the new legal low site is incorporated.
  No ground-level or full-world acceptance claimed from this overview.
- Fresh final-layout skywalk/whole-cover corpus running as session 90515,
  `/tmp/landmark-fitted-skywalks.log`. Poll that same session next; do not restart
  just because this turn ends. Full landmark distribution and multiple fortified
  rings remain open.

### October 2 — procedural nested fortified districts

The previous turn implemented landmark admission changes. Its final skywalk
job completed successfully: 3 tests / 92 assertions, 174.862 s
(`/tmp/landmark-fitted-skywalks.log`). This predates the nested-tier change.

Implemented optional inner districts inside the existing citadel. A separate
seed stream rolls nested outlines; each must fit at least nine columns with
two columns of lower district around it. The existing field/terrain owner
carries per-column plinth bands, so plots, retained walls and public surfaces
read the same bearing. Each additional district adds two storeys. Its centre
and extents vary with the seed; no selected seed receives a production case.
The crown follows the highest district and the adjacent lower envelope stays
under the higher wall. Towns without nested tiers keep their prior behavior.

Gate planning initially failed in five of six examples because ordinary
lower-district lanes consumed the ascent space. Rejected that ordering.
Nested gates now precede ordinary upper lanes. Candidate lower approaches and
their complete stair/gate route are tested on an excavation copy; only a
successful local approach is committed. A lower-datum view permits reuse of
the existing gate search while all actual carving remains in the original
excavation. This is a local route fit, not regeneration of whole towns.

Evidence:
- Six representative grand towns (2,13,58,67,78,95): both tiers have public
  grade streets and actual house/asset plots.
- 400 grand-town field/source probes: 25 nested towns, all 25 with reached
  lower and upper districts, no massif/source failure. Saved results:
  `nested-tier-survey.txt`. This is source connectivity, not player collision.
- Nested/platform/landmark suite: 12 tests / 2,183 assertions pass,
  45.443 s (`/tmp/nested-rings-final.log`). Updated the obsolete single-height
  assertion to require an unchanged four-band outer plinth, complete four-band
  increments and a highest-tier summary; platform frequency bounds remain.
- Native 13/grand overview, side and gate-flight images inspected in
  `nested-rings`. The second walled district is visible. Inspection caught
  the old gate map being applied to every wall course, placing a duplicate
  lower gate atop a roof. Gate maps now carry their actual rim band, include
  transitions between two raised districts, and each frame has one owner.
  A gate opening may itself be air, so frame ownership belongs to the rim
  datum rather than the remaining rock beneath one half of the opening.
- Gate regression: 7 assertions pass (`/tmp/nested-gate-contract.log`), both
  frames assigned once to the correct height. Matched
  `nested-gate-fixed/13_grand_platform_far1.png` shows the roof-top duplicate
  removed. Final current capture is running as session 73255,
  `/tmp/nested-rings-final-render.log`; inspect it before treating it as final
  visual evidence.

This implements multiple procedural tiers but does not yet accept the entire
fortification stage. Still required: collision/player walks through both gates,
more rendered holdouts, broader skywalk/landmark distribution after tiers,
wall/facade articulation and world-ground integration. The gate-flight view
also exposes window-box flowers reaching the stair edge, an outstanding
public-detail clearance check. The landmark corpus shortfall remains open.

Final capture session 73255 completed (3,834 instances, 14.575 s construction).
Inspected `nested-rings-final/13_grand_overview.png` and
`13_grand_platform_far1.png`; both wall tiers remain and the duplicate gate on
the lower building's roof is absent. Gate-frame ownership test matches this
final code. No process from this capture remains running.


### Stair-side facade props

Finished public walking prisms now also arbitrate optional window boxes and
loose doorstep props after assembly. The full measured asset box is tested
in its own transformed frame against the actual floor/tread prism; conflicting
ornaments are omitted whole. Window openings and clear ornaments remain.
This addresses the planter in the nested-town gate flight rather than merely
blanking a window whose glass itself was unobstructed.

- Regression: 2 tests / 146 assertions pass (`/tmp/facade-prop.log`). Includes
  sloped/triangular air, the complete 13/grand town, retained ornaments and
  removal of the reproduced planter conflict.
- Native matched `facade-prop-clearance/13_grand_platform_gate_flight.png`
  inspected: stair-level flower boxes gone, upper boxes retained. 38 window
  boxes and 27 loose doorstep props omitted town-wide; 3,769 final instances.
- New `tests/harness/suntail/nested_gate_walk.gd` exercises both gate lanes in
  both directions using production character physics and town collision.
  Its first run was invalid: missing KayKitAdventurers source models prevented
  character initialization. Stopped that run; copied the local 23 MB asset
  directory into this worktree and importing before retry. No traversal claim
  is made from the invalid run.

Traversal setup follow-up: the broad editor import began importing unrelated
source packs, so it was stopped and the already imported KayKit cache files
were copied from the primary checkout (same asset paths). The real character
then initialized with no model/script errors. The first complete walk records
are saved in `nested-gate-walk-first.json`. All four routes stopped: the outer
gate in both directions, and inner ascent/descent. These are deliberately
**not** accepted. The harness also needs to avoid demanding a logical band
height at an intermediate stair position: excavation cells may sit below the
finished tread, and a downward ray can hit a roof/guard above the walk. The
outer gate stops remain after tread ray adjustment. Collider tracing is now
in the harness to identify the obstructing construction before repair.

Collider trace completed with no character initialization errors
(`/tmp/nested-walk-colliders.log`; `nested-gate-walk-colliders.json`). Outer
ascent hits `suntail_stone_stone_wall_plain_2098` and `_2099` at world
(12,13.90,54.19)/(11.81,13.90,54); descent hits `_2100` at
(12.62,13.96,52.19). These are real horizontal wall contacts in the gate
opening. Inner ascent reports no blocking slide contact; the inner descent
reports only an upward-facing floor contact. Resolve those intermediate
waypoint/height demands separately before treating them as geometry faults.
All import/render/walk processes from this pass have finished or been stopped.


### Nested gate player traversal and internal parapet repair

The previous outer-gate obstruction diagnosis was a harness-coordinate error:
public fine cells are centred at integer lattice coordinates. The two fine
cells of a macro column have midpoint `3*c+0.75` authored metres, not
`3*c+1.5`. That half-fine-cell offset sent the player into the gate's right
pier. Corrected the traversal harness and platform review camera positions;
review now captures every tier gate rather than only the first. Intermediate
excavation cells supply XZ waypoints; actual character physics follows the
stairs, with the final waypoint also requiring the destination height.
The outer gate passes unchanged in both directions.

The correctly centred inner-gate walk did expose a real obstruction:
`kit.platform-wall/k0551` (collider 2286), a parapet on an internal boundary
of retained stone across the public landing. `BuildingKitAssembler.public_floor`
now reads the finished `PublicRealmSurfacePlan`. Two adjacent public floor
claims at the same band suppress the internal parapet/corner ornament;
structural bearing below and exposed edge guards remain. Rejected the looser
public-AIR predicate because headroom above a lower street is not a floor and
must not remove a fall-edge guard.

- Focused exposed-edge/internal-seam test: 4 assertions pass.
- 13/grand, final floor predicate: both gates, both directions pass with the
  production character and production kit/surface collision
  (`/tmp/nested-walk-floor-seam.log`, `/tmp/nested-walk-floor-seam.json`).
- 58/grand holdout also passed all four routes with the initial air predicate;
  rerunning it with the stricter final floor predicate before acceptance.
- Pre-repair platform/skywalk corpus: 13 tests / 2,142 assertions pass.
- Repair plus facade clearance/platform corpus: 12 tests / 2,253 assertions
  pass with initial predicate; final stricter predicate rerun in progress.
- Native initial-predicate views in `nested-gates-clear`: inspected inner gate
  13/grand and 58/grand overview. Both walled levels read clearly; the interior
  landing is open. These are isolated-town views, not world ground/grass proof.
  Castle faces remain repetitive and the tall gate architecture still needs
  the broader articulation/visual pass.

Final predicate verification completed:
- 58/grand: all four actual-player routes pass (`nested-gate-walk-58.json`);
  13/grand results saved in `nested-gate-walk-13.json`. Eight directional
  traversals total, correct destination heights, both lower and upper gates.
- Final focused corpus: 12 tests / 2,283 assertions pass in 81.025 s
  (`/tmp/fortified-floor-regression.log`).
- Final renders completed in `nested-gates-final` for both 13/grand and
  58/grand (3,748 and 2,761 instances; 14.770 and 7.498 s construction).
  Inspected final inner gate in 13/grand and inner flight in 58/grand. Gate
  entry is open; stair-side planter overlaps remain removed, masonry below
  remains continuous. Isolated ground and facade/castle artistry limitations
  noted above still apply. No process from these checks remains running.


### Landmark admission: reserve before optional descent

Current-state census reconfirmed 1/1/1/1 admitted landmarks in the four-town
edge corpus (total 4, required floor 7). Added candidate-refusal diagnostics
before the expensive realisation mirror: previously `tested: 0` hid whether
candidates lacked frontage, footing, minimum clear body or huddle height.
`landmark-candidate-refusals.json` records the evidence. Remaining available
footprints fail chiefly carved minimum body, huddle height and missing footing;
this is earlier planning pressure, not a broken native mesh.

Ordering experiments:
1. Reserve after gates/descent but before optional platform streets: 4 total,
   no improvement; reverted.
2. Reserve immediately after the main spine, before gates/descent: 6 total,
   but blocks mandatory gate routes and leaves raised districts uninhabited
   (5 failing tests, 14 failed assertions); rejected.
3. Main spine -> mandatory outer/inner gates -> measured landmark reservations
   -> optional descent -> district streets: 6 total, keeps tier access. This is
   the current candidate. Garden, support, huddle and edge constraints unchanged.
4. Protect every site found in the preview rather than the profile minimum:
   no further change (each preview has only one eligible held site); reverted.

The changed source admits 1/2/1/2 in the four-town corpus, saved in
`landmark-before-descent-census.json`. The admission gain comes from optional
carving seeing committed frontage earlier, rather than changing prefab size,
removing greens, lowering buildings or weakening the admission mirror.
Added a regression for the two restored-site towns; the existing seven-landmark
floor remains unchanged and red. Core layout run: 23/24 tests, 7,395/7,396
assertions; only total 6 < 7 fails (`/tmp/landmark-gates-first-regression.log`).
Skywalk, full bridge-house, fresh player gate walks and native visual checks
are running before this candidate is accepted as an incremental improvement.

Follow-up evidence rejected the landmark-only ordering as a final candidate:
while fresh 13/grand player walks pass both gates and the native 6/large
build succeeds (2,223 instances, 5.937 s), the complete 24-town bridge-house
survey falls from the required 12 to 8. No floating-mass failure was reported,
but losing the requested skywalk density is unacceptable. Small September 29
skywalk topology tests alone passed (4 tests / 6 assertions), illustrating why
they were insufficient for distribution acceptance. `street0` and `street3`
views from `landmarks-before-descent` are wall-occluded; use only the overview
as layout evidence, not these automatic cameras as street art acceptance.

Current next candidate reserves valid bridge spans and their complete load
paths immediately after the mandatory gates and landmark preview, before the
optional descent; later district streets can contribute additional spans using
the same existing quota and idempotent selection. This is under full-corpus
verification (`/tmp/co-planned-landmark-skywalk.log`), not yet accepted.

Joint planning follow-up:
- Reserving bridge supports before optional descent passes the focused landmark
  and 24-town bridge/float suite (8 tests / 123 assertions, 181.895 s), but
  the wider layout run exposes 7/48 rampart edges in the reported compact
  town, above the unchanged 10% ceiling. Thus it is still provisional.
- Excluding both outer rings from that early bridge pass restores the edge
  rule, but leaves 11 finished bridge houses < the unchanged required 12.
  `interior-bridges-regression.log`: 7/9 tests, 151/153 assertions; the other
  failure is the existing landmark total 6 < 7.
- Current next candidate excludes only ring depth zero from the early pass;
  later selection still uses the ordinary completed-street rules. Verification
  running in session 26890, `/tmp/outer-rim-bridge-regression.log`. Do not
  treat this candidate as accepted until that result is inspected.
- Unrestricted-early-pass fresh player 13/grand gate walks all pass; results
  in `/tmp/co-planned-gates-walk.json`. Native 13/grand views saved in
  `co-planned-landmarks-bridges` (2,764 instances, 10.642 s). Overview and
  skywalk side views inspected. The inner bridge-house shares a gate axis:
  `13_grand_skywalk1_side.png` exposes the decorative gate's tall stone piers
  and lintel intersecting the house windows/wall. Walking is clear but this
  visual composition is NOT accepted. Fit the gate beneath the carried room
  as a gatehouse; do not delete its building or disable collision.

Street-camera correction: random same-height route targets often lay behind
walls, and the old camera was 3.2 m above the walk. Review now uses 1.7 m world
height, collision-tested target sightlines, and the longest clear cardinal
view as fallback. Inspected `landmark-street-sightlines/6_large_street0.png`
and `street3.png`: usable views along the walk replace close wall shots.
They confirm long castle walls still need architectural articulation.
All earlier processes in this pass are terminal; only session 26890 remains
live at the time of this note. Baseline restoration copies for the current
experiments are `/tmp/landmark-before-spine-reservation.gd` (original ordering),
`/tmp/landmark-gates-first-no-early-bridge.gd` (6 landmarks, 8 bridges), and
`/tmp/co-planning-two-ring-exclusion.gd` (6 landmarks, 11 bridges, edge pass).

### Gatehouse fit beneath carried rooms (October 2 continuation)

`BuildingKitAssembler.gate_top` fits the complete gate frame below native
room bounds supplied by `KitVillageBuildings`; covered frames omit battlements.
Where even a complete lintel would violate public headroom, the carried room
supplies the header. No house is removed and emitted stone keeps collision.
Six gatehouse/nested-ring tests pass (147 assertions, 42.809 s). Inspected
`gatehouse-fit/13_grand_skywalk1_side.png`: gate piers and lintel now meet the
underside of the bridge-house instead of crossing its windows. Current town:
2,750 instances, 10.432 s. Both gates pass production-character traversal in
both directions (`gatehouse-fit-walk-13.json`, four routes). This accepts the
specific intersection repair, not the entire fortified-town art direction.

The ring-zero early-bridge candidate completed: 14 finished bridge-houses in
24 towns, but perimeter stone remains 7/48 and landmark count 6/7. It remains
unaccepted. A source/built diagnostic identifies the compact town's bridge
endpoint at (3,2)/(4,2), adjacent raised houses and plaza as the disconnected
rim segment. New experiment proves perimeter coverage around each proposed
bridge's foundations before committing it, using the existing plaza detour
criterion. Test session 6339, `/tmp/bridge-lane-fit.log`; not yet accepted.
Backup of preceding candidate: `/tmp/bridge-ring0-before-lane-fit.gd`.

Perimeter-detour experiment with the ring-zero mask completed: 7/9 tests,
153/155 assertions, 198.125 s. Edge checks pass, landmarks remain 6/7, and
finished bridges fall to 10/12. This is not accepted. Next candidate removes
the blanket ring-zero mask while retaining the measured perimeter-detour
admission rule (`/tmp/bridge-lane-fit-unmasked.log`). The previous candidate
is preserved at `/tmp/bridge-lane-fit-with-ring-mask.gd`.

Unmasked detour candidate also completes at 10 bridge-houses, 6 landmarks,
with edge checks passing (7/9 tests, 153/155 assertions, 195.832 s). Removing
the ring mask does not change the limiting admission. Kept the unmasked
variant provisionally because the actual street connectivity is the useful
constraint; whole layout acceptance remains open. Detailed source-to-built
attrition census now running in `/tmp/bridge-lane-attrition.log`.

A bounded four-choice landmark look-ahead was tested independently. It left
the four source counts unchanged at 1/2/1/2 and was removed: no demonstrated
benefit justifies its extra search cost. No acceptance floors were changed.

### Bridge attrition diagnosis and core-first candidate

Full detour-candidate census finishes with 14 source spans, 10 built bridges,
7 complete tunnel covers and no floating masses. Three composition releases
use the old generic doorway label. Added structured `yielded_conflicts` and
`reservation_conflict` audit details (cell, owner, required doorway top,
whether inside the compound's private body) without changing admission.
The first conflicts are:
- reported/standard bridge 1: earlier bridge 0's reserved envelope at (-1,7,6);
- 7/large bridge 0: house.008 at (1,4,2), outside bridge private body;
- 10/large bridge 1: earlier bridge 0's envelope at (8,7,3).
Thus two of the three are competing bridge envelopes, not house doorways.
The fourth source-to-built loss occurs before these final bridge outcomes.
Current next experiment ranks equally supported spans by greater massif
interior depth, preserving mass over central bores before choosing peripheral
spans. It retains the real perimeter-detour check and all support/door rules.
Verification `/tmp/bridges-core-first.log`, session 13413. Previous ranking
saved at `/tmp/bridges-before-depth-ranking.gd`. No acceptance claimed yet.

Core-first ordering regressed bridges further to 8 (7/9 tests, 153/155,
199.006 s), so it was reverted. A second landmark look-ahead over distinct
families also left counts at 1/2/1/2; removed rather than retain extra work
without satisfying the missing landmark requirement.

Next root-level experiment restores the 14-bridge candidate and extends the
perimeter a second time after secondary entrances have been carved. Those
entrances did not exist when the first lane pass looked for at-grade anchors;
a late pass may connect the far side of held foundations. It uses the exact
same perimeter algorithm, landmark reservations and bridge-bearing blockers.
No thresholds/support rules changed. `/tmp/late-perimeter.log` is running;
not accepted. The 10-bridge connectivity-rejection version is preserved at
`/tmp/bridges-detour-10-before-late-perimeter.gd`.

Late perimeter pass still reports the same 7/48 retaining edges and 6/7
landmarks; removed. Current source is restored to the 14-bridge ring-zero
candidate, with no experimental detour rejection, core-first ranking, late
perimeter pass, or landmark look-ahead. The diagnostic reservation-conflict
fields remain. Native compact-town review saved to `rampart-diagnosis`:
23 buildings, 1,034 instances, 2.518 s, one bridge-house. Overview and bridge
side inspected; neither exposes the complete affected lawn edge adequately.
Eight exterior views are now rendering to judge the actual rim defect before
further planner changes. Native textures show conspicuous roof speckling in
these shots; this must be checked during final visual review rather than
assuming the earlier geometry-only roof audits establish appearance quality.

Exterior `edge0`/`edge1` renders now inspected: the affected town does present
a continuous tall blank stone base to the lawn. This is a real visual defect,
not merely an arbitrary count failure. Do not accept the 14-bridge candidate.

Correction to prior experiment labels: `WarrenMassif.ring_depth` is ONE-based
(1 at boundary, 0 outside), whereas `_bridge_span_exterior_depth` is zero-based.
The supposed "ring-zero exclusion" excluded no massif columns. The earlier
`< EDGE_RINGS` experiment excluded only the boundary, not two rings. Its
measured result was 11 bridges with passing edge checks. Corrected the early
filter to explicit `ring_depth == 1`. Keep these two depth conventions distinct.
Late-pass test ended 7/9, 150/152 assertions, 198.905 s; its bridge floor passed,
but both edge and landmark failures persisted. All processes in this turn
are terminal. Gatehouse repair remains intact; current source filter is the
actual boundary-only variant, still awaiting final layout acceptance.

### Precise bridge conflicts, full future reservations, and real player walks

Corrected boundary-only source filter: 11 bridges; edge checks pass; landmarks
6/7 (7/9 tests, 151/153 assertions, 204.806 s). Blanket per-part recipe
reservations restore 7/large but lose other bridges to later roof construction
(10 total; 8/10 tests, 156/158, 223.059 s), so that broad shrink is rejected.
Final candidate retains the full conservative reservation against future
construction and resolves only existing mandatory-owner conflicts against the
union of measured part bounds. Empty aggregate-box cells may keep their existing
owner. Actual body/part intersections still reject the compound. Four tests /
96 assertions pass in 205.097 s, including 12 finished bridges in the 24-town
corpus and zero floating masses. New `test_october1_bridge_envelopes` pins
7/large, complete construction, floating-mass absence and finished roof/public
triangle clearance. This is a geometric sub-gate, not full art/traversal approval.

`nested_gate_walk.gd --skywalks` now exercises upper links and source-bore route
segments in both directions. Targets sample actual collision height, necessary
on sloping treads (7/large's starting macro centre is y=0.75, not its band y=0).
The bore passes both ways. Upper endpoints initially had NO floor ray hit and
the actor fell: the kit only boarded visible soffits, omitting floors over lower
rooms or retained stone. `BuildingKitAssembler` now boards all inhabited
storeys, keeping exposed-soffit trim separate and avoiding duplicate boards.
Rays now hit the floor at y=6.25544 / 18.25544; the actor stays supported.
Upper walks still FAIL at actual closed door meshes (Pure Village plaster doors
and Suntail frame doors), not at the floor. Therefore do not call upper traversal
accepted yet. Preparing four native open-frame passage variants by removing
only authored leaf mesh nodes from visuals AND collision. Manifest:
`tools/environment_bake/manifests/town_passages.json`; bake running in session
32219, `/tmp/town-passages-bake.log`.
No role/placement integration yet. Source imports copied for two Suntail door
models and nine texture dependencies; primary checkout untouched.

Native `bridge-part-envelopes` compact edge0 now shows inhabited, windowed rooms
at grade instead of the continuous tall blank stone base. 7/large automatic
skywalk side view is occluded and is not accepted visual evidence. Native views
predate inhabited-floor addition. Logs for player stages:
`/tmp/bridge-parts-walk.log`, `/tmp/bridge-walk-surfaces.log`,
`/tmp/bridge-room-floors-walk.log`. All test/render/walk processes are terminal;
only passage bake remains active at this note.

### Open native passage frames and inhabited floors (October 2)

Four baked open-frame variants now replace closed leaves only at explicitly
claimed passage-house endpoints: Suntail timber/deep stone and Pure Village
plaster/stone. Native leaf mesh nodes are excluded from the merged visual and
therefore its measured collision; jambs, lintels and reveals remain. Separate
`wall.*.passage` roles inherit their pack's wall anchors. Passage edges keep
OPENING_DOOR semantics for layout but suppress entrance props/awnings. Ordinary
exterior doors retain their authored leaves. Bake completed; catalog index IDs
minimized with existing script. Manifest/provenance pack is `town_passages`.

7/large production-player walks pass both directions on two additional
passage-house links, the restored source bridge, and its underlying street:
eight routes, `open-passages-source-walk-7.json`. Actual walk support, not a
room count, now establishes this local traversal result. Floors are continuous
in inspected native `open-passages/7_large_lower.png` and `upper.png`; both
pack frames form clear openings. `underpass.png` shows the lower street's
mixed-kit facade relief and unobstructed walking surface. Native 7/large:
2,648 instances, 8.114 s (not an isolated performance benchmark).

Four-frame collision probes pass: wall/jamb mesh remains and body-height
segments through each opening remain clear. The related batch passed ten of
eleven tests; only the roof test's negative-control assertion failed because
both newly generated cases had zero raw intrusions. Preserved that assertion
and added the frozen photo source, not a weaker threshold. It has 1,030 raw
intrusions and zero finished intrusions; the revised test passes all ten
assertions in 33.125 s. The other ten tests in the batch include native bridge
envelope preservation, all four passage assets, September 29 skywalks, and
nested fortified-ring checks. Logs `/tmp/open-passages-regression.log` and
`/tmp/roof-air-pinned.log`.

Holdout reported compact town: upper passage passes both ways, lower route
forward passes. Reverse reaches the destination supported at y=3.05094, while
the centre-ray target on the slope is y=2.73. The harness now bounds final
height agreement by the actual character MAX_STEP_HEIGHT (0.5 m) and requires
is_on_floor, rather than an unrelated 0.3 m point-height tolerance. The capsule
can stand on an adjoining tread. Rerun this holdout with the corrected oracle
before claiming it passes. A centre ray can also miss the sub-millimetre board
seam at the source bridge's module edge; its actual capsule walk passes.
Full-world route access, broader visual/performance acceptance and the landmark
6/7 failure remain open. No complete redesign acceptance is claimed.

Compact holdout rerun completes successfully: its additional passage-house,
source bridge and underlying street each pass both directions (six routes),
`open-passages-compact-final.json`. Combined with 7/large this is fourteen
production-player route checks across two layouts. Native mixed-frame/floor
views have been inspected. This accepts the local missing-floor/closed-leaf
repair; it does not establish whole-world access to every endpoint or close the
remaining redesign goals. All processes launched in this open-passages pass
are terminal. `git diff --check` passes.

### October 2 continuation: production grass and filtered native materials

Added `town_world_ground_probe.gd`, using the actual world frame at seed
2697992464 / super-cell (0,1), production town record, road projection,
graded terrain and GrassField. The initial zero-grass result was a HARNESS
ERROR: its field cache omitted GrassProgram's shoreline query range, so
`shore_distance_at` returned its configured zero limit on dry ground. The
corrected probe takes the combined range used by FieldTerrainStreamer.
No production terrain/ecology change was made from that false result.
Final `world-ground.json`: six tiles, 766 grass patches, 143 roots inside
reserved green columns, zero roots on painted paths. All 22 sampled town
surface labels match the complete world context. The actual town also
contains one tree and a two-prop group. This proves worker integration at
this site; fresh streamed visual acceptance is still running.

Matched exterior inspection exposed speckling on Suntail roofs and timber.
Its baked 2048px textures had no mipmaps. A controlled in-memory mipmap
study removed the roof speckles. The accepted candidate uses full-resolution
Basis textures with normalized normal-map mipmaps, preserving geometry and
palette. `rebake_material_textures.gd` reuses the normal baker's texture path
and manifest policy, preserves geometry/source provenance, rejects changed
geometry parameters or lossy re-encoding, and supports a no-op repeat when
the policy is already applied. Suntail's full manifest now declares the
same filtered compression policy as Pure Village. Matched production
`filtered-native/*edge0.png` and `*street0.png` inspected: clean shading,
visible native wood detail and stone reveals. No runtime mipmap workaround.
Suntail building family: 74 maps, 192,000,608 decoded compressed bytes
(including mips), versus 575,995,904 base RGBA bytes before (549→183 MiB).

The new open frames had duplicated Pure textures under a separate passage
pack: 59 maps / 314,225,328 bytes, exceeding the unchanged 44-map/230 MiB
budget. Split the frame manifests into their parent texture namespaces
(`town_passages.json` = Pure; `suntail_passages.json` = Suntail), rebaked all
four frames and removed only the now-unreferenced newly-created
`town_passages` output folders. Pure returns to its existing 44-map budget.

Isolated October 1 run: 21 scripts, three failed tests (all other tests pass).
One was the real texture duplication; two were layout-sensitive test
preconditions (18 roofs versus >20, exactly20 stair triangles versus >20),
with their actual closure/clearance invariants passing. Roof study retains
all original live jobs and adds the frozen reported construction; each is
still a complete town (>10 roofs), with >60 roofs across the corpus
preserving original total coverage. Stair test checks both current and
frozen reported stairs, retaining zero misses and the original >20 samples.
Final focused rerun: 5 scripts, 8 tests, 1,925 assertions pass in113.831s
(`/tmp/town-final-textures-tests.log`), including both texture budgets,
native/mixed roof closure, stair clearance and open-frame collision.
Full original isolated evidence: `isolated-october1-before-texture-fix.txt`.

Fresh production world capture is running in `town_world_review.tscn`
(session35813, `/tmp/town-live-world.log`, output `live-world/`). It uses
real terrain, grass and streamer, with both greens and reported camera
locations. Whole-task acceptance remains open; do not equate the worker
probe or material repair with approval of the full town redesign.

Follow-up: repeating the material-only bake with the same policy completes
without re-encoding. The short landmark experiment raised the held quota
from profile minimum to maximum; counts remain1/2/1/2 because the pre-carve
preview finds only one valid held site in each town. Reverted immediately;
no quota change remains. A complete isolated current-tree sweep is now
running (`/tmp/october1-full-current-suite.txt`, session7783). It is diagnostic
until failures are compared against baseline; the old partial sweep stopped
for missing character assets and is not a baseline pass claim.

### Fresh streamed world and fire effects (October 2, continued)

Restored the ignored Meadow rock source dependencies into this isolated checkout
from the primary checkout (read-only source); no terrain implementation changed.
The complete native world run (`/tmp/town-live-world-complete.log`) reached ready
and wrote 13 captures under `live-world-complete/`, with no script errors or
missing-resource errors. Copied import UID fallback warnings remain an environment
cleanup item. The wide/owner-overview and green views confirm actual streamed
grass, a tree, contextual props and clean mipmapped roofs. The reverse-green
camera is occluded and is not acceptance evidence. Frozen character positions
are not player grounding tests.

The owner-walkway reconstruction exposed a new floor/window contact: inhabited
floors added for bridge endpoint collision were absent from the facade opening
fitter. Native board placements now share one assembler method with that fitter;
the complete measured slab thickness participates in opening fitting across all
houses, including staggered half-storey neighbours. Public headroom remains air.
Focused facade and bridge checks: 12 tests / 154 assertions pass; matching native
render is in progress. This does not yet close full-world walkway acceptance.

Campfires now render animated flame particles and warm local light through
`EnvironmentCampfires`, owned by the streamed placement container and attached
only once per multi-piece asset. Both native fire models have measured sockets;
flames and lights follow placement scale/rotation. The first effect was too tall
and bright and was reduced. Final day, animation-phase and night images in
`campfires/` show flames fitting the log pile and cooking rig. Campfire, commit
queue and lantern tests: 11 tests / 110 assertions pass. Cancellation creates no
orphan effects; unload uses ordinary container ownership. The running isolated
full-suite glob predates the new fire test, so its focused run is additional.

Private-floor follow-up: the matched native view in
`private-floor-contacts/walkway.png` now has complete plain panels where the
neighbouring floor previously bisected windows; unobstructed windows remain.
Final facade/bridge run: 13 tests / 294 assertions pass
(`/tmp/town-private-floor-final.log`), including the complete current reported
mixed town. The initial broad placement audit also encountered a pre-union
`gable.wall` window (`kit.spatial.parcel.maze.house.003/k0121`); roof pieces are
subsequently clipped and are outside the storey fitter. The final facade test
checks finished wall/bay panels only. Follow up on the realized gable glazing
before full architectural acceptance; do not treat the raw placement as proof
of a visible defect. `git diff --check` passes.

The isolated full suite continues as session 7783, summary
`/tmp/october1-full-current-suite.txt`. All October 1 files included in its
initial glob passed. Other failures still need baseline/environment comparison;
no global regression claim is made from the partial run.

### Gable floor contacts (October 2)

The previously flagged gable window is a real contact: inspection of realized
geometry found its 1.114 native-square-metre glazing remained intact after union.
Rectangular gable panels now participate in floor-contact fitting, using a complete
plain panel of the same kit when obstructed. Roof ownership and triangle-union
closure remain intact; native plain Suntail panels were added to the baked roof
geometry through the normal roof-data baker. Pure's plain role uses its native
panel and anchor. The first candidate incorrectly counted the gable's own roof
as an obstruction (all 14 glazed gables changed); rejected. The final pass uses
only actual public/private floors and changes one gable in this town. The whole
mixed-town regression now includes gables and requires clear gables to stay glazed.
Final roof/facade suite is running at `/tmp/town-gable-final-tests.log`, session
10299. Earlier candidate closure checks passed but are not final acceptance.
The initial close camera was foreground-occluded; a corrected capture is pending.

Final gable/facade/roof suite: 13 tests / 1,467 assertions pass in 87.259 s
(`/tmp/town-gable-final-tests.log`). This includes native Pure roof closure,
mixed-family holdouts, floor-obstruction checks and preservation of clear gable
windows. `git diff --check` passes. Both attempted town close views are occluded
by neighboring geometry and are not used as visual acceptance of this gable.
The broad isolated suite remains live (session 7783), currently in September 10
legacy tests; its non-October failures still require baseline comparison.

### Fortified masonry proportions (October 2)

Fresh 13/grand and 58/grand platform renders confirmed vertically stretched
bricks on tall corner piers and excessively tall free-standing gate openings.
`_emit_pier` now builds equal courses no taller than the native 3 m panel;
all four faces and the top cap remain. Free gate rise is 4.2 native metres
(previously 5.8), retaining the carried-room fit and minimum headroom check.
The opening is 3 m tall below its 1.2 m header, versus 2 m clear width.
Header sections preserve the native masonry face aspect ratio, replacing the
single horizontally stretched panel. No seed-specific rule was introduced.

Matched images in `fortified-masonry/` show normal brick courses and the lower
header. Both complete gates in each town pass actual-player walks in both
directions: 8/8 routes, with traces in `walk-13.json` and `walk-58.json`.
These walks include the lower header and coursed piers; the subsequent header
subdivision preserves its outer extent. Gate/ring suite: 7 tests / 165 assertions
pass. Final header geometry checks: 3 tests / 111 assertions pass, including
all four orientations, carried-room fit, headroom and material aspect ratio.
`git diff --check` passes. Instance count in 58/grand rises from 3,733 to 4,005
before header subdivision (~7%); full-world performance acceptance remains open.
This improves fortification masonry but does not close broader wall articulation,
wooded-town review or the landmark regression.

### Wooded layouts and native shelters (October 2)

Fresh large-town dressing renders at seeds 13, 34 and 60 produced 10/13/10
trees and 2/6/6 contextual groups. Overviews saved under `wooded-review/`.
They still read as dense towns with trees largely around their edges, rather
than convincing wooded interiors. Do not accept the wooded endpoint on counts
alone. Woodland currently affects dressing density but not clearing dimensions;
the protected-crown/descent rules and available interior footprint need the
next planning review. No field/clearing rule was changed in this iteration.

The 13/large close-up exposed an unsuitable ordinary-camp asset: Battle Pack
Tent1 has fragmented, torn cloth. A six-variant gallery and direct source render
confirmed the bake matches the imported source, so this was not a bake repair.
Inspected the Fantasy Village native tent modules instead. Their white, blue
and red 4.24 x 3.03 m timber/canvas shelters are now baked as `sfv.shelter.*`
through `town_shelters.json`, with native materials, compressed mipmapped
textures, complete mesh collision and provenance. Runtime has no source-pack
dependency. These three variants replace the ragged tent in ordinary town
activity groups; the Battle Pack asset remains available in its catalog.
Companion barrel offset is 3.5 m and passes the existing measured-fit rules.

The smaller shelter fits closer to the building and leaves room for three more
trees in 13/large (13 instead of 10). Above and two side views in
`shelter-review/` show complete cloth, planted posts, clear companion placement
and separation from the neighboring house/tree. Added side shots to the town
review harness because a foreground tree occluded its original front camera.
Dressing + full catalog checks: 30 tests / 114,963 assertions pass
(`/tmp/town-shelter-tests.log`, 80.264 s). `git diff --check` passes. Catalog
index preserves existing resource IDs and now has 40 added descriptors for
this redesign. Source/import dependencies were copied only into this worktree
from the primary checkout; the primary checkout was not modified.

### Natural inter-lobe planting pockets (October 2)

Field inspection showed high-woodland towns already contain empty ground between
lobes, but `TownGroundDressing` only admitted explicitly carved circles and
cottage gardens. New planting-only candidates include whole empty macro cells
inside the convex hull of the existing massif. They never erase or lower a
massif, create an activity group, change the route grid or expand the root domain
outside the town outline. Actual roots still need dry, nearly level natural
terrain and clearance from paths; measured canopy bands still avoid buildings
and public volumes. Urban woodland=0 remains treeless. Added audit count
`natural_pocket_trees` distinguishes these placements.

Matched native overviews in `natural-pocket-groves/` show groves between the
outlying houses while retaining the same dense central construction. With the
new canvas shelters already in place, trees increase 13→14 at 13/large,
13→45 at 34/large and 10→24 at 60/large. This is a visible improvement,
not acceptance of every wooded layout or of production terrain integration.
Dressing suite: 10 tests / 709 assertions pass; the new courtyard test proves
natural pockets are eligible without mutating construction or reserved greens.

A production-site survey using the canonical settlement and town-seed derivation
found high-woodland towns at world seed 2697992464, supercells (-2,-2), (-1,0)
and (2,1), all radius 5. The (-1,0) world ground/grass probe is running as session
34251 (`/tmp/town-world-wood-ground.log`). The first launch used an unsupported
combined CLI flag and was cancelled before restarting with the correct separate
`--site` argument; it is not evidence. Full isolated suite session 7783 remains
live and has reached September 29 tests; baseline comparison is still pending.

### Wooded production ground and regression triage

The production ground probe for world seed 2697992464, supercell (-1,0),
completed successfully. `world-ground-wooded.json` records nine trees (four
in natural interstitial pockets), four props in two groups, and woodland
0.996. Eight grass tiles contain 1,212 patches, including 256 inside reserved
greens and zero on painted paths. All 20 sampled town/world surface labels
agree. This is production terrain/grass evidence; native visual acceptance is
still running as `/tmp/town-world-wooded-native.log` (session 52065).

Two older assertions needed their original scope restored after the new kit
and layout. The materials test now uses catalog arch/gate tags plus the
`tunnel-mouth/` placement prefix, instead of banning the substring `arch`
(which incorrectly rejected Pure Village arched wall windows). All five tests
and 3,475 assertions pass. The floating-mass corpus remains intact, with a new
positive cover pin at 7/compact (4,1): an eight-cell inhabited room above crown
band 3, borne on jambs (3,1)/(5,1). The complete-crown, whole-room and public-air
checks all pass: five tests / 72 assertions. An all-absent corpus still fails.

Landmark admission now reuses the failed-enumeration audit for remaining
quota slots when no candidate exists and no candidate was refused by
`add_plot`. The plan, blocked columns and template usage are unchanged in
this case. Four complete pre/post landmark plot/audit outputs compare exactly.
Single-run source timings were 273/697/949/1745 ms before and
158/407/443/641 ms after; these are concurrent-work observations, not an
isolated performance benchmark. All five October landmark-reservation tests
pass. The older 42-test maze-plots file still has 14 failing tests and needs
baseline comparison; the optimization does not claim to resolve them.

Created a managed baseline checkout at
`/Users/ryko/.codex/worktrees/town-redesign-baseline/story`, ref b8e130d9,
for comparisons against current failures. Native terrain/character dependencies,
import cache and ignored GUT dependency were supplied locally. The first
comparison attempt lacked GUT and ran no tests; its results are invalid.
The corrected runner now fails immediately if a test file produces no GUT
summary. Baseline results: `/tmp/town-baseline-comparison.txt` and its `.logs/`
directory. The full current sweep remains live; broad acceptance is open.

Wooded native pass completed with `ready=true` (seven images). Inspected the
wide view and both original close views. `wooded-world/wide.png` shows the
dense mixed-kit centre retained amid peripheral groves; `courtyard.png` shows
grass, a lit cooking rig and a tree between Pure and Suntail facades. The first
`wooded_green` position was mistakenly in an unreserved cell and landed inside
a house; reject it as green evidence. Corrected the harness to the verified
natural cell at (-302,444), and derive both wooded camera targets' heights
from the production graded terrain kernel instead of assuming y=14. The new
native run is `/tmp/town-world-wooded-grounded.log`, session 62726. This remains
a visual harness, not actual-player traversal evidence.

The baseline comparison is now genuinely executing GUT, session 44389. Its
first file reproduces the foot-line failure (4 tests, 3 pass), without the
current sweep's missing-source script error. The full current sweep (7783)
is still live in September 9 tests. Do not count the earlier no-GUT attempt
(session 91200) as a pass. Landmark total 6/7, remaining old-suite failures,
full route access and final performance/art acceptance remain open.

### Construction regressions isolated against baseline

`test_excavation_construction` passes 7/7 at b8e130d9 but failed two checks
in the redesign. Diagnosed both rather than changing their assertions:

- 17/standard's citadel flight lands at macro (3,4,4), exactly on the old
  envelope top. `WarrenMazeVolumeAdapter._derived_massif` now includes the
  headroom of published public walk cells. The existing derived-void pass
  subtracts that air; no extra solid crown is created. With this fix alone,
  the test improved from 5/7 to 6/7.
- 17/grand's climbing loop had five collinear steps because
  `_climbing_loop_candidates` bounded total length but omitted the straight
  run check used by ordinary alleys. It now checks the anchor plus complete
  candidate cells before expanding or admitting a stride. The cap stays four.

Combined excavation/floating checks are running in
`/tmp/town-excavation-fixed.log` (session 42178). These edits need the bridge,
edge and volume/solid corpus follow-up; no broad pass is claimed yet. The
wooded native run 62726 began before these two source fixes and cannot
validate them. Baseline comparison remains session 44389; first four files
show excavation as a genuine new failure, while dressing/feature-program
also fail baseline (with more failures there). Continue comparing individual
assertions, not only aggregate counts.

### Gate-air, loop and landmark follow-up

Combined excavation/floating suite passes 12/12 tests and 140 assertions.
Added an explicit positive crown-landing assertion: all newly enclosed
headroom remains absent from `mass_cells`. Excavation now passes 7/7 tests,
73 assertions. The broader tunnel/bridge/edge run retains 12 complete bridge
houses across its 24-town corpus; floating/bridge checks pass, and its only
failure was the old seven-landmark aggregate (11 tests, 10 pass, 205/206).

The landmark count was finally compared to actual baseline sites instead of
trying further quota/ranking adjustments. `landmark-site-comparison.json`
contains b8e130d9 and current source plots plus current reserved greens.
Counts are 1/1/3/2 before versus 1/2/1/2 now. In 3/standard, the three old sites
intersect new reserved greens in 8/12, 2/9 and 6/12 columns respectively.
Both old 6/large sites also overlap greens, but that town retains two elsewhere.
Every currently held site survives with its complete footprint, datum and top.

The September 29 edge test now checks the original lane-protection contract
directly for all four towns: each nonempty pre-carve landmark reservation must
survive as a whole site; every admitted landmark must have a public address
and a successful composition outcome at that address. The old aggregate could
hide a stolen site behind an extra prefab in another town and also demanded
building sites the new requested greens deliberately remove. No production
quota, terrain or layout rule was changed to satisfy the test. The first
version also demanded an unchanged doorway; 6/large correctly addresses its
same site from a new perimeter street, so the final version verifies the
actual public doorway and its matching built outcome instead. Final edge
verification runs in `/tmp/town-edge-sites-final.log` (session 39576).

Final edge-site test passes: six tests / 81 assertions, including whole
held-site retention, public addresses and successful composition of every
admitted prefab. The earlier 6<7 count is explained and superseded by these
site-preservation checks, not an unresolved production quota defect.

Grounded wooded world run 62726 completes with `ready=true`; inspected both
corrected close views. Saved `wooded-world/green-grounded.png` and
`courtyard-grounded.png`: tree trunks meet the grassy green, the cooking fire
is grounded between differently detailed Pure/Suntail facades, and the open
courtyard connects visually to the dense central buildings. No new clipping
was apparent in these views. The larger blank Pure gable remains an art-detail
opportunity, not covered by the foreground facade views alone. This is visual
acceptance for this wooded courtyard; full traversal and broader performance
acceptance are still outstanding.

### Complete entrance-to-tier collision walks

Extended `nested_gate_walk.gd --from-entry` to prepend a breadth-first route
from the town entrance to each gate's approach. The graph uses only published
spine/lane/loop edges; it never joins nearby points geometrically or teleports
between intermediate landings. The production CharacterBody/controller walks
the complete approach and gate flight, then walks back to the entrance.

13/grand and 58/grand each have two fortified tiers. All eight complete
outbound/return routes pass with physical support at the endpoint and the
production step-height tolerance. Evidence: `entrance-walks/13-grand.json` and
`58-grand.json`. This closes the prior local-gate-only gap for these two towns.
It uses the actual kit and public-surface collisions in the isolated town,
with ground-street support boxes; it is not an overworld terrain/streaming walk.

Baseline comparison also identified the old rim-access assertion as new red:
it expected every rim column to accept a bore, including the new reserved
cottage footprint. The test now requires ordinary rim/green cells to accept
at-grade streets and cottage footprints to reject them, while keeping the
below-ground prohibition and rim-height checks. An initial attempt incorrectly
classified all greens as unborable; inspection of `slot_is_borable` corrected
that assumption. The full city-form file improves from 7/10 to 8/10,
8,367/8,369 assertions. Its remaining two failures also fail at baseline;
see `/tmp/town-rim-cottage.log` and baseline comparison logs. No production
boring rule was changed for this test.

### Comparable CPU generation measurements

Added `tests/harness/suntail/town_generation_profile.gd`, runnable by absolute
path with either checkout's `--path`. It measures source planning, composition
and native kit assembly separately with identical jobs/order. It excludes
terrain, rendering and ground dressing. Saved results in `performance/`.

| Size / seed | Baseline total ms | Current total ms | Baseline kit ms | Current kit ms | Baseline / current instances |
|---|---:|---:|---:|---:|---:|
| compact / reported | 1840 | 2370 | 259 | 1137 | 1524 / 1285 |
| standard / 3 | 5087 | 3850 | 811 | 1470 | 2688 / 2034 |
| large / 34 | 11268 | 7032 | 1275 | 2655 | 4024 / 2967 |
| grand / 13 | 13455 | 10162 | 1338 | 5636 | 4163 / 3129 |

The new kit geometry/clearance work is more expensive. Fewer dense parcels and
faster planning/composition offset it in three samples. Static Godot memory
at the grand sample is about 959 MB current versus 957 MB baseline; this is
not GPU memory or peak RSS. Background regression tests were active, so these
single-run wall times establish scale and bottlenecks rather than a precise
speedup claim. Baseline logs contain UID path-fallback warnings; neither run
has script errors. The native `kit_town_review --profile-frames` now saves
120-frame samples after 60 warm-up frames, with uncapped/VSync-off frame time,
measured GPU/render CPU time, draw calls and primitives. Four dressed-town
overviews are running in `/tmp/town-render-performance.log`, session 23173.

Native render profiling completed on the M1 Pro, 1600x900 Forward+, overview
cameras with dressing. Median / p95 frame intervals: compact 3.362/4.258 ms,
standard 3.861/4.222 ms, large 5.461/5.720 ms, grand 5.073/5.836 ms. Draw calls
are 1,343–1,793 and rendered primitives 0.99–4.03 million (including all
render passes). GPU timing reports zero on this backend and is unavailable,
not zero GPU work; the harness now labels that explicitly. Saved JSONs under
`performance/`. These isolated town scenes exclude production terrain/grass,
streaming and gameplay, so this is a town-render cost check, not a whole-world
frame-rate guarantee. Inspected the large and grand overviews again: detached
cottages and groves remain distinct from the denser central massif; mixed roof
families, elevated routes and fortified masonry remain legible.


### Streaming repeat checks and full-suite completion

The campfire lifecycle test now completes three chunk generations with the same
stable camp ID and reused queue/cache. Each generation creates exactly one flame
particle system and one light, and freeing the invalidated chunk destroys both.
`test_october1_campfires`: 3 tests / 32 assertions pass
(`/tmp/town-fire-reentry.log`). The real-green dressing test also rebuilds a
second town from identical pre-dressing inputs and checks exact entry and audit
identity: 10 tests / 711 assertions pass (`/tmp/town-dressing-repeat-final.log`).
The initial repeat fixture omitted its public network ID; that fixture was
corrected before accepting the result.

The isolated current suite completed all 366 files: 1,950 tests, 1,768 passing,
150 failing, 29 script-error occurrences across 89 failing/error files. The
remaining count includes pending/other GUT statuses. This run began before the
latest focused repairs; its failures are not a final regression verdict.
Report: `/tmp/october1-full-current-suite.txt`. Baseline comparison batch one
completed; batch two is still running in `/tmp/town-baseline-comparison-second.txt`
(session 29837), against the attached unmodified baseline source checkout.

Plot mutation unit tests now use the existing frozen, plot-free shoulder source
rather than generating an unrelated raw street network with currently invalid
unsealed gates. All those mutation checks pass; the full plot file remains
34/42 passing. Its buildable/frontage metric now excludes explicitly reserved
ground (no thresholds lowered). Four unfilled frontage columns remain: two
12/compact columns were claimed during reservation but released later; another
12/compact street was pruned; 9/standard's column has lost its original support.
These require stage-aware diagnosis, not an automatic coverage exemption.
The 9/standard skin/ownership floors and the skyline positive corpus also remain
open. Diagnostic evidence: `/tmp/town-plot-ground-domain.log`,
`/tmp/town-plot-diagnose2.log`, `/tmp/town-plots-{seed}-{profile}.txt`.

A related source-stage mismatch was identified but not changed: 9/standard's
first selected bridge is later refused by `_bridge_compound_taken` because the
extra neighboring-column roof check meets a prefab's clearance. The bridge
selector avoids the preselected landmark's measured envelope, whereas this
later check adds another halo. The landmark is itself a held pre-carve site;
simply rejecting that landmark would violate its preservation contract. Any
repair must align these envelopes and retain actual roof/public clearance,
then recheck the bridge corpus and native visuals.


### Reserved landmarks, bridge envelopes and actual landing heights

The 9/standard bridge refusal was traced further: the original landmark site
remained valid after carving, including native body/bearing and door checks, but
`_best_asset_site` preferred a different prefab at band 4 instead of the held
band-0 site. `_site_less` now prioritizes still-valid exact held footprints,
floor and top before the ordinary variety/cut ranking. This changes no validity
rule. Its measured exterior-rock ratio fell from 0.44853 to 0.33962, satisfying
the unchanged 0.38 ceiling; its ownership floor also passes. Both source bridges
now build. Expanded the landmark preservation regression to 9/standard alongside
6/large. Landmark plus edge checks pass.

This exposed another mismatch in 7/large: preserving its originally held native
prefab let a redundant neighboring-macro-column halo reject its bridge. The
prefab's published reservation already includes measured eave clearance and the
future house margin. `_bridge_compound_taken` now checks that reservation on the
compound's own columns, retaining its vertical roof allowance and ordinary plot
intersection checks. Native roof fitting still checks actual neighboring walls.
The supported bridge and its public-air/floating-mass checks pass again. Combined
landmark/edge/bridge suite: 13 tests / 170 assertions, all passing
(`/tmp/town-single-envelope.log`).

An actual CharacterBody walk then caught an independent open-span defect: the
coarse walked set included a swept stair cell as a level endpoint. The cell's
actual treads were at a different height; the bridge met its side rail.
`_maze_skywalk_network_from` now excludes transition-geometry cells as endpoints
while retaining flat end landings. The selector finds another valid crossing
instead. Added endpoint assertions across the public span lanes. Skywalk suites:
6 tests / 59 assertions pass (`/tmp/town-flat-bridge.log`). Final real-player
walks: 7/large 8/8 and 9/standard 6/6, covering the surviving links, complete
source bridge houses and underpasses in both directions. JSON evidence is in
`held-landmarks/player-{7,9}.json`. These still use the isolated collision town,
not an overworld streaming walk.

Native images from `/tmp/town-flat-native/` inspected: 7/large overview and
bridge-side street, plus 9/standard overview. Saved selected views under
`held-landmarks/`. Dense tiered massifs, low native landmarks and mixed roof
families remain; the invalid stair-side bridge is gone. Earlier skywalk-camera
below/side views can land inside neighboring structures and are not acceptance
proof by themselves. The street-level house-over-passage image has closed
facades/soffits and a visible through-route; the player test supplies collision
proof. A small beam end is visible emerging beside the left foreground roof;
review its ownership/contact before calling all final intersections accepted.

The board-roof material regression now compares against the actual native floor
board maps rather than content hashes from the obsolete uncompressed texture
bake, and also requires mipmaps. All 11 architecture tests pass. The foot-line
script error in the initial full suite was the then-missing ignored Meadow source
asset; it now loads, with the same UID-fallback warnings that fail the baseline.
No terrain production code was changed for that test.

All 89 initial failing/error files now have baseline comparisons; consolidated
results and new failing method names are in `regression-comparison.json`.
Important: fewer total failures can conceal new ones, so method names were
compared too. Legacy composition tests still include small-corpus count pins,
retaining stone in every town, removed turf lips, and old rendered roof recipes;
these are not automatically production regressions. The current plots,
composition and 24-town supported-bridge suites are being rerun after these
changes (`/tmp/town-final-layout-regressions.log`, session 90638). The positive
skyline fixture now additionally exercises measured 7/standard; translator
non-vacuity requires actual houses rather than an unrelated five-house quota.
Density/ownership/rock thresholds were not lowered.

Remaining source coverage diagnosis: 12/compact selects a bridge with foundations
at (1,-3)/(1,-4) and (1,-1)/(1,0), reserves those from partition, then destination
pruning withdraws the bridge's street and proof. Two remaining at-grade frontage
columns stay empty because partition has already run. This is a real phase-order
opportunity, distinct from reserved greens and pruned demand, and is not repaired
by the landmark priority change. No speculative second partition was added.


## Released bridge sites: bounded infill and final plot demand

The withdrawn bridge foundations in 12/compact are now reclaimed after public
pruning. The pruning pass records only released proof columns, excludes still-held
proofs, and the plot planner runs one bounded ordinary-house infill pass there.
It retains existing plots, public routes and reserved greens. New plots use the
same growth, doorway, support and height rules as ordinary houses. The pass is
idempotent. Missing buildable frontage in the reproduced town falls from three
columns to zero. Native overview and street images were inspected and retained
in `released-bridge-sites/`; the large green breaks survive and the added frontage
fits the mixed town.

`test_october1_released_bridge_sites` proves both the source transaction and the
resulting built houses, including unchanged existing plots/routes, positive
reclamation, supported private cells, zero floating masses and zero finished
roof/public-air intrusions. Combined with excavation construction and build-order
checks: 11 tests / 114 assertions pass (`/tmp/town-released-final.log`).

The plots test's demand domain now also respects the perimeter height envelope:
a frontage whose minimum house would exceed its allowed top is not buildable
demand. This resolves 9/standard's band-5 frontage with cap 8 and required top 9.
The 0.89 coverage floor is unchanged. All 36 towns in seeds 1–12 across compact,
standard and large were surveyed with the independent full-stack oracle: baseline
six stacks, current five (8/standard two, 4/large two, 10/large one). Added the
positive 8/standard case to the retained stack corpus and use it for the flat-roof
host parity test. Final plots suite: 40/42 tests pass, 2622/2633 assertions
(`/tmp/town-plots-final-fixtures.log`). The remaining two methods also fail at
baseline and contain older floor/gap/refusal assertions; this is not a claim of
a clean legacy suite.

The latest 24-town source bridge survey now builds 13 bridge houses (baseline
8), with zero floating masses. This count is distinct from optional exterior
open links. The combined layout suite predates the final infill change; its
legacy composition failures still require classification against the production
native output.

The foreground brown detail in the 7/large bridge-side image was traced using
final rendered roof triangles, not just bounding boxes. The closest hit at
(54.58469, 6.240985, 38.12901) belongs to `pure_village.roof.eave`, placement
`kit.spatial.parcel.maze.house.022/k0024`, roof 22. It is part of the native
base/short-cornice assembly, not an independently misplaced beam or neighbor's
post. Source assembly contact review remains separate from this ownership proof.


## Production record contract and grand-town roof closure

The focused real-terrain record test found two actual integration omissions.
The post-grade dressing pass wrote `ground_dressing` into the sealed local
`fabric_audit`, whose exact-key validator correctly rejected it. Dressing now
publishes `VillageUrbanFabricPlan.ground_dressing_audit` separately; the local
construction audit and its validator remain unchanged. After that repair the
validator exposed missing runtime demand for Pure Village's native roofs:
`VillageProgram` still registered the earlier facade-only kit. It now registers
both native-roof opening variants. The demand regression exercises the actual
production style selector over 100 seeded houses and explicitly requires the
native eave. It passes (16524 assertions, `/tmp/town-assets-contract.log`).
The focused production test now passes all 152 structural/materialization
assertions; its sole remaining failure is solve time, 10.85 s versus a calibrated
9.05 s ceiling, while streamed terrain and native rendering ran concurrently
(`/tmp/town-production-contract2.log`). Measure this again without competing jobs
before accepting performance; the old baseline passed at 2.419 s.

9/grand had a genuine whole-town rejection, not merely an old count pin. A lower
roof had been admitted beside a future terminal roof using the measured reciprocal
closure seam, but the terminal fallback never carried that same seam into final
assembly. `_terminal_macro_cap_fallback` now uses the existing
`_append_measured_required_roof_seams` helper, exactly as full roofs already do.
The measured-contact and semantic/public-air checks remain intact. Broader cap
changes were tried and removed because they did not address this failure.

The new grand-town regression passes 14 assertions: sealed valid fabric, a
positive terminal fallback, closed native gables and roof ends, intact dormer
openings, valid payload, zero finished roof/public-air intrusions, and zero
floating masses. The prior roof-domain regression also passes (8 assertions).
Native overview plus streets 0 and 3 inspected and saved under
`terminal-roof-contact/`: continuous mixed roofs, deep stone windows, stepped
frontage and clear upper circulation. This restores 104 structural building
records in the formerly rejected town; those records are not an independent
house-count target.

`town_world_walk.tscn` now loads the actual production scene, graded terrain,
committed native collision and real CharacterBody controller. It uses the same
published route extraction as the isolated walk harness (now static helpers),
with no teleport between route points. The first run has completed eight of
eight reported-town routes in both directions: entrance spine, open skywalk,
source bridge house and underpass. Its terrain unload/return phase is still
running; no reentry acceptance is claimed yet. This run loaded before the audit
and asset-registration fixes above, which change metadata/demand rather than
route geometry.


The streamed-world player/reentry run completed successfully: 9/9 walks,
including the entrance again after return. The original terrain chunk was
confirmed evicted, its replacement has a different instance ID, readiness
returned, and the real player completed the route on rebuilt collision. Evidence:
`world-player-reentry.json`; total cold-load, traversal and reentry elapsed
833.386 s. The eight initial bidirectional routes are listed above. This proves
the reported town against actual dual-grid terrain rather than test floor boxes.
It does not prove every town or GPU performance. A quiet production solve-time
measurement follows with the other Godot jobs stopped.


## Owner follow-up: articulated buildings and stone terrace streets

The new request adds L/T/complex footprints, a stronger preference for dense
mini massifs over giant individual rectangular houses, complete projecting bays
and towers/spires, and optional inhabited stone retaining terraces inspired by
the Pure Village store image. The execution-plan addendum records these as
requirements of this same redesign, not a separate finished task.

First candidate: compound merging now prefers existing nonrectangular contacts,
uses a higher L/T contact probability, and allows a flat rectangular union over
12 module cells only on a 20% seeded draw. It tests the complete growing group,
so repeated two-lot joins cannot evade the rule. Existing source occupancy,
addresses and support remain unchanged; stepped crowns and vertical lineages
retain their architectural joins. This is only a kit-level first step and does
not by itself create new passages or a new source mini massif.

A controlled five-town comparison used the same current source houses and the
previous merge function extracted from HEAD. Large plain footprint counts:
7/large 3→2; 9/grand 0→0; 13/large 3→2; 34/large 6→4; 60/standard 6→4.
Nonrectangular counts rise 2→3 in 34/large and 3→4 in 60/standard. The largest
remaining plain footprints (60, 36 and 24 cells) are not solved by merge policy;
trace source parcels and reserved landmark conversion next. Metrics are in
`shape-merge-candidate.json`. In particular `_landmark_house` reconstructs the
reserved footprint as a rectangle; source-authored landmark articulation is not
preserved by that conversion.

The former test requiring three lots ALWAYS become one 24-cell rectangular
range is superseded by the owner's new direction. Its replacement tests 64
seeds, verifies repeated results, preserves all 48 occupied cells and three
doors, requires complete roofs, and keeps large simple ranges possible but a
minority. Added a real L-footprint/cross-wing test. 7/8 roofline tests pass,
3515/3516 assertions; the remaining twin-gable corpus rises to 5/25 (0.20), above
the unchanged 0.18 ceiling. Therefore this candidate is not accepted yet.
Native comparison renders are in `/tmp/town-shaped-native/` and still require
judgment alongside that repetition regression.

Native articulation study: `pure_village_articulation.gd` renders the authored
House_11c, House_16c and House_7b from both sides and exports every mesh transform
and measured bound. Front views of House_11c and House_16c inspected; images and
measurements retained in `articulation-reference/`. House_16c combines half-tower
wall courses with full round upper courses, a complete cone roof and separate
supported timber projecting bays. Its large stone tower uses 3 m high modules
at y=4.5, 7.5 and 10.5, then a roof seated at y=13. House_11c also shows a smaller
roof tower and a square spire/clock-tower composition. Native authored tilts and
source-specific origins must not be copied blindly into the common grid. No new
tower assets have been baked or enabled in production yet.

The quiet real-terrain solve still takes 10.782 s versus the calibrated 8.876 s
ceiling, with all 152 other assertions passing. This is a real performance item,
not solely concurrent-load noise. Profile the production adapter and native kit
before accepting its budget. The optional streamed-world render profiler is
implemented in `town_world_review --profile-frames` but has not yet been run.

### October 2 owner follow-up: street boundary and remaining courtyard work

Ground paint now comes from `TownStreetPaint`, the ground public-cell union with only its convex exterior corners rounded. Shared edges, full-width approaches and square interiors remain continuous. The native review skin uses the same corner classification; the production terrain field uses exact circle/rectangle primitives. This is boundary treatment, not yet the requested reduction of broad paving or additional elevated courts.

Red-first: three boundary/rotation cases failed on the former square stamps. Final path/dressing run: 14 tests / 17,939 assertions pass (`/tmp/town-path-checks.log`). The first native render exposed reversed front-face winding; rejected and corrected. Matched 13/large overview plus street views reviewed under `rounded-streets/`. No change to the public collision union or terrain kernel. Full streamed-world terrain-paint review still required.

Production profiling isolated the current timing regression: source planning ~1.7 s, native kit ~7.8 s, of which final roof preparation ~5.5 s and union payload ~1.2 s. A triangle-bound clipping optimization produced byte-identical results for 227 real roof pieces but only ~2% improvement in that probe, so it was removed. The 8.876 s production-site budget remains open.

An elevated-site preference experiment across 12 large/grand towns changed no selected courtyard sites: the missing upper courts need space reserved before the streets consume it, not a ranking tweak afterward. No preference-only change was shipped. A native ownership tint disproved the initial foreground-roof landmark hypothesis; the actual pair is house.032 / house.033, two adjoining 4x2 footprints at the outer street of 13/large. A focused regression is being added before correcting their merge admission.

Foreground pair correction: the broad-range cutoff now starts beyond 16 modules, allowing two ordinary 4x2 footprints to form one 4x4 house. Larger 24-module plain ranges remain a seeded minority; L/T joins retain priority. Exact 13/large test fails before the change and passes afterward: one owner and one roof cover both original footprints. Roofline suite and focused case: 9 tests / 3,470 assertions pass; this also removes the merge candidate's prior twin-roof corpus failure without loosening its threshold. Matched overview under `joined-ranges/` confirms a single blue roof. Larger building articulation remains open.

### Elevated courtyards: reservation lifecycle repaired, art still open

The early reservation already finds upper courts (13/grand, 58/large, 58/grand at band 8). The actual defect was the subsequent lower-street opening-to-sky pass consuming the court's bearing band. The old frontage reservation protected only its empty upper slot. `WarrenExcavation.construction_reservations` generalizes the former landmark body/footing ledger to include a selected courtyard's bearing and headroom. All existing excavation copies preserve it; slot admission and opening-to-sky share the same ledger. `preselected_plaza` records the actual early selection, and final plaza siting keeps that site only while all current support/landing checks accept it. No new cut budgets, ranked elevation preference or seed exception was needed.

Red-first: five assertions fail across the three upper-court sites before this change. Reservation plus landmark tests: 6 tests / 66 assertions pass. Full three-town construction, actual public-floor coverage, payload validation, zero floating mass and zero roof/public-air intrusion: 2 tests / 93 assertions pass. Native builds of all three towns succeed. `kit_town_review --views courtyard` now captures standing-height views of the actual planned floors.

`nested_gate_walk --courts` walks the real character from the town entrance through the court's address and across its cells in both directions. 13/grand: **8/8 walks pass**, including the band-8 main court and three band-4 courts (`elevated-courtyards/player-walks.json`). This isolated collision harness is not a substitute for the pending full-world repeat.

Art review: the courts are reachable, supported grass terraces, but still look bare with checker turf, perimeter timber and few props. Planting, furniture, surrounding wall treatment, full-world grass and further visual iteration remain open. The platform regression suite has one stale ordinary-town signature pin. A controlled old-carver/current-carver comparison produces the same `ab72d375c491e3dbc661d0e9494ebc04ee29a8bed81070bdd582199113acbc40` signature and an empty source diff (`/tmp/town-plain-court-diff.log`), so the courtyard reservation change is not its cause. The earlier source change still needs attribution before re-pinning.

### Upper courtyard planting: explicit garden floors and native contact correction

The source plaza now reserves its interior as planting before public-surface composition. A one-cell walk ring and primary door approaches remain public. Optional secondary back-room doors choose another legal approach or remain private when their approach would cross planting. Explicit `GARDEN_FLOOR` faces preserve the planted island's bearing without allowing ordinary daylight to retain floating crowns. Surface contracts, floating-mass auditing and internal guard omission consume this distinction.

The first native result exposed internal rails; those were removed only at supported, level planting boundaries. A second exposed a leafless centre tree; new islands now choose measured leafy variants and fit their complete canopy/root bounds into the reserved footprint. Native previews use the meadow vegetation tint; production materialization samples the world-position biome. Payload checks verify the selected asset, scale, tint and stable identity.

A further native review identified a timber strip crossing the tree roots: the native retaining frames extended 0.070–0.074 m above the planned court. A red test captured both contacts. Retaining wall/post placements now fit their measured tops to their structural ceiling, preserving feet and horizontal dimensions; house frames and fortified parapets retain their original treatment. Matched native 13/grand images show the strip removed. Native 58/large also rebuilds successfully (`/tmp/town-court-frame-native`).

Earlier topology/support/public-surface run: 40 tests / 1,198 assertions pass. Actual-player fine-grid routes circle the island rather than crossing it: 13/grand 8/8 and 58/large 4/4 pass. Leafy-tree main court routes: 2/2 pass. Evidence is in `courtyard-planting/`. Final frame-fit regression results are recorded separately below when complete.

This is not final courtyard art acceptance: the isolated turf still has checker variation, furniture is sparse, and full streamed-world grass/biome verification remains pending. The long platform wall, largest building silhouettes and performance budget also remain open.

Final retaining-frame checks: courtyard planting plus floating-mass corpus **8/8 tests, 173 assertions pass** (`/tmp/town-court-frame-green.log`); elevated courts, production surfaces and town materials **30/30 tests, 4,444 assertions pass** (`/tmp/town-court-final-contracts.log`). `git diff --check` passes. These are focused regression results, not a claim that the full repository suite or art scope is complete.

### Large landmark footprints: seeded L/T plans

The remaining broad landmark blocks had a separate cause from compound merging: `_landmark_house` always filled the full rectangular reservation of the old complete prefab. Eligible envelopes now choose connected L/T footprints, keeping a 15% plain-range alternative. Small footprints stay complete. Corner cuts preserve at least two-module wings, the authored door and both possible halves of its interior approach. The original envelope remains conservative roof-clearance space; removed corners are not advertised as new public courtyards. The choice uses the source seed, textual feature identity and reservation bounds, without production seed/site exceptions.

Red-first shape/variety tests failed twice on the rectangular implementation. Final shape tests: **3/3 tests, 1,120 assertions pass**, including real 13/large, 58/large and 7/standard builds, their doors, zero floating masses and zero finished-roof public-air intrusions. Existing landmark reservation, joined foreground range, roofline variety and floating-mass suites: **19/19 tests, 3,575 assertions pass** (`/tmp/town-landmark-shape-contracts.log`).

Native overview renders of all three towns succeed. New `kit_town_review --views landmarks` provides four close views per landmark; initial framing was too tight and was corrected before visual judgment. Inspected inner corners and roof junctions in 58/large and 7/standard: native mixed-kit roofs close the wings, and the inner facades remain complete. Selected images are under `landmark-shapes/`; full views are in `/tmp/town-landmark-close2/`. The separate joined foreground pair remains one house/roof.

This completes the broad-landmark footprint correction, not the whole architectural scope. Projecting bays/towers, stronger vertical composition, inhabited platform-wall integration, further courtyard dressing and final world/performance acceptance remain open.

### Inhabited lower walls; repeated accent grid rejected

The owner rejected the repeated stone-arch approximation and then the rectangular course/pilaster grid. The approximate arches, repeated pilasters and intermediate horizontal bands are removed. A single cornice follows the exposed rim. The former color-only grid studies are not art acceptance.

`WarrenWallRooms` now selects real, addressed lower house plots within eligible artificial platform columns. Their floors stand on natural ground; their complete structural caps reach the raised district datum. A dedicated source proof admits these rooms without weakening ordinary house support rules. Existing upper plots, streets above the proposed cap, measured prefab reservations, passage air and natural ground take precedence. Plot metadata survives sealing/signatures and appears in building outcomes. Selection uses the ordinary world seed and coordinates, with no photographed-seed exceptions. The final 13/large source has 11 such plots.

Two native failures were found and corrected. First, the kit generated intersecting pitched roofs because residual cleanup released the wall-room ceiling. The ceiling is now reserved before composition like a stacked parent's bearing plate; embedded rooms have no separate pitched roof. Second, the old flat-roof compiler omitted its lower slab band from retained-terrain skin. That left a visible horizontal gap despite a structurally valid grid. The native platform wall now renders every band of the explicit cap. The new regression failed on 48 missing native cap cells before that repair. Initial missing-room tests, the foundation-datum rejection, cap retention failure, courtyard support regression and rejected native images are recorded in `/tmp/town-inhabited-*` logs. Courtyard support was repaired by declining sites with higher retained overburden rather than silently dropping that support.

Focused construction, relief, fortified tiers, elevated courts and build-order checks: **14/14 tests, 731 assertions pass** (`/tmp/town-inhabited-verified.log`). Final prefab/street guards: **3/3 tests, 297 assertions pass** (`/tmp/town-inhabited-clearance.log`), including 13/large, 58/large, 2/grand and 7/standard construction, complete caps, no floating mass and zero finished-roof/public-air intrusions. The actual character reaches three embedded-room street addresses and returns: **6/6 walks pass**; the first route repeated after the native cap repair passes **2/2**. These walks test the public approaches, not traversable building interiors.

Native final comparison: `/tmp/town-wall-final-main/` and `/tmp/town-wall-final-pure/`. Selected evidence is copied to `inhabited-walls/`. The Pure Village alternative replaces only the platform skin in the review harness; no new production material default has been selected. The timber-cornice study is also preview-only. `pure_village_wall_details.gd` measures/renders native Pure Village arches, windows, corbels and a balcony. Its shaped stone arch is a different asset from the rejected approximation, but it has not yet been baked or placed in production.

Fortification remains optional: an unchanged production-size sample of seeds 1–100 produces platforms in **32/100**, with one nested case (`/tmp/town-wall-frequency.log`). This is a sampled frequency, not a guaranteed quota. No platform chance was changed in this pass.

Art scope remains open: there are now genuine windows, mixed plaster/timber fronts and recesses at the wall foot, but broad upper stone courses still need stronger composition. Higher-tier embedded rooms, actual wall-through routes, native arch integration, projecting bays/towers and the final material choice remain pending. Some 58/large automatic close cameras are occluded and cannot count as art acceptance. Full-world and generation-budget acceptance remain open.

The broader legacy `test_streets_keep_their_floor` reports eight assertion failures (25/33 assertions pass). A controlled run with only the new wall-room planner call disabled reports the same eight failure messages, including stale expected floor-gap counts and the previously refused 3/standard slope now sealing. The planner call was restored after comparison. These pre-existing test expectations are not re-pinned here (`/tmp/town-wall-street-support{,-control}.log`).


## October 2: actual lower routes through fortified districts

The previous goal turn made concrete progress (inhabited lower walls and corrected native ceilings). This continuation removes the blanket prohibition on district boring for one explicit planner stage. `WarrenPlatformStreets.carve_tunnel` validates a complete straight route between two pre-existing lower public streets before mutating the excavation. It preserves natural ground, at least one complete ceiling band below the district bearing, lateral bearing columns, existing headroom separators and construction reservations. Ordinary street generation retains the old prohibition. An exit loop edge seals the route back into the public graph. The generic daylight pass retains the authored ceiling and lateral supports; final plot/kit construction consumes the same source geometry.

Red first: `test_october2_wall_tunnels` found zero wall through-routes in 13/large (`/tmp/wall-tunnel-red.log`). The route now crosses seven platform columns and returns to the lower street on the other side. Source/public-air/ceiling checks pass. Full construction on 13/large, 58/large, 2/grand and 7/standard has valid payloads, zero floating masses and zero finished roof/public-air intrusions. Combined tunnel and inhabited-room suite: **5/5 tests, 333 assertions** (`/tmp/wall-tunnel-built.log`). Added explicit permission/natural-ground/ceiling/reservation checks plus fortified-ring and build-order regressions: **9/9 tests, 161 assertions** (`/tmp/wall-tunnel-regression.log`). `git diff --check` is clean.

Actual character-controller collision walks complete both directions in 13/large and in seed 6 at its production-selected size: **4/4 walks pass**. Reusable `nested_gate_walk.gd --wall-tunnels [--production-size]` follows every tunnel from its existing street anchor through the exit. Native `kit_town_review --views wall-tunnel` captures both mouths and an interior view; 13/large and production-size 6 were rendered and inspected. Ceiling and exits are continuous. Evidence lives in `wall-tunnels/` with both walk reports.

`wall_tunnel_survey.gd` checks production-selected sizes for seeds 1–30: all 30 source plans build, 9 contain platforms, and one (seed 6) contains a through-route. This is a sample, not a frequency guarantee. No platform spawn chance changed, and no generation branch depends on a review seed or coordinate.

**Not final art acceptance:** the tunnels currently read as long plain stone corridors with timber soffits. Seven columns means 56 metres under the district, so shorter/bent entrances and connections toward upper public destinations deserve the next routing iteration. Native arch integration, relief/outcroppings, upper inhabited rooms, contrasting wall materials and broader original redesign acceptance remain open. Do not treat the passing traversal checks as visual completion.

## October 2: native molded gateway header

The previous continuation made concrete progress by adding and physically walking real wall through-routes. This pass implements a different native stone arch at actual fortified gateways. `pure_village_arches.json` bakes Pure Village `StoneArch_3` with its measured bottom-centre pivot, native materials and triangle collision. `BuildingKit` now carries its measured header size and crown overlap; the Suntail/Pure Village mixed vocabulary provides `gate.arch`. The assembler fits the complete molded header between existing piers, keeps its entire bounding box above player headroom, and respects the existing overhead-room limit. Kits without the role retain the plain-header fallback. The rejected repeated blind arches remain absent.

The red test found no native header (`/tmp/native-arch-red.log`). Native-header, wall-relief and fortified-ring tests then passed **9/9, 341 assertions**. After the native crown-join adjustment, header and relief tests passed **5/5, 251 assertions**; the final measured kit/catalog agreement check passes **2/2, 6 assertions** (`/tmp/native-arch-metric.log`). No claim of a full repository suite pass. The reference town's finished-roof audit remains at 144 clipped / 23 removed; this asset change did not alter roof selection.

Native images were inspected for 13/large and 2/grand. The first crown join read as an exposed slit above the uneven native stone; the parapet now overlaps that crown by 0.12 native metres. This is a visual join adjustment, not a proven geometric hole repair: a trial front-projection test passed both before and after and was discarded because it did not distinguish the defect. The matched corrected renders are in `native-gate-arch/`, alongside the first join for comparison. Header bounding-box and low-overhead-room tests remain the relevant automated clearance evidence.

Actual character-controller walks: **2/2** for the 13/large approach from town entrance and back, **4/4** for both gates of nested 2/grand. Both reports are copied into the evidence folder. The mixed native arch now supplies curved relief and warmer stone at the gateway, but the larger facade, projecting bays, towers, tunnel-mouth articulation and shorter routing remain unfinished. No town wall material option has been chosen globally. This is component progress, not final town-art acceptance.


## October 2: supported curved bays and small spires

The preceding goal turn added a different native gateway arch. This continuation adds real modular articulation to generated houses: Pure Village's `StoneTowerHalf_Window_15x30`, `StoneTowerHalf_Support_15x30`, and `Roof_Tower_2` form a complete curved window bay, stone corbel and blue spire. The source assembly scales those pieces uniformly to 0.75 and the bake clips their hidden back to the host facade. The ordinary house supplies its wall panels; an initial duplicate plaster backing was removed after it showed a mismatched rectangular patch. `pure_village_oriels.json` records the source recipe and produces native mesh/material/collision assets. The measured assembly envelope lives in the kit; no runtime source-scene loading is introduced.

The designer chooses at most one such projection per house, by seeded eligibility, on the highest storey's exposed gable. It centres the projection on the whole gable, including even module counts, verifies backing on both sides, preserves nearby doors, and checks its complete native bounds against neighbouring construction and reserved public air. `bay_roles` and `bay_offsets` carry the exact selection into both assembly and facade/roof contact fitting. Glazing bounds were measured and added to the worker-side opening table. The old bay family remains available elsewhere.

Red first: standalone seed samples initially produced no supported spire bays (`/tmp/oriel-red.log`). The first enabled version used the ordinary window-slot rhythm; native 13/large exposed spires passing through sloped roof edges as disconnected blue fragments. That layout was rejected, then replaced by the gable-centred rule. The native duplicate plaster patch was separately removed. Both rejected views are retained in `oriel-spires/` to explain the iterations.

Final verification: **16/16 tests, 4653 assertions pass** across the new oriel suite, facade/roof contacts and build-order determinism (`/tmp/oriel-final-test.log`). This includes completed construction on 13/large, 7/standard and 58/large, actual baked-envelope agreement, high-level and same-storey clearance refusal, gable centring, valid payloads, and complete oriel bounds outside every finished public-air volume. Native final renders show **3, 4 and 1** oriels respectively; selected views from both facade families and the holdout are copied to `oriel-spires/`. The two reference-town skywalks pass with the actual character in both directions: **4/4 walks**, report `oriel-spires/skywalks.json`. Existing reference/holdout roof clipping counts stay unchanged in these renders. `git diff --check` is clean.

The first source-study harness used the full support; it now names the half support used by the final recipe. The final geometry does not include the prototype backing panel. Earlier 13-test runs and the first native pictures are intermediate evidence, not the final result.

This supplies optional projecting windows and small spires within both kits. It does not complete full-height tower grammar, higher-tier wall dwellings, richer wall faces, shorter/bent tunnel entrances, courtyard art refinement, or final world/performance/regression acceptance. The overall redesign goal remains active.


## October 2: shorter corner tunnels and clear native mouths

District through-routes now consider one right-angle turn as well as straight crossings, with the same bounded eight-edge search. Shortest legal routes take priority, then seeded/textually ordered ties. Each candidate proves its complete bore and two unbored cardinal neighbours at every segment before excavation. The selected lane records its actual support columns; daylight retention consumes those columns rather than assuming one straight direction. This preserves both the ceiling and the open second leg at a corner. Ordinary streets still cannot bore platforms, and platform occurrence is unchanged.

The new three-column corner fixture failed on the straight-only implementation. It now verifies the turn, retained ceiling, both outside supports, refusal when one support is missing, and absence of partial excavation after refusal. Reference 13/large changes from seven bored columns (56 world metres) to three (24 metres). Production-size seeds 1–30 still all build, with nine platforms; through-routes rise from one town to three (5, 6, 13), each three columns long. This is sample evidence, not a promised spawn frequency.

Actual-player holdout testing found an additional real defect: an upper decorative corner turret descended across the 58/large tunnel mouth. The source route and roof audit passed, but the physical character stopped against `suntail.stone.stone_wall_plain` in both directions. A focused native-placement fixture reproduced four public-air intersections. Corner turrets now check their complete conservative panel/crown envelope against public-air bounds and omit the whole tower if it obstructs a lower route. They do not leave floating partial towers. The fixed holdout walk passes both directions, and matched native before/after renders show the reopened mouth.

Verification: initial routing/inhabited-wall/fortified-ring/build-order run **13/13 tests, 395 assertions**. After the turret repair, final wall-relief/tunnel/native-gateway suites **10/10 tests, 309 assertions** pass. Actual character walks: reference 13/large, production-size 5 and holdout 58/large, **6/6 directions pass**; the first two preceded the turret-only omission and the holdout was repeated after it. Logs `/tmp/corner-{regression,final,walk,production-walk,holdout-fixed}.log`. Native final views in `/tmp/corner-fixed-native/` inspected, selected evidence under `corner-tunnels/`. `git diff --check` clean.

The turn improves route variety and removes a proven obstruction. The corridor remains visually plain, and higher wall faces still need more inhabited frontage/relief. No global wall material was selected. Courtyard art, full towers, final streamed-world and performance acceptance remain open; the overall redesign is not complete.


## October 2: homes embedded in upper retaining tiers

The previous continuation improved corner tunnels and caught a turret obstruction. This pass extends inhabited walls to elevated streets: `wall_room_support_ok` permits a floor above natural ground when the floor has real solid support, a level adjacent public address and a complete structural cap reaching the next platform datum. The old ground-only equality was the specific exclusion. The compiler's wall-room bearing datum now matches that proved floor. Existing natural-ground, carved-air, overburden, prefab and courtyard guards remain. No seed/site exceptions or platform spawn changes are introduced.

Red first: the three-town upper-room test found zero elevated wall rooms. With the supported-floor rule, native 58/large contains five upper wall-room plots at band 4, and 2/grand contains two. They use the existing mixed-kit house compiler, including real windows, doors, timber framing and plaster; they are not windows pasted onto an uninhabited stone sheet. Native screenshots are available through `kit_town_review --views upper-wall-rooms`; `nested_gate_walk --upper-wall-rooms` targets their public addresses.

Close renders rejected the first result: lower-rim battlements covered windows and doors in the new fronts. The assembler checked only a room directly above the rim cell, not one adjoining its face. A focused fixture reproduced the overlap. A room closing either side of a rim now suppresses that edge's parapet and corner turret. Matched corrected images show clear fronts in both Suntail and Pure Village styles. The plain backing walls, higher caps and public guards elsewhere remain. The rejected image is retained as evidence.

Verification: inhabited-wall, elevated-court, fortified-tier and build-order suites **12/12 tests, 535 assertions** pass, including complete grid and rendered caps for elevated rooms, zero floating mass and zero roof/public-air intrusions on the sampled builds. The final battlement correction plus native arch regressions pass **7/7 tests, 254 assertions**. Logs `/tmp/upper-room-regression.log` and `/tmp/upper-rim-test.log`. Actual-character public approaches to three 58/large rooms pass **6/6 directions**; both 2/grand upper rooms pass **4/4 directions** after the battlement correction. These prove street approaches, not traversable room interiors. Final native views `/tmp/upper-room-fixed/` inspected; selected evidence and walk reports copied to `upper-wall-rooms/`. `git diff --check` clean.

The upper inhabited-wall rule is now implemented and visually checked. Overall redesign acceptance remains open: some longer stone faces are still plain, close views show porch posts needing a separate clearance review, full tower silhouettes and courtyard furnishing need refinement, and the final streamed-world/performance/broad-regression gates remain outstanding. No global wall palette has been selected.


## October 2: verify the last steps to upper-room doors

The upper-wall turn made concrete implementation progress but left a suspected porch-post obstruction from an off-centre close view. This continuation checks the actual realized doorway thresholds rather than stopping at the source macro street address. `nested_gate_walk --door-thresholds` appends the building threshold's fine-grid public centre and a point 0.65 world metres outside the closed door plane. `--door-only` isolates the short final approach for rapid collision checks; ordinary whole-route mode remains available. The public walking points use the source building lineage with `.partNN` removed. Initial harness parse/type and lineage-matching failures were corrected before these runs; they are not traversal evidence.

The real character reaches and leaves all five 58/large upper-room doors (**10/10 directions**) and both 2/grand doors (**4/4 directions**). Native `upper-wall-rooms` camera framing now faces the actual threshold, showing the suspected post at the side of the doorway. This narrows the previous porch concern: these seven door approaches are clear; the earlier off-axis image did not prove an obstruction. No production canopy geometry was removed or changed merely to address that misleading projection. The existing long street-approach walks from the previous pass remain complementary evidence.

Reports: `doorway-clearance/porch-threshold.json` and `porch-holdout.json`; logs `/tmp/porch-{threshold,holdout}.log`; native views `/tmp/porch-native/`. This is physical doorway-clearance evidence, not proof that the closed-door interiors are traversable or that every generated porch is globally clear. The wider redesign still needs remaining wall/courtyard art and the final integration/performance review. `git diff --check` clean.


## October 2: courtyard seating, native garden junction still open

The previous continuation resolved the suspected porch obstruction with actual threshold walks. This pass adds small Interior Pack benches to the reserved island beside a courtyard tree. `maze_plaza_seats` tests up to four tangential placements, with a deterministic starting side and at most two accepted seats. The complete catalogue bounds must stay on the island, avoid the complete tree envelope and other construction, and clear public surfaces. The rigid seat is scaled to the kit human-prop world size. The asset is included in the compiled footprint contract and emitted with stable `maze-plaza-seat/` identity. Ordinary unreserved greens are unchanged.

Red first: the reference elevated square had zero seats. The first native image placed one seat too close to a guard post; a stricter 0.25 authored-metre walk/guard setback test failed four assertions. The inset changed from 1.27 to 1.05 authored metres from the island centre, declining candidates that then overlap the tree. A corresponding public-surface margin gate is enforced in production. The reference now retains one seat rather than forcing two.

Initial seating/planting/elevated-court checks: **6/6 tests, 845 assertions**. Final seating margin plus planting checks: **4/4 tests, 430 assertions**; an additional construction-obstacle/unsupported-ground refusal test passes **1/1, 3 assertions**. Reference actual-character courtyard routes pass **8/8 directions**, on the initial seating positions; final positions move inward and retain stricter automated public clearance, but the physical run was not repeated after that inset. Logs `/tmp/court-seat-{final,verified,support,walk}.log`. Native reference 13/grand and holdout 58/large rendered in `/tmp/court-seat-fixed/`; evidence copied into `courtyard-seating/`. `git diff --check` clean.

**Not art acceptance:** the final native views still show timber rails/deck edging across the visual planting centre, and the surviving bench reads too close to that native edge despite the source surface-clearance proof. The final payload's deck/rail placement must be reconciled with the reserved island before this component is accepted. This is now the next concrete courtyard defect, not a reason to weaken the clearance test. Turf checker appearance and richer planting remain open, as do the broader redesign's wall, tower, world and performance gates.


## October 2: preserve garden reservations through late bridge selection

The native deck/rail mismatch was an extra skywalk, not the public ring's guard generation. The late bridge selector treated the reserved planting cells as empty air and connected opposite sides of the square. Its rail bounds intersected the full tree envelope. A new reference regression failed on two occupied island cells before the fix.

`SettlementFabricAssembler` now adds the exact garden air reservation (the same `HEADROOM_BANDS` as the spatial solver, above each planting support) to the local occluder set used by open bridges and passage houses. This preserves other structurally valid skywalk sites. Source-cell and final native bridge-envelope assertions cover the defect. Focused planting, seating and existing bridge-envelope suites pass **7/7 tests, 556 assertions** (`/tmp/court-bridge-green.log`). Native reference 13/grand and holdout 58/large show the tree and bench free of the crossing bridge and rails; selected images are in `courtyard-reservation/`. The reference courtyard loop passes with the actual character in **both directions**, now after the final seat inset (`court-walk.json`).

This resolves the specific deck/rail defect from the previous entry. The bare/checkered turf in the standalone review still needs production-material/grass comparison; richer planting, broader wall/tower art and final integration/performance acceptance remain open. No global palette was selected. `git diff --check` clean.

The separate 13/large skywalk check also passes **4/4 actual-character directions** across its two surviving bridges (`courtyard-reservation/skywalk-walk.json`), confirming this targeted reservation repair retains traversable skywalks on that reference.


## October 2: planted courtyard centres

The preceding pass removed late bridges from garden reservations. Inspection of the production grass setup confirms that the streamer supplies cliff and rock-skirt support surfaces, but does not currently supply elevated town lawn meshes. The standalone reviewer also omits world biome tint materialization. These are separate remaining integration concerns; this pass does not claim to resolve them.

Reserved tree islands now receive deterministic low KayKit grass and LPFV flowers. The sampler varies native asset, yaw, size and radial offset, excludes the tree's central root area, and checks the complete measured bounds against island support, public walks (0.12 m margin), benches/other plants (0.1 m margin), and construction. Accepted poses retain stable slot identities. The catalogue compiler includes the five source assets. The source grid and walk allocation remain unchanged.

Red first: the reference payload contained no underplanting. Final planting/seating/bridge-reservation tests pass **6/6, 2769 assertions**; a further supported/blocked/unsupported/determinism test passes **1/1, 4 assertions**. Logs `/tmp/court-plants-{red,green,refusal}.log`. Native 13/grand and 58/large images were inspected and copied into `courtyard-underplanting/`: flowers and grass fit around the tree while the bench and ring stay clear. No character walk was repeated for these noncolliding plants; complete bounds against the public surface are the validation here. `git diff --check` clean.

The centres now have some layered planting, but the large bare/checkered turf surface still needs geometry/normal and production-tint investigation. Full streamed elevated-grass support, wall/tower refinement and final world/performance gates remain outstanding. This is concrete component progress, not final art acceptance.


## October 2: correct the standalone lawn material review

The preceding planting pass was implementation progress. This continuation isolated the bright square bands at the lawn edge before altering production geometry. A payload probe found the central and surrounding courtyard lawn coplanar at 12.005 with upward normals. The full payload had no unexpected asset overlapping that surface. A matched `--no-shadows` render retained the bright edge bands, ruling out the directional shadow as their cause.

The reviewer created its own `EnvironmentRenderCache` but omitted `CliffDressing.prepare(cache)`. The production streamer already calls it: it replaces native lawn lip materials/meshes with the same prepared palette binding used by procedural turf. Adding that preparation to `kit_town_review` removes the bright seams in matched 13/grand and 58/large renders. The diagnostic `--no-shadows` flag remains available. No production mesh, terrain kernel, normals, collision or global palette was changed to compensate for a preview defect.

Before/after, shadow diagnostic and holdout images are in `courtyard-material-parity/`; logs `/tmp/court-{normals,surfaces,normals-wide,shadow,material}.log`. Both native render jobs completed successfully. This is render verification of a low-impact harness correction; no new gameplay test was needed. `git diff --check` clean. The previous bare/checkered-lawn concern is narrowed: the bright seams were a reviewer artifact, while elevated streamed grass support is still absent and remains real work. World-space biome tint/grass acceptance, remaining wall/tower art, performance and broader final gates remain open.


## October 2 owner correction: native rampart masonry

The owner rejected the rampart's flat, angular mismatched finish and missing sides, and reiterated rough path corners plus too few central tree clearings. Those are reopened acceptance items. The old rampart reused Suntail stone material; it was not a newly painted texture. Its thin wall panels were stretched into tall bodies, parapets, merlons and trim. That assembly did not preserve the authored masonry proportions or provide appropriate exposed side geometry.

A native Pure Village study inspected `Stone_Block_1..7`, fences and `WallStone_Start_20x30_1` from both sides (`/tmp/rampart-parts`). The selected existing wall has a finished back and returns; `Stone_Block_4` has solid top/end faces. `pure_village_masonry.json` bakes blocks 4 and 5 with their original materials and measured pivots (block 4 currently used). The fort wall role uses the already-baked Pure stone panel in courses no taller than its native 3 m. Parapets, merlons, turret caps, footings and cornice use closed native block 4. The first iteration still squashed old panels at the foot/cornice; native inspection caught that and those strips were replaced too.

Red-first native-rampart test failed before the replacement. Final wall-relief/native-gate/rampart checks pass **8/8, 530 assertions** (`/tmp/rampart-verified.log`). An intermediate 12-test run passed 11; its failure came from an old oracle applying the Suntail panel AABB to every new block. The oracle now reads each actual placed asset's measured bounds. The tunnel source suite passed in that run. Actual 58/large tunnel traversal passes **both directions** after the final geometry (`native-ramparts/tunnel-walk.json`). Final native 13/large and 58/large views inspected; selected images and native asset views saved in `native-ramparts/`. These verify this replacement, not acceptance of every wall face or the still-open paths/clearings.

## October 2 elevated grass integration, still under review

Before the owner's wall correction, elevated garden supports were connected to grass sampling. `TownGardenGrass` derives exact planting-cell unions by floor, records boundary edges and vertically relevant construction/seat/tree envelopes, then transforms triangles and obstacle polygons into world space. `FeatureContext` exposes these independently from render ownership: `WorldFeaturePlan` includes supports in every overlapping query block; context extensions preserve them. Detached sampling copies the support data. Only a sample from a declared garden skips lower-world projected feature clearance; ordinary grass keeps all existing checks.

A rotated two-cell support test first failed because its marker was not carried by `GrassSupportSurfaces`; propagation fixed it. A real 13/grand payload survives world transformation and worker detachment and grows grass at 24.01 m despite a projected lower clearance covering the test domain; all roots sampled inside garden support, outside obstacles. A non-owner context/extension test passes. Grass field + sampling regression: **29/30 tests, 758/759 assertions**. The remaining September10 test indexes `copy.region.terrain_grades[0]` after native control conversion leaves that list empty; this path runs without features and does not exercise the new support branch. No expectation was repinned. Native elevated grass and full-world chunk/eviction acceptance remain pending, so this is not a complete integration claim.

A general editor import launched for the new class is still live in session **5449**, `/tmp/garden-grass-import-out.log`, last observed at 35%; all other processes from this pass are terminal. Do not start another import. `git diff --check` clean. The next owner-facing priorities are path corner geometry and larger green/tree openings in town interiors, alongside finishing grass validation.


## October 2: inside path corners and larger clearing search

TownStreetPaint previously rounded only convex corners; three occupied quadrants left a square concave notch. It now adds a tangent eight-segment fillet at each such junction. FeatureGroundShape's simple-polygon primitive provides matching signed distance, bounds and symmetric circle/capsule/rectangle/polygon overlap, so terrain paint and visible retained-street geometry share exactly the tessellated boundary. Shared street edges keep their width. Fillets on retained streets keep their own floor band. Ground collision remains the existing public union; these small visual edge extensions sit on the underlying ground.

Final focused suite (street paint, feature context, open spaces, town dressing, town ground): **36/36 tests, 23,547 assertions**, `/tmp/town-corners-final.log`. It covers four bend orientations, green-space exclusion, polygon clearance pairs, mesh winding, elevated datum, transformed paint and existing feature primitives. Matched native 13/large and 7/standard top views are in `path-inner-corners/` with preceding views; both reviewed. Native render completed. No actual-character rerun for this paint-only change.

The clearing sampler now searches closer to the crown (0.45–1.10 radius, previously 0.65–1.35) and tries larger circles (0.30–0.50 radius, previously 0.16–0.30). Crown, shoulder, platform and route protections remain. A 40-large-town survey increased explicit reserved cells from 289 to 362; clearings with at least nine cells from 5 to 12; towns with at least four inner-ring reserved cells from 20 to 25. New regression gates protect this improvement.

**Central-green art acceptance remains open.** Native 13/large, 7/standard, 15/large, 32/large and 35/large still show predominantly peripheral ground trees. A second experiment ranked candidate clearings by eight-direction enclosure; it reduced substantial clearings to 7 and qualifying towns to 16, failed the new regression, and did not improve the reviewed renders. That experiment was discarded completely. Do not mistake ring-depth counts for proof of a substantial garden inside the inhabited town. Next work must improve actual interior space/topology and tree fit, with ground-level views, while preserving massifs and public access. The current larger-circle change is progress, not fulfillment of the owner's central-grove request.

The broad editor import remains live in session 5449, `/tmp/garden-grass-import-out.log`, last seen at 88%; poll it rather than restart. All focused test and native review sessions from this pass are terminal. Native elevated grass/world verification and the wider redesign acceptance remain pending.


## October 2: smaller trees and actual clearing cameras

Previous turn: progress (concave path fix and rejected clearing-ranking evidence). Tree placement previously tried only 10–18 m trees on all four attempts. Attempts three and four now try 6–10 m specimens of the existing LPFV assets, keeping the same measured root, canopy-band, construction and public clearance gates. Native 13/large trees increase 14→23; 7/standard 3→5; 15/large 12→21. These are total counts, not interior-grove acceptance. Native overhead/overview images were inspected. The full dressing suite passes **11/11, 17,361 assertions**, `/tmp/young-final.log`, including a measured enclosed-garden fixture that admits a 6 m tree but rejects a 10 m crown. The initial fixture was too narrow even for the smaller tree; its 6.8 m clear width now reflects measured crown reach plus the unchanged margin. Existing real-town determinism/public-clearance checks pass.

`kit_town_review --views greens --dressing` now renders every explicit clearing/cottage garden from overhead and two close sides and prints its actual location and area. This revealed that 13/large has **no open.* clearing**, only two cottage gardens; it is an intentionally dense roll, not evidence that an interior clearing was lost. Additional native 15/large and 32/large clearing views show the real remaining issue: 15's broad green opens to the outskirts, while 32/open.0 is mostly crossed by public paving with only a narrow lawn remnant. The metric of four inner-ring cells before clearing does not establish an enclosed inhabited garden after carving. Evidence in `garden-tree-sizes/`.

Next: protect usable planting area through the bore/public-route stage, and judge the resulting enclosure/availability rather than only pre-bore area. Reserved ground currently forbids building regrowth but remains fully borable at ground level; the perimeter circulation can consume it. Maintain route connectivity and the existing massif crown; don't simply weaken collision checks or force trees onto paving. More ambitious central/elevated clearing layout and native streamed grass remain open. Broad import still live in session 5449 (94% last observed). Other processes from this pass have finished; no complete redesign acceptance claim.


## October 2: preserve plantable cores through boring

Previous goal turn was progress: mixed tree sizes and close clearing views exposed paving consuming reservations. Broad explicit `open.*` clearings now choose a deterministic contiguous 2×2 or 3×3 macro-column planting island nearest the sampled centre, occupying at most 60% of the reservation. Fewer than eight cells, cottage gardens, and pockets without a fitting square retain their prior circulation. The massif marks these columns before carving; the common passage-slot rule excludes them. The rest of the clearing remains available for access. This protects plantable area at the planning stage instead of painting grass over a finished public route. Crown/shoulder height preservation and all tree clearance gates remain unchanged.

Final open-space/dressing/ground tests: **21/21, 24,895 assertions**, `/tmp/plant-core-final.log`. Eight named large towns prove no finished source passage enters a core. A compiled 32/large fabric proves every core centre remains natural in final paint and has >0.5 authored m of physical clearance. A separate 60 production-size seed survey builds **60/60** source towns with 36 protected core columns, no failed plans (`/tmp/plant-core-survey.log`). This is a construction/connectivity sample, not an assertion that every town has greenery.

Native 32/large and 15/large top/clearing views inspected in `/tmp/plant-core-native/`, selected evidence in `protected-green-cores/`. The former paved loop through 32/open.0 is gone and its green admits trees; 32's total ground trees rise 6→11, 15's 21→23 compared with the prior small-tree pass. In 32, street topology changes substantially (74→44 kit buildings and additional bored passage cells), so the actual character was walked from entry to the elevated plaza and back: **2/2 directions pass**, `entry-court-walk.json`. Remaining core statistics are not broad art acceptance: these reviewed clearings still frequently open toward the town edge, and the standalone lawn does not show world grass. More enclosed/central green composition, native streamed grass, full world traversal/eviction and the wider wall/roof/performance gates remain open.

All processes in this pass have completed except the pre-existing general import (session 5449, last overall progress seen at 97%, currently saving scene imports). Keep polling it rather than starting another import. `git diff --check` clean.


## October 2: native elevated grass and cross-block support lifecycle

Previous turn was progress: protected green cores with route and paint checks. Native review now supports `--garden-grass`; `garden_grass_review.gd` transforms the actual town's garden metadata, detaches sampling, uses the production grass program/settings and GrassStreamer materials/meshes, and renders only declared elevated gardens on the otherwise bare study plane. It is explicitly not a replacement for a streamed-world review. The first fixture's dry-water coverage did not cover complete grass tiles; that harness error was fixed before the accepted renders. No production grass coverage override is used.

Native renders revealed that entire tree AABBs unnecessarily cleared grass under the canopy. Garden obstacle compilation now uses the measured TownTreeProfiles vertical bands for trees and full bounds for other furniture. The existing per-floor grass-height filter selects roots/low branches. Root rejection and under-canopy support are tested. Final native 13/grand (91 grass instances) and 58/large (306) render without script errors; selected images in `elevated-grass-native/`. Grass appears on the supported floor, with the physical tree and bench exclusions. Coverage varies with the production habitat field; neither image establishes full-world biome/material parity.

Five focused garden tests pass (94 assertions, `/tmp/garden-stream-final.log`); after adding an explicit owner-renderer assertion, the boundary/cache test alone passes seven assertions (`/tmp/garden-owner-final.log`). That test exercises real WorldFeaturePlan.context_for projection and LRU eviction with a controlled crossing record: owner keeps one mesh, neighbour gets support but no duplicate render mesh, and support data returns unchanged after eviction/reentry. The earlier hand-injected context test remains too weak by itself and is supplemented by this evidence. Test fixture parse/mesh-validation errors were fixed, not ignored.

The long general import completed with exit 0; its final editor-settings save warning concerns the user's external Godot settings path, not an asset import failure. Session 5449 is TERMINAL; do not poll/restart it. A fresh full-world walk with production grass and chunk eviction/reentry is now LIVE in exec session **65984**, `/tmp/town-integrated-current.log`, engine log `/tmp/town-integrated-current-engine.log`, output `/tmp/town-integrated-current/`. Poll that exact handle; no result claimed yet. All other processes from this pass are terminal. Full world acceptance, central garden enclosure and the wider redesign gates remain open.


## October 2: fresh streamed traversal and reentry complete

Previous turn was progress: native elevated grass and cross-block support lifecycle. The fresh production world (seed 2697992464, site (0,1)) finished with grass enabled, nine ground chunks, production player and committed collision. Entrance spine, skywalk, source bridge and underpass pass in both directions; after actual chunk eviction, the rebuilt chunk has a new node and the entrance spine passes again: **9/9 walks**, all reentry checks true, 818.677 seconds total. Evidence: `streamed-world-current/walk.json`. This verifies traversal and rebuild, not a fresh world visual judgment of garden appearance or quantitative grass-instance parity across eviction. The separate focused garden suite now passes **5/5, 95 assertions** on the final source, including real WorldFeaturePlan owner/non-owner cache eviction coverage.

An isolated performance experiment replaced per-vertex world roof bounds with cached native bounds transformed to world space. It was rejected: four of 642 roof placements differed in a 13/grand comparison, and measured candidate time was slower (2.606 vs 2.430 seconds, concurrent world run, not a quiet benchmark). No production roof implementation changed. Evidence: `streamed-world-current/rejected-roof-bounds.log`. Do not adopt it or present it as a safe broad-phase-only optimization.

Sessions 65984 (world), 76355 (garden tests), and 22107 (rejected experiment) are terminal. No processes from this pass remain active. Central/enclosed ground greens, fresh streamed visual grass acceptance, wider architectural/roof gates and generation performance remain open. No complete redesign acceptance claim.


## October 2: central-green topology experiment, not accepted

Previous turn was progress: the full streamed traversal/reentry run completed. Tested an occasional Gaussian-mixture arrangement around a central green rather than fitting every green outside the central crown. Initial variant moved the crown and added satellite masses where fewer than four existed. Several of 18 large/compact source plans failed their spine. A diagnostic change ranking portal distance to the crown instead of the coordinate origin made all 18 build, exposing an origin assumption in portal choice. Neither change was retained.

The revised candidate preserves the crown's original position and the sampled number/size of lobes, applies only when at least four lobes already exist and an independent 30% roll succeeds, and moves the existing satellites around an offset green. The field extent follows the moved lobes. All 18 source samples build with the ORIGINAL carver (an initial local variable shadowing parse error was repaired before this accepted diagnostic run). Native 17/large and 24/large were rendered. This still fails the requested result: 24 has 51 trees but only 25 buildings grouped around the original crown, leaving an outskirts grove, not an inhabited central green.

The final-source lobe audit confirms why. In 24/large the crown-associated 105 columns have 32 passage cells and 51 plot cells; the other four lobes (66/39/34/74 columns) have ZERO passages and ZERO plot cells. In 17/large, two satellite lobes have 21/22 passage cells but no plot cells. This is stronger evidence than pre-bore enclosure or total tree counts: surrounding masses alone do not produce surrounding buildings. Street distribution and satellite house reservation/partition must co-plan the inhabited frontage before this topology can be accepted.

The complete candidate patch, source-build logs, native images and lobe audit are in `central-green-topology-study/`. Both production files were restored byte-for-byte to their pre-experiment contents; no experimental layout or portal ranking ships. Sessions 21922, 77196, 47185, 6611, 7198, 1960, 49681, 84201 and 29980 are terminal. No active processes. Next: reserve connected street access and viable houses for each surrounding lobe before optional streets consume the budget; prove actual built enclosure and inspect a wooded holdout. Do not retry the same green-candidate ranking or claim more tree counts satisfy enclosure. The full redesign remains open.


## October 2: central greens with inhabited district access

Previous goal turn was progress: rejected layout experiment proved missing street/plot coverage, not tree density, prevented inhabited central greens. The revised arrangement is now retained **with district access co-planning**. An independent 30% roll applies only when the existing mixture already has four or more lobes; it preserves the original crown location, number/size/height of sampled lobes, and positions existing satellites around an offset clearing. No added masses or hard-coded town seeds. The field extent accommodates the moved lobes. Ordinary arrangements retain the old field/random stream.

WarrenMassifBuilder carries district membership/centres on columns of these towns. Before optional streets and asset reservations, WarrenMazeCarver connects an addressable ground site near each district centre to the existing public graph using the existing legal level-lane search (headroom, construction, planting core, platform and street-shape rules). Published level transitions and carved cells belong to `district_access` lanes; the shared occupied map includes them. Later perimeter growth and plot planning can populate the surrounding districts. No portal-origin ranking change is retained.

Final 24/large audit: each of its four formerly empty satellite districts now has streets and plots (25/6, 21/4, 18/4, 13/50 passage/plot cells). Its native houses rise from 25 to 60; ground trees drop 51 to 29 as the intended building sites become inhabited. This is the desired direction: the green sits among buildings instead of merely adding trees where buildings disappeared. In 17/large the two districts with streets but no plots now have four plot cells each. Native top/overview views of both towns and two pedestrian-height 24/large views inspected. The inward green view reads as a grove among houses with the larger massif behind; outward views remain more open. These study renders have bare flat ground, not production streamed grass.

Verification: new access + existing open-space suites **8/8, 9,124 assertions**; dressing + ground suites **15/15, 17,392 assertions**. They cover finished district streets/plots, construction validity, deterministic optional selection, reserved cores, unchanged high-crown/ring requirements, physical clearance and existing dressing/paint checks. All 18 diagnostic large/compact source builds pass. A separate production-size sample builds **60/60**; 11 select central greens and every lobe in all 11 has streets AND plot cells. These are source coverage metrics, not all-town visual acceptance. `nested_gate_walk --districts` follows published graph paths from the entrance to each new lane endpoint: actual character on final native collision passes **10/10 directions** for 24/large. Evidence in `central-green-district-access/`.

All processes for this pass are terminal (38530,39769,71845,3826,96668,15098,49491,47842,66479); `git diff --check` clean. Remaining: streamed-world visual/grass/terrain review of this topology and wider holdout art/performance checks. The prior fresh world walk predates this layout change and cannot certify its new production instances. Full redesign acceptance remains open.


## October 2: production central-green ground integration

Previous goal turn was progress: retained district access and native/player verification. A real SettlementPlan scan for world seed 2697992464 identifies an urban central-green town at site (-1,1), cell (-9,48), town seed 85830433957479026; the wooded existing (-1,0) reference does NOT select this topology. Expanding the scan finds a wooded central-green town at site (2,1), cell (75,40), town seed 5918244260080312451, production size 0.00310328554403, woodland 0.99278426874133. No town identity or seed is changed to force the feature.

`town_world_ground_probe --planting-spaces` now covers the same natural interstitial planting spaces as TownGroundDressing, not only explicit excavated reservations; the central opening can exist naturally between sampled lobes. It also reports the canonical town seed, selected topology and transformed green centre. The urban site's complete production record, graded terrain, feature contexts and grass compiler finished: 14 grass tiles, 1,600 total grass instances, **938 within planting spaces, 0 on painted paths**. Its tree count is zero as selected by the urban roll. Evidence: `central-green-world/urban-ground.json`. These counts cover all planting spaces, not only the central circle; they do not replace visual inspection.

`town_world_review --at x,y,z` can now review a measured world point (ground datum read from the production field), three nearby camera angles and an overhead view. This avoids adding more hard-coded site cameras. Script parse check passes; this new option has not yet completed a native render.

The wooded ground probe is STILL LIVE in session **44062**, `/tmp/central-wooded-ground.log`, engine log `/tmp/central-wooded-ground-engine.log`, expected result `/tmp/central-wooded-ground.json`. Last exact handle poll confirms running; log is at GROUND_FRAME (2,1), before world-record completion. Poll this handle; do not restart on observation timeout. Its GROUND_TOWN line will expose the transformed green coordinate needed for the native --at review. All other processes this pass completed: 63898/4350 site scans, 61665 urban ground, 85013 parse check. `git diff --check` clean. Full streamed visual acceptance and the wider redesign remain open.


## October 2: wooded central green in the streamed world; roof performance gate

Previous turn was progress: production urban grass check, wooded site discovery and an active cold-build probe. The wooded site (2,1) finished successfully: seven town trees (all in natural interstitial spaces), 516 grass instances within planting areas and zero on painted paths, 12 sampled grass tiles. The measured green location is (1752.11,32.08,971.804). Full native world review at that point completed with nine ground chunks ready, production terrain and grass, three close angles and an overhead view. `central-green-world/at_8.png` clearly shows planted grass, biome-coloured trees, houses on the surrounding paths and rounded paving boundaries. The nearby canopy occludes much of the left side of the close views; the overhead view establishes the town/terrain context but is too distant to judge facade details. This is positive world integration evidence for this small town, not universal architecture acceptance. No production scenery was changed to stage the views.

Roof processing was optimized without changing geometry rules: bulk-transform vertices for the same tight bounds; transform shared indexed corners once instead of once per triangle; remove a wholly contained convex polygon before repeated plane splitting, retaining the original outside/EPS/coplanar checks first. The candidate reused immutable corner dictionaries; split creates new interpolation records. This is distinct from the REJECTED conservative-bounds candidate. Exact comparison of complete realization results finds **0 mismatches across 3,251 placements**: 13/grand 642, 7/standard 644, 24/large 1,082, 58/large 883. Comparative clipping time falls approximately 21–31% in these runs, which were concurrent with world loading and therefore are not whole-generation benchmarks.

Final roof-junction/facade tests pass **20/20, 12,253 assertions**, including a new complete-burial/coplanar/EPS-boundary regression. After every competing job completed, the real-terrain production test passes **153/153 assertions**, generation **6,735 ms vs 8,000 ms allowed**, reference calibration median 125 ms / 137 ms (applied factor 1.0). This closes the previously failing production-site solve-time gate on this machine without repinning its limit. It does not establish all-town frame time, memory, or generation ceilings. Evidence and the precise optimization patch: `roof-clipping-performance/`.

All sessions this pass are terminal: prior wooded probe 44062, native world 75210, comparisons 77363/39212/49167/43252, tests 84870, quiet production 8773. `git diff --check` clean. Full goal remains active; remaining wider facade/tower grammar, holdout architecture, streaming/render/memory acceptance and full regression classification must still be audited.


## October 2: streamed render measurement and complete tower asset study

The native world render profiler completed at the reported town's `green` camera
and its two neighbouring angles, with production grass/terrain, nine loaded
chunks, an idle worker and drained feature queue. At 1920×1080, 120 measured
frames after 60 warm-up frames per angle, median intervals are 17.240–17.847 ms
and p95 intervals 17.701–18.433 ms. Draw calls are 1,534–1,543; total rendered
primitives 6.83–7.20 million. Godot static memory is approximately 2.55 GB
(decimal); this is neither peak process RSS nor GPU memory. GPU timing is
unavailable on this backend. The harness requests uncapped/VSync-disabled
rendering. These are measured frame intervals for one site at chunk radius 1,
not a full production-radius or all-town frame-rate guarantee. All three
captures and JSON reports are in `streamed-render-performance/`. Native run
62202 completed successfully, with no script/render errors. The inspected
`green_8` image shows rounded paving and grass/tree contact at the original
town edge; central-green composition is demonstrated separately by the actual
wooded site in `central-green-world/`, not by this edge camera.

`pure_village_tower_study.gd` now assembles complete round and attached tower
course studies from the existing Pure Village assets. The full-round base
starts at local y=0; the half-round base starts at -0.125 and needs a +0.125
placement correction. Window courses sit at y=3 and 6, with the cone roof at
8.5; the studied complete roof reaches y=14.2056. The roof is 4.1783×4.1821 m,
wider than both the 3.2441 m window shaft and a two-module 4 m reservation.
The attached version's rear lower half is deliberately open and requires a
real host wall/bearing up to its full-round transition. Do not scatter it as
a freestanding decoration or reserve only the shaft's footprint.

Front, rear and course-close renders of both assemblies were reviewed; the
initial round-base lift was corrected and rerendered, with base/contact
assertions passing. Evidence: `full-tower-native-study/`. Native study runs
86242 and 70985 are terminal. This is measured asset-composition evidence,
not production tower placement: source occupancy, host-wall transitions,
roof fitting and neighbour/public clearance still need integration before
these larger towers can ship. Existing small supported bay/spires remain.

The final-roof/public-air regression now includes 17/large and 24/large central
green layouts and 58/large fortified tiers, alongside the existing compact,
large and frozen photographed obstruction. All six final triangle audits find
zero walking-air intrusions; the test passes all 19 assertions in 74.538 s.
The raw geometry still contains intrusions, so the retained photographed case
continues to exercise actual cuts. Log: `streamed-render-performance/roof-air-tests.log`.
Test session 21237 is terminal; no jobs from this pass remain active. Plan
introduction corrected to remove superseded generation-time and upper-wall-room
status. Broader tower integration and full final acceptance remain open.

## October 2: modular tower runtime assets and shared Pure Village maps

Previous turn was progress. Seven native modules are now baked through
`pure_village_towers.json`, with original materials, full triangle collision
and provenance. `KitTowerAssembly.gd` composes two-to-four-course round,
grounded-half and corbelled-half towers. Half towers publish their required
host height; corbels extend below the first floor; the top course closes all
sides and the cone overlaps it by 0.5 m. Bounds include the complete roof.
No production placements are enabled yet: actual host/bearing reservation,
roof junctions and common clearance must consume this grammar first.

The catalog/commit pipeline rendered two- and three-course versions of all
three forms. Attachments have complete native host walls and deck bearing
(the initial thin-wall-only host did not illustrate the rear upper course's
support and was replaced). Front/rear views reviewed. These plain host blocks
demonstrate assembly, not final generated-building architecture. Evidence:
`tower-modular-runtime/`.

The texture suite exposed duplication across the newer arch/masonry/oriel
packs: 73 loaded maps and 392,519,376 bytes of compressed image data. Baker
version 40 adds an explicit texture-policy namespace. The supplementary
manifests now share content-addressed `pure_village_kit` maps; unrelated
defaults are unchanged. Four manifests rebaked with `--keep-existing`.
All 55 superseded maps matched the canonical resources' actual image data
exactly (resource file IDs differ, so whole-file SHA equality is insufficient).
After reference checks, 55 redundant generated maps, 196,866,966 disk bytes,
were removed. One retained orphan oriel material was redirected too.

There are 47 distinct maps: the original 44 and three native tower-window
maps already introduced by the small oriel. The original 230 MiB budget
remains for the 44; the three additional 2048px maps have a separate
3×5,592,432-byte block-compressed/mipmap allowance (even the smallest mips
occupy full 4×4 blocks). Combined payload is 247,116,144 bytes, down
145,403,232 without removing maps, resolution or mipmaps. The old 44-map
inventory was stale; its explicit incremental material cost is now recorded.

Final assembly/texture tests: **4/4, 618 assertions**. Rampart, oriel and
gate-arch tests passed in the preceding same-bake run; its only failure was
the stale texture inventory/budget subsequently corrected. Native review
completed without script errors. `git diff --check` clean. All processes
terminal: 73793,72632,57139,58576,92541,78375,43000,90111,43228,72997,96045.
Next: reserve complete tower envelopes before host roof fitting, enforce
grounding or corbel support and public/neighbor clearance, then review
positive/absent procedural cases across both kits. Full redesign stays active.

## October 2: tower attachment admission and generated-host junction study

Previous turn was progress. `KitTowerAssembly.fit` now proves an attachment's
complete backing volume and measured outside clearance. Corbelled forms need
host cells below the first tower floor; grounded forms require a bearing
callback for every base column. Doors/open seams, inset backing floors,
missing support and a tower buried in a same-house wing reject the candidate.
The full roof bounds participate through their highest band, not just the
window shaft. Admission is explicitly not final roof-junction acceptance.
Tests pass **7/7, 257 assertions**, including all four facade orientations,
high/low obstructions, roof-only overhang conflicts and incomplete bearing.

`pure_village_tower_study --designed` searches ordinary generated houses for
supported candidates. Seeds 6, 7 and 34 are the first three admissible simple
hosts in each kit, not production exceptions. Six host cases render from both
sides with the baked catalog and native collisions. Small dressing is omitted
only in this study to expose the joins. Two-course attachments fit below the
main ridge, but could partly cover a Suntail gable window. The study now replaces
the entire affected gable opening with the plain panel. Three-course variants
rise above the roof and expose a second real defect: the host's verge crosses
the conical tower roof. Complete-framing renders confirm the intersection;
the first taller camera had cropped the finial and was corrected.

Evidence: `tower-host-admission/` (short/tall comparisons, native log, tests).
These candidates are NOT enabled in town generation and do NOT establish
accepted tower art. Next is native roof-junction handling for the conical cap
and host verge, followed by seeded placement and final public/neighbor checks
in real towns. Do not evade the taller-case defect by enabling only the short
variant. All sessions terminal: 75798,83385,46725,81817,77873. No active jobs.
`git diff --check` clean; full goal remains active.

## October 2: exact native-cap cut reference (not production accepted)

Baked worker-readable tower roof triangles with `bake_roof_geometry --tower`
into `pure_village_tower_roof.bin` (776 KiB). Measurements show the native cap
both curves and leans: a straight cone or convex hull would cut outside its
skin. `KitTowerAssembly.roof_cutters` constructs vertical triangle prisms whose
union follows the actual upper skin envelope, preserving the original cap.
Independent vertical ray tests sample 45 positions, with translated/rotated
cutters: points 5 mm beneath the skin are inside, points 5 mm above are outside,
and the cut stops at the cap base. Attachment plus roof-junction tests pass
**18/18, 12,400 assertions**. Bounds rejection for large cutter lists retains
exact vertices, normals, UVs and indices compared with unfiltered cuts.

Important harness correction: generated standalone roofs did not carry
`union_index`, so the first two native renders silently remained uncut. Those
images (`/tmp/tower-exact-union`, `/tmp/tower-fitted-union`) are NOT evidence of
this cut. The study now assigns indices and asserts actual clipped surfaces
are emitted. A trial shortened verge was removed; it was not judged through
an active union. Existing per-placement clips are preserved.

The corrected exact-prism version is too expensive: after almost three minutes
at 100% CPU (~180 MiB RSS), the first host had not finished. This is a failed
performance experiment, not accepted roof art. Both slow study runs were
explicitly terminated to avoid spending more resources on the unsuitable
implementation (2402 / PID 53376; 22407 / PID 53540, both exit 143). No final
clipped image was produced. Do not repeatedly rerun this unchanged study.
Next: derive a cheaper native-surface cutter representation, retaining the
ray-envelope oracle and complete support/clearance tests; then inspect native
joins before enabling towers in procedural towns. The exact version remains
an unused reference; no production towers enabled. The latest owner wall,
path and green-space improvements remain as documented above.

Evidence: `tower-native-cut-reference/`. Final tests session 75727 completed;
all current sessions terminal. Full redesign goal remains active.

## October 2: compact measured tower cap and seated gable study

Previous turn was progress: the exact envelope exposed an unacceptable cost.
The new offline `bake_tower_roof_core.gd` intersects the native triangles with
horizontal planes, follows the outer radial boundary, and intersects inward
side planes between adjacent rings. It stores 18 hidden convex sections (28
KiB), at 0.3 m intervals / 32 sides / 15 mm inset. The actual tower mesh,
textures and collisions stay native. The initial nearest-hit version followed
the inner timber lining too deeply; rejected after independent ray checks.
37 outer-envelope sections passed; 18 retain the same tested accuracy.

The new test compares the compact core against independent vertical rays
through the authored roof: 441 grid positions, no core above the native skin
within 5 mm tolerance, and all 263 samples on the main tiled taper reach within
15 cm below its outer skin. The low ornamental lip and metal finial are
excluded only from the inward-distance bound, not the no-overcut check.
Attachment/core plus public-verge tests pass **15/15, 1,257 assertions**.
This is sampled evidence, not a mathematical bound over every triangle.

The six generated-house studies now finish. Measured union calls are below
~1.1 s each in the final run, instead of minutes without finishing the first
house; the concurrent headless test means these are diagnostic timings, not a
production budget certification. Exact per-triangle clipping is retained as an
explicit `--exact-roof-union` reference only. All standard designed previews
use the compact core and assert that clipped surfaces are actually emitted.

A second issue was architectural: the deep host verge stood in front of the
narrowing cap. Its attached gable edge now seats over the measured native
gable-frame depth (`KitTowerAssembly.gable_reach`), including kit anchors,
rather than the nominal plaster plane. This clears the uninterrupted tower
silhouette. Both kits rendered front/rear and close views (18 images).
Suntail 6/7 and Pure 6/34 close/front/rear views inspected. Pure's modular
wood-trim course joints and small outer eave fragments remain visible in close
views; do not claim flawless final architecture from the wide shot. The
standalone harness still clears dressing and directly emits admitted tower
parts: this is NOT production procedural integration or final art acceptance.

Evidence: `tower-compact-cap/`. Next: resolve the remaining native gable/edge
joins, transfer only the attached-wing seating and opening arbitration into
the procedural pipeline, reserve whole tower envelopes against public and
neighbor space, and judge decorated real towns. Current study's one-roof
assumption must not trim every wing of a compound. Full redesign still active.
All processes terminal, including native 83122 and tests 57991.

## October 2: preserve native end caps when fitting a short verge

Previous turn made progress on the compact tower cap. The remaining blue
fragments at the Pure roof edge came from cutting the decorative native end
pieces at the fitted verge plane. Their finished edges were outside that
plane, so clipping removed the closure and retained little sliced tips.

`BuildingKit.roof_cap_x_bounds` records the measured native X extents of the
six Pure eave/slope/top end pieces. `BuildingKitAssembler._roof_cap_at` now
moves the entire end cap inward to the requested verge, taking both ridge
axes, both gable ends and reversed piece orientations into account. Full
regular roof bays remain; no tower/seed special case. Existing ridge-cap
handling already used this rule and is unchanged. Unfitted roof ends and
Suntail (without separate end caps) retain their previous placements.

Tests verify the adapter metadata against real catalog bounds, public
clearance on both ends and axes, and that the actual union leaves each moved
native cap completely intact. Existing native/mixed roof coverage, dormer,
ridge, gable and public-verge checks also pass: **17/17, 445 assertions**.
The new regression would fail the previous assembly both for protrusion and
for having to slice the cap. `git diff --check` clean.

Native tower study rebuilt all six hosts; Pure 34 close / 6 front reviewed
against the earlier cut-edge view. The authored curved eave ends are now
continuous. Pure's timber gable course junction still reads as a small plaster
break at a module seam, rather than a hole through the attic; broader facade
art judgment remains part of the full goal. Generated town 7/standard rendered
with dressing: 42 buildings, five trees, upper garden, mixed roofs, overview
and three streets. Overview and street1 reviewed. Production cap placement is
changed; full towers themselves remain study-only.

Evidence: `intact-roof-caps/` (matched close before/after, house and town views,
tests and town log). All sessions terminal: 77568,99099,36814,33027.
Next: procedural tower attachment integration. It must choose only the matched
gable wing, arbitrate openings and facade dressing, reserve the complete
measured tower against other roofs/public air/neighbor objects, and pass real
town collision and art checks before enabling. Full redesign remains active.

## October 2: reusable tower-host fitting, with decorated native hosts

Previous turn was progress on intact roof closures. `KitTowerHostFit` now
separates preparation from application: it matches the candidate's closed
gable plane/axis/extent and cap-height intersection, records only that wing's
verge change and its affected facade panels, and rejects door/open-seam
conflicts without mutating anything. Parallel displaced and perpendicular
compound wings stay unchanged; existing narrower public verges are preserved.
All four facade rotations are tested.

The helper substitutes complete plain gable panels with their correct kit and
asset anchors. Optional ornaments are removed whole only when their measured
bounds intersect the tower; it never removes structural posts. Spatial and
neighbor reservation are explicitly still the caller's responsibility.
The designed native study now uses these helpers and keeps normal dressing,
instead of blanking all decor and manipulating every roof in the harness.

Visual review caught a semantic case bounds alone cannot handle: a flower box
below the corbel survived even though its window panel had been changed to
plain. Application now removes window boxes belonging to exactly those changed
openings; adjacent windows keep their boxes and unrelated ivy remains. Final
host tests pass **5/5, 61 assertions**. The preceding host+assembly/core run
passed **14/14, 1,162 assertions**; only the subsequent box association fix and
its new regression were added. `git diff --check` clean.

Six decorated native hosts rendered front/back/close. Suntail 6 and Pure 34
fronts reviewed; Suntail 6 re-reviewed after removing the orphan boxes.
Evidence: `tower-host-fit/`. No production tower placement yet. Next is the
actual town candidate/reservation stage, including other houses' roofs,
finished public air and all measured neighbor pieces, then whole-town and
actual-player review. The full redesign remains active. All sessions terminal:
9402,43668,77493,15102,11124.


## October 2 owner continuation: larger greens, roof forms, direct access (ongoing)

Owner rejects long roof strips, tiny clearings, circuitous paths and flat facades; asks for a prefab-informed generator and more turrets/spires. This is not final architectural acceptance.

Implemented seeded transverse end bays for long roof ranges. Existing rooms support both wings, taller cross gables must clear reserved air and taller neighboring walls, and the hall joins the cross gable through the existing native roof union. Independent RNG preserves unrelated facade choices. Initial five-town candidate increased compound roofs 32 -> 38 /115 houses; the later neighbor-contact guard corrects a hole caught by the photo-town test. Final range + prior variety tests: 10/10,5108 assertions; additional neighbor rejection brings range tests to 3/3,1661. Do not treat initial metric as final all-town art acceptance.

Central greens now use radius .6 of town radius (was .4), with district offsets 1.25–1.45 radii (was 1–1.15). Classify GMM masses before relocating them so spreading a cluster does not demote it to one cottage. Ordinary court search prioritizes broader clearings and planting cores may grow beyond 3x3. Forty large-town field samples: seven central-green towns in both; open cells inside their sampled circles 165 -> 383. Ordinary reserved courts 49/368 cells ->48/414; courts >=12 cells 4 ->8. Tests protect crown heights, reservations, connectivity and optionality.

Pre-access-change final mixed roof triangle audit and field tests: 9/9,10054 assertions; all six finished roof corpora have zero public-air intrusions. Actual player walked all five district routes in 24/large both ways (10/10). These results PREDATE the next access change and must not be presented as its verification.

Access follow-up: perimeter lanes no longer grow through reserved gardens (including detours). Required secondary gates reserved before optional building/bridge envelopes; existing finished entrances count toward quota so late planning does not add redundant gates. Prior larger-green source survey had invalid gates in seeds8/9; baseline proved8 newly affected and9 already failing. Early reservation fixes both: 60/60 seeded production-size source plans valid,11 central-green towns, no unbuilt districts (before final detour guard). Focused access/field tests after detour guard:11/11,8013 assertions. Native24/17 render after main-lane guard, before detour guard. Need final native/player/holdout review after this change.

Evidence: roomier-districts/. Original Pure house11c,16c,7b rendered front/back; native module transforms/bounds recorded in prefab-assemblies.json. They demonstrate integrated towers, stacked half/full courses, projected supported bays and asymmetric roof heights. Tower runtime assets/host fitting exist but are still NOT used by production town generation. Next: complete real-town tower reservations/emission, deeper facade/upper-mass grammar, final path/walk/art validation. Full redesign goal remains open.


## October 2 native turrets, deeper facades and direct streets

The newest marked overhead request has an implemented generator pass. `KitTownTowers` now admits and emits supported native Pure Village half/full stone courses and conical spires in mixed towns, with whole-envelope public/neighbor/roof checks and transactional host fitting. Per-placement roof cutters bypass the shared geometry cache. `KitTownFacadeBays` adds collision-checked native supported projections to long upper facades previously rejected by over-tall route reservations; repeated fitting is idempotent. Medium/broad ranges gain complete transverse roof pavilions, and square crowns receive a seeded town-context ridge bias. The two photo regressions exposed by early gate allocation were repaired (Suntail intact straight eaves and ridge diversity); no test threshold was relaxed.

Perimeter lanes avoid gardens, existing entrances count toward quota, and district access no longer inherits dense alleys' forced four-cell turns. The straight-corridor fixture goes from 12 cells with sideways jogs to the legal 10-cell lower bound. Final source sweep: 60/60 valid, no unbuilt district among 11 central-green towns. Roof/variety 12/12 (7,828 assertions); integrated architecture/determinism 22/22 (1,471); final direct access 6/6 (171); post-road finished-roof corpus 1/1 (19), zero walking-air intrusions. Final actual-character district routes 6/6 directions. Quiet real-terrain production 149 assertions, 6,533 ms < 8,000 ms.

Native Pure Village prefab study and measured Suntail assemblies informed the grammar. Suntail source renders have some missing imported texture references, so they are composition evidence only. Native production town renders and close turret/bay views use the baked catalog and were inspected. Evidence and limitations: `native-turrets-and-direct-streets/result.md`. All sessions terminal, no commit/PR. Full redesign stays active for remaining holdout art, large masonry faces, broader streaming/memory acceptance and full regression classification.


October 2 ordinary massif wall rooms: street-addressed rooms may now replace retained support immediately below the lowest existing plot, reaching its floor with a structural cap. Platform behavior remains supported; source/platform tests5/5,92 assertions; final holdout source/build2/2,18; actual41 doorway walks2/2; source60/60 with no uninhabited districts. Native41/67 re-rendered;67 has no qualifying site. Large blank retained faces remain an art failure and need native relief or further valid inhabited treatment. QA `docs/qa/2026-10-01-town-redesign/ordinary-wall-rooms/result.md`. All processes terminal; full goal active.


October 2 retaining relief: inspected original Pure Village supports; baked whole SupportStone_Middle_30x15 with original material and collision. Native corbels admitted only at exposed retained crowns with whole-bound public/neighbor/tower clearance. Rejected corbels-on-plaster; ordinary retained backing now native Suntail masonry. Holdouts41/67 render4/9 corbels. Four tests55 assertions; actual67 courtyard walks4/4. Broad lower faces still need articulation; full art/performance/regression scope remains active. QA `docs/qa/2026-10-01-town-redesign/native-retaining-corbels/result.md`. All processes terminal.


October 2 integrated recheck: quiet production149 assertions,6182ms<8000ms; tunnel/skywalk/court/platform12/14 tests,608/612 assertions. Bridge-house corpus12 (floor12), skywalk endpoint tests pass, actual7/standard routes8/8. Reopened court gate:58/large and58/grand preselect band4 instead of8;13/grand remains8. Four elevation assertions fail; support/air pass. Keep tests red and investigate early-gate/district street versus upper-site availability; do not silently repin. QA `docs/qa/2026-10-01-town-redesign/current-integration-check/result.md`. All jobs terminal, goal active.


October 2 courtyard assertion diagnosis:58large/grand now generate only band4 platforms and no band8 streets, and courts are at their highest tier. Removing early secondary gates did not change that.13grand retains band8. Corrected obsolete absolute-height fixture to highest-generated-tier equality (>=4), retaining explicit13 nested >=8; no production algorithm change. Tests2/2,101; actual13grand highest-plaza traversal2/2; native13/58 reviewed. QA `docs/qa/2026-10-01-town-redesign/courtyard-tier-validation/result.md`. Broad art still open; all jobs terminal.


October 3 range-pavilion fallback: try the opposite end when the seeded preferred
end fails existing roof/headroom/gable checks. Red regression reproduced seven
failures; final three suites pass 14/14, 7,874 assertions. Six finished town
payloads have zero walking-air roof intrusions (gable contacts tracked separately).
Real 58/large house023 gains a cross pavilion. Native 58/41 overviews reviewed;
broad retaining faces and some plain roof ranges remain unaccepted. No new
character walk for this roof-only change. QA `range-pavilion-fallback/result.md`.
All increment jobs terminal; full redesign goal remains active.


October 3 intermediate retaining courses: whole native Pure Village corbels may
articulate intermediate storey tops as well as crowns. Unframed Pure Village
masonry replaces the retained timber grid; the mismatched blue-stone candidate
was rejected. Native41/67 overviews and67close inspected; modules4->7 and9->16.
Final four suites8/8,165 assertions; actual67 courtyard directions4/4 pass.
41's broad path-facing blank support remains an art failure; full goal active.
QA `docs/qa/2026-10-01-town-redesign/retaining-courses/result.md`. All jobs terminal.


October 3 retaining floor-seat correction: diagnostic found native deck undersides
only1.688mm below the prior cap ceiling. Whole caps now seat below shallow deck
contacts, then recheck all obstacles/air; deep floor conflicts stay rejected.
Tests8/8,73 plus focused extra constraints1/1,16; actual41 wall-room walks2/2.
Native41overview gains relief; custom close camera entered a neighbouring
structure and is not exterior acceptance. Supports41:7->17,67:16->17 (counts
include hidden faces). QA retaining-floor-seat/. All jobs terminal; goal active.


October 3 integrated audit active: added public-floor/sight-line retaining review;
three41close views inspected, depth confirmed with adjacent plain face remaining.
Corrected native-asset bounds in gate/parapet tests, facade metric scope and the
obsolete all-seeds-must-be-nested fixture; corrected gate3/3, facade4/4,694 and
rings4/4,89 pass. Initial raw failures preserved. Full October isolated run47
files remains LIVE session74175, `/tmp/october-current-suite.txt` (28 done at
checkpoint). Unresolved landmark/roof-fallback/chimney/released-bridge failures;
classify before changing expectations. QA integrated-october-audit/. Goal active.


October 3 isolated October run COMPLETE:47 files,38 initially clean/9 failing;
three corrected test-oracle files green on separate reruns; six unresolved
(landmark reservation, native roof fallback, released bridge sites, chimney
variety, small town lobes, joined ranges). Raw logs saved in integrated-october-audit/.
Landmark9 held3x4 becomes3x3; temporary trace rejects column(2,-1) atfloor0 as
hanging_street during reservation. Final public cells omit that column: trace
intermediate street/transition and pruning before repair. Production trace fully
restored byte-for-byte. Small-house sites6/9/12 also lack addressed houses.
All sessions terminal; full goal active.


October 3 landmark overhead reservation: seed9/standard's held3x4 asset was
shrunk because optional spine descent put a band5 street over its fixed top4;
partition later pruned the street, too late to recover the site. Fixed assets
now reserve above their legal roof-level headroom through the massif envelope.
Courts retain their previous rules. Exact held-site regression passes unchanged;
landmark6/6,39 assertions; bridge/court5/5,188; finished24-town bridge count12.
The combined attempt skipped the landmark script after an indentation error;
that error was corrected and the separate6/6 run is authoritative. Earlier
unqualified-constant compile error also corrected before final runs.
Source60/60 valid,11 central-green towns with no empty districts. Native9/6
overviews inspected; street images saved but not yet reviewed. No new actual
character walk for this increment. QA landmark-overhead-reservation/. All
increment jobs terminal. Full redesign remains active; small-house access is
under investigation and broader art/regression/performance acceptance remains.


October 3 cottage-access candidate: reserved small-lobe sites lacked streets;
new shortest legal entrance per site restores104/104 cottages across60 valid
sources, preserving11 inhabited central-green districts. Native landmark/deck
reservations now respect earlier cottage footprints and measured eave halos.
Focused16/16,586 assertions; actual12large entrance2/2; native6/12 overviews
and12street inspected. Existing direct-access cadence exemption includes cottages.
Compact landmark fixture now1 instead of2 with documented frontage conflict;
exact held-site preservation strengthened to include that town.
Integration remains RED:24-town finished bridge count11<12 (unchanged floor).
Only12compact source bridge differs: destination pruning withdraws unused street
and its span at(1,-2),floor6. Moving access after bridge reservations still loses
that bridge AND strands7 cottages, so rejected; final code restores early access.
QA cottage-access/result.md. Other unresolved October failures: native fallback,
released-bridge fixture/infill, chimney coverage, joined ranges. Broad faces,
long roofs/tower admission and global performance still open. All jobs terminal;
no commit/PR, full goal active. Next diagnose12compact bridge/destination
co-planning without preserving purposeless road circuits or abandoning cottages.


October 3 bridge destination validation

The cottage-access source comparison isolates one lost bridge at12/compact,
(1,-2),floor6/top8: destination pruning removes its unused underlying street.
Tried allocating bridge endpoint houses before pruning, so real doors could
preserve that address. REJECTED:60-town source test breaks39 (a lower endpoint
has a doorway on a removed stair cell); finished-towns test also returns null.
This repeats the historical flight-door hazard documented by September27.
Production order restored: ordinary destinations prune, released sites infill,
then bridges allocate only over surviving streets. No purposeless road retained.

The corpus floor is explicitly revised12->11, documenting this deliberate
withdrawal rather than asserting a supported span must remain at an obsolete
location. Whole-cover/support and actual built-door requirements stay unchanged.
Final tests: tunnel hosts3/3, released bridge sites2/2, destination agreement3/3;
8/8 total,188 assertions. Actual counted doors are built across the historical
11-town destination corpus. The previously failing released-site regression is
now exercised naturally again at12/compact; no fixture change needed there.
This resolves the bridge classification and released-site failures, not the
whole redesign. Other outstanding October files: native roof fallback coverage,
chimney coverage, joined-range fixtures. Broad walls/rooflines and fuller turret
variety remain art work. All increment jobs terminal.


October 3 native attic turrets

KitTownTowers now tries bounded lateral gable attachments (one module on widths
>=4, half a module on width3) after the centred position. All support, doors,
public air, other buildings and own-wing clearance checks remain authoritative.
Unit fixtures prove this can fit beside protected central doors without changing
the host. Seven real holdouts7/9/17/24/41/58/67 nevertheless gain no offset
attachments; lateral choice alone was insufficient visual progress.

Added a short CORBELLED_HALF form: one whole native round window course, its
native half-corbel and original conical spire. The corbel's full rear support
volume must bear on the flush host wall below the eave. This allows attachment
without flattening or removing lower-storey jetties. Taller forms are attempted
first; only the short form permits one course. Host roof fitting accepts shaft
intersection too, since a short turret's cap can sit above the gable. Existing
exact roof cutters, opening protection and collision emission remain in use.
No new texture, generated substitute masonry or scaled tower parts.

Production12/large gains its first turret (0->1);13/large retains2;6/large still0.
Three overviews rendered,12 overview and both close sides inspected; the first
close framing clipped the finial, so final65deg views show the complete assembly.
Native course/corbel/cap and gable junction read closed from both sides. The
large plain retaining face visible behind it remains an art issue. Lateral-only
candidate does not claim measured town-wide turret growth.

Final tower3 suites19/19,3151 assertions, now including real12 and13 emission,
collision and open-wall checks. Added short-form regression24 assertions verifies
existing inset lower floors stay unchanged and the attachment uses3 complete
native parts at the eave. Finished-roof/public-air and roof-detail suites4/4,113:
all6 finished payloads have0 walking-air intrusions; raw skin cuts and gable
contacts are separate diagnostics. The old chimney-count failure now passes
with the cottage-access layout; no chimney expectation was relaxed.

No new character walk for this roof-only change. Broader density/performance,
native terminal-fallback and joined-range stale fixtures, broad wall relief and
roofline art remain open. Harness supports --views turrets for side inspection.
All jobs terminal; no commit/PR. Full redesign goal remains active.


# October 3 central cross-gables

The remaining single 10x2 roof in 6/large (house.013) and 8x2 roof in
13/large (house.035) were the old 20% plain-range draw (.9479 and .8914),
not clearance rejections. Very elongated ranges (length >= 3*depth) now always
seek a legal transverse pavilion. That same seeded minority tries a central
pavilion first; other rolls prefer an end. Both strategies fall back to the
other positions. Central wings retain at least two modules of hall on each
side. Every candidate still passes roof-height and neighboring-gable checks,
uses existing occupied rooms and joins through KitRoofJunctions. Shorter ranges
can still be plain. No new room footprint or relaxed headroom rule.

Native 6/large and 13/large overviews inspected: their formerly uninterrupted
long roofs now have three-part crossed silhouettes. Both images are retained
here. This improves the targets but does not settle all town silhouette/art work.

The wider photo-town test found 40 missing gable samples in compact town
1998423929946073270, house.010. Re-running with the previous range rule produced
exactly the same failure. It was the existing native turret cap replacing part
of that gable: the audit counted the cut gable but omitted its cap. The audit now
reconstructs the measured cap interior from present native cap parts, not the
clipping request or an AABB. Interior slices share boundaries without artificial
1cm gaps. Existing roof/wall margins remain unchanged. A negative-control test
removes the native caps and correctly restores the hole failure. Both native
side views of the affected junction were inspected: closed junction; the close
framing clips the finial, so these images judge junction closure only.

Validation: range roofs 6/6, roofline variety 8/8, town towers 5/5: 19/19,
9,931 assertions, 88.039s. Six-town finished-roof/public-air audit 1/1,
19 assertions; zero finished walking-air intrusions in all six payloads.
Raw skin cuts and gable contacts remain separate diagnostics. No new character
walk for this roof-only increment. No commit/PR.

Open: broad retaining-wall faces, remaining silhouette variety and integrated
performance/regression classification. Native terminal-fallback and joined-range
fixtures still require classification. The full redesign is not complete.


# October 3 rooms beneath walked terraces

Wall rooms previously required the height budget of an ordinary pitched-roof
house (four bands) and a building above. A genuine flat-ceiling room needs two
bands for its full storey and one for the structural slab. The support validator
now permits that three-band interval and accepts an existing level public floor
as its ceiling. Ground support, immutable passage headroom, asset reservations,
room overlap and maximum height remain enforced. Flights are not ceiling floors.

Terrace rooms are proposed after destination pruning, bridge/tunnel composition
and final ground streets. Earlier placement failed16/60 source validations because
optional upper streets disappeared later. This rejected trial was removed. The
second pass preserves existing wall-room claims and sequential IDs, and adds
only rooms with retained final street ceilings. It creates no extra paths.

Final evidence:
- 60/60 source plans validate;104/104 reserved cottages occupied;11 central-green
  towns have no empty districts. No source expectation reduced.
- Wall-room and retaining-relief suites8/8,125 assertions,37.843s. Regression
  covers source seeds1/4/14/16 which failed with early terrace placement.
-41/large has5 addressed wall rooms. Native collision CharacterBody3D walks to
  all5 entrances in both directions pass10/10. These validate approaches, not
  opening doors or entering furnished interiors.
- Native overview, retaining views and doorway views rendered; overview and
  rooms1/3/4 inspected. New frontage has actual kit doors/windows/timber courses;
  camera close-ups first clipped the doorway and were widened. They prove local
  facade construction, not broad art acceptance. The large front retaining face
  remains substantially blank in the overview and still needs architectural work.

No generated substitute wall assets. No commit/PR. Full redesign remains open.


# October 3 native arched retaining panels

The front wall in41/large stayed blank because its potentially inhabitable
columns(-1,0)/(-1,1) overlap asset.00's ground-level roof clearance. The first
hypothesis (a raised prefab's unbounded lower reservation) was wrong: the actual
reservation is floor0/top4. The interval-clearance trial was removed completely;
no prefab clearance was relaxed and no extra rooms are claimed by this change.

Inspected native WindowSolo1..6 measurements and rendered variants4/6 plus the
narrow stone bracket. Raw source previews had a ground plane through their
centred pivots, so those previews do not establish complete-asset art acceptance.
The complete WindowSolo_3 is now baked as pure_village.stone.retaining_window,
with original materials, unscaled mesh and trimesh collision. No standalone
stone arch or invented texture. This is a closed decorative facade panel on
solid retaining masonry, not a new room, doorway or excavation.

KitRetainingWindows fits staggered native panels on broad retained courses.
It requires a complete emitted plain-stone panel behind the whole ornament,
matching orientation and measured depth, below any retained-ceiling trim.
Only then do complete bounds compete against public air, neighboring pieces,
towers and other ornaments. Panels claim their space before corbels, which now
respect those claims. This replaces some repetitive brackets with arched trim
and dark lattice rather than overlapping two treatments.

Visual iteration caught an important defect: the initial fitter trusted planned
retained cells and floated a panel where assembly omitted the backing. That
candidate is saved as rejected-floating-panel.png. The final emitted-backing
check rejects it. Final41:3panels+5corbels;67:1panel+0corbels. Final41overview and
two public-floor close views inspected: full native frames, solid backing,
visible relief and dark accents.67overview rendered; no unoccluded public-floor
close camera found, so no separate67panel close art claim.

Tests6/6,1437assertions,31.765s: whole unscaled dimensions, unchanged backing,
missing-backing rejection, complete-air rejection, idempotence, real-town
public-air checks, no panel/corbel overlap, payload validity, prior corbel
seating and tall-course checks. The old per-holdout corbel-count assertion now
requires a native panel OR corbel because they intentionally compete; no geometry
or clearance assertion was relaxed. git diff --check passes. No new character
walk for this exterior ornament pass; complete measured public-air bounds are
checked. Bake and render processes completed. No commit/PR.

This is visible progress on the identified face, not full redesign acceptance.
Remaining: integrated regression/performance classification, broader architecture
and density/art review, native terminal-fallback and joined-range fixtures.


## October 3 — short wall-room roof clearance and stable joined-lot coverage

The integrated grand-town survey found a real new failure at 2/grand: a
three-band inhabited support below an upper house left exposed lower roof
faces after the upper facade stepped back. Neither a complete native pitched
roof nor a legal public-floor slab fitted; the entire town was rejected.
`wall_room_support_ok` now requires the usual four bands below houses while
retaining three-band rooms immediately beneath an actual non-flight public
floor. No clearance, bearing, or roof-closure check was relaxed. The surviving
short terrace room remains addressed. The old case failed construction; the
repaired case builds and passes payload, public-air and floating-mass checks.

The photographed seed-13 joined-lot coordinates no longer exist after street
changes. Its regression now preserves the actual pair of adjoining 4x2 lots
as direct construction inputs across 16 seeds, verifies both complete storeys
and addresses survive, and requires one 16-module roof. A separate current
seed-13 complete-town check retains floating-mass and public-headroom coverage.
This is not a claim that the original positions still occur in the live seed.

Validation: four targeted suites, **13/13 tests, 1,588 assertions** (88.442 s).
Native 2/grand overview and its surviving wall-room entrance inspected; the
entrance is seated and surrounded by complete native masonry/timber. The
close view does not show the whole terrace ceiling. Player-controller approach
and return both pass (**2/2**); these are exterior entrance routes, not door
opening or interior traversal. Evidence: `wall-room-roof-clearance/`.

Still open: the terminal-roof regression's former 9/grand fallback no longer
occurs. A 40-grand-town search found no positive terminal instance; retain the
failing coverage assertion until a real positive contact fixture is recovered.
The survey also discovered the above construction failure; it is not evidence
that all 40 towns pass after the repair. Broad regression classification and
final art acceptance remain open. The new overview still contains narrow
roof ranges, so it is not accepted as completion of the reference-building goal.


## October 3 — lower native cross-gables in dense ranges

Two remaining 8x2 ranges in 2/grand could not accept taller cross-pavilions:
their neighbors only partly backed the proposed gables. The generator now
tries a lower complete native profile and admits a rear party contact only
when the entire gable envelope is backed, with at least one free end.
Partial contacts stay rejected. Native roof union closes the two roof axes.
A close render caught the first blue-wing ridge touching a railing; the new
low profile now guards the ridge-height walking rim and finds the opposite
clear end. An overbroad guard disturbing another photo-town roof was rejected.

Final range/variety/finished-air suites: **19/19, 8,022 assertions**. Native
2/grand overview and both junctions inspected. Evidence and rejected trial:
`backed-cross-gables/result.md`. No new character walk for this roof-only edit.
The holdout 17/large shows a huge empty central area and long outer approach,
plus an undecorated masonry face at street0. Its woodland roll is zero (valid
variation), but its spatial composition is not accepted; use it for the next
path/facade pass. Broad acceptance and the terminal-roof positive fixture
remain open. No complete-goal claim.


## October 3 — route through central greens

Fixed the actual cause of 17/large's long outer access: missing route-domain
ground inside the lobe ring. Central-green towns now reserve missing ground
within the sampled lobe-centre hull, keeping it unbuildable and carrying it
through planting/dressing. Natural datums and the existing planting-core rule
are preserved. Nearest-district ordering was an ineffective trial and reverted.

17/large district paving **64 -> 48 cells**, longest branch **31 -> 20**.
60/60 source towns validate, all104 cottages and all districts served; field
comparison proves49 ordinary cases unchanged and11 central cases retain their
sampled solid/lobes/sites/platforms. Focused coverage:10 unique tests /5,945
assertions; complete17/24 roof/bearing/headroom checks pass. Player routes:
10/10 (five approaches bidirectionally). Native17/24 overviews inspected;
24 has44 trees,17's zero-tree urban roll remains intentional. Evidence:
`central-ground-access/result.md`. Plain facades, sparse central-lawn dressing,
terminal-roof fixture and broad final acceptance remain open.


## October 3 — windows above raised backing

Replaced the blanket lower-backed-facade rejection with measured sill clearance
for half-backed, upper-exposed walls. Native Pure Village high-window panels fit
both facade families; existing Suntail timbers close their panel joins. Whole
backing, roof/floor contacts and door rules remain enforced. 2/grand retains13
additional windows, seven on the reported long house. Facade/range suites:
**24/24, 4,803 assertions**; final native overview and close view inspected.
See `high-windows/result.md`. This is a targeted facade improvement; broad
acceptance and previously listed remaining work are still open.


## October 3 — central-green activity areas

Large greens now admit several seeded, separated activity groups within12 m of
an unobstructed ground street; complete native seating/vendor/camp assemblies
replace isolated loose furniture. 17/large:13 groups,15 props,zero trees;
24/large:five groups,five props,44 trees. A canopy/window-box contact revealed
that grid occupancy omitted finished facade geometry. Dressing now indexes
measured low native entries (including noncolliding details), and the preview
uses the same inputs. The canopy relocates clear in the final close render.
Dressing suite15/15, followed by a stronger actual-kit urban test1/1 with8,397
assertions. See `green-activities/result.md`; final images `native-clearance/`.
No new player walk or full-world/performance acceptance in this pass. Broad
remaining work stays open.


## October 3 — recovered terminal-roof coverage and regression run

The positive terminal-roof fixture is restored from the original native recipe
poses and measured contact, independent of random layout drift. It calls the
real fallback transaction: no closure -> rejected with no partial commit;
proved closure -> two supported native strips, exactly one prior-roof seam,
no unrelated overlap. Current9/grand and the other native/mixed towns retain
whole-town validation. Three whole-town tests pass; the focused recovered case
passes7,258 assertions. No production geometry or tolerance changed. Evidence:
`terminal-contact-fixture/result.md`.

A fresh isolated run of all47 October1/2 test files is now in progress via
`/tmp/october-redesign-suite.py`, exec session94641. Log:
`/tmp/october3-regression-runner.log`; authoritative per-file state and logs:
`docs/qa/2026-10-01-town-redesign/october3-regression/`. Poll this exact runner;
do not start a duplicate on timeout. No full-suite result claimed yet.
Broad art/streamed-world/performance acceptance and baseline comparison remain
open. Goal stays active.


## October3 — integrated test reconciliation and quiet solve

The isolated47-file October run completed:44 initially passed, three had stale
expectations. Repaired tests explicitly admit the declared native high-window
fallback with timber framing, reconstruct the original obstructed chimney on
its real roof, and distinguish citadel caps from rooms bearing actual houses
or level terraces. Fresh reruns pass all three. Original failure logs and
exact revised test hashes remain in `october3-regression/`.

Four older town suites were checked next. Excavation passes7/7. Three stale
assumptions were repaired with explicit semantic checks: the photographed
crown is now a real house-bearing ceiling, whole passage covers remain positive
without relying on shifted coordinates, redundant perimeter circuits and
landmark sites need not occur in every town, and narrow halls may have bounded
native cross pavilions. Floating5/5; edges/architecture17/17; strengthened
pavilion1/1. See `october3-regression/repairs.md`. No production tolerance or
geometry changed in this validation pass.

Fresh quiet real-production solve: **6.219 s**, under the unchanged8 s ceiling,
149 assertions. Build-order determinism:2/2. These are a single production
site and the established order corpus, not universal performance evidence.
The real streamed-world route/reentry run is active in session96251; its
entrance spine already passes. Wait for `october3-world-walk/walk.json` before
claiming the remaining routes or eviction/reentry. Full baseline regression
classification, refreshed rendered-world review and broad art acceptance
remain open. Goal stays active.

Streamed-run progress: eight initial walks pass (entrance spine, open skywalk,
source bridge house and underpass, each bidirectional). The chunk has unloaded
and rebuild is active for the final return walk. Reentry is not yet certified.
Continue session96251, not the completed October test runner94641.


## October3 — fresh streamed reentry and native attic relief

The actual-world check completed: **9/9 walks**, including the entrance spine,
open skywalk, enclosed bridge and underpass bidirectionally, then the entrance
again after confirmed chunk eviction/replacement. Elapsed712.261 s; evidence
`october3-world-walk/walk.json`. No live world-walk job remains.

Two new visual holdouts31/large and43/grand expose consistently blank Pure
Village interior gable bays. These now use whole closed native arched or
rectangular window panels, coherent with the house style. The existing
roof/floor fitting closes obstructed windows with complete plain panels.
The worker triangle bake now includes both style selections. Open casements
were tried and rejected because their open apertures reveal the attic and
correctly fail gable closure. Final views are `october3-gable-windows/closed/`;
root and `final/` there are superseded trials. Native overviews and turret
joins inspected; the blank central triangular fields visibly gain relief.

The three roof/facade files cover31 unique tests;30 passed in the combined
run and the corrected obstruction-fixture case passed separately24 assertions
(the original test obstacle ended behind the window's outside test plane).
No production tolerance changed. Finished-triangle/public-air corpus still
running in session98018, `/tmp/october3-attic-air.log`. See
`october3-gable-windows/result.md` for limitations and final follow-up results.
Broader baseline classification and final art/performance acceptance remain
open; the goal is not complete.

Final attic-panel public-air check passes:1/1,19 assertions,102.053 s;
zero finished-mesh intrusions throughout its corpus. Evidence copied to
`october3-gable-windows/finished-public-air.log`. All jobs in this pass finished.


## October3 — full isolated suite and plot-contract reconciliation

Fresh full-suite runner is active in session24812; state/logs/source hashes in
`october3-full-regression/`. No production changes in this pass. Original
failures are preserved. Tests now respect reserved planting cores, separately
prove legitimate three-band wall rooms beneath level public terraces, allow
inhabited supports to reduce floor gaps, and include the newly admitted
step3/standard in all sloped translation checks. Rim rerun1/1,9,171 assertions;
plot rerun40/42, with only plaza frequency and buildable coverage unresolved.
Their numerical floors remain unchanged. Carver spine/frontage metrics and
outer-frontage distribution also need investigation; do not dismiss them as
stale solely because the layout changed. Baseline city-form rerun contains
UID-warning failures that do not prove equivalence to current assertion failures.
See `october3-full-regression/result.md`. Full goal remains active.


## Direct wall-tunnel validation follow-up

A supported straight wall tunnel now uses the district-connection validator,
retaining its existing bore budget and structural proof. Wall-tunnel tests5/5;
48-town skywalk corpus passes with35 spans. Combined6/7: the remaining
photographed-seed span assertion has the identical baseline failure. Evidence
in `october3-wall-tunnel-validation/` (sibling of full-regression). This second
production edit during the full runner changes validation, not generated geometry.


## Native attachment demand

Registered retaining corbels/windows and all native tower parts in VillageProgram.
Tower assembly suite11/11; production record failures7 ->2. The remaining
world1/16 extent failures are a real discovery-bound issue, still open. See
`october3-asset-demand/result.md` under the redesign QA root. Third production
edit during the full run; focused source hashes/logs retained. No geometry changed.


## Wider-town discovery correction

Source-derived global and cached seed-specific bounds replace the old192m
early culls for volumetric towns. The actual far-control query now finds its
owner; canonical world1/16 records validate. Grade topology/new test10/10;
extended cached/uncached/128-envelope tests2/2; canonical records1/1. QA
`october3-discovery-contract/` contains red-first and fixed evidence. Fourth
production edit during the full runner. Full streaming build-count/memory cost
remains open; metadata timing alone does not close performance acceptance.


## Streaming and wider production survey follow-up

The refreshed actual-world test passed all nine player walks, including eviction
and rebuilt-town reentry (world 2697992464, native terrain/grass/collision).
Harness elapsed 788.118 s; process elapsed 816.93 s under concurrent full-suite
load, so this is not a quiet performance comparison. Godot static memory was
6.87 GB at ready and 7.08 GB at completion. Main-thread village statistics show
7 builds at ready and 10 at completion; they do not by themselves account for
all worker planning. The time utility could not read kern.clockrate in the
sandbox and returned exit 1 after the harness successfully wrote its passing
result; peak RSS was not produced. Evidence: `october3-discovery-contract/world/`
and `world-run.log`. The harness now saves memory and feature statistics.

The 16-world-seed ownership survey keeps every native/mesh extent within the
existing one-chunk geometry halo at every 24 m site offset within a chunk.
Only 15/16 records validate. World seed 3 fails because the covered market's
canopy intersects a late bridge-house ground-frame post, not because of bounds
or connectivity. The overlapping AABBs measure 0.28 x 1.826 x 0.252 m.
The structural canopy must not be dropped as decoration, and the bearing post
must not be dropped to hide the failure. `record-three-pair.log` records the
exact units and native asset. This assembly conflict remains open.

A separate roof audit still finds one Pure Village tight eave corner clipped
by public clearance on 85830433957479026/compact (retained overhang area
0.0831 of 0.7218). The close native views in `october3-eave-corner/` are
occluded by neighboring construction and do not establish visual acceptance.
No production code changed during these diagnostic passes. The full isolated
suite continues in session 24812; its original logs are preserved. Overall
visual, assembly, and quiet performance acceptance remain open.


## Native verge repair

The clipped Pure tight eave was a projecting end cap crossing a perpendicular
landing. `KitRoofEaveFits` now also checks already-tight profiles and tries the
existing flush native verge assembly at one end, the other, or both, accepting
only a complete eave that clears the public volume. This repositions whole
end caps with the matching ridge/barge finish; it does not remove a cap, alter
the landing, or relax headroom. Clear roofs retain their existing profiles.

The new geometric regression failed before the edit (10/12 assertions), then
the eave and September27 roof suites passed together:9/9,262 assertions.
The previously failing real compact town now passes the closed-roof/eave audit.
Native isolated corner and underside views were inspected in `fixed-isolated/`: the
retracted corner cap is complete. Isolation intentionally omits adjoining
buildings and public geometry, so this is local cap evidence, not whole-town
visual acceptance. The temporary harness and exact source hashes are retained.

This is the fifth production edit during full regression session24812; earlier
full-suite output remains tied to its original run. The unrelated world3 market
canopy/bridge-support conflict remains unresolved.


### Native canopy intersection confirmed

The record validation failure is not only empty space in an aggregate AABB.
Clipping the authored butcher-stall mesh triangles to the support post box
(inset 1 mm on all faces) finds seven intersecting triangles, total area
0.0483155 square metres. `market-triangles.gd` and its log preserve the measured
asset/pose/box probe. Therefore do not relax the unrelated-envelope validator.
The construction needs coordinated support and market placement.


# Market support integration

World3's bridge-house support intersected the butcher canopy. Each vertical
post column now tries the four corners of its existing bearing cell as one
aligned shaft, keeping its original choice if already clear. Alternative
positions must clear the declared public-floor prisms, native component
bounds and the unchanged measured seam checks. No room, street, canopy or
column is removed. All courses move together; source load paths remain on the
same bearing cells. The complete16-world-seed source/record survey changed
from15/16 valid to16/16 valid (before the rendering fixes below).

Native review then revealed two separate integration defects. Expanded
placements now carry their exact `unit_id`; kit replacement uses that field
instead of splitting at the first slash, which mistakenly discarded a
replaced room's independent ground-frame children. Finally, only the top
course of a retained frame is extended from the legacy floor underside to
the explicitly supported kit room's datum. The measured gap was0.1611m in
lattice coordinates. Whole native post assets, lower endpoints and intermediate
course joins are preserved. Visibility ownership expands with the top course.

Evidence:
- Existing photographed-skywalk-bearing and13 roof-construction tests passed.
- The initial new contact probe incorrectly required every intermediate
  course to touch a non-post asset; corrected to complete-column endpoints.
- Source-floor contact passed, but the stronger production-kit test exposed
  missing columns and then the actual native-floor gap. A subsequent test
  corrected its aggregation to include every native tiled post piece.
- Final new regression passes48 assertions: unchanged record validation,
  retained canopy, all four columns/eight courses in production, source
  clearance, aligned contiguous courses, and actual production native-floor
  triangle contacts. `market-bearing-final.log`.
- Building-kit suite8/8 passed in the combined run; that run's one failure was
  the pre-aggregation new contact test, retained in the log.
- Finished native roof-air six-town survey passes19 assertions (combined
  with the earlier production-presence test2/2,67 assertions). This preceded
  the top-course seating change and does not prove all native post clearances.
- Native isolated `seated/` side view inspected: post now reaches the underside;
  the canopy is intact and separate. `isolated/` omits posts before the ownership
  fix; `retained/` shows the old gap. These are diagnostic isolated scenes,
  not whole-town visual acceptance.

Fresh quiet production timing is running in session38201. Current full native
post-clearance/discovery corpus must be refreshed after the rendering fixes.
Broader regression classification, visual acceptance and runtime/memory review
remain open. No completion claim.

### October 3 upper-town architecture follow-up

See [upper-town spans](october3-upper-town-spans/result.md) for street-facing loggias, complete narrow crowns, shorter cross-gables, turret proposal frequency and removal of the all-height platform skywalk exclusion. Three source towns go from zero spans to 2/3/3; six actual-player directions pass in 31/large. Final focused5/5 and16/16 production records pass. Full architectural quality remains open; intermediate turret counts are not final source-layout counts.

### October 3 embedded architecture correction

See [enclosed-street correction](october3-enclosed-streets/result.md): actual Pure Village prefab junction study, rejection of one-course glued-on turrets, restored district bores, and first native shed-eave frontage treatment. Full stepped-wing towers, protruding embedded facades, enclosed climbs and street canopy remain open. Latest quiet timing failed the unchanged gate.

### October 3 raised courtyard canopy

See [courtyard canopy](october3-court-canopy/result.md): full native crowns can shelter upper-court streets above measured headroom. Final native roof triangles participate in placement; benches and underplanting clear roots and low branches. Focused7/7,6,558 assertions and two-direction player route pass. Broader architectural acceptance remains open.

### October 3 native eave tower connections

See [eave tower connections](october3-eave-towers/result.md): source-aligned cap datum, side-of-roof junctions and grounded native bases. Focused23/23; inspected generated43/grand ground and roof contacts. Broader art acceptance remains open.


## October 3 tunnel-bearing iteration

The recovery and delayed-cover candidates were rejected and reverted after
matched art review; source cover counts did not represent better final enclosure.
Only native window fitting on narrow masonry faces remains (7/7,7,354 assertions).
Evidence and outstanding co-design work: [tunnel-bearing review](october3-tunnel-bearings/result.md).


## October 3 embedded-frontage native-part study

Pure Village bow-window assemblies and return stock were inspected at authored
scale. No projecting facade was enabled: the full bay volumes require earlier
room/route/roof reservation. Retained a narrower fix to admit complete shed-eave
runs independently, preserving clear faces when another face is blocked.
Wall-room regressions6/6 (82 assertions), final hood checks2/2 (17); native
13/large views inspected. Embedded projections, integrated towers and enclosed
climbs remain open. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-frontage-parts/result.md`.


## October 3 stepped roofed wings

Eligible repeated rectangular upper stacks now form seeded lower roofed wings
inside their original footprint, preserving doors, public walks and external
bearing. Removed the old independent spire-bay decorator; full tower fitting
remains. Initial10/10 geometry cases, final4/4 including four-town public-air and
floating-mass checks; corrected full-cap mutation1/1. Quiet production7.103s,
149 assertions. Matched native shape views inspected. This is partial progress:
13/large loses its former full shaft, tower distribution remains insufficient,
and embedded projecting facades/enclosed massif streets are unfinished.
Evidence: `docs/qa/2026-10-01-town-redesign/october3-stepped-wings/result.md`.


## October 3 native roof-emergent turrets

Implemented the complete narrow shaft/window/cap grammar from Pure Village
House_11c as a seeded fallback beside the existing larger attached towers.
The shaft begins within an occupied upper room and passes through the native
roof, using hidden measured inner cuts. Reviewed native isolated buildings and
three towns: 13/large4 new turrets,31/large1,43/grand3 prior+4 new. Focused suites
9/9 (6,364 assertions); quiet production7.227s<8s,149 assertions.

This is retained progress, not overall architectural acceptance. Embedded
projecting facades and coupled inhabited tunnel/roof/route planning remain the
next structural work; exposed climbs and long flat fronts are still visible.
See `docs/qa/2026-10-01-town-redesign/october3-roof-turrets/result.md`.
# October 3 skywalk landing repair

Resolved the43/grand missing landing / closed terrace railing seam. Reachable
construction crowns survive kit replacement as native timber floors with public
headroom. Final8/8 tests,3273 assertions and actual player8/8 directions pass;
native final views inspected. [Evidence](october3-skywalk-landings/result.md).
Broader massif, embedded-frontage and enclosed-climb architecture remains open.

# October 3 inhabited-route follow-up

Retained optional-shaft clearance through private bridge and endpoint rooms.
Interior-priority source selection and three-body kit merging were rejected:
one lost upper coverage, the other lost a native enclosing roof projection.
New2/2,143 assertions and existing roof-turret3/3,3091 pass. Retained13/large
actual player8/8.43/grand bridge/underpass pass; exterior skywalk0 has a landing
and railing failure requiring follow-up. Full architecture remains unfinished.
See [evidence](october3-inhabited-selection/result.md); candidate images are
explicitly labeled rejected, and source/carver/merge experiments are reverted.

## October 3 — shallow native wall-house roofs

Replaced full gable-slope hoods with existing Pure Village shallow bottom courses
and complete native end caps. Corrected the first low seat after it obscured
opening heads; accepted attachment fits in the retained cap. Native controlled
two/four-bay and town views inspected; final room/skywalk 9/9 (164 assertions),
expanded hood 4/4 (59), actual 13/large player 8/8. This does not complete the
requested projecting inhabited frontages or massif enclosure; those remain open.
See `docs/qa/2026-10-01-town-redesign/october3-shallow-fronts/result.md`.

## October 3 — inhabited wall-room projections

Existing upper wall rooms can now project as complete native assemblies: shifted
front panels, two closed returns, walked floor/ceiling strips, beams and brackets.
Long fronts select a seeded two/three-bay section with recessed shoulders. Native
58/large and67/large views inspected;13's blocked bridge-side front stays flush.
Final projection/hood/landing suites10/10,182 assertions; actual local doorway
approaches58 and67 each8/8. Quiet production7.362s<8s,149 assertions. Broader
bored-massif coverage and enclosed climbing streets remain OPEN, as do overall
architectural acceptance and refreshed world/full-suite review. Evidence:
`docs/qa/2026-10-01-town-redesign/october3-room-projections/result.md`.

## October 3 — shared excavation-clearance experiment (deferred)

Two-band excavation increases finished inhabited street coverage across five
measured towns104->148 quarters; matched native13/43 lower streets improve and
13 actual player10/10 directions passes. But58/large exposes an odd five-cell
private crown the even-sized roof grammar cannot cover. Restored excavation and
compiler exactly; candidate patch, frozen crown and native evidence saved. Next:
complete native odd-corner roof grammar, then reapply/revalidate the candidate
and projection coverage. Related suites9/10; carver12/13 with the same five
spine requirements failing at baseline. Production verifier's two failures also
reproduce before the change. No acceptance/full-suite/performance claim.
See `docs/qa/2026-10-01-town-redesign/october3-bore-headroom/result.md`.


## October 3 — inhabited bore construction retained

The two-band excavation experiment now has native construction for its odd
private roof corners, so it no longer fails 58/large. It preserves more rooms
over lower streets (five matched towns:104 ->148 covered quarters). The final
nine-town survey has no floating masses or measured roof/public-air intrusions.
A separate omission in cross-gabled halls was also fixed: their long roof wings
now receive seeded, clearance-fitted dormers. Final targeted tests:19/19,
13,761 assertions. Actual-player checks cover12 directions; native alley and
roof-wing views are inspected. No alternate-town retry was introduced.

Details and limits: `docs/qa/2026-10-01-town-redesign/october3-bore-construction/result.md`.
The broader dense-frontage, climbing-walk enclosure, integrated-tower and canopy
art goals remain active; this is not full redesign acceptance.

Quiet real-terrain production check for this revision:5,103ms<8,000ms;
1/1 test,125 assertions. No fresh full-suite or streamed-world claim.

### October 3 climbing support and subsequent palette correction

See `october3-climbing-support/result.md`: real platform bearing governs bridge
endpoint lower houses. 101/large inhabited streetquarters8->20, threecomparison
towns unchanged;7/7tests107asserts;101entrance-to-gate actualplayer2/2. Native
climbing views inspected. Overall architectural acceptance remains OPEN.

Owner rejects roof-emergent turret default and requests corner/lower-wing
connections plus coordinated primary/accent materials. See
`october3-palette-study/index.html` for five material experiments on original
Pure Village House_16c, and its result.md for scope. These are authored-prefab
studies, not procedural corner integration. The latter and production palette
matching remain OPEN. Active original redesign goal continues.
