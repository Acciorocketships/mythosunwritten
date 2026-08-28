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
## How far over the court's own lattice plane the edge planter stands, and how
## tall it is (`sfv_fabric_planter_003.tres`, AABB y 0 -> 0.927858). Both were
## literals inside `_append_courtyard_paving`; task I4 round 6 needs the rise as
## well, because a channel that never measured what it stood in front of now
## does.
const COURTYARD_PLANTER_LIFT := 0.04
const COURTYARD_PLANTER_RISE := 0.927858
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
## TASK I4, ANNOTATION 1 -- "sometimes the grass overhangs, and sometimes it
## disappears", and THIS CONSTANT IS THE WHOLE OF IT.
##
## The rim used to land on the lattice BOUNDARY, always. But the two modules that
## clad a garden's drop do not stand in the same plane, and the difference is
## measured rather than guessed:
##
## * the coursed masonry panel STRADDLES its boundary -- `_maze_stone_transform`
##   puts the module's origin on the boundary plane and the piece is 0.664 m
##   deep, so its outer face stands STONE_CAP_HALF_DEPTH = 0.332 m PROUD of it;
## * the timber facade panel is pinned by its outer face TO the boundary
##   (`_maze_facade_transform`), so it stands 0.000 m proud.
##
## A rim at the boundary is therefore BURIED behind a masonry face -- the turf
## reads as paint on top of a stone box, which is "sometimes it disappears" --
## and hangs its full 0.705 m roll proud of a flat timber face, which is
## "sometimes the grass overhangs". One lawn, two edges, and neither of them the
## edge a bank of turf really has.
##
## The rim now takes the stand-off of the panel UNDER it, so its roll lands on
## that panel's own outer face whatever the panel is made of. The turf turns the
## rim in the same plane everywhere, and it never reaches past the thing it caps:
## the stand-off is exactly the proud-ness of a module that is already there, so
## nothing new occupies the cell in front of it.
##
## ROUND-2 CORRECTION -- AND THAT ARGUMENT STANDS ALONE, WHICH IS THE OPPOSITE
## OF WHAT THE FIRST TELLING SAID. It finished "and the corpus clearance row is
## the measurement that says so". That is not true and cannot be:
## `kaykit.cliff.lip` BAKES NO COLLIDER -- its descriptor declares zero pieces,
## its provenance names no collision source, and `test_the_hillside_pushes_back`
## both states the ruling and checks it (`bare_rims == rims`, because a body on
## a rim stands on the CAP three centimetres under it). The clearance row asks
## the physics server, so it is blind to every rim in the corpus.
##
## THE FAILURE MODE IS THEREFORE SILENT, not loud. This stand-off is the coursed
## panel's own proud-ness -- 0.33194 m by `sfv_fabric_wall_rock_plain_001`'s
## measured 0.66389 m depth, and task I2 already recorded that the panel's own
## clearance holds by about a millimetre. A re-bake that deepened the module
## would push the PANEL past the gate and turn the clearance row red, which is
## the loud half; it would push this turf lip the same distance into the same
## street and NOTHING would go red, because there is no collider there to be
## measured. What keeps the rim honest is the geometry above -- it reaches
## exactly as far as the panel already standing there and not one millimetre
## further -- and, since round 2, `test_the_rim_stands_off_the_panel_it_caps`,
## which measures the laid transform against the panel the payload really put
## under it. That test is the only guard this constant has.
const GREEN_RIM_MASONRY_STANDOFF := STONE_CAP_HALF_DEPTH
const GREEN_RIM_FACADE_STANDOFF := 0.0
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
##
## TASK I1 -- THE PREMISE WENT FALSE, AND WAS PUT BACK RATHER THAN PAID FOR.
## This is the history, because a proof standing on a measurement should carry
## the day that measurement moved. Task I1 halved every footprint and its first
## 48-town matrix measured `blocked = 3`: three walked cells in three towns
## admitting no capsule, which is exactly the condition written above. The floor
## was NOT raised to 0.75. The three cells were read one at a time
## (`i1f1/probe-before.log`) and not one of them was the g = 2 configuration
## this proof rules out -- in all three the module in the street was a
## HORIZONTAL cap oversailing its own run, a defect on an axis neither clamp
## looked at. Extending the trim machinery to that axis
## (`maze_stone_cap_juts_over_walk`) took all three cells and all four of their
## shut crossings back to free, and the matrix measures `blocked = 0` again.
##
## So the premise is measured-true on the shipped tree, by the same corpus and
## the same physics query it was true by before -- and it is now true with one
## more mechanism holding it up rather than one fewer. The contingency above
## still stands for the next time.
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
##
## TASK I4 ROUND 5, ITEM 4 -- AND THIS CONSTANT IS NOT THE "gaps between the
## grass textures", WHICH IS WHY IT IS UNCHANGED. The plates themselves tile the
## lattice exactly and that is measured three ways: the module's mesh is a flat
## 4 x 4 grid spanning -1.5 to +1.5 with no bevel and no inset (16 vertices, 18
## triangles); inflating every plate by 8 per cent leaves the lines exactly where
## they were; and the transforms abut to the micron by construction. What the
## lines really are is named in the round-5 report -- a BUILDING UNIT's own floor
## board, 0.161 m thick, standing with its base ON the lawn's plane one band up,
## so it lies over the turf rather than beside it. Lifting the quad to hide it
## was tried at 0.006, 0.045 and 0.075 m and none of them clears a 0.161 m board;
## 0.30 m does, and a lawn standing a foot proud of its own ground is not a fix.
## The producer is a cell the garden treatment should not have called a yard at
## all -- 6 to 67 garden cells a town lie under a room's envelope one band up,
## which is task I4 round 4's own third concern -- and demoting them costs
## 7/large its entire green. That is a change worth its own round and its own
## frames, not a constant nudged here.
const GREEN_CAP_LIFT := -0.02
## TASK I2 -- THE GARDEN. The green quad is KayKit's grass swatch rendered
## WHITE, which means the atlas colour raw; every other grass surface in the
## world goes through `BiomeRegistry.ground_tint_at`, and the terrain's own
## multiplier is well under 1.0 in value. So a bench top rendered white is
## brighter and more saturated than the meadow it sits in -- the "lime plate"
## the H3 battery named, and half of the "grass tops built into the city" the
## user called cliffs.
##
## The fabric payload has no world anchor to evaluate that field at (its
## transforms are settlement-local and the commit applies the placement), so the
## tint is MEASURED off the frame it has to match rather than derived. Iteration
## 1 of this task rendered the production settlement with the palette's own
## centre (`BiomeProfile.ground_tint` for meadow, Color(0.72, 0.66, 1.0)) and
## sampled both surfaces in the same frame
## (`i2/r1-production/seed-2697992464-overview-nw.png`): the terrain read sRGB
## (93, 178, 60) and the bench tops (124, 200, 82) -- lighter and paler, which is
## exactly the "grass tops" read the user called part of a cliff. Converting both
## to linear and taking the ratio gives (0.544, 0.771, 0.534), and multiplying
## the meadow centre by it gives the constant below. A bench is then the same
## value and hue as the ground the village stands on.
##
## Applied to the RIM as well, for the reason the rim exists: turf and its own
## rolled edge that do not match are two surfaces, not one bench.
const GARDEN_TURF_TINT := Color(0.39, 0.51, 0.53)
## What grows on a bench once it is a garden rather than a plate. All four are
## authored village dressing under a metre tall, so one sits inside its own
## 1.5 m cell with room to spare (the broadest measures 0.95 m) and none of them
## can reach a neighbour's street. They ship without colliders, exactly as the
## courtyard planter this file already places does, and that is sound here for a
## reason worth stating: a planted cell is by construction a cell the public
## realm does NOT walk -- that is what made it green in the first place -- so
## there is no body to stop.
##
## TASK I4 ROUND 5, ITEM 5 -- "there could be more variation in the types of
## assets/decorations used". FOUR self-sown pieces was the whole vocabulary of a
## yard, and the plaza's own boundary had exactly ONE (see GARDEN_PLANTER); the
## user's frame is a row of six identical crate-planters. Measured on the review
## corpus before the change: 2 to 5 distinct pieces a town, and on 12/compact
## FOUR of four adjacent planted pairs wore the SAME module.
##
## The widening is drawn from what the catalogue already ships and what this
## project already reviews. The self-sown pool gains the five authored flowers
## the roof terraces are dressed with (`ROOF_FLOWER_*`) and three mushrooms;
## every one measures under 1.2 m across, ships no collider, and is authored
## standing on its own y = 0 exactly as the four plants are.
const GARDEN_PLANTING: Array[StringName] = [
	&"lpfv.fabric.prop.plant.broad.03",
	&"lpfv.fabric.prop.plant.mid.02",
	&"lpfv.fabric.prop.plant.low.01",
	&"lpfv.fabric.prop.plant.tall.04",
	SettlementFabricProgram.ROOF_FLOWER_BLUE,
	SettlementFabricProgram.ROOF_FLOWER_WARM,
	SettlementFabricProgram.ROOF_FLOWER_SMALL,
	SettlementFabricProgram.ROOF_FLOWER_TALL,
	SettlementFabricProgram.ROOF_FLOWER_PALE,
	&"lpfv.mushroom.01",
	&"lpfv.mushroom.02",
	&"lpfv.mushroom.03",
]
## The BUILT pieces of the vocabulary, and the village green's own. A self-sown
## plant says "nobody comes here"; a made planter says somebody laid this square
## out, which is the difference between a leftover patch of grass and a plaza.
## The planter is the same module the elevated courtyards are already edged with,
## so a plaza and a court are furnished from one kit.
##
## TASK I4 ROUND 5, ITEM 5 -- AND IT IS NO LONGER ONE MODULE. Everything added
## here is a piece `SettlementFabricProgram` already stands on its own terraces
## and inside its own covered markets, so nothing is a new asset decision: a
## barrel, a crate, a sack, a bucket, a bench, a stack of firewood and a lamp
## post are what a laid-out village square has round its edge. Ordered
## LARGEST FIRST, because the fit rule below walks the pool in order and takes
## the first piece that fits the cell's real free box -- so a roomy edge cell
## gets a planter and a pinched one still gets a bucket rather than nothing.
##
## EIGHT PIECES, AND ORDER IS NOT WHAT PICKS ONE. Round 5's note here said
## "ordered LARGEST FIRST, because the fit rule below walks the pool in order and
## takes the first piece that fits", and the r4+r5 review is right that the code
## does no such thing: `maze_decor_choice` walks from a SEEDED OFFSET and wraps,
## so the first piece a cell sees is a fact about the cell's own roll and the
## order only decides what follows it. That is deliberate -- an ordered pool
## would put the same planter on every roomy cell in the town, which is the
## repetition item 5 is about -- and the largest-first arrangement survives as
## what it really is: the reading order of the list, not a policy.
const GARDEN_PLANTER := COURTYARD_PLANTER
const GARDEN_PLANTER_POOL: Array[StringName] = [
	COURTYARD_PLANTER,
	SettlementFabricProgram.TERRACE_BARREL_A,
	SettlementFabricProgram.TERRACE_BARREL_B,
	SettlementFabricProgram.TERRACE_CRATE,
	SettlementFabricProgram.TERRACE_BAG,
	SettlementFabricProgram.TERRACE_CHAIR,
	SettlementFabricProgram.TERRACE_BUCKET,
	SettlementFabricProgram.TERRACE_LANTERN_TABLE,
]
## TASK I4 ROUND 6 -- THE PIECES THAT NEED TWO CELLS, and the whole answer to
## round 5's second concern: the square's planted boundary went thin because
## every piece a laid-out square really has along its edge is longer than a cell.
## Round 5 measured them and left them out; this round merges the free boxes of a
## PAIR of boundary cells and the adjacent-differs rule treats the pair as one
## occupant, so the boundary comes back with MORE variety rather than less.
##
## The three, measured off the descriptors as half-extents about each piece's own
## origin (the same reading DECOR_CLEARANCE takes, and the same reason -- these
## are authored off-centre):
##
## * `lpfv.fabric.prop.bench.02` -- 1.031 x 0.208. Fits a pair's 1.5 x 0.75 with
##   0.47 m to spare along the run.
## * `lpfv.fabric.prop.bench.01` -- 1.153 x 0.219. The longer bench of the two.
## * `lpfv.fabric.prop.lantern.post.02` -- 1.234 x 0.277. The post stands on its
##   own centre and the ARM reaches 1.234 m to one side, which is why the
##   symmetric bound is the arm's and not half the piece's width.
##
## AND THE FIREWOOD STACK IS STILL REFUSED, on the measurement rather than on
## taste: `lpfv.fabric.prop.firewood.01` is 2.147 x 1.946, so its half-extents
## are 1.078 x 1.031 and the CROSS axis is what fails -- a pair of cells is 3.0 m
## long and still only 1.5 m deep, which leaves 0.75 m against the stack's own
## 1.031 m. It would hang 0.28 m over the cell behind it at every yaw. A rule
## that spanned a 2 x 2 block would take it and this round did not write one.
const GARDEN_WIDE_POOL: Array[StringName] = [
	SettlementFabricProgram.TERRACE_BENCH,
	SettlementFabricProgram.TERRACE_LANTERN_POST,
	SettlementFabricProgram.TERRACE_BENCH_ALT,
]
## How often an ordinary yard grows something: one bench cell in three. Sparse
## on purpose -- the direction is "gardens/courtyards BEHIND and BETWEEN houses,
## incidental", not a nursery.
const GARDEN_PLANTING_ODDS := 0.34
## THE VILLAGE GREEN (user annotation, 2026-08-26): "this should be more
## integrated in the city, like a grass plaza in the center". One deliberate
## plaza beats scattered lawn, so the largest connected run of bench tops in a
## town is designated as that plaza and dressed as one: its INTERIOR stays open
## grass (a plaza is a clearing) and its EDGE cells take planting at twice the
## ordinary rate, which is what turns a shapeless green patch into a bounded
## square. A run must reach this many cells to be worth calling a plaza; below
## it a town simply has no green big enough and every bench is dressed as an
## ordinary yard.
## Iteration 2 of this task rendered the edge at 0.68 and the capture
## (`i2/r2-12-compact/seed-012-gate-approach-far.png`) reads as a regular row of
## boxes along a parapet rather than as a planted boundary -- nearly every edge
## cell took one. Half is enough to bound the square and leaves gaps to look
## through.
const VILLAGE_GREEN_MINIMUM_CELLS := 4
const VILLAGE_GREEN_EDGE_ODDS := 0.5
## TASK I3 -- WHAT FINISHES THE SQUARE. The plaza had a clearing and a planted
## boundary at I2; the direction asks for the other two things a square has.
##
## THE THRESHOLD is the coursed masonry slab this file already lays over a
## walked bench cap, laid over the green's own entrance cells instead. It is a
## treatment the skin has proved rather than a new module: a cap the realm walks
## keeps its stone (task C5b's "the street stands on stone"), and the mouth of a
## square is exactly where the pavement stops being pavement. It rides in the
## garden channel with a `maze-plaza-threshold/` id, so the shell's own
## panel-for-panel identity is untouched.
##
## THE CENTRE FEATURE is one of three authored village pieces, chosen by seed,
## and the choice is bounded by MEASUREMENT rather than by taste -- each needs a
## clear square of plaza to stand in and each fits its own with quarter turns
## only:
##
## * `sfv.well.001`   -- AABB 3.911 x 4.260 x 3.304, 12 colliders. Half-extents
##   1.955/1.652 against the 2.250 m half of a 3 x 3-cell block.
## * `sfm.stall.variant.001` -- 4.474 x 4.019 x 3.199, 7 colliders. Half-extents
##   2.237/1.599, which clears the same 2.250 m by 13 mm.
## * `lpfv.tree.05`   -- 2.498 x 5.991 x 2.142, 1 collider. Half-extents
##   1.249/1.071 against the 1.500 m half of a 2 x 2-cell block, so the tree is
##   also the answer where only a 2 x 2 is clear.
##
## Quarter turns only for the reason the built planter takes them: on a free yaw
## the bound above is measured off the wrong axis, and a laid-out square is
## square to its own grid anyway.
const PLAZA_WELL := &"sfv.well.001"
const PLAZA_MARKET_STALL := &"sfm.stall.variant.001"
const PLAZA_TREE := &"lpfv.tree.05"
const PLAZA_WIDE_FEATURES: Array[StringName] = [PLAZA_WELL, PLAZA_MARKET_STALL,
	PLAZA_TREE]
const PLAZA_WIDE_BLOCK := 3
const PLAZA_NARROW_BLOCK := 2
const PLAZA_FEATURE_SALT := 53
## TASK I4 ROUND 5, ITEM 1 -- "one of the plants is glitched into the wall", and
## the cause is that A LATTICE CELL IS NOT FREE SPACE.
##
## `maze_garden_dressing` stood every piece on its cell's own centre and bounded
## it by the CELL: "turned so it CANNOT reach a neighbour -- the broadest
## measures 0.951 m, whose worst rotated half-extent is 0.639 m against the
## cell's own 0.750 m". Every number in that sentence is right and the sentence
## is still wrong, because the thing a planter really meets is not the lattice
## plane at 0.750 m, it is the BUILT SURFACE standing in front of it:
##
## * a COURSED MASONRY panel straddles its boundary -- origin ON the plane,
##   0.664 m deep -- so it occupies STONE_CAP_HALF_DEPTH = 0.332 m of the cell on
##   EITHER side of it, its own and its neighbour's;
## * a TIMBER FACADE panel is pinned by its outer face to the boundary and
##   occupies the outer FACADE_CELL_DEPTH = 0.553 m of ITS OWN column (the number
##   `_maze_facade_transform` already states: "it occupies the outer 0.553 m,
##   which leaves 0.947 m of a 1.5 m cell");
## * a BUILDING's own wall across the boundary is a room unit's module, and the
##   deepest in the vocabulary is the double door leaf at 0.563 m from the plane
##   (`sfv.fabric.wall.wood.door.closed.001`, measured z -0.563 to +0.508).
##
## So the free half-width of an edge cell is 0.750 m minus whichever of those is
## standing there -- 0.418 m against coursed stone, 0.197 m against a facade,
## 0.187 m against a door -- and a 1.208 m planter centred on that cell reaches
## 0.186 m into the stone and 0.407 m into the timber. Measured on the review
## corpus before the fix: 14 to 34 placed pieces a town intersect real built
## geometry.
##
## THE DISCIPLINE IS I4 ROUND 1's, REUSED. `PERIMETER_FRONTAGE_CLEARANCE` learnt
## this lesson for the market frontage -- per asset, the envelope it really
## occupies, taken as the LARGER of the baked collider hull and the visual AABB
## per axis. Every piece in the two garden pools bakes NO collider at all, so for
## these the geometry is the whole of it; the table is mirrored against the
## descriptors by `test_the_decor_constants_mirror_the_module_descriptors` all
## the same, so a re-bake that grew one fails there rather than putting a plant
## back in a wall.
const DECOR_MASONRY_INTRUSION := STONE_CAP_HALF_DEPTH
const FACADE_CELL_DEPTH := 0.5530
const DECOR_FACADE_INTRUSION := FACADE_CELL_DEPTH
## TASK I4 ROUND 6 REPLACES THE FOURTH NUMBER WITH THE MODULE'S OWN BOX.
##
## Round 5 charged a building's outward wall as the DEEPEST module the wall
## vocabulary can put on a boundary -- `sfv.fabric.wall.wood.door.closed.001`
## measures 1.071 m through -- to any face with a solid or occluder cell across
## it or across either diagonal. The measurement is exact (12/compact's own leaf
## spans x -4.821 to -3.750 across a garden cell running -5.25 to -3.75) and
## charging it to that SET was not: the occluder envelope is a room's whole
## volume INCLUDING ITS INTERIOR AIR, so a cell that merely touched a room
## diagonally paid a front door's depth on a face with a blank wall or nothing
## at all on it. That blanket is where 41 per cent of the corpus's planting went
## between rounds 4 and 5, and why 12/compact's green wore four table lanterns
## out of nine pieces: only the narrowest piece in the pool fitted what was
## left. `maze_footprint_intrusion` asks the placement's own box instead.
##
## HOW TALL A PIECE THE PROBE HAS TO CLEAR, which is what makes the box a
## question about a BAND rather than about a column: the tallest module in the
## two garden pools is `lpfv.mushroom.03` at 1.268610 m over its own footing.
## A gallery board 1.339 m over a lawn is therefore not a wall the planting has
## to stand off -- it is a ceiling, and `maze_footprint_headroom` is the rule
## that reads it.
const DECOR_PROBE_RISE := 1.268610
## The slack every footprint query allows itself before it calls two boxes
## touching. A tenth of a millimetre: below the tolerance any of these modules
## was authored to and far below anything an eye resolves at 1.5 m.
const FOOTPRINT_EPSILON := 0.0001
## A hair of daylight between a piece and the wall behind it, so "just fits" is
## not "just touches". One centimetre -- the smallest gap the sweep's own
## clearance margin calls a gap.
const DECOR_STANDOFF_MARGIN := 0.01
## Per asset, the half-extents it really occupies along its own local X and Z,
## as (HALF-X, HALF-Z) and NOT half its size: several pieces are authored
## off-centre (`lpfv.fabric.prop.plant.broad.03` runs x -0.406 to +0.474), so
## half the width would understate the end that really hangs past. Each is the
## larger of the two extents on that axis, and the larger of the visual and the
## baked hull -- which for these is the visual, because every one of them bakes
## zero collision pieces.
const DECOR_CLEARANCE := {
	COURTYARD_PLANTER: Vector2(0.604000, 0.450000),
	SettlementFabricProgram.TERRACE_BARREL_A: Vector2(0.449679, 0.449679),
	SettlementFabricProgram.TERRACE_BARREL_B: Vector2(0.449679, 0.449679),
	SettlementFabricProgram.TERRACE_CRATE: Vector2(0.375695, 0.375695),
	SettlementFabricProgram.TERRACE_BAG: Vector2(0.317735, 0.268193),
	SettlementFabricProgram.TERRACE_CHAIR: Vector2(0.279078, 0.234450),
	SettlementFabricProgram.TERRACE_LANTERN_TABLE: Vector2(0.073000, 0.205000),
	SettlementFabricProgram.TERRACE_BUCKET: Vector2(0.278094, 0.278094),
	&"lpfv.fabric.prop.plant.broad.03": Vector2(0.474518, 0.430053),
	&"lpfv.fabric.prop.plant.mid.02": Vector2(0.463525, 0.455049),
	&"lpfv.fabric.prop.plant.low.01": Vector2(0.493207, 0.437208),
	&"lpfv.fabric.prop.plant.tall.04": Vector2(0.513118, 0.456085),
	SettlementFabricProgram.ROOF_FLOWER_BLUE: Vector2(0.506855, 0.383075),
	SettlementFabricProgram.ROOF_FLOWER_WARM: Vector2(0.528646, 0.367876),
	SettlementFabricProgram.ROOF_FLOWER_SMALL: Vector2(0.329099, 0.222446),
	SettlementFabricProgram.ROOF_FLOWER_TALL: Vector2(0.350779, 0.231889),
	SettlementFabricProgram.ROOF_FLOWER_PALE: Vector2(0.565099, 0.433177),
	&"lpfv.mushroom.01": Vector2(0.427022, 0.435514),
	&"lpfv.mushroom.02": Vector2(0.421398, 0.399904),
	&"lpfv.mushroom.03": Vector2(0.400689, 0.400689),
	SettlementFabricProgram.TERRACE_BENCH: Vector2(1.030627, 0.207915),
	SettlementFabricProgram.TERRACE_BENCH_ALT: Vector2(1.152981, 0.218718),
	SettlementFabricProgram.TERRACE_LANTERN_POST: Vector2(1.233737, 0.276905),
}
## TASK I4 ROUND 5, ITEM 2 -- "the market stall is not one of the stocked ones;
## it is empty. we should use the stocked ones."
##
## THE CATALOGUE'S STOCKED STALLS DO NOT FIT, and that is a measurement rather
## than a preference. `sfm.stall.variant.001` -- the empty canopy the square
## stands today -- is 4.474 x 3.199 m, which clears the 4.5 m of a 3 x 3-cell
## plaza block by 13 mm and the 4.5 m of a three-cell perimeter window by the
## same. The SMALLEST genuinely stocked prefab in the bake is
## `sfm.stall.fish.001` at 5.113 x 3.415 (half-width 2.718 against 2.250), and
## the rest run to 7.6 m; every one of them would hang half a metre past the
## block it stands in, over the very edge cells item 1 above is about, and the
## wide ones bake a single CONCAVE hull where the canopy pool bakes seven boxes.
##
## SO THE CANOPY IS STOCKED INSTEAD OF REPLACED, which is this project's own
## established answer rather than a new one: `SettlementFabricProgram`'s
## `_covered_market_recipe` already builds "one exact 6 x 3 m covered bazaar" by
## standing the reviewed stocked counter and the hanging goods under a bare
## canopy from `COVERED_MARKET_CANOPIES`. This is that composition, done in the
## fabric for the two canopies this file sites itself -- the square's centre
## feature and the perimeter frontage.
##
## THE STATIONS ARE MEASURED OFF THE CANOPY'S OWN SEVEN COLLIDER BOXES. Four
## posts, 0.30 m square, at (+-2.08, +-1.12); the canopy and its two valances
## from y = 4.21 up. The GROUND between the posts is therefore clear from
## x = -1.93 to +1.93 and z = -0.97 to +0.97, and every station that stands on
## the ground is inside that. The HANGING station is not and does not need to
## be: it is 3.9 m up, well over the posts' own 1.12 m half-depth, and what
## bounds it is the cloth above it rather than the frame below -- which is the
## bound round 5 never asserted and `maze_stall_hanging_station` now does.
## (r4+r5 review, minor 3.)
##
## * the STOCKED COUNTER (`sfm.table.fishmonger.001`, 2.064 x 1.406 with its
##   fish, its crate and its board) stands at z = +0.45, so it spans x +-1.032
##   and z -0.359 to +1.259 -- clear of both post rows in x;
## * THREE GOODS stand in a row at z = -0.95, at x = -1.45, 0.00 and +1.45, each
##   at most 0.45 m across, so the widest of them runs 1.00 to 1.90 in x against
##   the post's own 1.93 and never touches the counter;
##
## WHICH SIDE IS THE FRONT is a fact about the CANOPY's own local axes and this
## file's two siting rules disagree about it, so neither station is described as
## front or back any more. `maze_perimeter_frontage` turns each module's
## authored local +Z outward (see its own note), which puts the counter at
## z = +0.45 on the MEADOW side of a perimeter stall and the three goods against
## the town wall; the square's centre feature takes a seeded quarter turn and so
## faces wherever the roll put it. Both compositions are inside the canopy and
## both read as a stocked stall; what is not defensible is a comment claiming a
## front the geometry does not have. (r4+r5 review, minor 2.)
## * the HANGING GOODS (`sfm.stall.veg_string.001`) hang from y = 3.90 down to
##   2.64, which is above the 2.244 m a body needs -- the same bound
##   `_covered_market_recipe` states for its own two attachments.
##
## TASK I4 ROUND 6 -- AND THE STATION IS PER CANOPY, because the two canopies are
## not the same piece and round 5 measured only one of them. The r4+r5 review
## caught it: `sfv.fabric.awning.blue.001` rises 3.4910 m and the string hung
## from 3.9 spans y 2.635 -> 3.9004, so its top stood 0.4094 m IN OPEN AIR above
## the cloth -- on 18 of 18 awnings on the review towns and on the order of 150
## across the matrix, a defect this file's own item-2 fix introduced.
##
## THE AWNING CANNOT CARRY A STRING AT ALL, and the arithmetic is what says so
## rather than a preference. The string is 1.2653 m long with its top 0.0004 m
## over its own origin, so a station that keeps the top under the cloth needs
## `y <= 3.4906` and one that keeps the foot over a body's head needs
## `y >= 2.244 + 1.2649 = 3.5089`. There is no such y. An awning is therefore
## stocked with its counter and its three goods and hangs nothing, which is
## `maze_stall_hanging_station` returning nothing rather than a number nobody
## checked.
const STALL_COUNTER := SettlementFabricProgram.COVERED_MARKET_TABLE
const STALL_HANGING_GOODS := SettlementFabricProgram.COVERED_MARKET_HANGING_GOODS
const STALL_COUNTER_STATION := Vector3(0.0, 0.0, 0.45)
## The hanging string's own authored reach about its origin
## (`sfm.stall.veg_string.001`, AABB y -1.264895 -> +0.000420), and the canopy
## rises it is measured against. Both mirrored against the descriptors by
## `test_the_stall_stations_fit_the_canopies_they_hang_from`.
const STALL_HANGING_LOCAL_TOP := 0.000420
const STALL_HANGING_LOCAL_DROP := 1.264895
const STALL_CANOPY_RISE: Dictionary = {
	PLAZA_MARKET_STALL: 4.019341,
	SettlementFabricProgram.ROOF_TERRACE_AWNING: 3.490989,
}
## Where the market stall's string hangs, unchanged from round 5: 0.119 m of
## daylight between the string's top and the canopy's own, and 2.635 m of head
## room under its foot.
const STALL_HANGING_STATION := Vector3(0.0, 3.9, 1.35)
const STALL_GOODS_STATIONS: Array[Vector3] = [
	Vector3(-1.45, 0.0, -0.95),
	Vector3(0.0, 0.0, -0.95),
	Vector3(1.45, 0.0, -0.95),
]
## What stands at a goods station. Every one is a `SettlementFabricProgram`
## terrace prop this file already places elsewhere, every one is at most 0.45 m
## across, and every one bakes no collider -- which is sound for the reason the
## garden planting is: a stall stands on a garden cap or on meadow outside the
## town's own wall, and neither is a cell the public realm walks.
const STALL_GOODS: Array[StringName] = [
	SettlementFabricProgram.TERRACE_BARREL_A,
	SettlementFabricProgram.TERRACE_CRATE,
	SettlementFabricProgram.TERRACE_BARREL_B,
	SettlementFabricProgram.TERRACE_BAG,
	SettlementFabricProgram.TERRACE_BUCKET,
]
const STALL_GOODS_SALT := 97
## The canopies this file stands and therefore has to stock. Both are frames
## with nothing under them: the market stall is the empty variant the user
## circled, and the framed awning is a canopy on four legs.
const STALL_CANOPIES: Array[StringName] = [PLAZA_MARKET_STALL,
	SettlementFabricProgram.ROOF_TERRACE_AWNING]
