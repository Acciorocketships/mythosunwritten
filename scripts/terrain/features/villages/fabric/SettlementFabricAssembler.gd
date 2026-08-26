class_name SettlementFabricAssembler
extends RefCounted

## Main-thread adapter for a sealed fabric plan. The worker-facing output is an
## ordinary resource-free EnvironmentInstancePayload, so the eventual
## procedural solver can reuse the existing commit and streaming path.
const PLANK_FLOOR := &"sfv.fabric.floor.l.001"
const PLANK_GALLERY := &"sfv.fabric.gallery.floor.m.001"
const PLANK_SINGLE := &"sfv.deck.floor.s.001"
const PLANK_RAILING := &"sfv.deck.railing.s.001"
const PLANK_RAILING_MEDIUM := &"sfv.deck.railing.m.001"
const COURTYARD_PLANTER := &"sfv.fabric.planter.003"
const TIMBER_SUPPORT := &"sfv.deck.pillar.001"
const TIMBER_CORNER_POST := &"sfv.fabric.wall.wood.corner.s.001"
const LOW_RETAINING_WALL := &"sfv.fabric.wall.rock.plain.001"
## The authored foundation piece, not a wall panel pressed into service as one.
## Same measured envelope as LOW_RETAINING_WALL (1.77 x 3.00 x 0.66, pivot at
## the bottom centre), so it drops into the same lattice slot, but it reads as
## the base course of a building rather than a length of retaining wall.
const HOUSE_PLINTH := &"sfv.foundation.rock.001"
const PLANK_Y_OFFSET := -0.12
## Every authored module that reads as coursed rock, whether a recipe places it
## as a house's ground storey or this assembler places it as a plinth. The
## budget below is measured across the union, because a viewer sees one
## continuous masonry face and does not care which stage emitted it.
const STONE_FACADE_ASSETS: Array[StringName] = [
	&"sfv.fabric.wall.rock.plain.001",
	&"sfv.fabric.wall.rock.door.005",
	&"sfv.fabric.wall.rock.window.010",
	&"sfv.foundation.rock.001",
]
## REVIEWER BUDGET (round 3, binding): "almost no stone should be visible, it
## should only be used sparingly to make a house one storey taller." One storey
## is two bands, which is exactly one upright 3 m rock module. No continuous
## stone face anywhere in a town may be taller than this.
const STONE_BUDGET_BANDS := 2
const FACE_DIRECTIONS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
	Vector3i.FORWARD, Vector3i.BACK]
## TASK C5b RULING 1. The retained-terrace channel carries two different facts
## by the time a maze town reaches this file: a building's own plinth course
## (`true`, and every legacy plan's only kind) and the MOUNTAIN a maze town is
## cut into, which `WarrenSpatialFabricCompiler._retained_foundation_cells`
## tags with this value. The tag rides in the dictionary the channel already
## carries -- nothing reads a retained cell's value, only its key -- so the
## skin below is keyed on a fact no legacy plan states, and every legacy
## payload is byte-identical.
const MAZE_STONE_TAG := &"maze_stone"
## Six faces, not four: a retained mountain has a sky-facing top (the shoulder
## between the buildings) and a floor-facing bottom (the roof of every bored
## passage). Indices 0-3 deliberately match FACE_DIRECTIONS, so a side face
## key means the same thing in both rules.
const STONE_FACE_DIRECTIONS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
	Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP, Vector3i.DOWN]
## Half the authored foundation module's measured depth (0.664 m, descriptor
## `sfv_foundation_rock_001.tres`). A horizontal cap is that module laid flat,
## sunk by this much so its rock face is FLUSH with the cell boundary it
## closes instead of standing proud of it: a cap can never rise above the
## stone it caps, and a passage roof can never hang below its own ceiling.
const STONE_CAP_HALF_DEPTH := 0.332
## The module the retained MOUNTAIN wears. Same measured envelope as
## HOUSE_PLINTH (1.77 x 3.00 x 0.66) and the same transform idiom, and already
## this file's own module for retained stone (`low_retaining_payload`), but a
## plain rock wall rather than a building's base course. FIRST PASS USED
## HOUSE_PLINTH and the capture refused it: the foundation piece carries an
## authored timber sill along its lower band -- what makes it read as the base
## of a HOUSE -- and a mountain many courses tall then reads as a log-cabin
## stripe of rock and timber, once per course (seed 12,
## `foundation-retained-04-ne`, c5b-view pass 1). A hillside is not a stack of
## building bases.
##
## TASK H2b NARROWS WHAT THIS MODULE CLADS. It was every exposed face of the
## mountain, and the user's verdict on that was "i'm still seeing a lot of
## boxy stone rectangles": a hillside is not a stack of masonry courses
## either. It now clads the RETAINING faces (banks no taller than
## STONE_BUDGET_BANDS), the caps the public realm walks, and the floor-facing
## roofs of bored passages. TERRAIN_GREEN_CAP and NATURAL_ROCK_FACE below
## carry the rest.
const MAZE_STONE_MODULE := LOW_RETAINING_WALL
## TASK H2b. The mountain wears masonry ONLY where a mason would have built
## it. Two authored terrain modules carry the rest, and both come from the
## catalog the terrain's own cliff dressing already draws hillsides with
## (`CliffDressing.ASSETS`), so a maze town's substrate and the world's
## hillsides are made of the same thing.
##
## * `TERRAIN_GREEN_CAP` -- the flat grass quad KayKit's hill tops are surfaced
##   with. It caps every sky-facing rock face the public realm does NOT walk,
##   so a terrace bench reads as a garden shoulder rather than a stone lid.
## * `NATURAL_ROCK_FACE` -- KayKit's cliff wall. It clads every side face
##   standing in a bank taller than STONE_BUDGET_BANDS: a bank that tall is
##   the HILLSIDE the town is cut into, and coursed ashlar there is the
##   "boxy stone rectangles" the user rejected. At or below the budget the
##   masonry stays, because a two-band coursed face holding up a terrace is a
##   retaining wall, which is correct medieval vocabulary and quaint.
const TERRAIN_GREEN_CAP := &"kaykit.terrain.top_center"
const NATURAL_ROCK_FACE := &"kaykit.cliff.wall"
## TASK H2b FIX 1, IMPORTANT 3 -- the bench RIM, and the third module from the
## same kit. The grass quad has no thickness: from anywhere but straight
## overhead the only thing between lawn and cliff is a LINE, so a bench reads
## as paint on the rock rather than as ground with a body. `kaykit.cliff.lip`
## is the rolled edge the terrain's own `CliffDressing` crowns every real
## hillside with -- where the lip shares the wall's origin and rotation, which
## is the idiom copied here.
##
## Measured envelope, `kaykit_cliff_lip.tres`:
## AABB(-1.5, -0.705, -1.5, 3.0, 0.705, 2.75). Flat grass at y = 0 from its
## back edge out to local +1.0, then a rounded rim bulging to +1.25 and
## hanging 0.705 below the turf.
const GREEN_RIM_EDGE := &"kaykit.cliff.lip"
const GREEN_RIM_DEPTH := 2.75
const GREEN_RIM_FRONT := 1.25
## The rim is bounded to the cell it dresses, the way MINOR 2 bounds the quad:
## its depth scales to exactly one cell and its roll lands ON the boundary, so
## it reaches over nothing and cannot lay turf on a neighbour's street. It sits
## a centimetre ABOVE the boundary rather than under it -- the opposite of
## GREEN_CAP_LIFT and for the same reason the terrain lifts its own lip: two
## grass surfaces in one plane fight, and this one has to win, because it is
## the one carrying the edge.
const GREEN_RIM_LIFT := 0.01
## Measured envelopes, read off the descriptors rather than assumed:
## `kaykit_terrain_top_center.tres` is AABB(-1.5, 0, -1.5, 3.0, 1e-05, 3.0) --
## a single-swatch grass quad CENTRED on its origin, and
## `kaykit_cliff_wall.tres` is AABB(-1.5, -0.3, 0.25, 3.0, 4.0, 0.75) -- a rock
## face whose bulge stands in front of its origin and whose top is 3.7 above
## it.
##
## FIX 1, IMPORTANT 1: THESE FOUR ARE CHECKED MIRRORS, NOT TRUSTED COPIES.
## `test_the_skin_constants_mirror_the_module_descriptors` asserts each one
## against the descriptor it was transcribed from, because a re-bake that
## shifted an AABB would otherwise leave the coverage proofs below arguing
## about a module that no longer exists. A red there means the DESCRIPTOR
## moved: correct the constant and re-read every bound that rests on it.
const NATURAL_ROCK_TOP := 3.7
const NATURAL_ROCK_BASE := 0.3
const NATURAL_ROCK_FACE_DEPTH_CENTRE := 0.625
## Both modules are 3.0 m across their long axis, because both are authored on
## the terrain's own 3 m tile. Named once so the cross-axis scales below and
## the coverage arithmetic they have to satisfy read against the same number.
const TERRAIN_MODULE_SPAN := 3.0
## Both terrain modules are authored on the terrain's 3 m tile, and the fabric
## lattice is 1.5 m. Along the module's long axis that is exactly the pair a
## cap already spans and exactly the two bands a side course already covers,
## so only the CROSS axis is ever rescaled -- to the one cell the panel really
## closes. The green quad is a flat single-colour swatch (`CliffDressing`
## takes the ground palette's grass UV off this same mesh family), so scaling
## it inside its own plane changes no proportion an eye can read, and it drops
## to exactly the 1.5 m cell so a bench top can never overhang its own rim.
## The rock face keeps 2.16 m rather than dropping to 1.5, because the 1.77 m
## masonry module it replaces OVERSAILED its cell too: panels that merely abut
## draw a seam every cell, which is the coursing this task is retiring.
const GREEN_CAP_CROSS_SCALE := 0.5
const NATURAL_ROCK_CROSS_SCALE := 0.72
## ONE cliff mesh clads every tall bank, and the first pass laid it on the
## lattice unaltered: identical shard every 1.5 m across and every 3 m up. The
## capture of that (`h2b/renders/r1-12-compact/seed-012-overview-se.png`) reads
## as a quilt of blue scallops -- a decorative repeat, not a hillside, and by
## the same fault the ashlar had: a motif on a grid. The kit ships three more
## `Hill_Cliff_Tall_*_Side` variants and importing them is a new-asset
## decision this task may not take, so the repeat is broken by PLACEMENT
## instead, seeded off the panel's own coordinates so the payload stays a pure
## function of the cell set:
##
## * the shard is mirrored and turned upside down on about half the panels
##   (a rotation about the outward axis, so winding and volume are untouched
##   and one mesh reads as two);
## * its width, its height, how far it slides along the face and how far it
##   stands proud of it all vary, so no two neighbours share a lobe line.
##
## THE BOUNDS ARE A COVERAGE PROOF, NOT A TASTE. A slit between two shards
## does not show rock behind it -- the skin is a SHELL, so it shows the sky
## through the mountain. Two conditions, both on the WORST roll:
##
## * a lone shard must close its own cell by itself, because the neighbouring
##   cell may own no panel at all:
##       1.5 x (CROSS_SCALE - CROSS_JITTER) >= 0.75 + SLIDE
##       1.5 x 0.62 = 0.930 >= 0.870, margin 0.060 m;
## * two neighbours sliding APART must still overlap, since their slides can
##   differ by twice SLIDE:
##       3.0 x (CROSS_SCALE - CROSS_JITTER) >= 1.5 + 2 x SLIDE
##       3.0 x 0.62 = 1.860 >= 1.740, margin 0.120 m.
##
## The first pass failed both (0.16 jitter with a 0.24 slide leaves 0.30 m of
## a cell open on the worst pair) and the comment here claimed otherwise; the
## numbers are now written out so the claim is checkable. The rise is bounded
## the same way -- 4.0 x (1 - RISE_JITTER) = 3.36 m still covers the 3 m
## course -- and the TOP is pinned whatever the roll, because a bank's rim is
## where the green cap begins and may not move.
##
## TASK H2c FIX 2, IMPORTANT 1 -- WHICH PANELS THAT 3.36 m COVERS. The bound
## above is a bound on the JITTER, so it holds for every panel whose rise is
## the roll: the worst roll is 0.84, the module hangs 4.0 x 0.84 = 3.36 m from
## its pinned top, and the two-band course under that top is 2 x CELL_SIZE =
## 3.0 m. It does NOT hold for a panel the tail clamp shortens -- a clamped
## rise is not drawn from [0.84, 1.16] at all and can be as little as
## NATURAL_ROCK_CUT_MIN_RISE = 0.375, which covers one band and not two. Those
## panels are covered by a different argument, written out in full at
## `NATURAL_ROCK_CUT_MIN_RISE` below, and it is the only thing standing
## between a clamped panel and a slit.
const NATURAL_ROCK_CROSS_JITTER := 0.10
const NATURAL_ROCK_RISE_JITTER := 0.16
const NATURAL_ROCK_SLIDE := 0.12
const NATURAL_ROCK_RELIEF := 0.22
## TASK H2c FIX 1 -- THE STREET CUTS THE ROCK.
##
## Giving the shard a collider turned a bulge the eye could see into one a body
## cannot pass, and the 48-town matrix then measured what that costs: a majority
## of towns had a route component CUT APART -- a crossing between two walked
## cells with no way round it. The remedy the controller ruled for is the one a
## hill town's masons would have used: where the path passes, the rock is cut
## back. Not the collider (visible rock a body walks through is a lie), and not
## a global relief shave (the strata read is right everywhere it is not in the
## way).
##
## THE ARITHMETIC, because the clamp is derived and not chosen. The shard's nose
## plane is at local z = 1.0 (`kaykit_cliff_wall` is AABB z 0.25 -> 1.0) and its
## origin sits `NATURAL_ROCK_FACE_DEPTH_CENTRE` behind the boundary, so the nose
## stands `1.0 - 0.625 + relief` proud of it. Two panels facing each other across
## a one-cell street therefore leave
##
##     CELL_SIZE - 2 x (NOSE_LOCAL_Z - FACE_DEPTH_CENTRE + relief)
##       = 1.5 - 0.75 - 2 x relief
##
## and a body needs its own width plus the clearance query's margin on both
## sides plus a working allowance. At relief 0 that leaves 0.750 m for a
## 0.795 m body: a street flanked by rock on both sides was ALWAYS too narrow,
## whatever the jitter rolled -- which is why the pinch is common rather than
## freak. Solving for the relief that clears the budget gives the cut plane.
const NATURAL_ROCK_NOSE_LOCAL_Z := 1.0
## The player capsule's own width, `characters/character.tscn` radius
## 0.39746094 doubled, plus the 0.02 the clearance sweep pads its query with on
## each side, plus 0.03 of working allowance so the pass is not a scrape.
const NATURAL_ROCK_CUT_BODY_WIDTH := 0.79492188
const NATURAL_ROCK_CUT_QUERY_MARGIN := 0.02
const NATURAL_ROCK_CUT_ALLOWANCE := 0.03
const NATURAL_ROCK_CUT_BUDGET := NATURAL_ROCK_CUT_BODY_WIDTH \
	+ 2.0 * NATURAL_ROCK_CUT_QUERY_MARGIN + NATURAL_ROCK_CUT_ALLOWANCE