## The one-cell facade module's own front face, mirrored from
## `SettlementFabricProgram.WOOD_CELL_FACADE_FRONT_DEPTH` so this file's
## transform arithmetic reads against the same number the pool is measured by.
const FACADE_FRONT_DEPTH := SettlementFabricProgram.WOOD_CELL_FACADE_FRONT_DEPTH
## What one panel of the skin WEARS. The shell, its coursing and its cap
## pairing are unchanged by this: a treatment picks the module, never the
## panel, so the retained rock's volume and the audited face identity are the
## same facts they were.
##
## TASK I2 ADDS THE FOURTH AND RETIRES THE SECOND. FACADE is a BUILDING storey:
## the authored one-cell timber wall, window or boarded, in the district's own
## family. NATURAL -- the KayKit cliff shard H2b clad tall banks with -- is
## `maze_natural_is_permitted()` false and therefore unreachable; the user's
## verdict on it was "these are the parts that i think we should remove: the
## cliffs", rim included. The enum keeps the member because the shard's own
## arithmetic (its coverage bounds, its street cut, its tail clamp) is still
## proved by the suite and is the record of why a 4 m module on a 1.5 m lattice
## needed three clamps -- the next skin module with that habit should be able to
## read it.
## TASK I4, ANNOTATION 2 ADDS THE FIFTH: the PLANK TERRACE. "these grass areas
## are too small, we should only have grass in large areas like plazas/gardens."
##
## Task I2 made every free sky-facing cap green, and the census says what that
## costs: a town's garden is 8-22 separate RUNS, and the small end of that
## distribution is a lawn one cell wide on top of a tower. The garden treatment
## is now a fact about the RUN rather than about the panel -- a run has to be big
## enough AND somewhere two cells wide to be a yard -- and everything under the
## bar takes the deck instead, which is the vocabulary the town's own terraces
## are already made of.
enum SkinTreatment {MASONRY, NATURAL, GREEN, FACADE, DECK}
## THE GARDEN BAR, picked off the run histogram of the five review towns rather
## than chosen. Every connected run of free caps, by size:
##
## | town | runs | sizes |
## | 12/compact | 13 | 4x2, 6x4, 8, 17, 36 |
## | 4/compact | 13 | 5x2, 2x4, 6, 3x8, 12, 36 |
## | 3/standard | 22 | 7x2, 7x4, 6, 5x8, 11, 30 |
## | 9/standard | 15 | 5x2, 6x4, 2x8, 12, 17 |
## | production | 8 | 3x2, 4, 8, 2x10, 41 |
##
## SIX CELLS is where that distribution has its gap: it is above every 2-run and
## every 4-run (a 2x2 patch or a four-cell thread on a wall head, which is what
## the annotation circled) and below the smallest run any of the five towns would
## call a garden. It keeps 61-79 % of each town's garden cells and it never
## empties a town -- the smallest surviving garden is 3 runs.
const GARDEN_RUN_MINIMUM_CELLS := 6
## AND SOMEWHERE TWO CELLS WIDE. Size alone still admits a six-cell RIBBON along
## a parapet, which reads exactly like the patches the annotation is about. A run
## qualifies only if it contains at least one 2 x 2 block of its own cells --
## the same "is this a clearing or a thread" question the square's own `interior`
## census asks, at the weakest strength that any run can satisfy.
const GARDEN_RUN_MINIMUM_BLOCKS := 1
## What a cap under the bar wears instead: the authored deck the town's galleries,
## balconies and skywalks are already floored with, one module per panel exactly
## as the turf quad was. `PLANK_SINGLE` for a cap that closes one cell,
## `PLANK_GALLERY` for a pair -- both are 1.5 m across and both are authored on
## the same 0.161 m board, so a deck cap is the same construction at either size.
const PLANK_TERRACE_CAP := PLANK_SINGLE
const PLANK_TERRACE_CAP_PAIR := PLANK_GALLERY
## The deck's own measured thickness (`sfv_deck_floor_s_001.tres` /
## `sfv_fabric_gallery_floor_m_001.tres`, both AABB y 0 -> 0.161052), mirrored by
## `test_the_skin_constants_mirror_the_module_descriptors`. A cap is laid so its
## WALKING FACE is the cell's own top, which means the board is sunk by its own
## thickness -- the opposite of the turf quad, which has none.
const PLANK_TERRACE_THICKNESS := 0.16105233
## TASK I4 ROUND 6, ITEM 4a -- HOW CLOSE TO THE PLANE A FLOOR HAS TO BE to make
## the boundary beside it a LEVEL junction rather than a buried one. One board's
## own thickness: a room's gallery or court floor lying on the lawn's plane has
## its underside within a centimetre of it and its walking face one board over
## it, which is the same step a plank street at the lawn's own height makes and
## is therefore the same lip. A gallery a metre and a third overhead is well
## outside it and is a headroom question instead -- `_maze_cap_is_free` owns
## that one.
const GREEN_RIM_LEVEL_REACH := PLANK_TERRACE_THICKNESS
## HOW MUCH OF A CELL A FLOOR HAS TO COVER before the cell is called floored
## rather than clipped. Half, and the corpus says nothing sits near the bar: the
## two populations measured on the review towns are 162 cells covered 1.00 of
## their own area and every other overlap at 0.22 or below. See
## `maze_cap_is_boarded`.
const CAP_BOARD_COVER_FRACTION := 0.5
## `sfv_deck_floor_s_001.tres` is AABB(-1.503246, 0, -0.75, 1.5, 0.161, 1.5):
## authored on its own local +X EDGE rather than centred, which is why
## `_add_plank_tile` shifts it half a cell and why this file does the same.
## `sfv_fabric_gallery_floor_m_001.tres` is AABB(-1.5, 0, -0.75, 3.0, 0.161,
## 1.5) and IS centred across its 3 m span.
const PLANK_TERRACE_CAP_OFFSET := 0.75
## TASK I4, ANNOTATION 6 -- THE PERIMETER COMES ALIVE. "instead of a sheer wall
## at the edge of the city it would look better if there were ground story
## buildings or a market around the perimeter."
##
## THE VOCABULARY IS MEASURED, not chosen, and every number below is read off
## the descriptor rather than assumed -- mirrored against them by
## `test_the_frontage_constants_mirror_the_module_descriptors`:
##
## * `sfm.stall.variant.001`  -- 4.474 x 4.019 x 3.199, 7 colliders. The market
##   stall the square already stands one of in its middle.
## * `sfv.fabric.awning.blue.001` -- 4.241 x 3.491 x 3.030, 0 colliders. A
##   complete framed awning, which is the lean-to end of the vocabulary.
## * `sfm.table.fishmonger.001` -- 2.064 x 1.343 x 1.406, 5 colliders.
## * `lpfv.fabric.prop.barrel.01` -- 0.899 x 1.030 x 0.899, 0 colliders.
##
## THE WINDOW IS THREE CELLS because the two wide pieces are 4.474 m and
## 4.241 m against 4.5 m of lattice -- 13 mm and 130 mm of slack. Two cells hold
## the table with 0.94 m to spare and one cell holds a barrel.
##
## HALF-DEPTHS, so a piece's VISIBLE back plane lands on the wall it fronts:
## half of each module's own measured z extent.
##
## ROUND-2 CORRECTION -- "AND NOTHING REACHES INTO THE MASS" WAS AN ABSOLUTE AND
## IS NOT TRUE. These are half the VISUAL extent, and the market stall's baked
## collider is deeper than its geometry: the hull reaches 1.831 m out from its
## own origin against the 1.599 m this table pushes it, so 0.231 m of collider
## stands BEHIND the wall plane, inside the town's own mass. It is harmless --
## the cells it occupies are solid, nothing walks there, and no rule in this file
## measures anything from a frontage's back plane -- and the alternative is
## worse: pushing the piece out by the collider's half-depth instead would float
## the visible stall 0.23 m off the wall it is meant to lean on. The 0.231 m is
## footprint mass and is named here so the next reader does not rediscover it as
## a bug. What the collider hull DOES govern is the clearance envelope in front
## of the piece -- see PERIMETER_FRONTAGE_CLEARANCE, which takes the larger of
## the two readings per axis for exactly this reason.
const PERIMETER_WINDOW_CELLS := 3
const PERIMETER_MARKET_STALL := PLAZA_MARKET_STALL
const PERIMETER_AWNING := SettlementFabricProgram.ROOF_TERRACE_AWNING
const PERIMETER_TABLE := SettlementFabricProgram.COVERED_MARKET_TABLE
const PERIMETER_BARREL := SettlementFabricProgram.TERRACE_BARREL_A
const PERIMETER_WIDE_FRONTAGE: Array[StringName] = [PERIMETER_MARKET_STALL,
	PERIMETER_AWNING]
const PERIMETER_NARROW_FRONTAGE: Array[StringName] = [PERIMETER_TABLE]
const PERIMETER_SINGLE_FRONTAGE: Array[StringName] = [PERIMETER_BARREL]
const PERIMETER_FRONTAGE_DEPTH := {
	PERIMETER_MARKET_STALL: 1.599468,
	PERIMETER_AWNING: 1.514985,
	PERIMETER_TABLE: 0.702901,
	PERIMETER_BARREL: 0.449679,
}
## WHAT EACH PIECE REALLY OCCUPIES, which is NOT its visual AABB and is why the
## first pass of this rule stood a market stall in a street.
##
## `sfm.stall.variant.001` measures 4.474 x 4.019 x 3.199 as geometry and bakes
## a COLLIDER HULL of 5.280 x 4.550 x 3.661 -- 18 % wider, 13 % taller and 14 %
## deeper than the thing you can see. The awning and the barrel bake NO collider
## at all, so for those the geometry is the whole of it. Both readings matter and
## the envelope is the larger of them per axis: a body may not walk through a
## stall's frame, and it may not walk through an awning's canopy either.
##
## Per asset, as (HALF-WIDTH, RISE, REACH) in metres:
##
## * HALF-WIDTH -- how far the piece reaches to EITHER side of the window's
##   centre, which is the larger of its two lateral extents and not half its
##   size: `sfm.table.fishmonger.001` is authored off-centre (x runs -0.980 to
##   +1.084), so half its width would understate the end it really hangs past;
## * RISE -- how far it stands above the foot band's floor, which every module in
##   the pool is authored from;
## * REACH -- how far it reaches out from the WALL PLANE: the placement offset
##   `PERIMETER_FRONTAGE_DEPTH` plus its own outward half-extent, so the stall's
##   1.599 + 1.831 = 3.430 m is measured from the boundary the back plane lands
##   on rather than from the piece's own middle.
##
## Mirrored against the descriptors by
## `test_the_frontage_constants_mirror_the_module_descriptors`, which fails if a
## re-bake moves a module and this table does not follow it.
##
## TASK I4 ROUND 2 -- AND AGAINST THE COLLIDERS THEMSELVES. Round 1 shipped this
## table with only its VISUAL half checked and filed the rest as a concern: a
## re-bake that grew a collider without moving the geometry would have passed
## every pin and put a stall back in a street.
## `test_the_frontage_clearance_covers_the_baked_colliders` closes it. The bake
## writes each piece's shape and `local_transform` into the asset's own
## `EnvironmentVisual`, so the hull is a resource read rather than the physics
## frame the first estimate assumed, and both halves of every row above are now
## asserted against the thing they were transcribed from.
const PERIMETER_FRONTAGE_CLEARANCE := {
	PERIMETER_MARKET_STALL: Vector3(2.640000, 4.550289, 3.430078),
	PERIMETER_AWNING: Vector3(2.120373, 3.490989, 3.029970),
	PERIMETER_TABLE: Vector3(1.084048, 1.343014, 1.511983),
	PERIMETER_BARREL: Vector3(0.449679, 1.032944, 0.899358),
}
## HOW MUCH OF THE PERIMETER IS DRESSED. Seeded per window off the window's own
## anchor, which is this file's idiom for every dressing rate it owns. Two in
## three rather than all of it: a market that fills every metre of every outward
## face is a wall of stalls, and what the direction asks for is a town whose foot
## reads as buildings meeting meadow -- which wants gaps in it.
const PERIMETER_FRONTAGE_ODDS := 0.66
const PERIMETER_FRONTAGE_SALT := 71
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
## TASK I3 -- THE OPEN TIMBER SKYWALK, and the four pieces it is made of.
##
## The reference frame is a plank bridge with railings crossing the air between
## two buildings at storey height, open to the sky. That is NOT the
## `room.bridge.*` arch or the plot model's own maze BRIDGE ROOM: both of those
## are enclosed rooms with walls and a roof, which is the thing the direction
## says is missing rather than the thing it asks for. This is FABRIC -- a deck,
## two rails and two bearers hung across a gap the town already has -- so it
## adds no room, claims no cell and changes no plot.
##
## Every module is already in this file's own vocabulary. The walkway pack
## (`fantasy_village_walkways`, 46 assets) was surveyed first and is the wrong
## kit for a 1.5 m lattice: its decks are 3.83-8.04 m long by 2.24-3.21 m deep
## (`sfbp.wwall.floor.001-004`) -- a rampart wall-walk, not a village footbridge
## -- and its supports (`sfbp.wwall.support.*`) are 3.6-4.8 m tall posts that
## would stand in the street the span crosses. What that pack DOES supply is
## `sfbp.wwall.support.s.002`, already this program's `DIAGONAL_BRACE`, and it
## is excluded here for the reason the jetty recipe excludes it: a 3.6 m post
## cannot pass through public air.
const SKYWALK_DECK := PLANK_GALLERY
const SKYWALK_DECK_SHORT := PLANK_SINGLE
const SKYWALK_RAIL := PLANK_RAILING
const SKYWALK_RAIL_MEDIUM := PLANK_RAILING_MEDIUM
## The measured 1.94 m timber corbel, the same piece the E3b bracketed jetty
## puts under a cantilevered room (`SettlementFabricProgram.BRACE`). Named
## through the program so a re-bake that renames the module breaks in one place.
const SKYWALK_BEARER := SettlementFabricProgram.BRACE
## Measured envelopes, transcribed from the descriptors and MIRRORED against
## them by `test_the_skywalk_constants_mirror_the_module_descriptors`:
##
## * `sfv_fabric_gallery_floor_m_001.tres` / `sfv_deck_floor_s_001.tres` --
##   both 0.16105 m thick, so one number covers the long deck and the short one.
## * `sfv_fabric_brace_wood_002.tres` -- AABB(-1.9427, 0, -0.4331, 1.9427,
##   0.4710, 0.8662): a corbel lying on its own local -X, 0.471 m deep below
##   the plate it carries and 0.866 m across the bearing it lies on.
const SKYWALK_DECK_THICKNESS := 0.16105233
const SKYWALK_BEARER_DROP := 0.47099975
const SKYWALK_BEARER_REACH := 1.9426978
## The corbel's third dimension, and the one an OUTCROPPING has to respect: laid
## across a face, this is how much of the projection's own depth the piece eats.
## The bay's 1.5 m box holds two of them clear of each other; the bump-out's
## half cell is SHALLOWER than one is deep, which is stated where they are
## placed rather than hidden by a fraction (fix 1, minor 4).
const SKYWALK_BEARER_DEPTH := 0.8662016
## HOW LONG A SPAN MAY BE, and the asset is the answer rather than taste. The
## longest deck in the catalog that tiles a 1.5 m lattice is the authored 3.0 m
## gallery floor -- TWO cells -- and a three-cell span would need a splice
## bearing in mid-air or a post standing in the street underneath. Both are
## refused, so the span stops where the module's own free length stops. The
## corpus measurement that says this costs nothing today: across the four
## planner towns every three-cell candidate gap sits ONE band over its street
## and is rejected by the headroom rule below before the length rule is reached.
const SKYWALK_MAX_GAP := 2
## HOW HIGH OVER A STREET, in bands. A body standing on the street below needs
## PLAYER capsule height plus the sweep's own margins -- 2.284 m -- and the
## lowest thing a span puts in the air is its bearer's underside at
## `band x CELL_SIZE - SKYWALK_DECK_THICKNESS - SKYWALK_BEARER_DROP`. Two bands
## leave 3.0 - 0.632 = 2.368 m, which clears by 84 mm; one band leaves 0.868 m
## and shuts the street. The sweep's clearance row is the live proof of this
## arithmetic -- `terrace_retaining_payload` carries the spans, so a span hung
## too low turns that row red instead of shipping a street nobody can walk.
const SKYWALK_MIN_HEADROOM_BANDS := 2
## The walk CARRIES its own clearance too, and this is how many bands ABOVE the
## deck's own band have to be clear of built mass. ONE, by the same arithmetic
## the headroom rule uses in the other direction: a body on the bridge stands
## from `band x CELL_SIZE` to `+2.244 m`, the deck's own band is 1.5 m of that
## and is already air by fact 3, and the band above carries the remaining
## 0.744 m with 0.756 m to spare. Two bands would be 3.0 m of sky over a
## village footbridge, and it costs real sites: the two-cell crossings on
## 12/compact run under an overhanging upper storey, which is a covered lane
## and exactly the kind of place a town puts a bridge.
const SKYWALK_HEAD_BANDS := 1
## And this is how far BELOW the deck the span's own column must be clear of
## built mass -- one band, so that a "gap" cannot be a 1.5 m notch cut in one
## terrace with a plank laid across it. Everything deeper is answered by the
## headroom rule instead, and deliberately: a public floor unit may claim its
## own walked cell as solid, so counting built mass two bands down would reject
## a real street crossing for being a street.
const SKYWALK_UNDERCUT_BANDS := 1
## The salt the seeded order below is drawn with, in the same idiom the garden
## dressing uses (`_face_noise`).
const SKYWALK_ORDER_SALT := 31
## Each unordered pair of ends is visited ONCE, from its lower-x / lower-z side
## -- the same convention the corpus sweep's own gate pass uses, and what keeps
## one gap from producing two mirrored spans.
const SKYWALK_STEPS: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.BACK]
## TASK I3 -- THE OUTCROPPINGS, and which face they hang on.
##
## The direction names three: "a sort of bay window in this case, but there
## should also be other types, such as dormers, bump-outs, etc". Two of them
## are a WALL's business and live here; the third is a ROOF's and lives in
## `WarrenParcelConstruction._roof_feature`, because a dormer is a hole in a
## pitch and this file's mass faces are capped by gardens, not by pitches.
##
## THEY HANG ON THE CLAD MASS, which is where the blank walls are. Task I2 turned
## every tall bank face into a building storey and the corpus now carries 64-347
## of those panels per town -- the tower-like faces the reference frame's own bay
## window projects from. Ruling 2 puts them here rather than in the feature
## solver for the same reason: an outcropping on a clad panel is FABRIC on
## existing structure, it moves no plot, reserves no cell and cannot cost a seal,
## where widening the compiled `facade_bay` reservation would do all three.
enum FacadeOutcrop {NONE, BAY, BUMP}
## How often a qualifying panel takes each. Measured against the corpus rather
## than chosen: at these rates the four planner towns carry 5-11 outcroppings
## each, which is articulation on most blocks and a stamp on none.
const FACADE_BAY_ODDS := 0.14
const FACADE_BUMP_ODDS := 0.14
## HOW HIGH A PANEL HAS TO STAND OVER A STREET, in bands measured from the
## panel's own band, and it is THREE rather than the skywalk's two because an
## outcropping hangs a course LOWER than a bridge does. The panel clads the
## course {band - 1, band}; its bearers hang SKYWALK_BEARER_DROP under the box's
## own floor at `(band - 1) x CELL_SIZE`, so the lowest timber is
## `(band - 1) x 1.5 - 0.471`.
##
## FIX 1, MINOR 8 CORRECTS THAT SUBTRACTION and the conclusion survives it. The
## first telling wrote `- 0.632`, which is the SKYWALK's number: a bridge hangs
## its corbel under a DECK, so it pays the deck's 0.161 m as well, and an
## outcropping's bearers hang straight off the box's floor line and do not. The
## real requirement against a body's 2.284 m is
## `(band - 1 - b) x 1.5 >= 2.284 + 0.471 = 2.755`, i.e. `band - b >= 2.837`,
## i.e. three bands -- the same answer the wrong constant gave, reached
## honestly. THE MARGIN IS 245 MM (`3.0 - 2.755`), not the 84 mm a bridge has;
## two bands would leave 1.029 m of air under the timber against a 2.284 m body
## and shut the street.
const FACADE_OUTCROP_MIN_HEADROOM_BANDS := 3
## The corner post is a measured 0.751 x 3.000 x 0.752 m block -- one HALF cell
## square and exactly one storey tall -- so two of them fill the whole half-cell
## body of a bump-out behind its pushed face, with no seam to close and nothing
## scaled. `sfv_fabric_wall_wood_corner_s_001.tres`.
const FACADE_OUTCROP_POST := SettlementFabricProgram.WALL_WOOD_CORNER_S
const FACADE_OUTCROP_POST_HALF := 0.3754524
## How far a bump-out pushes its face: half a cell, which is what the direction
## calls a bump-out and what the corner post above is measured to fill.
const FACADE_BUMP_REACH := FabricRecipe.CELL_SIZE * 0.5
## The flat cap over a bay box -- the same 1.5 m deck module the skywalk lays,
## for the same reason `_capped_outcrop_recipe` caps its own jetty with the
## authored gallery floor: a bay is a small room and a room has a lid.
const FACADE_OUTCROP_CAP := PLANK_SINGLE
## The salt the seeded roll is drawn with, in the `_face_noise` idiom the garden
## dressing uses. ONE, not two: a `FACADE_OUTCROP_TRIM_SALT` sat here unread
## from the first landing and went with fix 1, minor 3 -- an unused salt is a
## seeded decision a reader goes looking for and cannot find.
const FACADE_OUTCROP_KIND_SALT := 41


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
	var surface_instances := surface_visual_payload(plan.surface_plan,
		maze_module_footprints(plan))
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
	var paved := public_floor_cells(plan.surface_plan)
	var plinths := plinth_faces(retained, solids, bearing_footprint)
	var walked := walked_floor_cells(plan.surface_plan)
	# ONE derivation of the shell for the whole payload. Each of the three
	# emitters below used to re-derive what it needed from the cell sets --
	# `exposed_maze_stone_faces` ran FOUR times per payload, `maze_stone_faces`
	# twice, `maze_skin_treatments` twice and `plinth_faces` twice -- and each
	# derivation is a pure function of arguments that do not change between
	# them, so every repeat was the same answer computed again. `maze_skin_shell`
	# states that fact once and the emitters read it; the shell is a PER-CALL
	# local handed down the stack, never a static that outlives a solve.
	# TASK I4 ROUND 6. Derived ONCE for the whole payload, exactly as the shell
	# is: where every authored module of every unit really stands. Four rules
	# read it -- the cap gate, the garden's free box, the rim's junction class
	# and the floor bearer's headroom -- and each of them used to answer a
	# question about geometry out of a cell set that could not see it.
	var footprints := maze_module_footprints(plan)
	var shell := maze_skin_shell(retained, solids, paved, plinths, walked,
		footprints)
	var out := _plinth_payload(plinths)
	out.append_from(maze_stone_walls(retained, solids, paved, plinths, walked,
		shell, plan.world_seed))
	# TASK H2b FIX 1, IMPORTANT 3. The rolled edge round every green bench,
	# beside the shell rather than inside it -- see `maze_green_rim_walls`.
	out.append_from(maze_green_rim_walls(retained, solids, paved, plinths,
		walked, shell, footprints))
	# TASK I2. What grows on those benches once they are yards rather than lime
	# plates, and the village green among them.
	out.append_from(maze_garden_dressing(retained, solids, paved, plinths,
		walked, shell, footprints))
	# TASK I4, ANNOTATION 2. The guard round every deck cap the garden bar
	# demoted, which is what makes a demoted top read as a terrace rather than as
	# a board.
	out.append_from(maze_plank_terrace_railings(retained, solids, paved,
		plinths, walked, shell, footprints))
	# TASK I4, ANNOTATION 3. The corbels under the public floor plates that have
	# nothing beneath them -- the "random planks on the sides of these buildings"
	# turned into the galleries they were always meant to read as.
	# TASK I4 ROUND 5, ITEM 3. `maze_capped_stance_cells` is what tells the
	# headroom gate that a lawn and a plank terrace are surfaces a body stands on.
	out.append_from(maze_public_floor_bearers(retained, solids, paved, walked,
		maze_capped_stance_cells(shell, footprints)))
	# TASK I4, ANNOTATION 6. The town's outward foot, dressed: stalls, awnings
	# and their props standing on the meadow against the ground storey, so the
	# edge reads as buildings meeting open ground rather than as a sheer wall.
	out.append_from(maze_perimeter_frontage(retained, solids, paved, walked,
		plan.world_seed))
	# TASK C5e RULING 3. The other half of what a maze town's crown wears.
	# The parapet course that used to cap every flat roof is released to air
	# by `WarrenVolumetricSolver._maze_released_parapet_cells`, so the slab is
	# an open terrace and its exposed edges take a railing. It rides here
	# rather than in its own payload because this is the one function BOTH the
	# production materialiser and the review commit already call for the
	# retained crown, and a terrace with no rail is the same defect as a
	# mountain with no skin.
	out.append_from(maze_terrace_railings(plan))
	# TASK I3. The open timber skywalks, in the same channel and for the same
	# two reasons: this is the one function BOTH the production materialiser and
	# the review commit already call for the retained crown, AND it is the
	# payload the corpus sweep's clearance row commits -- so a span hung too low
	# over a street turns that row red instead of shipping quietly.
	#
	# Derived ONCE and used twice: the bridges themselves, and the cells they
	# claim, which the outcropping channel below must keep clear so a bay window
	# never grows into a walkway.
	var spans := maze_skywalk_spans(plan)
	out.append_from(maze_skywalks_from(spans))
	# TASK I3. The bays and bump-outs the clad mass projects, on the same shell
	# and against the same walked set.
	out.append_from(maze_facade_outcroppings(retained, solids, paved, plinths,
		walked, shell, plan.world_seed, maze_skywalk_cells(spans)))
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
	return _plinth_payload(plinth_faces(retained, solids, bearing_footprint))