## -0.05746094: the rock is cut back a further 5.7 cm behind the plane its
## unjittered stand-off would have put it on. A panel that already jitters
## BEHIND this plane is not touched -- the cut is a ceiling on how far rock may
## stand into a crossing, not a new plane every cut panel is flattened to, so
## the face keeps its relief above and below the cut.
const NATURAL_ROCK_CUT_RELIEF := (FabricRecipe.CELL_SIZE \
	- 2.0 * (NATURAL_ROCK_NOSE_LOCAL_Z - NATURAL_ROCK_FACE_DEPTH_CENTRE) \
	- NATURAL_ROCK_CUT_BUDGET) * 0.5
## HOW FAR DOWN A PANEL REACHES, in bands, and therefore how far below its own
## course a crossing must be looked for. The shard HANGS from the top of its
## course and buries the rest below, so a panel is in the way of streets well
## under it: it spans `(TOP + BASE) x (1 + RISE_JITTER)` = 4.0 x 1.16 = 4.64 m
## downward from `(band + 1) x CELL_SIZE`, and a body on a floor further down
## still occupies `NATURAL_ROCK_CUT_BODY_HEIGHT` of that column. Overlap needs
##
##     (band + 1 - crossing) x CELL_SIZE - 4.64 < BODY_HEIGHT
##       -> band - crossing < (4.64 + 2.244 - 1.5) / 1.5 = 3.589
##
## so three bands. THIS WAS THE MISS IN THE FIRST CUT: reaching one band down
## caught the panel a body walks into and the one at its head, and left the
## panels two and three courses up still leaning over the same street. The
## eight-town check still split 9/standard until the reach was solved rather
## than assumed. `test_the_skin_constants_mirror_the_module_descriptors` re-does
## this arithmetic against the descriptor so it cannot rot.
const NATURAL_ROCK_CUT_BODY_HEIGHT := 2.244
## HEADROOM is NOT the body's height. The clearance sweep stands its capsule a
## floor-lift above the ground and then asks the physics server with a query
## margin, and that margin grows the shape in EVERY direction -- up as well as
## sideways. So the column a body really needs is
##
##     FLOOR_LIFT + MARGIN + BODY_HEIGHT + MARGIN + ALLOWANCE
##
## and a clamp solved against the bare 2.244 m comes out 0.03 m short, which is
## exactly the amount that left crossings shut after the tail clamp first
## landed and sent this back for another pass. The lift mirrors the sweep's
## `CLEARANCE_FLOOR_LIFT`; the two must move together.
const NATURAL_ROCK_CUT_FLOOR_LIFT := 0.02
const NATURAL_ROCK_CUT_HEADROOM := NATURAL_ROCK_CUT_FLOOR_LIFT \
	+ 2.0 * NATURAL_ROCK_CUT_QUERY_MARGIN + NATURAL_ROCK_CUT_BODY_HEIGHT \
	+ NATURAL_ROCK_CUT_ALLOWANCE
const NATURAL_ROCK_CUT_BAND_REACH := 3
## THE SECOND HALF OF THE CUT: THE TAIL, not the nose.
##
## Stand-off alone did not clear the corpus, and the probe that found out why
## (`h2c-evidence/pinch_probe.gd`) is worth reading before touching any of this.
## The panels still shutting streets after the first cut were not the facing
## lobes the pinch arithmetic models. They were panels whose OWN FACE PLANE the
## street crosses, one to three courses above it: the shard clads a 1.5 m band
## but is 4 m tall, the design buries the excess "in the mass below", and where
## the mass below is an open street the excess hangs into it instead. Such a
## panel does not LEAN into the corridor, it crosses the whole of it -- the
## probe reads 1.500 m of a 1.500 m boundary covered -- so no stand-off reaches
## it, and pulling it back only moves the wall.
##
## What reaches it is the module's own RISE, which is the one dial that moves
## its bottom edge: the top is pinned (a bank's rim is where the green cap
## begins) and the module hangs `(TOP + BASE) x rise` below it. Clearing a body
## walking `g` bands underneath needs
##
##     (g + 1) x CELL_SIZE - (TOP + BASE) x rise >= HEADROOM
##
## and the rise may not fall below what covers the panel's own BAND, or the
## skin opens a slit and shows sky through the mountain:
##
##     (TOP + BASE) x rise >= CELL_SIZE      ->  rise >= 0.375
##
## At g = 3 that allows rise <= 0.917 and the tail lifts clear. At g = 2 it
## demands 0.542 and at g = 1 it demands 0.167 -- and 0.167 is below the
## coverage floor, so at g = 1 there is NO rise that both clads the band and
## clears the street. Those crossings pass a mass corner at head height and no
## cladding of any material can open them; they are counted, not silenced.
##
## TASK H2c FIX 2, IMPORTANT 1 -- THE FLOOR IS A BAND AND A PANEL CLADS A
## COURSE, SO HERE IS THE REST OF THE PROOF. `maze_stone_faces` keeps one panel
## per STONE_COURSE_BANDS = 2 exposed bands, so the panel at band y clads the
## COURSE {y, y - 1} whenever band y - 1's face is exposed too. A floor of one
## CELL_SIZE therefore proves less than it looks: 0.375 covers band y and
## nothing under it. The three cases the clamp can be in, and what closes each:
##
## * g = 3 -- ARITHMETIC ALONE. The ceiling is 0.9165, the module hangs
##   4.0 x 0.9165 = 3.666 m, and the course is 3.0 m. Fully clad, no
##   dependency.
## * g = 2 -- THE ONE THAT LEANS ON `blocked = 0`. The ceiling is 0.5415 and
##   the module hangs 2.166 m, which is 0.834 m short of the course. That is a
##   slit IF band y - 1 carries an exposed face. It cannot, while the corpus
##   measures `blocked = 0`: for that face to exist, cell (x, y-1, z) must be
##   maze stone, and it sits directly on the walked cell (x, y-2, z) that fired
##   the clamp. Stone directly over a walked cell has an exposed DOWN face --
##   the neighbour below is neither retained nor solid -- so `maze_stone_faces`
##   emits a floor-facing cap there, `maze_skin_treatments` makes it MASONRY
##   (only an UP cap can be green), and `_maze_stone_transform` lays that 3 m
##   slab flat and sinks it by STONE_CAP_HALF_DEPTH so its rock face is FLUSH
##   with the boundary. The slab spans the cell's whole footprint and the cell
##   is 1.5 m tall against a body that needs NATURAL_ROCK_CUT_HEADROOM =
##   2.334 m, so the capsule meets it at every offset and that walked cell
##   would count `blocked`. The 48-town matrix measures `blocked = 0`, so the
##   configuration is not in the corpus and the clamped panel's course is one
##   band.
## * g = 1 -- band y - 1 IS the street, so the course is one band and 0.375
##   clads it exactly. This case is also `maze_natural_face_tail_is_clearable`
##   false and is published as `maze_skin_cut_tail_unclearable_count`, measured
##   0 corpus-wide, so it does not arise either.
##
## THE DEPENDENCY IS LOAD-BEARING AND IT IS ON A MEASURED NUMBER, not on a
## construction. If `blocked` ever leaves zero, this floor stops being sound at
## g = 2 and has to be re-derived -- the honest fix then is 2 x CELL_SIZE /
## (TOP + BASE) = 0.75, which is why that number is NOT the floor today: it
## would make g = 2 unclearable and course the crossing over to masonry, which
## is a heavier answer than the geometry needs.
const NATURAL_ROCK_CUT_MIN_RISE := FabricRecipe.CELL_SIZE \
	/ (NATURAL_ROCK_TOP + NATURAL_ROCK_BASE)
## The grass quad has no thickness, so it is offset off the boundary it closes
## rather than left coplanar with the course below it -- DOWN by a hair rather
## than up, which is the opposite of `CliffDressing.LIP_LIFT` and for the
## opposite reason. The terrain lifts its lip to overlay a field it would
## otherwise fight; here there is nothing to fight, and a quad standing proud
## catches light on all four of its edges and reads as a sheet of paper laid
## on the rock. Two centimetres under the rim, the rock's own top edge
## oversails it and the bench reads as turf behind a kerb.
const GREEN_CAP_LIFT := -0.02
## What one panel of the skin WEARS. The shell, its coursing and its cap
## pairing are unchanged by this: a treatment picks the module, never the
## panel, so the retained rock's volume and the audited face identity are the
## same facts they were.
enum SkinTreatment {MASONRY, NATURAL, GREEN}
## A side panel is 3 m tall -- TWO bands -- so a run of exposed stone is
## coursed at the module's own height instead of hung once per band. Hanging
## one per band put each module's lower band inside the one below it, which is
## both twice the geometry and the reason every 1.5 m showed a seam. The
## bottom course of an odd run buries its lower half in the mass beneath,
## exactly as a building plinth buries its own.
const STONE_COURSE_BANDS := 2
## TASK H2c FIX 2, MINOR 3 -- THE MASONRY REACH, NAMED. The coursed module's
## own height was a bare `3.0` at three sites (the trim's full height, the trim
## scale it divides by, and the flat cap's sweep) and the band reach it implies
## was a bare `-3` in a range. Both are now derived and both are MIRRORED
## against the descriptor by `test_the_skin_constants_mirror_the_module_
## descriptors`, exactly as `NATURAL_ROCK_CUT_BAND_REACH` is, so a re-bake that
## moved `sfv.fabric.wall.rock.plain.001`'s 3.000 m envelope fails there rather
## than shifting every masonry panel in silence.
##
## The height IS the course: two bands of cladding, which is the whole reason
## `STONE_COURSE_BANDS` is 2 and not 1.
const STONE_MODULE_HEIGHT := STONE_COURSE_BANDS * FabricRecipe.CELL_SIZE
## How many bands BELOW its own a coursed panel can hang into. The module drops
## `STONE_MODULE_HEIGHT` from `(band + 1) x CELL_SIZE` and a body standing `g`
## bands under it occupies `NATURAL_ROCK_CUT_HEADROOM` of that column, so the
## two meet while
##
##     (g + 1) x CELL_SIZE < STONE_MODULE_HEIGHT + HEADROOM
##       ->  g < (3.0 + 2.334) / 1.5 - 1 = 2.556
##
## which is two bands. The rock's reach is three because its module is taller
## and its rise jitters; this one neither hangs further nor rolls.
const STONE_FACE_OVERHANG_BAND_REACH := 2
## The 3 m module laid flat spans two cells along its former height axis, so a
## cap always covers this cell and ONE neighbour, chosen in this fixed order.
## FIX 1, CRITICAL 1: the neighbour is preferentially another exposed cap cell
## that has no slab yet -- adjacent capped cells are PAIRED and the pair emits
## one slab, where the first pass emitted one each and laid them coplanar. An
## odd leftover leans on a neighbour that is closed mass (stone, plinth or
## building) instead, which owns no cap of its own and so cannot be covered
## twice; that also keeps the slab out of a street's headroom where there is
## mass to lean on. A cap with neither is centred on its own cell.
const STONE_CAP_PARTNERS: Array[Vector3i] = [Vector3i.BACK, Vector3i.FORWARD,
	Vector3i.RIGHT, Vector3i.LEFT]
## The public-surface kinds that PLANK a floor, and so draw the boundary a
## stone cap would otherwise have to close. Exactly the three
## `production_surface_payload` tiles: TERRAIN_STREET is worn-path paint on the
## terrain mesh and STAIR is a generated transition mesh, and neither puts
## anything at the top of the stone cell it runs over (fix 1, IMPORTANT 4).
const PAVED_FLOOR_KINDS: Array[int] = [
	PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
	PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE,
	PublicRealmSurfacePlan.SurfaceKind.BRIDGE,
]


static func payload(plan: SettlementFabricPlan) -> EnvironmentInstancePayload:
	assert(plan != null and plan.is_sealed() and plan.validate())
	var out := EnvironmentInstancePayload.new()
	for placement: Dictionary in plan.expanded_placements():
		out.add(StringName(placement.asset_id),
			placement.transform as Transform3D, Color.WHITE,
			StringName(placement.stable_id))
	out.append_from(modular_room_corner_payload(plan))
	assert(out.validate())
	return out


static func modular_room_corner_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## Authored facade modules are handed: one carries a heavier edge frame than
	## its mate. Four deterministic stitch posts make the final modular room read
	## as one timber frame without changing the measured recipe envelope that the
	## topology search uses. Shared world-space corners deduplicate, so a party
	## wall gets one post rather than the doubled beam seen in review captures.
	var out := EnvironmentInstancePayload.new()
	if plan == null:
		return out
	var claimed_positions: Dictionary = {}
	for unit: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit.recipe_id)
		if recipe_value == null:
			continue
		var local_posts := _modular_room_corner_transforms(recipe_value)
		for index in local_posts.size():
			var world_transform := unit.transform() * local_posts[index]
			var origin := world_transform.origin
			var key := "%d:%d:%d" % [roundi(origin.x * 1000.0),
				roundi(origin.y * 1000.0), roundi(origin.z * 1000.0)]
			if claimed_positions.has(key):
				continue
			claimed_positions[key] = true
			out.add(TIMBER_CORNER_POST, world_transform, Color.WHITE,
				StringName("%s/frame-corner-%d" % [unit.stable_id, index]))
	assert(out.validate())
	return out


static func _modular_room_corner_transforms(recipe_value: FabricRecipe) \
		-> Array[Transform3D]:
	var out: Array[Transform3D] = []
	if recipe_value == null or not recipe_value.has_tag(&"room") \
			or not recipe_value.has_tag(&"generated_building") \
			or recipe_value.has_tag(&"passage_room") \
			or recipe_value.has_tag(&"stair_house"):
		return out
	var half_x := 3.0
	var half_z := 3.0
	if recipe_value.has_tag(&"long_building"):
		half_z = 4.5
	elif recipe_value.has_tag(&"slim_building"):
		half_x = 1.5
	elif recipe_value.has_tag(&"row_building"):
		half_z = 1.5
	elif recipe_value.has_tag(&"compact_tower") \
			or recipe_value.has_tag(&"support_house"):
		half_x = 1.5
		half_z = 1.5
	const POST_HALF_WIDTH := 0.375
	var centre := Vector3(-0.75, 0.0, -0.75)
	for signs: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
			Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		out.append(Transform3D(Basis.IDENTITY, centre + Vector3(
			signs.x * (half_x - POST_HALF_WIDTH), 0.0,
			signs.y * (half_z - POST_HALF_WIDTH))))
	return out


static func commit(parent: Node3D, plan: SettlementFabricPlan,
		catalog: EnvironmentCatalog, include_collision: bool = true) -> Dictionary:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(parent != null and catalog != null and plan != null \
		and plan.is_sealed())
	var cache := EnvironmentRenderCache.new(catalog)
	var surface_instances := surface_visual_payload(plan.surface_plan)
	var instances := payload(plan)
	var support_instances := structural_support_payload(plan)
	instances.append_from(support_instances)
	var demanded_assets := instances.asset_ids()
	for asset_id: StringName in surface_instances.asset_ids():
		if not demanded_assets.has(asset_id):
			demanded_assets.append(asset_id)
	demanded_assets.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	assert(cache.prepare(demanded_assets))
	var collision_count := 0
	if include_collision:
		collision_count = EnvironmentCollisionBuilder.commit(parent, instances,
			cache, &"FabricCollision")
	var queue := EnvironmentCommitQueue.new(cache, &"FabricVisuals")
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, instances)
	queue.enqueue(Vector2i.ZERO, 1, parent, surface_instances)
	while queue.pending_count() > 0:
		queue.drain(64)
	var surface_commit := _commit_surfaces(parent, plan.surface_plan,
		include_collision)
	# The retained hill has NO generated skin. Round-3 review: flat slabs in an
	# earth palette read as boxes, and a town must be built out of catalog
	# assets -- buildings, paths, supports -- not primitives. An unfronted cut
	# face is therefore honestly nothing; a terrain-integrated hill is a
	# separate direction and this must not pre-empt it with a placeholder.
	return {
		"instance_count": instances.instance_count + surface_instances.instance_count,
		"fabric_instance_count": instances.instance_count,
		"surface_visual_instance_count": surface_instances.instance_count,
		"structural_support_instance_count": support_instances.instance_count,
		"collision_piece_count": collision_count \
			+ int(surface_commit.collision_piece_count),
		"asset_count": instances.asset_ids().size(),
		"surface_patch_count": plan.surface_plan.patches.size(),
		"surface_triangle_count": int(surface_commit.triangle_count),
	}


static func structural_support_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## Sparse fixed-module supports derive from the same continuous structural
	## surface that owns traversal. A support is never emitted through a lower
	## public route or occupied room column; those columns are already visibly
	## carried by the city below. Odd half-level heights bury the bottom half of
	## one ordinary 3 m module instead of stretching it.
	var out := EnvironmentInstancePayload.new()
	if plan == null or plan.surface_plan == null:
		return out
	out.append_from(low_retaining_payload(plan))
	out.append_from(terrace_retaining_payload(plan))
	var solids := plan.transformed_cells(&"solid")
	var structural := plan.surface_plan.cells_for_kind(
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT)
	var structural_set: Dictionary = {}
	for cell: Vector3i in structural:
		structural_set[cell] = true
	for cell: Vector3i in structural:
		var support_base := plan.surface_plan.support_base_at(cell)
		if cell.y <= support_base \
				or (plan.surface_plan.has_support_base(cell) \
					and cell.y - support_base == 1):
			continue
		var exposed_directions: Array[Vector3i] = []
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if not structural_set.has(cell + direction):
				exposed_directions.append(direction)
		if exposed_directions.is_empty() \
				or not _is_structural_support_anchor(cell, exposed_directions) \
				or _column_is_occupied_below(plan, solids, cell):
			continue
		var surface_y := float(cell.y) * FabricRecipe.CELL_SIZE
		var segment_top := surface_y
		var base_y := float(support_base) * FabricRecipe.CELL_SIZE
		var segment := 0
		while segment_top > base_y + 0.001:
			var origin_y := segment_top - 3.0
			var transform := Transform3D(Basis.IDENTITY,
				Vector3(float(cell.x) * FabricRecipe.CELL_SIZE, origin_y,
					float(cell.z) * FabricRecipe.CELL_SIZE))
			out.add(TIMBER_SUPPORT, transform, Color.WHITE,
				StringName("public-support/%d/%d/%d/%d" % [cell.x, cell.y,
					cell.z, segment]))
			segment_top -= 3.0
			segment += 1
	assert(out.validate())
	return out


static func _is_structural_support_anchor(cell: Vector3i,
		exposed_directions: Array[Vector3i]) -> bool:
	## A structural deck reads as load-bearing only when every exposed corner has
	## a post and each longer edge repeats that rhythm at the native 3 m module
	## width. The former one-in-three hash left terminal courts and market decks
	## with long apparently floating corners; this boundary rule is geometric and
	## deterministic instead of decorative.
	if exposed_directions.size() >= 2:
		return true
	var edge := exposed_directions[0]
	return posmod(cell.z, 2) == 0 if edge.x != 0 \
		else posmod(cell.x, 2) == 0


static func low_retaining_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## A platform only 1.5 m above its terrain datum cannot be a traversable
	## undercroft. Render it as a retained stone terrace, with fixed 3 m wall
	## modules half-buried, instead of exposing a crawl-height lawn beneath sparse
	## timber posts. Full-headroom surfaces continue to use open timber support.
	##
	## Within the round-3 stone budget by construction: exactly one module per
	## exposed face of a ONE-band step, which can never stack.
	var out := EnvironmentInstancePayload.new()
	if plan == null or plan.surface_plan == null:
		return out
	var solids := plan.transformed_cells(&"solid")
	var retained: Dictionary = {}
	for cell: Vector3i in plan.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT):
		if plan.surface_plan.has_support_base(cell) \
				and cell.y - plan.surface_plan.support_base_at(cell) == 1:
			retained[cell] = true
	for cell_value: Variant in retained.keys():
		var cell := cell_value as Vector3i
		var surface_y := float(cell.y) * FabricRecipe.CELL_SIZE
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if retained.has(neighbor) or solids.has(neighbor) \
					or solids.has(neighbor - Vector3i.UP):
				continue
			var midpoint := Vector3(cell) * FabricRecipe.CELL_SIZE \
				+ Vector3(direction) * FabricRecipe.CELL_SIZE * 0.5
			midpoint.y = surface_y - 3.0
			var yaw := PI * 0.5 if direction.x != 0 else 0.0
			out.add(LOW_RETAINING_WALL,
				Transform3D(Basis(Vector3.UP, yaw), midpoint), Color.WHITE,
				StringName("retaining-wall/%d/%d/%d/%d/%d" % [cell.x,
					cell.y, cell.z, direction.x, direction.z]))
	assert(out.validate())
	return out


static func terrace_retaining_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## Stone appears in exactly ONE role, and only under a building: the house
	## PLINTH -- the authored foundation piece, one course, where a house stopped
	## descending short of its own ground. This is the "stone to make a house one
	## storey taller" the directive allows, and it is where the liked
	## wood-over-stone junction happens.
	## THE MOUNTAIN SUBSTRATE ROLE IS GONE (terrain milestone Wave 4, design
	## §3.4). `hill_substrate_walls` used to tile the riser a house stood on with
	## whole rock modules, because the fabric owned the hill and an undrawn hill
	## left its houses floating. SettlementReliefPlan now stamps that hill into
	## the heightfield, so the terrain mesh renders it, CliffDressing dresses its
	## faces and the chunk collider carries it -- re-drawing it here would put a
	## masonry collider inside the terrain's own volume and rebuild the monument
	## rounds 2 and 3 rejected. The retired asset compiler no longer declares the
	## remainder either, so this function's input is already only plinths.
	##
	## TASK C5b RULING 1 ADDS THE SECOND ROLE, and only for a maze town: the
	## retained MOUNTAIN the plot model cut its streets and plots out of. That
	## hill is NOT the heightfield's -- `WarrenVolumetricSolver._retain_maze_
	## rock` claims it above each column's own terrain datum, so the terrain
	## mesh stops below it and nothing else in the pipeline draws it. Left
	## unskinned it is the render debt C5 measured: plazas on posts over
	## daylight, bored streets standing on nothing, and 47-64 building plinth
	## faces per town suppressed by mass that draws nothing. The skin is a
	## shell over the same channel, in the same module, through the same
	## transform idiom; legacy plans tag no cell and get no extra instance.
	if plan == null:
		return EnvironmentInstancePayload.new()
	var retained := plan.retained_terrace_cells
	var solids := plan.transformed_cells(&"solid")
	var bearing_footprint := plan.transformed_cells(&"terrain_bearing")
	var out := house_plinth_walls(retained, solids, bearing_footprint)
	var paved := public_floor_cells(plan.surface_plan)
	var plinths := plinth_faces(retained, solids, bearing_footprint)
	var walked := walked_floor_cells(plan.surface_plan)
	out.append_from(maze_stone_walls(retained, solids, paved, plinths, walked))
	# TASK H2b FIX 1, IMPORTANT 3. The rolled edge round every green bench,
	# beside the shell rather than inside it -- see `maze_green_rim_walls`.
	out.append_from(maze_green_rim_walls(retained, solids, paved, plinths,
		walked))
	# TASK C5e RULING 3. The other half of what a maze town's crown wears.
	# The parapet course that used to cap every flat roof is released to air
	# by `WarrenVolumetricSolver._maze_released_parapet_cells`, so the slab is
	# an open terrace and its exposed edges take a railing. It rides here
	# rather than in its own payload because this is the one function BOTH the
	# production materialiser and the review commit already call for the
	# retained crown, and a terrace with no rail is the same defect as a
	# mountain with no skin.
	out.append_from(maze_terrace_railings(plan))
	assert(out.validate())
	return out


static func building_ceiling(solids: Dictionary) -> Dictionary:
	## Highest band a building occupies in each column, as Vector2i -> int. A
	## retained cell below that band is mass the town stands ON: whatever of it
	## shows is read against the house above it, not as bare masonry.
	var out: Dictionary = {}
	for cell_value: Variant in solids.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		out[column] = maxi(int(out.get(column, cell.y)), cell.y)
	return out