static func _plinth_payload(faces: Dictionary) -> EnvironmentInstancePayload:
	## The emission half of `house_plinth_walls`, split off so a caller that has
	## ALREADY derived `plinth_faces` -- `terrace_retaining_payload` derives it
	## for the stone skin's deferral rule -- does not derive it a second time to
	## get the same panels back. The public entry above is unchanged and stays
	## the one every other caller uses.
	var out := EnvironmentInstancePayload.new()
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
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
	return _maze_stone_faces_from(exposed_maze_stone_faces(retained, solids,
		paved), retained, solids, plinths)


static func maze_skin_shell(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {},
		footprints: Dictionary = {}) -> Dictionary:
	## The WHOLE skin derivation, once: the raw shell (`exposed`), the panels
	## the coursing and pairing rules choose out of it (`faces`), and the module
	## each of those panels wears (`treatments`).
	##
	## Nothing here is a new rule. It is the same three functions in the same
	## order, hoisted to the one place that can hand the answer to every reader
	## of it -- `maze_stone_walls`, `maze_green_rim_walls` and the compiler's
	## skin audit each need two or three of these and each used to derive its
	## own copy, so `exposed_maze_stone_faces` alone ran four times per payload
	## and four more times per audit for four identical dictionaries.
	##
	## Byte-identity is by construction rather than by hope: each of the three
	## is a pure function of arguments that do not change between the callers,
	## so one derivation shared is the same dictionary each caller built for
	## itself. Nothing downstream mutates them -- the emitters read `faces[key]`
	## and `treatments[key]` and probe `exposed` -- and the bundle is a local
	## passed down one call stack, so it cannot survive the solve that made it.
	var exposed := exposed_maze_stone_faces(retained, solids, paved)
	var faces := _maze_stone_faces_from(exposed, retained, solids, plinths)
	return {
		"exposed": exposed,
		"faces": faces,
		"treatments": maze_skin_treatments(exposed, faces, walked, paved,
			footprints),
	}


static func _maze_stone_faces_from(exposed: Dictionary, retained: Dictionary,
		solids: Dictionary, plinths: Dictionary) -> Dictionary:
	## The coursing and cap-pairing half of `maze_stone_faces`, over a shell
	## already derived. `retained` and `solids` are still needed here: an odd
	## cap with no exposed mate leans over closed mass, and only those two sets
	## say what is closed.
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
		walked: Dictionary = {}, paved: Dictionary = {},
		footprints: Dictionary = {}) -> Dictionary:
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
	##
	## TASK I2 REPLACES THE SECOND ANSWER WITH A FOURTH, and the direction it
	## comes from is the user's own: "remove all stone from everywhere but the
	## ground floor of select buildings ... everything else should use actual
	## building assets", then, on the H2b result, "these are the parts that i
	## think we should remove: the cliffs". H2b's reading was that a tall bank is
	## HILLSIDE. The verdict is that a hillside standing inside a town is a cliff
	## in the town, whatever it is made of -- so a tall bank is not hillside at
	## all. It is the side of a BUILDING, and it takes building storeys:
	##
	## * FACADE -- every side face in a bank taller than STONE_BUDGET_BANDS,
	##   every course of it, foot to top. One authored 1.5 m x 3 m timber wall
	##   per panel, which is exactly one cell wide and exactly one storey tall.
	## * MASONRY keeps the LOW banks and nothing else. A face at or under the
	##   budget is at most one storey of coursed stone holding a terrace up,
	##   which is both the reviewer budget and the thing the user singled out as
	##   right: "the stone walls serving as one level in a house, and not
	##   overused in the city". The rate is therefore UNTOUCHED by this task --
	##   no low face becomes facade and no tall face becomes masonry.
	##
	## THE BANK HEIGHT IS THE ONLY DIAL, and that is deliberate. Every other
	## split the direction suggests -- above/below the street datum, rim against
	## interior, seeded stone bases on the mass -- would either need a datum this
	## file does not hold or would put stone back somewhere the verdict took it
	## out of. One number, measured per face, with the two answers on either side
	## of it.
	var out: Dictionary = {}
	for key_value: Variant in faces.keys():
		var key := key_value as Vector4i
		if key.w >= FACE_DIRECTIONS.size():
			out[key] = SkinTreatment.GREEN \
				if STONE_FACE_DIRECTIONS[key.w] == Vector3i.UP \
					and _maze_cap_is_free(key, faces[key] as Vector3i, exposed,
						walked, paved) \
				else SkinTreatment.MASONRY
			continue
		var tall := maze_bank_height(exposed, key) > STONE_BUDGET_BANDS
		if not tall:
			out[key] = SkinTreatment.MASONRY
			continue
		if not maze_natural_is_permitted():
			out[key] = SkinTreatment.FACADE
			continue
		# TASK H2c FIX 1. The cut's fallback: a tall bank the street crosses,
		# on a day the cut can no longer be expressed as stand-off, is coursed
		# rather than left as rock a body cannot pass. Dead today by
		# construction and live the moment the arithmetic above stops holding.
		out[key] = SkinTreatment.MASONRY \
			if not maze_natural_cut_is_expressible() \
				and maze_natural_face_is_cut(key, walked) \
			else SkinTreatment.NATURAL
	return _maze_demote_small_gardens(out, faces, exposed, footprints)


static func _maze_demote_small_gardens(treatments: Dictionary,
		faces: Dictionary, exposed: Dictionary,
		footprints: Dictionary = {}) -> Dictionary:
	## TASK I4, ANNOTATION 2 -- "we should only have grass in large areas like
	## plazas/gardens". THE GARDEN IS A FACT ABOUT THE RUN, and this is where a
	## run first exists.
	##
	## Every candidate green cap above is a PANEL. What an eye reads is the
	## connected piece of GROUND those panels floor -- laterally adjacent AT ONE
	## BAND, which is the same connectivity the village green is designated by, so
	## "is this a garden" and "is this the square" ask about the same shape. A run
	## that clears GARDEN_RUN_MINIMUM_CELLS and holds at least
	## GARDEN_RUN_MINIMUM_BLOCKS complete 2 x 2 blocks stays turf; everything
	## smaller becomes a plank terrace, which is a walked-looking deck rather than
	## a lawn on a chimney.
	##
	## DEMOTION IS PER PANEL AND A PAIR IS ONE PANEL, so the two cells a paired
	## cap floors can never disagree about what they are made of.
	##
	## TASK I4 ROUND 6 -- AND THE RUN IS MEASURED IN GROUND. A cell a building
	## already floors, or one with a gallery inside body height over it, is not a
	## piece of yard (`maze_cap_is_ground`), so it cannot lend its size to one:
	## counting it left 4/compact and 9/standard with two-cell threads of grass
	## that are exactly the patches annotation 2 retired.
	##
	## A BOARDED PANEL IS NEVER DEMOTED, and the arithmetic is why: a room's floor
	## board lies in the top 0.161 m of the cell's own band with its walking face
	## ON the boundary, which is exactly where `_maze_plank_terrace_transform`
	## would put a deck cap. Decking it would z-fight the board face for face. Its
	## turf quad sits 0.02 m inside the board and cannot be seen, so GREEN is the
	## one treatment that costs nothing there.
	var cover: Dictionary = {}
	var panel_cells: Dictionary = {}
	var boarded: Dictionary = {}
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		if int(treatments[key]) != SkinTreatment.GREEN:
			continue
		var cell := Vector3i(key.x, key.y, key.z)
		var cells: Array[Vector3i] = [cell]
		var partner := maze_green_cap_partner(key, faces[key] as Vector3i,
			exposed)
		if partner != Vector3i.ZERO:
			cells.append(cell + partner)
		panel_cells[key] = cells
		for member: Vector3i in cells:
			if maze_cap_is_boarded(footprints, member):
				boarded[key] = true
				continue
			if maze_cap_is_ground(footprints, member):
				cover[member] = true
	if cover.is_empty() and boarded.is_empty():
		return treatments
	var survivors := maze_garden_run_survivors(cover)
	for key_value: Variant in panel_cells.keys():
		var key := key_value as Vector4i
		if boarded.has(key):
			continue
		var cells := panel_cells[key] as Array
		var garden_run := false
		for member_value: Variant in cells:
			garden_run = garden_run or survivors.has(member_value as Vector3i)
		if not garden_run:
			treatments[key] = SkinTreatment.DECK
	return treatments


static func maze_garden_run_survivors(cover: Dictionary) -> Dictionary:
	## TASK I4, ANNOTATION 2 -- the cells of `cover` whose own RUN clears the
	## garden bar, as `cell -> true`. A run is laterally adjacent AT ONE BAND,
	## which is the connectivity the village green is designated by, so "is this
	## a garden" and "is this the square" ask about one shape.
	##
	## TASK I4 ROUND 6 factors it out of `_maze_demote_small_gardens` because
	## `maze_garden_cells` has to ask the SAME question of a slightly different
	## set. A panel that pairs a boarded cell with a bare one cannot be demoted
	## (see there), so its bare cell keeps its turf -- and if that cell's run is
	## two cells long it is exactly the thread annotation 2 retired, whatever the
	## panel wears. One derivation, asked twice.
	var run_of: Dictionary = {}
	var run_cells: Dictionary = {}
	var members: Array[Vector3i] = []
	members.assign(cover.keys())
	members.sort_custom(_cell_before)
	var next_run := 0
	for start: Vector3i in members:
		if run_of.has(start):
			continue
		var index := next_run
		next_run += 1
		var collected: Array[Vector3i] = []
		var frontier: Array[Vector3i] = [start]
		run_of[start] = index
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			collected.append(cell)
			for step: Vector3i in FACE_DIRECTIONS:
				var probe := cell + step
				if cover.has(probe) and not run_of.has(probe):
					run_of[probe] = index
					frontier.append(probe)
		run_cells[index] = collected
	var out: Dictionary = {}
	for index_value: Variant in run_cells.keys():
		var collected := run_cells[index_value] as Array
		if collected.size() < GARDEN_RUN_MINIMUM_CELLS \
				or _maze_run_block_count(collected, cover) \
					< GARDEN_RUN_MINIMUM_BLOCKS:
			continue
		for cell_value: Variant in collected:
			out[cell_value as Vector3i] = true
	return out


static func _maze_run_block_count(collected: Array,
		cover: Dictionary) -> int:
	## How many complete 2 x 2 blocks of the run's own cells it contains -- the
	## cheapest honest answer to "is this run anywhere two cells wide". Counted
	## off the cover set rather than off the run, which is the same thing: runs
	## are disjoint, so a 2 x 2 whose four cells are all covered is all one run.
	var blocks := 0
	for cell_value: Variant in collected:
		var cell := cell_value as Vector3i
		if cover.has(cell + Vector3i(1, 0, 0)) \
				and cover.has(cell + Vector3i(0, 0, 1)) \
				and cover.has(cell + Vector3i(1, 0, 1)):
			blocks += 1
	return blocks


static func maze_green_cap_partner(key: Vector4i, partner: Vector3i,
		exposed: Dictionary) -> Vector3i:
	## TASK I4, ANNOTATION 1 -- A LAWN NEVER LEANS.
	##
	## `_maze_stone_cap_partner` answers with either of two things and the caller
	## could not tell them apart: a genuine PAIR (the mate is an exposed cap cell
	## of its own, and the slab serves them both) or a LEAN (the mate owns no cap,
	## so the slab simply rests over the closed mass beside it). For a masonry
	## slab the lean is correct -- stone corbels. For a sheet of turf it is not,
	## and the census says what it costs: 4-6 cells a town wear grass they do not
	## own, 1-2 of them the top of a BUILDING, and because `maze_green_rim_walls`
	## can only dress a cell that owns a cap, EVERY bare turf edge measured in the
	## five review towns was on one of them.
	##
	## The lean is refused for GREEN caps only: the quad is bounded to its own
	## cell, exactly as fix 1 minor 2 already bounded an unpaired cap's long axis,
	## and for the same reason -- "a grass quad reaching over the void is a sheet
	## of lawn with nothing under it".
	##
	## The two branches are told apart by the rule that made them:
	## `_maze_stone_cap_partner`'s pairing branch REQUIRES `exposed.has(mate)` and
	## its leaning branch requires the opposite, so this one lookup is exact.
	if partner == Vector3i.ZERO:
		return Vector3i.ZERO
	return partner if exposed.has(Vector4i(key.x + partner.x,
		key.y + partner.y, key.z + partner.z, key.w)) else Vector3i.ZERO


static func maze_natural_is_permitted() -> bool:
	## TASK I2 -- THE CLIFF SWITCH, and it is off.
	##
	## The user annotated an I2-state frame with two marks: one on a coursed
	## stone storey under a green cap, "i like this part right now"; one on the
	## KayKit cliff shards, "these are the parts that i think we should remove:
	## the cliffs" -- and the ruling that followed took the rim allowance back
	## too. Zero shard faces anywhere in or on a town.
	##
	## A NAMED PREDICATE rather than a deleted branch, because what is being
	## retired is a TREATMENT and not the machinery under it. The shard's
	## coverage bounds, its street cut, its tail clamp and its three-band reach
	## are the repo's record of what a 4 m module on a 1.5 m lattice costs, they
	## are still proved by the suite against the descriptors, and the day some
	## rim really does want rock this is the one line that has to change. The
	## corpus reads `maze_skin_natural_panel_count = 0` while it says false, and
	## that zero is the pin.
	##
	## The world's own hillsides are untouched: `CliffDressing` hangs the same
	## module on real terrain cliffs through a different channel entirely, and a
	## village standing on a hill still has that hill around it.
	return false


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
	##
	## TASK I1 FIX 1 -- WHY THIS IS STILL ONE COLUMN WHERE `maze_natural_face_
	## is_cut` IS TWO, asked again with numbers this time. The straddle argument
	## that widened the NOSE test to both columns does not carry to the TAIL,
	## and the difference is what each clamp can reach. The nose clamp moves the
	## module 0.06 m along its own depth and cannot bare anything; the tail clamp
	## moves the module's BOTTOM EDGE, and a panel clads the course {y, y - 1}
	## whenever band y - 1's face is exposed too, so shortening it below
	## 2 x CELL_SIZE / (TOP + BASE) = 0.75 rise leaves part of that course as
	## bare rock -- the slit `NATURAL_ROCK_CUT_MIN_RISE` exists to forbid.
	##
	## Measured on the three towns fix round 1 was called for
	## (`i1f1/probe-capfix.log`): widening this test to the faced column would
	## newly offer the clamp 25 panels on 3/compact, 57 on 6/grand and 64 on
	## 10/grand, and on 21, 35 and 43 of those respectively the ceiling lands
	## UNDER that 0.75 floor with a two-band course above it. Widened naively,
	## every one of those is a hole in the mountain; widened with a course-aware
	## floor, none of them moves at all and the only thing that changes is that
	## `maze_skin_cut_tail_unclearable_count` stops meaning "a crossing no
	## cladding can open" and starts meaning nothing in particular.
	##
	## And the street the widening was proposed for is already answered: the
	## faced side is what the NOSE clamp is for, it fires on every one of these
	## panels, and a panel reaching 0.318 m into the cell it faces leaves 1.182 m
	## against a 0.795 m body. What actually shut the three cells was the cap
	## oversail, and `maze_stone_cap_juts_over_walk` closes it.
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
		exposed: Dictionary, walked: Dictionary,
		paved: Dictionary = {}) -> bool:
	## Does anybody WALK on either cell this sky-facing slab closes, and IS THERE
	## ROOM TO STAND ON IT? The mate is only asked when it is a capped cell in its
	## own right: a partner that is closed mass owns no cap, carries no surface,
	## and cannot be walked.
	##
	## TASK I4 ROUND 5, ITEM 3 opened the second question -- "it looks like there
	## is not enough headroom for the character between the two levels of
	## platforms" -- and could only ask it of the surface plan: a cap with a
	## public floor plate two bands over it leaves `1.5 - 0.161 = 1.339 m`
	## against the 2.244 m a body needs, so it is an UNDERCROFT and keeps its
	## stone rather than being dressed as a yard somebody could stand in.
	##
	## THAT CLAUSE NEVER FIRED. The r4+r5 review measured it: zero panels change
	## treatment on any of the five review towns, and the corpus `garden` and
	## `deck_caps` rows are byte-identical across the round. The reason is the
	## defect it was written for: the plate that pinches 12/compact's deck at
	## 1.339 m is a GALLERY FLOOR AUTHORED INSIDE A ROOM RECIPE, standing over a
	## column whose cells the surface plan does not claim -- so `paved` cannot see
	## it, and no cell-keyed set can.
	##
	## TASK I4 ROUND 6 MEASURED THAT CLAUSE AND LEFT IT AS IT IS. The r4+r5 review
	## found it INERT -- `capped_only_refusals = 0` and zero panel treatments
	## changed on all five review towns -- and the reason is the defect it was
	## written for: the plate that pinches 12/compact's deck at 1.339 m is a
	## GALLERY FLOOR AUTHORED INSIDE A ROOM RECIPE, standing over a column whose
	## cells the surface plan does not claim, so `paved` cannot see it and no
	## cell-keyed set can.
	##
	## THE ROUND-6 ANSWER IS NOT HERE, and that is deliberate. Reading the module
	## boxes at this point would demote a covered cap to MASONRY, and a masonry
	## slab on a top nobody walks is the one thing
	## `test_the_bench_tops_wear_the_town_s_own_materials` forbids outright --
	## "remove all stone from everywhere but the ground floor of select
	## buildings" is the direction this whole phase is under. So the cap keeps its
	## treatment and what changes is what the town does with it: a top a body
	## cannot stand on is not GROUND (`maze_garden_cells` drops it, so nothing is
	## planted there and it is not part of the square) and not a STANCE
	## (`maze_capped_stance_cells` drops it, so no corbel is measured against it
	## and no plank terrace rails itself as a platform over it). The geometry it
	## is measured against is the same in every case:
	## `maze_footprint_headroom` and `maze_cap_is_boarded`.
	##
	## `paved` is the three surface kinds that PLANK themselves -- a terrain
	## street or a stair overhead puts no plate in the air. It defaults to empty,
	## which keeps the pre-round answer for a caller that does not hold the
	## surface plan.
	if walked.has(Vector3i(key.x, key.y + 1, key.z)) \
			or paved.has(Vector3i(key.x, key.y + 2, key.z)):
		return false
	if partner == Vector3i.ZERO:
		return true
	var mate := Vector4i(key.x + partner.x, key.y + partner.y,
		key.z + partner.z, key.w)
	if not exposed.has(mate):
		return true
	return not walked.has(Vector3i(mate.x, mate.y + 1, mate.z)) \
		and not paved.has(Vector3i(mate.x, mate.y + 2, mate.z))


static func maze_stone_cap_jut_cells(key: Vector4i,
		partner: Vector3i) -> Array[Vector3i]:
	## TASK I1 FIX 1 -- the lattice cells a horizontal masonry slab reaches over
	## ALONG ITS OWN LENGTH that its panel does not own. Derived from the two
	## dials `_maze_stone_transform` builds a cap from -- the module's own
	## STONE_MODULE_HEIGHT laid flat, and the run its partner makes -- rather
	## than from the transform, so the audit and the payload cannot drift apart
	## silently. That is `maze_green_cap_jut_cells`'s rule and this is the same
	## question asked of the slab the grass quad replaced.
	##
	## EMPTY FOR EVERY PAIRED CAP, and the arithmetic says why: a pair's run is
	## 2 x CELL_SIZE = 3.0 m and the module laid flat is 3.0 m, so a paired slab
	## covers its two cells exactly. Only the UNPAIRED cap -- a 3 m module
	## centred on one 1.5 m cell -- reaches 0.75 m past each end, which is the
	## same overhang the green quad carried until H2c fix 1 minor 2 trimmed it.
	##
	## THE LONG AXIS ONLY, which is a statement about what the trim can move
	## rather than an oversight. The module measures 1.77 m across a 1.5 m cell,
	## so every cap oversails 0.135 m on its CROSS axis too; the cap branch of
	## the transform scales the long axis and nothing else, so a cross overlap
	## is not a thing this predicate could act on. It is also not a thing a body
	## meets -- 0.135 m off a 1.5 m cell leaves 1.365 m against a 0.795 m
	## capsule, where 0.75 m off it leaves 0.750 m and shuts the cell.
	var out: Array[Vector3i] = []
	if key.w < FACE_DIRECTIONS.size():
		return out
	var cell := Vector3i(key.x, key.y, key.z)
	# The axis the flat module sweeps along, read off the same `partner.x != 0`
	# branch the transform turns on.
	var axis := Vector3i.RIGHT if partner.x != 0 else Vector3i.BACK
	var half_long := STONE_MODULE_HEIGHT * 0.5
	var centre := (Vector3(cell) + Vector3(partner) * 0.5) \
		* FabricRecipe.CELL_SIZE
	var owned: Dictionary = {cell: true}
	if partner != Vector3i.ZERO:
		owned[cell + partner] = true
	# Both the slab and the cells are grid-aligned, so the overlap is one
	# interval test. A cell the slab merely TOUCHES is not covered by it -- that
	# is exactly the paired cap's own fit -- hence the tolerance.
	for along in range(-2, 3):
		var probe := cell + axis * along
		if owned.has(probe):
			continue
		var delta := Vector3(probe) * FabricRecipe.CELL_SIZE - centre
		if absf(delta.dot(Vector3(axis))) \
				< half_long + FabricRecipe.CELL_SIZE * 0.5 - 0.01:
			out.append(probe)
	return out


static func maze_stone_cap_juts_over_walk(key: Vector4i, partner: Vector3i,
		walked: Dictionary) -> bool:
	## TASK I1 FIX 1 -- does this slab reach over a cell the public realm WALKS?
	##
	## THE THIRD READING OF ONE DEFECT, and the first in the horizontal plane.
	## `maze_natural_face_rise_ceiling` clamps a rock module hanging into a
	## street below it and `maze_stone_face_overhangs_walk` trims the coursed
	## panel that does the same; both are modules taller than the band they clad,
	## burying the excess in what turns out to be an open street. A CAP is that
	## same 3 m module laid FLAT over a 1.5 m cell, so where it found no mate to
	## pair with it buries 0.75 m of itself in each neighbouring column -- and
	## where that column is a street, the slab stands in the walking space
	## instead. It leaves 0.750 m of a 1.5 m cell against a 0.795 m body, so the
	## capsule fits nowhere in the cell: that is exactly the three walked cells
	## the 48-town matrix reported at task I1's first landing (6/grand (-1,4,6)
	## and 10/grand (3,2,8) under a sky-facing cap, 3/compact (-5,3,-2) under a
	## floor-facing one).
	##
	## WHICH BANDS EACH KIND STANDS IN, because the two are not symmetric. The
	## slab is sunk STONE_CAP_HALF_DEPTH so its rock face is FLUSH with the
	## boundary it closes: a SKY-FACING cap therefore fills the top 0.66 m of its
	## own band, which is the head space of anybody walking that band, and a
	## FLOOR-FACING cap fills the bottom 0.66 m of it, which is the head space of
	## the band BELOW and the floor of the band it is in. Both of the second
	## kind's bands are asked, because a slab lying on a street's floor stops the
	## capsule as surely as one hanging over its head.
	if key.w < FACE_DIRECTIONS.size():
		return false
	var reach := 1 if STONE_FACE_DIRECTIONS[key.w] == Vector3i.UP else 2
	for jut: Vector3i in maze_stone_cap_jut_cells(key, partner):
		for step in reach:
			if walked.has(Vector3i(jut.x, key.y - step, jut.z)):
				return true
	return false


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
		walked: Dictionary = {},
		shell: Dictionary = {},
		world_seed: int = 0) -> EnvironmentInstancePayload:
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
	##
	## `shell` is `maze_skin_shell()` for the same five arguments, and an empty
	## one means "derive it here". A caller that already holds the shell -- the
	## payload, and the compiler's audit, both of which need it for their own
	## reasons anyway -- hands it down instead of paying for a second identical
	## copy. It is never legitimately empty when passed: the bundle always
	## carries its three keys, empty town or not.
	var out := EnvironmentInstancePayload.new()
	var derived := shell if not shell.is_empty() \
		else maze_skin_shell(retained, solids, paved, plinths, walked)
	var faces := derived.faces as Dictionary
	var treatments := derived.treatments as Dictionary
	var exposed := derived.exposed as Dictionary
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		var cell := Vector3i(key.x, key.y, key.z)
		var direction := STONE_FACE_DIRECTIONS[key.w]
		var partner := faces[key] as Vector3i
		var cap_partner := maze_green_cap_partner(key, partner, exposed)
		var stable_id := StringName("maze-stone/%d/%d/%d/%d" % [key.x, key.y,
			key.z, key.w])
		match int(treatments[key]):
			SkinTreatment.GREEN:
				# TASK I2. The turf takes the ground palette's own multiplier
				# rather than the atlas raw -- see GARDEN_TURF_TINT.
				# TASK I4: and it never leans -- see `maze_green_cap_partner`.
				out.add(TERRAIN_GREEN_CAP,
					_maze_green_cap_transform(cell, cap_partner),
					GARDEN_TURF_TINT, stable_id)
			SkinTreatment.DECK:
				# TASK I4, ANNOTATION 2. A free top too small to be a yard: the
				# authored board the town's own galleries are floored with, laid
				# over exactly the run this panel closes. ONE module per panel,
				# so task C5b's instance-for-panel identity is untouched.
				out.add(maze_plank_terrace_module(cap_partner),
					_maze_plank_terrace_transform(cell, cap_partner),
					Color.WHITE, stable_id)
			SkinTreatment.FACADE:
				# TASK I2. A building storey, and nothing is clamped: the module
				# closes its panel exactly and stands entirely behind the
				# boundary. `_maze_facade_transform` carries the argument.
				out.add(maze_facade_module(key, world_seed),
					_maze_facade_transform(key, direction), Color.WHITE,
					stable_id)
			SkinTreatment.NATURAL:
				out.add(NATURAL_ROCK_FACE,
					_maze_natural_face_transform(key, direction,
						maze_natural_face_is_cut(key, walked),
						maze_natural_face_rise_ceiling(key, walked)),
					Color.WHITE, stable_id)
			_:
				# ONE FLAG, TWO AXES (task I1 fix 1): each predicate answers for
				# the kind of panel it is about and false for the other, so the
				# module is cut back to the boundary it closes whenever the
				# public realm is in the space it would otherwise reach into --
				# downward for a side panel, sideways for a cap.
				out.add(MAZE_STONE_MODULE,
					_maze_stone_transform(cell, direction, partner,
						maze_stone_face_overhangs_walk(key, walked) \
							or maze_stone_cap_juts_over_walk(key, partner,
								walked)),
					Color.WHITE, stable_id)
	assert(out.validate())
	return out


static func maze_facade_family(key: Vector4i, world_seed: int) -> StringName:
	## TASK I2 -- WHICH TIMBER FAMILY a clad mass face belongs to.
	##
	## The district field, and the same call every real room's recipe is chosen
	## through (`WarrenSpatialFabricCompiler.architectural_district_theme`), read
	## at the panel's own lattice column. That is the whole alignment argument
	## for palette: a fake storey and the house across the alley are in the same
	## architectural district, so they draw from the same authored family, and a
	## block does not change colour where the mass ends and the building begins.
	##
	## The BAND is deliberately not part of it. A district is a plan fact in x/z
	## -- the compiler passes `room.lattice_origin` whose y varies storey by
	## storey and gets the same answer -- so a clad face keeps one family from
	## its foot to its top.
	return WarrenSpatialFabricCompiler.architectural_district_theme(
		Vector3i(key.x, 0, key.z), world_seed)


static func maze_facade_module(key: Vector4i, world_seed: int) -> StringName:
	## Which authored wall this panel wears: the family's one-cell pool, indexed
	## by the panel's own lattice position.
	##
	## A SUM AND NOT A HASH, which is the compiler's own idiom for facade phase
	## (`_room_recipe_id` hashes the horizontal slot plus the storey the same
	## way) and which matters here for a reason a hash would spoil. Stepping one
	## cell along a run steps one entry along the pool, so a face reads as an
	## alternating rhythm of window and boarded panel -- a wall -- where a hash
	## would scatter windows at random and give the "window spam" the iterate
	## ruling names. Stepping one COURSE up steps two entries, because the
	## coursing is two bands, so the storey above is offset rather than
	## identical.
	##
	## `key.w` joins the sum so the two faces meeting at a mass corner start on
	## different entries instead of turning the corner with the same module.
	var pool := SettlementFabricProgram.cell_facade_pool(
		maze_facade_family(key, world_seed))
	return pool[posmod(key.x + key.z + key.y + key.w + world_seed, pool.size())]


static func _maze_facade_transform(key: Vector4i,
		direction: Vector3i) -> Transform3D:
	## The authored timber wall hung on one panel of the shell.
	##
	## VERTICALLY it is the masonry module's own idiom and the same span: the
	## module is STONE_MODULE_HEIGHT tall, its top lands on the course boundary
	## at `(band + 1) x CELL_SIZE`, and it therefore clads exactly the two bands
	## the coursing gave it. That is one storey -- `WarrenBuildingParcel
	## .STOREY_BANDS` bands -- so a fake storey is the same height as a real one
	## and a run of clad mass reads as floors rather than as panelling.
	##
	## HORIZONTALLY it is the ROOM RECIPE's idiom rather than the skin's: the
	## module is pinned by its OUTER FACE to the boundary plane, exactly as
	## `FabricModuleProgram.facade_aligned_transform` pins a house's wall, so its
	## full 0.553 m depth stands INSIDE the mass and nothing at all reaches into
	## the street. (FACADE_FRONT_DEPTH itself is 0.277 m -- the FRONT HALF of
	## the deepest module, |position.z| off its own origin, not the module's
	## whole depth; see below.) Two consequences worth stating out loud:
	##
	## * IT CANNOT OPEN THE SHELL. The module measures 1.500 m across against a
	##   1.5 m cell and 3.000 m tall against a 3.0 m course, so it closes its own
	##   panel exactly, with no jitter, no scale and no coverage argument to
	##   make. The rock it replaces needed a two-part proof and three clamps for
	##   the same job.
	## * IT CANNOT SHUT A STREET. The coursed masonry panel straddles its
	##   boundary and stands 0.332 m into the cell it faces; the rock shard stood
	##   0.375 m plus its relief; this stands 0.000 m. Every trim in this file
	##   exists because a module reached into somewhere a body walks, and a
	##   facade panel reaches into the faced cell not at all. Down its OWN column
	##   it occupies the outer 0.553 m (its own measured `size.z`, not
	##   FACADE_FRONT_DEPTH), which leaves 0.947 m of a 1.5 m cell against a
	##   0.795 m body -- so no trim is applied and the clearance row is the
	##   measurement that says so.
	##
	## The yaw is `atan2(outward.x, outward.z)`, the same four-way turn the rock
	## face and the bench rim take, which puts the module's authored front (its
	## local +Z) outward.
	var outward := Vector3(direction)
	var origin := Vector3(key.x, 0.0, key.z) * FabricRecipe.CELL_SIZE \
		+ outward * (FabricRecipe.CELL_SIZE * 0.5 - FACADE_FRONT_DEPTH)
	origin.y = float(key.y + 1) * FabricRecipe.CELL_SIZE - STONE_MODULE_HEIGHT
	return Transform3D(Basis(Vector3.UP, atan2(outward.x, outward.z)), origin)


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


static func maze_plank_terrace_railings(retained: Dictionary,
		solids: Dictionary, paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}, shell: Dictionary = {},
		footprints: Dictionary = {}) -> EnvironmentInstancePayload:
	## TASK I4, ANNOTATION 2 -- what makes a demoted top read as a TERRACE.
	##
	## The first render of the deck caps (`i4r1/f1-big.png`) is the reason this
	## exists: a bare board laid over a one-cell top is a plank floating in the
	## air, which is the very thing annotation 3 is about. The direction's own
	## words are "the plank-deck terrace treatment (walkable-looking, matches the
	## deck culture)", and what makes a deck read as walkable in this town is its
	## RAIL -- `maze_terrace_railings` already puts the same authored guard round
	## every released plot crown, and this is that rule applied to the caps the
	## garden bar demoted.
	##
	## One rail per exposed lateral edge of every deck cell, at the deck's own
	## walking surface. Pairs are merged into the authored 3 m guard exactly as
	## the crown railings merge, so a two-cell run reads as one rail rather than
	## as two fences meeting at a post.
	##
	## TASK I4 ROUND 6, ITEM 3 -- AND A TOP NOBODY CAN STAND ON TAKES NO RAIL.
	## The rail is what says "this is a platform"; over a deck cap with a room's
	## gallery board 1.339 m above it that is exactly the wrong thing to say, and
	## it is the user's own note. `maze_capped_stance_cells` is the one
	## derivation that decides what a stance is, so the rail and the headroom
	## census cannot disagree.
	var out := EnvironmentInstancePayload.new()
	var derived := shell if not shell.is_empty() \
		else maze_skin_shell(retained, solids, paved, plinths, walked,
			footprints)
	var faces := derived.faces as Dictionary
	var treatments := derived.treatments as Dictionary
	var exposed := derived.exposed as Dictionary
	var stances := maze_capped_stance_cells(derived, footprints)
	var up_index := STONE_FACE_DIRECTIONS.find(Vector3i.UP)
	var edges: Dictionary = {}
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		if int(treatments[key]) != SkinTreatment.DECK:
			continue
		var partner := maze_green_cap_partner(key, faces[key] as Vector3i,
			exposed)
		var covered: Array[Vector3i] = [Vector3i(key.x, key.y, key.z)]
		if partner != Vector3i.ZERO:
			covered.append(Vector3i(key.x, key.y, key.z) + partner)
		for cell: Vector3i in covered:
			if not exposed.has(Vector4i(cell.x, cell.y, cell.z, up_index)) \
					or not stances.has(cell):
				continue
			for index in FACE_DIRECTIONS.size():
				if exposed.has(Vector4i(cell.x, cell.y, cell.z, index)):
					edges[Vector4i(cell.x, cell.y, cell.z, index)] = true
	var edge_keys: Array[Vector4i] = []
	edge_keys.assign(edges.keys())
	edge_keys.sort_custom(_face_before)
	var paired: Dictionary = {}
	for key: Vector4i in edge_keys:
		if paired.has(key):
			continue
		paired[key] = true
		var direction := FACE_DIRECTIONS[key.w]
		var tangent := Vector3i.BACK if direction.x != 0 else Vector3i.RIGHT
		var mate := Vector4i(key.x + tangent.x, key.y, key.z + tangent.z, key.w)
		var span := 0
		if edges.has(mate) and not paired.has(mate):
			paired[mate] = true
			span = 1
		var boundary := (Vector3(key.x, 0.0, key.z) \
			+ Vector3(direction) * 0.5) * FabricRecipe.CELL_SIZE
		var origin := boundary + Vector3(tangent) * FabricRecipe.CELL_SIZE \
			* 0.5 * float(span)
		origin.y = float(key.y + 1) * FabricRecipe.CELL_SIZE
		out.add(PLANK_RAILING_MEDIUM if span == 1 else PLANK_RAILING,
			Transform3D(Basis(Vector3.UP, atan2(-float(tangent.z),
				float(tangent.x))), origin), Color.WHITE,
			StringName("maze-deck-rail/%d/%d/%d/%d" % [key.x, key.y, key.z,
				key.w]))
	assert(out.validate())
	return out


static func maze_plank_terrace_module(partner: Vector3i) -> StringName:
	## TASK I4, ANNOTATION 2. Which board a deck cap lays: the 3 m gallery floor
	## over a PAIR, the 1.5 m deck over a cap that closes one cell. Both are one
	## cell across and both are the same authored 0.161 m board, so the run is the
	## only thing that changes.
	return PLANK_TERRACE_CAP_PAIR if partner != Vector3i.ZERO \
		else PLANK_TERRACE_CAP


static func _maze_plank_terrace_transform(cell: Vector3i,
		partner: Vector3i) -> Transform3D:
	## The board laid over the run this panel closes, walking face up and flush
	## with the cell's own top.
	##
	## THE PIVOTS DIFFER AND THE CONSTANT SAYS SO: the 3 m gallery floor is
	## centred across its span, while the 1.5 m deck is authored on its own local
	## +X edge (`sfv_deck_floor_s_001.tres` runs x = -1.503 -> -0.003). The single
	## board is therefore shifted by PLANK_TERRACE_CAP_OFFSET along its own local
	## +X, which is `_add_plank_tile`'s correction for the same module.
	##
	## SUNK BY ITS OWN THICKNESS, unlike the turf quad it replaces: the quad has
	## no body and is dropped GREEN_CAP_LIFT under the boundary so the terrain
	## below wins the z-fight, but a board 0.161 m thick laid at the boundary
	## would stand proud of every street it adjoins. Its TOP is the boundary and
	## its body is in the band underneath, which is the same rule
	## `_maze_facade_transform` uses for a wall and `_add_plank_tile` for a floor.
	## THE YAW IS THE BOARD'S OWN AXIS, NOT THE QUAD'S. The turf quad's long axis
	## is its local +Z and `_maze_green_cap_transform` turns it with
	## `atan2(axis.x, axis.z)` accordingly; both deck boards run their length
	## along local +X instead (3.000 x 0.161 x 1.500). Copying the quad's turn
	## laid a paired board ACROSS its own pair -- 3 m over the cross axis and
	## 1.5 m along the run -- which covers one cell of the pair and one cell of
	## each neighbour it does not own. `atan2(-axis.z, axis.x)` puts local +X on
	## the run, which is the two cells the panel closes and no other.
	var axis := Vector3(partner) if partner != Vector3i.ZERO else Vector3.BACK
	var origin := Vector3(cell) * FabricRecipe.CELL_SIZE \
		+ Vector3(partner) * FabricRecipe.CELL_SIZE * 0.5
	origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE \
		- PLANK_TERRACE_THICKNESS
	var basis := Basis(Vector3.UP, atan2(-axis.z, axis.x))
	if partner == Vector3i.ZERO:
		origin += basis * Vector3(PLANK_TERRACE_CAP_OFFSET, 0.0, 0.0)
	return Transform3D(basis, origin)


static func maze_green_rim_walls(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}, shell: Dictionary = {},
		footprints: Dictionary = {}) -> EnvironmentInstancePayload:
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
	##
	## `shell` is `maze_skin_shell()` for the same five arguments and follows
	## the same rule `maze_stone_walls` states: empty means derive it here, and
	## a caller that already holds it hands it down rather than building an
	## identical second copy of the same three dictionaries.
	var out := EnvironmentInstancePayload.new()
	var derived := shell if not shell.is_empty() \
		else maze_skin_shell(retained, solids, paved, plinths, walked,
			footprints)
	var exposed := derived.exposed as Dictionary
	if exposed.is_empty():
		return out
	var treatments := derived.treatments as Dictionary
	var depth_scale := FabricRecipe.CELL_SIZE / GREEN_RIM_DEPTH
	# TASK I4 ROUND 5, ITEM 4. The boundary set, by junction class, derived once
	# and read by the audit as well -- see `maze_green_rim_faces`.
	for face: Vector4i in maze_green_rim_faces(derived, walked, paved,
			footprints):
		var cell := Vector3i(face.x, face.y, face.z)
		out.add(GREEN_RIM_EDGE,
			_maze_green_rim_transform(cell, FACE_DIRECTIONS[face.w],
				depth_scale, maze_green_rim_standoff(face, treatments)),
			GARDEN_TURF_TINT,
			StringName("maze-rim/%d/%d/%d/%d" % [cell.x, cell.y, cell.z,
				face.w]))
	assert(out.validate())
	return out


static func maze_green_rim_faces(shell: Dictionary, walked: Dictionary = {},
		paved: Dictionary = {}, footprints: Dictionary = {}) -> Array[Vector4i]:
	## TASK I4 ROUND 5, ITEM 4 -- EVERY BOUNDARY A LAWN HAS, BY JUNCTION CLASS,
	## in sorted lattice order. One derivation, read by the payload and by the
	## audit, so the two cannot drift.
	##
	## "the edge of the grass could be textured better too (with the grass lip,
	## or perhaps a plank of wood)". The lip was already there -- since round 1
	## every DROP a lawn has turns one. What had nothing on it is the other
	## junction, and the square's own mouth is the clearest instance of it: where
	## the green meets a plank street AT ITS OWN HEIGHT, the neighbouring cell is
	## MASS (it is what the street stands on), so the boundary is not exposed, no
	## rim was laid, and the turf simply stopped at a razor cut against the boards.
	## Measured on the review corpus: 7, 14, 9, 14 and 12 such boundaries a town.
	##
	## THE RULE, and it is a rule about the FAR SIDE rather than about the lawn:
	##
	## * DROP -- nothing across the boundary at the lawn's own band. The lip
	##   hangs its roll over the fall, which is what it was drawn for.
	## * LEVEL -- mass across the boundary carrying a walked or paved floor one
	##   band up, whose surface is the lawn's own plane to the millimetre (that
	##   levelness is `maze_plaza_entries`' own definition of an entrance). The
	##   same lip, and its roll lands ON the boundary exactly as it does at a drop
	##   -- `_maze_green_rim_transform` pulls the piece back by its own scaled
	##   overhang -- so the roll buries itself in the mass under the pavement
	##   instead of oversailing it, and what shows is a rolled turf edge meeting
	##   the boards.
	## * BURIED -- mass across the boundary with nothing walkable on it: the lawn
	##   runs into a wall and there is no edge to finish.
	##
	## TASK I4 ROUND 6 ADDS THE THIRD LEVEL CASE, and it is item 4a's other half.
	## A cell whose own top is FLOORED BY A BOARD -- a room's authored gallery or
	## court floor lying on the lawn's own plane -- yields its turf at
	## `_maze_cap_is_free` and keeps its stone under the boards. Left there the
	## lawn beside it would stop at exactly the razor cut this rule exists to
	## finish, against exactly the timber the user's frame shows four bright lines
	## of. The board's walking face stands one board's thickness over the plane,
	## which is the same junction a plank street at the lawn's own height makes,
	## so it takes the same lip.
	var faces := shell.faces as Dictionary
	var treatments := shell.treatments as Dictionary
	var exposed := shell.exposed as Dictionary
	var up_index := STONE_FACE_DIRECTIONS.find(Vector3i.UP)
	var out: Array[Vector4i] = []
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		if int(treatments[key]) != SkinTreatment.GREEN:
			continue
		var partner := maze_green_cap_partner(key, faces[key] as Vector3i,
			exposed)
		var covered: Array[Vector3i] = [Vector3i(key.x, key.y, key.z)]
		if partner != Vector3i.ZERO:
			covered.append(Vector3i(key.x, key.y, key.z) + partner)
		for cell: Vector3i in covered:
			# A cell a building already FLOORS carries no visible turf -- its quad
			# is 0.02 m inside the board -- so it has no edge of its own to
			# finish, and a lip laid there would be geometry under a floor.
			if not exposed.has(Vector4i(cell.x, cell.y, cell.z, up_index)) \
					or maze_cap_is_boarded(footprints, cell):
				continue
			for index in FACE_DIRECTIONS.size():
				var face := Vector4i(cell.x, cell.y, cell.z, index)
				if exposed.has(face):
					out.append(face)
					continue
				var beside := cell + FACE_DIRECTIONS[index]
				if walked.has(beside + Vector3i.UP) \
						or paved.has(beside + Vector3i.UP) \
						or maze_cap_is_boarded(footprints, beside):
					out.append(face)
	return out


static func maze_cap_is_boarded(footprints: Dictionary,
		cell: Vector3i) -> bool:
	## TASK I4 ROUND 6, ITEM 4a -- is this cell's own top FLOORED by an authored
	## board lying on it, rather than merely built over somewhere above?
	##
	## "there are gaps between the grass textures." Round 5 proved the turf quads
	## innocent three ways -- the mesh is a flat 4 x 4 grid with no bevel, the
	## transforms abut to the micron, and inflating every plate by 8 per cent
	## leaves the lines exactly where they were -- and found the real cause: a
	## BUILDING UNIT'S OWN FLOOR BOARD, 0.161 m thick, standing with its base ON
	## the lawn's plane, so the turf is under the boards rather than beside them
	## and what shows is four bright timber lines across the grass.
	##
	## THE TWO TESTS, and the second is what makes this surgical. The board's body
	## has to reach this cell's own top plane within one board's thickness EITHER
	## WAY -- a room's floor is laid the way this file lays a deck cap, walking
	## face ON the boundary and body sunk beneath it, so the turf quad at
	## GREEN_CAP_LIFT is inside the board rather than under it, and a gallery
	## 1.339 m overhead is a headroom question `_maze_cap_is_free`'s own clause
	## owns -- and it has to FLOOR the cell rather than clip its edge. Measured on
	## the review corpus, the two populations do not overlap: 162 cells covered
	## 1.00 of their own area by a `sfv.fabric.floor.l.001` or a
	## `sfv.fabric.gallery.floor.m.001`, and every other overlap is 0.40 or less
	## -- a roof eave over the lawn's edge, a wall's own footing or a brace's
	## foot. Half a cell is the bar, and nothing sits near it.
	return maze_footprint_floor_cover(footprints, cell) \
		>= CAP_BOARD_COVER_FRACTION


static func maze_footprint_floor_cover(footprints: Dictionary,
		cell: Vector3i) -> float:
	## How much of this cell's own top plane an authored floor really covers, as
	## a fraction of the cell's area -- see `maze_cap_is_boarded`.
	var boxes := footprints.get("boxes", []) as Array
	if boxes.is_empty():
		return 0.0
	var by_cell := footprints.get("by_cell", {}) as Dictionary
	var plane := float(cell.y + 1) * FabricRecipe.CELL_SIZE
	var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
	var half := FabricRecipe.CELL_SIZE * 0.5
	var out := 0.0
	var seen: Dictionary = {}
	for band in [cell.y, cell.y + 1]:
		var bucket := by_cell.get(Vector3i(cell.x, band, cell.z),
			PackedInt32Array()) as PackedInt32Array
		for index: int in bucket:
			if seen.has(index):
				continue
			seen[index] = true
			var box := boxes[index] as AABB
			if box.position.y > plane + GREEN_RIM_LEVEL_REACH \
					- FOOTPRINT_EPSILON \
					or box.position.y + box.size.y \
						< plane - GREEN_RIM_LEVEL_REACH + FOOTPRINT_EPSILON:
				continue
			var overlap := maxf(0.0, minf(centre.x + half,
					box.position.x + box.size.x) \
				- maxf(centre.x - half, box.position.x)) \
				* maxf(0.0, minf(centre.z + half,
					box.position.z + box.size.z) \
					- maxf(centre.z - half, box.position.z))
			out = maxf(out, overlap \
				/ (FabricRecipe.CELL_SIZE * FabricRecipe.CELL_SIZE))
	return out


static func maze_perimeter_frontage_sites(retained: Dictionary,
		solids: Dictionary, paved: Dictionary, walked: Dictionary,
		world_seed: int = 0) -> Array[Dictionary]:
	## TASK I4, ANNOTATION 6 -- "instead of a sheer wall at the edge of the city
	## it would look better if there were ground story buildings or a market
	## around the perimeter".
	##
	## FABRIC DRESSING ONLY, per the controller's ruling: no plot, no parcel and
	## no room moves. What changes is what stands on the ground OUTSIDE the town's
	## own outward wall, which is meadow the plot model does not own.
	##
	## A SITE IS FOUR FACTS, each of them a way a stall could be wrong:
	##
	## 1. THE FACE LOOKS OUT. Its column across the boundary carries no mass at
	##    any band -- open terrain rather than the next block -- so the wall
	##    behind the stall really is the town's edge.
	## 2. IT IS THE TOWN'S OWN GROUND STOREY, and that is stricter than "the
	##    lowest panel of its own column". A terrace bench three storeys up is
	##    also the lowest panel of ITS column, and the first pass put a
	##    fishmonger's table halfway up a retaining wall because of it
	##    (`i4r1/f3-big.png`). The fabric does not hold the terrain height
	##    outside its own footprint, so the one datum it can honestly stand a
	##    stall on is the band where the town's own mass reaches its lowest --
	##    which is where the massif meets the ground it was cut into.
	## 3. THE GROUND IS ONE LEVEL ACROSS THE WHOLE FRONT. Every column of the
	##    window shares one foot band, which is what "both feet on the ground"
	##    means for a piece 4.5 m wide: a stall spanning a step would float at one
	##    end and bury itself at the other.
	## 4. NOBODY WALKS THERE. No public floor and no walked cell in front of the
	##    wall, at the foot band or the one above it, so a frontage can never
	##    stand in the mouth of a street leaving the town.
	##
	## The window is THREE CELLS because the vocabulary is: the market stall
	## measures 4.474 m across and the framed awning 4.241 m, against 4.5 m of
	## lattice. Two-cell remainders take the fishmonger's table (2.064 m) and
	## one-cell remainders a barrel, so a short front is dressed rather than
	## skipped.
	var out: Array[Dictionary] = []
	# The town's own footprint and the foot band of every column in it.
	var foot: Dictionary = {}
	for cell_value: Variant in retained.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		foot[column] = mini(int(foot.get(column, cell.y)), cell.y)
	for cell_value: Variant in solids.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		foot[column] = mini(int(foot.get(column, cell.y)), cell.y)
	if foot.is_empty():
		return out
	var ground_band := 1 << 30
	for band_value: Variant in foot.values():
		ground_band = mini(ground_band, int(band_value))
	# Fact 1 and fact 2, per face: every outward-looking boundary of the town's
	# own FOOTPRINT at the ground band.
	#
	# THE FOOTPRINT AND NOT THE STONE SHELL, which the first pass used and which
	# measured 20 outward faces on a town whose whole southern flank is a wall.
	# Most of a maze town's edge at ground level is a BUILDING's own outward
	# wall -- a unit, not a panel of the retained skin -- so a rule that reads
	# the shell can only dress the stretches nobody built on, which is the
	# opposite of "ground story buildings around the perimeter". The footprint
	# boundary is the town's edge whatever clads it.
	var sites: Dictionary = {}
	var columns: Array[Vector2i] = []
	columns.assign(foot.keys())
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	for column: Vector2i in columns:
		if int(foot[column]) != ground_band:
			continue
		var cell := Vector3i(column.x, ground_band, column.y)
		if not retained.has(cell) and not solids.has(cell):
			continue
		for index in FACE_DIRECTIONS.size():
			var direction := FACE_DIRECTIONS[index]
			var front := Vector2i(column.x + direction.x,
				column.y + direction.z)
			if foot.has(front):
				continue
			sites[Vector3i(column.x, index, column.y)] = ground_band
	if sites.is_empty():
		return out
	# The runs, per face, along that face's own cross axis.
	for face_index in FACE_DIRECTIONS.size():
		var direction := FACE_DIRECTIONS[face_index]
		var cross := Vector3i(direction.z, 0, direction.x)
		var members: Array[Vector3i] = []
		for slot_value: Variant in sites.keys():
			var slot := slot_value as Vector3i
			if slot.y == face_index:
				members.append(slot)
		members.sort_custom(_cell_before)
		var claimed: Dictionary = {}
		for slot: Vector3i in members:
			if claimed.has(slot):
				continue
			var previous := slot - cross
			if sites.has(previous) \
					and int(sites[previous]) == int(sites[slot]):
				continue
			# One run: every next column along the cross axis that stands on the
			# same foot band (fact 3).
			var run: Array[Vector3i] = []
			var walker := slot
			while sites.has(walker) and int(sites[walker]) == int(sites[slot]) \
					and not claimed.has(walker):
				claimed[walker] = true
				run.append(walker)
				walker += cross
			_append_frontage_windows(out, run, direction, int(sites[slot]),
				paved, walked, world_seed)
	return out