static func house_plinth_walls(retained: Dictionary,
		solids: Dictionary, bearing_footprint: Dictionary = {}) \
		-> EnvironmentInstancePayload:
	## One authored HOUSE_PLINTH foundation piece per exposed plinth face, and
	## never a second. Its top is flush with the house floor it carries and its
	## bottom is buried in the bank below -- the same half-burial the one-band
	## court in low_retaining_payload already relies on, and the reason no asset
	## is ever scaled. A deeper bank is NOT tiled with further courses: nothing
	## below the declared run (bounded at construction by
	## WarrenMassif.PLINTH_BUDGET_BANDS) is ever rendered.
	##
	## Pure function of integer cell sets whose every loop runs over a sorted
	## key list, so the payload is byte-identical for identical input.
	var out := EnvironmentInstancePayload.new()
	var keys: Array[Vector4i] = []
	keys.assign(plinth_faces(retained, solids, bearing_footprint).keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		var direction := FACE_DIRECTIONS[key.w]
		var midpoint := Vector3(float(key.x), 0.0, float(key.z)) \
			* FabricRecipe.CELL_SIZE \
			+ Vector3(direction) * FabricRecipe.CELL_SIZE * 0.5
		midpoint.y = float(key.y + 1) * FabricRecipe.CELL_SIZE - 3.0
		var yaw := PI * 0.5 if direction.x != 0 else 0.0
		out.add(HOUSE_PLINTH,
			Transform3D(Basis(Vector3.UP, yaw), midpoint), Color.WHITE,
			StringName("house-plinth/%d/%d/%d/%d" % [key.x, key.y, key.z,
				key.w]))
	assert(out.validate())
	return out


static func plinth_faces(retained: Dictionary, solids: Dictionary,
		bearing_footprint: Dictionary = {}) -> Dictionary:
	## The faces stone is allowed to claim, keyed Vector4i(x, band, z, direction
	## index into FACE_DIRECTIONS) at the TOP band of the run. A face qualifies
	## only when a building stands directly on that cell (so the stone is part
	## of that house rather than a retaining wall in its own right) and the
	## side is one nothing else already closes.
	##
	## NOT gated on whether the house's own ground storey already reads as rock.
	## Round 5 shipped that gate and it refused all 216 houses the stamped-hill
	## corpus declared a plinth for, because every ground storey is
	## unconditionally rock (WarrenAssetCompiler builds every stack's base from
	## `room.*.base.rock`) -- the test was "does this house wear any stone",
	## which is always true, rather than "how much stone would this add"
	## (task-24-report.md concern #2). A plinth is FRONTED stone: the check
	## just below already requires a building to stand directly on the cell, so
	## it can never be a bare retaining face. It is bounded on its own terms by
	## the declaration side (WarrenParcelConstruction.resolve_support_band,
	## budgeted at WarrenMassif.PLINTH_BUDGET_BANDS) rather than by
	## tallest_bare_stone_stack_bands, which governs masonry nothing stands
	## over and must not be weakened to make room for this. Whether the ground
	## storey above also happens to be rock is the separate, already-accepted
	## "stone feature" the reviewer praised, not a reason to refuse the
	## foundation course beneath it.
	##
	## The 3 m module hung from this band also covers the band below it, which
	## is why the earth skin skips both.
	##
	## TASK C5b FIX 1, IMPORTANT 2. A retained cell the compiler tagged as the
	## MOUNTAIN is never a building's course, whatever happens to stand on it:
	## the stone skin below already owns every exposed face of it, so a plinth
	## panel here would put a SECOND, different module in the very same plane
	## -- `HOUSE_PLINTH` and `MAZE_STONE_MODULE` at one transform. A plinth is
	## a building's own base course; the mountain is not a building. Legacy
	## plans tag no cell, so this removes no legacy face.
	var out: Dictionary = {}
	var stone := maze_stone_cells(retained)
	var cells: Array[Vector3i] = []
	cells.assign(retained.keys())
	cells.sort_custom(_cell_before)
	for cell: Vector3i in cells:
		if stone.has(cell):
			continue
		var above := cell + Vector3i.UP
		# TASK C5b FIX 1, IMPORTANT 2. The DECLARED run is one course, and this
		# is where that promise is kept: a retained cell under another retained
		# cell is a bank the course above already faces, and its own 3 m module
		# would cover this band a second time. Measured on seed 12/compact as
		# four panels below the course at (7, 0, -6) and (9, 0, 0), where the
		# course cell above is also carried in the solid projection -- panels
		# `house_plinth_walls` promises never to render and the shell audit
		# never expected, so `foundation_rendered_face_count` stood four above
		# `foundation_expected_face_count`.
		if retained.has(above):
			continue
		if not solids.has(above) and not bearing_footprint.has(above):
			continue
		for index in FACE_DIRECTIONS.size():
			var neighbor := cell + FACE_DIRECTIONS[index]
			if retained.has(neighbor) or solids.has(neighbor) \
					or bearing_footprint.has(neighbor + Vector3i.UP):
				continue
			out[Vector4i(cell.x, cell.y, cell.z, index)] = true
	return out


static func maze_stone_cells(retained: Dictionary) -> Dictionary:
	## The retained cells a maze town's compiler tagged as MOUNTAIN. Empty for
	## every legacy plan, which is what keeps the skin below inert there.
	var out: Dictionary = {}
	for cell_value: Variant in retained.keys():
		var tag: Variant = retained[cell_value]
		if tag is StringName and StringName(tag) == MAZE_STONE_TAG:
			out[cell_value as Vector3i] = true
	return out


static func maze_stone_faces(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {}) -> Dictionary:
	## TASK C5b RULING 1 -- the retained mountain is a SHELL, not a voxel dump.
	## The panels that shell needs, keyed Vector4i(x, band, z, index into
	## STONE_FACE_DIRECTIONS) at the cell each panel hangs from, and VALUED
	## with the neighbour offset that panel reaches over (`Vector3i.ZERO` for a
	## side panel, and for a cap with nothing beside it to lean on).
	##
	## The module is 3 m long whichever way it is laid, so both rules below are
	## about covering two cells with one instance rather than one each:
	##
	## * A SIDE run is coursed at the module's own height (STONE_COURSE_BANDS),
	##   counting down from the top of the column's contiguous exposed run.
	## * A CAP is PAIRED. Laid flat the module spans two cells along its former
	##   height axis, so emitting one per exposed top or bottom face laid two
	##   coplanar slabs over every adjacent pair -- 248 tops and 259 bottoms on
	##   seed 12 for barely half that much ground (fix 1, CRITICAL 1). Adjacent
	##   exposed cap cells are matched instead and the pair owns ONE slab; an
	##   odd leftover leans over closed mass, exactly as before.
	##
	## `plinths` is `plinth_faces()` for the same plan. A building's plinth
	## panel is 3 m too, so it already closes the top band of any stone run
	## directly beneath it, and a stone panel there would intersect it in
	## plane; that run starts one band lower instead (fix 1, IMPORTANT 2).
	##
	## Pure function of integer cell sets whose loops run over a sorted key
	## list, so the payload is byte-identical for identical input.
	var exposed := exposed_maze_stone_faces(retained, solids, paved)
	var out: Dictionary = {}
	var caps: Array[Vector4i] = []
	for key_value: Variant in exposed.keys():
		var key := key_value as Vector4i
		if key.w >= FACE_DIRECTIONS.size():
			caps.append(key)
			continue
		# Keep the top of every STONE_COURSE_BANDS-tall course, counting down
		# from the top of this column's own contiguous run.
		var above := 0
		var probe := Vector4i(key.x, key.y + 1, key.z, key.w)
		while exposed.has(probe):
			above += 1
			probe.y += 1
		if _plinth_covers(plinths, probe):
			above += 1
		if above % STONE_COURSE_BANDS == 0:
			out[key] = Vector3i.ZERO
	caps.sort_custom(_face_before)
	var paired: Dictionary = {}
	for key: Vector4i in caps:
		if paired.has(key):
			continue
		paired[key] = true
		out[key] = _maze_stone_cap_partner(key, exposed, paired, retained,
			solids)
	return out


static func exposed_maze_stone_faces(retained: Dictionary,
		solids: Dictionary, paved: Dictionary = {}) -> Dictionary:
	## The raw shell: every boundary of retained maze stone that meets
	## something other than mass, before the side faces are coursed and the
	## caps are paired. Audited beside the panel count so "the shell is
	## complete" and "the panels cover the shell" stay two separate, checkable
	## statements.
	##
	## A face is exposed when the neighbour on that side is not mass: another
	## retained cell (stone or a building's plinth course), a building cell,
	## or -- for the sky-facing top only -- a public floor that PLANKS itself
	## (`public_floor_cells`), all emit nothing, because something else already
	## closes that seam.
	##
	## The paved exception is the top face's alone. A stone cell BESIDE a
	## street must still wear its retaining face -- that is the whole point of
	## "the street stands on stone" -- while a stone cell UNDER a planked floor
	## would only put rock behind the planks that already draw it.
	var stone := maze_stone_cells(retained)
	var out: Dictionary = {}
	if stone.is_empty():
		return out
	var cells: Array[Vector3i] = []
	cells.assign(stone.keys())
	cells.sort_custom(_cell_before)
	for cell: Vector3i in cells:
		for index in STONE_FACE_DIRECTIONS.size():
			var direction := STONE_FACE_DIRECTIONS[index]
			var neighbor := cell + direction
			if retained.has(neighbor) or solids.has(neighbor):
				continue
			if direction == Vector3i.UP and paved.has(neighbor):
				continue
			out[Vector4i(cell.x, cell.y, cell.z, index)] = true
	return out


static func maze_bank_height(exposed: Dictionary, face: Vector4i) -> int:
	## TASK H2b -- how tall the BANK this side face stands in really is, in
	## bands: the contiguous run of exposed faces in the same fine column and
	## the same direction, counted through this one whether it is the top of a
	## course or not.
	##
	## The run, not the panel, is what an eye reads. A 3 m panel is two bands
	## whatever it clads, so counting panels would call every bank two bands
	## tall; and the coursing walks DOWN from the top of the run, so the run is
	## already the unit `maze_stone_faces` thinks in.
	##
	## Zero for a cap: a sky- or floor-facing face stands in no bank.
	if face.w >= FACE_DIRECTIONS.size():
		return 0
	var top := face.y
	while exposed.has(Vector4i(face.x, top + 1, face.z, face.w)):
		top += 1
	var bottom := face.y
	while exposed.has(Vector4i(face.x, bottom - 1, face.z, face.w)):
		bottom -= 1
	return top - bottom + 1


static func maze_skin_treatments(exposed: Dictionary, faces: Dictionary,
		walked: Dictionary = {}) -> Dictionary:
	## TASK H2b -- which module each panel of the skin wears, as
	## `panel key -> SkinTreatment`. One entry per panel of `maze_stone_faces`
	## and never a panel of its own, so the shell this decides the cladding of
	## is exactly the shell that rule derived.
	##
	## THE THREE ANSWERS, and the reason each is the right one:
	##
	## * GREEN -- a SKY-FACING cap the public realm does not walk. After task
	##   H2 retired the crown lids these are terrace bench tops, the massif's
	##   own shoulders, and the flat plateaus task E4's trim left on top of a
	##   plot it cut down. Nobody stands on them and nothing is built on them:
	##   they are ground, and ground is green. A cap covers its own cell AND
	##   the neighbour it was paired with, so BOTH have to be unwalked -- one
	##   green plate under a street would be lawn where the pavement is.
	## * NATURAL -- a side face in a bank taller than STONE_BUDGET_BANDS. Two
	##   bands is the budget a mason's retaining wall was given; above it the
	##   face is hillside, and hillside is rock.
	## * MASONRY -- everything else: the <= 2-band retaining faces, the caps
	##   the realm walks (task C5b's "the street stands on stone"), and every
	##   floor-facing cap, which is the roof of a bored passage and is read
	##   from inside a tunnel rather than as part of the town's silhouette.
	var out: Dictionary = {}
	for key_value: Variant in faces.keys():
		var key := key_value as Vector4i
		if key.w >= FACE_DIRECTIONS.size():
			out[key] = SkinTreatment.GREEN \
				if STONE_FACE_DIRECTIONS[key.w] == Vector3i.UP \
					and _maze_cap_is_free(key, faces[key] as Vector3i, exposed,
						walked) \
				else SkinTreatment.MASONRY
			continue
		var natural := maze_bank_height(exposed, key) > STONE_BUDGET_BANDS
		# TASK H2c FIX 1. The cut's fallback: a tall bank the street crosses,
		# on a day the cut can no longer be expressed as stand-off, is coursed
		# rather than left as rock a body cannot pass. Dead today by
		# construction and live the moment the arithmetic above stops holding.
		if natural and not maze_natural_cut_is_expressible() \
				and maze_natural_face_is_cut(key, walked):
			natural = false
		out[key] = SkinTreatment.NATURAL if natural else SkinTreatment.MASONRY
	return out


static func maze_natural_face_is_cut(key: Vector4i,
		walked: Dictionary) -> bool:
	## TASK H2c FIX 1. Does this rock panel stand where the public realm
	## CROSSES? A side panel faces exactly one open cell -- the neighbour its
	## face is exposed toward -- so the question is whether that cell is walked
	## and has a walked lateral neighbour to reach. If it has, a body has to get
	## between the two, and this panel is one of the things in the way.
	##
	## Derived HERE from the walked-cell set the assembler already holds, not
	## imported from the clearance harness: the harness measures the same
	## predicate with a physics query, and a skin that read the harness's answer
	## would be a skin that cannot be built without running the harness.
	##
	## The bands BELOW are asked as well, `NATURAL_ROCK_CUT_BAND_REACH` of them,
	## because the shard hangs from the top of its course rather than standing
	## on the bottom of it: a panel three courses up still leans over the street
	## a body walks. The first band down alone is the census's `head` panels --
	## the capsule is 2.244 m against a 1.5 m band, so three quarters of a metre
	## of a body stands in the course above the floor it walks -- and the two
	## after that are the module's own overhang.
	if key.w >= FACE_DIRECTIONS.size():
		return false
	# BOTH columns. The module STRADDLES its boundary -- it is pulled back so
	# the rock stands half in the mass and half in the open -- so a street under
	# the mass side is as much in its way as one under the side it faces. The
	# probe found the panel that proved it: a face three courses up whose faced
	# cell is solid all the way down, over a street running through its own
	# column, which a faced-cell-only test never named.
	var own := Vector3i(key.x, key.y, key.z)
	var faced := own + STONE_FACE_DIRECTIONS[key.w]
	for band in NATURAL_ROCK_CUT_BAND_REACH + 1:
		var drop := Vector3i.DOWN * band
		if _maze_cell_is_crossed(faced + drop, walked) \
				or _maze_cell_is_crossed(own + drop, walked):
			return true
	return false


static func maze_stone_face_overhangs_walk(key: Vector4i,
		walked: Dictionary) -> bool:
	## TASK H2c FIX 1 SUB-ROUND. Does this coursed panel hang into a street?
	##
	## The reach is TWO bands, not one, and the arithmetic is the same shape as
	## the rock's; it is derived and named at `STONE_FACE_OVERHANG_BAND_REACH`
	## rather than spelled `-3` in the range below (fix 2, minor 3).
	##
	## The test is on the panel's OWN MASS COLUMN, exactly as the rock's is and
	## for exactly the same reason: an ordinary retaining wall has mass beneath
	## it -- the course below wears its own panel -- so its column is never
	## walked and it is never trimmed. Only mass overhanging a street is.
	if key.w >= FACE_DIRECTIONS.size():
		return false
	for band in range(key.y - 1, key.y - STONE_FACE_OVERHANG_BAND_REACH - 1, -1):
		if walked.has(Vector3i(key.x, band, key.z)):
			return true
	return false


static func maze_natural_face_overhung_band(key: Vector4i,
		walked: Dictionary) -> int:
	## The HIGHEST band below this panel's own course at which the public realm
	## walks THROUGH THE PANEL'S OWN MASS COLUMN -- the case the tail clamp
	## exists for, and the exact line between the two kinds of overhang.
	##
	## The test is on the MASS side, not the open side, and that is what makes
	## it surgical. A panel cladding an ordinary bank has mass under it all the
	## way down -- the bank continues, and each lower course wears its own
	## panel -- so its own column is never walked and its tail is never clamped:
	## a wall beside a path stays full height. A panel whose own column turns
	## into STREET a few courses down is mass that overhangs a street, and its
	## 4 m tail hangs into the space a body walks through.
	##
	## `key.y` itself is excluded: a panel level with the street is that
	## street's own wall. Returns the band, or `key.y` when nothing walks under
	## it, so callers read "overhung band < key.y" as the condition.
	if key.w >= FACE_DIRECTIONS.size():
		return key.y
	for band in range(key.y - 1, key.y - NATURAL_ROCK_CUT_BAND_REACH - 1, -1):
		if walked.has(Vector3i(key.x, band, key.z)):
			return band
	return key.y


static func maze_natural_face_rise_ceiling(key: Vector4i,
		walked: Dictionary) -> float:
	## How tall this panel's module may be before its tail hangs into a street
	## crossing its own boundary. `INF` when nothing crosses under it.
	var band := maze_natural_face_overhung_band(key, walked)
	if band >= key.y:
		return INF
	return (float(key.y + 1 - band) * FabricRecipe.CELL_SIZE \
		- NATURAL_ROCK_CUT_HEADROOM) / (NATURAL_ROCK_TOP + NATURAL_ROCK_BASE)


static func maze_natural_face_tail_is_clearable(key: Vector4i,
		walked: Dictionary) -> bool:
	## Can the tail be lifted clear at all, or does the crossing pass a corner
	## of mass at head height? The second is a ROUTING fact -- the plot model
	## put a street through a boundary whose upper course is solid -- and no
	## choice of cladding opens it, so it is published rather than papered over.
	return maze_natural_face_rise_ceiling(key, walked) \
		>= NATURAL_ROCK_CUT_MIN_RISE


static func _maze_cell_is_crossed(cell: Vector3i, walked: Dictionary) -> bool:
	if not walked.has(cell):
		return false
	for step: Vector3i in FACE_DIRECTIONS:
		if walked.has(cell + step):
			return true
	return false


static func maze_natural_cut_is_expressible() -> bool:
	## Can the cut be made by pulling the shard back, or does it need more
	## stand-off than the module's own relief range can express? Today it can:
	## the cut plane is 0.057 m behind nominal and relief reaches 0.22 m. This
	## is the guard for the day it cannot -- a wider body, a narrower cell, a
	## deeper module -- and the answer THEN is a mason's wall where the street
	## squeezes through the rock, which is also true vernacular, rather than a
	## rock face quietly left standing in a street a body cannot use.
	return NATURAL_ROCK_CUT_RELIEF >= -NATURAL_ROCK_RELIEF


static func _maze_cap_is_free(key: Vector4i, partner: Vector3i,
		exposed: Dictionary, walked: Dictionary) -> bool:
	## Does anybody WALK on either cell this sky-facing slab closes? The mate
	## is only asked when it is a capped cell in its own right: a partner that
	## is closed mass owns no cap, carries no surface, and cannot be walked.
	if walked.has(Vector3i(key.x, key.y + 1, key.z)):
		return false
	if partner == Vector3i.ZERO:
		return true
	var mate := Vector4i(key.x + partner.x, key.y + partner.y,
		key.z + partner.z, key.w)
	if not exposed.has(mate):
		return true
	return not walked.has(Vector3i(mate.x, mate.y + 1, mate.z))


static func walked_floor_cells(surface_plan: PublicRealmSurfacePlan) \
		-> Dictionary:
	## Every cell the public realm WALKS, over all five surface kinds.
	##
	## Deliberately a different question from `public_floor_cells`, which asks
	## "does something else already DRAW this boundary" and therefore names
	## only the three kinds that plank themselves. A terrain street and a stair
	## draw nothing at the top of the stone cell they run over -- which is
	## exactly why that cell keeps its stone cap -- but they are walked, and a
	## walked cap may not become lawn.
	##
	## The enum itself rather than a hand-kept list of five, because the
	## question is "is this cell part of the public realm at all" and every
	## SurfaceKind that exists answers yes by definition. A list here would be
	## a thing that goes stale silently the day a sixth kind is added, and the
	## failure would be lawn under a new kind of street.
	var out: Dictionary = {}
	if surface_plan == null:
		return out
	for kind in PublicRealmSurfacePlan.SurfaceKind.values():
		for cell: Vector3i in surface_plan.cells_for_kind(int(kind)):
			out[cell] = true
	return out


static func maze_stone_walls(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}) -> EnvironmentInstancePayload:
	## ONE module per panel of `maze_stone_faces`, and `maze_skin_treatments`
	## says which module. The panel set, its coursing and its cap pairing are
	## untouched by task H2b: this function chose one asset before and chooses
	## one of three now, so `maze_stone_expected_face_count` and
	## `maze_stone_rendered_face_count` mean exactly what they meant, and every
	## instance still carries the `maze-stone/x/y/z/w` id of the face it closes.
	##
	## MASONRY rides the same transform idiom `house_plinth_walls` uses for a
	## building's own plinth: a side panel hangs from the top of its cell and
	## buries its lower half in the course beneath, so a run of stone reads as
	## one coursed masonry mass. Top and bottom caps are that same module laid
	## flat -- the catalog ships no horizontal rock slab (every `sfv.*.rock.*`
	## piece is a 3 m upright), and C5b ruling 1 allows the plinth panel laid
	## flat rather than a new asset. The rotation puts the module's own rock
	## face toward the sky (or, for a passage roof, toward the floor) and sinks
	## it by STONE_CAP_HALF_DEPTH so that face is flush with the boundary it
	## closes.
	##
	## `walked` is `walked_floor_cells()` for the same plan and defaults to
	## empty, which makes every cap MASONRY -- the pre-H2b answer. A caller
	## that does not hold the surface plan therefore gets the old skin rather
	## than lawn under a street it could not see.
	var out := EnvironmentInstancePayload.new()
	var faces := maze_stone_faces(retained, solids, paved, plinths)
	var treatments := maze_skin_treatments(exposed_maze_stone_faces(retained,
		solids, paved), faces, walked)
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		var cell := Vector3i(key.x, key.y, key.z)
		var direction := STONE_FACE_DIRECTIONS[key.w]
		var partner := faces[key] as Vector3i
		var stable_id := StringName("maze-stone/%d/%d/%d/%d" % [key.x, key.y,
			key.z, key.w])
		match int(treatments[key]):
			SkinTreatment.GREEN:
				out.add(TERRAIN_GREEN_CAP,
					_maze_green_cap_transform(cell, partner), Color.WHITE,
					stable_id)
			SkinTreatment.NATURAL:
				out.add(NATURAL_ROCK_FACE,
					_maze_natural_face_transform(key, direction,
						maze_natural_face_is_cut(key, walked),
						maze_natural_face_rise_ceiling(key, walked)),
					Color.WHITE, stable_id)
			_:
				out.add(MAZE_STONE_MODULE,
					_maze_stone_transform(cell, direction, partner,
						maze_stone_face_overhangs_walk(key, walked)),
					Color.WHITE, stable_id)
	assert(out.validate())
	return out