static func _append_frontage_windows(out: Array[Dictionary],
		run: Array[Vector3i], direction: Vector3i, band: int,
		paved: Dictionary, walked: Dictionary, world_seed: int) -> void:
	## One run of outward ground-storey wall, cut into windows and dressed. The
	## widest piece the run can hold is tried first so a long front reads as a
	## market rather than as a row of barrels; what is left over takes the
	## narrower vocabulary.
	var index := 0
	var wide_taken := 0
	# Which wide piece THIS RUN starts with, rolled once off the first wide
	# window it actually dresses. See the alternation note below for why it is a
	# run-level fact and not a per-window one.
	var wide_start := -1
	while index < run.size():
		var width := mini(PERIMETER_WINDOW_CELLS, run.size() - index)
		var window: Array[Vector3i] = []
		for step in width:
			window.append(run[index + step])
		# THE POOL IS CHOSEN BEFORE THE GATE, because the gate is about what the
		# piece OCCUPIES and the pieces differ: a barrel clears a street a market
		# stall stands in the middle of.
		var pool := PERIMETER_WIDE_FRONTAGE if width \
			>= PERIMETER_WINDOW_CELLS \
			else PERIMETER_NARROW_FRONTAGE if width == 2 \
			else PERIMETER_SINGLE_FRONTAGE
		if not _frontage_window_is_free(window, direction, band, paved, walked,
				pool):
			index += 1
			continue
		var anchor := window[0]
		var key := Vector4i(anchor.x, band, anchor.z, anchor.y)
		# TASK I4 ROUND 2. THE WORLD SEED IS SPENT HERE, and until this round it
		# was carried through `maze_perimeter_frontage`,
		# `maze_perimeter_frontage_sites` and this function without ever being
		# read -- three signatures asserting a dependency the code did not have.
		# The window key is a TOWN-LOCAL lattice anchor, so without the seed two
		# towns that happen to present a front at the same local column dress it
		# the same way and skip it in the same places; with it they do not. It is
		# the same argument `maze_facade_module` already makes for which timber
		# wall a panel wears.
		var roll := _face_noise(key, PERIMETER_FRONTAGE_SALT, world_seed)
		if roll < PERIMETER_FRONTAGE_ODDS:
			# ALTERNATE THE WIDE PIECES ALONG A RUN. A free roll put two
			# identical striped market tents shoulder to shoulder on the
			# production town's south front (`i4r1/r4-se-town-big.png`), which
			# reads as a fairground rather than as a street of shopfronts. The
			# seed still chooses which piece a run STARTS with; the alternation
			# decides the rest, so no two adjacent wide frontages are the same
			# module and a run reads as a parade of different fronts.
			#
			# TASK I4 FIX. THE SEED IS ROLLED ONCE PER RUN, and the first pass
			# rolled it per WINDOW and then added `wide_taken` to it -- which
			# does not alternate anything. Two neighbours whose own rolls differ
			# by one land on the SAME module after the offset, and 7/large's
			# south front shipped three identical tents shoulder to shoulder
			# (`i4r1/r6-z-market.png` against the fix). Alternation is a fact
			# about the SEQUENCE, so the sequence needs one starting point and
			# not one per term.
			var pick := int(_face_noise(key, PERIMETER_FRONTAGE_SALT + 1,
				world_seed) * float(pool.size())) % pool.size()
			if width >= PERIMETER_WINDOW_CELLS:
				if wide_start < 0:
					wide_start = pick
				pick = posmod(wide_start + wide_taken, pool.size())
				wide_taken += 1
			out.append({
				"asset": pool[pick],
				"cells": window,
				"direction": direction,
				"band": band,
				"depth": PERIMETER_FRONTAGE_DEPTH[pool[pick]],
			})
		index += width


static func _frontage_window_is_free(window: Array[Vector3i],
		direction: Vector3i, band: int, paved: Dictionary,
		walked: Dictionary, pool: Array[StringName]) -> bool:
	## Fact 4: NOBODY WALKS WHERE THE PIECE STANDS -- over the whole volume the
	## piece really occupies, which is the fix for the one town this rule shipped
	## a stall into.
	##
	## THE FIRST PASS PROBED A GUESS: one cell out and two bands up, the same
	## box for a barrel and for a market tent. The clearance row measured what
	## that costs on 11/standard -- a `sfm.stall.variant.001` standing in three
	## walked cells of a street at band 2, the town's only red column in the
	## 48-town matrix (`offset_free=3`, `gates_offset=2` against ceilings of 0).
	## The stall's own numbers say why: its BAKED COLLIDER HULL is
	## 5.280 x 4.550 x 3.661 against a visual AABB of 4.474 x 4.019 x 3.199, so
	## the piece reaches 3.43 m out from the wall it fronts -- into the THIRD
	## cell of open ground -- stands 4.55 m tall over THREE bands, and overhangs
	## its own three-cell window by 1.14 m at each end. The probe looked at none
	## of that.
	##
	## The gate now asks the vocabulary instead of assuming: the widest, tallest
	## and deepest envelope in the pool the window would draw from
	## (PERIMETER_FRONTAGE_CLEARANCE, read off the baked colliders and the
	## descriptors together), converted to the lattice the walked cells live on.
	## The pool rather than the piece, so the answer cannot depend on a roll --
	## a window either has room for its whole class or is skipped.
	##
	## AND ONE BAND BELOW. A body standing on the band under the piece's foot is
	## 2.244 m tall and puts its head 0.744 m into that foot band, so the cell
	## below the stall's ground is as much a street as the cell beside it.
	var half_width := 0.0
	var rise := 0.0
	var reach := 0.0
	for asset_id: StringName in pool:
		var envelope: Vector3 = PERIMETER_FRONTAGE_CLEARANCE[asset_id]
		half_width = maxf(half_width, envelope.x)
		rise = maxf(rise, envelope.y)
		reach = maxf(reach, envelope.z)
	var depth_cells := int(ceilf(reach / FabricRecipe.CELL_SIZE))
	var top_lift := int(ceilf(rise / FabricRecipe.CELL_SIZE)) - 1
	# How far past the window's own end columns the piece hangs, in cells: the
	# centres of a `size` window span `(size - 1) * CELL`, and the cell `k`
	# columns beyond an end begins `(k - 0.5) * CELL` past that end's centre.
	var spread := float(window.size() - 1) * FabricRecipe.CELL_SIZE * 0.5
	var overhang := 0
	while half_width > spread \
			+ (float(overhang) + 0.5) * FabricRecipe.CELL_SIZE:
		overhang += 1
	var cross := Vector3i(direction.z, 0, direction.x)
	var first := window[0] as Vector3i
	for step in range(-overhang, window.size() + overhang):
		var column := Vector3i(first.x, 0, first.z) + cross * step
		for out_step in range(1, depth_cells + 1):
			var front := Vector3i(column.x + direction.x * out_step, band,
				column.z + direction.z * out_step)
			for lift in range(-1, top_lift + 1):
				var probe := front + Vector3i.UP * lift
				if paved.has(probe) or walked.has(probe):
					return false
	return true


static func maze_perimeter_frontage(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, walked: Dictionary = {},
		world_seed: int = 0) -> EnvironmentInstancePayload:
	## The frontages themselves, standing on the outside ground with their backs
	## on the town's own wall plane. Every piece carries a `maze-frontage/` id
	## that no reading of the skin mistakes for cladding -- the same separation
	## the garden dressing and the outcroppings already have.
	##
	## THE YAW puts each module's authored front (local +Z) outward, which is the
	## turn every other outward-facing module in this file takes, and the origin
	## is pushed out by the piece's own measured half-depth so its VISIBLE back
	## plane lands on the wall. The stall's baked collider is 0.231 m deeper than
	## that and does reach into the mass; the correction, and why leaving it there
	## is the right answer, are at PERIMETER_FRONTAGE_DEPTH.
	##
	## THE DATUM is the foot band's own floor, `band x CELL_SIZE` -- the bottom of
	## the lowest cell of mass in that column, which is where the terrain the town
	## is cut into meets it. Every module in the pool is authored standing on
	## y = 0, so a piece stands on the ground rather than hovering over it.
	var out := EnvironmentInstancePayload.new()
	for site: Dictionary in maze_perimeter_frontage_sites(retained, solids,
			paved, walked, world_seed):
		var window := site.cells as Array
		var direction := site.direction as Vector3i
		var outward := Vector3(direction)
		var first := window[0] as Vector3i
		var last := window[window.size() - 1] as Vector3i
		var centre := (Vector3(first.x, 0.0, first.z) \
			+ Vector3(last.x, 0.0, last.z)) * 0.5 * FabricRecipe.CELL_SIZE
		var origin := centre + outward * (FabricRecipe.CELL_SIZE * 0.5 \
			+ float(site.depth))
		origin.y = float(site.band) * FabricRecipe.CELL_SIZE
		var yaw := atan2(outward.x, outward.z)
		out.add(StringName(site.asset), Transform3D(Basis(Vector3.UP, yaw),
			origin), Color.WHITE,
			StringName("maze-frontage/%d/%d/%d/%d" % [first.x, int(site.band),
				first.z, first.y]))
		# TASK I4 ROUND 5, ITEM 2. A canopy on the town's own front is a MARKET,
		# so it carries a market's goods -- see STALL_GOODS_STATIONS.
		for goods: Dictionary in maze_stall_goods(StringName(site.asset), origin,
				yaw, Vector4i(first.x, int(site.band), first.z, first.y)):
			out.add(StringName(goods.asset), goods.transform as Transform3D,
				Color.WHITE, StringName("maze-stall-goods/%d/%d/%d/%d/%s" % [
					first.x, int(site.band), first.z, first.y,
					String(goods.station)]))
	assert(out.validate())
	return out


static func maze_stall_goods(canopy: StringName, anchor: Vector3, yaw: float,
		key: Vector4i) -> Array[Dictionary]:
	## TASK I4 ROUND 5, ITEM 2 -- "the market stall is not one of the stocked
	## ones; it is empty. we should use the stocked ones."
	##
	## What stands UNDER a canopy this file has just placed, as
	## `{asset, station, transform}` records. Empty for anything that is not a
	## canopy, so a well, a tree, a table or a barrel is untouched.
	##
	## The stations, the counter and the hanging goods are measured off the
	## canopy's own seven collider boxes -- the whole argument is at
	## STALL_COUNTER. Each goods station takes a seeded piece from STALL_GOODS
	## with an adjacent-differs rule along the row, so a stall never reads as
	## three identical barrels; the counter and the hanging string are fixed,
	## because a market stall has ONE counter and it is the thing that says the
	## stall is stocked.
	var out: Array[Dictionary] = []
	if not STALL_CANOPIES.has(canopy):
		return out
	var basis := Basis(Vector3.UP, yaw)
	out.append({"asset": STALL_COUNTER, "station": &"counter",
		"transform": Transform3D(basis, anchor + basis * STALL_COUNTER_STATION)})
	var hanging := maze_stall_hanging_station(canopy)
	if hanging != Vector3.ZERO:
		out.append({"asset": STALL_HANGING_GOODS, "station": &"hanging",
			"transform": Transform3D(basis, anchor + basis * hanging)})
	var previous := &""
	for index in STALL_GOODS_STATIONS.size():
		var roll := _face_noise(Vector4i(key.x, key.y, key.z, key.w + index),
			STALL_GOODS_SALT)
		var offset := int(roll * float(STALL_GOODS.size())) % STALL_GOODS.size()
		var asset := STALL_GOODS[offset]
		if asset == previous:
			asset = STALL_GOODS[(offset + 1) % STALL_GOODS.size()]
		previous = asset
		var station: Vector3 = STALL_GOODS_STATIONS[index]
		out.append({"asset": asset,
			"station": StringName("goods%d" % index),
			"transform": Transform3D(Basis(Vector3.UP, yaw + roll * TAU),
				anchor + basis * station)})
	return out


static func maze_stall_hanging_station(canopy: StringName) -> Vector3:
	## TASK I4 ROUND 6 -- WHERE THIS CANOPY'S STRING HANGS, or `Vector3.ZERO` when
	## it cannot carry one. The whole argument and both bounds are at
	## STALL_HANGING_STATION.
	##
	## THE FIT IS ASSERTED RATHER THAN ASSUMED, which is the half of round 5 that
	## was missing: the station is checked against the canopy's own rise every
	## time it is asked for, so a third canopy entering STALL_CANOPIES with no
	## measured rise, or with a rise the string cannot hang inside, gets nothing
	## instead of a number transcribed from a different piece.
	if not STALL_CANOPY_RISE.has(canopy):
		return Vector3.ZERO
	var rise := float(STALL_CANOPY_RISE[canopy])
	if STALL_HANGING_STATION.y + STALL_HANGING_LOCAL_TOP > rise \
			or STALL_HANGING_STATION.y - STALL_HANGING_LOCAL_DROP \
				< NATURAL_ROCK_CUT_BODY_HEIGHT:
		return Vector3.ZERO
	return STALL_HANGING_STATION


static func maze_stall_goods_count(canopy: StringName) -> int:
	## How many pieces this canopy is stocked with: the counter, the three goods
	## and -- only where the canopy is tall enough to hang one -- the string.
	if not STALL_CANOPIES.has(canopy):
		return 0
	return STALL_GOODS_STATIONS.size() + 1 \
		+ int(maze_stall_hanging_station(canopy) != Vector3.ZERO)


static func maze_public_floor_bearer_sites(retained: Dictionary,
		solids: Dictionary, paved: Dictionary, walked: Dictionary,
		capped: Dictionary = {}) -> Array[Dictionary]:
	## TASK I4, ANNOTATION 3 -- "a bunch of random planks on the sides of these
	## buildings", and this is what they really are.
	##
	## The producing channel is `_append_plank_tiles`: the public realm's own
	## floors, tiled with the authored 1.5 m and 3 m boards. Most of them are the
	## town's galleries and courts and read as what they are, but a floor cell
	## with NOTHING UNDER IT renders as a board hanging in the air off a wall --
	## which is exactly the annotation's words. It was traced to this channel by
	## suppression: with `_append_plank_tiles` returning nothing, the annotated
	## board and one other are the only things that leave the frame.
	##
	## THE FIX IS THIS BRANCH's OWN RULE, not a new one. "We cant have floating
	## buildings" (user reference batch 2) and "every overhang renders its
	## brackets" are already how the jetties, the bays and the skywalks are built:
	## an unborne plate gets the same measured corbel laid ACROSS the wall it
	## springs from. Sites are returned rather than instances so the audit and the
	## payload count the same thing.
	##
	## BORNE means mass directly under the cell -- retained rock, a building, or
	## another public floor, any of which is a thing the board can rest on.
	##
	## THE HEADROOM GATE is the skywalk's, and the arithmetic is the same piece
	## of timber: the corbel's underside sits at
	## `band x CELL_SIZE - PLANK_Y_OFFSET's drop - SKYWALK_BEARER_DROP`, which
	## leaves 3.0 - 0.591 = 2.409 m over a street two bands down against the
	## 2.284 m a body needs -- 125 mm. One band down leaves 0.909 m and is
	## refused. That case cannot arise on a sealed town (the BOARD alone already
	## leaves 1.38 m there, so the clearance row would be red before this ran),
	## and it is gated and counted anyway rather than argued away.
	##
	## TASK I4 ROUND 5, ITEM 3 -- AND A STREET IS NOT THE ONLY THING A BODY
	## STANDS ON. "it looks like there is not enough headroom for the character
	## between the two levels of platforms." The gate above asked ONE question --
	## is the cell below a walked cell of the public realm -- and a lawn is not
	## one, nor is a plank terrace: both are CAPS, whose surface is the top of the
	## cell BELOW them. So the same 0.909 m the rule refuses over a street could
	## be hung over a garden or over a terrace without a word.
	##
	## `capped` is every cell whose TOP a body stands on -- the garden cells and
	## the deck cells of the same shell -- so a cap two bands under the plate puts
	## its surface one band under it, which is the case the street rule already
	## refuses. It defaults to empty, which keeps the pre-round answer for a
	## caller that does not hold the shell.
	##
	## THE CLAUSE IS GATED AND HAS NEVER FIRED, and the round-5 report's claim
	## that it refused two corbels on 4/compact was that town's PRE-EXISTING
	## "not borne" pair, not this branch. The r4+r5 review measured it directly:
	## `capped_only_refusals = 0` on all five review towns, and the corpus's
	## `floor_bearers` row is byte-identical across that round. It is live the
	## moment the arithmetic changes -- exactly as the one-band street case above
	## has been since round 1 -- and until then it costs nothing and claims
	## nothing. Round 6 narrows `capped` further (a cap with a real module inside
	## body height of its surface is no longer dressed at all, so it is no longer
	## a stance), which makes the clause rarer rather than commoner.
	var out: Array[Dictionary] = []
	if paved.is_empty():
		return out
	var cells: Array[Vector3i] = []
	cells.assign(paved.keys())
	cells.sort_custom(_cell_before)
	for cell: Vector3i in cells:
		var below := cell + Vector3i.DOWN
		if retained.has(below) or solids.has(below) or paved.has(below):
			continue
		if walked.has(below) or capped.has(below + Vector3i.DOWN):
			out.append({"cell": cell, "direction": Vector3i.ZERO,
				"refused": true})
			continue
		var borne := false
		for step: Vector3i in FACE_DIRECTIONS:
			var side := cell + step
			# The wall the board springs from: mass beside it at its own band or
			# at the band its bearer hangs in. Anything else is open air and a
			# corbel there would be the floating plate this rule is about.
			if not (retained.has(side) or solids.has(side) \
					or retained.has(side + Vector3i.DOWN) \
					or solids.has(side + Vector3i.DOWN)):
				continue
			out.append({"cell": cell, "direction": step, "refused": false})
			borne = true
		if not borne:
			out.append({"cell": cell, "direction": Vector3i.ZERO,
				"refused": true})
	return out


static func maze_capped_stance_cells(shell: Dictionary,
		footprints: Dictionary = {}) -> Dictionary:
	## TASK I4 ROUND 5, ITEM 3 -- every cell whose TOP is a surface a body stands
	## on, as `cell -> true`: the garden cells and the plank terraces, which is
	## the GREEN and DECK halves of the same cap set. Derived off the shell the
	## payload is built from, so the headroom gate and the caps cannot drift.
	##
	## TASK I4 ROUND 6 -- AND A TOP WITH A GALLERY OVER IT IS NOT ONE. "it looks
	## like there is not enough headroom for the character between the two levels
	## of platforms." The user's own frame is a room recipe's gallery floor board
	## 1.339 m over a DECK CAP, and a body needs 2.244: nobody stands there. Two
	## things follow and both are the point of the note -- the floor bearer no
	## longer measures its corbels against a surface that is not one, and
	## `maze_plank_terrace_railings` no longer RAILS it, so a covered top stops
	## advertising itself as a platform and reads as the undercroft floor it is.
	##
	## Measured on the review corpus before the change: 36 capped stances with an
	## authored module inside body height -- gallery boards, braces, chimneys,
	## dormer windows and hanging ivy. `footprints` defaults to empty, which
	## keeps the pre-round answer for a caller that does not hold the plan.
	var faces := shell.faces as Dictionary
	var treatments := shell.treatments as Dictionary
	var exposed := shell.exposed as Dictionary
	var out: Dictionary = {}
	for key_value: Variant in faces.keys():
		var key := key_value as Vector4i
		var treatment := int(treatments[key])
		if treatment != SkinTreatment.GREEN and treatment != SkinTreatment.DECK:
			continue
		var cell := Vector3i(key.x, key.y, key.z)
		if _maze_cap_is_stance(footprints, cell):
			out[cell] = true
		var partner := maze_green_cap_partner(key, faces[key] as Vector3i,
			exposed)
		if partner != Vector3i.ZERO \
				and _maze_cap_is_stance(footprints, cell + partner):
			out[cell + partner] = true
	return out


static func _maze_cap_is_stance(footprints: Dictionary,
		cell: Vector3i) -> bool:
	## Is this cap's own top a surface a body can really stand on -- nothing
	## authored inside the height a body needs over it?
	return float(maze_footprint_headroom(footprints, cell,
		float(cell.y + 1) * FabricRecipe.CELL_SIZE,
		NATURAL_ROCK_CUT_BODY_HEIGHT).rise) == INF


static func maze_public_floor_bearers(retained: Dictionary,
		solids: Dictionary, paved: Dictionary, walked: Dictionary,
		capped: Dictionary = {}) -> EnvironmentInstancePayload:
	## The corbels themselves, one per site, with a `maze-floor-bearer/` id that
	## no reading of the public surface mistakes for a board: the surface payload
	## keeps its own instance-for-cell identity and its own tests exactly as they
	## are, and this rides `terrace_retaining_payload` -- the payload the corpus
	## sweep's clearance row commits, so a corbel hung into a street turns that
	## row red instead of shipping quietly.
	var out := EnvironmentInstancePayload.new()
	for site: Dictionary in maze_public_floor_bearer_sites(retained, solids,
			paved, walked, capped):
		if bool(site.refused):
			continue
		var cell := site.cell as Vector3i
		var direction := site.direction as Vector3i
		var outward := Vector3(direction)
		var cross := Vector3(-outward.z, 0.0, outward.x)
		# Laid ACROSS the bearing, the way the skywalk's and the outcropping's
		# bearers are and for the same reason: two corbels reaching outward from
		# opposite walls of a one-cell plate would pass through each other.
		var origin := Vector3(cell) * FabricRecipe.CELL_SIZE \
			+ outward * (FabricRecipe.CELL_SIZE * 0.5 - SKYWALK_BEARER_DEPTH \
				* 0.5) + cross * (SKYWALK_BEARER_REACH * 0.5)
		origin.y = float(cell.y) * FabricRecipe.CELL_SIZE + PLANK_Y_OFFSET \
			- SKYWALK_BEARER_DROP
		out.add(SKYWALK_BEARER, Transform3D(Basis(Vector3.UP,
			atan2(-cross.z, cross.x)), origin), Color.WHITE,
			StringName("maze-floor-bearer/%d/%d/%d/%d/%d" % [cell.x, cell.y,
				cell.z, direction.x, direction.z]))
	assert(out.validate())
	return out


static func maze_garden_rim_face_count(shell: Dictionary,
		walked: Dictionary = {}, paved: Dictionary = {},
		footprints: Dictionary = {}) -> int:
	## TASK I4, ANNOTATION 1 -- THE CONSISTENCY ROW's left-hand side: how many
	## turf edges a town HAS, counted off the cell sets rather than off the
	## payload. Every lateral boundary of every cell a green cap floors where the
	## neighbour is not mass -- which is exactly the boundary a body standing on
	## the lawn would fall off.
	##
	## `maze_green_rim_walls` emits one piece per such boundary and nothing else,
	## so `count - rim instances` is zero while the audit and the payload agree,
	## and positive the moment a piece the rule counted fails to reach the
	## renderer. The compiler publishes the difference as
	## `maze_garden_rim_deficit`.
	##
	## ROUND-2 CORRECTION -- WHAT THIS IS NOT. It is not the pin for a BARE TURF
	## EDGE, and the round-1 report and this docstring both said it was. Both
	## sides of the subtraction walk the same cell sets through the same
	## `maze_green_cap_partner`, so an edge that goes bare because its cell owns
	## no cap is invisible to the left-hand side exactly as it is to the right,
	## and the deficit stays at zero. This is an AUDIT-AGAINST-PAYLOAD row. The
	## bare-edge class is pinned by `capless == 0` in
	## `test_no_lawn_is_laid_over_a_building`, which counts garden cells that own
	## no cap of their own -- the one number that really does go positive when a
	## lawn gets an edge no rim can dress.
	##
	## TASK I4 ROUND 5, ITEM 4 -- AND IT IS NO LONGER "the exposed ones". The
	## boundary set is now `maze_green_rim_faces`, the same derivation the payload
	## lays its pieces from, and it carries the LEVEL junctions this round
	## finished as well as the drops. `walked` and `paved` default to empty, which
	## keeps the pre-round answer for a caller that does not hold the surface plan
	## -- and the compiler, which does, passes them.
	return maze_green_rim_faces(shell, walked, paved, footprints).size()


static func maze_green_rim_standoff(face: Vector4i,
		treatments: Dictionary) -> float:
	## TASK I4, ANNOTATION 1 -- how far a rim stands out from its own lattice
	## boundary, which is exactly how far the panel UNDER it does. The arithmetic
	## and the reason are at GREEN_RIM_MASONRY_STANDOFF.
	##
	## THE PANEL IS ALWAYS THERE TO ASK. A capped cell is the top of its own
	## column's exposed run, so `_maze_stone_faces_from` counts zero faces above
	## it, `0 % STONE_COURSE_BANDS == 0`, and the cell's own side face is kept as
	## a panel rather than swallowed by the course above. A face that is somehow
	## not a panel keeps the boundary, which is the pre-I4 answer.
	if not treatments.has(face):
		return GREEN_RIM_FACADE_STANDOFF
	match int(treatments[face]):
		SkinTreatment.MASONRY:
			return GREEN_RIM_MASONRY_STANDOFF
		SkinTreatment.NATURAL:
			# Unreachable while `maze_natural_is_permitted()` is false. The
			# shard's nose plane is at local z = 1.0 and its origin sits
			# NATURAL_ROCK_FACE_DEPTH_CENTRE behind the boundary, so its NOMINAL
			# proud-ness is the difference; the seeded relief moves it either way
			# per panel and a rim cannot follow that without becoming a per-panel
			# roll. Stated here so the day the cliffs come back the rim has a
			# number and a caveat rather than a surprise.
			return NATURAL_ROCK_NOSE_LOCAL_Z - NATURAL_ROCK_FACE_DEPTH_CENTRE
		_:
			return GREEN_RIM_FACADE_STANDOFF


static func _maze_green_rim_transform(cell: Vector3i, direction: Vector3i,
		depth_scale: float, stand_off: float) -> Transform3D:
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
	##
	## TASK I4: `stand_off` moves the whole piece outward so the roll lands on the
	## OUTER FACE of the panel below rather than on the abstract lattice plane --
	## see `maze_green_rim_standoff` and GREEN_RIM_MASONRY_STANDOFF. It is never
	## more than that panel's own proud-ness, so the rim reaches past the lattice
	## boundary exactly as far as the wall it caps and no further.
	var outward := Vector3(direction)
	var origin := Vector3(cell) * FabricRecipe.CELL_SIZE \
		+ outward * (FabricRecipe.CELL_SIZE * 0.5 + stand_off - GREEN_RIM_FRONT \
			* depth_scale)
	origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_RIM_LIFT
	var basis := Basis(Vector3.UP, atan2(outward.x, outward.z))
	basis.x = basis.x * GREEN_CAP_CROSS_SCALE
	basis.z = basis.z * depth_scale
	return Transform3D(basis, origin)


static func maze_garden_cells(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}, shell: Dictionary = {},
		footprints: Dictionary = {}) -> Dictionary:
	## TASK I2 -- every lattice cell whose TOP is a garden, as `cell -> true`.
	##
	## One entry per cell rather than per panel: a green cap covers its own cell
	## and the neighbour it was paired with, and a yard is a piece of ground, not
	## a slab. Read off the shell the payload already derived, so the set of
	## planted cells and the set of green-capped cells cannot drift apart.
	##
	## TASK I4 ROUND 6, ITEM 4a -- AND A TOP A BUILDING ALREADY FLOORS IS NOT
	## GROUND. "there are gaps between the grass textures." Round 5 proved the
	## turf quads innocent three ways and found the cause: a room's own floor
	## board lays its walking face on EXACTLY this plane -- measured, base
	## `plane - 0.1611`, top `plane + 0.0000`, which is the same transform this
	## file gives a deck cap -- so the turf quad at GREEN_CAP_LIFT lies 0.02 m
	## inside the board and what shows is the timber. Those cells were being
	## counted as yard: planted on, designated as part of the square, and left
	## with a razor-cut edge where the lawn beside them stopped. They are a
	## BUILDING'S FLOOR, and this is where the fabric stops calling them ground.
	##
	## THE CAP ITSELF IS NOT TOUCHED, and that is not an oversight. The quad is
	## invisible under the board; the two things that could replace it are a deck
	## board (exactly coincident with the room's own -- a z-fight) and a masonry
	## slab (which `test_the_bench_tops_wear_the_town_s_own_materials` forbids on
	## a top nobody walks, and rightly: this phase's direction is to remove
	## stone). What had to change is what the town DOES with the cell.
	##
	## A COVERED TOP IS NOT GROUND EITHER, for item 3's reason: a cap with an
	## authored module inside body height over its surface -- a gallery board at
	## 1.339 m, a brace at 0.894 m, a chimney at 1.500 m, a dormer at 0.220 m --
	## is somewhere nobody can stand, so nothing is planted on it and it cannot be
	## the square.
	var derived := shell if not shell.is_empty() \
		else maze_skin_shell(retained, solids, paved, plinths, walked,
			footprints)
	var faces := derived.faces as Dictionary
	var treatments := derived.treatments as Dictionary
	var exposed := derived.exposed as Dictionary
	var out: Dictionary = {}
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		if int(treatments[key]) != SkinTreatment.GREEN:
			continue
		var cell := Vector3i(key.x, key.y, key.z)
		if maze_cap_is_ground(footprints, cell):
			out[cell] = true
		# TASK I4: the pair only, never the lean -- see `maze_green_cap_partner`.
		var partner := maze_green_cap_partner(key, faces[key] as Vector3i,
			exposed)
		if partner != Vector3i.ZERO \
				and maze_cap_is_ground(footprints, cell + partner):
			out[cell + partner] = true
	# AND THE GARDEN BAR AGAIN, over the ground that is left. A panel pairing a
	# boarded cell with a bare one keeps its GREEN treatment because decking it
	# would z-fight the room's own board, so its bare cell can survive the
	# demotion as a two-cell thread of grass -- which is exactly the patch
	# annotation 2 retired. `maze_garden_run_survivors` is the same derivation
	# the demotion uses.
	return maze_garden_run_survivors(out)


static func maze_cap_is_ground(footprints: Dictionary,
		cell: Vector3i) -> bool:
	## TASK I4 ROUND 6 -- is this capped cell's top really a piece of GROUND?
	##
	## Not if a building already floors it (`maze_cap_is_boarded`, item 4a) and
	## not if a building stands over it inside the height a body needs
	## (`maze_footprint_headroom`, item 3). Both are asked of the plan's own
	## per-placement boxes, because both defects are authored modules standing
	## outside the cells their unit declares -- which is task I4 round 5's first
	## concern, and the one thing no cell-keyed rule in this file could see.
	return not maze_cap_is_boarded(footprints, cell) \
		and float(maze_footprint_headroom(footprints, cell,
			float(cell.y + 1) * FabricRecipe.CELL_SIZE,
			NATURAL_ROCK_CUT_BODY_HEIGHT).rise) == INF


static func maze_garden_run_count(garden: Dictionary) -> int:
	## TASK I4, ANNOTATION 2 -- how many separate pieces of ground a town's
	## garden is, at the same lateral-at-one-band connectivity the demotion and
	## the village green both use. Published beside the cell count so "the garden
	## shrank" and "the garden broke up" stay two different readings.
	var seen: Dictionary = {}
	var runs := 0
	var cells: Array[Vector3i] = []
	cells.assign(garden.keys())
	cells.sort_custom(_cell_before)
	for start: Vector3i in cells:
		if seen.has(start):
			continue
		runs += 1
		seen[start] = true
		var frontier: Array[Vector3i] = [start]
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			for step: Vector3i in FACE_DIRECTIONS:
				var probe := cell + step
				if garden.has(probe) and not seen.has(probe):
					seen[probe] = true
					frontier.append(probe)
	return runs


static func maze_plaza_entries(plaza: Dictionary,
		walked: Dictionary) -> Dictionary:
	## TASK I3 -- WHERE A STREET MEETS THE GREEN, as `plaza cell -> true`.
	##
	## A garden cell's ground is the TOP of its own cell, at
	## `(cell.y + 1) x CELL_SIZE`; a walked public cell's floor is the BOTTOM of
	## its own, at `cell.y x CELL_SIZE`. The two surfaces are therefore level
	## when the walked cell sits one band UP and one cell across -- and that is
	## an entrance: you walk off the pavement straight onto the grass without a
	## step. Anything else is a wall, a drop or a climb.
	var out: Dictionary = {}
	for cell_value: Variant in plaza.keys():
		var cell := cell_value as Vector3i
		for step: Vector3i in FACE_DIRECTIONS:
			if walked.has(cell + step + Vector3i.UP):
				out[cell] = true
				break
	return out


static func maze_plaza_threshold_openings(plan: SettlementFabricPlan,
		surface_plan: PublicRealmSurfacePlan = null) -> Array[Dictionary]:
	## TASK I4 ROUND 4 -- THE BOUNDARIES A SQUARE IS ENTERED THROUGH, as
	## `{cell, direction}` records naming the STREET cell and the face of it that
	## looks onto the green. The public realm's guard rule opens exactly these,
	## the way a door's landing already opens its own.
	##
	## THE DEFECT THIS EXISTS FOR, measured on the round-3 corpus: every mouth of
	## every plaza whose street is a STRUCTURAL_COURT had a fence across it (4 of
	## 4 on 12/compact, 4 of 4 on 4/compact, 4 of 6 on 3/standard, 2 of 6 on
	## 7/large -- the rest are terrain streets, which are never guarded). Neither
	## crown nor plank terrace railing was ever involved. `_build_guards` asks
	## "is there a claimed floor across this boundary", and the lawn is not a
	## claim: it is a green cap on retained mass, one band down and one cell
	## across, which the fabric owns and the realm cannot see.
	##
	## AND THERE IS NO FALL THERE. `maze_plaza_entries`' own arithmetic is that a
	## mouth's turf top, `(cell.y + 1) x CELL_SIZE`, is the street's own floor,
	## `street.y x CELL_SIZE`, to the millimetre -- that levelness is the whole
	## definition of an entrance. A guard rail across it is a fence across a
	## doorway, in both the render and the collider, which is the difference
	## between a lawn beside a lane and a square you walk into.
	##
	## SCOPED TO THE VILLAGE GREEN'S OWN MOUTHS and nothing else: an ordinary
	## yard's edge keeps every rail it has. `plaza` is the designated run, so the
	## set is empty on a town with no square and on a square no street reaches.
	var out: Array[Dictionary] = []
	if plan == null:
		return out
	var surfaces := surface_plan if surface_plan != null else plan.surface_plan
	if surfaces == null:
		return out
	var retained := plan.retained_terrace_cells
	var solids := plan.transformed_cells(&"solid")
	var plinths := plinth_faces(retained, solids,
		plan.transformed_cells(&"terrain_bearing"))
	var paved := public_floor_cells(surfaces)
	var walked := walked_floor_cells(surfaces)
	var garden := maze_garden_cells(retained, solids, paved, plinths, walked,
		{}, maze_module_footprints(plan))
	var plaza := maze_village_green_cells(garden, walked)
	if plaza.is_empty():
		return out
	var mouths: Array[Vector3i] = []
	mouths.assign(maze_plaza_entries(plaza, walked).keys())
	mouths.sort_custom(_cell_before)
	for mouth: Vector3i in mouths:
		for step: Vector3i in FACE_DIRECTIONS:
			if not walked.has(mouth + step + Vector3i.UP):
				continue
			# The street's own face back toward the green it stands beside.
			out.append({"cell": mouth + step + Vector3i.UP,
				"direction": -step})
	return out


static func maze_village_green_cells(garden: Dictionary,
		walked: Dictionary = {}) -> Dictionary:
	## TASK I2, USER ANNOTATION -- THE VILLAGE GREEN. "this should be more
	## integrated in the city, like a grass plaza in the center."
	##
	## The largest connected run of garden cells in the town, or empty when the
	## largest reaches fewer than VILLAGE_GREEN_MINIMUM_CELLS. Connected means
	## laterally adjacent AT THE SAME BAND: two benches a storey apart are two
	## terraces, and a plaza is one surface you can cross.
	##
	## Ties are broken by the run's own sorted first cell rather than by which
	## key the dictionary happened to yield first, so the designation is a pure
	## function of the cell set and a re-solve names the same plaza.
	##
	## TASK I3 ADDS THE MISSING HALF, and it is the concern task I2's own report
	## raised as its third: the designation was a SHAPE question and nothing
	## else, on the argument that the widest surviving shoulder of a hill town is
	## its centre. MEASURED, that argument fails on the towns it matters most on.
	## Every connected garden run of the four planner towns, with the number of
	## streets that reach it:
	##
	## | town | run the size rule picks | streets into it | best entered run |
	## | 12/compact | 36 cells | **0** | 17 cells, 8 streets |
	## | 4/compact | 36 cells | **0** | 8 cells, 3 streets |
	## | 3/standard | 30 cells | 6 | the same 30 |
	## | 9/standard | 17 cells | 7 | the same 17 |
	## | 7/large | 20 cells | **0** | 18 cells, 3 streets |
	##
	## On three of five towns the size rule was naming a rooftop shoulder nobody
	## can walk onto. A square is a place you ARRIVE at, so the rule is now
	## "the largest run a street enters, and the largest run overall only when no
	## run has a street" -- reachability first, size within it. On the two
	## standard towns it picks exactly what the old rule picked.
	##
	## `walked` empty keeps the pre-I3 answer, so a caller that does not hold the
	## surface plan gets the size rule rather than a plaza with no entrances.
	##
	## Ties are broken by the run's own sorted first cell rather than by which
	## key the dictionary happened to yield first, so the designation is a pure
	## function of the cell set and a re-solve names the same plaza.
	var seen: Dictionary = {}
	var cells: Array[Vector3i] = []
	cells.assign(garden.keys())
	cells.sort_custom(_cell_before)
	var best: Dictionary = {}
	var best_entered: Dictionary = {}
	var best_shaped: Dictionary = {}
	for start: Vector3i in cells:
		if seen.has(start):
			continue
		var run: Dictionary = {start: true}
		var frontier: Array[Vector3i] = [start]
		seen[start] = true
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			for step: Vector3i in FACE_DIRECTIONS:
				var neighbor := cell + step
				if not garden.has(neighbor) or seen.has(neighbor):
					continue
				seen[neighbor] = true
				run[neighbor] = true
				frontier.append(neighbor)
		if run.size() > best.size():
			best = run
		var entered := not maze_plaza_entries(run, walked).is_empty()
		if run.size() > best_entered.size() and entered:
			best_entered = run
		if run.size() > best_shaped.size() and entered \
				and _maze_run_block_count(run.keys(), run) \
					>= GARDEN_RUN_MINIMUM_BLOCKS:
			best_shaped = run
	# TASK I4 -- AND IT HAS TO BE A SHAPE. Task I3 fixed WHERE the square is (the
	# run a street can reach) and its own report then measured that the answer is
	# still not a square: `interior = 0` on three of four planner towns, which is
	# a RIBBON threading between blocks. The designation now asks the same "is
	# this anywhere two cells wide" question the garden bar asks, at the same
	# strength, and prefers a run that passes it.
	#
	# THE FALLBACK IS DELIBERATE AND THE REPORT SAYS SO. A town whose only
	# street-entered runs are threads keeps the largest of them rather than
	# losing its square altogether -- a green with no shape is still where the
	# town gathers, and the alternative is a designation that silently fails.
	# Widening those runs is a PLOT question, which this round may not touch.
	var chosen := best_shaped if not best_shaped.is_empty() \
		else best_entered if not best_entered.is_empty() else best
	return chosen if chosen.size() >= VILLAGE_GREEN_MINIMUM_CELLS else {}


static func maze_plaza_centre_feature(plaza: Dictionary,
		entries: Dictionary) -> Dictionary:
	## TASK I3 -- WHAT STANDS IN THE MIDDLE OF THE SQUARE, as
	## `{asset, cell, origin, quarter, cells}`, or empty when the green has no
	## room for one.
	##
	## The clearing has to be a real clear SQUARE of plaza, not a ragged run:
	## PLAZA_WIDE_BLOCK cells across for the well, the stall and the tree, and
	## PLAZA_NARROW_BLOCK for the tree alone. No cell of the block may be an
	## entrance -- a well in the doorway is worse than no well.
	##
	## A wide block is centred ON its middle cell (an odd square), a narrow one
	## on the corner its four cells share, and the module's own measured
	## half-extents fit either without a correction -- see PLAZA_WELL above for
	## the three numbers.
	##
	## TASK I4 ROUND 4 -- AND IT STANDS IN THE MIDDLE. The block used to be the
	## FIRST clear one in sorted lattice order, which is the lowest-x, lowest-z
	## corner of whatever the green offers: on 12/compact that put the tree in
	## the north-west corner of a 6x6 square, 2.12 cells off its centroid with
	## twelve clear blocks to choose from. The block is now the one whose own
	## anchor is NEAREST THE GREEN'S CENTROID, which is what "the centre feature"
	## has always meant. Over 12/compact, 4/compact, 3/standard, 9/standard and
	## 7/large that moves the anchor from 2.12/2.59/2.10/0.67/1.66 cells off
	## centre to 0.71/0.39/0.83/0.67/0.49 -- 9/standard's green offers exactly
	## one clear block and keeps it, which is the rule's own no-op case.
	##
	## STILL A PURE FUNCTION OF THE CELL SET. The candidates are swept in sorted
	## lattice order and a later one has to be STRICTLY nearer to win, so a
	## symmetric green -- where two blocks tie to the last bit -- keeps the
	## sorted-first of them exactly as before. The centroid is the mean of the
	## run's own integer coordinates; the same green always furnishes itself the
	## same way.
	if plaza.is_empty():
		return {}
	var cells: Array[Vector3i] = []
	cells.assign(plaza.keys())
	cells.sort_custom(_cell_before)
	var centroid := Vector3.ZERO
	for cell: Vector3i in cells:
		centroid += Vector3(cell)
	centroid /= float(cells.size())
	# A wide block's anchor is its own middle cell; a narrow one's is the corner
	# its four cells share, half a cell along each axis.
	var wide := _maze_plaza_block_nearest_centroid(plaza, entries, cells,
		centroid, PLAZA_WIDE_BLOCK, Vector3.ZERO)
	if not wide.is_empty():
		var cell := wide.cell as Vector3i
		var key := Vector4i(cell.x, cell.y, cell.z, 0)
		var pick := int(_face_noise(key, PLAZA_FEATURE_SALT) \
			* float(PLAZA_WIDE_FEATURES.size())) % PLAZA_WIDE_FEATURES.size()
		var origin := Vector3(cell) * FabricRecipe.CELL_SIZE
		origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_CAP_LIFT
		return {"asset": PLAZA_WIDE_FEATURES[pick], "cell": cell,
			"origin": origin,
			"quarter": int(_face_noise(key, PLAZA_FEATURE_SALT + 1) * 4.0) % 4,
			"cells": wide.cells}
	var narrow := _maze_plaza_block_nearest_centroid(plaza, entries, cells,
		centroid, PLAZA_NARROW_BLOCK, Vector3(0.5, 0.0, 0.5))
	if not narrow.is_empty():
		var cell := narrow.cell as Vector3i
		var key := Vector4i(cell.x, cell.y, cell.z, 1)
		var origin := Vector3(cell) * FabricRecipe.CELL_SIZE \
			+ Vector3(FabricRecipe.CELL_SIZE, 0.0, FabricRecipe.CELL_SIZE) * 0.5
		origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_CAP_LIFT
		return {"asset": PLAZA_TREE, "cell": cell, "origin": origin,
			"quarter": int(_face_noise(key, PLAZA_FEATURE_SALT + 1) * 4.0) % 4,
			"cells": narrow.cells}
	return {}


static func _maze_plaza_block_nearest_centroid(plaza: Dictionary,
		entries: Dictionary, cells: Array[Vector3i], centroid: Vector3,
		size: int, anchor_offset: Vector3) -> Dictionary:
	## TASK I4 ROUND 4. The clear `size x size` block of plaza whose anchor lies
	## nearest `centroid`, as `{cell, cells}`, or empty when none is clear.
	##
	## An ODD block is centred on its own cell and swept from -size/2 to +size/2;
	## an EVEN one is anchored on its lowest cell and swept forward, which is the
	## two loops this replaced, written once. `anchor_offset` is where the module
	## really stands relative to `cell` and so is what the distance is measured
	## from -- a 2x2's post is on the corner its four cells share, not on one of
	## them.
	var low := -(size / 2) if size % 2 == 1 else 0
	var high := size / 2 if size % 2 == 1 else size - 1
	var best: Dictionary = {}
	var best_offset := INF
	for cell: Vector3i in cells:
		var block: Dictionary = {}
		var clear := true
		for dx in range(low, high + 1):
			for dz in range(low, high + 1):
				var probe := cell + Vector3i(dx, 0, dz)
				clear = clear and plaza.has(probe) and not entries.has(probe)
				block[probe] = true
		if not clear:
			continue
		var offset := (Vector3(cell) + anchor_offset - centroid).length_squared()
		if offset >= best_offset:
			continue
		best_offset = offset
		best = {"cell": cell, "cells": block}
	return best


static func maze_module_footprints(plan: SettlementFabricPlan) -> Dictionary:
	## TASK I4 ROUND 6 -- WHERE EVERY AUTHORED MODULE REALLY STANDS.
	##
	## `{boxes: Array[AABB], assets: Array[StringName], by_cell: cell -> Array}`
	## over every placement of every unit of a sealed plan, bucketed into the
	## lattice cells each box touches so a rule can ask about a cell without
	## walking eight hundred boxes.
	##
	## DERIVED DATA, AND THAT IS THE WHOLE DESIGN. The plan already carried both
	## halves of this -- `expanded_placements()` yields one transform per module
	## and `FabricRecipe.seal` already measures every module's box off the
	## catalogue -- so nothing is authored, nothing is serialised and no
	## signature can move. What it replaces is the ONE merged
	## `local_clearance_bounds` a recipe keeps, which is why task I4 round 5's
	## first concern is three defects wearing one hat: a room's front door
	## reaching 1.071 m past the envelope its recipe claims, a gallery board
	## reaching over a deck cap whose column carries no paved cell, and a floor
	## board lying on a lawn one band up. A cell-based rule can see none of them,
	## and this is the set that can.
	var boxes: Array[AABB] = []
	var assets: Array[StringName] = []
	var by_cell: Dictionary = {}
	if plan == null:
		return {"boxes": boxes, "assets": assets, "by_cell": by_cell}
	for placement: Dictionary in plan.expanded_placements():
		var box := placement.get("bounds", AABB()) as AABB
		if not box.has_volume():
			continue
		var index := boxes.size()
		boxes.append(box)
		assets.append(StringName(placement.asset_id))
		# The cell a world point lies in: lattice x and z are cell CENTRES and
		# lattice y is a cell's FLOOR, which is the split `FabricRecipe.
		# _bounds_for_cells` states.
		var low := Vector3i(
			floori((box.position.x + FabricRecipe.CELL_SIZE * 0.5) \
				/ FabricRecipe.CELL_SIZE),
			floori(box.position.y / FabricRecipe.CELL_SIZE),
			floori((box.position.z + FabricRecipe.CELL_SIZE * 0.5) \
				/ FabricRecipe.CELL_SIZE))
		var high := Vector3i(
			floori((box.position.x + box.size.x + FabricRecipe.CELL_SIZE * 0.5) \
				/ FabricRecipe.CELL_SIZE),
			floori((box.position.y + box.size.y) / FabricRecipe.CELL_SIZE),
			floori((box.position.z + box.size.z + FabricRecipe.CELL_SIZE * 0.5) \
				/ FabricRecipe.CELL_SIZE))
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				for x in range(low.x, high.x + 1):
					var cell := Vector3i(x, y, z)
					if not by_cell.has(cell):
						by_cell[cell] = PackedInt32Array()
					var bucket := by_cell[cell] as PackedInt32Array
					bucket.append(index)
					by_cell[cell] = bucket
	return {"boxes": boxes, "assets": assets, "by_cell": by_cell}


static func maze_footprint_headroom(footprints: Dictionary, cell: Vector3i,
		surface: float, limit: float) -> Dictionary:
	## TASK I4 ROUND 6, ITEM 3 -- THE LOWEST THING OVER A SURFACE A BODY STANDS
	## ON, as `{rise, asset}` with `rise = INF` when the column is clear.
	##
	## Measured over the BODY's own footprint at the cell's centre rather than
	## over the whole cell, because the question is "can somebody stand here",
	## not "does anything overhang this square metre": a wall on the boundary
	## reaching 0.553 m in still leaves a body its 0.795 m, and a board 1.339 m
	## overhead does not.
	##
	## AND ONLY THINGS WITH AN UNDERSIDE ABOVE THE SURFACE. A module rising out
	## of the same plane -- the storey standing on the cap, the wall beside it --
	## has its box bottom AT the surface and is not a ceiling; counting it would
	## call every cap beside a building pinched and cost the town its gardens,
	## which is the trade task I4 round 5 refused to make blind.
	var out := {"rise": INF, "asset": &""}
	var boxes := footprints.get("boxes", []) as Array
	if boxes.is_empty():
		return out
	var assets := footprints.get("assets", []) as Array
	var by_cell := footprints.get("by_cell", {}) as Dictionary
	var half := NATURAL_ROCK_CUT_BODY_WIDTH * 0.5
	var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
	var seen: Dictionary = {}
	for band in range(floori(surface / FabricRecipe.CELL_SIZE),
			floori((surface + limit) / FabricRecipe.CELL_SIZE) + 1):
		var bucket := by_cell.get(Vector3i(cell.x, band, cell.z),
			PackedInt32Array()) as PackedInt32Array
		for index: int in bucket:
			if seen.has(index):
				continue
			seen[index] = true
			var box := boxes[index] as AABB
			var rise := box.position.y - surface
			if rise <= FOOTPRINT_EPSILON or rise >= limit or rise >= float(
					out.rise):
				continue
			if box.position.x >= centre.x + half \
					or box.position.x + box.size.x <= centre.x - half \
					or box.position.z >= centre.z + half \
					or box.position.z + box.size.z <= centre.z - half:
				continue
			out = {"rise": rise, "asset": StringName(assets[index])}
	return out


static func maze_footprint_intrusion(footprints: Dictionary, cell: Vector3i,
		step: Vector3i, base: float, rise: float) -> float:
	## TASK I4 ROUND 6, ITEM 1 -- how far real authored geometry reaches INTO
	## this cell across one of its four sides, over the band a piece standing on
	## `base` and `rise` tall would occupy.
	##
	## EXACT, WHERE ROUND 5 TOOK THE POOL'S WORST CASE -- the whole argument, with
	## the numbers, is at DECOR_PROBE_RISE. A cell beside a blank wall now gets
	## the depth that wall really takes rather than a front door's metre.
	##
	## THE DEPTH IS THE CHEAPEST RETREAT. For each box overlapping the probe
	## slab, the four faces are each a distance you would have to give up to be
	## clear of it; the smallest of them is the one that box really costs, and
	## charging it to that face is what keeps a module hanging over a corner from
	## being read as a wall across the whole side.
	var boxes := footprints.get("boxes", []) as Array
	if boxes.is_empty():
		return 0.0
	var by_cell := footprints.get("by_cell", {}) as Dictionary
	var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
	var half := FabricRecipe.CELL_SIZE * 0.5
	var out := 0.0
	var seen: Dictionary = {}
	for band in range(floori(base / FabricRecipe.CELL_SIZE),
			floori((base + rise) / FabricRecipe.CELL_SIZE) + 1):
		var bucket := by_cell.get(Vector3i(cell.x, band, cell.z),
			PackedInt32Array()) as PackedInt32Array
		for index: int in bucket:
			if seen.has(index):
				continue
			seen[index] = true
			var box := boxes[index] as AABB
			if box.position.y >= base + rise - FOOTPRINT_EPSILON \
					or box.position.y + box.size.y <= base + FOOTPRINT_EPSILON:
				continue
			var reach := _maze_footprint_face_reach(box, centre, half, step)
			if reach > out:
				out = reach
	return out