static func _maze_green_cap_transform(cell: Vector3i,
		partner: Vector3i) -> Transform3D:
	## The grass quad laid over the pair its stone slab covered. Its long axis
	## is its own local +Z and it is centred on its origin, so the origin is
	## the CENTRE of the covered run -- the module's own geometry then reaches
	## half the run each way -- while the masonry slab it replaces is anchored
	## at one end and sweeps 3 m along its local +Y. Two modules, two honest
	## idioms; the covered cells are the same two.
	##
	## FIX 1, MINOR 2 -- AN UNPAIRED CAP IS TRIMMED TO ITS OWN CELL. It used to
	## keep the stone's own answer, a 3 m module centred on one 1.5 m cell,
	## overhanging the two neighbours it does not own by 0.75 m each way. What
	## that overhang is made of is the whole difference: a masonry slab reaching
	## over the void is a stone ledge, and the eye reads rock as a thing that
	## can corbel, but a grass quad reaching over the void is a sheet of lawn
	## with nothing under it -- two such caps a town, and two of their jut cells
	## open AIR. The long axis is now bounded exactly the way the cross axis
	## already is, so the quad covers the one cell it closes and no other.
	## `maze_green_cap_jut_cells` states the same fact as arithmetic and the
	## audit counts it.
	var axis := Vector3(partner) if partner != Vector3i.ZERO else Vector3.BACK
	var origin := Vector3(cell) * FabricRecipe.CELL_SIZE \
		+ Vector3(partner) * FabricRecipe.CELL_SIZE * 0.5
	origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_CAP_LIFT
	var basis := Basis(Vector3.UP, atan2(axis.x, axis.z))
	basis.x = basis.x * GREEN_CAP_CROSS_SCALE
	basis.z = basis.z * maze_green_cap_long_scale(partner)
	return Transform3D(basis, origin)


static func maze_green_rim_walls(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}) -> EnvironmentInstancePayload:
	## TASK H2b FIX 1, IMPORTANT 3 -- the rolled edge round every green bench.
	##
	## A RIM is a green-capped cell's own exposed SIDE: turf on top of it and a
	## drop beside it. That is exactly the pair of facts the shell already
	## carries, so nothing new is derived -- the cap's treatment says the top is
	## lawn, and the exposed side face says there is a fall there.
	##
	## Only a cell that is a capped cell IN ITS OWN RIGHT is dressed. A cap
	## paired with closed mass covers that mass too, but its rim there is buried
	## inside the thing it leans on and a piece would be geometry nobody sees.
	##
	## A SEPARATE PAYLOAD, not a fourth module inside `maze_stone_walls`: task
	## C5b's identity is one INSTANCE per panel of the shell, and a rim is not a
	## panel of the shell -- it dresses one. `maze_stone_expected_face_count`
	## and `_rendered_face_count` therefore still mean exactly what they meant,
	## and every rim carries a `maze-rim/` id that no reading of the skin
	## mistakes for a panel.
	var out := EnvironmentInstancePayload.new()
	var exposed := exposed_maze_stone_faces(retained, solids, paved)
	if exposed.is_empty():
		return out
	var faces := maze_stone_faces(retained, solids, paved, plinths)
	var treatments := maze_skin_treatments(exposed, faces, walked)
	var up_index := STONE_FACE_DIRECTIONS.find(Vector3i.UP)
	var depth_scale := FabricRecipe.CELL_SIZE / GREEN_RIM_DEPTH
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		if int(treatments[key]) != SkinTreatment.GREEN:
			continue
		var partner := faces[key] as Vector3i
		var covered: Array[Vector3i] = [Vector3i(key.x, key.y, key.z)]
		if partner != Vector3i.ZERO:
			covered.append(Vector3i(key.x, key.y, key.z) + partner)
		for cell: Vector3i in covered:
			if not exposed.has(Vector4i(cell.x, cell.y, cell.z, up_index)):
				continue
			for index in FACE_DIRECTIONS.size():
				if not exposed.has(Vector4i(cell.x, cell.y, cell.z, index)):
					continue
				out.add(GREEN_RIM_EDGE,
					_maze_green_rim_transform(cell, FACE_DIRECTIONS[index],
						depth_scale), Color.WHITE,
					StringName("maze-rim/%d/%d/%d/%d" % [cell.x, cell.y,
						cell.z, index]))
	assert(out.validate())
	return out


static func _maze_green_rim_transform(cell: Vector3i, direction: Vector3i,
		depth_scale: float) -> Transform3D:
	## The rolled edge laid along one cell of one bench rim, turned so its own
	## roll faces the drop -- the yaw `CliffDressing` gives the lip and the wall
	## alike, and the same yaw `_maze_natural_face_transform` gives the rock
	## below it, so turf and cliff face the same way by construction.
	##
	## Its depth is scaled to the cell and its origin pulled back by its own
	## scaled overhang, so the roll lands ON the boundary and the piece occupies
	## exactly the cell it dresses. Its length takes the quad's cross scale,
	## because both are the same authored 3 m terrain tile meeting the same
	## 1.5 m fabric cell. The DROP is never scaled: a rim that hangs a metre in
	## one place and half of one in the next is not a rim.
	var outward := Vector3(direction)
	var origin := Vector3(cell) * FabricRecipe.CELL_SIZE \
		+ outward * (FabricRecipe.CELL_SIZE * 0.5 - GREEN_RIM_FRONT \
			* depth_scale)
	origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_RIM_LIFT
	var basis := Basis(Vector3.UP, atan2(outward.x, outward.z))
	basis.x = basis.x * GREEN_CAP_CROSS_SCALE
	basis.z = basis.z * depth_scale
	return Transform3D(basis, origin)


static func maze_green_cap_long_scale(partner: Vector3i) -> float:
	## How much of the grass quad's authored 3 m long axis a cap really lays:
	## the whole of it over a PAIR, and one cell's worth over a cap that had
	## nothing beside it to pair with.
	return 1.0 if partner != Vector3i.ZERO else GREEN_CAP_CROSS_SCALE


static func maze_green_cap_jut_cells(cell: Vector3i,
		partner: Vector3i) -> Array[Vector3i]:
	## FIX 1, MINOR 2 -- the lattice cells a green quad reaches over that its
	## own panel does not own, derived from the two dials the transform is built
	## from rather than from the transform, so the audit and the payload cannot
	## drift apart silently.
	##
	## Zero for every cap since the trim above, and that is the point: the audit
	## publishes it, `test_a_green_cap_never_juts_past_the_bench_it_caps`
	## measures the same thing off the payload the renderer is handed, and the
	## pin is on the cells that jut over AIR -- a lawn sheet with nothing under
	## it, which is worse than the stone ledge it replaced.
	var out: Array[Vector3i] = []
	var axis := partner if partner != Vector3i.ZERO else Vector3i.BACK
	var cross := Vector3i(axis.z, 0, axis.x)
	var half_long := TERRAIN_MODULE_SPAN * 0.5 \
		* maze_green_cap_long_scale(partner)
	var half_cross := TERRAIN_MODULE_SPAN * 0.5 * GREEN_CAP_CROSS_SCALE
	var centre := (Vector3(cell) + Vector3(partner) * 0.5) \
		* FabricRecipe.CELL_SIZE
	var owned: Dictionary = {cell: true}
	if partner != Vector3i.ZERO:
		owned[cell + partner] = true
	# Both the quad and the cells are grid-aligned, so the overlap is two
	# interval tests. A cell that merely TOUCHES the quad's edge is not covered
	# by it -- that is exactly the paired cap's fit -- hence the tolerance.
	for along in range(-2, 3):
		for across in range(-2, 3):
			var probe := cell + axis * along + cross * across
			if owned.has(probe):
				continue
			var delta := Vector3(probe) * FabricRecipe.CELL_SIZE - centre
			if absf(delta.dot(Vector3(axis))) \
					< half_long + FabricRecipe.CELL_SIZE * 0.5 - 0.01 \
					and absf(delta.dot(Vector3(cross))) \
						< half_cross + FabricRecipe.CELL_SIZE * 0.5 - 0.01:
				out.append(probe)
	return out


static func _maze_natural_face_transform(face: Vector4i,
		direction: Vector3i, cut: bool, rise_ceiling: float) -> Transform3D:
	## FIX 2, MINOR 7: `cut` and `rise_ceiling` take no defaults. Their safe
	## values are the LOOSE ones -- no stand-off clamp, no tail clamp -- so a
	## caller that forgot them would get the pre-cut skin back and shut streets
	## quietly. `maze_stone_walls` is the one caller and passes both from
	## `maze_natural_face_is_cut` and `maze_natural_face_rise_ceiling`.
	##
	## The cliff face hung from the top of its own course, exactly as the
	## masonry panel is: its top edge lands on the course boundary and its
	## extra height buries itself in the mass below, so a bank's rim is where
	## the rock stops and the green cap begins.
	##
	## The module is handed -- its bulge stands in front of its origin -- so
	## unlike the symmetric masonry slab it takes a FOUR-way yaw that turns
	## its rock face outward, and its origin is pulled back by the bulge's own
	## half-depth so the rock straddles the boundary rather than standing a
	## metre out in the street.
	##
	## Everything else here is the seeded relief the constants above argue
	## for. The turn is a half turn about the OUTWARD axis, which mirrors the
	## shard and stands it on its head in one rotation; the module then hangs
	## from the 0.3 m that used to be its underside, which is why the pinned
	## top is written twice rather than once.
	var outward := Vector3(direction)
	var tangent := Vector3.BACK if direction.x != 0 else Vector3.RIGHT
	var turned := _face_noise(face, 0) < 0.5
	var rise := 1.0 + (_face_noise(face, 1) * 2.0 - 1.0) \
		* NATURAL_ROCK_RISE_JITTER
	# The tail clamp. Bounded below by the panel's own band coverage, so a
	# module can never be shortened into a slit that shows sky through the
	# mountain -- if the ceiling is under that floor the crossing is unclearable
	# and `maze_natural_face_tail_is_clearable` says so out loud.
	if rise_ceiling < rise:
		rise = maxf(rise_ceiling, NATURAL_ROCK_CUT_MIN_RISE)
	var cross := NATURAL_ROCK_CROSS_SCALE \
		+ (_face_noise(face, 2) * 2.0 - 1.0) * NATURAL_ROCK_CROSS_JITTER
	# TASK H2c FIX 1. `cut` is the panel standing where the street crosses, and
	# the clamp is a CEILING on how far its nose may lean into that crossing --
	# a panel already jittered behind the cut plane keeps its own roll, so the
	# face reads as rock cut back where the path passes and undisturbed rock
	# elsewhere, rather than as one flat dent.
	var relief := (_face_noise(face, 3) * 2.0 - 1.0) * NATURAL_ROCK_RELIEF
	if cut:
		relief = minf(relief, NATURAL_ROCK_CUT_RELIEF)
	var origin := Vector3(face.x, 0.0, face.z) * FabricRecipe.CELL_SIZE \
		+ outward * (FabricRecipe.CELL_SIZE * 0.5 \
			- NATURAL_ROCK_FACE_DEPTH_CENTRE + relief) \
		+ tangent * (_face_noise(face, 4) * 2.0 - 1.0) * NATURAL_ROCK_SLIDE
	origin.y = float(face.y + 1) * FabricRecipe.CELL_SIZE \
		- (NATURAL_ROCK_BASE if turned else NATURAL_ROCK_TOP) * rise
	var basis := Basis(Vector3.UP, atan2(outward.x, outward.z))
	if turned:
		basis = basis * Basis(Vector3.BACK, PI)
	basis.x = basis.x * cross
	basis.y = basis.y * rise
	return Transform3D(basis, origin)


static func _face_noise(face: Vector4i, salt: int) -> float:
	## A deterministic value in [0, 1) per panel per dial, through the same
	## splitmix64 avalanche every other seeded placement in this project uses.
	## A function of the PANEL and nothing else: the skin stays byte-identical
	## for identical input, and a town cannot roll different rock on a re-solve.
	return Helper._hash01(Helper._mix64(face.x ^ Helper._mix64(face.y \
		^ Helper._mix64(face.z ^ Helper._mix64(face.w ^ Helper._mix64(salt))))))


static func maze_terrace_crown_units(plan: SettlementFabricPlan) -> Dictionary:
	## The PLOT MODEL's own flat crowns, as `unit id -> true`, read from the
	## sealed plan's audit where `WarrenSpatialFabricCompiler.compile_roof_
	## units` published them: the `roof.flat.*` slab of every `flat_roof` room
	## stamp, plus the tiles that complete a partial one.
	##
	## REVIEW FIX 1, IMPORTANT 2 -- why the list and not a recipe tag. The
	## first pass selected any unit tagged `flat_roof`/`setback_cap` with
	## nothing bearing on it, which is a WIDER set than the plot-flat crowns:
	## it would rail the weather shoulder of a pitched house and double an
	## authored terrace rail. It was inert only because this corpus emits no
	## setback caps outside the tiling. The compiler knows which units are
	## crowns because it built them, and this file cannot re-derive it -- it
	## holds the fabric plan, not the room stamps that carry `flat_roof`.
	##
	## Empty for every legacy plan, which publishes no such key, which is what
	## keeps the whole terrace rule maze-only and every legacy payload
	## byte-identical.
	var out: Dictionary = {}
	if plan == null:
		return out
	for unit_value: Variant in plan.audit.get("maze_terrace_crown_unit_ids",
			[]) as Array:
		out[StringName(unit_value)] = true
	return out


static func maze_terrace_deck_cells(plan: SettlementFabricPlan,
		crown_unit_ids: Dictionary = {}) -> Dictionary:
	## TASK C5e RULING 3 -- which cells of this town are an OPEN FLAT CROWN,
	## as `cell -> unit id`.
	##
	## `crown_unit_ids` is `maze_terrace_crown_units(plan)` and defaults to it;
	## the compiler passes its own list explicitly because it audits this rule
	## before the plan is sealed.
	##
	## A crown unit's occupancy is read from BOTH the solid and the occluder
	## layer, because the authored thin plank cap that tiles a one-cell setback
	## strip claims its cells as occluder only (it is a weather face, not
	## mass).
	var out: Dictionary = {}
	if plan == null:
		return out
	var crowns := crown_unit_ids
	if crowns.is_empty():
		crowns = maze_terrace_crown_units(plan)
	if crowns.is_empty():
		return out
	for unit: FabricUnit in plan.units:
		if not crowns.has(unit.stable_id):
			continue
		var recipe := plan.recipe(unit.recipe_id)
		if recipe == null:
			continue
		var local_cells: Dictionary = {}
		for local_cell: Vector3i in recipe.solid_cells:
			local_cells[local_cell] = true
		for local_cell: Vector3i in recipe.occluder_cells:
			local_cells[local_cell] = true
		for local_value: Variant in local_cells.keys():
			out[FabricRecipe.transform_cell(local_value as Vector3i,
				unit.lattice_origin, unit.yaw_quarters)] = unit.stable_id
	return out


static func maze_terrace_edges(plan: SettlementFabricPlan,
		crown_unit_ids: Dictionary = {}) -> Dictionary:
	## TASK C5e RULING 3 -- the open edges of every flat crown, keyed
	## Vector4i(x, band, z, index into FACE_DIRECTIONS) and valued `true`.
	##
	## A crown cell owes a railing on a horizontal boundary whose neighbour AT
	## THE CROWN'S OWN BAND is open air. Four things close a boundary and each
	## of them is a real reason:
	##
	## * another crown cell -- the terrace simply continues;
	## * any other built solid -- the room stacked on this crown, the party
	##   wall of a taller neighbour, the next house's slab;
	## * retained stone -- a rock shoulder or a parapet somebody really kept;
	## * a public floor that PLANKS itself -- a deck, an interior passage or a
	##   bridge at this very band, which you step straight out onto.
	##
	## Everything else is a fall, including the swept headroom of a street
	## many bands below: that is the edge a railing exists for.
	var deck := maze_terrace_deck_cells(plan, crown_unit_ids)
	var out: Dictionary = {}
	if deck.is_empty():
		return out
	var solids := plan.transformed_cells(&"solid")
	var retained := plan.retained_terrace_cells
	var paved := public_floor_cells(plan.surface_plan)
	for cell_value: Variant in deck.keys():
		var cell := cell_value as Vector3i
		for index in FACE_DIRECTIONS.size():
			var neighbor := cell + FACE_DIRECTIONS[index]
			if deck.has(neighbor) or solids.has(neighbor) \
					or retained.has(neighbor) or paved.has(neighbor):
				continue
			out[Vector4i(cell.x, cell.y, cell.z, index)] = true
	return out


static func maze_terrace_railings(plan: SettlementFabricPlan,
		crown_unit_ids: Dictionary = {}) -> EnvironmentInstancePayload:
	## TASK C5e RULING 3 -- one authored railing per open crown edge, through
	## the same transform idiom `_append_guard_instances` uses for a public
	## deck's guard: the module stands ON the walk surface, centred on the
	## boundary, with its own local +X along the edge.
	##
	## The 3 m module spans TWO fine cells, so adjacent open edges in the same
	## plane are PAIRED and the pair emits one instance -- the same reasoning
	## that pairs the stone caps above, and what keeps a terrace edge reading
	## as one run of fence rather than as a row of 1.5 m panels each with its
	## own terminal posts. An odd leftover takes the authored 1.5 m module,
	## which is the same asset the public guards already use.
	##
	## A crown's walk surface is the BOTTOM of its own band: the authored flat
	## module is walk-aligned to local y = 0 and the unit stands at
	## `band * CELL_SIZE`, so the rail's base sits exactly on the planks.
	var out := EnvironmentInstancePayload.new()
	var edges := maze_terrace_edges(plan, crown_unit_ids)
	if edges.is_empty():
		return out
	var keys: Array[Vector4i] = []
	keys.assign(edges.keys())
	keys.sort_custom(_face_before)
	var paired: Dictionary = {}
	for key: Vector4i in keys:
		if paired.has(key):
			continue
		paired[key] = true
		var direction := FACE_DIRECTIONS[key.w]
		# The edge runs across its own normal; sweeping the sorted keys toward
		# the positive tangent makes the pairing deterministic.
		var tangent := Vector3i.BACK if direction.x != 0 else Vector3i.RIGHT
		var mate := Vector4i(key.x + tangent.x, key.y, key.z + tangent.z,
			key.w)
		var span := 0
		if edges.has(mate) and not paired.has(mate):
			paired[mate] = true
			span = 1
		var boundary := (Vector3(key.x, 0.0, key.z) \
			+ Vector3(direction) * 0.5) * FabricRecipe.CELL_SIZE
		var origin := boundary + Vector3(tangent) * FabricRecipe.CELL_SIZE \
			* 0.5 * float(span)
		origin.y = float(key.y) * FabricRecipe.CELL_SIZE
		out.add(PLANK_RAILING_MEDIUM if span == 1 else PLANK_RAILING,
			Transform3D(Basis(Vector3.UP, atan2(-float(tangent.z),
				float(tangent.x))), origin), Color.WHITE,
			StringName("maze-terrace-rail/%d/%d/%d/%d" % [key.x, key.y, key.z,
				key.w]))
	assert(out.validate())
	return out