static func _maze_footprint_face_reach(box: AABB, centre: Vector3, half: float,
		step: Vector3i) -> float:
	## How much of the `step` side this box costs the cell, or 0 when it is clear
	## of the cell or is cheaper to retreat from on another face.
	var low := Vector2(box.position.x, box.position.z)
	var high := Vector2(box.position.x + box.size.x, box.position.z
		+ box.size.z)
	if low.x >= centre.x + half - FOOTPRINT_EPSILON \
			or high.x <= centre.x - half + FOOTPRINT_EPSILON \
			or low.y >= centre.z + half - FOOTPRINT_EPSILON \
			or high.y <= centre.z - half + FOOTPRINT_EPSILON:
		return 0.0
	# The four retreats: how deep the cell would have to give up from +x, -x, +z
	# and -z to stand clear of this box. Only the CHEAPEST is charged, and only
	# to its own face -- a module hanging over one corner is not a wall across a
	# whole side. Ties go to the first face in this order, which is a fact about
	# the box rather than about the caller and so is stable.
	var push := centre.x + half - low.x
	var cheapest := Vector3i(1, 0, 0)
	var probe := high.x - (centre.x - half)
	if probe < push:
		push = probe
		cheapest = Vector3i(-1, 0, 0)
	probe = centre.z + half - low.y
	if probe < push:
		push = probe
		cheapest = Vector3i(0, 0, 1)
	probe = high.y - (centre.z - half)
	if probe < push:
		push = probe
		cheapest = Vector3i(0, 0, -1)
	return push if cheapest == step else 0.0


static func maze_decor_face_intrusion(cell: Vector3i, step: Vector3i,
		treatments: Dictionary, garden: Dictionary,
		footprints: Dictionary = {}) -> float:
	## TASK I4 ROUND 5, ITEM 1 -- how far the BUILT SURFACE across one face of a
	## garden cell reaches back INTO that cell. The three panel numbers and where
	## they come from are at DECOR_MASONRY_INTRUSION; this is the lookup that
	## decides which of them is standing here, and the exact reach of everything
	## the retained skin did not lay.
	##
	## Asked of BOTH panels, because the coursed module straddles its boundary and
	## so belongs to neither cell alone: this cell's own face closes it from the
	## inside and the neighbour's face closes it from the outside, and either one
	## being masonry puts 0.332 m of stone in front of anything standing here.
	##
	## A LAWN ACROSS THE BOUNDARY CARRIES NO PANEL, AND THAT IS ALL IT MEANS.
	## Round 5 returned 0.0 for a garden neighbour BEFORE it probed anything else,
	## on the reasoning that "a garden neighbour is more of the same bench". True
	## of PANELS and false of BUILDINGS: a room can stand ON the lawn one band up,
	## and its own modules are then standing in this cell. Measured on the review
	## corpus, with that early return gone and nothing else changed: 25 of the 28
	## pieces that still intersected real geometry no longer fit their own free
	## box -- every door, every window and the one plain wall. The lawn's share of
	## the answer survives as the `garden` guard on the panel lookups alone.
	##
	## TASK I4 ROUND 6 -- AND THE BUILDING'S OWN REACH IS NOW EXACT. A building's
	## outward wall is a room unit's MODULE rather than a panel of the retained
	## skin, so no treatment names it. Round 5 asked whether a solid or occluder
	## cell stood across this face or either diagonal and, when the answer was
	## yes, charged the whole pool's worst case; `maze_footprint_intrusion` asks
	## the module boxes themselves. See it for what that blanket cost.
	var out := 0.0
	var lawn := garden.has(cell + step)
	var index := FACE_DIRECTIONS.find(step)
	var back := FACE_DIRECTIONS.find(-step)
	if index >= 0 and not lawn:
		out = maxf(out, _maze_decor_panel_intrusion(treatments.get(
			Vector4i(cell.x, cell.y, cell.z, index), -1)))
	var neighbour := cell + step
	if back >= 0 and not lawn:
		out = maxf(out, _maze_decor_panel_intrusion(treatments.get(
			Vector4i(neighbour.x, neighbour.y, neighbour.z, back), -1)))
	return maxf(out, maze_footprint_intrusion(footprints, cell, step,
		float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_CAP_LIFT,
		DECOR_PROBE_RISE))


static func _maze_decor_panel_intrusion(treatment: int) -> float:
	match treatment:
		SkinTreatment.MASONRY:
			return DECOR_MASONRY_INTRUSION
		SkinTreatment.FACADE:
			return DECOR_FACADE_INTRUSION
		SkinTreatment.NATURAL:
			return NATURAL_ROCK_NOSE_LOCAL_Z - NATURAL_ROCK_FACE_DEPTH_CENTRE
		_:
			return 0.0


static func maze_decor_free_box(cell: Vector3i, treatments: Dictionary,
		garden: Dictionary, footprints: Dictionary = {},
		run: Array[Vector3i] = []) -> Dictionary:
	## TASK I4 ROUND 5, ITEM 1 -- the cell's REAL free ground, as
	## `{centre: Vector3, half: Vector2}` in world XZ.
	##
	## The lattice cell shrunk on each of its four sides by whatever is built
	## there, and then by DECOR_STANDOFF_MARGIN so a piece stands off the wall
	## rather than against it. The centre moves with the shrinking: an edge cell
	## with a house on one side gives its planter the room it has and stands it
	## clear, instead of centring it on a plane half of which is masonry.
	##
	## A box can come back with a NEGATIVE half on an axis -- a cell walled on
	## both sides by facade panels leaves 0.394 m of 1.5 m -- and the caller reads
	## that as "nothing this pool carries fits here" rather than as an error.
	##
	## TASK I4 ROUND 6 -- AND `run` MERGES A PAIR. A bench is 2.30 m and a lamp
	## post reaches 1.23 m off its own centre along its arm: neither fits a 1.5 m
	## cell at any yaw, which is why round 5 left them out of the pool and the
	## square's boundary came back thinner. Given the cells of a run, the free box
	## is their union shrunk by what is built on the RUN's own outside faces --
	## the boundary between two cells of the run is not a side anything stands
	## on -- so a pair of edge cells is one 3 m stance and the bench stands in it.
	var cells: Array[Vector3i] = run.duplicate()
	if cells.is_empty():
		cells.append(cell)
	var member: Dictionary = {}
	for member_cell: Vector3i in cells:
		member[member_cell] = true
	var span := Vector3(cells[cells.size() - 1] - cells[0]) \
		* FabricRecipe.CELL_SIZE
	var origin := (Vector3(cells[0]) + Vector3(cells[cells.size() - 1])) * 0.5 \
		* FabricRecipe.CELL_SIZE
	var lo := Vector2(-(absf(span.x) + FabricRecipe.CELL_SIZE) * 0.5,
		-(absf(span.z) + FabricRecipe.CELL_SIZE) * 0.5)
	var hi := -lo
	for step: Vector3i in FACE_DIRECTIONS:
		var reach := 0.0
		for member_cell: Vector3i in cells:
			if member.has(member_cell + step):
				continue
			var intrusion := maze_decor_face_intrusion(member_cell, step,
				treatments, garden, footprints)
			if intrusion > reach:
				reach = intrusion
		if reach <= 0.0:
			continue
		reach += DECOR_STANDOFF_MARGIN
		if step.x > 0:
			hi.x -= reach
		elif step.x < 0:
			lo.x += reach
		elif step.z > 0:
			hi.y -= reach
		else:
			lo.y += reach
	var middle := (lo + hi) * 0.5
	var centre := origin
	centre.x += middle.x
	centre.z += middle.y
	return {"centre": centre, "half": (hi - lo) * 0.5}


static func maze_decor_fits(half_free: Vector2, asset: StringName,
		yaw: float) -> bool:
	## Whether the piece, turned to `yaw`, stands inside the free box.
	##
	## The footprint of a grid-aligned envelope at an arbitrary yaw, which is what
	## a self-sown plant takes: `hx |cos| + hz |sin|` along world X and the mirror
	## of it along Z. A quarter turn falls out of the same arithmetic, so the
	## built planter and the self-sown plant are measured by one rule.
	if not DECOR_CLEARANCE.has(asset):
		return false
	var clearance: Vector2 = DECOR_CLEARANCE[asset]
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	return clearance.x * c + clearance.y * s <= half_free.x \
		and clearance.x * s + clearance.y * c <= half_free.y


static func maze_garden_dressing(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}, shell: Dictionary = {},
		footprints: Dictionary = {}) -> EnvironmentInstancePayload:
	## TASK I2 -- WHAT MAKES A BENCH TOP A YARD. The cap is the ground and the
	## rim is its edge; this is what stands on it.
	##
	## A SEPARATE PAYLOAD for the reason `maze_green_rim_walls` is one: task
	## C5b's identity is one instance per panel of the shell, and a planter is
	## not a panel. Every piece carries a `maze-garden/` id that no reading of
	## the skin mistakes for cladding.
	##
	## TWO RATES, and the difference is the whole plaza. An ordinary yard grows
	## something on a third of its cells -- incidental green behind and between
	## houses. The VILLAGE GREEN grows nothing in its middle and twice as much on
	## its EDGE, which is what a plaza is: a clearing with a planted boundary. A
	## cell on the plaza edge is one with a lateral neighbour that is not plaza.
	##
	## Nothing here is placed on a cell the public realm walks: `maze_garden_
	## cells` is derived from the GREEN treatment, and a cap is only green when
	## neither cell it covers is walked.
	##
	## TASK I3 FINISHES THE SQUARE with the two things a plaza still lacked: a
	## paved THRESHOLD wherever a street reaches it, and one CENTRE FEATURE in
	## its clearing. Both are emitted here rather than in a channel of their own,
	## because both are dressing laid on a garden cap and because the planting
	## loop has to know about them: a planter standing in a doorway or inside the
	## well is the defect they would otherwise introduce.
	##
	## TASK I4 ROUND 5 -- ITEMS 1 AND 5. Two things changed and they are the same
	## change: WHERE a piece may stand and WHICH piece stands there.
	##
	## Every placement now goes through `maze_decor_free_box`, which is the cell
	## minus whatever is really built on its four sides -- see
	## DECOR_MASONRY_INTRUSION for the three panel depths and the defect they
	## explain, and DECOR_PROBE_RISE for what round 6 replaced the fourth with.
	## The pool is then walked in a seeded rotation and the FIRST piece that fits
	## that box at its own yaw is the one that stands; a cell with room for
	## nothing plants nothing and is counted. That is the frontage gate's rule
	## (choose the pool, then measure the envelope, then refuse) applied to the
	## channel that had no such gate at all.
	##
	## AND NO TWO NEIGHBOURS WEAR THE SAME PIECE. The cells are swept in sorted
	## lattice order, so a cell's -x and -z neighbours are already decided and
	## their pieces are excluded from its own choice; where the exclusion would
	## leave nothing that fits, it is dropped rather than the cell going bare.
	var derived := shell if not shell.is_empty() \
		else maze_skin_shell(retained, solids, paved, plinths, walked,
			footprints)
	var treatments := derived.treatments as Dictionary
	var garden := maze_garden_cells(retained, solids, paved, plinths, walked,
		derived, footprints)
	var out := EnvironmentInstancePayload.new()
	if garden.is_empty():
		return out
	var plaza := maze_village_green_cells(garden, walked)
	var entries := maze_plaza_entries(plaza, walked)
	var feature := maze_plaza_centre_feature(plaza, entries)
	var reserved: Dictionary = {}
	for cell_value: Variant in (feature.get("cells", {}) as Dictionary).keys():
		reserved[cell_value as Vector3i] = true
	var cells: Array[Vector3i] = []
	cells.assign(garden.keys())
	cells.sort_custom(_cell_before)
	# The thresholds first, so the square reads as entered before anything is
	# planted on it.
	var entry_cells: Array[Vector3i] = []
	entry_cells.assign(entries.keys())
	entry_cells.sort_custom(_cell_before)
	for cell: Vector3i in entry_cells:
		out.add(MAZE_STONE_MODULE,
			_maze_stone_transform(cell, Vector3i.UP, Vector3i.ZERO, true),
			Color.WHITE, StringName("maze-plaza-threshold/%d/%d/%d" % [cell.x,
				cell.y, cell.z]))
	if not feature.is_empty():
		var anchor := feature.origin as Vector3
		var feature_cell := feature.cell as Vector3i
		var feature_yaw := float(int(feature.quarter)) * PI * 0.5
		out.add(StringName(feature.asset), Transform3D(Basis(Vector3.UP,
			feature_yaw), anchor), Color.WHITE,
			StringName("maze-plaza-centre/%d/%d/%d" % [feature_cell.x,
				feature_cell.y, feature_cell.z]))
		# TASK I4 ROUND 5, ITEM 2. The square's own stall is stocked -- the
		# counter, the goods along its front and the hanging string, measured off
		# the canopy's posts. A well or a tree in the middle takes nothing.
		for goods: Dictionary in maze_stall_goods(StringName(feature.asset),
				anchor, feature_yaw, Vector4i(feature_cell.x, feature_cell.y,
					feature_cell.z, 2)):
			out.add(StringName(goods.asset), goods.transform as Transform3D,
				Color.WHITE, StringName("maze-stall-goods/%d/%d/%d/plaza/%s" % [
					feature_cell.x, feature_cell.y, feature_cell.z,
					String(goods.station)]))
	for site: Dictionary in maze_garden_planting_sites(garden, plaza, entries,
			reserved, treatments, footprints):
		if bool(site.refused):
			continue
		out.add(StringName(site.asset), Transform3D(Basis(Vector3.UP,
			float(site.yaw)), site.origin as Vector3), Color.WHITE,
			maze_garden_decor_id(site))
	assert(out.validate())
	return out


static func maze_garden_decor_id(site: Dictionary) -> StringName:
	## TASK I4 ROUND 6 -- the stable id of one planted site, and it names the RUN
	## rather than only the cell: `maze-garden/x/y/z` for the ordinary one-cell
	## piece and `maze-garden/x/y/z/sx/sz` for a piece that spans on to the cell
	## `step` away. Every reader that asked `begins_with("maze-garden/")` and took
	## the first three fields still reads exactly what it read before; a reader
	## that wants to know what ground the piece really stands on now can.
	var cell := site.cell as Vector3i
	var step := site.get("step", Vector3i.ZERO) as Vector3i
	if step == Vector3i.ZERO:
		return StringName("maze-garden/%d/%d/%d" % [cell.x, cell.y, cell.z])
	return StringName("maze-garden/%d/%d/%d/%d/%d" % [cell.x, cell.y, cell.z,
		step.x, step.z])


static func maze_garden_planting_sites(garden: Dictionary, plaza: Dictionary,
		entries: Dictionary, reserved: Dictionary, treatments: Dictionary,
		footprints: Dictionary = {}) -> Array[Dictionary]:
	## TASK I4 ROUND 5 -- WHAT GROWS WHERE, as records rather than instances, so
	## the audit and the payload count the same thing (the frontage channel's own
	## shape). A refused site is the one this round added: a cell whose odds roll
	## said "plant here" and whose real free ground holds nothing the pool
	## carries.
	##
	## TASK I4 ROUND 6 -- AND A PIECE MAY SPAN A PAIR. `step` is the cell the
	## piece runs on to, `Vector3i.ZERO` for the ordinary one-cell placement; a
	## pair is ONE occupant, with one roll, one record and one id, so the audit
	## and the adjacent-differs rule both read it as the single thing it is. The
	## measurement that made it necessary is at GARDEN_WIDE_POOL.
	var out: Array[Dictionary] = []
	var cells: Array[Vector3i] = []
	cells.assign(garden.keys())
	cells.sort_custom(_cell_before)
	var placed: Dictionary = {}
	var taken: Dictionary = {}
	for cell: Vector3i in cells:
		# A threshold is a doorway and the centre feature's block is its
		# clearing; neither grows anything. A cell the piece beside it already
		# runs across is spoken for.
		if entries.has(cell) or reserved.has(cell) or taken.has(cell):
			continue
		var built := _maze_garden_plants_built(cell, plaza)
		if not _maze_garden_odds_say_plant(cell, plaza):
			continue
		# Turned so it cannot reach a neighbour: a self-sown plant takes a free
		# yaw and the BUILT piece takes quarter turns only, which is what a
		# laid-out square looks like and what keeps its long axis on an axis of
		# the free box below.
		var seed_key := Vector4i(cell.x, cell.y, cell.z, 0)
		var yaw_roll := _face_noise(seed_key, 13)
		var yaw := floorf(yaw_roll * 4.0) * PI * 0.5 if built else yaw_roll * TAU
		var pool := GARDEN_PLANTER_POOL if built else GARDEN_PLANTING
		var run: Array[Vector3i] = [cell]
		var step := Vector3i.ZERO
		var free := maze_decor_free_box(cell, treatments, garden, footprints)
		var neighbours := _maze_decor_neighbours(run, placed)
		var choice: Dictionary = {"asset": &"", "yaw": yaw}
		# THE WIDE PIECE FIRST, and only on the square's own boundary: the pair
		# is what a bench or a lamp post needs and what a laid-out square wants
		# along its edge, and an ordinary back yard is not laid out.
		if built:
			for probe: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
				var partner := cell + probe
				if taken.has(partner) or placed.has(partner) \
						or entries.has(partner) or reserved.has(partner) \
						or not garden.has(partner) \
						or not _maze_garden_plants_built(partner, plaza) \
						or not _maze_garden_odds_say_plant(partner, plaza):
					continue
				var pair: Array[Vector3i] = [cell, partner]
				var wide := maze_decor_free_box(cell, treatments, garden,
					footprints, pair)
				var wide_choice := maze_decor_choice(GARDEN_WIDE_POOL,
					wide.half as Vector2, atan2(-float(probe.z),
						float(probe.x)),
					int(_face_noise(seed_key, 12) \
						* float(GARDEN_WIDE_POOL.size())) \
						% GARDEN_WIDE_POOL.size(),
					_maze_decor_neighbours(pair, placed))
				if StringName(wide_choice.asset).is_empty():
					continue
				run = pair
				step = probe
				free = wide
				choice = wide_choice
				neighbours = {}
				break
		if StringName(choice.asset).is_empty():
			choice = maze_decor_choice(pool, free.half as Vector2, yaw,
				int(_face_noise(seed_key, 12) * float(pool.size())) \
					% pool.size(), neighbours)
		var asset := StringName(choice.asset)
		yaw = float(choice.yaw)
		if asset.is_empty():
			# Nothing this pool carries stands clear of what is built here. A bare
			# cell is the honest answer and it is counted rather than hidden --
			# the alternative is the plant in the wall this rule exists to stop.
			out.append({"cell": cell, "step": Vector3i.ZERO, "asset": &"",
				"yaw": 0.0, "origin": Vector3.ZERO, "built": built,
				"refused": true})
			continue
		for member: Vector3i in run:
			placed[member] = asset
			taken[member] = true
		# Standing on the cap's own plane, centred in the ground it really has.
		var origin := free.centre as Vector3
		origin.y = float(cell.y + 1) * FabricRecipe.CELL_SIZE + GREEN_CAP_LIFT
		out.append({"cell": cell, "step": step, "asset": asset, "yaw": yaw,
			"origin": origin, "built": built, "refused": false})
	return out


static func _maze_garden_plants_built(cell: Vector3i,
		plaza: Dictionary) -> bool:
	## Does this cell take the BUILT pool -- the made planter, the barrel, the
	## bench -- rather than a self-sown plant? Only the square's own boundary
	## does: a cell of the plaza with a lateral neighbour that is not plaza.
	if not plaza.has(cell):
		return false
	for step: Vector3i in FACE_DIRECTIONS:
		if not plaza.has(cell + step):
			return true
	return false


static func _maze_garden_odds_say_plant(cell: Vector3i,
		plaza: Dictionary) -> bool:
	## The cell's own seeded roll against its own rate: a third of an ordinary
	## yard, half of the square's boundary, and NOTHING in the square's clearing
	## -- a plaza is a clearing, and that is what keeps it one.
	var odds := GARDEN_PLANTING_ODDS
	if plaza.has(cell):
		odds = VILLAGE_GREEN_EDGE_ODDS \
			if _maze_garden_plants_built(cell, plaza) else 0.0
	return _face_noise(Vector4i(cell.x, cell.y, cell.z, 0), 11) < odds


static func _maze_decor_neighbours(run: Array[Vector3i],
		placed: Dictionary) -> Dictionary:
	## What the already decided neighbours of this run are wearing, which is what
	## the adjacent-differs rule excludes. The run's own members are not its own
	## neighbours.
	var out: Dictionary = {}
	var member: Dictionary = {}
	for cell: Vector3i in run:
		member[cell] = true
	for cell: Vector3i in run:
		for step: Vector3i in FACE_DIRECTIONS:
			var probe := cell + step
			if member.has(probe) or not placed.has(probe):
				continue
			out[StringName(placed[probe])] = true
	return out


static func maze_decor_choice(pool: Array[StringName], half_free: Vector2,
		yaw: float, offset: int, exclude: Dictionary) -> Dictionary:
	## TASK I4 ROUND 5, ITEMS 1 AND 5 -- which piece stands on this ground.
	##
	## The pool walked from a seeded offset, taking the first piece that FITS the
	## cell's real free box at the yaw it would be turned to and that no already
	## decided neighbour is already wearing. The rotation is what makes the choice
	## seeded; the fit is what keeps it out of the wall; the exclusion is what
	## stops a run of edge cells reading as one repeated crate.
	##
	## THREE PASSES, and the last two are what keep the square planted rather than
	## trading its boundary for its stand-off:
	##
	## 1. the seeded yaw, and no piece a decided neighbour already wears;
	## 2. the seeded yaw, repeats allowed -- variety is worth a repeat, it is not
	##    worth a hole in the boundary;
	## 3. the yaw SNAPPED to the nearest quarter turn, which is the narrowest a
	##    grid-aligned envelope can present to a grid-aligned free box: a piece
	##    0.60 x 0.45 needs 0.74 of room at 45 degrees and 0.45 square to the
	##    grid. A pinched cell gets a piece standing square instead of nothing.
	if pool.is_empty():
		return {"asset": &"", "yaw": yaw}
	var square := roundf(yaw / (PI * 0.5)) * PI * 0.5
	for pass_index in 3:
		var turn := yaw if pass_index < 2 else square
		for step in pool.size():
			var asset := pool[(offset + step) % pool.size()]
			if pass_index == 0 and exclude.has(asset):
				continue
			if maze_decor_fits(half_free, asset, turn):
				return {"asset": asset, "yaw": turn}
	return {"asset": &"", "yaw": yaw}


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


static func _face_noise(face: Vector4i, salt: int,
		world_seed: int = 0) -> float:
	## A deterministic value in [0, 1) per panel per dial, through the same
	## splitmix64 avalanche every other seeded placement in this project uses.
	## A function of the PANEL and nothing else: the skin stays byte-identical
	## for identical input, and a town cannot roll different rock on a re-solve.
	##
	## TASK I4 ROUND 2 -- AND, WHERE A CALLER HAS ONE, THE WORLD. The frontage
	## rule was handed a `world_seed` through three functions and never spent it;
	## it is spent here now, and the other eleven dials in this file are unchanged
	## BY CONSTRUCTION rather than by inspection. The seed joins the outermost XOR
	## the panel's own x already sits in -- `Helper.position_hash01`'s shape -- so
	## the default of 0 is the identity (`x ^ 0 == x`) and every caller that does
	## not pass one gets exactly the value it got before this line was written.
	return Helper._hash01(Helper._mix64(face.x ^ world_seed \
		^ Helper._mix64(face.y ^ Helper._mix64(face.z \
			^ Helper._mix64(face.w ^ Helper._mix64(salt))))))


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


static func maze_skywalk_spans(plan: SettlementFabricPlan,
		crown_unit_ids: Dictionary = {}) -> Array[Dictionary]:
	## TASK I3 -- WHERE THE TOWN ALREADY HAS A BRIDGE-SHAPED HOLE IN IT, as an
	## array of `{cell, step, gap}` records: `cell` is the near end, `step` is
	## one of SKYWALK_STEPS, and `gap` is how many cells of air lie between the
	## two ends. Deterministic and disjoint -- no cell belongs to two spans.
	##
	## SITE SELECTION IS STRUCTURAL FIRST AND SEEDED SECOND, which is what the
	## direction asks for: the rules below are the scarce filter (the four
	## planner towns offer 0-4 sites each out of 136-278 walkable cells), and the
	## seed decides only which of two OVERLAPPING candidates wins. Adding an
	## acceptance roll on top would only turn a town with three bridges into a
	## town with two; the geometry is already the rate.
	##
	## A SITE IS SIX FACTS, and each of them is a way a bridge could be wrong:
	##
	## 1. BOTH ENDS ARE WALKED SURFACES AT ONE BAND -- a terrace crown, a roof
	##    deck, a gallery or a public floor. A bridge you cannot step onto is
	##    scenery; a bridge whose far end is a storey up is a stair, and the
	##    catalog ships no walkway stair piece that tiles this lattice.
	## 2. IT IS AN UPPER CROSSING. The near end stands above the town's lowest
	##    walked band, so a span can never be a plank laid across the street it
	##    is supposed to fly over.
	## 3. THE GAP IS AIR. Every cell between the ends is free of built solid,
	##    retained mass, public floor and walk surface, and so is the band
	##    directly beneath it (SKYWALK_UNDERCUT_BANDS) -- otherwise the "gap" is
	##    a notch in one terrace and the bridge is a plank on a bench.
	## 4. IT CROSSES A STREET. At least one gap column has a walked cell below
	##    it. This is the reference frame's own subject and it is deliberately
	##    strict: it costs the corpus two of eight candidate sites and it is what
	##    stops a bridge being hung over a private yard nobody looks up from.
	## 5. THE STREET KEEPS ITS HEADROOM. Every walked cell below any gap column
	##    is at least SKYWALK_MIN_HEADROOM_BANDS down -- see that constant for
	##    the arithmetic, and the sweep's clearance row for the live proof.
	## 6. THE WALK CARRIES ITS OWN CLEARANCE. SKYWALK_HEAD_BANDS above each gap
	##    cell are free of built mass, so a body can stand on the bridge.
	var out: Array[Dictionary] = []
	if plan == null or plan.surface_plan == null:
		return out
	var deck := maze_terrace_deck_cells(plan, crown_unit_ids)
	var walked := walked_floor_cells(plan.surface_plan)
	if walked.is_empty():
		return out
	var stand: Dictionary = {}
	for cell_value: Variant in deck.keys():
		stand[cell_value as Vector3i] = true
	for cell_value: Variant in walked.keys():
		stand[cell_value as Vector3i] = true
	var solids := plan.transformed_cells(&"solid")
	var occluders := plan.transformed_cells(&"occluder")
	var retained := plan.retained_terrace_cells
	var paved := public_floor_cells(plan.surface_plan)
	# The street datum: the lowest band anybody walks in this town.
	var ground := 1 << 30
	var walked_bands: Dictionary = {}
	for cell_value: Variant in walked.keys():
		var cell := cell_value as Vector3i
		ground = mini(ground, cell.y)
		var column := Vector2i(cell.x, cell.z)
		var bands: Array = walked_bands.get(column, [])
		bands.append(cell.y)
		walked_bands[column] = bands
	var cells: Array[Vector3i] = []
	cells.assign(stand.keys())
	cells.sort_custom(_cell_before)
	var candidates: Array[Dictionary] = []
	for cell: Vector3i in cells:
		if cell.y <= ground:
			continue
		for index in SKYWALK_STEPS.size():
			var step := SKYWALK_STEPS[index]
			for gap in range(1, SKYWALK_MAX_GAP + 1):
				if not _skywalk_site_holds(cell, step, gap, stand, solids,
						retained, occluders, paved, walked_bands):
					continue
				candidates.append({"cell": cell, "step": step, "gap": gap,
					"order": _face_noise(Vector4i(cell.x, cell.y, cell.z,
						index), SKYWALK_ORDER_SALT)})
	# The seeded order, with the lattice key as the tie-break so two candidates
	# that draw the same noise still resolve the same way on every run.
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if not is_equal_approx(float(left.order), float(right.order)):
			return float(left.order) < float(right.order)
		return _cell_before(left.cell as Vector3i, right.cell as Vector3i))
	var claimed: Dictionary = {}
	for candidate: Dictionary in candidates:
		var cell := candidate.cell as Vector3i
		var step := candidate.step as Vector3i
		var gap := int(candidate.gap)
		var free := true
		for index in range(0, gap + 2):
			free = free and not claimed.has(cell + step * index)
		if not free:
			continue
		for index in range(0, gap + 2):
			claimed[cell + step * index] = true
		out.append({"cell": cell, "step": step, "gap": gap})
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var a := left.cell as Vector3i
		var b := right.cell as Vector3i
		if a != b:
			return _cell_before(a, b)
		return SKYWALK_STEPS.find(left.step as Vector3i) \
			< SKYWALK_STEPS.find(right.step as Vector3i))
	return out