static func _maze_stone_transform(cell: Vector3i, direction: Vector3i,
		partner: Vector3i, trimmed: bool) -> Transform3D:
	## `partner` is the neighbour a horizontal cap reaches over -- the module
	## laid flat spans two cells -- and is Vector3i.ZERO for a side panel and
	## for a cap centred on its own cell.
	##
	## `trimmed` takes no default (fix 2, minor 7): it decides how much wall
	## there is, and a caller that forgets it should not silently get the full
	## module back. `maze_stone_walls` is the one caller and passes
	## `maze_stone_face_overhangs_walk`.
	##
	## TASK H2c FIX 1 SUB-ROUND. `trimmed` is the coursed twin of the rock's
	## tail clamp, and it exists for the same defect in the same words: the
	## module is STONE_MODULE_HEIGHT tall cladding a 1.5 m band and "buries its
	## lower half in the course beneath", and where that course is an open
	## street it buries itself in the street instead. A panel two courses over a
	## walked cell hangs to `(band + 1) x CELL - 3.0`, which is 0.8 m inside the
	## headroom of a body standing down there -- so the coursing reads on, and
	## the street is shut by a wall nobody can see the bottom of.
	##
	## Trimmed, the module covers its own band EXACTLY: half height, re-anchored
	## so its top still lands on the course boundary.
	##
	## NOTHING OPENS ABOVE IT, and the reason is the anchor rather than any
	## neighbour (fix 2, minor 2 -- the first telling of this said a panel one
	## band up covered our band twice, which coursing makes impossible: panels
	## sit STONE_COURSE_BANDS apart, so a column with a panel at y has none at
	## y + 1). The trim moves the module's BOTTOM edge only; its top stays
	## anchored at `(y + 1) x CELL_SIZE`, which is the course boundary the panel
	## above it, if any, hangs from. The seam is where it always was.
	##
	## BELOW IT, THE CLAIM IS TRUE AT g = 1 AND CONTINGENT AT g = 2 (fix 2,
	## important 1). `maze_stone_face_overhangs_walk` fires on a walked cell one
	## or two bands down, and the panel clads the course {y, y - 1}:
	##
	## * g = 1 -- band y - 1 IS the walked street, so it carries no exposed face
	##   and the course is one band. The only overlap the trim gives up is with
	##   open air. Unconditionally sound.
	## * g = 2 -- band y - 1 could be stone whose face is exposed and paired
	##   into this course, and the trim would leave the whole of it bare. It
	##   cannot be, while `blocked = 0`: stone directly over the walked cell at
	##   band y - 2 wears a floor-facing masonry cap flush with that cell's
	##   ceiling, and the cell is 1.5 m against a 2.334 m body, so the capsule
	##   is stopped at every offset and the cell counts `blocked`. THE CASE THAT
	##   FIRED IS THIS ONE -- both 6/standard blockers are band-2 panels over a
	##   street at band 0 -- so the dependency is not hypothetical. The same
	##   argument, in full, is at `NATURAL_ROCK_CUT_MIN_RISE`.
	var lattice := Vector3(cell) * FabricRecipe.CELL_SIZE
	if direction.y == 0:
		var height := FabricRecipe.CELL_SIZE if trimmed else STONE_MODULE_HEIGHT
		var midpoint := Vector3(lattice.x, 0.0, lattice.z) \
			+ Vector3(direction) * FabricRecipe.CELL_SIZE * 0.5
		midpoint.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE - height
		var basis := Basis(Vector3.UP,
			PI * 0.5 if direction.x != 0 else 0.0)
		if trimmed:
			# FIX 2, MINOR 1 -- WHAT THIS 0.5 IS AND IS NOT. A trimmed panel's
			# `basis.y.y` lands on exactly 0.5, and two readers in this repo
			# threshold on that number in OPPOSITE directions:
			#
			# * `tallest_bare_stone_stack_bands` skips `basis.y.y < 0.5` as
			#   "laid flat", so 0.5 survives the filter -- but it then requires
			#   `_is_assembler_stone`, which accepts only `house-plinth/` and
			#   `retaining-wall/` ids. A maze skin panel is `maze-stone/`, so it
			#   was NEVER counted by that reader, trimmed or not. The earlier
			#   note here claimed the trim kept it in the stone budget; it was
			#   never in it. The maze skin's own budget is `maze_bank_height`
			#   against STONE_BUDGET_BANDS, published as the tall/low face
			#   counts and `maze_tall_bank_masonry_panel_count`, and the trim
			#   moves a transform rather than a treatment so none of them move.
			# * `test_warren_production_surfaces.gd` asserts `basis.y.y > 0.5`
			#   STRICTLY -- 0.5 would fail it -- but it reads
			#   `house_plinth_walls`, which this function does not emit into.
			#
			# So the landmine is real but neither reader is armed today. What
			# would arm the first is a trimmed panel appearing under a
			# `retaining-wall/` id; what would arm the second is the plinth
			# channel gaining a trim of its own. Anything that shortens this
			# further, or lends the trim to another channel, has to revisit both.
			basis.y = basis.y * (height / STONE_MODULE_HEIGHT)
		return Transform3D(basis, midpoint)
	var half := Vector3(partner) * FabricRecipe.CELL_SIZE * 0.5
	var span := STONE_MODULE_HEIGHT if direction == Vector3i.UP \
		else -STONE_MODULE_HEIGHT
	var basis := Basis(Vector3.RIGHT, -PI * 0.5 * signf(span))
	if partner.x != 0:
		basis = Basis(Vector3.UP, PI * 0.5) * basis
	var origin := lattice + half
	origin.y = float(cell.y + int(direction == Vector3i.UP)) \
		* FabricRecipe.CELL_SIZE \
		- STONE_CAP_HALF_DEPTH * signf(span)
	if partner.x != 0:
		origin.x += span * 0.5
	else:
		origin.z += span * 0.5
	return Transform3D(basis, origin)


static func _maze_stone_cap_partner(key: Vector4i, exposed: Dictionary,
		paired: Dictionary, retained: Dictionary,
		solids: Dictionary) -> Vector3i:
	## Which neighbour this cap slab reaches over, in the fixed
	## STONE_CAP_PARTNERS order. First choice is an exposed cap cell that has
	## no slab of its own yet: that is the PAIR, and it is why one slab serves
	## two cells instead of two slabs serving one each. `paired` is written
	## through -- a mate this returns is spoken for and will not emit again.
	## Failing that, the slab leans over closed mass (stone, plinth or
	## building), which owns no cap of its own here and therefore cannot be
	## covered twice; an isolated cap with neither is centred on its own cell.
	for partner: Vector3i in STONE_CAP_PARTNERS:
		var mate := Vector4i(key.x + partner.x, key.y + partner.y,
			key.z + partner.z, key.w)
		if exposed.has(mate) and not paired.has(mate):
			paired[mate] = true
			return partner
	var cell := Vector3i(key.x, key.y, key.z)
	for partner: Vector3i in STONE_CAP_PARTNERS:
		var neighbor := cell + partner
		if exposed.has(Vector4i(neighbor.x, neighbor.y, neighbor.z, key.w)):
			continue
		if retained.has(neighbor) or solids.has(neighbor):
			return partner
	return Vector3i.ZERO


static func _plinth_covers(plinths: Dictionary, face: Vector4i) -> bool:
	## Is this boundary already closed by a building's plinth panel? A plinth
	## panel is 3 m tall and hangs from the top of its own cell, so it covers
	## its band and the one below. It may be keyed from either side of the
	## plane it stands in -- from the cell itself, or from the cell across the
	## boundary facing back -- and the stone skin must defer to it in both
	## cases or the two modules intersect (fix 1, IMPORTANT 2).
	if plinths.is_empty():
		return false
	if plinths.has(face):
		return true
	var direction := FACE_DIRECTIONS[face.w]
	return plinths.has(Vector4i(face.x + direction.x, face.y,
		face.z + direction.z, face.w + 1 - 2 * (face.w % 2)))


static func public_floor_cells(surface_plan: PublicRealmSurfacePlan) \
		-> Dictionary:
	## Every cell a public floor PLANKS. Used only to keep a stone cap out from
	## under a floor that draws itself.
	##
	## TASK C5b FIX 1, IMPORTANT 4: three of the five surface kinds, not all
	## five. `production_surface_payload` planks STRUCTURAL_COURT,
	## INTERIOR_PASSAGE and BRIDGE; TERRAIN_STREET is worn-path paint on the
	## real terrain mesh, which in a maze town lies BELOW the retained stone,
	## and STAIR is a generated transition mesh. Neither draws anything at the
	## stone cell's own top boundary, so suppressing the cap there left the
	## mountain open to the sky under a street.
	var out: Dictionary = {}
	if surface_plan == null:
		return out
	for kind in PAVED_FLOOR_KINDS:
		for cell: Vector3i in surface_plan.cells_for_kind(kind):
			out[cell] = true
	return out


static func _column_is_covered(origin: Vector3,
		covered_columns: Dictionary) -> bool:
	## A wall module sits ON a cell boundary, half a cell out from the cell it
	## retains, so it belongs to BOTH adjacent columns. If a building stands over
	## either one, the stone is read against that building.
	if covered_columns.is_empty():
		return false
	var x := origin.x / FabricRecipe.CELL_SIZE
	var z := origin.z / FabricRecipe.CELL_SIZE
	for column_x: int in [floori(x), ceili(x)]:
		for column_z: int in [floori(z), ceili(z)]:
			if covered_columns.has(Vector2i(column_x, column_z)):
				return true
	return false


static func _is_assembler_stone(stable_id: String) -> bool:
	## Rock this file placed, as opposed to a rock module inside a house recipe.
	## The asset ids overlap, so provenance lives in the stable id.
	##
	## `maze-stone/` is deliberately absent: the maze skin is measured by its own
	## budget (`maze_bank_height` against STONE_BUDGET_BANDS, published as the
	## tall/low bank face counts), not by this round-3b stack reader. See the
	## trim note in `_maze_stone_transform` for what that means for the 0.5
	## upright threshold below.
	return stable_id.begins_with("house-plinth/") \
		or stable_id.begins_with("retaining-wall/")


static func tallest_bare_stone_stack_bands(payload: EnvironmentInstancePayload,
		covered_columns: Dictionary = {}) -> int:
	## Measures the round-3b budget: the tallest run of contiguous bands of BARE
	## stone -- rock this assembler placed on a column no building stands over.
	## Substrate under a house is read against that house and is deliberately
	## exempt (the reviewer wants the mountain the town is draped on); an
	## uncovered face is a uniform masonry field and may not exceed
	## STONE_BUDGET_BANDS.
	##
	## `covered_columns` is a set of Vector2i lattice columns a building
	## occupies -- see building_ceiling. Recipe facades are excluded outright:
	## a house's own wall is a building, which is exactly what the town is
	## supposed to be made of.
	##
	## A module is 3 m wide but the plinth lattice is offset half a cell from the
	## room lattice, so width is resolved in 0.75 m slots; two modules that
	## overlap laterally at all count as the same face.
	var planes: Dictionary = {}
	for asset_id: StringName in STONE_FACADE_ASSETS:
		var batch := payload.batches.get(asset_id, {}) as Dictionary
		var ids: Array = batch.get("ids", [])
		var transforms: Array = batch.get("transforms", [])
		for order in transforms.size():
			var placement := transforms[order] as Transform3D
			if placement.basis.y.y < 0.5 \
					or not _is_assembler_stone(String(ids[order])) \
					or _column_is_covered(placement.origin, covered_columns):
				continue
			var yaw_index := posmod(roundi(placement.basis.get_euler().y
				/ (PI * 0.5)), 2)
			var plane := placement.origin.z if yaw_index == 0 \
				else placement.origin.x
			var tangent := placement.origin.x if yaw_index == 0 \
				else placement.origin.z
			var base_band := roundi(placement.origin.y / FabricRecipe.CELL_SIZE)
			var first_slot := roundi((tangent - 1.5) / 0.75)
			for slot in 4:
				var key := Vector3i(yaw_index, roundi(plane / 0.75),
					first_slot + slot)
				if not planes.has(key):
					planes[key] = {}
				(planes[key] as Dictionary)[base_band] = true
				(planes[key] as Dictionary)[base_band + 1] = true
	var tallest := 0
	for key_value: Variant in planes.keys():
		var bands: Array = (planes[key_value] as Dictionary).keys()
		bands.sort()
		var index := 0
		while index < bands.size():
			var last := index
			while last + 1 < bands.size() \
					and int(bands[last + 1]) == int(bands[last]) + 1:
				last += 1
			tallest = maxi(tallest, last - index + 1)
			index = last + 1
	return tallest


static func _cell_before(left: Vector3i, right: Vector3i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	if left.z != right.z:
		return left.z < right.z
	return left.x < right.x


static func _face_before(left: Vector4i, right: Vector4i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	if left.z != right.z:
		return left.z < right.z
	if left.x != right.x:
		return left.x < right.x
	return left.w < right.w


static func _column_is_occupied_below(plan: SettlementFabricPlan,
		solids: Dictionary, top: Vector3i) -> bool:
	for y in range(0, top.y):
		var cell := Vector3i(top.x, y, top.z)
		if solids.has(cell) or plan.surface_plan.has_cell(cell):
			return true
	return false


static func surface_visual_payload(plan: PublicRealmSurfacePlan) \
		-> EnvironmentInstancePayload:
	## The continuous union remains the sole collision authority. Reviewed
	## fixed-size plank meshes tile structural portions of that union without
	## scaling an asset or allowing independently placed decks to define
	## connectivity. The generated structural skin is deliberately not rendered.
	var out := EnvironmentInstancePayload.new()
	if plan == null or not plan.is_sealed():
		return out
	var courtyard_cells := plan.cells_owned_by_prefix("volume.courtyard.")
	var courtyard_set := _cell_set(courtyard_cells)
	for kind in [PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
			PublicRealmSurfacePlan.SurfaceKind.BRIDGE]:
		var cells := plan.cells_for_kind(kind)
		if kind == PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			cells = _without_cells(cells, courtyard_set)
		_append_plank_tiles(out, cells, int(kind))
	_append_courtyard_paving(out, courtyard_cells, plan)
	_append_guard_instances(out, plan.guard_segments)
	assert(out.validate())
	return out


static func production_surface_payload(plan: PublicRealmSurfacePlan) \
		-> EnvironmentInstancePayload:
	## Streaming cannot commit the review harness' generated ArrayMesh from a
	## worker payload.  Tile the *same sealed surface union* with collision-
	## bearing fixed modules instead.  This is deliberately a second adapter,
	## not a second topology. Ground streets are NOT planked: they keep the
	## worn-path paint on real terrain, so the lower town reads as dirt paths
	## carved between building masses; timber belongs to genuinely structural
	## surfaces only.
	var out := EnvironmentInstancePayload.new()
	if plan == null or not plan.is_sealed():
		return out
	var courtyard_cells := plan.cells_owned_by_prefix("volume.courtyard.")
	var courtyard_set := _cell_set(courtyard_cells)
	for kind in [PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
			PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE,
			PublicRealmSurfacePlan.SurfaceKind.BRIDGE]:
		var cells := plan.cells_for_kind(kind)
		if kind == PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			cells = _without_cells(cells, courtyard_set)
		_append_plank_tiles(out, cells, int(kind))
	_append_courtyard_paving(out, courtyard_cells, plan)
	_append_guard_instances(out, plan.guard_segments)
	assert(out.validate())
	return out


static func _append_guard_instances(out: EnvironmentInstancePayload,
		segments: Array[Dictionary]) -> void:
	## Two short guard segments may meet on the centreline of a generated 3 m
	## doorway. Their collision-authoritative plan marks that exact shared point;
	## render the pair as one baked 3 m fence so it retains endpoint posts without
	## doubling a post in front of the door.
	var used: Dictionary = {}
	for index in segments.size():
		if used.has(index):
			continue
		var segment := segments[index]
		var asset_id := PLANK_RAILING
		var a := segment.a as Vector3
		var b := segment.b as Vector3
		var stable_key := String(segment.stable_key)
		if segment.has("visual_join_point"):
			var join := segment.visual_join_point as Vector3
			for other_index in range(index + 1, segments.size()):
				if used.has(other_index):
					continue
				var other := segments[other_index]
				if not other.has("visual_join_point") \
						or not (other.visual_join_point as Vector3) \
							.is_equal_approx(join):
					continue
				var first_outer := b if a.is_equal_approx(join) else a
				var other_a := other.a as Vector3
				var other_b := other.b as Vector3
				var second_outer := other_b \
					if other_a.is_equal_approx(join) else other_a
				if not is_equal_approx(first_outer.distance_to(second_outer),
						FabricRecipe.CELL_SIZE * 2.0):
					continue
				a = first_outer
				b = second_outer
				asset_id = PLANK_RAILING_MEDIUM
				var keys := PackedStringArray([stable_key,
					String(other.stable_key)])
				keys.sort()
				stable_key = "+".join(keys)
				used[other_index] = true
				break
		var delta := b - a
		var expected_length := FabricRecipe.CELL_SIZE * 2.0 \
			if asset_id == PLANK_RAILING_MEDIUM else FabricRecipe.CELL_SIZE
		assert(is_equal_approx(delta.length(), expected_length))
		var yaw := atan2(-delta.z, delta.x)
		out.add(asset_id, Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5),
			Color.WHITE, StringName("public-guard/%s" % stable_key))
		used[index] = true


static func production_surface_bundle(plan: PublicRealmSurfacePlan) \
		-> EnvironmentInstancePayload:
	## Production adapter: plank instances plus the sealed plan's generated
	## stair/ramp meshes in one streamable payload. Patch skins stay review
	## diagnostics; only collision-bearing transition geometry may stream, so a
	## STAIR claim can never remain an invisible hole between plank runs.
	var out := production_surface_payload(plan)
	if plan == null or not plan.is_sealed():
		return out
	for mesh: Dictionary in plan.mesh_payloads:
		if not bool(mesh.get("is_transition", false)):
			continue
		var entry := mesh.duplicate(true)
		var claim_cells := entry.get("claim_cells", []) as Array
		assert(not claim_cells.is_empty())
		var first_cell := claim_cells[0] as Vector3i
		entry["anchor"] = (Vector3(first_cell) + Vector3(0.5, 0.0, 0.5)) \
			* FabricRecipe.CELL_SIZE
		entry["stable_id"] = StringName("public-transition/%s" \
			% StringName(mesh.get("stable_id", "")))
		out.add_surface_mesh(entry)
	assert(out.validate())
	return out


static func _append_plank_tiles(out: EnvironmentInstancePayload,
		cells: Array[Vector3i], kind: int) -> void:
	var pending: Dictionary = {}
	for cell: Vector3i in cells:
		pending[cell] = true
	for cell: Vector3i in cells:
		if not pending.has(cell):
			continue
		var east := cell + Vector3i.RIGHT
		var south := cell + Vector3i.BACK
		var southeast := east + Vector3i.BACK
		if pending.has(east) and pending.has(south) and pending.has(southeast):
			_add_plank_tile(out, PLANK_FLOOR,
				Vector3(cell) + Vector3(0.5, 0.0, 0.5), 0, kind)
			pending.erase(cell)
			pending.erase(east)
			pending.erase(south)
			pending.erase(southeast)
		elif pending.has(east):
			_add_plank_tile(out, PLANK_GALLERY,
				Vector3(cell) + Vector3(0.5, 0.0, 0.0), 0, kind)
			pending.erase(cell)
			pending.erase(east)
		elif pending.has(south):
			_add_plank_tile(out, PLANK_GALLERY,
				Vector3(cell) + Vector3(0.0, 0.0, 0.5), 1, kind)
			pending.erase(cell)
			pending.erase(south)
		else:
			# The reviewed 1.5 m deck module closes odd residual cells without
			# scaling a 3 m floor or exposing the plain diagnostic underlay. Its
			# authored pivot lies on the local +X seam; _add_plank_tile() corrects
			# that pivot after receiving the logical cell centre.
			_add_plank_tile(out, PLANK_SINGLE,
				Vector3(cell) + Vector3(0.5, 0.0, 0.5), 0, kind)
			pending.erase(cell)


static func _append_courtyard_paving(out: EnvironmentInstancePayload,
		cells: Array[Vector3i], plan: PublicRealmSurfacePlan) -> void:
	## The elevated 6 m court stays timber-supported, but a checker of cool and
	## warm weathered boards plus two edge planters separates it visually from
	## through-galleries and broad roof decks. Every module still tiles the same
	## collision-authoritative surface claim; this is identity, not an
	## independently inferred platform. The centre remains a clear 4 m room.
	if cells.is_empty():
		return
	for cell: Vector3i in cells:
		var yaw := posmod(cell.x + cell.z, 2)
		_add_plank_tile(out, PLANK_SINGLE,
			Vector3(cell) + Vector3(0.5, 0.0, 0.5), yaw,
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
			Color("b9c1b8") if yaw == 0 else Color("c8b79d"))
	# Select actual supported perimeter cells rather than corners of the court's
	# AABB. Compact towns can form L/T-shaped roof courts; the old rectangle
	# shortcut could put the second planter over a missing corner. A corner is
	# eligible only when two perpendicular sides leave the complete public-surface
	# union. This also keeps a planter away from the exact route seam, whose
	# neighboring public cell makes that side non-exposed.
	var corner_cells: Array[Vector3i] = []
	for cell: Vector3i in cells:
		var exposed: Array[Vector3i] = []
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if plan == null or not plan.has_cell(cell + direction):
				exposed.append(direction)
		var has_corner := false
		for first: Vector3i in exposed:
			for second: Vector3i in exposed:
				has_corner = has_corner or first.x * second.x \
					+ first.z * second.z == 0
		if has_corner:
			corner_cells.append(cell)
	if corner_cells.size() < 2:
		corner_cells.assign(cells)
	corner_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _cell_before(a, b))
	var first_cell := corner_cells[0]
	var second_cell := corner_cells[1] if corner_cells.size() > 1 \
		else corner_cells[0]
	var best_distance := -1
	for first_index in corner_cells.size():
		for second_index in range(first_index + 1, corner_cells.size()):
			var a := corner_cells[first_index]
			var b := corner_cells[second_index]
			var distance := absi(a.x - b.x) + absi(a.z - b.z)
			if distance > best_distance:
				best_distance = distance
				first_cell = a
				second_cell = b
	var planter_cells: Array[Vector3i] = [first_cell, second_cell]
	for index in planter_cells.size():
		var cell := planter_cells[index]
		var planter_position := (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) \
			* FabricRecipe.CELL_SIZE + Vector3.UP * 0.04
		out.add(COURTYARD_PLANTER,
			Transform3D(Basis(Vector3.UP, float(index) * PI),
				planter_position), Color.WHITE,
			StringName("courtyard-planter/%d/%d/%d/%d" % [cell.x,
				cell.y, cell.z, index]))


static func _cell_set(cells: Array[Vector3i]) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in cells:
		out[cell] = true
	return out


static func _without_cells(cells: Array[Vector3i], excluded: Dictionary) \
		-> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for cell: Vector3i in cells:
		if not excluded.has(cell):
			out.append(cell)
	return out


static func _add_plank_tile(out: EnvironmentInstancePayload,
		asset_id: StringName, lattice_center: Vector3, yaw_quarters: int,
		kind: int, color := Color.WHITE) -> void:
	var world_origin := lattice_center * FabricRecipe.CELL_SIZE
	world_origin.y += PLANK_Y_OFFSET
	var basis := Basis(Vector3.UP, float(yaw_quarters) * PI * 0.5)
	if asset_id == PLANK_SINGLE:
		world_origin += basis * Vector3(FabricRecipe.CELL_SIZE * 0.5, 0, 0)
	var transform := Transform3D(basis, world_origin)
	var stable_id := StringName("public-surface/%d/%d/%d/%d/%s" % [kind,
		roundi(lattice_center.x * 2.0), roundi(lattice_center.y * 2.0),
		roundi(lattice_center.z * 2.0), asset_id])
	out.add(asset_id, transform, color, stable_id)


static func _commit_surfaces(parent: Node3D, plan: PublicRealmSurfacePlan,
		include_collision: bool) -> Dictionary:
	assert(plan != null and plan.is_sealed())
	var root := Node3D.new()
	root.name = "PublicRealmSurfaces"
	parent.add_child(root)
	var collision_body: StaticBody3D
	if include_collision:
		collision_body = StaticBody3D.new()
		collision_body.name = "PublicRealmCollision"
		root.add_child(collision_body)
	var triangle_count := 0
	var collision_piece_count := 0
	var payloads: Array[Dictionary] = []
	payloads.assign(plan.mesh_payloads)
	if not plan.guard_mesh_payload.is_empty():
		payloads.append(plan.guard_mesh_payload)
	for payload: Dictionary in payloads:
		var vertices := payload.vertices as PackedVector3Array
		var indices := payload.indices as PackedInt32Array
		if vertices.is_empty() or indices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = payload.normals as PackedVector3Array
		arrays[Mesh.ARRAY_TEX_UV] = payload.uvs as PackedVector2Array
		arrays[Mesh.ARRAY_INDEX] = indices
		var kind := int(payload.kind)
		# Structural courts, bridges, and guards are completely covered by the
		# reviewed authored plank/rail payload above. Rendering their generated
		# collision underlay through the gaps between boards produced the dark,
		# rectangular "platform texture" seen in review captures. Keep the exact
		# union as collision authority, but do not draw that duplicate skin.
		var render_underlay := renders_generated_surface_underlay(kind)
		var instance_name := "Surface_%s" % _surface_kind_name(kind)
		if render_underlay:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, _surface_material(kind))
			var instance := MeshInstance3D.new()
			instance.name = instance_name
			instance.mesh = mesh
			root.add_child(instance)
		triangle_count += indices.size() / 3
		if include_collision:
			var faces := payload.collision_faces as PackedVector3Array
			if not faces.is_empty():
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(faces)
				var shape_node := CollisionShape3D.new()
				shape_node.name = "%sCollision" % instance_name
				shape_node.shape = shape
				collision_body.add_child(shape_node)
				collision_piece_count += 1
	return {
		"triangle_count": triangle_count,
		"collision_piece_count": collision_piece_count,
	}


static func renders_generated_surface_underlay(kind: int) -> bool:
	## Authored plank modules completely cover structural courts and bridges.
	## Their generated union remains collision authority but must not peek
	## through board seams as a dark duplicate skin. Guards likewise have no
	## horizontal diagnostic underlay.
	return kind != PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT \
		and kind != PublicRealmSurfacePlan.SurfaceKind.BRIDGE and kind != -1


static func _surface_material(kind: int) -> Material:
	# Surface union UVs are world-continuous and must not sample a source asset's
	# atlas as though they were authored mesh UVs. Deliberate flat materials keep
	# closure readable now; a future dedicated tiling plank material can replace
	# this without changing topology or geometry.
	if kind == PublicRealmSurfacePlan.SurfaceKind.STAIR:
		return _transition_plank_material()
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET:
			# Ground streets are diagnostic dirt in the isolated review scene, not
			# timber platforms. Lit like every neighbouring surface so review
			# captures show the same light/shadow the streamed town has.
			material.albedo_color = Color("cbb584")
		PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE:
			material.albedo_color = Color("765b3b")
		PublicRealmSurfacePlan.SurfaceKind.BRIDGE:
			material.albedo_color = Color("9a7044")
		-1:
			material.albedo_color = Color("69472c")
		_:
			material.albedo_color = Color("a98050")
	return material


static func _transition_plank_material() -> Material:
	## Ramps and stair flights are one continuous generated collision surface, so
	## fixed horizontal deck meshes cannot represent them. A world-stable board
	## pattern gives that exact sloped surface a deliberate timber finish without
	## stretching an asset or letting render geometry redefine traversal.
	## The swatch pair matches the SFV plank atlas, alternating per board, with a
	## muted seam instead of a near-black groove. The constants are authored as
	## sRGB display colours, but ALBEDO is a linear-light input: writing them raw
	## desaturated every transition to ivory ("white walkways"), so they pass
	## through srgb_to_linear first. Boards are lit like the plank assets around
	## them; the old near-black lit look was the (since fixed) top-face winding.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

vec3 srgb_to_linear(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

void fragment() {
	vec2 board_uv = UV * vec2(3.0, 2.0);
	vec2 within = fract(board_uv);
	float seam = max(step(0.94, within.x), step(0.94, within.y));
	float alternate = mod(floor(board_uv.x) + floor(board_uv.y), 2.0);
	vec3 board_a = srgb_to_linear(vec3(0.718, 0.549, 0.361));
	vec3 board_b = srgb_to_linear(vec3(0.647, 0.494, 0.325));
	vec3 timber = mix(board_a, board_b, alternate);
	ALBEDO = mix(timber, srgb_to_linear(vec3(0.51, 0.38, 0.25)), seam);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _surface_kind_name(kind: int) -> String:
	match kind:
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET:
			return "TerrainStreet"
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			return "StructuralCourt"
		PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE:
			return "InteriorPassage"
		PublicRealmSurfacePlan.SurfaceKind.BRIDGE:
			return "Bridge"
		-1:
			return "DerivedGuards"
		_:
			return "Unknown"