static func _skywalk_site_holds(cell: Vector3i, step: Vector3i, gap: int,
		stand: Dictionary, solids: Dictionary, retained: Dictionary,
		occluders: Dictionary, paved: Dictionary,
		walked_bands: Dictionary) -> bool:
	## Facts 1 and 3-6 of `maze_skywalk_spans`, for one candidate. Fact 2 (the
	## span is an upper crossing) is the caller's, because it needs the town's
	## own street datum rather than anything about this gap.
	var far := cell + step * (gap + 1)
	if not stand.has(far):
		return false
	var over_street := false
	for index in range(1, gap + 1):
		var mid := cell + step * index
		if stand.has(mid) or solids.has(mid) or retained.has(mid) \
				or occluders.has(mid) or paved.has(mid):
			return false
		for drop in range(1, SKYWALK_UNDERCUT_BANDS + 1):
			var under := mid - Vector3i.UP * drop
			if solids.has(under) or retained.has(under):
				return false
		for rise in range(1, SKYWALK_HEAD_BANDS + 1):
			var over := mid + Vector3i.UP * rise
			if solids.has(over) or retained.has(over) or occluders.has(over):
				return false
		for band_value: Variant in walked_bands.get(
				Vector2i(mid.x, mid.z), []):
			var band := int(band_value)
			if band >= cell.y:
				continue
			if cell.y - band < SKYWALK_MIN_HEADROOM_BANDS:
				return false
			over_street = true
	return over_street


static func maze_skywalk_cells(spans: Array[Dictionary]) -> Dictionary:
	## Every cell of AIR a span occupies, as `cell -> true`. The ends are left
	## out: they are surfaces the town already built and nothing else is
	## considering putting anything in them. The gap cells are what another
	## channel has to keep clear -- see `maze_facade_outcroppings`.
	var out: Dictionary = {}
	for span: Dictionary in spans:
		var cell := span.cell as Vector3i
		var step := span.step as Vector3i
		for index in range(1, int(span.gap) + 1):
			out[cell + step * index] = true
	return out


static func maze_skywalks_from(spans: Array[Dictionary]) \
		-> EnvironmentInstancePayload:
	## TASK I3 -- the open timber bridge itself: one deck, two rails, two
	## bearers per span of `maze_skywalk_spans`.
	##
	## Over spans a caller ALREADY DERIVED, and there is no convenience wrapper
	## that derives them here (fix 1, minor 1: there was one, `maze_skywalks`,
	## and nothing ever called it). The payload derives the spans once and hands
	## the same array to this and to `maze_skywalk_cells`, so the bridges the
	## town renders and the cells the outcropping channel keeps clear can never
	## be two different answers -- which a second derivation is exactly how to
	## break.
	##
	## THE DECK is the same authored plank floor the public realm's own galleries
	## are laid with, and it is laid FLUSH: its top face lands exactly on
	## `band x CELL_SIZE`, which is the walk surface of the terrace crown at each
	## end (`maze_terrace_railings` states the same datum), so a body steps onto
	## the bridge without a lip. A two-cell span takes the 3.0 m module whole; a
	## one-cell span takes the 1.5 m module, whose authored pivot lies on its own
	## +X seam and is corrected here exactly as `_add_plank_tile` corrects it.
	##
	## THE RAILS are the pair that makes it read as a bridge rather than as a
	## shelf, and they are the modules the terrace edges already use: one 3.0 m
	## rail per side over a two-cell span, one 1.5 m rail per side over a
	## one-cell span, standing ON the deck and centred on the deck's own edge.
	##
	## THE BEARERS are the visible bearing, one under each end: the measured
	## 1.94 m corbel laid ACROSS the walk at the boundary it bears on, so it
	## reads from the street below as the plate the planks sit on. Across and not
	## along, because along is what a corbel wants to do and two 1.94 m corbels
	## reaching out from either end of a 3.0 m gap would pass through each other
	## in mid-air. It hangs SKYWALK_BEARER_DROP below the deck and that drop is
	## the number the headroom rule is written against.
	var out := EnvironmentInstancePayload.new()
	for span: Dictionary in spans:
		var cell := span.cell as Vector3i
		var step := span.step as Vector3i
		var gap := int(span.gap)
		var index := SKYWALK_STEPS.find(step)
		var stable := "maze-skywalk/%d/%d/%d/%d" % [cell.x, cell.y, cell.z,
			index]
		var walk_y := float(cell.y) * FabricRecipe.CELL_SIZE
		var along := Basis(Vector3.UP, atan2(-float(step.z), float(step.x)))
		# The middle of the run of air, in world space.
		var centre := (Vector3(cell + step) \
			+ Vector3(step) * (float(gap) - 1.0) * 0.5) * FabricRecipe.CELL_SIZE
		var deck_origin := centre
		deck_origin.y = walk_y - SKYWALK_DECK_THICKNESS
		if gap == 1:
			deck_origin += along * Vector3(FabricRecipe.CELL_SIZE * 0.5, 0.0,
				0.0)
		out.add(SKYWALK_DECK if gap > 1 else SKYWALK_DECK_SHORT,
			Transform3D(along, deck_origin), Color.WHITE,
			StringName("%s/deck" % stable))
		var cross := Vector3i(step.z, 0, step.x)
		for side in 2:
			var rail_origin := centre + Vector3(cross) \
				* (FabricRecipe.CELL_SIZE * 0.5) * (1.0 if side == 0 else -1.0)
			rail_origin.y = walk_y
			out.add(SKYWALK_RAIL_MEDIUM if gap > 1 else SKYWALK_RAIL,
				Transform3D(along, rail_origin), Color.WHITE,
				StringName("%s/rail/%d" % [stable, side]))
		var across := Basis(Vector3.UP, atan2(-float(cross.z), float(cross.x)))
		for end in 2:
			var anchor := cell if end == 0 else cell + step * (gap + 1)
			var inward := step if end == 0 else -step
			var bearer_origin := Vector3(anchor) * FabricRecipe.CELL_SIZE \
				+ Vector3(inward) * (FabricRecipe.CELL_SIZE * 0.5) \
				+ Vector3(cross) * (SKYWALK_BEARER_REACH * 0.5)
			bearer_origin.y = walk_y - SKYWALK_DECK_THICKNESS \
				- SKYWALK_BEARER_DROP
			out.add(SKYWALK_BEARER, Transform3D(across, bearer_origin),
				Color.WHITE, StringName("%s/bearer/%d" % [stable, end]))
	assert(out.validate())
	return out


static func maze_facade_outcrop_kinds(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}, shell: Dictionary = {},
		blocked: Dictionary = {}) -> Dictionary:
	## TASK I3 -- WHICH CLAD PANEL PROJECTS, and as what, as
	## `panel key -> FacadeOutcrop`. Only the panels that project appear; a
	## reader asking about a panel that is not here is asking about a flat wall.
	##
	## FOUR FACTS QUALIFY A PANEL, and each is a way a projection could be wrong:
	##
	## 1. IT IS A SIDE FACE WEARING A BUILDING STOREY -- a FACADE panel of the
	##    clad mass. A retaining course does not grow a bay window and neither
	##    does a garden cap.
	## 2. IT IS AN UPPER STOREY. The same face carries another panel one course
	##    below it, so there is a house under the projection rather than a
	##    pavement. This is the direction's own "on upper storeys".
	## 3. THE AIR IN FRONT IS FREE, over the panel's whole course AND OVER THE
	##    BAND ITS BEARERS HANG IN: no built solid, no retained mass, no public
	##    floor, nobody's walk surface, and no skywalk. A bay occupies exactly
	##    the one cell in front of its panel, so that is exactly the cell this
	##    asks about.
	## 4. THE STREET UNDER IT KEEPS ITS HEADROOM --
	##    FACADE_OUTCROP_MIN_HEADROOM_BANDS, whose arithmetic is written at the
	##    constant and whose live proof is the corpus sweep's clearance row.
	##
	## AND ONE PANEL PER COLUMN PER FACE takes it, which is what stops a stack of
	## bays climbing one wall like a fire escape. The keys are swept in sorted
	## order so which storey of a column wins is a fact of the lattice rather
	## than of dictionary iteration.
	##
	## THE ROLL TAKES NO WORLD SEED (fix 1, minor 2). It used to accept one and
	## never read it, which reads as a seeded rate that a caller can vary and is
	## not one. `_face_noise` keys on the PANEL'S OWN POSITION, which is this
	## file's established idiom for every seeded dressing rate it owns (the
	## garden planting, the skin's own family choice), and it is the right one
	## here: the town's identity is already in where its faces are.
	var out: Dictionary = {}
	var derived := shell if not shell.is_empty() \
		else maze_skin_shell(retained, solids, paved, plinths, walked)
	var faces := derived.faces as Dictionary
	var treatments := derived.treatments as Dictionary
	var keys: Array[Vector4i] = []
	keys.assign(faces.keys())
	keys.sort_custom(_face_before)
	# Walked bands per column, so fact 4 is one lookup rather than a scan.
	var walked_bands: Dictionary = {}
	for cell_value: Variant in walked.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		var bands: Array = walked_bands.get(column, [])
		bands.append(cell.y)
		walked_bands[column] = bands
	var claimed: Dictionary = {}
	for key: Vector4i in keys:
		if key.w >= FACE_DIRECTIONS.size() \
				or int(treatments[key]) != SkinTreatment.FACADE:
			continue
		var column_key := Vector3i(key.x, key.w, key.z)
		if claimed.has(column_key):
			continue
		if not faces.has(Vector4i(key.x, key.y - STONE_COURSE_BANDS, key.z,
				key.w)):
			continue
		var direction := STONE_FACE_DIRECTIONS[key.w]
		var front := Vector3i(key.x + direction.x, key.y, key.z + direction.z)
		var free := true
		# ONE BAND FURTHER DOWN THAN THE PANEL'S OWN COURSE (fix 1, minor 7).
		# The course is {key.y - 1, key.y} and the projection's floor sits at
		# `(key.y - 1) x CELL_SIZE`, so its two bearers hang SKYWALK_BEARER_DROP
		# into the band BELOW that -- `key.y - 2`, which this loop used to leave
		# unasked. The walked half of that band was already covered (the headroom
		# rule below refuses a walked cell within three bands); what was not is
		# BUILT mass, so a bay could hang its corbels inside the roof of the
		# house across the street. The skywalk path has carried the matching
		# guard since it landed (`SKYWALK_UNDERCUT_BANDS`); this is its twin.
		for band in range(0, STONE_COURSE_BANDS + 1):
			var probe := front - Vector3i.UP * band
			free = free and not solids.has(probe) and not retained.has(probe) \
				and not paved.has(probe) and not walked.has(probe) \
				and not blocked.has(probe)
		if not free:
			continue
		for band_value: Variant in walked_bands.get(
				Vector2i(front.x, front.z), []):
			var band := int(band_value)
			if band < key.y and key.y - band < FACADE_OUTCROP_MIN_HEADROOM_BANDS:
				free = false
			elif band >= key.y:
				free = false
		if not free:
			continue
		var roll := _face_noise(key, FACADE_OUTCROP_KIND_SALT)
		if roll >= FACADE_BAY_ODDS + FACADE_BUMP_ODDS:
			continue
		claimed[column_key] = true
		out[key] = FacadeOutcrop.BAY if roll < FACADE_BAY_ODDS \
			else FacadeOutcrop.BUMP
	return out


static func maze_facade_outcroppings(retained: Dictionary, solids: Dictionary,
		paved: Dictionary = {}, plinths: Dictionary = {},
		walked: Dictionary = {}, shell: Dictionary = {},
		world_seed: int = 0,
		blocked: Dictionary = {}) -> EnvironmentInstancePayload:
	## TASK I3 -- the projections themselves. Every piece carries a
	## `maze-outcrop/` id that no reading of the skin mistakes for cladding: the
	## C5b identity is one instance per PANEL of the shell, and a bay window is
	## not a panel. Same separation the garden dressing already has.
	##
	## THE BAY WINDOW is a one-cell box hung on the panel's own course: the
	## family's WINDOW module facing out at the box's front, its two boarded
	## cheeks closing the returns, the authored 1.5 m deck as a flat lid, and two
	## bearers under the floor. Every module is pinned by its OUTER FACE to the
	## boundary it closes, which is `_maze_facade_transform`'s own idiom, so the
	## box is exactly one cell and nothing is scaled or jittered.
	##
	## THE BUMP-OUT is the panel's own wall pushed HALF a cell proud, with two
	## measured corner posts filling the half-cell body behind it and the same
	## two bearers underneath. It is a jetty rather than a room: the same wall,
	## the same window rhythm, a storey of it standing forward of the block.
	##
	## EVERY OVERHANG SHOWS ITS BRACKET. Both kinds carry two bearers and there
	## is no branch that can emit a projection without them, which is what keeps
	## the corpus `bare_overhangs` pin at zero honest for this channel too.
	var out := EnvironmentInstancePayload.new()
	var kinds := maze_facade_outcrop_kinds(retained, solids, paved, plinths,
		walked, shell, blocked)
	if kinds.is_empty():
		return out
	var keys: Array[Vector4i] = []
	keys.assign(kinds.keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		var direction := STONE_FACE_DIRECTIONS[key.w]
		var outward := Vector3(direction)
		var cross := Vector3(-outward.z, 0.0, outward.x)
		var yaw := atan2(outward.x, outward.z)
		var floor_y := float(key.y + 1) * FabricRecipe.CELL_SIZE \
			- STONE_MODULE_HEIGHT
		var boundary := Vector3(key.x, 0.0, key.z) * FabricRecipe.CELL_SIZE \
			+ outward * (FabricRecipe.CELL_SIZE * 0.5)
		var pool := SettlementFabricProgram.cell_facade_pool(
			maze_facade_family(key, world_seed))
		var stable := "maze-outcrop/%d/%d/%d/%d" % [key.x, key.y, key.z, key.w]
		var reach := FabricRecipe.CELL_SIZE \
			if int(kinds[key]) == FacadeOutcrop.BAY else FACADE_BUMP_REACH
		if int(kinds[key]) == FacadeOutcrop.BAY:
			# The pool's first entry is its family's WINDOW and its second is a
			# boarded panel, by construction of `WOOD_CELL_FACADE_*` -- asserted
			# by `test_the_outcrop_constants_mirror_the_module_descriptors`.
			var face_origin := boundary + outward \
				* (FabricRecipe.CELL_SIZE - FACADE_FRONT_DEPTH)
			face_origin.y = floor_y
			out.add(pool[0], Transform3D(Basis(Vector3.UP, yaw), face_origin),
				Color.WHITE, StringName("%s/face" % stable))
			for side in 2:
				var hand := 1.0 if side == 0 else -1.0
				var cheek_out := cross * hand
				var cheek_origin := boundary \
					+ outward * (FabricRecipe.CELL_SIZE * 0.5) \
					+ cheek_out * (FabricRecipe.CELL_SIZE * 0.5 \
						- FACADE_FRONT_DEPTH)
				cheek_origin.y = floor_y
				out.add(pool[1], Transform3D(Basis(Vector3.UP,
					atan2(cheek_out.x, cheek_out.z)), cheek_origin),
					Color.WHITE, StringName("%s/cheek/%d" % [stable, side]))
			var cap_origin := boundary \
				+ outward * (FabricRecipe.CELL_SIZE * 0.5)
			cap_origin.y = float(key.y + 1) * FabricRecipe.CELL_SIZE \
				- SKYWALK_DECK_THICKNESS
			var cap_basis := Basis(Vector3.UP, yaw)
			out.add(FACADE_OUTCROP_CAP, Transform3D(cap_basis, cap_origin \
				+ cap_basis * Vector3(FabricRecipe.CELL_SIZE * 0.5, 0.0, 0.0)),
				Color.WHITE, StringName("%s/cap" % stable))
		else:
			var face_origin := boundary \
				+ outward * (FACADE_BUMP_REACH - FACADE_FRONT_DEPTH)
			face_origin.y = floor_y
			out.add(maze_facade_module(key, world_seed),
				Transform3D(Basis(Vector3.UP, yaw), face_origin), Color.WHITE,
				StringName("%s/face" % stable))
			for side in 2:
				var hand := 1.0 if side == 0 else -1.0
				var post_origin := boundary \
					+ cross * hand * (FabricRecipe.CELL_SIZE * 0.5 \
						- FACADE_OUTCROP_POST_HALF) \
					+ outward * FACADE_OUTCROP_POST_HALF
				post_origin.y = floor_y
				out.add(FACADE_OUTCROP_POST,
					Transform3D(Basis(Vector3.UP, yaw), post_origin),
					Color.WHITE, StringName("%s/post/%d" % [stable, side]))
		# THE BEARERS, and they are the skywalk's own: the measured 1.94 m corbel
		# laid ACROSS the face under the projection's floor. One at the wall and
		# one at the projection's outer edge, which is where a jetty's two
		# joists really are.
		#
		# STATIONED BY THE CORBEL'S OWN DEPTH (fix 1, minor 4), not by a fraction
		# of the reach. At 0.3 and 0.7 of the reach the pair overlapped by 65 %
		# on a bump-out and the OUTER corbel hung 0.208 m PAST the face it was
		# meant to bear -- a plate floating in front of the wall, which is the
		# opposite of what a visible bracket is for. Half a depth in from each
		# end puts the inner corbel's back on the wall and the outer corbel's
		# front on the projection's own face, which is what the paragraph above
		# has always claimed.
		#
		# AND A BUMP-OUT IS SHALLOWER THAN THIS CORBEL IS DEEP -- 0.750 m of
		# jetty against 0.866 m of timber -- so on that kind the two stations
		# CROSS, by 0.116 m, and the pair reads as one plate rather than as two
		# joists. That is the module's measurement rather than a choice, and it
		# is the honest state: what the crossing costs is 0.116 m of corbel
		# tailing past the face where the old fraction cost 0.208 m, and no
		# timber now passes the face the projection presents to the street.
		var across := Basis(Vector3.UP, atan2(-cross.z, cross.x))
		for index in 2:
			var station := SKYWALK_BEARER_DEPTH * 0.5 if index == 0 \
				else reach - SKYWALK_BEARER_DEPTH * 0.5
			var bearer_origin := boundary + outward * station \
				+ cross * (SKYWALK_BEARER_REACH * 0.5)
			bearer_origin.y = floor_y - SKYWALK_BEARER_DROP
			out.add(SKYWALK_BEARER, Transform3D(across, bearer_origin),
				Color.WHITE, StringName("%s/bearer/%d" % [stable, index]))
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
	## `maze_stone_face_overhangs_walk or maze_stone_cap_juts_over_walk` -- one
	## flag, one meaning, and the branch below decides which axis it cuts. A
	## SIDE panel is cut back to its own band (it hangs into the street under
	## it); a CAP is cut back to its own run (it reaches into the street beside
	## it). Each predicate answers for its own kind of panel and false for the
	## other, so the two can never both be asking.
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
	# THE HORIZONTAL TRIM (task I1 fix 1), and it is the same word doing the
	# same job on the other axis: a cap that reaches over a street lays only the
	# run it closes -- its own cell alone, or the two cells of a pair -- instead
	# of the module's whole 3 m. `maze_stone_cap_juts_over_walk` is the caller's
	# test and carries the measurement.
	#
	# IT CANNOT OPEN A HOLE, and unlike the two vertical trims that is true by
	# arithmetic rather than by a corpus fact. The boundary a cap closes is its
	# own run and nothing else; the trimmed slab is that run exactly, and the
	# 0.135 m the module stands proud on its cross axis is untouched. A PAIRED
	# cap already lays 3.0 m over a 3.0 m run, so the trim is identity there and
	# the predicate never fires on one anyway.
	var half := Vector3(partner) * FabricRecipe.CELL_SIZE * 0.5
	var length := STONE_MODULE_HEIGHT
	if trimmed:
		length = FabricRecipe.CELL_SIZE \
			* (2.0 if partner != Vector3i.ZERO else 1.0)
	var span := length if direction == Vector3i.UP else -length
	var basis := Basis(Vector3.RIGHT, -PI * 0.5 * signf(span))
	if partner.x != 0:
		basis = Basis(Vector3.UP, PI * 0.5) * basis
	if trimmed:
		basis.y = basis.y * (length / STONE_MODULE_HEIGHT)
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


static func surface_visual_payload(plan: PublicRealmSurfacePlan,
		footprints: Dictionary = {}) -> EnvironmentInstancePayload:
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
	_append_courtyard_paving(out, courtyard_cells, plan, footprints)
	_append_guard_instances(out, plan.guard_segments)
	assert(out.validate())
	return out


static func production_surface_payload(plan: PublicRealmSurfacePlan,
		footprints: Dictionary = {}) -> EnvironmentInstancePayload:
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
	_append_courtyard_paving(out, courtyard_cells, plan, footprints)
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


static func production_surface_bundle(plan: PublicRealmSurfacePlan,
		footprints: Dictionary = {}) -> EnvironmentInstancePayload:
	## Production adapter: plank instances plus the sealed plan's generated
	## stair/ramp meshes in one streamable payload. Patch skins stay review
	## diagnostics; only collision-bearing transition geometry may stream, so a
	## STAIR claim can never remain an invisible hole between plank runs.
	var out := production_surface_payload(plan, footprints)
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
		cells: Array[Vector3i], plan: PublicRealmSurfacePlan,
		footprints: Dictionary = {}) -> void:
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
		if has_corner and maze_courtyard_planter_is_clear(footprints, cell):
			corner_cells.append(cell)
	# TASK I4 ROUND 6, B2 -- EVERY DECOR CHANNEL IS GATED, INCLUDING THIS ONE.
	# The garden planting learnt in round 5 that a lattice cell is not free
	# space; this channel never learnt anything, and it has stood the same
	# `sfv.fabric.planter.003` on a court corner since the courts were built with
	# no measurement of what is really there. The fallback is filtered too: an
	# unclear corner is not a better place to stand a planter merely because no
	# corner was clear.
	if corner_cells.size() < 2:
		corner_cells.assign([])
		for cell: Vector3i in cells:
			if maze_courtyard_planter_is_clear(footprints, cell):
				corner_cells.append(cell)
	if corner_cells.is_empty():
		return
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
	var planter_cells: Array[Vector3i] = [first_cell]
	if second_cell != first_cell:
		planter_cells.append(second_cell)
	for index in planter_cells.size():
		var cell := planter_cells[index]
		out.add(COURTYARD_PLANTER,
			Transform3D(Basis(Vector3.UP, float(index) * PI),
				maze_courtyard_planter_origin(cell)), Color.WHITE,
			StringName("courtyard-planter/%d/%d/%d/%d" % [cell.x,
				cell.y, cell.z, index]))


static func maze_courtyard_planter_origin(cell: Vector3i) -> Vector3:
	## Where a court's edge planter stands: on the corner its four cells share,
	## a plank's thickness over the boards.
	return (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * FabricRecipe.CELL_SIZE \
		+ Vector3.UP * COURTYARD_PLANTER_LIFT


static func maze_courtyard_planter_is_clear(footprints: Dictionary,
		cell: Vector3i) -> bool:
	## TASK I4 ROUND 6, B2 -- can a planter really stand on this court corner?
	##
	## The piece's own envelope (DECOR_CLEARANCE, quarter turns only, so the
	## rotated footprint is the table's two numbers either way about) against
	## every authored module that reaches the same air. A court corner is by
	## construction the place a room's wall is nearest, which is exactly why this
	## channel needed the measurement the garden channel got in round 5.
	var boxes := footprints.get("boxes", []) as Array
	if boxes.is_empty():
		return true
	var by_cell := footprints.get("by_cell", {}) as Dictionary
	var origin := maze_courtyard_planter_origin(cell)
	var clearance: Vector2 = DECOR_CLEARANCE[COURTYARD_PLANTER]
	var reach := maxf(clearance.x, clearance.y) + DECOR_STANDOFF_MARGIN
	var piece := AABB(origin - Vector3(reach, 0.0, reach),
		Vector3(reach * 2.0, COURTYARD_PLANTER_RISE, reach * 2.0))
	var seen: Dictionary = {}
	for band in range(floori(piece.position.y / FabricRecipe.CELL_SIZE),
			floori((piece.position.y + piece.size.y) / FabricRecipe.CELL_SIZE) \
				+ 1):
		for step: Vector3i in [Vector3i.ZERO, Vector3i(1, 0, 0),
				Vector3i(0, 0, 1), Vector3i(1, 0, 1)]:
			var bucket := by_cell.get(Vector3i(cell.x + step.x, band,
				cell.z + step.z), PackedInt32Array()) as PackedInt32Array
			for index: int in bucket:
				if seen.has(index):
					continue
				seen[index] = true
				if _maze_boxes_overlap(piece, boxes[index] as AABB):
					return false
	return true


static func _maze_boxes_overlap(left: AABB, right: AABB) -> bool:
	return left.position.x + left.size.x > right.position.x + FOOTPRINT_EPSILON \
		and right.position.x + right.size.x > left.position.x + FOOTPRINT_EPSILON \
		and left.position.y + left.size.y > right.position.y + FOOTPRINT_EPSILON \
		and right.position.y + right.size.y > left.position.y + FOOTPRINT_EPSILON \
		and left.position.z + left.size.z > right.position.z + FOOTPRINT_EPSILON \
		and right.position.z + right.size.z > left.position.z + FOOTPRINT_EPSILON


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
