class_name SettlementFabricProgram
extends RefCounted

## Compiled finite vocabulary for the sectional warren. Resource access is
## confined to compile(); topology-only route recipes contribute surface claims
## but never place their own floors.
const CELL := FabricRecipe.CELL_SIZE

const ROCK_PLAIN := &"sfv.fabric.wall.rock.plain.001"
const ROCK_WINDOW := &"sfv.fabric.wall.rock.window.010"
const WOOD_PLAIN := &"sfv.fabric.wall.wood.plain.001"
# These two reviewed assemblies include a coplanar authored door leaf that
# fully fills the arch. The stone version combines the original rock shell with
# the standalone SFV leaf at bake time, preserving the masonry facade instead
# of substituting a timber wall. Gameplay can replace either static assembly
# with an interactive door later.
const ROCK_DOOR_CLOSED := &"sfv.fabric.wall.rock.door.closed.005"
const WOOD_DOOR_CLOSED := &"sfv.fabric.wall.wood.door.closed.001"
# Static exterior entrances always use the reviewed closed leaf above. This
# open assembly is reserved for the two ends of a continuously traversable
# bridge-house: both thresholds already land on sealed upper walking surfaces,
# so the visible opening is circulation rather than a decorative mid-air door.
const WOOD_DOOR_OPEN := &"sfv.fabric.wall.wood.door.open.001"
const ROCK_DOOR := ROCK_DOOR_CLOSED
const WOOD_DOOR := WOOD_DOOR_CLOSED
const PORTAL_JAMB := &"sfv.deck.pillar.001"
const FLOOR := &"sfv.fabric.floor.l.001"
const GALLERY_FLOOR := &"sfv.fabric.gallery.floor.m.001"
const SETBACK_CAP := &"sfv.deck.floor.s.001"
const ROOF_BLUE := &"sfv.fabric.roof.half.s.blue.002"
const ROOF_ORANGE := &"sfv.fabric.roof.half.s.orange.002"
const ROOF_BISECT_LEFT_BLUE := &"sfv.fabric.roof.bisect.left.s.blue.001"
const ROOF_BISECT_RIGHT_BLUE := &"sfv.fabric.roof.bisect.right.s.blue.001"
const ROOF_BISECT_LEFT_ORANGE := &"sfv.fabric.roof.bisect.left.s.orange.001"
const ROOF_BISECT_RIGHT_ORANGE := &"sfv.fabric.roof.bisect.right.s.orange.001"
const COMPACT_ROOF_03 := &"lpfv.fabric.roof.compact.orange.03"
const COMPACT_ROOF_06 := &"lpfv.fabric.roof.compact.orange.06"
const COMPACT_ROOF_SLATE_03 := &"lpfv.fabric.roof.compact.slate.03"
const COMPACT_ROOF_SLATE_06 := &"lpfv.fabric.roof.compact.slate.06"
const COMPACT_ROOF_ORANGE_REAR := \
	&"lpfv.fabric.roof.compact.orange.03.rear"
const COMPACT_ROOF_ORANGE_FRONT := \
	&"lpfv.fabric.roof.compact.orange.06.front"
const COMPACT_ROOF_SLATE_REAR := \
	&"lpfv.fabric.roof.compact.slate.06.rear"
const COMPACT_ROOF_SLATE_FRONT := \
	&"lpfv.fabric.roof.compact.slate.03.front"
const COMPACT_ROOF_ORANGE_REAR_END := \
	&"lpfv.fabric.roof.compact.orange.03.rear.end"
const COMPACT_ROOF_ORANGE_FRONT_END := \
	&"lpfv.fabric.roof.compact.orange.06.front.end"
const COMPACT_ROOF_SLATE_REAR_END := \
	&"lpfv.fabric.roof.compact.slate.06.rear.end"
const COMPACT_ROOF_SLATE_FRONT_END := \
	&"lpfv.fabric.roof.compact.slate.03.front.end"
const COMPACT_ROOF_ORANGE_MIDDLE := \
	&"lpfv.fabric.roof.compact.orange.06.middle"
const COMPACT_ROOF_SLATE_MIDDLE := \
	&"lpfv.fabric.roof.compact.slate.03.middle"
const COMPACT_ROOF_ORANGE_REAR_END_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.03.rear.end.tight"
const COMPACT_ROOF_ORANGE_FRONT_END_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.06.front.end.tight"
const COMPACT_ROOF_ORANGE_REAR_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.03.rear.tight"
const COMPACT_ROOF_ORANGE_MIDDLE_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.06.middle.tight"
const COMPACT_ROOF_ORANGE_FRONT_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.06.front.tight"
const COMPACT_ROOF_SLATE_REAR_END_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.06.rear.end.tight"
const COMPACT_ROOF_SLATE_FRONT_END_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.03.front.end.tight"
const COMPACT_ROOF_SLATE_REAR_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.06.rear.tight"
const COMPACT_ROOF_SLATE_MIDDLE_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.03.middle.tight"
const COMPACT_ROOF_SLATE_FRONT_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.03.front.tight"
const COMPACT_ROOF_ORANGE_RUN_START := \
	&"lpfv.fabric.roof.compact.orange.03.run.start"
const COMPACT_ROOF_ORANGE_RUN_MIDDLE := \
	&"lpfv.fabric.roof.compact.orange.03.run.middle"
const COMPACT_ROOF_ORANGE_RUN_MIDDLE_MIRROR := \
	&"lpfv.fabric.roof.compact.orange.03.run.middle.mirror_z"
const COMPACT_ROOF_ORANGE_RUN_END := \
	&"lpfv.fabric.roof.compact.orange.03.run.end"
const COMPACT_ROOF_ORANGE_RUN_START_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.03.run.start.tight"
const COMPACT_ROOF_ORANGE_RUN_START_FLUSH := \
	&"lpfv.fabric.roof.compact.orange.03.run.start.flush"
const COMPACT_ROOF_ORANGE_RUN_START_TIGHT_FLUSH := \
	&"lpfv.fabric.roof.compact.orange.03.run.start.tight.flush"
const COMPACT_ROOF_ORANGE_RUN_MIDDLE_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.03.run.middle.tight"
const COMPACT_ROOF_ORANGE_RUN_MIDDLE_TIGHT_MIRROR := \
	&"lpfv.fabric.roof.compact.orange.03.run.middle.tight.mirror_z"
const COMPACT_ROOF_ORANGE_RUN_END_TIGHT := \
	&"lpfv.fabric.roof.compact.orange.03.run.end.tight"
const COMPACT_ROOF_ORANGE_RUN_END_FLUSH := \
	&"lpfv.fabric.roof.compact.orange.03.run.end.flush"
const COMPACT_ROOF_ORANGE_RUN_END_TIGHT_FLUSH := \
	&"lpfv.fabric.roof.compact.orange.03.run.end.tight.flush"
const COMPACT_ROOF_SLATE_RUN_START := \
	&"lpfv.fabric.roof.compact.slate.03.run.start"
const COMPACT_ROOF_SLATE_RUN_MIDDLE := \
	&"lpfv.fabric.roof.compact.slate.03.run.middle"
const COMPACT_ROOF_SLATE_RUN_MIDDLE_MIRROR := \
	&"lpfv.fabric.roof.compact.slate.03.run.middle.mirror_z"
const COMPACT_ROOF_SLATE_RUN_END := \
	&"lpfv.fabric.roof.compact.slate.03.run.end"
const COMPACT_ROOF_SLATE_RUN_START_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.03.run.start.tight"
const COMPACT_ROOF_SLATE_RUN_START_FLUSH := \
	&"lpfv.fabric.roof.compact.slate.03.run.start.flush"
const COMPACT_ROOF_SLATE_RUN_START_TIGHT_FLUSH := \
	&"lpfv.fabric.roof.compact.slate.03.run.start.tight.flush"
const COMPACT_ROOF_SLATE_RUN_MIDDLE_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.03.run.middle.tight"
const COMPACT_ROOF_SLATE_RUN_MIDDLE_TIGHT_MIRROR := \
	&"lpfv.fabric.roof.compact.slate.03.run.middle.tight.mirror_z"
const COMPACT_ROOF_SLATE_RUN_END_TIGHT := \
	&"lpfv.fabric.roof.compact.slate.03.run.end.tight"
const COMPACT_ROOF_SLATE_RUN_END_FLUSH := \
	&"lpfv.fabric.roof.compact.slate.03.run.end.flush"
const COMPACT_ROOF_SLATE_RUN_END_TIGHT_FLUSH := \
	&"lpfv.fabric.roof.compact.slate.03.run.end.tight.flush"
const ROOM_ROOF_01 := &"lpfv.fabric.roof.room.orange.01"
const ROOM_ROOF_04 := &"lpfv.fabric.roof.room.orange.04"
const ROOM_ROOF_02 := &"lpfv.fabric.roof.room.boarded.02"
const ROOM_ROOF_05 := &"lpfv.fabric.roof.room.boarded.05"
const ROOF_WINDOW_01 := &"sfv.fabric.roof.window.001"
const ROOF_WINDOW_02 := &"sfv.fabric.roof.window.002"
const ROOF_WINDOW_03 := &"sfv.fabric.roof.window.003"
const ROOF_WINDOW_04 := &"sfv.fabric.roof.window.004"
const ROOF_SEAM := &"sfv.fabric.roof.seam.m.002"
const COMPACT_CHIMNEY := &"lpfv.fabric.chimney.orange.01"
const TERRACE_CHIMNEY := &"sfv.fabric.chimney.002"
const FACADE_IVY := &"sfv.fabric.ivy.001"
const FACADE_CLOTHES := &"sfv.fabric.clothes.001"
const FACADE_SIGN := &"sfv.fabric.sign.tavern.001"
const ROOF_PLANTER := &"sfv.fabric.planter.003"
const ROOF_TERRACE_AWNING := &"sfv.fabric.awning.blue.001"
const ROOF_FLOWER_BLUE := &"lpfv.flower.02"
const ROOF_FLOWER_WARM := &"lpfv.flower.04"
const ROOF_FLOWER_SMALL := &"lpfv.flower.01"
const ROOF_FLOWER_TALL := &"lpfv.flower.03"
const ROOF_FLOWER_PALE := &"lpfv.flower.05"
const TERRACE_LANTERN_TABLE := &"lpfv.fabric.prop.lantern.table.01"
const TERRACE_LANTERN_POST := &"lpfv.fabric.prop.lantern.post.02"
const TERRACE_BARREL_A := &"lpfv.fabric.prop.barrel.01"
const TERRACE_BARREL_B := &"lpfv.fabric.prop.barrel.02"
const TERRACE_BAG := &"lpfv.fabric.prop.bag.01"
const TERRACE_BENCH_ALT := &"lpfv.fabric.prop.bench.01"
const TERRACE_BENCH := &"lpfv.fabric.prop.bench.02"
const TERRACE_BUCKET := &"lpfv.fabric.prop.bucket.01"
const TERRACE_CHAIR := &"lpfv.fabric.prop.chair.01"
const TERRACE_CRATE := &"lpfv.fabric.prop.crate.01"
const TERRACE_FIREWOOD := &"lpfv.fabric.prop.firewood.01"
const TERRACE_PLANT_LOW := &"lpfv.fabric.prop.plant.low.01"
const TERRACE_PLANT_MID := &"lpfv.fabric.prop.plant.mid.02"
const TERRACE_PLANT_BROAD := &"lpfv.fabric.prop.plant.broad.03"
const TERRACE_PLANT_TALL := &"lpfv.fabric.prop.plant.tall.04"
const LPFV_PREFAB_DOORS: Array[StringName] = [
	&"lpfv.fabric.door.closed.01",
	&"lpfv.fabric.door.closed.02",
]
# All seven complete houses reuse the same authored jamb transform. Their total
# AABBs do not: Houses 03--06 extend far to the left, and every roof eave extends
# well beyond the wall. Consequently neither an AABB centre nor its outer edge
# identifies this aperture. The `_01` pieces are centred jamb frames already
# merged into each house; the `_02` leaves are authored about their right hinge.
# The 0.548 m half-leaf offset below puts that hinge on the jamb while keeping the
# complete leaf centred in the opening. Production landmark captures visually
# review this source-pack relationship.
const LPFV_PREFAB_DOOR_ORIGIN := Vector3(1.311, 0.0, 2.869)
const GABLE := &"sfv.fabric.gable.wood.m.001"
const BRACE := &"sfv.fabric.brace.wood.002"
const ATTACHMENT_BRACKET_M := &"sfv.fabric.bracket.wood.m.attach.001"
const DIAGONAL_BRACE := &"sfbp.wwall.support.s.002"
const DECK_PILLAR := &"sfv.deck.pillar.001"
const WALL_WOOD_S_A := &"sfv.fabric.wall.wood.s.001"
const WALL_WOOD_S_B := &"sfv.fabric.wall.wood.s.002"
const WALL_WOOD_CORNER_S := &"sfv.fabric.wall.wood.corner.s.001"
const WALL_WOOD_WINDOW_S_BLUE := &"sfv.fabric.wall.wood.window.s.002"
const WALL_WOOD_WINDOW_S_ORANGE := &"sfv.fabric.wall.wood.window.s.004"
const WALL_WOOD_WINDOW_S_AMBER := &"sfv.fabric.wall.wood.window.s.006"
const WINDOW_ROOF_ORANGE := &"sfv.fabric.wall.wood.window.roof.001"
const WINDOW_ROOF_BLUE := &"sfv.fabric.wall.wood.window.roof.004"
const WINDOW_ROOF_ORANGE_TRIMMED := \
	&"sfv.fabric.wall.wood.window.roof.001.trimmed"
const WINDOW_ROOF_BLUE_TRIMMED := \
	&"sfv.fabric.wall.wood.window.roof.004.trimmed"
const WINDOW_ROOF_ORANGE_PARTY_LEFT := \
	&"sfv.fabric.wall.wood.window.roof.001.party.left"
const WINDOW_ROOF_ORANGE_PARTY_RIGHT := \
	&"sfv.fabric.wall.wood.window.roof.001.party.right"
const WINDOW_ROOF_BLUE_PARTY_LEFT := \
	&"sfv.fabric.wall.wood.window.roof.004.party.left"
const WINDOW_ROOF_BLUE_PARTY_RIGHT := \
	&"sfv.fabric.wall.wood.window.roof.004.party.right"

## TASK I4 ROUND 7 -- THE DECOR CLASS, enumerated off this file's own vocabulary
## rather than guessed from an id.
##
## A DECOR module is a piece of DRESSING: it encloses nothing, bears nothing,
## carries no opening, and a town with none of it is the same town less
## furnished. That is the whole of the definition and it is why the class can be
## withdrawn from one unit without the composition noticing -- every other module
## a recipe places (a wall, a floor, a roof, a door, a rail, a stair, a chimney,
## a brace) is part of what the building IS.
##
## WHAT IT IS FOR. The r6 review measured the user's own circled piece --
## `...house.001.part01.room00.garden/garden.planter` on 12/compact -- sharing
## 0.66 x 0.74 x 0.93 m with two `maze-stone` rock panels the SAME COMPILE lays,
## and the round-7 ruling is that a dressing module standing inside fabric-laid
## masonry is withdrawn from that unit rather than left buried. Naming the class
## here keeps the compiler's predicate one lookup wide and keeps "what counts as
## dressing" a vocabulary statement, next to the constants it is made of.
##
## The planter and the plant that stands in it are BOTH here on purpose: they are
## two placements, they are buried together, and a planter withdrawn without its
## plant leaves a shrub standing in a wall on its own.
##
## TASK I4 ROUND 8 FIX 1 (r7+r8 review I3) -- THE COVERED MARKET'S CONTENTS JOIN
## THE CLASS. Round 7 enumerated this list off the ROOM vocabulary and stopped
## there, so the four modules a covered bazaar is stocked with were in no class
## at all: the review found 2/large's market unit with its barrel and its
## flowers withdrawn from a wall by this very rule while its own stocked counter
## stood 0.109 m inside the same cladding, invisible to the rule and to every
## pin. The counter, the hanging vegetables, the market wheel and the roof
## terrace's awning are dressing by this class's own definition -- they enclose
## nothing, bear nothing, carry no opening -- and they are here now.
const DECOR_MODULE_ASSETS: Array[StringName] = [
	ROOF_PLANTER, FACADE_IVY, FACADE_CLOTHES, FACADE_SIGN,
	ROOF_FLOWER_BLUE, ROOF_FLOWER_WARM, ROOF_FLOWER_SMALL, ROOF_FLOWER_TALL,
	ROOF_FLOWER_PALE,
	TERRACE_LANTERN_TABLE, TERRACE_LANTERN_POST, TERRACE_BARREL_A,
	TERRACE_BARREL_B, TERRACE_BAG, TERRACE_BENCH_ALT, TERRACE_BENCH,
	TERRACE_BUCKET, TERRACE_CHAIR, TERRACE_CRATE, TERRACE_FIREWOOD,
	TERRACE_PLANT_LOW, TERRACE_PLANT_MID, TERRACE_PLANT_BROAD,
	TERRACE_PLANT_TALL,
	ROOF_TERRACE_AWNING, COVERED_MARKET_TABLE, COVERED_MARKET_HANGING_GOODS,
	COVERED_MARKET_WHEEL,
]
## TASK I4 ROUND 8 FIX 1 -- THE ONE PLACEMENT AT WHICH A DECOR-CLASS ASSET IS
## STRUCTURE, named here because the class is keyed by ASSET and this asset does
## two jobs.
##
## `ROOF_TERRACE_AWNING` is dressing over a roof terrace (`garden.awning`,
## `terrace.awning`) and it is also one of the seven `COVERED_MARKET_CANOPIES` --
## the thing a covered bazaar IS. A canopy bears the hanging goods and the wheel,
## `_covered_market_recipe` seals canopy, posts, goods, aisle and backing socket
## as one all-or-nothing transaction, and a market unit places nothing else: a
## withdrawn canopy leaves vegetables hanging in mid-air over a counter, or an
## empty patch of ground where a market is. So a suppression rule reading this
## class skips this placement, and the burial it may carry is a MEASURED, RULED
## case rather than an unseen one -- 2/large's canopy shares 0.584 m of a 0.664 m
## cladding panel that hangs down from the mass ABOVE the market's own bay, at
## 3.0-4.7 m up, where the market's authored cells legitimately are and the
## panel's bottom half has nothing behind it.
##
## The rest of `COVERED_MARKET_CANOPIES` is out of the class entirely for the
## same reason and needs no exception, because those six `sfm.stall.*` pieces are
## canopies and nothing else.
const DECOR_STRUCTURAL_PLACEMENTS: Array[StringName] = [&"canopy"]
## TASK I4 ROUND 7 -- THE OUTRIGGER CLASS: the two authored props that lean OUT
## of the room that places them rather than standing inside its envelope.
##
## Both are diagonal timbers under a projecting storey, and both were measured by
## the r6 review standing their own BAKED COLLIDER in the body column over a
## walked public street -- `sfbp.wwall.support.s.002` from 0.894 m to 4.500 m and
## `sfv.fabric.brace.wood.002` from 1.600 m. A body cannot pass under either.
##
## They are a class of their own and not DECOR because they are not
## interchangeable with dressing: a brace reads as what holds the storey up, and
## withdrawing one is a real loss the report has to state. What they share with
## decor is the only property the suppression needs -- nothing in the composition
## depends on them, so a unit can be built without one.
const OUTRIGGER_MODULE_ASSETS: Array[StringName] = [BRACE, DIAGONAL_BRACE]


static func decor_module_is_dressing(asset_id: StringName,
		placement_id: StringName, decor_assets: Dictionary) -> bool:
	## Whether THIS placement of THIS asset is a withdrawable piece of dressing:
	## the DECOR class, less the placements at which one of its assets is doing
	## structural work. `decor_assets` is `DECOR_MODULE_ASSETS` as a set, built
	## once by the caller, because the predicate is asked of every placement of
	## every unit in a town.
	return decor_assets.has(asset_id) \
		and not DECOR_STRUCTURAL_PLACEMENTS.has(placement_id)


## The facade module pools, indexed by facade phase.
##
## Every entry is a COMPLETE authored wall module, so a phase change is a
## geometry and joinery change rather than a tint. Two invariants keep widening
## these pools inert for everything except what a viewer sees:
##
## 1. Indices 0-2 are the pre-wave modules in their pre-wave order, so any
##    recipe that asks for a bare phase renders exactly what it rendered before.
## 2. Every wood entry measures exactly 3.000 m wide and 3.000 m tall, and every
##    rock entry at most 3.085 m wide -- the width the shipped rock pool already
##    carried. `FabricModuleProgram.facade_aligned_transform` pins a module's
##    OUTER face to the wall plane, so a module no wider than the widest module
##    its family already places cannot grow any recipe's clearance envelope, and
##    therefore cannot change which parcels the visual-compatibility broad phase
##    admits. `tests/test_warren_facade_variety.gd` measures both invariants
##    against the catalog rather than trusting this comment.
const WOOD_FACADE_BLUE: Array[StringName] = [
	&"sfv.fabric.wall.wood.window.001",
	&"sfv.fabric.wall.wood.window.040",
	&"sfv.fabric.wall.wood.window.010",
	&"sfv.fabric.wall.wood.window.004",
	&"sfv.fabric.wall.wood.window.033",
	&"sfv.fabric.wall.wood.plain.005",
	&"sfv.fabric.wall.wood.window.052",
	&"sfv.fabric.wall.wood.window.017",
	&"sfv.fabric.wall.wood.plain.011",
	&"sfv.fabric.wall.wood.window.066",
]
const WOOD_FACADE_ORANGE: Array[StringName] = [
	&"sfv.fabric.wall.wood.window.020",
	&"sfv.fabric.wall.wood.window.060",
	&"sfv.fabric.wall.wood.window.010",
	&"sfv.fabric.wall.wood.window.024",
	&"sfv.fabric.wall.wood.window.037",
	&"sfv.fabric.wall.wood.plain.007",
	&"sfv.fabric.wall.wood.window.056",
	&"sfv.fabric.wall.wood.window.028",
	&"sfv.fabric.wall.wood.plain.015",
	&"sfv.fabric.wall.wood.window.069",
]
## A third timber family so the streetscape graph-colouring has three colours to
## spend instead of two. Its modules are drawn from the part of the bake the
## other two pools do not touch (one module, `window.037`, is shared with the
## orange pool because the flush 3 m window vocabulary runs out at 21 pieces):
## a neighbour in a different family is a different authored wall, not the same
## wall in a different phase.
const WOOD_FACADE_AMBER: Array[StringName] = [
	&"sfv.fabric.wall.wood.window.013",
	&"sfv.fabric.wall.wood.window.048",
	&"sfv.fabric.wall.wood.window.008",
	&"sfv.fabric.wall.wood.window.044",
	&"sfv.fabric.wall.wood.plain.003",
	&"sfv.fabric.wall.wood.window.058",
	&"sfv.fabric.wall.wood.window.064",
	&"sfv.fabric.wall.wood.plain.009",
	&"sfv.fabric.wall.wood.plain.013",
	&"sfv.fabric.wall.wood.window.037",
]
## TASK I2 -- THE HALF-WIDTH FACADE VOCABULARY, one module per fabric cell.
##
## The pools above are the authored 3.000 m wall, which is TWO fabric cells; a
## room recipe spans three of them at a time and never meets the lattice
## boundary. The retained-mass skin does: it clads one 1.5 m cell per panel,
## because that is the unit the shell's coursing and its whole coverage proof are
## written in (`SettlementFabricAssembler.maze_stone_faces`). Cladding it with a
## 3 m module would mean either pairing panels -- which breaks the one-instance-
## per-panel identity task C5b's audit rests on -- or scaling a window to half
## its authored width.
##
## The source pack ships the half-width wall itself, so neither is necessary.
## `SFV_Wall_Wooden_Window_S_*` and `SFV_Wall_Wooden_S_*` measure 1.500 x 3.000 m
## against the 3.000 x 3.000 m of the pools above: exactly one cell wide and
## exactly one storey (`WarrenBuildingParcel.STOREY_BANDS` x
## `FabricRecipe.CELL_SIZE`) tall, which is exactly the course the skin already
## lays. Every entry carries one collision piece, which the H2c census requires
## of anything standing beside a walked cell.
##
## FAMILY MEMBERSHIP IS THE REVIEWED ONE, not a guess. The three window pieces
## are `WALL_WOOD_WINDOW_S_BLUE/ORANGE/AMBER` -- the same three the embedded
## oriel bay picks between on the same district theme -- so a clad mass face and
## the bay on the house beside it are the same authored window. The two plain
## pieces are `WALL_WOOD_S_A/B`, which the shipped balcony recipe already places
## under all three themes and are therefore family-neutral by precedent.
##
## The pool is read with a per-panel hash, so a run of clad mass alternates
## window and boarded panel instead of repeating one module: three of six
## entries carry a window, which is the same rhythm the 3 m pools above carry.
const WOOD_CELL_FACADE_BLUE: Array[StringName] = [
	WALL_WOOD_WINDOW_S_BLUE,
	WALL_WOOD_S_A,
	WALL_WOOD_WINDOW_S_BLUE,
	WALL_WOOD_S_B,
	WALL_WOOD_S_A,
	WALL_WOOD_WINDOW_S_BLUE,
]
const WOOD_CELL_FACADE_ORANGE: Array[StringName] = [
	WALL_WOOD_WINDOW_S_ORANGE,
	WALL_WOOD_S_B,
	WALL_WOOD_WINDOW_S_ORANGE,
	WALL_WOOD_S_A,
	WALL_WOOD_S_B,
	WALL_WOOD_WINDOW_S_ORANGE,
]
const WOOD_CELL_FACADE_AMBER: Array[StringName] = [
	WALL_WOOD_WINDOW_S_AMBER,
	WALL_WOOD_S_A,
	WALL_WOOD_WINDOW_S_AMBER,
	WALL_WOOD_S_B,
	WALL_WOOD_WINDOW_S_AMBER,
	WALL_WOOD_S_A,
]
## The measured front extent of the deepest module in the three pools above --
## `sfv.fabric.wall.wood.window.s.002`, AABB z -0.27658..+0.27658. The skin pins
## its facade panels by this ONE number rather than by a per-asset lookup, so
## every panel of a clad face stands in the same plane and the shallower boarded
## pieces sit at most 0.042 m behind it, which no eye reads and which can only
## make a street wider. `test_the_skin_constants_mirror_the_module_descriptors`
## checks it against the descriptors so a re-bake cannot move it in silence.
## TASK I2 FIX 1, M5 -- this value is transcribed from that module's own
## `|position.z|` (its back half), and the mirror test checks it against
## `end.z` (its front half) instead, because `end.z` is the number the skin's
## own coverage argument is written in. The two differ by 1.1 µm on the
## authored mesh (0.27658215 vs the descriptor's 0.276581), which the 5 mm
## `SKIN_ENVELOPE_TOLERANCE` swallows without comment. Noted rather than
## re-sourced: moving it would not change any coverage bound, only which of
## two numbers a float-noise gap is measured from.
const WOOD_CELL_FACADE_FRONT_DEPTH := 0.27658215
const ROCK_FACADE: Array[StringName] = [
	&"sfv.fabric.wall.rock.window.010",
	&"sfv.fabric.wall.rock.plain.001",
	&"sfv.fabric.wall.rock.window.010",
	&"sfv.fabric.wall.rock.window.m.016",
	&"sfv.fabric.wall.rock.window.m.019",
	&"sfv.fabric.wall.rock.plain.002",
	&"sfv.fabric.wall.rock.window.s.003",
]
## Static generated thresholds are closed. Open frames remain catalogued for a
## future interactive-door assembly but are never selected as a finished wall.
const WOOD_DOORS: Array[StringName] = [
	WOOD_DOOR_CLOSED,
]
const ROCK_DOORS: Array[StringName] = [
	ROCK_DOOR_CLOSED,
]
## Roof-feature stacks. Index 0 is the shipped compact chimney; the rest are the
## authored SFV chimney family, so a capped bay is a different silhouette on
## every roll instead of one repeated stack.
const ROOF_CHIMNEYS: Array[StringName] = [
	&"lpfv.fabric.chimney.orange.01",
	&"sfv.fabric.chimney.002",
	&"sfv.fabric.chimney.005",
	&"sfv.fabric.chimney.003",
]
## The four faces of a square or compact room take four DIFFERENT phases. Every
## offset is >= 3, so each face draws from the widened part of its pool and the
## frozen 0-2 phases keep meaning exactly what they meant before. Offset 0 keeps
## the addressed face on its family's signature module.
const FACE_PHASE_OFFSETS: Array[int] = [0, 3, 5, 4]
## Each segmented footprint can now select one of three authored shell families.
## The even phase is the flush collision-safe construction; the following odd
## phase keeps the same lineage style and adds one measured façade projection.
## This gives the segmenter six genuine asset compositions per footprint while
## preserving one exact fallback for every detailed variant.
const BUILDING_STYLE_COUNT := 3
const FACADE_PHASE_COUNT := BUILDING_STYLE_COUNT * 2
## Dormers use the source pack's complete attic-window shells at reviewed
## family-specific reduced scales. The gabled 001/002 and shed-roof 003/004 families supply real
## cheeks, sills, windows, supports, and closed roofs in their authored
## proportions. Their open backs and feet sit below the host pitch.
# Roof recipes use the wall-top/eave plane as local Y=0. The dormer's feet sit
# above that datum but below the slope at their upslope X position; a negative
# value wrongly exposed them beneath the building eave.
const DORMER_EMBED_Y := 0.10
## The shed source is broader and very slightly taller than the gabled source.
# Its separate 50% scale and 0.22 m registration crown the 3.111 m shell at
# 1.776 m, safely inside the compact host's 2.173 m ridge while leaving its
# downslope window course readable.
const DORMER_SHED_EMBED_Y := 0.22
const DORMER_SCALE := Vector3(0.56, 0.56, 0.56)
const DORMER_SHED_SCALE := Vector3(0.50, 0.50, 0.50)
# Keep the complete shell far enough upslope for the host tiles to bury its
# three construction feet. Its roof tail still runs inward beneath the pitch.
const DORMER_COMPACT_EAVE_OFFSET := 1.15
const DORMER_WIDE_EAVE_OFFSET := 2.15
## Shed shells have a longer upslope roof tail than the steep gabled family.
## Moving only that family slightly toward its eave keeps the open rear buried
## below the host pitch instead of letting a stray timber lip cross the ridge.
const DORMER_SHED_DOWNSLOPE_OFFSET := 0.22
const FEATURE_PORTAL_NORTH := 1
const FEATURE_PORTAL_EAST := 2
const FEATURE_PORTAL_SOUTH := 4
const FEATURE_PORTAL_WEST := 8
const FEATURE_PORTAL_MASK_ALL := FEATURE_PORTAL_NORTH \
	| FEATURE_PORTAL_EAST | FEATURE_PORTAL_SOUTH | FEATURE_PORTAL_WEST
## Preset 003 is the complete switchback: the same aligned two flights as the
## bare preset 004, plus its authored mid-landing, guard posts, and handrails.
## Using the complete asset also makes the solver reserve the real railing
## envelope rather than leaving an apparently broken staircase in final towns.
const STAIR_FULL := &"sfv.fabric.stair.preset.003"
const STAIR_HALF := &"sfv.stair.s.001"
const RAILING := &"sfv.deck.railing.s.001"
const RAILING_MEDIUM := &"sfv.deck.railing.m.001"

## Every reviewed stocked-stall prefab in the bake, not the seven that happened
## to exist before the wave. WarrenMarketSolver picks a family per origin and
## then walks this list, so its width IS how much two towns' bazaars differ.
## The first seven entries are the pre-wave pool in its pre-wave order, which
## keeps `market.stall.00`..`.06` naming the same assets they always named.
const MARKET_STALLS: Array[StringName] = [
	&"sfm.stall.alchemy.002",
	&"sfm.stall.forge.002",
	&"sfm.stall.fish.001",
	&"sfm.stall.tavern.001",
	&"sfm.stall.tavern.002",
	&"sfm.stall.tavern.003",
	&"sfm.stall.butcher.002",
]
## Compact canopies with one reviewed stocked table attachment. Unlike the
## large self-contained stalls above, these fit a single 6 x 3 m frontage and
## make the mass-first bazaar one rich covered unit rather than a distant pair.
const COVERED_MARKET_CANOPIES: Array[StringName] = [
	&"sfm.stall.blue.007",
	&"sfm.stall.orange.006",
	&"sfm.stall.teal.008",
	&"sfm.stall.neutral.009",
	&"sfm.stall.butcher.001",
	# This is a complete 4.24 x 3.03 m framed awning, not a shallow facade
	# decoration. It fits the bazaar's measured 6 x 3 m structural envelope and
	# keeps the exact public aisle clear; putting it on a 1.5 m balcony would
	# project most of the asset into the street below.
	ROOF_TERRACE_AWNING,
	&"sfm.stall.butcher.003",
]
const COVERED_MARKET_TABLE := &"sfm.table.fishmonger.001"
const COVERED_MARKET_HANGING_GOODS := &"sfm.stall.veg_string.001"
const COVERED_MARKET_WHEEL := &"sfm.stall.veg_wheel.001"

const PREFAB_ANCHORS: Array[StringName] = [
	# Keep the original recipe indices stable for reviewed fixtures and captures.
	# These larger authored buildings remain available where a standard, large,
	# or grand fabric can release enough adjacent parcels without breaking a route.
	&"sfv.building.interior.blue.001",
	&"sfv.building.interior.orange.006",
	&"aws.building.003",
	&"sft.building.001",
	&"sfv.building.interior.blue.002",
	&"sfv.building.interior.orange.002",
	&"sfv.building.interior.blue.005",
	&"sfv.building.interior.orange.005",
	&"sfv.building.interior.blue.006",
	&"sfv.building.interior.orange.001",
	# Complete 6--9 m houses are the compact-town vocabulary. They preserve the
	# source pack's authored massing, porches, chimneys, windows, and rooflines as
	# one construction record instead of being imitated with repeated room boxes.
	&"lpfv.building.house.01",
	&"lpfv.building.house.02",
	&"lpfv.building.house.03",
	&"lpfv.building.house.04",
	&"lpfv.building.house.05",
	&"lpfv.building.house.06",
	&"lpfv.building.house.07",
	# The exhaustive source review adds every remaining distinct complete-building
	# silhouette. Exterior-only duplicates of these same meshes were rejected from
	# the catalog because they add filenames, not visual variety.
	&"sfv.building.interior.blue.003",
	&"sfv.building.interior.orange.003",
	&"sfv.building.interior.blue.004",
	&"sfv.building.interior.orange.004",
	&"aws.building.001",
	&"aws.building.002",
	&"sffa.building.001",
	&"sffa.building.002",
	&"sft.building.002",
	&"sft.building.003",
	&"sft.building.004",
	&"sft.building.005",
	&"sft.building.006",
	&"sft.building.007",
	&"lpfv.building.church.01",
]

var referenced_asset_ids: Array[StringName] = []
## Resource-free visual contracts for every asset this vocabulary or one of its
## assembly adapters can emit.  The catalogue is read exactly once here; worker
## layout and payload assembly receive only plain AABBs and never reopen a
## resource to decide whether optional dressing fits the finished town.
var asset_visual_bounds: Dictionary = {}
var module_program: FabricModuleProgram
var _recipes: Dictionary = {}


static func feature_portal_recipe_id(base_recipe_id: StringName,
		portal_mask: int) -> StringName:
	## Private balcony and occupied-skywalk openings are finite recipe variants,
	## never facade overlays. The mask is local to the room so rotations preserve
	## one exact wall aperture and measured module placement per cardinal face.
	assert(not base_recipe_id.is_empty())
	assert(portal_mask > 0 and (portal_mask & ~FEATURE_PORTAL_MASK_ALL) == 0)
	return StringName("%s.portal.%x" % [base_recipe_id, portal_mask])


static func address_door_phase_recipe_id(base_recipe_id: StringName,
		door_phase: int) -> StringName:
	## The second phase uses the baked handed counterpart of the same complete
	## 3 m facade module.  Its visible aperture therefore follows the threshold
	## into the other 1.5 m half-cell without a negative runtime scale.
	assert(not base_recipe_id.is_empty() and door_phase >= 0 and door_phase <= 1)
	return base_recipe_id if door_phase == 0 \
		else StringName("%s.door_b" % base_recipe_id)


static func compile(catalog: EnvironmentCatalog) -> SettlementFabricProgram:
	if catalog == null:
		return null
	var program := SettlementFabricProgram.new()
	program.module_program = _compile_module_program(catalog)
	if program.module_program == null:
		return null
	var modules := program.module_program
	var candidates: Array[FabricRecipe] = [
		_route_recipe(&"route.straight", false, false, false),
		_route_recipe(&"route.corner", false, true, false),
		_route_recipe(&"route.landing", true, true, false),
		_route_recipe(&"deck.straight", false, false, true),
		_route_recipe(&"deck.corner", false, true, true),
		_route_recipe(&"deck.landing", true, true, true),
		_stair_recipe(&"stair.full", STAIR_FULL, 2, 2, modules),
		_stair_recipe(&"stair.half", STAIR_HALF, 1, 1, modules),
		_exterior_stair_facade_recipe(&"stair.facade.full.terrain.blue", &"blue", modules),
		_exterior_stair_facade_recipe(&"stair.facade.full.terrain.orange", &"orange", modules),
		_gallery_recipe(),
		_room_recipe(&"room.base.rock", true, &"rock", true, modules),
		_room_recipe(&"room.base.rock.closed", true, &"rock", false, modules),
		_room_recipe(&"room.base.blue", true, &"blue", true, modules),
		_room_recipe(&"room.base.blue.closed", true, &"blue", false, modules),
		_room_recipe(&"room.base.orange", true, &"orange", true, modules),
		_room_recipe(&"room.base.orange.closed", true, &"orange", false, modules),
		_room_recipe(&"room.base.amber", true, &"amber", true, modules),
		_room_recipe(&"room.base.amber.closed", true, &"amber", false, modules),
		_room_recipe(&"room.upper.blue", false, &"blue", false, modules),
		_room_recipe(&"room.upper.orange", false, &"orange", false, modules),
		_room_recipe(&"room.upper.amber", false, &"amber", false, modules),
		_room_recipe(&"room.upper.stone", false, &"stone", false, modules),
		_room_recipe(&"room.upper.blue.b", false, &"blue", false, modules, 1),
		_room_recipe(&"room.upper.orange.b", false, &"orange", false, modules, 1),
		_room_recipe(&"room.upper.amber.b", false, &"amber", false, modules, 1),
		_room_recipe(&"room.upper.stone.b", false, &"stone", false, modules, 1),
		_room_recipe(&"room.upper.address.blue", false, &"blue", true, modules),
		_room_recipe(&"room.upper.address.orange", false, &"orange", true, modules),
		_room_recipe(&"room.upper.address.amber", false, &"amber", true, modules),
		_room_recipe(&"room.upper.address.stone", false, &"stone", true, modules),
		_room_recipe(&"room.upper.address.blue.b", false, &"blue", true, modules, 1),
		_room_recipe(&"room.upper.address.orange.b", false, &"orange", true, modules, 1),
		_room_recipe(&"room.upper.address.amber.b", false, &"amber", true, modules, 1),
		_room_recipe(&"room.upper.address.stone.b", false, &"stone", true, modules, 1),
		_long_room_recipe(&"room.long.base.rock", true, &"rock", true, 0, modules),
		_long_room_recipe(&"room.long.base.rock.closed", true, &"rock", false, 1, modules),
		_long_room_recipe(&"room.long.base.blue", true, &"blue", true, 0, modules),
		_long_room_recipe(&"room.long.base.blue.closed", true, &"blue", false, 1, modules),
		_long_room_recipe(&"room.long.base.orange", true, &"orange", true, 0, modules),
		_long_room_recipe(&"room.long.base.orange.closed", true, &"orange", false, 1, modules),
		_long_room_recipe(&"room.long.base.amber", true, &"amber", true, 0, modules),
		_long_room_recipe(&"room.long.base.amber.closed", true, &"amber", false, 1, modules),
		_long_room_recipe(&"room.long.upper.blue.a", false, &"blue", false, 0, modules),
		_long_room_recipe(&"room.long.upper.blue.b", false, &"blue", false, 1, modules),
		_long_room_recipe(&"room.long.upper.orange.a", false, &"orange", false, 0, modules),
		_long_room_recipe(&"room.long.upper.orange.b", false, &"orange", false, 1, modules),
		_long_room_recipe(&"room.long.upper.amber.a", false, &"amber", false, 0, modules),
		_long_room_recipe(&"room.long.upper.amber.b", false, &"amber", false, 1, modules),
		_long_room_recipe(&"room.long.upper.stone.a", false, &"stone", false, 0, modules),
		_long_room_recipe(&"room.long.upper.stone.b", false, &"stone", false, 1, modules),
		_long_room_recipe(&"room.long.upper.address.blue.a", false, &"blue", true, 0, modules),
		_long_room_recipe(&"room.long.upper.address.blue.b", false, &"blue", true, 1, modules),
		_long_room_recipe(&"room.long.upper.address.orange.a", false, &"orange", true, 0, modules),
		_long_room_recipe(&"room.long.upper.address.orange.b", false, &"orange", true, 1, modules),
		_long_room_recipe(&"room.long.upper.address.amber.a", false, &"amber", true, 0, modules),
		_long_room_recipe(&"room.long.upper.address.amber.b", false, &"amber", true, 1, modules),
		_long_room_recipe(&"room.long.upper.address.stone.a", false, &"stone", true, 0, modules),
		_long_room_recipe(&"room.long.upper.address.stone.b", false, &"stone", true, 1, modules),
		_tower_room_recipe(&"room.tower.base.rock", true, &"rock", true, modules),
		_tower_room_recipe(&"room.tower.base.rock.closed", true, &"rock", false, modules),
		_tower_room_recipe(&"room.tower.base.blue", true, &"blue", true, modules),
		_tower_room_recipe(&"room.tower.base.blue.closed", true, &"blue", false, modules),
		_tower_room_recipe(&"room.tower.base.orange", true, &"orange", true, modules),
		_tower_room_recipe(&"room.tower.base.orange.closed", true, &"orange", false, modules),
		_tower_room_recipe(&"room.tower.base.amber", true, &"amber", true, modules),
		_tower_room_recipe(&"room.tower.base.amber.closed", true, &"amber", false, modules),
		_tower_room_recipe(&"room.tower.upper.blue", false, &"blue", false, modules),
		_tower_room_recipe(&"room.tower.upper.orange", false, &"orange", false, modules),
		_tower_room_recipe(&"room.tower.upper.amber", false, &"amber", false, modules),
		_tower_room_recipe(&"room.tower.upper.stone", false, &"stone", false, modules),
		_bridge_room_recipe(&"room.bridge.tower.blue", &"blue", modules),
		_open_bridge_gallery_recipe(&"room.bridge.gallery.blue", &"blue", modules),
		_bridge_room_recipe(&"room.bridge.tower.orange", &"orange", modules),
		_bridge_room_recipe(&"room.bridge.slim.blue", &"blue", modules),
		_bridge_room_recipe(&"room.bridge.slim.orange", &"orange", modules),
		_bridge_room_recipe(&"room.jetty.tower.blue", &"blue", modules, 1),
		_bridge_room_recipe(&"room.jetty.tower.orange", &"orange", modules, 1),
		_bridge_room_recipe(&"room.jetty.slim.blue", &"blue", modules, 1),
		_bridge_room_recipe(&"room.jetty.slim.orange", &"orange", modules, 1),
		_tower_room_recipe(&"room.tower.upper.blue.b", false, &"blue", false, modules, 1),
		_tower_room_recipe(&"room.tower.upper.orange.b", false, &"orange", false, modules, 1),
		_tower_room_recipe(&"room.tower.upper.amber.b", false, &"amber", false, modules, 1),
		_tower_room_recipe(&"room.tower.upper.stone.b", false, &"stone", false, modules, 1),
		_tower_room_recipe(&"room.tower.upper.address.blue", false, &"blue", true, modules),
		_tower_room_recipe(&"room.tower.upper.address.orange", false, &"orange", true, modules),
		_tower_room_recipe(&"room.tower.upper.address.amber", false, &"amber", true, modules),
		_tower_room_recipe(&"room.tower.upper.address.stone", false, &"stone", true, modules),
		_tower_room_recipe(&"room.tower.upper.address.blue.b", false, &"blue", true, modules, 1),
		_tower_room_recipe(&"room.tower.upper.address.orange.b", false, &"orange", true, modules, 1),
		_tower_room_recipe(&"room.tower.upper.address.amber.b", false, &"amber", true, modules, 1),
		_tower_room_recipe(&"room.tower.upper.address.stone.b", false, &"stone", true, modules, 1),
		_slim_room_recipe(&"room.slim.base.rock", true, &"rock", true, modules),
		_slim_room_recipe(&"room.slim.base.rock.closed", true, &"rock", false, modules),
		_slim_room_recipe(&"room.slim.base.blue", true, &"blue", true, modules),
		_slim_room_recipe(&"room.slim.base.blue.closed", true, &"blue", false, modules),
		_slim_room_recipe(&"room.slim.base.orange", true, &"orange", true, modules),
		_slim_room_recipe(&"room.slim.base.orange.closed", true, &"orange", false, modules),
		_slim_room_recipe(&"room.slim.base.amber", true, &"amber", true, modules),
		_slim_room_recipe(&"room.slim.base.amber.closed", true, &"amber", false, modules),
		_slim_room_recipe(&"room.slim.upper.blue", false, &"blue", false, modules),
		_slim_room_recipe(&"room.slim.upper.orange", false, &"orange", false, modules),
		_slim_room_recipe(&"room.slim.upper.amber", false, &"amber", false, modules),
		_slim_room_recipe(&"room.slim.upper.stone", false, &"stone", false, modules),
		_slim_room_recipe(&"room.slim.upper.blue.b", false, &"blue", false, modules, 1),
		_slim_room_recipe(&"room.slim.upper.orange.b", false, &"orange", false, modules, 1),
		_slim_room_recipe(&"room.slim.upper.amber.b", false, &"amber", false, modules, 1),
		_slim_room_recipe(&"room.slim.upper.stone.b", false, &"stone", false, modules, 1),
		_slim_room_recipe(&"room.slim.upper.address.blue", false, &"blue", true, modules),
		_slim_room_recipe(&"room.slim.upper.address.orange", false, &"orange", true, modules),
		_slim_room_recipe(&"room.slim.upper.address.amber", false, &"amber", true, modules),
		_slim_room_recipe(&"room.slim.upper.address.stone", false, &"stone", true, modules),
		_slim_room_recipe(&"room.slim.upper.address.blue.b", false, &"blue", true, modules, 1),
		_slim_room_recipe(&"room.slim.upper.address.orange.b", false, &"orange", true, modules, 1),
		_slim_room_recipe(&"room.slim.upper.address.amber.b", false, &"amber", true, modules, 1),
		_slim_room_recipe(&"room.slim.upper.address.stone.b", false, &"stone", true, modules, 1),
		_pier_room_recipe(&"room.pier.base.rock", true, &"rock", modules),
		_pier_room_recipe(&"room.pier.upper.blue", false, &"blue", modules),
		_pier_room_recipe(&"room.pier.upper.orange", false, &"orange", modules),
		_passage_room_recipe(&"room.passage.blue", &"blue", false, modules),
		_passage_room_recipe(&"room.passage.orange", &"orange", false, modules),
		_passage_room_recipe(&"room.passage.terrain.blue", &"blue", true, modules),
		_passage_room_recipe(&"room.passage.terrain.orange", &"orange", true, modules),
		_stair_house_recipe(&"room.stair_house.blue", &"blue", false, modules),
		_stair_house_recipe(&"room.stair_house.terrain.orange", &"orange", true, modules),
		_supported_court_recipe(),
		_compact_supported_court_recipe(),
		_bridged_compact_court_recipe(),
		_roof_recipe(&"roof.blue", ROOF_BLUE, modules),
		_roof_recipe(&"roof.orange", ROOF_ORANGE, modules),
		_plain_modular_square_roof_recipe(&"roof.square.blue.plain",
			ROOF_BLUE, modules),
		_plain_modular_square_roof_recipe(&"roof.square.orange.plain",
			ROOF_ORANGE, modules),
		_short_roof_recipe(&"roof.short.blue", ROOF_BLUE, modules),
		_short_roof_recipe(&"roof.short.orange", ROOF_ORANGE, modules),
		_complete_room_roof_recipe(&"roof.square.01", ROOM_ROOF_01, modules),
		_complete_room_roof_recipe(&"roof.square.02", ROOM_ROOF_02, modules),
		_complete_room_roof_recipe(&"roof.square.04", ROOM_ROOF_04, modules, true),
		_complete_room_roof_recipe(&"roof.square.05", ROOM_ROOF_05, modules, true),
		_modular_square_dormer_roof_recipe(
			&"roof.square.orange.dormer.left", ROOF_ORANGE,
			ROOF_WINDOW_04, -1, modules),
		_modular_square_dormer_roof_recipe(
			&"roof.square.orange.dormer.right", ROOF_ORANGE,
			ROOF_WINDOW_04, 1, modules),
		_modular_square_dormer_roof_recipe(
			&"roof.square.blue.dormer.left", ROOF_BLUE,
			ROOF_WINDOW_03, -1, modules),
		_modular_square_dormer_roof_recipe(
			&"roof.square.blue.dormer.right", ROOF_BLUE,
			ROOF_WINDOW_03, 1, modules),
		_long_roof_recipe(&"roof.long.blue", ROOF_BLUE, modules),
		_long_roof_recipe(&"roof.long.orange", ROOF_ORANGE, modules),
		_dormered_long_roof_recipe(&"roof.long.blue.dormer.left",
			ROOF_BLUE, ROOF_WINDOW_03, -1, modules),
		_dormered_long_roof_recipe(&"roof.long.blue.dormer.right",
			ROOF_BLUE, ROOF_WINDOW_03, 1, modules),
		_dormered_long_roof_recipe(&"roof.long.orange.dormer.left",
			ROOF_ORANGE, ROOF_WINDOW_04, -1, modules),
		_dormered_long_roof_recipe(&"roof.long.orange.dormer.right",
			ROOF_ORANGE, ROOF_WINDOW_04, 1, modules),
		_paired_dormered_long_roof_recipe(&"roof.long.blue.dormer.pair.left",
			ROOF_BLUE, ROOF_WINDOW_03, -1, modules),
		_paired_dormered_long_roof_recipe(&"roof.long.blue.dormer.pair.right",
			ROOF_BLUE, ROOF_WINDOW_03, 1, modules),
		_paired_dormered_long_roof_recipe(&"roof.long.orange.dormer.pair.left",
			ROOF_ORANGE, ROOF_WINDOW_04, -1, modules),
		_paired_dormered_long_roof_recipe(&"roof.long.orange.dormer.pair.right",
			ROOF_ORANGE, ROOF_WINDOW_04, 1, modules),
		_tower_roof_recipe(&"roof.tower.blue", COMPACT_ROOF_SLATE_03, modules),
		_tower_roof_recipe(&"roof.tower.orange", COMPACT_ROOF_06, modules),
		_terminal_tight_gable_recipe(&"roof.tower.party.blue",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"z", &"blue",
			modules, -1, 0, false),
		_terminal_tight_gable_recipe(&"roof.tower.party.orange",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"z", &"orange",
			modules, -1, 0, false),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.tower.blue",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"z",
			&"blue", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.tower.orange",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"z",
			&"orange", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.slim.blue",
			Vector3i(-1, 0, -2), Vector3i(2, 1, 4), &"z",
			&"blue", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.slim.orange",
			Vector3i(-1, 0, -2), Vector3i(2, 1, 4), &"z",
			&"orange", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.row.blue",
			Vector3i(-2, 0, -1), Vector3i(4, 1, 2), &"x",
			&"blue", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.row.orange",
			Vector3i(-2, 0, -1), Vector3i(4, 1, 2), &"x",
			&"orange", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.building.blue",
			Vector3i(-2, 0, -2), Vector3i(4, 1, 4), &"z",
			&"blue", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.building.orange",
			Vector3i(-2, 0, -2), Vector3i(4, 1, 4), &"z",
			&"orange", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.long.blue",
			Vector3i(-2, 0, -3), Vector3i(4, 1, 6), &"z",
			&"blue", modules),
		_terminal_tight_gable_recipe(&"roof.terminal.tight.long.orange",
			Vector3i(-2, 0, -3), Vector3i(4, 1, 6), &"z",
			&"orange", modules),
		_dormered_tower_roof_recipe(&"roof.tower.blue.dormer.left",
			COMPACT_ROOF_SLATE_03, ROOF_WINDOW_02, -1, modules),
		_dormered_tower_roof_recipe(&"roof.tower.blue.dormer.right",
			COMPACT_ROOF_SLATE_03, ROOF_WINDOW_02, 1, modules),
		_dormered_tower_roof_recipe(&"roof.tower.orange.dormer.left",
			COMPACT_ROOF_06, ROOF_WINDOW_04, -1, modules),
		_dormered_tower_roof_recipe(&"roof.tower.orange.dormer.right",
			COMPACT_ROOF_06, ROOF_WINDOW_04, 1, modules),
		_chimney_tower_roof_recipe(&"roof.tower.chimney.blue",
			COMPACT_ROOF_SLATE_03, modules),
		_chimney_tower_roof_recipe(&"roof.tower.chimney.orange",
			COMPACT_ROOF_06, modules),
		_short_tower_roof_recipe(&"roof.tower.short.blue", COMPACT_ROOF_SLATE_03,
			modules),
		_short_tower_roof_recipe(&"roof.tower.short.orange", COMPACT_ROOF_06,
			modules),
		_flat_roof_recipe(&"roof.flat.tower", Vector3i(-1, 0, -1),
			Vector3i(2, 1, 2), &"compact_tower", modules),
		_flat_roof_recipe(&"roof.flat.slim", Vector3i(-1, 0, -2),
			Vector3i(2, 1, 4), &"slim_building", modules),
		_flat_roof_recipe(&"roof.flat.square", Vector3i(-2, 0, -2),
			Vector3i(4, 1, 4), &"square_building", modules),
		_flat_roof_recipe(&"roof.flat.long", Vector3i(-2, 0, -3),
			Vector3i(4, 1, 6), &"long_building", modules),
		_flat_roof_garden_recipe(&"roof.flat.tower.garden",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"compact_tower",
			TERRACE_PLANT_LOW, modules),
		_flat_roof_garden_recipe(&"roof.flat.slim.garden",
			Vector3i(-1, 0, -2), Vector3i(2, 1, 4), &"slim_building",
			TERRACE_PLANT_MID, modules),
		_flat_roof_garden_recipe(&"roof.flat.square.garden",
			Vector3i(-2, 0, -2), Vector3i(4, 1, 4), &"square_building",
			TERRACE_PLANT_BROAD, modules),
		_flat_roof_garden_recipe(&"roof.flat.long.garden",
			Vector3i(-2, 0, -3), Vector3i(4, 1, 6), &"long_building",
			TERRACE_PLANT_TALL, modules),
		_flat_roof_garden_recipe(&"roof.flat.tower.garden.rich",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"compact_tower",
			TERRACE_PLANT_LOW, modules, true),
		_flat_roof_garden_recipe(&"roof.flat.slim.garden.rich",
			Vector3i(-1, 0, -2), Vector3i(2, 1, 4), &"slim_building",
			TERRACE_PLANT_MID, modules, true),
		_flat_roof_garden_recipe(&"roof.flat.square.garden.rich",
			Vector3i(-2, 0, -2), Vector3i(4, 1, 4), &"square_building",
			TERRACE_PLANT_BROAD, modules, true),
		_flat_roof_garden_recipe(&"roof.flat.long.garden.rich",
			Vector3i(-2, 0, -3), Vector3i(4, 1, 6), &"long_building",
			TERRACE_PLANT_TALL, modules, true),
		_flat_roof_micro_garden_recipe(&"roof.flat.tower.garden.micro",
			Vector3i(-1, 0, -1), Vector3i(2, 1, 2), &"compact_tower"),
		_flat_roof_micro_garden_recipe(&"roof.flat.slim.garden.micro",
			Vector3i(-1, 0, -2), Vector3i(2, 1, 4), &"slim_building"),
		_flat_roof_micro_garden_recipe(&"roof.flat.square.garden.micro",
			Vector3i(-2, 0, -2), Vector3i(4, 1, 4), &"square_building"),
		_flat_roof_micro_garden_recipe(&"roof.flat.long.garden.micro",
			Vector3i(-2, 0, -3), Vector3i(4, 1, 6), &"long_building"),
		_setback_cap_recipe(&"roof.setback.cap.1", 1, modules),
		_setback_cap_recipe(&"roof.setback.cap.2", 2, modules),
		_setback_cap_recipe(&"roof.setback.cap.4", 4, modules),
		_setback_cap_recipe(&"roof.setback.cap.6", 6, modules),
		_setback_garden_recipe(&"roof.setback.garden.2", 2, modules),
		_setback_garden_recipe(&"roof.setback.garden.4", 4, modules),
		_setback_garden_recipe(&"roof.setback.garden.6", 6, modules),
		_setback_lean_roof_recipe(&"roof.setback.lean.blue.2.negative", 2,
			-1, ROOF_BLUE),
		_setback_lean_roof_recipe(&"roof.setback.lean.blue.2.positive", 2,
			1, ROOF_BLUE),
		_setback_lean_roof_recipe(&"roof.setback.lean.orange.2.negative", 2,
			-1, ROOF_ORANGE),
		_setback_lean_roof_recipe(&"roof.setback.lean.orange.2.positive", 2,
			1, ROOF_ORANGE),
		_setback_lean_roof_recipe(&"roof.setback.lean.blue.4.negative", 4,
			-1, ROOF_BLUE),
		_setback_lean_roof_recipe(&"roof.setback.lean.blue.4.positive", 4,
			1, ROOF_BLUE),
		_setback_lean_roof_recipe(&"roof.setback.lean.orange.4.negative", 4,
			-1, ROOF_ORANGE),
		_setback_lean_roof_recipe(&"roof.setback.lean.orange.4.positive", 4,
			1, ROOF_ORANGE),
		_setback_lean_roof_recipe(&"roof.setback.lean.blue.6.negative", 6,
			-1, ROOF_BLUE),
		_setback_lean_roof_recipe(&"roof.setback.lean.blue.6.positive", 6,
			1, ROOF_BLUE),
		_setback_lean_roof_recipe(&"roof.setback.lean.orange.6.negative", 6,
			-1, ROOF_ORANGE),
		_setback_lean_roof_recipe(&"roof.setback.lean.orange.6.positive", 6,
			1, ROOF_ORANGE),
		_setback_shed_roof_recipe(&"roof.setback.shed.blue.2.negative", 2,
			-1, WINDOW_ROOF_BLUE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.blue.2.positive", 2,
			1, WINDOW_ROOF_BLUE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.orange.2.negative", 2,
			-1, WINDOW_ROOF_ORANGE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.orange.2.positive", 2,
			1, WINDOW_ROOF_ORANGE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.blue.4.negative", 4,
			-1, WINDOW_ROOF_BLUE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.blue.4.positive", 4,
			1, WINDOW_ROOF_BLUE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.orange.4.negative", 4,
			-1, WINDOW_ROOF_ORANGE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.orange.4.positive", 4,
			1, WINDOW_ROOF_ORANGE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.blue.6.negative", 6,
			-1, WINDOW_ROOF_BLUE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.blue.6.positive", 6,
			1, WINDOW_ROOF_BLUE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.orange.6.negative", 6,
			-1, WINDOW_ROOF_ORANGE, modules),
		_setback_shed_roof_recipe(&"roof.setback.shed.orange.6.positive", 6,
			1, WINDOW_ROOF_ORANGE, modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.blue.2.negative", 2,
			-1, &"blue", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.blue.2.positive", 2,
			1, &"blue", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.orange.2.negative", 2,
			-1, &"orange", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.orange.2.positive", 2,
			1, &"orange", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.blue.4.negative", 4,
			-1, &"blue", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.blue.4.positive", 4,
			1, &"blue", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.orange.4.negative", 4,
			-1, &"orange", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.orange.4.positive", 4,
			1, &"orange", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.blue.6.negative", 6,
			-1, &"blue", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.blue.6.positive", 6,
			1, &"blue", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.orange.6.negative", 6,
			-1, &"orange", modules),
		_partial_gable_roof_recipe(&"roof.partial.gable.orange.6.positive", 6,
			1, &"orange", modules),
		_interstitial_seal_recipe(&"interstitial.seal.1.capped", 1, true,
			modules),
		_interstitial_seal_recipe(&"interstitial.seal.1.buried", 1, false,
			modules),
		_interstitial_seal_recipe(&"interstitial.seal.2.capped", 2, true,
			modules),
		_interstitial_seal_recipe(&"interstitial.seal.2.buried", 2, false,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.1.left", 1, -1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.1.right", 1, 1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.2.left", 2, -1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.2.right", 2, 1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.4.left", 4, -1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.4.right", 4, 1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.6.left", 6, -1,
			modules),
		_setback_terrace_recipe(&"roof.setback.terrace.6.right", 6, 1,
			modules),
		_slim_roof_recipe(&"roof.slim.blue", ROOF_BLUE, modules),
		_slim_roof_recipe(&"roof.slim.orange", ROOF_ORANGE, modules),
		_dormered_slim_roof_recipe(&"roof.slim.blue.dormer.left",
			ROOF_BLUE, ROOF_WINDOW_02, -1, modules),
		_dormered_slim_roof_recipe(&"roof.slim.blue.dormer.right",
			ROOF_BLUE, ROOF_WINDOW_02, 1, modules),
		_dormered_slim_roof_recipe(&"roof.slim.orange.dormer.left",
			ROOF_ORANGE, ROOF_WINDOW_04, -1, modules),
		_dormered_slim_roof_recipe(&"roof.slim.orange.dormer.right",
			ROOF_ORANGE, ROOF_WINDOW_04, 1, modules),
		_chimney_slim_roof_recipe(&"roof.slim.chimney.blue", ROOF_BLUE,
			modules),
		_chimney_slim_roof_recipe(&"roof.slim.chimney.orange", ROOF_ORANGE,
			modules),
		_short_slim_roof_recipe(&"roof.slim.short.blue", ROOF_BLUE, modules),
		_short_slim_roof_recipe(&"roof.slim.short.orange", ROOF_ORANGE, modules),
		_outcrop_recipe(&"outcrop.blue", &"blue", modules),
		_outcrop_recipe(&"outcrop.orange", &"orange", modules),
		_outcrop_recipe(&"outcrop.amber", &"amber", modules),
		_outcrop_recipe(&"outcrop.corner.left.blue", &"blue", modules, 0, -2),
		_outcrop_recipe(&"outcrop.corner.left.orange", &"orange", modules, 0, -2),
		_outcrop_recipe(&"outcrop.corner.right.blue", &"blue", modules, 0, 1),
		_outcrop_recipe(&"outcrop.corner.right.orange", &"orange", modules, 0, 1),
		_outcrop_recipe(&"outcrop.half.blue", &"blue", modules, 1),
		_outcrop_recipe(&"outcrop.half.orange", &"orange", modules, 1),
		_embedded_oriel_recipe(&"outcrop.embedded.blue", &"blue", modules),
		_embedded_oriel_recipe(&"outcrop.embedded.orange", &"orange", modules),
		_embedded_oriel_recipe(&"outcrop.embedded.amber", &"amber", modules),
		_capped_outcrop_recipe(&"outcrop.capped.corner.left.blue", &"blue",
			modules, -1),
		_capped_outcrop_recipe(&"outcrop.capped.corner.left.orange", &"orange",
			modules, -1),
		_capped_outcrop_recipe(&"outcrop.capped.corner.right.blue", &"blue",
			modules, 0),
		_capped_outcrop_recipe(&"outcrop.capped.corner.right.orange", &"orange",
			modules, 0),
		_capped_outcrop_recipe(&"outcrop.flue.corner.left.blue", &"blue",
			modules, -1, ROOF_CHIMNEYS[1]),
		_capped_outcrop_recipe(&"outcrop.flue.corner.left.orange", &"orange",
			modules, -1, ROOF_CHIMNEYS[3]),
		_capped_outcrop_recipe(&"outcrop.flue.corner.right.blue", &"blue",
			modules, 0, ROOF_CHIMNEYS[3]),
		_capped_outcrop_recipe(&"outcrop.flue.corner.right.orange", &"orange",
			modules, 0, ROOF_CHIMNEYS[1]),
		_capped_outcrop_recipe(&"outcrop.capped.corner.left.amber", &"amber",
			modules, -1),
		_capped_outcrop_recipe(&"outcrop.capped.corner.right.amber", &"amber",
			modules, 0),
		_capped_outcrop_recipe(&"outcrop.flue.corner.left.amber", &"amber",
			modules, -1, ROOF_CHIMNEYS[2]),
		_capped_outcrop_recipe(&"outcrop.flue.corner.right.amber", &"amber",
			modules, 0, ROOF_CHIMNEYS[2]),
		_dormer_outcrop_recipe(&"outcrop.dormer.gable.teal.left",
			ROOF_WINDOW_02, false, modules, -1),
		_dormer_outcrop_recipe(&"outcrop.dormer.gable.teal.right",
			ROOF_WINDOW_02, false, modules, 0),
		_dormer_outcrop_recipe(&"outcrop.dormer.shed.teal.left",
			ROOF_WINDOW_03, false, modules, -1),
		_dormer_outcrop_recipe(&"outcrop.dormer.shed.teal.right",
			ROOF_WINDOW_03, false, modules, 0),
		_dormer_outcrop_recipe(&"outcrop.dormer.gable.orange.left",
			ROOF_WINDOW_01, true, modules, -1),
		_dormer_outcrop_recipe(&"outcrop.dormer.gable.orange.right",
			ROOF_WINDOW_01, true, modules, 0),
		_dormer_outcrop_recipe(&"outcrop.dormer.shed.orange.left",
			ROOF_WINDOW_04, true, modules, -1),
		_dormer_outcrop_recipe(&"outcrop.dormer.shed.orange.right",
			ROOF_WINDOW_04, true, modules, 0),
		_corner_wrap_outcrop_recipe(&"outcrop.corner.wrap.left.blue", &"blue",
			modules, -1),
		_corner_wrap_outcrop_recipe(&"outcrop.corner.wrap.left.orange",
			&"orange", modules, -1),
		_corner_wrap_outcrop_recipe(&"outcrop.corner.wrap.right.blue", &"blue",
			modules, 1),
		_corner_wrap_outcrop_recipe(&"outcrop.corner.wrap.right.orange",
			&"orange", modules, 1),
		_corner_wrap_outcrop_recipe(&"outcrop.corner.wrap.left.amber", &"amber",
			modules, -1),
		_corner_wrap_outcrop_recipe(&"outcrop.corner.wrap.right.amber", &"amber",
			modules, 1),
		_micro_room_recipe(&"room.micro.terrain.blue", &"blue", modules),
		_micro_room_recipe(&"room.micro.terrain.orange", &"orange", modules),
		_skywalk_recipe(&"skywalk.3.blue", 1, &"blue", modules, 2),
		_skywalk_recipe(&"skywalk.6.orange", 2, &"orange", modules, 2),
		_skywalk_recipe(&"skywalk.9.blue", 3, &"blue", modules, 2),
		_skywalk_recipe(&"skywalk.cantilever.3.blue", 1, &"blue", modules, 1),
		_skywalk_recipe(&"skywalk.cantilever.6.orange", 2, &"orange", modules, 1),
		_skywalk_recipe(&"skywalk.cantilever.9.blue", 3, &"blue", modules, 1),
		_skywalk_corner_recipe(&"skywalk.corner.blue", &"blue", modules),
		_skywalk_corner_recipe(&"skywalk.corner.orange", &"orange", modules),
		_balcony_recipe(&"balcony.bracketed.left.blue", &"blue", -1,
			modules),
		_balcony_recipe(&"balcony.bracketed.right.orange", &"orange", 0,
			modules),
		_balcony_recipe(&"balcony.bracketed.left.amber", &"amber", -1,
			modules),
		_balcony_recipe(&"balcony.bracketed.right.blue", &"blue", 0,
			modules),
		_balcony_recipe(&"balcony.bracketed.left.blue.planted", &"blue", -1,
			modules, true),
		_balcony_recipe(&"balcony.bracketed.right.orange.planted", &"orange", 0,
			modules, true),
		_balcony_recipe(&"balcony.bracketed.left.amber.planted", &"amber", -1,
			modules, true),
		_balcony_recipe(&"balcony.bracketed.right.blue.planted", &"blue", 0,
			modules, true),
		_balcony_recipe(&"balcony.walkout.deep.left.blue.planted", &"blue", -1,
			modules, true, 2, true),
		_balcony_recipe(&"balcony.walkout.deep.right.orange.planted", &"orange", 0,
			modules, true, 2, true),
		_balcony_recipe(&"balcony.walkout.deep.left.amber.planted", &"amber", -1,
			modules, true, 2, true),
		_balcony_recipe(&"balcony.walkout.deep.right.blue.planted", &"blue", 0,
			modules, true, 2, true),
		_wrap_balcony_recipe(&"balcony.wrap.left.blue.planted", &"blue", -1,
			modules),
		_wrap_balcony_recipe(&"balcony.wrap.right.orange.planted", &"orange", 1,
			modules),
		_wrap_balcony_recipe(&"balcony.wrap.left.amber.planted", &"amber", -1,
			modules),
		_wrap_balcony_recipe(&"balcony.wrap.right.blue.planted", &"blue", 1,
			modules),
		_integrated_cantilever_support_recipe(modules),
		_integrated_cantilever_diagonal_support_recipe(modules),
		_integrated_cantilever_terminal_support_recipe(modules),
		_integrated_cantilever_terminal_diagonal_support_recipe(modules),
	]
	for portal_mask in range(1, FEATURE_PORTAL_MASK_ALL + 1):
		candidates.append(_arcade_overhang_foundation_recipe(portal_mask,
			modules))
	_append_segment_building_variants(candidates, modules)
	_append_row_vocabulary(candidates, modules)
	for flat_spec: Dictionary in [
		{"kind": "tower", "minimum": Vector3i(-1, 0, -1),
			"size": Vector3i(2, 1, 2), "family": &"compact_tower"},
		{"kind": "slim", "minimum": Vector3i(-1, 0, -2),
			"size": Vector3i(2, 1, 4), "family": &"slim_building"},
		{"kind": "row", "minimum": Vector3i(-2, 0, -1),
			"size": Vector3i(4, 1, 2), "family": &"row_building"},
		{"kind": "square", "minimum": Vector3i(-2, 0, -2),
			"size": Vector3i(4, 1, 4), "family": &"square_building"},
		{"kind": "long", "minimum": Vector3i(-2, 0, -3),
			"size": Vector3i(4, 1, 6), "family": &"long_building"},
	]:
		for micro_index in 4:
			var micro_offset := [
				Vector2(-0.65, -0.65), Vector2(0.65, -0.65),
				Vector2(0.65, 0.65), Vector2(-0.65, 0.65),
			][micro_index] as Vector2
			candidates.append(_flat_roof_micro_garden_recipe(StringName(
				"roof.flat.%s.garden.micro.%d" % [flat_spec.kind,
					micro_index]), flat_spec.minimum as Vector3i,
				flat_spec.size as Vector3i, StringName(flat_spec.family),
				micro_offset))
		for side: StringName in [&"north", &"east", &"south", &"west"]:
			candidates.append(_flat_roof_terrace_recipe(StringName(
				"roof.flat.%s.terrace.%s.lived" % [flat_spec.kind, side]),
				flat_spec.minimum as Vector3i, flat_spec.size as Vector3i,
				StringName(flat_spec.family), side, modules, true))
			candidates.append(_flat_roof_terrace_recipe(StringName(
				"roof.flat.%s.terrace.%s" % [flat_spec.kind, side]),
				flat_spec.minimum as Vector3i, flat_spec.size as Vector3i,
				StringName(flat_spec.family), side, modules))
	_append_address_door_phase_vocabulary(candidates)
	_append_feature_portal_vocabulary(candidates, modules)
	_append_terminal_step_gable_vocabulary(candidates, modules)
	_append_roof_seam_vocabulary(candidates, modules)
	_append_bisected_valley_vocabulary(candidates, modules)
	for index in MARKET_STALLS.size():
		var market_descriptor := catalog.descriptor(MARKET_STALLS[index])
		# Route-first's narrow two-stall alley admits only the seven complete
		# `stocked_market` prefabs whose measured envelopes were reviewed for that
		# grammar. The broader themed stalls remain available to other systems;
		# adding them here crowds the bounded beam and can erase every valid alley.
		if market_descriptor == null \
				or not market_descriptor.tags.has(&"stocked_market"):
			push_error("Market vocabulary asset is not a reviewed stocked prefab: %s" %
				MARKET_STALLS[index])
			return null
		candidates.append(_market_recipe(StringName("market.stall.%02d" % index),
			MARKET_STALLS[index]))
		candidates.append(_covered_market_recipe(
			StringName("market.covered.%02d" % index),
			COVERED_MARKET_CANOPIES[index % COVERED_MARKET_CANOPIES.size()],
			COVERED_MARKET_TABLE))
		candidates.append(_covered_market_recipe(
			StringName("market.covered.%02d.garden" % index),
			COVERED_MARKET_CANOPIES[index % COVERED_MARKET_CANOPIES.size()],
			COVERED_MARKET_TABLE, true))
	for index in PREFAB_ANCHORS.size():
		candidates.append(_prefab_recipe(StringName("anchor.prefab.%02d" % index),
			PREFAB_ANCHORS[index], catalog, modules))
	for candidate: FabricRecipe in candidates:
		var compiled := candidate != null \
			and modules.apply_visual_envelope(candidate)
		if compiled:
			compiled = _preserve_lpfv_prefab_clearance(candidate, modules)
		if not compiled or not candidate.seal(catalog) \
				or not program._add_recipe(candidate):
			push_error("Could not compile settlement fabric recipe %s: %s" % [
				"<null>" if candidate == null else candidate.recipe_id,
				"null recipe" if candidate == null else candidate.last_rejection])
			return null
	var unique_assets: Dictionary = {}
	for recipe_value: FabricRecipe in program._recipes.values():
		for asset_id: StringName in recipe_value.asset_ids():
			unique_assets[asset_id] = true
	# EVERY ASSET AN ADAPTER PLACES, declared here because no `FabricRecipe`
	# mentions it and nothing else would. `VillageUrbanFabricPlan._validate_
	# compiled_fabric` refuses a production plan carrying an entry whose asset
	# this program never declared -- and it did, at task H2b, which is how the
	# omission surfaced -- and the streamer prepares its render cache from the
	# same list, so an undeclared adapter asset is a BLANK TOWN in the real
	# game and not only a failed assert.
	#
	# * RAILING_MEDIUM -- public-realm guard coalescing over the sealed surface
	#   plan needs the authored 3 m repeat.
	# * TERRAIN_GREEN_CAP, NATURAL_ROCK_FACE, GREEN_RIM_EDGE -- the three
	#   terrain modules `SettlementFabricAssembler` clads a hillside bank, a
	#   bench top and a bench rim with.
	#
	# Each is CHECKED against the catalog rather than trusted, so a renamed or
	# unbaked module fails at program compile with a name instead of at the
	# first render with a blank town. FIX 1, MINOR 8 gives RAILING_MEDIUM the
	# same check the two skin modules got: it was declared bare, and a guard
	# rail that vanished from the bake would have been the same silent failure.
	# * TASK I2 adds two more families to the same list. The one-cell facade
	#   modules are placed by the skin and by nothing else -- the room recipes
	#   use the 3 m pools -- so without this line a clad mass face is a hole in
	#   the streamed town. The garden props are the dressing that turns a bench
	#   top from a lime plate into a yard.
	# * TASK I3 adds the LIFE the same way, and for exactly the same failure
	#   mode. The skywalk deck, its two rails and its bearer are all modules the
	#   room recipes already name, so they would survive this list by accident --
	#   the corner post the bump-outs fill their body with and the three plaza
	#   centre features would not, and a village green whose well never streamed
	#   is the blank-town failure this list exists to stop.
	var adapter_assets: Array[StringName] = [
		RAILING_MEDIUM,
		SettlementFabricAssembler.TERRAIN_GREEN_CAP,
		SettlementFabricAssembler.NATURAL_ROCK_FACE,
		SettlementFabricAssembler.GREEN_RIM_EDGE,
		SettlementFabricAssembler.GREEN_RIM_OUTER_CORNER,
		SettlementFabricAssembler.SKYWALK_DECK,
		SettlementFabricAssembler.SKYWALK_DECK_SHORT,
		SettlementFabricAssembler.SKYWALK_RAIL,
		SettlementFabricAssembler.SKYWALK_BEARER,
		SettlementFabricAssembler.FACADE_OUTCROP_POST,
		SettlementFabricAssembler.FACADE_OUTCROP_CAP,
	]
	for pool: Array[StringName] in [WOOD_CELL_FACADE_BLUE,
			WOOD_CELL_FACADE_ORANGE, WOOD_CELL_FACADE_AMBER,
			SettlementFabricAssembler.GARDEN_PLANTING,
			SettlementFabricAssembler.PLAZA_WIDE_FEATURES,
			[SettlementFabricAssembler.GARDEN_PLANTER] as Array[StringName]]:
		for asset_id: StringName in pool:
			if not adapter_assets.has(asset_id):
				adapter_assets.append(asset_id)
	for adapter_asset: StringName in adapter_assets:
		if catalog.descriptor(adapter_asset) == null:
			push_error("Fabric adapter asset is not in the catalog: %s" \
				% adapter_asset)
			return null
		unique_assets[adapter_asset] = true
	program.referenced_asset_ids.assign(unique_assets.keys())
	program.referenced_asset_ids.sort_custom(func(a: StringName,
			b: StringName) -> bool: return String(a) < String(b))
	for asset_id: StringName in program.referenced_asset_ids:
		var descriptor := catalog.descriptor(asset_id)
		if descriptor == null or not descriptor.measured_aabb.has_volume():
			push_error("Fabric asset has no measured visual contract: %s" \
				% asset_id)
			return null
		program.asset_visual_bounds[asset_id] = descriptor.measured_aabb
	return program


static func _preserve_lpfv_prefab_clearance(recipe_value: FabricRecipe,
		modules: FabricModuleProgram) -> bool:
	## Moving the leaf from the old logical-AABB guess into the actual authored
	## jamb must not shrink a prefab recipe's already-reviewed construction
	## clearance and thereby reshuffle bounded town search. Retain that former
	## conservative envelope as an explicit clearance-only margin; no visual or
	## collision is emitted at the obsolete location.
	if recipe_value == null or not recipe_value.has_tag(&"prefab_anchor"):
		return recipe_value != null
	var leaf: Dictionary = {}
	for placement: Dictionary in recipe_value.placements:
		if StringName(placement.id) == &"front.closed_door":
			leaf = placement
			break
	if leaf.is_empty() or recipe_value.entrances.size() != 1:
		return true
	var asset_id := StringName(leaf.asset_id)
	var contract_value := modules.contract(asset_id)
	if contract_value == null:
		return false
	var entrance_cell := recipe_value.entrances[0].cell as Vector3i
	var boundary := (float(entrance_cell.z) + 0.5) * CELL
	var old_pose := modules.facade_aligned_transform(asset_id,
		_pose(Vector3(float(entrance_cell.x) * CELL, 0.0, boundary), 0.0),
		Vector3i.BACK, boundary)
	var old_bounds := old_pose * contract_value.clearance_bounds()
	return recipe_value.grow_local_clearance_bounds(old_bounds)


static func _compile_module_program(catalog: EnvironmentCatalog) \
		-> FabricModuleProgram:
	var modules := FabricModuleProgram.new(catalog)
	var facade_assets: Array[StringName] = [
		ROCK_PLAIN, ROCK_DOOR, ROCK_WINDOW,
		WOOD_PLAIN, WOOD_DOOR,
		WOOD_DOOR_OPEN,
		PORTAL_JAMB,
		STAIR_HALF,
		WALL_WOOD_S_A, WALL_WOOD_S_B, WALL_WOOD_CORNER_S,
		WALL_WOOD_WINDOW_S_BLUE, WALL_WOOD_WINDOW_S_ORANGE,
		WALL_WOOD_WINDOW_S_AMBER,
		COMPACT_CHIMNEY, ROOM_ROOF_01, ROOM_ROOF_02, ROOM_ROOF_04,
		ROOM_ROOF_05, COMPACT_ROOF_03, COMPACT_ROOF_06,
		COMPACT_ROOF_SLATE_03, COMPACT_ROOF_SLATE_06,
		COMPACT_ROOF_ORANGE_REAR, COMPACT_ROOF_ORANGE_FRONT,
		COMPACT_ROOF_SLATE_REAR, COMPACT_ROOF_SLATE_FRONT,
		COMPACT_ROOF_ORANGE_REAR_END, COMPACT_ROOF_ORANGE_FRONT_END,
		COMPACT_ROOF_SLATE_REAR_END, COMPACT_ROOF_SLATE_FRONT_END,
		COMPACT_ROOF_ORANGE_MIDDLE, COMPACT_ROOF_SLATE_MIDDLE,
		COMPACT_ROOF_ORANGE_REAR_END_TIGHT,
		COMPACT_ROOF_ORANGE_FRONT_END_TIGHT,
		COMPACT_ROOF_ORANGE_REAR_TIGHT,
		COMPACT_ROOF_ORANGE_MIDDLE_TIGHT, COMPACT_ROOF_ORANGE_FRONT_TIGHT,
		COMPACT_ROOF_SLATE_REAR_END_TIGHT,
		COMPACT_ROOF_SLATE_FRONT_END_TIGHT,
		COMPACT_ROOF_SLATE_REAR_TIGHT,
		COMPACT_ROOF_SLATE_MIDDLE_TIGHT, COMPACT_ROOF_SLATE_FRONT_TIGHT,
		COMPACT_ROOF_ORANGE_RUN_START, COMPACT_ROOF_ORANGE_RUN_MIDDLE,
		COMPACT_ROOF_ORANGE_RUN_END, COMPACT_ROOF_ORANGE_RUN_START_TIGHT,
		COMPACT_ROOF_ORANGE_RUN_MIDDLE_TIGHT,
		COMPACT_ROOF_ORANGE_RUN_MIDDLE_MIRROR,
		COMPACT_ROOF_ORANGE_RUN_MIDDLE_TIGHT_MIRROR,
		COMPACT_ROOF_ORANGE_RUN_END_TIGHT,
		COMPACT_ROOF_ORANGE_RUN_START_FLUSH,
		COMPACT_ROOF_ORANGE_RUN_START_TIGHT_FLUSH,
		COMPACT_ROOF_ORANGE_RUN_END_FLUSH,
		COMPACT_ROOF_ORANGE_RUN_END_TIGHT_FLUSH,
		COMPACT_ROOF_SLATE_RUN_START, COMPACT_ROOF_SLATE_RUN_MIDDLE,
		COMPACT_ROOF_SLATE_RUN_END, COMPACT_ROOF_SLATE_RUN_START_TIGHT,
		COMPACT_ROOF_SLATE_RUN_MIDDLE_TIGHT,
		COMPACT_ROOF_SLATE_RUN_MIDDLE_MIRROR,
		COMPACT_ROOF_SLATE_RUN_MIDDLE_TIGHT_MIRROR,
		COMPACT_ROOF_SLATE_RUN_END_TIGHT,
		COMPACT_ROOF_SLATE_RUN_START_FLUSH,
		COMPACT_ROOF_SLATE_RUN_START_TIGHT_FLUSH,
		COMPACT_ROOF_SLATE_RUN_END_FLUSH,
		COMPACT_ROOF_SLATE_RUN_END_TIGHT_FLUSH,
		ROOF_WINDOW_01, ROOF_WINDOW_02, ROOF_WINDOW_03, ROOF_WINDOW_04,
		ROOF_SEAM,
		ROOF_BISECT_LEFT_BLUE, ROOF_BISECT_RIGHT_BLUE,
		ROOF_BISECT_LEFT_ORANGE, ROOF_BISECT_RIGHT_ORANGE,
		ROOF_TERRACE_AWNING, ATTACHMENT_BRACKET_M, BRACE, DIAGONAL_BRACE,
		WINDOW_ROOF_ORANGE_TRIMMED, WINDOW_ROOF_BLUE_TRIMMED,
		WINDOW_ROOF_ORANGE_PARTY_LEFT, WINDOW_ROOF_ORANGE_PARTY_RIGHT,
		WINDOW_ROOF_BLUE_PARTY_LEFT, WINDOW_ROOF_BLUE_PARTY_RIGHT,
	]
	for pool: Array[StringName] in [WOOD_FACADE_BLUE, WOOD_FACADE_ORANGE,
			WOOD_FACADE_AMBER, ROCK_FACADE, WOOD_DOORS, ROCK_DOORS,
			ROOF_CHIMNEYS, LPFV_PREFAB_DOORS]:
		for asset_id: StringName in pool:
			if not facade_assets.has(asset_id):
				facade_assets.append(asset_id)
	for wall_asset: StringName in facade_assets:
		if not modules.add_generic(wall_asset):
			push_error("Could not compile facade contract %s: %s" % [
				wall_asset, modules.last_rejection])
			return null
		var mirrored_asset := _mirrored_facade_asset(wall_asset)
		if mirrored_asset != wall_asset and catalog.has(mirrored_asset) \
				and not modules.add_generic(mirrored_asset):
			push_error("Could not compile mirrored facade contract %s: %s" % [
				mirrored_asset, modules.last_rejection])
			return null
	# Preset 003 shares preset 004's stair/landing datum; its complete handrails
	# extend above the walking plane. Keep the real upper tread in the contract so
	# every use meets its destination platform instead of aligning by the post top.
	# Both reviewed window-roof colours share the same source geometry: local
	# -Z is the measured high edge.  Treat them as typed shed roofs even when a
	# facade recipe also uses them as a canopy; no caller may guess their pitch.
	if not modules.add_shed_roof(WINDOW_ROOF_ORANGE, Vector3i.FORWARD) \
			or not modules.add_shed_roof(WINDOW_ROOF_BLUE, Vector3i.FORWARD) \
			or not modules.add_switchback_stair(STAIR_FULL, 0.0, 2.9479) \
			or not modules.add_walk_surface(FLOOR) \
			or not modules.add_walk_surface(GALLERY_FLOOR) \
			or not modules.add_walk_surface(SETBACK_CAP) \
			or not modules.add_roof_repeat(ROOF_BLUE, Vector3i.BACK, 3.0,
				Vector3i.RIGHT, 1.6217227, &"gable.wood.m", &"roof.blue", 0.12) \
			or not modules.add_roof_repeat(ROOF_ORANGE, Vector3i.BACK, 3.0,
				Vector3i.RIGHT, 1.6217227, &"gable.wood.m", &"roof.orange", 0.12) \
			or not modules.add_roof_end(GABLE, &"gable.wood.m"):
		push_error("Could not compile fabric module contracts: %s" %
			modules.last_rejection)
		return null
	for asset_id: StringName in PREFAB_ANCHORS:
		if not modules.add_prefab(asset_id, 0.15):
			push_error("Could not compile prefab contract %s: %s" % [
				asset_id, modules.last_rejection])
			return null
	if not modules.seal():
		push_error("Could not seal fabric module contracts: %s" %
			modules.last_rejection)
		return null
	return modules


func recipe(recipe_id: StringName) -> FabricRecipe:
	return _recipes.get(recipe_id) as FabricRecipe


func recipes() -> Array[FabricRecipe]:
	var ids: Array[StringName] = []
	ids.assign(_recipes.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var out: Array[FabricRecipe] = []
	for recipe_id: StringName in ids:
		out.append(_recipes[recipe_id] as FabricRecipe)
	return out


func _add_recipe(recipe_value: FabricRecipe) -> bool:
	if recipe_value == null or _recipes.has(recipe_value.recipe_id):
		return false
	_recipes[recipe_value.recipe_id] = recipe_value
	return true


static func _route_recipe(recipe_id: StringName, landing: bool,
		corner: bool, structural: bool) -> FabricRecipe:
	var tags: Array[StringName] = [
		&"route", &"public_walk", &"surface_claim", &"topology_only",
	]
	if landing:
		tags.append(&"route_landing")
	if corner:
		tags.append(&"route_corner")
	if structural:
		# Elevated exterior circulation is a thin timber public surface. It is
		# intentionally not tagged as a standalone platform: support is derived
		# from the continuous surface union, and the episode cannot exist apart
		# from its connected public-realm graph.
		tags.append(&"structural_court")
		tags.append(&"elevated_deck_route")
	var recipe_value := FabricRecipe.new(recipe_id, tags, 0)
	# Every route episode is a true two-lane 3 m square. The former straight
	# recipe was only one lattice cell wide and depended on the realm builder to
	# invent a second forecourt cell at each seam; adjacent buildings could then
	# block that invisible repair. Repetition supplies length, while width and
	# junction continuity now exist in the recipe itself.
	var minimum := Vector3i(-1, 0, -1)
	var size := Vector3i(2, 1, 2)
	recipe_value.walk_cells = FabricRecipe.box_cells(minimum, size)
	recipe_value.headroom_cells = FabricRecipe.box_cells(minimum,
		Vector3i(size.x, 2, size.z))
	recipe_value.public_air_cells.assign(recipe_value.headroom_cells)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.WALK, &"walk", 0,
		minimum, size.x, size.z)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing", 0, minimum, size.x, size.z)
	return recipe_value


static func _stair_recipe(recipe_id: StringName, asset_id: StringName,
		rise_cells: int, run_cells: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"route", &"public_walk", &"stair"], 1)
	var stair_transforms := modules.stair_lane_transforms(asset_id)
	for lane in stair_transforms.size():
		var stair_transform := stair_transforms[lane]
		if asset_id == STAIR_FULL:
			stair_transform = modules.stair_high_aligned_transform(asset_id,
				stair_transform, float(rise_cells) * CELL)
		recipe_value.add_placement(StringName("stair.%02d" % lane), asset_id,
			stair_transform)
	for x in [-1, 0]:
		for step in rise_cells + 1:
			var z := -mini(step, run_cells)
			recipe_value.walk_cells.append(Vector3i(x, step, z))
			recipe_value.headroom_cells.append(Vector3i(x, step, z))
			recipe_value.headroom_cells.append(Vector3i(x, step + 1, z))
	recipe_value.public_air_cells.assign(recipe_value.headroom_cells)
	recipe_value.add_socket(&"walk.low", FabricRecipe.SocketKind.WALK,
		Vector3i(-1, 0, 0), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"walk.high", FabricRecipe.SocketKind.WALK,
		Vector3i(-1, rise_cells, -run_cells), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"bearing.low", FabricRecipe.SocketKind.BEARING,
		Vector3i(-1, 0, 0), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"bearing.high", FabricRecipe.SocketKind.BEARING,
		Vector3i(-1, rise_cells, -run_cells), Vector3i(0, 0, -1))
	return recipe_value


static func _gallery_recipe() -> FabricRecipe:
	var recipe_value := FabricRecipe.new(&"gallery.landing",
		[&"gallery", &"public_walk", &"platform", &"surface_claim",
			&"topology_only"], 1)
	recipe_value.walk_cells = FabricRecipe.box_cells(Vector3i(-1, 0, 0),
		Vector3i(2, 1, 1))
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-1, 0, 0),
		Vector3i(2, 2, 1))
	recipe_value.public_air_cells.assign(recipe_value.headroom_cells)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.WALK, &"walk", 0,
		Vector3i(0, 0, 0))
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i(-1, 0, 0), Vector3i(0, 0, -1))
	return recipe_value


static func _room_recipe(recipe_id: StringName, terrain_bearing: bool,
		theme: StringName, has_exterior_door: bool,
		modules: FabricModuleProgram, facade_phase: int = 0) -> FabricRecipe:
	assert(facade_phase >= 0 and facade_phase < FACADE_PHASE_COUNT)
	var tags: Array[StringName] = [&"room", &"generated_building"]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var facade_family := &"stone" if theme == &"rock" else theme
	## Four faces, four authored modules. Before this the whole shell repeated a
	## single window, which is what made a square room read as one stamped box
	## from every angle; the offsets live in FACE_PHASE_OFFSETS so the frozen
	## phases 0-2 keep their pre-wave meaning.
	var face_assets: Array[StringName] = []
	for face_index in 4:
		face_assets.append(_facade_asset(facade_family,
			_face_phase(facade_phase, face_index)))
	_add_room_shell(recipe_value,
		_facade_door(facade_family, facade_phase) if has_exterior_door \
			else face_assets[0],
		face_assets, 6.0, modules, &"front" if has_exterior_door else &"")
	if not terrain_bearing and not has_exterior_door \
			and facade_phase % 2 == 1:
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"square", facade_phase),
			FabricModuleProgram.footprint_centre(Vector3i(-2, 0, -2),
				Vector3i(4, 1, 4)), 3.0)
	_add_room_occupancy(recipe_value, &"front" if has_exterior_door else &"")
	_add_room_sockets(recipe_value)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -2),
			Vector3i(4, 1, 4))
	return recipe_value


static func _long_room_recipe(recipe_id: StringName, terrain_bearing: bool,
		theme: StringName, has_exterior_door: bool, facade_phase: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A true 6 x 9 m longhouse. Its local Z axis is both the parcel depth and the
	## terminal roof ridge, so orientation cannot drift between the logical plot,
	## walls, doors, and roof recipe. Side facades use reviewed complete modules
	## in two alternating phases; a tall stack therefore articulates each storey
	## without tinting, stretching, or inventing a decorative overlay.
	assert(facade_phase >= 0 and facade_phase < FACADE_PHASE_COUNT)
	var tags: Array[StringName] = [
		&"room", &"generated_building", &"long_building",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var facade_family := &"stone" if theme == &"rock" else theme
	var primary_window := _facade_window(facade_family)
	var plain_asset := _facade_plain(facade_family)
	var facade_variants: Array[StringName] = []
	for phase in 5:
		facade_variants.append(_facade_asset(facade_family, phase))
	var door_asset := _facade_door(facade_family) if has_exterior_door \
		else primary_window
	var minimum := Vector3i(-2, 0, -3)
	var size := Vector3i(4, 1, 6)
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	for z_index in 3:
		for x_index in 2:
			var floor_offset := Vector3(-1.5 + float(x_index) * 3.0, 0.0,
				-3.0 + float(z_index) * 3.0)
			recipe_value.add_placement(StringName("floor.%d.%d" % [
				z_index, x_index]), FLOOR, modules.walk_aligned_transform(FLOOR,
					_pose(centre + floor_offset, 0.0), 0.0))
	for index in 2:
		var x_offset := -1.5 + float(index) * 3.0
		var front_asset := door_asset if has_exterior_door and index == 0 \
			else facade_variants[(index + facade_phase) % facade_variants.size()]
		var back_asset := facade_variants[(index + facade_phase + 2) \
			% facade_variants.size()]
		recipe_value.add_placement(StringName("front.%d" % index), front_asset,
			modules.facade_aligned_transform(front_asset,
				_pose(centre + Vector3(x_offset, 0.0, 4.5), 0.0),
				Vector3i.BACK, centre.z + 4.5))
		recipe_value.add_placement(StringName("back.%d" % index), back_asset,
			modules.facade_aligned_transform(back_asset,
				_pose(centre + Vector3(x_offset, 0.0, -4.5), PI),
				Vector3i.FORWARD, centre.z - 4.5))
	for index in 3:
		var z_offset := -3.0 + float(index) * 3.0
		var west_asset := facade_variants[(index + facade_phase + 1) \
			% facade_variants.size()]
		var east_asset := facade_variants[(index + facade_phase + 3) \
			% facade_variants.size()]
		west_asset = _mirrored_facade_asset(west_asset)
		east_asset = _mirrored_facade_asset(east_asset)
		recipe_value.add_placement(StringName("west.%d" % index), west_asset,
			modules.facade_aligned_transform(west_asset,
				_pose(centre + Vector3(-3.0, 0.0, z_offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 3.0))
		recipe_value.add_placement(StringName("east.%d" % index), east_asset,
			modules.facade_aligned_transform(east_asset,
				_pose(centre + Vector3(3.0, 0.0, z_offset), -PI * 0.5),
				Vector3i.RIGHT, centre.x + 3.0))
	if not terrain_bearing and not has_exterior_door \
			and facade_phase % 2 == 1:
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"long", facade_phase), centre, 4.5)
	var door_cell := Vector3i(-1, 0, 2)
	for y in 2:
		for z in range(-3, 3):
			for x in range(-2, 2):
				var cell := Vector3i(x, y, z)
				var boundary := x == -2 or x == 1 or z == -3 or z == 2
				var doorway := has_exterior_door and x == door_cell.x \
					and z == door_cell.z
				if boundary and not doorway:
					recipe_value.solid_cells.append(cell)
					recipe_value.occluder_cells.append(cell)
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -2),
		Vector3i(2, 2, 4))
	if has_exterior_door:
		for y in 2:
			recipe_value.headroom_cells.append(Vector3i(door_cell.x, y,
				door_cell.z))
		recipe_value.add_entrance(&"front", door_cell, Vector3i.BACK)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	_add_room_sockets(recipe_value, 2, 3)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, minimum, size)
	return recipe_value


static func _passage_room_recipe(recipe_id: StringName,
		theme: StringName, terrain_bearing: bool,
		modules: FabricModuleProgram) -> FabricRecipe:
	var tags: Array[StringName] = [
		&"room", &"passage_room", &"generated_building", &"interior_walk",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id,
		tags, 0 if terrain_bearing else 1)
	_add_passage_shell(recipe_value, theme, modules)
	# Four corner piers conservatively represent the shell while the two-cell
	# openings in every facade remain usable by stairs, galleries, and tunnels.
	for y in 2:
		for x in [-2, 1]:
			for z in [-2, 1]:
				recipe_value.solid_cells.append(Vector3i(x, y, z))
	# The public floor reaches each two-cell facade opening. Keeping only the
	# central 3 m square made the socket graph claim a doorway while leaving a
	# physical moat between the route and the room. Corner piers remain solids;
	# every other footprint cell is one continuous interior/portal surface.
	for z in range(-2, 2):
		for x in range(-2, 2):
			if (x == -2 or x == 1) and (z == -2 or z == 1):
				continue
			recipe_value.walk_cells.append(Vector3i(x, 0, z))
			recipe_value.headroom_cells.append(Vector3i(x, 0, z))
			recipe_value.headroom_cells.append(Vector3i(x, 1, z))
	_add_passage_occluders(recipe_value)
	_add_room_sockets(recipe_value)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.WALK, &"walk", 0,
		Vector3i(-2, 0, -2), 4, 4)
	# A public portal is also a legitimate structural landing. These bearing
	# sockets deliberately share the exact lane cells used by the walk sockets;
	# the room's older cardinal bearings remain centred facade anchors for room
	# composition and cannot silently shift an attached stair sideways.
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing.portal", 0, Vector3i(-2, 0, -2), 4, 4)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -2),
			Vector3i(4, 1, 4))
	return recipe_value


static func _pier_room_recipe(recipe_id: StringName, terrain_bearing: bool,
		theme: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## A 3 m square support house used only beneath a structural court. The next
	## storey or the court itself is its ceiling, so it never receives the flat
	## floor-cap that made the retired micro fillers read as boxes in open space.
	var tags: Array[StringName] = [
		&"room", &"generated_building", &"support_house",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var wall := ROCK_WINDOW if terrain_bearing else _wood_window(theme)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	recipe_value.add_placement(&"floor", FLOOR,
		modules.walk_aligned_transform(FLOOR, _pose(centre, 0.0), 0.0))
	for side: Dictionary in [
		{"id": &"south", "offset": Vector3(0.0, 0.0, 1.5),
			"yaw": 0.0, "outward": Vector3i.BACK, "boundary": centre.z + 1.5},
		{"id": &"north", "offset": Vector3(0.0, 0.0, -1.5),
			"yaw": PI, "outward": Vector3i.FORWARD, "boundary": centre.z - 1.5},
		{"id": &"west", "offset": Vector3(-1.5, 0.0, 0.0),
			"yaw": PI * 0.5, "outward": Vector3i.LEFT, "boundary": centre.x - 1.5},
		{"id": &"east", "offset": Vector3(1.5, 0.0, 0.0),
			"yaw": -PI * 0.5, "outward": Vector3i.RIGHT, "boundary": centre.x + 1.5},
	]:
		var side_asset := _mirrored_facade_asset(wall) \
			if (side.outward as Vector3i).x != 0 else wall
		recipe_value.add_placement(StringName(side.id), side_asset,
			modules.facade_aligned_transform(side_asset,
				_pose(centre + side.offset as Vector3, float(side.yaw)),
				side.outward as Vector3i, float(side.boundary)))
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 2, 2))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.top", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 1, 0), Vector3i.UP)
	if not terrain_bearing:
		recipe_value.add_socket(&"bearing.bottom",
			FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.DOWN)
	else:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-1, 0, -1),
			Vector3i(2, 1, 2))
	return recipe_value


static func _bridge_room_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram, bearing_parent_count: int = 2) -> FabricRecipe:
	## An inhabited room spanning a carved street or residual gap, bearing on
	## the two flanking buildings it joins instead of on mass below. The shell
	## is the ordinary unaddressed upper tower storey; only the bearing
	## contract differs: two bearing parents, bound through per-cell span
	## sockets so any placement whose side cell exactly meets a flank's
	## centred cardinal bearing socket can bind — the same strict
	## `_sockets_meet` adjacency the skywalk endpoints use, never a loosened
	## overlap test. Placements that cannot meet both flanks are rejected at
	## candidate time, so this admits real street-bridging rooms only.
	var recipe_value := _tower_room_recipe(recipe_id, false, theme, false,
		modules) if not String(recipe_id).contains(".slim.") \
		else _slim_room_recipe(recipe_id, false, theme, false, modules)
	assert(bearing_parent_count in [1, 2])
	recipe_value.bearing_parent_count = bearing_parent_count
	recipe_value.role_tags.append(&"bridge_room" if bearing_parent_count == 2 \
		else &"bracketed_jetty_room")
	if bearing_parent_count == 2:
		# The occupied span is itself the skywalk.  Put that semantic fact on the
		# same recipe as its body, two-sided bearing contract, and roof so generic
		# fabric audits do not have to infer a bridge from room names or source
		# reservations after construction.
		recipe_value.role_tags.append(&"skywalk")
		recipe_value.role_tags.append(&"overhead_occupied")
	# A bridge room is a complete house envelope, not an ordinary room whose
	# crown may later be reinterpreted as a terrace or a plank cap.  Keeping its
	# pitched shell in this recipe makes the two flank bonds, occupied body and
	# weather closure one measured transaction.  In particular, a late roof-
	# neighborhood collision can no longer flatten the connector and recreate
	# the broad timber lid that the visual review rejected.
	recipe_value.role_tags.append(&"integrated_pitched_roof")
	recipe_value.role_tags.append(&"bridge_eave_roof")
	var roof_centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2) if String(recipe_id).contains(".slim.") \
		else Vector3i(-1, 0, -1),
		Vector3i(2, 1, 4) if String(recipe_id).contains(".slim.") \
		else Vector3i(2, 1, 2))
	if String(recipe_id).contains(".slim."):
		# The occupied link is exactly two 3 m construction bays long. Rear/front
		# sections terminate at the typed party planes while retaining their normal
		# 0.328 m eaves across the exposed side walls. The roof therefore meets both
		# endpoint buildings without looking narrower than the bridge-house below.
		var rear_asset := COMPACT_ROOF_SLATE_REAR if theme == &"blue" \
			else COMPACT_ROOF_ORANGE_REAR
		var front_asset := COMPACT_ROOF_SLATE_FRONT if theme == &"blue" \
			else COMPACT_ROOF_ORANGE_FRONT
		recipe_value.add_placement(&"roof.rear", rear_asset,
			modules.roof_bearing_aligned_transform(rear_asset,
				_pose(roof_centre + Vector3(0.0, 3.0, -1.5), 0.0), 3.0))
		recipe_value.add_placement(&"roof.front", front_asset,
			modules.roof_bearing_aligned_transform(front_asset,
				_pose(roof_centre + Vector3(0.0, 3.0, 1.5), 0.0), 3.0))
		_add_compact_roof_run_contract(recipe_value, &"compact", [
			roof_centre + Vector3(0.0, 3.0, -1.5),
			roof_centre + Vector3(0.0, 3.0, 1.5),
		], [[&"roof.rear"], [&"roof.front"]], &"z", theme, modules)
	else:
		# A one-bay bridge has exposed side eaves but two exact party seams where
		# it enters its endpoint houses. Two finite half-run assets preserve the
		# normal cross-ridge overhang while ending precisely at those seam planes;
		# a complete 4.16 m source roof would bury 0.58 m under each endpoint.
		var rear_end := COMPACT_ROOF_SLATE_REAR_END if theme == &"blue" \
			else COMPACT_ROOF_ORANGE_REAR_END
		var front_end := COMPACT_ROOF_SLATE_FRONT_END if theme == &"blue" \
			else COMPACT_ROOF_ORANGE_FRONT_END
		for roof_part: Dictionary in [
				{"id": &"roof.rear", "asset": rear_end},
				{"id": &"roof.front", "asset": front_end}]:
			var asset_id := StringName(roof_part.asset)
			recipe_value.add_placement(StringName(roof_part.id), asset_id,
				modules.roof_bearing_aligned_transform(asset_id,
					_pose(roof_centre + Vector3.UP * 3.0, 0.0), 3.0))
		_add_compact_roof_run_contract(recipe_value, &"compact", [
			roof_centre + Vector3.UP * 3.0,
		], [[&"roof.rear", &"roof.front"]], &"z", theme, modules, false)
	var minimum := Vector3i(-1, 0, -1)
	var size := Vector3i(2, 2, 2)
	if String(recipe_id).contains(".slim."):
		minimum = Vector3i(-1, 0, -2)
		size = Vector3i(2, 2, 4)
	# Span sockets exist on every boundary cell of both storey bands:
	# neighbouring lineages deliberately stagger half-storey phases (the
	# vertical_phase_conflict motif), so a bridge may meet one flank's centred
	# socket at its lower band and the opposite flank's at its upper band
	# while both bonds stay strict exact adjacencies.
	for side: Dictionary in [
		{"prefix": "east", "facing": Vector3i(1, 0, 0)},
		{"prefix": "west", "facing": Vector3i(-1, 0, 0)},
		{"prefix": "north", "facing": Vector3i(0, 0, -1)},
		{"prefix": "south", "facing": Vector3i(0, 0, 1)},
	]:
		var facing := side.facing as Vector3i
		var side_cells: Array[Vector3i] = []
		if facing.x != 0:
			var x := minimum.x if facing.x < 0 else minimum.x + size.x - 1
			for z in range(minimum.z, minimum.z + size.z):
				side_cells.append(Vector3i(x, 0, z))
		else:
			var z := minimum.z if facing.z < 0 else minimum.z + size.z - 1
			for x in range(minimum.x, minimum.x + size.x):
				side_cells.append(Vector3i(x, 0, z))
		for band in 2:
			for index in side_cells.size():
				recipe_value.add_socket(StringName("bearing.span.%s.%d.%d" % [
					String(side.prefix), band, index]),
					FabricRecipe.SocketKind.BEARING,
					side_cells[index] + Vector3i(0, band, 0), facing)
	return recipe_value


static func _open_bridge_gallery_recipe(recipe_id: StringName,
		theme: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## A bridge-house is still a complete occupied room shell, but its two ends
	## are typed circulation openings rather than closed facades. Rebuild those
	## faces through the module program's measured facade alignment contract:
	## no runtime offset, scaling, or detached entrance posts can make a roof
	## appear borne when the underlying wall geometry says otherwise.
	var recipe_value := _bridge_room_recipe(recipe_id, theme, modules)
	var retained: Array[Dictionary] = []
	for placement: Dictionary in recipe_value.placements:
		if StringName(placement.id) not in [&"west", &"east"]:
			retained.append(placement)
	recipe_value.placements = retained
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	for side: Dictionary in [
		{"id": &"west", "asset": WOOD_DOOR_OPEN,
			"offset": Vector3(-1.5, 0.0, 0.0), "yaw": PI * 0.5,
			"outward": Vector3i.LEFT, "boundary": centre.x - 1.5},
		{"id": &"east", "asset": _mirrored_facade_asset(WOOD_DOOR_OPEN),
			"offset": Vector3(1.5, 0.0, 0.0), "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT, "boundary": centre.x + 1.5},
	]:
		var asset_id := StringName(side.asset)
		recipe_value.add_placement(StringName(side.id), asset_id,
			modules.facade_aligned_transform(asset_id,
				_pose(centre + side.offset as Vector3, float(side.yaw)),
				side.outward as Vector3i, float(side.boundary)))
	recipe_value.role_tags.append(&"open_end_gallery")
	return recipe_value


static func _tower_room_recipe(recipe_id: StringName, terrain_bearing: bool,
		theme: StringName, has_exterior_door: bool,
		modules: FabricModuleProgram, facade_phase: int = 0) -> FabricRecipe:
	## A complete one-bay party-wall storey. It gives the plot solver inhabited
	## mass for the 3 m pockets which cannot accept a 6 m square room.
	## Crucially, this is not the old capped micro filler: several storeys form one
	## bearing chain and receive one pitched roof only at the top. The addressed
	## storey owns the sole exterior door, so an upper alley is a real floor of a
	## ground-rooted building instead of a facade pasted onto a support column.
	var tags: Array[StringName] = [
		&"room", &"generated_building", &"compact_tower",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var facade_family := &"stone" if theme == &"rock" else theme
	var window_asset := _facade_asset(facade_family, facade_phase)
	var rear_asset := _facade_asset(facade_family, facade_phase + 1)
	var side_asset := _facade_asset(facade_family, facade_phase + 2)
	var door_asset := _facade_door(facade_family) if has_exterior_door \
		else window_asset
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	recipe_value.add_placement(&"floor", FLOOR,
		modules.walk_aligned_transform(FLOOR, _pose(centre, 0.0), 0.0))
	for side: Dictionary in [
		{"id": &"south", "asset": door_asset,
			"offset": Vector3(0.0, 0.0, 1.5), "yaw": 0.0,
			"outward": Vector3i.BACK, "boundary": centre.z + 1.5},
		{"id": &"north", "asset": rear_asset,
			"offset": Vector3(0.0, 0.0, -1.5), "yaw": PI,
			"outward": Vector3i.FORWARD, "boundary": centre.z - 1.5},
		{"id": &"west", "asset": side_asset,
			"offset": Vector3(-1.5, 0.0, 0.0), "yaw": PI * 0.5,
			"outward": Vector3i.LEFT, "boundary": centre.x - 1.5},
		{"id": &"east", "asset": _facade_asset(facade_family,
			facade_phase + 3),
			"offset": Vector3(1.5, 0.0, 0.0), "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT, "boundary": centre.x + 1.5},
	]:
		var asset_id := StringName(side.asset)
		if (side.outward as Vector3i).x != 0:
			asset_id = _mirrored_facade_asset(asset_id)
		recipe_value.add_placement(StringName(side.id), asset_id,
			modules.facade_aligned_transform(asset_id,
				_pose(centre + side.offset as Vector3, float(side.yaw)),
				side.outward as Vector3i, float(side.boundary)))
	if not terrain_bearing and not has_exterior_door \
			and facade_phase % 2 == 1:
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"tower", facade_phase), centre, 1.5)
	# At this lattice resolution a 3 m shell has no cell wholly inside it. Keep
	# the rear-west pier structural and treat the remaining cells as furnished
	# volume; exact visual envelopes and baked wall collision remain authoritative.
	# This is the same honest shell/interior split used by the 6 x 3 m bay.
	var pier_xz := Vector2i(-1, -1)
	var door_cell := Vector3i(0, 0, 0)
	for y in 2:
		for z in range(-1, 1):
			for x in range(-1, 1):
				var cell := Vector3i(x, y, z)
				var doorway := has_exterior_door and x == door_cell.x \
					and z == door_cell.z
				if x == pier_xz.x and z == pier_xz.y:
					recipe_value.solid_cells.append(cell)
				elif not doorway:
					recipe_value.headroom_cells.append(cell)
				if not doorway:
					recipe_value.occluder_cells.append(cell)
	if has_exterior_door:
		for y in 2:
			recipe_value.headroom_cells.append(Vector3i(door_cell.x, y,
				door_cell.z))
		recipe_value.add_entrance(&"front", door_cell, Vector3i.BACK)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	_add_room_sockets(recipe_value, 1, 1)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-1, 0, -1),
			Vector3i(2, 1, 2))
	return recipe_value


static func _slim_room_recipe(recipe_id: StringName, terrain_bearing: bool,
		theme: StringName, has_exterior_door: bool,
		modules: FabricModuleProgram, facade_phase: int = 0) -> FabricRecipe:
	## A narrow/deep 3 x 6 m townhouse storey for the slots alongside folded
	## upper routes. Unlike the old one-storey micro infill, this is a composable
	## bearing chain: one addressed floor owns the door and one terminal pitched
	## roof closes the complete stack.
	var tags: Array[StringName] = [
		&"room", &"generated_building", &"slim_building",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var facade_family := &"stone" if theme == &"rock" else theme
	var window_asset := _facade_asset(facade_family, facade_phase)
	var rear_asset := _facade_asset(facade_family, facade_phase + 1)
	var side_asset := _facade_asset(facade_family, facade_phase + 2)
	var door_asset := _facade_door(facade_family) if has_exterior_door \
		else window_asset
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2), Vector3i(2, 1, 4))
	for index in 2:
		var z_offset := -1.5 + float(index) * 3.0
		recipe_value.add_placement(StringName("floor.%d" % index), FLOOR,
			modules.walk_aligned_transform(FLOOR,
				_pose(centre + Vector3(0.0, 0.0, z_offset), 0.0), 0.0))
	recipe_value.add_placement(&"south", door_asset,
		modules.facade_aligned_transform(door_asset,
			_pose(centre + Vector3(0.0, 0.0, 3.0), 0.0),
			Vector3i.BACK, centre.z + 3.0))
	recipe_value.add_placement(&"north", rear_asset,
		modules.facade_aligned_transform(rear_asset,
			_pose(centre + Vector3(0.0, 0.0, -3.0), PI),
			Vector3i.FORWARD, centre.z - 3.0))
	if not terrain_bearing and not has_exterior_door \
			and facade_phase % 2 == 1:
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"slim", facade_phase), centre, 3.0)
	for index in 2:
		var z_offset := -1.5 + float(index) * 3.0
		var west_asset := side_asset if index == int(theme == &"blue") \
			else window_asset
		var east_asset := side_asset if index == int(theme == &"orange") \
			else window_asset
		west_asset = _mirrored_facade_asset(west_asset)
		east_asset = _mirrored_facade_asset(east_asset)
		recipe_value.add_placement(StringName("west.%d" % index), west_asset,
			modules.facade_aligned_transform(west_asset,
				_pose(centre + Vector3(-1.5, 0.0, z_offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 1.5))
		recipe_value.add_placement(StringName("east.%d" % index), east_asset,
			modules.facade_aligned_transform(east_asset,
				_pose(centre + Vector3(1.5, 0.0, z_offset), -PI * 0.5),
				Vector3i.RIGHT, centre.x + 1.5))
	var pier_xz := Vector2i(-1, -2)
	var door_cell := Vector3i(0, 0, 1)
	for y in 2:
		for z in range(-2, 2):
			for x in range(-1, 1):
				var cell := Vector3i(x, y, z)
				var doorway := has_exterior_door \
					and x == door_cell.x and z == door_cell.z
				if x == pier_xz.x and z == pier_xz.y:
					recipe_value.solid_cells.append(cell)
				elif not doorway:
					recipe_value.headroom_cells.append(cell)
				if not doorway:
					recipe_value.occluder_cells.append(cell)
	if has_exterior_door:
		for y in 2:
			recipe_value.headroom_cells.append(Vector3i(door_cell.x, y,
				door_cell.z))
		recipe_value.add_entrance(&"front", door_cell, Vector3i.BACK)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	_add_room_sockets(recipe_value, 1, 2)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-1, 0, -2),
			Vector3i(2, 1, 4))
	return recipe_value


static func _append_segment_building_variants(
		candidates: Array[FabricRecipe], modules: FabricModuleProgram) -> void:
	## The volume partition decides the footprint; this table decides which
	## complete authored construction inhabits it.  Phases 0/1 are the original
	## shell pair already declared in compile().  The remaining pairs reuse the
	## exact same cells, sockets, doors and bearing graph while selecting different
	## measured wall/door assets and different façade-depth treatments.
	for facade_phase in range(2, FACADE_PHASE_COUNT):
		var suffix := _facade_phase_suffix(facade_phase)
		var long_suffix := _facade_phase_suffix(facade_phase, true)
		for theme: StringName in [&"blue", &"orange", &"amber", &"stone"]:
			for addressed: bool in [false, true]:
				var address := ".address" if addressed else ""
				candidates.append(_room_recipe(StringName(
					"room.upper%s.%s%s" % [address, theme, suffix]),
					false, theme, addressed, modules, facade_phase))
				candidates.append(_tower_room_recipe(StringName(
					"room.tower.upper%s.%s%s" % [address, theme, suffix]),
					false, theme, addressed, modules, facade_phase))
				candidates.append(_slim_room_recipe(StringName(
					"room.slim.upper%s.%s%s" % [address, theme, suffix]),
					false, theme, addressed, modules, facade_phase))
				candidates.append(_long_room_recipe(StringName(
					"room.long.upper%s.%s.%s" % [address, theme, long_suffix]),
					false, theme, addressed, facade_phase, modules))


static func _facade_phase_suffix(facade_phase: int,
		long_form: bool = false) -> String:
	assert(facade_phase >= 0 and facade_phase < FACADE_PHASE_COUNT)
	var letters := ["a", "b", "c", "d", "e", "f"]
	var letter: String = letters[facade_phase]
	return letter if long_form else "" if facade_phase == 0 else ".%s" % letter


static func _append_row_vocabulary(candidates: Array[FabricRecipe],
		modules: FabricModuleProgram) -> void:
	## A rowhouse is geometrically the quarter-turn of a slim townhouse but not
	## semantically interchangeable with it: the real public door lies on the
	## broad four-cell eave. Keep that fact in the recipe vocabulary so an exact
	## base-band merge never rotates a decorative gable door toward private mass.
	for theme: StringName in [&"rock", &"blue", &"orange", &"amber"]:
		candidates.append(_row_room_recipe(StringName("room.row.base.%s" % theme),
			true, theme, true, modules))
		candidates.append(_row_room_recipe(StringName(
			"room.row.base.%s.closed" % theme), true, theme, false, modules))
	for theme: StringName in [&"blue", &"orange", &"amber", &"stone"]:
		for facade_phase in FACADE_PHASE_COUNT:
			var phase_suffix := _facade_phase_suffix(facade_phase)
			candidates.append(_row_room_recipe(StringName(
				"room.row.upper.%s%s" % [theme, phase_suffix]), false,
				theme, false, modules, facade_phase))
			candidates.append(_row_room_recipe(StringName(
				"room.row.upper.address.%s%s" % [theme, phase_suffix]), false,
				theme, true, modules, facade_phase))
	for roof_spec: Dictionary in [
		{"id": &"roof.row.blue", "theme": ROOF_BLUE},
		{"id": &"roof.row.orange", "theme": ROOF_ORANGE},
	]:
		candidates.append(_row_roof_recipe(StringName(roof_spec.id),
			StringName(roof_spec.theme), modules))
	var dormer_specs: Array[Dictionary] = [
		{"id": &"roof.row.blue.dormer.left", "theme": ROOF_BLUE,
			"asset": ROOF_WINDOW_02, "side": -1},
		{"id": &"roof.row.blue.dormer.right", "theme": ROOF_BLUE,
			"asset": ROOF_WINDOW_02, "side": 1},
		{"id": &"roof.row.orange.dormer.left", "theme": ROOF_ORANGE,
			"asset": ROOF_WINDOW_04, "side": -1},
		{"id": &"roof.row.orange.dormer.right", "theme": ROOF_ORANGE,
			"asset": ROOF_WINDOW_04, "side": 1},
	]
	for spec: Dictionary in dormer_specs:
		candidates.append(_dormered_row_roof_recipe(StringName(spec.id),
			StringName(spec.theme), StringName(spec.asset), int(spec.side), modules))
	for roof_spec: Dictionary in [
		{"id": &"roof.row.short.blue", "theme": ROOF_BLUE},
		{"id": &"roof.row.short.orange", "theme": ROOF_ORANGE},
		{"id": &"roof.row.chimney.blue", "theme": ROOF_BLUE},
		{"id": &"roof.row.chimney.orange", "theme": ROOF_ORANGE},
	]:
		candidates.append(_chimney_row_roof_recipe(StringName(roof_spec.id),
			StringName(roof_spec.theme), modules))
	var row_minimum := Vector3i(-2, 0, -1)
	var row_size := Vector3i(4, 1, 2)
	candidates.append(_flat_roof_recipe(&"roof.flat.row", row_minimum,
		row_size, &"row_building", modules))
	candidates.append(_flat_roof_garden_recipe(&"roof.flat.row.garden",
		row_minimum, row_size, &"row_building", TERRACE_PLANT_MID, modules))
	candidates.append(_flat_roof_garden_recipe(&"roof.flat.row.garden.rich",
		row_minimum, row_size, &"row_building", TERRACE_PLANT_MID, modules, true))
	candidates.append(_flat_roof_micro_garden_recipe(
		&"roof.flat.row.garden.micro", row_minimum, row_size, &"row_building"))


static func _row_room_recipe(recipe_id: StringName, terrain_bearing: bool,
		theme: StringName, has_exterior_door: bool,
		modules: FabricModuleProgram, facade_phase: int = 0) -> FabricRecipe:
	## One complete 6 x 3 m street-facing house storey. Two old tower cells become
	## one facade rhythm and one bearing volume rather than coincident wall meshes.
	var tags: Array[StringName] = [
		&"room", &"generated_building", &"row_building",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var facade_family := &"stone" if theme == &"rock" else theme
	var window_asset := _facade_asset(facade_family, facade_phase)
	var rear_asset := _facade_asset(facade_family, facade_phase + 1)
	var side_asset := _facade_asset(facade_family, facade_phase + 2)
	var door_asset := _facade_door(facade_family) if has_exterior_door \
		else window_asset
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -1), Vector3i(4, 1, 2))
	for index in 2:
		var x_offset := -1.5 + float(index) * 3.0
		recipe_value.add_placement(StringName("floor.%d" % index), FLOOR,
			modules.walk_aligned_transform(FLOOR,
				_pose(centre + Vector3(x_offset, 0.0, 0.0), 0.0), 0.0))
		var front_asset := door_asset if index == 0 else window_asset
		recipe_value.add_placement(StringName("front.%d" % index), front_asset,
			modules.facade_aligned_transform(front_asset,
				_pose(centre + Vector3(x_offset, 0.0, 1.5), 0.0),
				Vector3i.BACK, centre.z + 1.5))
		recipe_value.add_placement(StringName("back.%d" % index), rear_asset,
			modules.facade_aligned_transform(rear_asset,
				_pose(centre + Vector3(x_offset, 0.0, -1.5), PI),
				Vector3i.FORWARD, centre.z - 1.5))
	for side: Dictionary in [
		{"id": &"west.0", "x": -3.0, "yaw": PI * 0.5,
			"outward": Vector3i.LEFT, "boundary": centre.x - 3.0},
		{"id": &"east.0", "x": 3.0, "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT, "boundary": centre.x + 3.0},
	]:
		var handed_side_asset := _mirrored_facade_asset(side_asset)
		recipe_value.add_placement(StringName(side.id), handed_side_asset,
			modules.facade_aligned_transform(handed_side_asset,
				_pose(centre + Vector3(float(side.x), 0.0, 0.0),
					float(side.yaw)), side.outward as Vector3i,
				float(side.boundary)))
	if not terrain_bearing and not has_exterior_door \
			and facade_phase % 2 == 1:
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"row", facade_phase), centre, 1.5)
	var pier_xz := Vector2i(-2, -1)
	var door_cell := Vector3i(-1, 0, 0)
	for y in 2:
		for z in range(-1, 1):
			for x in range(-2, 2):
				var cell := Vector3i(x, y, z)
				var doorway := has_exterior_door \
					and x == door_cell.x and z == door_cell.z
				if x == pier_xz.x and z == pier_xz.y:
					recipe_value.solid_cells.append(cell)
				elif not doorway:
					recipe_value.headroom_cells.append(cell)
				if not doorway:
					recipe_value.occluder_cells.append(cell)
	if has_exterior_door:
		for y in 2:
			recipe_value.headroom_cells.append(Vector3i(door_cell.x, y,
				door_cell.z))
		recipe_value.add_entrance(&"front", door_cell, Vector3i.BACK)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	_add_room_sockets(recipe_value, 2, 1)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -1),
			Vector3i(4, 1, 2))
	return recipe_value


static func _stair_house_recipe(recipe_id: StringName, theme: StringName,
		terrain_bearing: bool, modules: FabricModuleProgram) -> FabricRecipe:
	var tags: Array[StringName] = [
		&"room", &"stair_house", &"passage_room", &"generated_building",
		&"interior_walk", &"stair", &"circulation_building",
	]
	if terrain_bearing:
		tags.append(&"terrain_bearing")
	var recipe_value := FabricRecipe.new(recipe_id, tags,
		0 if terrain_bearing else 1)
	var window_asset := _wood_window(theme)
	var room_centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	for level in 3:
		var y := float(level) * 3.0
		for index in 2:
			var offset := -1.5 + float(index) * 3.0
			var south_asset := WOOD_DOOR \
				if (level == 0 or level == 2) and index == 0 else window_asset
			var north_asset := window_asset
			recipe_value.add_placement(StringName("south.%d.%d" % [level, index]),
				south_asset, modules.facade_aligned_transform(south_asset,
					_pose(room_centre + Vector3(offset, y, 3.0), 0.0),
					Vector3i.BACK, room_centre.z + 3.0))
			recipe_value.add_placement(StringName("north.%d.%d" % [level, index]),
				north_asset, modules.facade_aligned_transform(north_asset,
					_pose(room_centre + Vector3(-offset, y, -3.0), PI),
					Vector3i.FORWARD, room_centre.z - 3.0))
			recipe_value.add_placement(StringName("west.%d.%d" % [level, index]),
				_mirrored_facade_asset(window_asset),
				modules.facade_aligned_transform(_mirrored_facade_asset(window_asset),
					_pose(room_centre + Vector3(-3.0, y, offset), PI * 0.5),
					Vector3i.LEFT, room_centre.x - 3.0))
			recipe_value.add_placement(StringName("east.%d.%d" % [level, index]),
				_mirrored_facade_asset(window_asset),
				modules.facade_aligned_transform(_mirrored_facade_asset(window_asset),
					_pose(room_centre + Vector3(3.0, y, -offset), -PI * 0.5),
					Vector3i.RIGHT, room_centre.x + 3.0))
	recipe_value.add_placement(&"interior.stair", STAIR_FULL,
		_pose(Vector3(0.0, 0.0, 1.5), 0.0))
	recipe_value.add_placement(&"interior.stair.upper", STAIR_FULL,
		_pose(Vector3(0.0, 3.0, -1.5), PI))
	var roof_asset := ROOF_ORANGE if theme == &"orange" else ROOF_BLUE
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		room_centre, 9.0, PI * 0.5, 6.0))
	var low_opening: Dictionary = {}
	var high_opening: Dictionary = {}
	for x in [-1, 0]:
		for y in [0, 1]:
			low_opening[Vector3i(x, y, 1)] = true
		for y in [4, 5]:
			high_opening[Vector3i(x, y, 1)] = true
	for y in 6:
		for z in range(-2, 2):
			for x in range(-2, 2):
				var cell := Vector3i(x, y, z)
				var boundary := x == -2 or x == 1 or z == -2 or z == 1
				if boundary and not low_opening.has(cell) \
						and not high_opening.has(cell):
					recipe_value.solid_cells.append(cell)
					recipe_value.occluder_cells.append(cell)
	# The roof and gables are part of the circulation building's sealed
	# envelope. They are not a later optional cap that can be forgotten.
	for roof_cell: Vector3i in FabricRecipe.box_cells(Vector3i(-2, 6, -2),
			Vector3i(4, 2, 4)):
		recipe_value.solid_cells.append(roof_cell)
		recipe_value.occluder_cells.append(roof_cell)
	for x in [-1, 0]:
		for step: Vector3i in [
			Vector3i(x, 0, 1), Vector3i(x, 1, 0),
			Vector3i(x, 2, -1), Vector3i(x, 3, 0),
			Vector3i(x, 4, 1),
		]:
			recipe_value.walk_cells.append(step)
			if not recipe_value.headroom_cells.has(step):
				recipe_value.headroom_cells.append(step)
			if not recipe_value.headroom_cells.has(step + Vector3i.UP):
				recipe_value.headroom_cells.append(step + Vector3i.UP)
	recipe_value.add_socket(&"walk.low", FabricRecipe.SocketKind.WALK,
		Vector3i(0, 0, 1), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"walk.high", FabricRecipe.SocketKind.WALK,
		Vector3i(0, 4, 1), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"bearing.top", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 7, 0), Vector3i(0, 1, 0))
	if not terrain_bearing:
		recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
			Vector3i(0, 0, 0), Vector3i(0, -1, 0))
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.ROOM, &"room", 2,
		Vector3i(-2, 0, -2), 4, 4)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	if terrain_bearing:
		_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -2),
			Vector3i(4, 1, 4))
	return recipe_value


static func _exterior_stair_facade_recipe(recipe_id: StringName,
		theme: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## A complete inhabited corner and its facade stair are one recipe. The
	## public cells sit wholly outside the room envelope, so an embedding cannot
	## obtain a vertical transition by accidentally routing through the house.
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"room", &"generated_building", &"terrain_bearing", &"public_walk",
		&"route", &"stair", &"exterior_stair", &"circulation_building",
	], 0)
	var face_assets: Array[StringName] = []
	for face_index in 4:
		face_assets.append(_facade_asset(theme, _face_phase(0, face_index)))
	# The east door opens directly onto the low public tread. Door placement and
	# semantic entrance data are derived from the same facade contract, so a
	# future facade variant cannot leave a decorative door disconnected from the
	# route graph (or claim a route through an unbroken wall).
	_add_room_shell(recipe_value, WOOD_DOOR, face_assets, 6.0, modules, &"right")
	_add_room_occupancy(recipe_value, &"right")
	var roof_asset := ROOF_ORANGE if theme == &"orange" else ROOF_BLUE
	var room_centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		room_centre, 3.0, PI * 0.5, 6.0))
	# The reviewed full stair runs north immediately outside the east facade.
	recipe_value.add_placement(&"facade.stair", STAIR_FULL,
		_pose(Vector3(4.5, 0.0, 1.5), 0.0))
	for x in [2, 3]:
		for step in 3:
			var cell := Vector3i(x, step, -step)
			recipe_value.walk_cells.append(cell)
			recipe_value.headroom_cells.append(cell)
			recipe_value.headroom_cells.append(cell + Vector3i.UP)
			recipe_value.public_air_cells.append(cell)
			recipe_value.public_air_cells.append(cell + Vector3i.UP)
	recipe_value.add_socket(&"walk.low", FabricRecipe.SocketKind.WALK,
		Vector3i(2, 0, 0), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"walk.high", FabricRecipe.SocketKind.WALK,
		Vector3i(2, 2, -2), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"bearing.top", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 3, 0), Vector3i.UP)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.ROOM, &"room", 1,
		Vector3i(-2, 0, -2), 4, 4)
	_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	return recipe_value


static func _supported_court_recipe() -> FabricRecipe:
	var recipe_value := FabricRecipe.new(&"court.supported.12x6", [
		&"public_walk", &"structural_court", &"platform", &"surface_claim",
		&"topology_only",
	], 2)
	recipe_value.walk_cells = FabricRecipe.box_cells(Vector3i(-4, 0, -2),
		Vector3i(8, 1, 4))
	# One deliberately small lightwell keeps the deck from erasing every view of
	# the lower city. It is plan data, not omitted render geometry: the surface
	# compiler classifies the opening and derives a complete guard around it.
	var lightwell := Vector3i(2, 0, 0)
	recipe_value.walk_cells.erase(lightwell)
	recipe_value.daylight_void_cells.append(lightwell)
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-4, 0, -2),
		Vector3i(8, 2, 4))
	recipe_value.public_air_cells.assign(recipe_value.headroom_cells)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.WALK, &"walk", 0,
		Vector3i(-4, 0, -2), 8, 4)
	recipe_value.add_socket(&"bearing.bottom.west",
		FabricRecipe.SocketKind.BEARING, Vector3i(-3, 0, 0), Vector3i.DOWN)
	recipe_value.add_socket(&"bearing.bottom.east",
		FabricRecipe.SocketKind.BEARING, Vector3i(1, 0, 0), Vector3i.DOWN)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing.edge", 0, Vector3i(-4, 0, -2), 8, 4)
	return recipe_value


static func _compact_supported_court_recipe() -> FabricRecipe:
	## A one-building court for the dense rising ring. Its two bearing sockets
	## occupy the far edge, allowing shallow inhabited stacks to support the deck
	## while the near edge cantilevers over the public stair canyon.
	var recipe_value := FabricRecipe.new(&"court.supported.6x6", [
		&"public_walk", &"structural_court", &"platform", &"surface_claim",
		&"topology_only",
	], 2)
	recipe_value.walk_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	# Keep the opening strictly inside the court footprint.  Every side is then
	# owned by a neighbouring walk cell, so guard generation can seal the void
	# without depending on a coincidental adjacent building wall.
	var lightwell := Vector3i(0, 0, 0)
	recipe_value.walk_cells.erase(lightwell)
	recipe_value.daylight_void_cells.append(lightwell)
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 2, 4))
	recipe_value.public_air_cells.assign(recipe_value.headroom_cells)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.WALK, &"walk", 0,
		Vector3i(-2, 0, -2), 4, 4)
	recipe_value.add_socket(&"bearing.bottom.north",
		FabricRecipe.SocketKind.BEARING, Vector3i(0, 0, -1), Vector3i.DOWN)
	recipe_value.add_socket(&"bearing.bottom.south",
		FabricRecipe.SocketKind.BEARING, Vector3i(0, 0, 1), Vector3i.DOWN)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing.edge", 0, Vector3i(-2, 0, -2), 4, 4)
	return recipe_value


static func _bridged_compact_court_recipe() -> FabricRecipe:
	## A 6 m court spanning the true party-wall gap between two inhabited towers.
	## Loads travel horizontally into their upper-storey facade sockets; no empty
	## pier or invented ground column occupies the street below. The public surface
	## and lightwell are otherwise identical to the compact vertically borne court.
	var recipe_value := FabricRecipe.new(&"court.bridged.6x6", [
		&"public_walk", &"structural_court", &"platform", &"surface_claim",
		&"topology_only", &"inhabited_bridge_court",
	], 2)
	recipe_value.walk_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	var lightwell := Vector3i(0, 0, 0)
	recipe_value.walk_cells.erase(lightwell)
	recipe_value.daylight_void_cells.append(lightwell)
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 2, 4))
	recipe_value.public_air_cells.assign(recipe_value.headroom_cells)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.WALK, &"walk", 0,
		Vector3i(-2, 0, -2), 4, 4)
	recipe_value.add_socket(&"bearing.west", FabricRecipe.SocketKind.BEARING,
		Vector3i(-2, 0, -1), Vector3i.LEFT)
	recipe_value.add_socket(&"bearing.east", FabricRecipe.SocketKind.BEARING,
		Vector3i(1, 0, 1), Vector3i.RIGHT)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing.edge", 0, Vector3i(-2, 0, -2), 4, 4)
	return recipe_value


static func _roof_recipe(recipe_id: StringName, roof_asset: StringName,
		modules: FabricModuleProgram) \
		-> FabricRecipe:
	## Legacy gable-fronted square run: the ridge deliberately runs local X, so
	## its gable fronts face the street in the authored fixture compositions
	## and the eave overhang stays on the party-wall sides. Only the fixture/
	## embedder path reaches these ids; production squares use the ridge-Z
	## shells, dormer runs, and the plain modular run below.
	var recipe_value := FabricRecipe.new(recipe_id, [&"roof", &"occupied_mass"], 1)
	var room_centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		room_centre, 0.0, PI * 0.5, 6.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 2, 4))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 0, 0), Vector3i(0, -1, 0))
	_add_roof_junction_sockets(recipe_value, Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	return recipe_value


static func _complete_room_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram,
		include_chimney: bool = false) -> FabricRecipe:
	## The measured complete roof is 5.87 m across its eaves and 6.65 m along
	## its ridge. It closes the 6 m room without a separate triangle whose UVs or
	## peak can drift, and the ridge is longer than the transverse width by
	## construction.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"complete_gable", &"ridge_z"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	recipe_value.add_placement(&"roof", roof_asset,
		modules.roof_bearing_aligned_transform(roof_asset,
			_pose(centre, 0.0), 0.0))
	if include_chimney:
		recipe_value.add_placement(&"chimney", COMPACT_CHIMNEY,
			_pose(centre + Vector3(1.15, -1.5, -0.65), 0.0))
		recipe_value.role_tags.append(&"chimney")
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 2, 4))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	return recipe_value


static func _plain_modular_square_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## Ridge-Z plain modular 6 m run. Equal-band flashed junctions build both
	## joined roofs from this one measured profile (or its dormer variants), so
	## a shared flashing never bridges a 0.6 m ridge mismatch between the SFV
	## run and an LPFV complete shell.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"complete_gable", &"ridge_z",
			&"modular_roof"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		centre, 0.0, 0.0, 6.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 2, 4))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	return recipe_value


static func _modular_square_dormer_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, dormer_asset: StringName,
		eave_side: int, modules: FabricModuleProgram) -> FabricRecipe:
	## Dormers may combine only with the native SFV repeat whose pitch and
	## material profile they were authored against.  Putting one on a complete
	## LPFV shell exposed its untextured construction back.  This finite 6 m run
	## shares the same ridge-Z/gable contract as long roofs and atomic valleys.
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"complete_gable", &"ridge_z",
			&"dormer", &"modular_roof"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		centre, 0.0, 0.0, 6.0))
	_add_compact_roof_dormer(recipe_value, &"dormer", dormer_asset,
		centre + Vector3(float(eave_side) * DORMER_WIDE_EAVE_OFFSET,
			0.0, 0.0), PI * 0.5 if eave_side > 0 else -PI * 0.5)
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -2),
		Vector3i(4, 2, 4))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-2, 0, -2),
		Vector3i(4, 1, 4))
	return recipe_value


static func _long_roof_recipe(recipe_id: StringName, roof_asset: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A 9 m repeat run over a 6 m eave span. The local Z run axis matches the
	## longhouse depth and is strictly longer than the measured 6.49 m eave axis.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"long_building", &"ridge_z"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -3), Vector3i(4, 1, 6))
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		centre, 0.0, 0.0, 9.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -3),
		Vector3i(4, 2, 6))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-2, 0, -3),
		Vector3i(4, 1, 6))
	return recipe_value


static func _dormered_long_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, dormer_asset: StringName, eave_side: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A dormer is selected as part of the proposal's complete measured roof
	## envelope.  It is never pasted on after parcel acceptance.  The authored
	## attic-window shell is embedded into one SFV roof slope and faces the eave;
	## the opposite side is a distinct recipe rather than a negative-scale mirror.
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := _long_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -3), Vector3i(4, 1, 6))
	# The attic-window source faces local +Z.  Rotate that direction toward the
	# selected eave: the earlier sign pointed every dormer into the ridge, leaving
	# its untextured construction back visible as a white wedge through the tiles.
	_add_compact_roof_dormer(recipe_value, &"dormer", dormer_asset,
		centre + Vector3(float(eave_side) * DORMER_WIDE_EAVE_OFFSET,
			0.0, 0.0), PI * 0.5 if eave_side > 0 else -PI * 0.5)
	recipe_value.role_tags.append(&"dormer")
	return recipe_value


static func _paired_dormered_long_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, dormer_asset: StringName, eave_side: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The nine-metre ridge can carry two complete attic-window modules without
	## scaling or overlap. Their centres stay on the roof-repeat lattice and the
	## pair remains one measured recipe, so parcel clearance sees the full roof
	## silhouette before packing. This is intentionally unavailable to the six-
	## metre square roof, where the same pair would crowd both gable seams.
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := _long_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -3), Vector3i(4, 1, 6))
	for index in 2:
		var ridge_offset := -2.0 + float(index) * 4.0
		# A two-window longhouse has one window on each occupied attic pitch.
		# `eave_side` chooses the handed ordering along the ridge rather than
		# putting both modules on one face and exposing their backs from the other.
		var side := eave_side if index == 0 else -eave_side
		var dormer_yaw := PI * 0.5 if side > 0 else -PI * 0.5
		_add_compact_roof_dormer(recipe_value,
			StringName("dormer.%d" % index), dormer_asset,
			centre + Vector3(float(side) * DORMER_WIDE_EAVE_OFFSET,
				0.0, ridge_offset), dormer_yaw)
	recipe_value.role_tags.append(&"dormer")
	recipe_value.role_tags.append(&"paired_dormer")
	recipe_value.role_tags.append(&"opposed_dormer")
	return recipe_value


static func _compact_roof_variants(centre: Vector3, yaw: float,
		bearing_y: float, modules: FabricModuleProgram,
		tight_cross_eaves: bool = true) -> Dictionary:
	## Every continuous compact-gable alternative is aligned here, while the
	## asset contract and its authored pivot are still available. The final town
	## compiler receives finite transforms; it never knows a source filename or
	## invents an offset for a mesh that happened to look close.
	var definitions := {
		&"blue": {
			&"start": COMPACT_ROOF_SLATE_RUN_START_TIGHT \
				if tight_cross_eaves else COMPACT_ROOF_SLATE_RUN_START,
			&"start_flush": COMPACT_ROOF_SLATE_RUN_START_TIGHT_FLUSH \
				if tight_cross_eaves else COMPACT_ROOF_SLATE_RUN_START_FLUSH,
			&"middle": COMPACT_ROOF_SLATE_RUN_MIDDLE_TIGHT \
				if tight_cross_eaves else COMPACT_ROOF_SLATE_RUN_MIDDLE,
			&"middle_mirror": COMPACT_ROOF_SLATE_RUN_MIDDLE_TIGHT_MIRROR \
				if tight_cross_eaves else COMPACT_ROOF_SLATE_RUN_MIDDLE_MIRROR,
			&"end": COMPACT_ROOF_SLATE_RUN_END_TIGHT \
				if tight_cross_eaves else COMPACT_ROOF_SLATE_RUN_END,
			&"end_flush": COMPACT_ROOF_SLATE_RUN_END_TIGHT_FLUSH \
				if tight_cross_eaves else COMPACT_ROOF_SLATE_RUN_END_FLUSH,
		},
		&"orange": {
			&"start": COMPACT_ROOF_ORANGE_RUN_START_TIGHT \
				if tight_cross_eaves else COMPACT_ROOF_ORANGE_RUN_START,
			&"start_flush": COMPACT_ROOF_ORANGE_RUN_START_TIGHT_FLUSH \
				if tight_cross_eaves else COMPACT_ROOF_ORANGE_RUN_START_FLUSH,
			&"middle": COMPACT_ROOF_ORANGE_RUN_MIDDLE_TIGHT \
				if tight_cross_eaves else COMPACT_ROOF_ORANGE_RUN_MIDDLE,
			&"middle_mirror": COMPACT_ROOF_ORANGE_RUN_MIDDLE_TIGHT_MIRROR \
				if tight_cross_eaves else COMPACT_ROOF_ORANGE_RUN_MIDDLE_MIRROR,
			&"end": COMPACT_ROOF_ORANGE_RUN_END_TIGHT \
				if tight_cross_eaves else COMPACT_ROOF_ORANGE_RUN_END,
			&"end_flush": COMPACT_ROOF_ORANGE_RUN_END_TIGHT_FLUSH \
				if tight_cross_eaves else COMPACT_ROOF_ORANGE_RUN_END_FLUSH,
		},
	}
	var out: Dictionary = {}
	for family_value: Variant in definitions.keys():
		var family := StringName(family_value)
		var roles: Dictionary = {}
		for role_value: Variant in (definitions[family_value] as Dictionary).keys():
			var role := StringName(role_value)
			var asset_id := StringName((definitions[family_value] as Dictionary)[role_value])
			assert(modules.contract(asset_id) != null)
			roles[role] = {
				"asset_id": asset_id,
				"transform": modules.roof_bearing_aligned_transform(asset_id,
					_pose(centre, yaw), bearing_y),
			}
		out[family] = roles
	return out


static func _add_compact_roof_run_contract(recipe_value: FabricRecipe,
		run_id: StringName, centres: Array[Vector3], original_ids: Array,
		ridge_axis: StringName, authored_family: StringName,
		modules: FabricModuleProgram, tight_cross_eaves: bool = true,
		run_half_length: float = CELL, run_pitch: float = CELL * 2.0,
		section_pitch: float = CELL) -> void:
	assert(recipe_value != null and not centres.is_empty()
		and centres.size() == original_ids.size())
	assert(ridge_axis in [&"x", &"z"])
	assert(authored_family in [&"blue", &"orange"])
	# Local run records are ordered from the numerically smaller seam to the
	# larger one. Godot's `FORWARD` is -Z, so the positive Z run axis is `BACK`.
	var axis := Vector3.RIGHT if ridge_axis == &"x" else Vector3.BACK
	var yaw := PI * 0.5 if ridge_axis == &"x" else 0.0
	var bays: Array[Dictionary] = []
	for index in centres.size():
		var placement_ids: Array[StringName] = []
		placement_ids.assign(original_ids[index] as Array)
		bays.append({
			"centre": centres[index],
			"placement_ids": placement_ids,
			"variants": _compact_roof_variants(centres[index], yaw,
				centres[index].y, modules, tight_cross_eaves),
		})
	var first := centres[0]
	var last := centres[-1]
	var cross := first.z if ridge_axis == &"x" else first.x
	recipe_value.add_compact_roof_run(run_id,
		first - axis * run_half_length, last + axis * run_half_length,
		cross - CELL, cross + CELL, run_pitch,
		&"compact_gable_exact_3m", authored_family, bays, section_pitch)


static func _tower_roof_recipe(recipe_id: StringName, roof_asset: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The Fantasy Village modular gable is 6.5 m wide and cannot close a 3 m
	## infill room without intersecting its neighbours. The measured LPFV compact
	## roofs are complete 3.7 x 4.2 m pitched shells: a small honest eave, no scale,
	## and no missing gable. Their protrusion stays in the exact visual envelope,
	## so adjacent plots are rejected before assembly rather than repaired later.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"compact_tower", &"ridge_z"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	recipe_value.add_placement(&"roof", roof_asset,
		modules.roof_bearing_aligned_transform(roof_asset,
			_pose(centre, 0.0), 0.0))
	_add_compact_roof_run_contract(recipe_value, &"compact", [centre],
		[[&"roof"]], &"z", &"blue" if roof_asset == COMPACT_ROOF_SLATE_03 \
		else &"orange", modules)
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
	return recipe_value


static func _terminal_tight_gable_recipe(recipe_id: StringName,
		minimum: Vector3i, size: Vector3i, ridge_axis: StringName,
		theme: StringName, modules: FabricModuleProgram,
		low_run_index: int = -1, low_run_mask: int = 0,
		continuous_run_tight_cross_eaves: bool = true) -> FabricRecipe:
	## A full-height authored gable for dense terminal houses whose ordinary eaves
	## cannot coexist with an adjacent roof-wall/support junction. The bake clips
	## only the eave to the exact three-metre construction lane; longer ridges are
	## made from measured rear/middle/front party-seam sections of that same source
	## roof. Thus a terminal crown is real tile-and-gable geometry by construction,
	## never a plank cap, window canopy, scaled substitute, or post-pack repair.
	## Party roofs at occupied bridge endpoints keep this tight authored fallback,
	## but publish the bridge's ordinary cross-eave profile to the continuous-run
	## compiler. When an endpoint and bridge meet, every source piece is replaced
	## by one compatible start/middle/end family; when they do not meet, the tight
	## complete roof remains. The measured union of both finite alternatives is
	## reserved before placement, so this does not create a late visual exception.
	assert(ridge_axis in [&"x", &"z"])
	assert(theme in [&"blue", &"orange"])
	assert(modules != null)
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"occupied_mass", &"pitched_roof", &"terminal_tight_gable",
		StringName("ridge_%s" % ridge_axis),
	], 1)
	var rear_end_asset := COMPACT_ROOF_SLATE_REAR_END_TIGHT \
		if theme == &"blue" else COMPACT_ROOF_ORANGE_REAR_END_TIGHT
	var front_end_asset := COMPACT_ROOF_SLATE_FRONT_END_TIGHT \
		if theme == &"blue" else COMPACT_ROOF_ORANGE_FRONT_END_TIGHT
	var rear_asset := COMPACT_ROOF_SLATE_REAR_TIGHT if theme == &"blue" \
		else COMPACT_ROOF_ORANGE_REAR_TIGHT
	var middle_asset := COMPACT_ROOF_SLATE_MIDDLE_TIGHT if theme == &"blue" \
		else COMPACT_ROOF_ORANGE_MIDDLE_TIGHT
	var front_asset := COMPACT_ROOF_SLATE_FRONT_TIGHT if theme == &"blue" \
		else COMPACT_ROOF_ORANGE_FRONT_TIGHT
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	var run_cells := size.x if ridge_axis == &"x" else size.z
	var cross_cells := size.z if ridge_axis == &"x" else size.x
	assert(posmod(run_cells, 2) == 0 and posmod(cross_cells, 2) == 0)
	var run_count := run_cells / 2
	var cross_count := cross_cells / 2
	assert(low_run_index >= -1 and low_run_index < run_count)
	assert(low_run_mask >= 0 and low_run_mask < (1 << run_count))
	var effective_low_mask := low_run_mask
	if low_run_index >= 0:
		effective_low_mask |= 1 << low_run_index
	if effective_low_mask != 0:
		recipe_value.role_tags.append(&"terminal_step_gable")
	if effective_low_mask == (1 << run_count) - 1:
		# An all-low terminal profile is one continuous shallow setback roof, not
		# a pitched gable with some decoration removed. Naming that construction
		# role lets the shared measured T-junction policy join it to a neighboring
		# wall/eave without granting arbitrary roof overlap.
		recipe_value.role_tags.append(&"setback_shed")
	var low_asset := WINDOW_ROOF_BLUE if theme == &"blue" \
		else WINDOW_ROOF_ORANGE
	for cross_index in cross_count:
		var cross_offset := (float(cross_index * 2 + 1)
			- float(cross_cells) * 0.5) * CELL
		for run_index in run_count:
			var run_offset := (float(run_index * 2 + 1)
				- float(run_cells) * 0.5) * CELL
			var target := centre + (Vector3(run_offset, 0.0, cross_offset) \
				if ridge_axis == &"x" else Vector3(cross_offset, 0.0, run_offset))
			if (effective_low_mask & (1 << run_index)) != 0:
				_add_terminal_low_tiled_bay(recipe_value, StringName(
					"gable.%02d.%02d.low" % [cross_index, run_index]),
					low_asset, target, ridge_axis, modules)
				continue
			var roof_asset := rear_asset if run_index == 0 \
				else front_asset if run_index == run_count - 1 \
				else middle_asset
			var yaw := PI * 0.5 if ridge_axis == &"x" else 0.0
			var assets: Array[StringName] = []
			if run_count == 1:
				assets.assign([rear_end_asset, front_end_asset])
			else:
				assets.append(roof_asset)
			for asset_index in assets.size():
				var selected_asset := assets[asset_index]
				assert(modules.contract(selected_asset) != null)
				var pose := modules.roof_bearing_aligned_transform(selected_asset,
					_pose(target, yaw), 0.0)
				recipe_value.add_placement(StringName("gable.%02d.%02d.%02d" % [
					cross_index, run_index, asset_index]), selected_asset, pose)
	# Publish each uninterrupted full-height ridge interval. A deliberately low
	# setback bay is a real break in the crown and cannot be bridged by the later
	# composition pass.
	for cross_index in cross_count:
		var segment_centres: Array[Vector3] = []
		var segment_ids: Array = []
		var segment_index := 0
		for run_index in run_count + 1:
			var is_full := run_index < run_count \
				and (effective_low_mask & (1 << run_index)) == 0
			if is_full:
				var cross_offset := (float(cross_index * 2 + 1)
					- float(cross_cells) * 0.5) * CELL
				var run_offset := (float(run_index * 2 + 1)
					- float(run_cells) * 0.5) * CELL
				segment_centres.append(centre + (Vector3(run_offset, 0.0,
					cross_offset) if ridge_axis == &"x" else Vector3(
					cross_offset, 0.0, run_offset)))
				var ids: Array[StringName] = []
				if run_count == 1:
					ids.assign([StringName("gable.%02d.%02d.00" % [
						cross_index, run_index]), StringName(
						"gable.%02d.%02d.01" % [cross_index, run_index])])
				else:
					ids.append(StringName("gable.%02d.%02d.00" % [
						cross_index, run_index]))
				segment_ids.append(ids)
			if is_full and run_index < run_count - 1:
				continue
			if not segment_centres.is_empty():
				_add_compact_roof_run_contract(recipe_value, StringName(
					"compact.%02d.%02d" % [cross_index, segment_index]),
					segment_centres, segment_ids, ridge_axis, theme, modules,
					continuous_run_tight_cross_eaves)
				segment_centres = []
				segment_ids = []
				segment_index += 1
	recipe_value.solid_cells = FabricRecipe.box_cells(minimum, size)
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, minimum, size)
	return recipe_value


static func _add_terminal_low_tiled_bay(recipe_value: FabricRecipe,
		placement_prefix: StringName, roof_asset: StringName, centre: Vector3,
		ridge_axis: StringName, modules: FabricModuleProgram) -> void:
	## One genuine tiled low bay lets a longer terminal house descend below typed
	## public headroom while the remaining run keeps a full-height gable. The pair
	## is one measured roof recipe; it is not a later cap pasted over a failed roof.
	var contract_value := modules.contract(roof_asset)
	assert(contract_value != null)
	for side in [-1, 1]:
		# Derive both slopes from one ridge plane. `side` names the eave side,
		# while the shed's high edge always points back toward the shared centre.
		# This makes an upward gable by construction; two unrelated yaw literals
		# can no longer turn the pair into a valley when the ridge axis rotates.
		var target := centre + (Vector3(0.0, 0.0, float(side) * 0.775) \
			if ridge_axis == &"x" else Vector3(float(side) * 0.775, 0.0, 0.0))
		var high_direction := Vector3i(0, 0, -side) if ridge_axis == &"x" \
			else Vector3i(-side, 0, 0)
		var high_boundary := centre.z if ridge_axis == &"x" else centre.x
		var pose := modules.shed_roof_aligned_transform(roof_asset, target, 0.0,
			high_direction, high_boundary)
		recipe_value.add_placement(StringName("%s.%s" % [placement_prefix,
			"negative" if side < 0 else "positive"]), roof_asset, pose)


static func _append_terminal_step_gable_vocabulary(
		candidates: Array[FabricRecipe], modules: FabricModuleProgram) -> void:
	## Every footprint receives the complete finite set of full/low ridge-bay
	## profiles. A one-bay tower therefore has one all-low alternative; a two-bay
	## house has both one-low steps and the all-low profile; the three-bay
	## longhouse has every non-empty subset. Selection is left to the ordinary
	## measured public-air/envelope transaction, so the exact clearance field
	## chooses the least altered profile that fits without seed, coordinate, or
	## mesh-specific repair.
	for spec: Dictionary in [
		{"kind": &"tower", "minimum": Vector3i(-1, 0, -1),
			"size": Vector3i(2, 1, 2), "ridge": &"z", "runs": 1},
		{"kind": &"slim", "minimum": Vector3i(-1, 0, -2),
			"size": Vector3i(2, 1, 4), "ridge": &"z", "runs": 2},
		{"kind": &"row", "minimum": Vector3i(-2, 0, -1),
			"size": Vector3i(4, 1, 2), "ridge": &"x", "runs": 2},
		{"kind": &"building", "minimum": Vector3i(-2, 0, -2),
			"size": Vector3i(4, 1, 4), "ridge": &"z", "runs": 2},
		{"kind": &"long", "minimum": Vector3i(-2, 0, -3),
			"size": Vector3i(4, 1, 6), "ridge": &"z", "runs": 3},
	]:
		for theme: StringName in [&"blue", &"orange"]:
			for low_run_index in int(spec.runs):
				candidates.append(_terminal_tight_gable_recipe(StringName(
					"roof.terminal.step.%s.%s.%d" % [StringName(spec.kind),
						theme, low_run_index]), spec.minimum as Vector3i,
					spec.size as Vector3i, StringName(spec.ridge), theme, modules,
					low_run_index))
			for low_run_mask in range(1, 1 << int(spec.runs)):
				# Singleton masks already have the stable step.<index> names above.
				if (low_run_mask & (low_run_mask - 1)) == 0:
					continue
				candidates.append(_terminal_tight_gable_recipe(StringName(
					"roof.terminal.profile.%s.%s.%d" % [StringName(spec.kind),
						theme, low_run_mask]), spec.minimum as Vector3i,
					spec.size as Vector3i, StringName(spec.ridge), theme, modules,
					-1, low_run_mask))


static func _dormered_tower_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, dormer_asset: StringName, eave_side: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The 3 m infill house uses a complete 4.2 m compact gable. A single native
	## attic-window module fits that ridge and turns the little roof into a
	## recognisable house crown instead of another repeated pyramid. The entire
	## combination is measured before packing; it is never pasted through a
	## neighbour after construction.
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := _tower_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	_add_compact_roof_dormer(recipe_value, &"dormer", dormer_asset,
		centre + Vector3(float(eave_side) * DORMER_COMPACT_EAVE_OFFSET,
			0.0, 0.0), PI * 0.5 if eave_side > 0 else -PI * 0.5)
	recipe_value.role_tags.append(&"dormer")
	return recipe_value


static func _flat_roof_recipe(recipe_id: StringName, minimum: Vector3i,
		size: Vector3i, family: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A flush plank cap for the exact diagonal corners where two authored eaves
	## cannot coexist. It is assembled from the same reviewed 3 m floor module
	## used inside every house, never scaled or shifted off the parcel lattice.
	## These are private roofs rather than public platforms: no walk claim is
	## invented and the ordinary room stack remains the bearing authority.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"flat_roof", family], 1)
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	var x_tiles: int = size.x / 2
	var z_tiles: int = size.z / 2
	for z_index in z_tiles:
		for x_index in x_tiles:
			var offset := Vector3(
				(float(x_index) - float(x_tiles - 1) * 0.5) * 3.0,
				0.0,
				(float(z_index) - float(z_tiles - 1) * 0.5) * 3.0)
			recipe_value.add_placement(StringName("cap.%d.%d" % [z_index,
				x_index]), FLOOR, modules.walk_aligned_transform(FLOOR,
					_pose(centre + offset, 0.0), 0.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(minimum, size)
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.DOWN)
	# A separately measured central accent can bind to this cap without inheriting
	# the cap's full AABB. That distinction matters where a neighboring pitched
	# eave legitimately reaches over the edge but does not approach the centre.
	recipe_value.add_socket(&"bearing.top",
		FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.UP)
	_add_roof_junction_sockets(recipe_value, minimum, size)
	return recipe_value


static func _flat_roof_terrace_recipe(recipe_id: StringName,
		minimum: Vector3i, size: Vector3i, family: StringName,
		side: StringName, modules: FabricModuleProgram,
		lived_in: bool = false) -> FabricRecipe:
	## A full plate whose pitched eaves cannot coexist with a higher neighbor
	## should read as a deliberate roof terrace, not a featureless box lid. One
	## native railing run marks a genuinely exposed edge; the compiler tries all
	## four measured orientations against the final construction envelopes and
	## keeps the old plain cap only when every terrace rail is obstructed.
	assert(side in [&"north", &"east", &"south", &"west"])
	var recipe_value := _flat_roof_recipe(recipe_id, minimum, size, family,
		modules)
	recipe_value.role_tags.append(&"flat_roof_terrace")
	if lived_in:
		recipe_value.role_tags.append(&"lived_in_roof_terrace")
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	var half_x := float(size.x) * CELL * 0.5
	var half_z := float(size.z) * CELL * 0.5
	if side in [&"north", &"south"]:
		var z := centre.z + (-half_z if side == &"north" else half_z)
		for x_index in size.x:
			recipe_value.add_placement(StringName("guard.%02d" % x_index),
				RAILING, _pose(Vector3(float(minimum.x + x_index) * CELL,
					0.0, z), 0.0))
	else:
		var x := centre.x + (-half_x if side == &"west" else half_x)
		for z_index in size.z:
			recipe_value.add_placement(StringName("guard.%02d" % z_index),
				RAILING, _pose(Vector3(x, 0.0,
					float(minimum.z + z_index) * CELL), PI * 0.5))
	if lived_in:
		_add_lived_in_roof_terrace_dressing(recipe_value, centre, size, side)
	return recipe_value


static func _flat_roof_garden_recipe(recipe_id: StringName,
		minimum: Vector3i, size: Vector3i, family: StringName,
		plant_asset: StringName,
		modules: FabricModuleProgram, rich: bool = false) -> FabricRecipe:
	## A full terrace rail can be blocked by a higher neighbor on every exposed
	## side. That geometric pressure must not turn the surviving house into a bare
	## plank cube. This conservative accent binds to the separately sealed cap and
	## keeps its entire envelope in the middle of the already-owned roof plate.
	## Separating their envelopes is exact: a neighboring eave may overlap the cap
	## edge while remaining metres from this planter. It invents neither a walk
	## surface nor a parapet and is rejected if its own measured bounds collide.
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"roof_decoration", &"flat_roof_garden", family,
	], 1)
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	recipe_value.add_placement(&"garden.planter", ROOF_PLANTER,
		_pose(centre + Vector3.UP * 0.04, 0.0))
	recipe_value.add_placement(&"garden.plant", plant_asset,
		_pose(centre + Vector3(0.18, 0.04, -0.14), 0.0))
	if rich:
		# These are private rooftop service/garden structures, not walkable
		# balconies. A chimney gives narrow roofs a vertical stone landmark; broad
		# roofs get the complete framed awning and a second planting cluster. Their
		# exact envelopes are optional and the compiler falls back to the minimal
		# garden when a dense neighboring room occupies the same space.
		if mini(size.x, size.z) >= 4:
			recipe_value.add_placement(&"garden.awning", ROOF_TERRACE_AWNING,
				_pose(centre + Vector3(-0.35, 0.04, 0.0),
					0.0 if size.z >= size.x else PI * 0.5))
			recipe_value.add_placement(&"garden.planter.second", ROOF_PLANTER,
				_pose(centre + Vector3(1.65, 0.04, 1.65), 0.0))
			recipe_value.add_placement(&"garden.plant.second", ROOF_FLOWER_PALE,
				_pose(centre + Vector3(1.82, 0.08, 1.50), 0.0))
			recipe_value.role_tags.append(&"roof_garden_awning")
		else:
			recipe_value.add_placement(&"garden.chimney", TERRACE_CHIMNEY,
				_pose(centre + Vector3(0.42, 0.04, -0.48), 0.0))
			recipe_value.role_tags.append(&"chimney")
		recipe_value.role_tags.append(&"rich_roof_garden")
	# Placed at the same origin as the cap. A local y=1 downward socket meets the
	# cap's local y=0 upward socket without moving the visible authored assets.
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.UP, Vector3i.DOWN)
	return recipe_value


static func _flat_roof_micro_garden_recipe(recipe_id: StringName,
		minimum: Vector3i, size: Vector3i, family: StringName,
		offset_xz: Vector2 = Vector2.ZERO) -> FabricRecipe:
	## Last complete accent in the flat-roof rule table. A neighboring eave can
	## block the planter's broad measured box while leaving enough central roof for
	## one authored flower clump. This remains a real asset with measured bounds,
	## never an overlap exception or a bare procedural plate.
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"roof_decoration", &"flat_roof_garden",
		&"micro_roof_garden", family,
	], 1)
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	recipe_value.add_placement(&"garden.flower", ROOF_FLOWER_SMALL,
		_pose(centre + Vector3(offset_xz.x, 0.05, offset_xz.y), 0.0))
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.UP, Vector3i.DOWN)
	return recipe_value


static func _add_lived_in_roof_terrace_dressing(recipe_value: FabricRecipe,
		centre: Vector3, size: Vector3i, guarded_side: StringName) -> void:
	## Flat roofs are an intentional dense-city type, but a field of pristine
	## plank plates still reads like solver fallback. These finite variants put
	## laundry and planters inside the same measured roof transaction. If their
	## real envelopes meet a higher wall, the compiler tries another orientation
	## and finally the equally valid guarded-but-undressed terrace.
	var inward := Vector3.ZERO
	match guarded_side:
		&"north":
			inward = Vector3(0.0, 0.0, 0.58)
		&"south":
			inward = Vector3(0.0, 0.0, -0.58)
		&"west":
			inward = Vector3(0.58, 0.0, 0.0)
		&"east":
			inward = Vector3(-0.58, 0.0, 0.0)
	var along_x := guarded_side in [&"north", &"south"]
	var half_run := (float(size.x) if along_x else float(size.z)) * CELL * 0.5
	var along := Vector3.RIGHT if along_x else Vector3.BACK
	var planter_offset := maxf(0.0, half_run - 0.72)
	recipe_value.add_placement(&"terrace.planter.0", ROOF_PLANTER,
		_pose(centre + inward + along * planter_offset + Vector3.UP * 0.04,
			0.0 if along_x else PI * 0.5))
	# Four authored leaf/flower silhouettes keep roof gardens from repeating the
	# same pair throughout the town. The orientation still owns the deterministic
	# choice, so this remains a finite recipe rather than random scatter.
	var first_flower := TERRACE_PLANT_TALL if guarded_side == &"south" \
		else TERRACE_PLANT_MID if guarded_side == &"north" \
		else TERRACE_PLANT_BROAD if guarded_side == &"east" \
		else ROOF_FLOWER_BLUE
	var second_flower := ROOF_FLOWER_PALE if guarded_side == &"south" \
		else TERRACE_PLANT_BROAD if guarded_side == &"north" \
		else TERRACE_PLANT_LOW if guarded_side == &"east" \
		else TERRACE_PLANT_MID
	recipe_value.add_placement(&"terrace.flowers.0", first_flower,
		_pose(centre + inward * 1.18 + along * maxf(0.0,
			planter_offset - 0.24) + Vector3.UP * 0.04,
			0.0 if along_x else PI * 0.5))
	if planter_offset > 0.1:
		recipe_value.add_placement(&"terrace.planter.1", ROOF_PLANTER,
			_pose(centre + inward - along * planter_offset + Vector3.UP * 0.04,
				0.0 if along_x else PI * 0.5))
		recipe_value.add_placement(&"terrace.flowers.1", second_flower,
			_pose(centre + inward * 1.18 - along * maxf(0.0,
				planter_offset - 0.24) + Vector3.UP * 0.04,
				0.0 if along_x else PI * 0.5))
	# Wide roof terraces are small exterior rooms in their own right. A bench,
	# barrel, and tabletop lantern occupy the sheltered guard edge; a longhouse
	# can additionally carry one full-height lamp post. Every prop is baked at
	# its authored scale and contributes its measured AABB to this recipe, so a
	# higher neighbour makes the compiler choose another orientation or the
	# undecorated fallback instead of accepting a collision.
	if mini(size.x, size.z) >= 4:
		var guardward := -inward.normalized()
		var cross_half := (float(size.z) if along_x else float(size.x)) \
			* CELL * 0.5
		var furniture_yaw := 0.0 if along_x else PI * 0.5
		var bench_origin := centre + guardward * (cross_half - 0.55)
		var bench_asset := TERRACE_BENCH_ALT \
			if guarded_side in [&"east", &"south"] else TERRACE_BENCH
		recipe_value.add_placement(&"terrace.bench", bench_asset,
			_pose(bench_origin, furniture_yaw))
		var barrel_origin := centre + guardward * (cross_half - 0.50) \
			- along * minf(half_run - 0.50, 2.50)
		var uses_crate := guarded_side in [&"south", &"west"]
		var storage_asset := TERRACE_CRATE if uses_crate else TERRACE_BARREL_A
		recipe_value.add_placement(&"terrace.storage", storage_asset,
			_pose(barrel_origin, furniture_yaw))
		recipe_value.add_placement(&"terrace.lantern.table",
			TERRACE_LANTERN_TABLE,
			_pose(barrel_origin + Vector3.UP * (0.76 if uses_crate else 1.04),
				furniture_yaw))
		if uses_crate:
			recipe_value.add_placement(&"terrace.storage.bag", TERRACE_BAG,
				_pose(barrel_origin + Vector3.UP * 0.76, furniture_yaw + 0.18))
		else:
			recipe_value.add_placement(&"terrace.storage.bucket", TERRACE_BUCKET,
				_pose(barrel_origin + along * 0.86, furniture_yaw))
		recipe_value.role_tags.append(&"roof_storage")
		recipe_value.role_tags.append(&"furnished_roof_terrace")
		if maxi(size.x, size.z) >= 6:
			var post_origin := centre + guardward * (cross_half - 0.68) \
				+ along * minf(half_run - 0.82, 3.25)
			recipe_value.add_placement(&"terrace.lantern.post",
				TERRACE_LANTERN_POST, _pose(post_origin, furniture_yaw))
			recipe_value.role_tags.append(&"terrace_lamp")
	# Broad flat closers otherwise read as low timber slabs from the town
	# overview. A real stone chimney gives every 6 m-or-larger lived-in terrace
	# a vertical service core and a second material. It is part of this measured
	# roof recipe, so dense neighbors can reject it and fall back to the guarded
	# terrace instead of accepting a post-build overlap.
	if mini(size.x, size.z) < 4 and maxi(size.x, size.z) >= 4:
		recipe_value.add_placement(&"terrace.chimney", TERRACE_CHIMNEY,
			_pose(centre + inward * 0.78 - along * 0.42, 0.0))
		recipe_value.role_tags.append(&"chimney")
	elif size.x == size.z and size.x >= 4 \
			and guarded_side in [&"east", &"west"]:
		recipe_value.add_placement(&"terrace.chimney", TERRACE_CHIMNEY,
			_pose(centre + inward * 0.78 - along * 0.42, 0.0))
		# A sheltered stack of firewood occupies the opposite back corner. Its
		# complete 2.15 x 1.95 m bounds fit this 6 m plate and are rejected with the
		# terrace if a neighboring upper room needs the same volume.
		recipe_value.add_placement(&"terrace.firewood", TERRACE_FIREWOOD,
			_pose(centre + inward * 1.92 + along * 1.48,
				0.0 if along_x else PI * 0.5))
		recipe_value.role_tags.append(&"chimney")
		recipe_value.role_tags.append(&"roof_firewood")
	elif size.z > size.x and size.x >= 4 \
			or size.x == size.z and size.x >= 4:
		# The complete 4.24 x 3.03 m framed blue awning fits inside long terraces
		# and broad square terraces without scaling. Alternating square sides
		# between this canopy and a stone chimney keeps the low roof population
		# from repeating one silhouette. Its full measured envelope remains part
		# of the terrace transaction and may fall back when an upper neighbor needs
		# the volume.
		recipe_value.add_placement(&"terrace.awning", ROOF_TERRACE_AWNING,
			_pose(centre, 0.0 if along_x else PI * 0.5))
		recipe_value.role_tags.append(&"roof_terrace_awning")
		if size.x == size.z:
			# The chair sits beneath the square terrace awning rather than consuming
			# a street or balcony cell. Long terraces keep their central aisle open.
			recipe_value.add_placement(&"terrace.chair", TERRACE_CHAIR,
				_pose(centre + inward * 0.36 + along * 1.92,
					0.0 if along_x else PI * 0.5))
			recipe_value.role_tags.append(&"roof_seating")
	# The authored line is 3.135 m long from an end pivot. A three-metre tower
	# cannot contain that measured span, so its pair of planters is the complete
	# lived-in treatment; every deeper/wider family gets laundry as well.
	if half_run * 2.0 < 3.14:
		return
	var laundry_y := 1.48
	if along_x:
		recipe_value.add_placement(&"terrace.laundry", FACADE_CLOTHES,
			_pose(centre + Vector3(-1.565, laundry_y, 0.0) - inward * 0.25,
				0.0))
	else:
		recipe_value.add_placement(&"terrace.laundry", FACADE_CLOTHES,
			_pose(centre + Vector3(0.0, laundry_y, 1.565) - inward * 0.25,
				PI * 0.5))


static func _setback_cap_recipe(recipe_id: StringName, length_cells: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A thin plank weather-cap for the one-cell strip exposed when the next room
	## shifts laterally. The reviewed S floor is a native 1.5 x 1.5 m slab, so one
	## fixed asset closes each exact face even beside protected public air. It is
	## lowered four centimetres below the next floor datum and never scaled.
	assert(length_cells in [1, 2, 4, 6])
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"thin_roof_face", &"setback_cap", &"occupied_mass",
	], 1)
	for x in length_cells:
		# The S asset's pivot lies on its local +X seam (same correction as
		# SettlementFabricAssembler._add_plank_tile), so +0.75 m centres it on
		# the logical fine cell without changing its authored scale.
		var pose := _pose(Vector3(float(x) * CELL + CELL * 0.5, 0.0, 0.0),
			0.0)
		recipe_value.add_placement(StringName("cap.%02d" % x), SETBACK_CAP,
			modules.walk_aligned_transform(SETBACK_CAP, pose, -0.04))
		recipe_value.occluder_cells.append(Vector3i(x, 0, 0))
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.DOWN)
	return recipe_value


static func _setback_terrace_recipe(recipe_id: StringName, length_cells: int,
		rail_side: int, modules: FabricModuleProgram) -> FabricRecipe:
	## A measured inhabited-looking treatment for an otherwise bare setback
	## strip. It retains the exact thin roof-face contract of the plain cap but
	## adds complete authored rail modules only along one solver-selected exposed
	## edge. Even one-cell ledges are real 1.5 m room setbacks and receive the
	## native 1.5 m rail rather than being left as visually empty shelves. The
	## strip remains a private roof, not a fabricated walk surface.
	assert(length_cells in [1, 2, 4, 6] and rail_side in [-1, 1])
	var recipe_value := _setback_cap_recipe(recipe_id, length_cells, modules)
	recipe_value.role_tags.append(&"setback_terrace")
	for x in length_cells:
		recipe_value.add_placement(StringName("guard.%02d" % x), RAILING,
			_pose(Vector3(float(x) * CELL, 0.0,
				float(rail_side) * CELL * 0.5), 0.0))
	# These strips are the exposed shoulders of genuinely staggered rooms, but a
	# rail over bare boards still reads as a solver cap from the town overview.
	# Native planters make every usable 3 m-or-longer strip inhabited; the rare
	# 9 m family also receives one measured stone chimney to break its horizontal
	# silhouette. Both remain inside the recipe's measured visual envelope and
	# can therefore fall back to the plain cap if a neighboring room conflicts.
	if length_cells >= 2:
		var run_centre := float(length_cells) * CELL * 0.5
		recipe_value.add_placement(&"terrace.planter",
			ROOF_PLANTER, _pose(Vector3(run_centre, 0.04,
				-float(rail_side) * 0.22), 0.0))
		var flower_asset := TERRACE_PLANT_TALL if length_cells >= 4 \
				and rail_side < 0 else TERRACE_PLANT_MID if rail_side < 0 \
			else TERRACE_PLANT_BROAD if length_cells >= 4 \
			else TERRACE_PLANT_LOW
		recipe_value.add_placement(&"terrace.flowers", flower_asset,
			_pose(Vector3(run_centre + 0.42, 0.04,
				-float(rail_side) * 0.48), 0.0))
		recipe_value.role_tags.append(&"roof_planter")
	if length_cells == 6:
		recipe_value.add_placement(&"terrace.chimney", TERRACE_CHIMNEY,
			_pose(Vector3(float(length_cells) * CELL * 0.28, 0.0,
				-float(rail_side) * 0.18), 0.0))
		recipe_value.role_tags.append(&"chimney")
	return recipe_value


static func _setback_garden_recipe(recipe_id: StringName, length_cells: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A setback can be enclosed by later room additions on both long edges, so
	## it cannot honestly receive an exposed-edge rail. A native planter still
	## turns that otherwise bare plank band into an inhabited roof garden. The
	## measured asset is only 1.21 x 0.90 m and stays inside the 1.5 m strip; the
	## spatial compiler nevertheless tests its complete visual envelope and can
	## fall back to the undecorated cap where a projecting facade is too close.
	assert(length_cells in [2, 4, 6])
	var recipe_value := _setback_cap_recipe(recipe_id, length_cells, modules)
	recipe_value.role_tags.append(&"setback_garden")
	var run_centre := float(length_cells) * CELL * 0.5
	recipe_value.add_placement(&"garden.planter", ROOF_PLANTER,
		_pose(Vector3(run_centre, 0.04, 0.0), 0.0))
	var flower_asset := TERRACE_PLANT_LOW if length_cells == 2 \
		else TERRACE_PLANT_BROAD if length_cells == 4 else TERRACE_PLANT_MID
	recipe_value.add_placement(&"garden.flowers", flower_asset,
		_pose(Vector3(run_centre - 0.42, 0.04, 0.18), 0.0))
	recipe_value.role_tags.append(&"roof_planter")
	return recipe_value


static func _interstitial_seal_recipe(recipe_id: StringName,
		length_cells: int, capped: bool,
		modules: FabricModuleProgram) -> FabricRecipe:
	## Deliberately sealed infill for a sub-tolerance interstitial slot: a
	## one-cell-deep residual course trapped between two occupied party walls.
	## The construction consumes the slot as solid built mass. Its long side
	## faces stay bare on purpose — the neighboring facades remain the visible
	## surfaces inside the sealed reveal, so no coplanar duplicate skin is
	## created. Only the exposed end reveals are boarded, and a slot open to
	## the sky receives a flush capped top; a slot buried under bridging upper
	## mass omits the cap so no plate fights the soffit above.
	assert(length_cells in [1, 2])
	assert(modules != null)
	# Sealed infill is anchored mass wedged between two party walls; like the
	# authored bracket courses it declares no bearing parent of its own, and a
	# stacked slit band simply rests on the strip sealed beneath it.
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"interstitial_join", &"sealed_infill", &"occupied_mass"], 0)
	# The strip supplies no side or end skins of its own: every 1.5 m band
	# asset in the module program is a full-storey wall whose measured bounds
	# would poke into the storey above the slot. The flanking party walls are
	# the visible reveal surfaces, and the flush cap (or the bridging soffit
	# above a buried strip) closes the top; buried strips carry real timber
	# blocking at their base so the sealed course is honest built mass.
	if capped:
		for x in length_cells:
			recipe_value.add_placement(StringName("cap.%02d" % x),
				SETBACK_CAP, modules.walk_aligned_transform(SETBACK_CAP,
					_pose(Vector3(float(x) * CELL + CELL * 0.5, CELL, 0.0),
						0.0), 0.0))
	else:
		for x in length_cells:
			recipe_value.add_placement(StringName("blocking.%02d" % x),
				BRACE, _pose(Vector3(float(x) * CELL, 0.1, 0.0), 0.0))
	for x in length_cells:
		recipe_value.solid_cells.append(Vector3i(x, 0, 0))
		recipe_value.occluder_cells.append(Vector3i(x, 0, 0))
	return recipe_value


static func _setback_lean_roof_recipe(recipe_id: StringName,
		length_cells: int, wall_side: int,
		roof_asset: StringName) -> FabricRecipe:
	## Close a one-cell room setback as a real wall-bound lean-to. Each 3 m bay is
	## one native SFV half-gable; it overlaps the continuing upper wall only at
	## its authored ridge seam and sheds outward across the exposed lower shoulder.
	## The compiler binds that overlap to the exact upper room as a visual seam.
	assert(length_cells in [2, 4, 6] and wall_side in [-1, 1])
	assert(roof_asset == ROOF_BLUE or roof_asset == ROOF_ORANGE)
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"thin_roof_face", &"setback_lean_to", &"occupied_mass",
		&"pitched_roof",
	], 1)
	var yaw := PI * 0.5 * float(wall_side)
	# The logical row is centred at local Z=0 and its wall seam lies at +/-0.75m.
	# The measured half-gable reaches 1.6217227m from its pivot to either bound;
	# this origin puts the ridge on that seam and the tiles on the exposed side.
	var cross_centre := -float(wall_side) * (1.6217227 - CELL * 0.5)
	for run_index in length_cells / 2:
		var run_centre_x := (float(run_index) * 2.0 + 0.5) * CELL
		recipe_value.add_placement(StringName("slope.%02d" % run_index),
			roof_asset, _pose(Vector3(run_centre_x, 0.0, cross_centre), yaw))
	for x in length_cells:
		recipe_value.solid_cells.append(Vector3i(x, 0, 0))
		recipe_value.occluder_cells.append(Vector3i(x, 0, 0))
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.DOWN)
	return recipe_value


static func _setback_shed_roof_recipe(recipe_id: StringName,
		length_cells: int, eave_side: int, roof_asset: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The one-cell shoulder is only 1.5 m deep. The former half-gable lean-to was
	## authored for a 3 m slope and projected through buildings across a nominal
	## alley. This reviewed window-roof mesh is a true shallow shed: 1.55 m deep,
	## 3.06 m wide, and less than one metre high. One unscaled piece closes each
	## 3 m run. Its typed high edge meets the continuing wall and its low edge
	## drains toward the exposed shoulder.
	assert(length_cells in [2, 4, 6] and eave_side in [-1, 1])
	assert(roof_asset == WINDOW_ROOF_BLUE or roof_asset == WINDOW_ROOF_ORANGE)
	assert(modules != null)
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"thin_roof_face", &"setback_shed", &"occupied_mass",
		&"pitched_roof",
	], 1)
	var contract_value := modules.contract(roof_asset)
	assert(contract_value != null \
		and contract_value.kind == FabricModuleContract.Kind.ROOF_SHED)
	var high_direction := Vector3i(0, 0, -eave_side)
	var high_boundary := -float(eave_side) * CELL * 0.5
	for run_index in length_cells / 2:
		var target := Vector3((float(run_index) * 2.0 + 1.0) * CELL,
			0.0, 0.0)
		var pose := modules.shed_roof_aligned_transform(roof_asset, target, 0.0,
			high_direction, high_boundary)
		recipe_value.add_placement(StringName("shed.%02d" % run_index),
			roof_asset, pose)
	for x in length_cells:
		recipe_value.occluder_cells.append(Vector3i(x, 0, 0))
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.DOWN)
	return recipe_value


static func _partial_gable_roof_recipe(recipe_id: StringName,
		length_cells: int, gable_side: int, theme: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A private one-cell-deep crown remainder is a tiny complete roof edge, not a
	## walk deck and not a window canopy standing in for one. Each 3 m bay uses one
	## exact 3 m x 1.5 m derivative of the same authored compact gable as ordinary
	## houses. The chosen half retains its exterior gable end; its bake-clipped end
	## is the party seam toward the adjoining mass. Both handed alternatives are
	## finite recipes and the normal measured-envelope transaction selects them.
	assert(length_cells in [2, 4, 6] and gable_side in [-1, 1])
	assert(theme in [&"blue", &"orange"] and modules != null)
	var rear_asset := COMPACT_ROOF_SLATE_REAR_END_TIGHT \
		if theme == &"blue" else COMPACT_ROOF_ORANGE_REAR_END_TIGHT
	var front_asset := COMPACT_ROOF_SLATE_FRONT_END_TIGHT \
		if theme == &"blue" else COMPACT_ROOF_ORANGE_FRONT_END_TIGHT
	var roof_asset := rear_asset if gable_side < 0 else front_asset
	var contract_value := modules.contract(roof_asset)
	assert(contract_value != null)
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"roof", &"thin_roof_face", &"partial_gable", &"occupied_mass",
		&"pitched_roof", &"ridge_x",
	], 1)
	for run_index in length_cells / 2:
		var target := Vector3((float(run_index) * 2.0 + 0.5) * CELL,
			0.0, 0.0)
		var pose := _pose(target, 0.0)
		var transformed := pose * contract_value.visual_bounds
		pose.origin.x += target.x - transformed.get_center().x
		pose.origin.z += target.z - transformed.get_center().z
		pose = modules.roof_bearing_aligned_transform(roof_asset, pose, 0.0)
		recipe_value.add_placement(StringName("gable.%02d" % run_index),
			roof_asset, pose)
		# A half-depth crown is still a typed ridge run. Neighboring source
		# strips can therefore join before realization, replacing repeated
		# exterior halves with one start/middle/end roof. The 1.5 m run pitch
		# describes the source claim; the 1.5 m section pitch describes the
		# symmetric baked repeat. Keeping both explicit avoids inferring either
		# measurement from a rendered AABB.
		_add_compact_roof_run_contract(recipe_value,
			StringName("compact.%02d" % run_index), [target],
			[[StringName("gable.%02d" % run_index)]], &"z", theme,
			modules, true, CELL * 0.5, CELL, CELL)
	for x in length_cells:
		recipe_value.occluder_cells.append(Vector3i(x, 0, 0))
	recipe_value.add_socket(&"bearing.bottom",
		FabricRecipe.SocketKind.BEARING, Vector3i.ZERO, Vector3i.DOWN)
	return recipe_value


static func _short_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## A broad one-storey closer is rare and must not read as a low shed. Keep
	## the ordinary complete 6 m gable, but integrate the measured chimney well
	## inside its footprint to restore a convincingly vertical silhouette.
	var recipe_value := _roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	recipe_value.add_placement(&"chimney", COMPACT_CHIMNEY,
		_pose(centre + Vector3(1.0, -1.5, 0.0), 0.0))
	return recipe_value


static func _short_tower_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## The rare one-storey corner closer gets a chimney integrated through its
	## complete pitched roof. The measured 4.88 m chimney is buried 1.5 m into
	## the roof/upper wall volume, leaving a vertical silhouette without scaling
	## the room or claiming a fictitious second inhabited storey.
	var recipe_value := _tower_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	recipe_value.add_placement(&"chimney", COMPACT_CHIMNEY,
		_pose(centre + Vector3(0.65, -1.5, -0.25), 0.0))
	return recipe_value


static func _chimney_tower_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## A roof feature is part of the parcel's prequalified construction choice;
	## this wrapper is shared by ordinary and short compact stacks so a chimney
	## never appears after neighboring clearance has already been accepted.
	return _short_tower_roof_recipe(recipe_id, roof_asset, modules)


static func _slim_roof_recipe(recipe_id: StringName, roof_asset: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## Two complete compact gables close the 3 x 6 m townhouse. Each authored
	## ridge runs along local Z and is longer than its eave span; the half-cell
	## longitudinal composition makes the silhouette narrow/deep without scaling
	## a 6.49 m modular gable sideways. Both shells share the exact wall-top datum:
	## a former 0.6 m visual stagger read as one roof floating off the house.
	assert(roof_asset == ROOF_BLUE or roof_asset == ROOF_ORANGE)
	assert(modules != null)
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"slim_building", &"ridge_z",
			&"staggered_roof"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2), Vector3i(2, 1, 4))
	var first_asset := COMPACT_ROOF_SLATE_REAR if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_ORANGE_REAR
	var second_asset := COMPACT_ROOF_SLATE_FRONT if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_ORANGE_FRONT
	recipe_value.add_placement(&"roof.rear", first_asset,
		modules.roof_bearing_aligned_transform(first_asset,
			_pose(centre + Vector3(0.0, 0.0, -1.5), 0.0), 0.0))
	recipe_value.add_placement(&"roof.front", second_asset,
		modules.roof_bearing_aligned_transform(second_asset,
			_pose(centre + Vector3(0.0, 0.0, 1.5), 0.0), 0.0))
	_add_compact_roof_run_contract(recipe_value, &"compact", [
		centre + Vector3(0.0, 0.0, -1.5),
		centre + Vector3(0.0, 0.0, 1.5),
	], [[&"roof.rear"], [&"roof.front"]], &"z",
		&"blue" if roof_asset == ROOF_BLUE else &"orange", modules)
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -2),
		Vector3i(2, 2, 4))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-1, 0, -2),
		Vector3i(2, 1, 4))
	return recipe_value


static func _row_roof_recipe(recipe_id: StringName, roof_asset: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The wide/shallow counterpart to the slim roof. Two complete compact gables
	## share one rowhouse transaction and run along local X. They use one measured
	## wall-top datum so the composite reads as a professionally joined building,
	## not two modules with one roof lifted above its walls.
	assert(roof_asset == ROOF_BLUE or roof_asset == ROOF_ORANGE)
	assert(modules != null)
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"row_building", &"ridge_x",
			&"staggered_roof"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -1), Vector3i(4, 1, 2))
	var first_asset := COMPACT_ROOF_SLATE_REAR if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_ORANGE_REAR
	var second_asset := COMPACT_ROOF_SLATE_FRONT if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_ORANGE_FRONT
	recipe_value.add_placement(&"roof.left", first_asset,
		modules.roof_bearing_aligned_transform(first_asset,
			_pose(centre + Vector3(-1.5, 0.0, 0.0), PI * 0.5), 0.0))
	recipe_value.add_placement(&"roof.right", second_asset,
		modules.roof_bearing_aligned_transform(second_asset,
			_pose(centre + Vector3(1.5, 0.0, 0.0), PI * 0.5), 0.0))
	_add_compact_roof_run_contract(recipe_value, &"compact", [
		centre + Vector3(-1.5, 0.0, 0.0),
		centre + Vector3(1.5, 0.0, 0.0),
	], [[&"roof.left"], [&"roof.right"]], &"x",
		&"blue" if roof_asset == ROOF_BLUE else &"orange", modules)
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -1),
		Vector3i(4, 2, 2))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_row_roof_junction_sockets(recipe_value, Vector3i(-2, 0, -1),
		Vector3i(4, 1, 2))
	return recipe_value


static func _dormered_row_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, dormer_asset: StringName, eave_side: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := _row_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -1), Vector3i(4, 1, 2))
	_add_compact_roof_dormer(recipe_value, &"dormer", dormer_asset,
		centre + Vector3(1.5, 0.0,
			float(eave_side) * DORMER_COMPACT_EAVE_OFFSET),
		0.0 if eave_side > 0 else PI)
	recipe_value.role_tags.append(&"dormer")
	return recipe_value


static func _chimney_row_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	var recipe_value := _row_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -1), Vector3i(4, 1, 2))
	recipe_value.add_placement(&"chimney", COMPACT_CHIMNEY,
		_pose(centre + Vector3(-0.75, -1.5, 0.45), PI * 0.5))
	return recipe_value


static func _dormered_slim_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, dormer_asset: StringName, eave_side: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A narrow/deep house is already one macroscopic two-gable roof. Embed the
	## attic window in only its forward bay so the stagger remains legible and the
	## silhouette does not become a repeated dormer stack.
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := _slim_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2), Vector3i(2, 1, 4))
	_add_compact_roof_dormer(recipe_value, &"dormer", dormer_asset,
		centre + Vector3(float(eave_side) * DORMER_COMPACT_EAVE_OFFSET,
			0.0, 1.5), PI * 0.5 if eave_side > 0 else -PI * 0.5)
	recipe_value.role_tags.append(&"dormer")
	return recipe_value


static func _add_compact_roof_dormer(recipe_value: FabricRecipe,
		placement_id: StringName, former_dormer_asset: StringName,
		base: Vector3, yaw: float) -> void:
	assert(former_dormer_asset in [ROOF_WINDOW_01, ROOF_WINDOW_02,
		ROOF_WINDOW_03, ROOF_WINDOW_04])
	var embed_y := DORMER_EMBED_Y \
		if former_dormer_asset in [ROOF_WINDOW_01, ROOF_WINDOW_02] \
		else DORMER_SHED_EMBED_Y
	var downslope := Vector3.ZERO
	if former_dormer_asset in [ROOF_WINDOW_03, ROOF_WINDOW_04]:
		downslope = Basis(Vector3.UP, yaw) * Vector3.BACK \
			* DORMER_SHED_DOWNSLOPE_OFFSET
	var scale_value := DORMER_SCALE \
		if former_dormer_asset in [ROOF_WINDOW_01, ROOF_WINDOW_02] \
		else DORMER_SHED_SCALE
	recipe_value.add_placement(placement_id, former_dormer_asset,
		_scaled_pose(base + Vector3.UP * embed_y + downslope, yaw,
			scale_value))
	if not recipe_value.has_tag(&"complete_authored_dormer"):
		recipe_value.role_tags.append(&"complete_authored_dormer")
	var family_tag := &"authored_gabled_dormer" \
		if former_dormer_asset in [ROOF_WINDOW_01, ROOF_WINDOW_02] \
		else &"authored_shed_dormer"
	if not recipe_value.has_tag(family_tag):
		recipe_value.role_tags.append(family_tag)


static func _roof_seam_recipe(recipe_id: StringName, width_m: float,
		owner_run_m: float, seam_run_m: float, run_offset_half_steps: int,
		eave_side: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## Fixed three-metre authored flashing repeats close one classified eave join:
	## either a parallel valley or the lower slope of a stepped eave wall. The
	## seam is carried by exactly one adjacent roof and repeats at its native
	## pitch; no strip is stretched to fit a parcel.
	assert(width_m in [3.0, 6.0] and owner_run_m in [3.0, 6.0, 9.0]
		and seam_run_m in [3.0, 6.0, 9.0] and seam_run_m <= owner_run_m)
	assert(eave_side == -1 or eave_side == 1)
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof_junction", &"classified_eave_join", &"visual_seam"], 1)
	var centre := Vector3(-0.75, 0.0, -0.75)
	var eave_x := centre.x + float(eave_side) * width_m * 0.5
	var seam_centre_z := centre.z \
		+ float(run_offset_half_steps) * CELL * 0.5
	var start_z := seam_centre_z - seam_run_m * 0.5
	var repeat_count := roundi(seam_run_m / 3.0)
	for index in repeat_count:
		recipe_value.add_placement(StringName("seam.%02d" % index), ROOF_SEAM,
			_pose(Vector3(eave_x, 0.05, start_z + float(index) * 3.0), 0.0))
	var width_cells := roundi(width_m / CELL)
	var depth_cells := roundi(owner_run_m / CELL)
	var minimum := Vector3i(-width_cells / 2, 0, -depth_cells / 2)
	var socket_x := minimum.x if eave_side < 0 \
		else minimum.x + width_cells - 1
	var socket_id := &"bearing.bottom"
	recipe_value.add_socket(socket_id, FabricRecipe.SocketKind.BEARING,
		Vector3i(socket_x, 1, 0), Vector3i(0, -1, 0))
	return recipe_value


static func _append_feature_portal_vocabulary(
		candidates: Array[FabricRecipe], modules: FabricModuleProgram) -> void:
	## Enumerate all non-empty cardinal masks for the room recipes the spatial
	## compiler can actually select. A room may carry a balcony on one face and
	## one or two skywalk ends on others, so choosing only a single opening would
	## make valid sealed topology visually lie whenever features coincide.
	var base_count := candidates.size()
	for candidate_index in base_count:
		var base := candidates[candidate_index]
		if not _is_feature_portal_base(base):
			continue
		for portal_mask in range(1, FEATURE_PORTAL_MASK_ALL + 1):
			candidates.append(_feature_portal_variant(base, portal_mask, modules))


static func _append_address_door_phase_vocabulary(
		candidates: Array[FabricRecipe]) -> void:
	## Enumerate the second exact threshold for every addressed generated room
	## before feature-portal variants are expanded. A balcony or occupied bridge
	## can therefore coexist with either exterior-door phase in one measured
	## recipe; no later compiler pass moves an aperture or wall module.
	var base_count := candidates.size()
	for candidate_index in base_count:
		var base := candidates[candidate_index]
		if base == null or not base.has_tag(&"room") \
				or not base.has_tag(&"generated_building") \
				or base.entrances.size() != 1 \
				or (base.entrances[0] as Dictionary).facing != Vector3i.BACK:
			continue
		candidates.append(_address_door_phase_variant(base))


static func _address_door_phase_variant(base: FabricRecipe) -> FabricRecipe:
	var tags: Array[StringName] = []
	tags.assign(base.role_tags)
	tags.append(&"alternate_door_phase")
	var variant := FabricRecipe.new(address_door_phase_recipe_id(base.recipe_id, 1),
		tags, base.bearing_parent_count)
	for placement: Dictionary in base.placements:
		var asset_id := StringName(placement.asset_id)
		if WOOD_DOORS.has(asset_id) or ROCK_DOORS.has(asset_id):
			asset_id = _mirrored_facade_asset(asset_id)
		variant.add_placement(StringName(placement.id),
			asset_id, placement.transform as Transform3D)
	for run: Dictionary in base.construction_runs:
		var placement_ids: Array[StringName] = []
		placement_ids.assign(run.placement_ids as Array)
		variant.add_construction_run(StringName(run.id), StringName(run.kind),
			placement_ids, float(run.start_seam), float(run.end_seam),
			float(run.repeat_pitch), StringName(run.seam_profile),
			StringName(run.material_family))
	variant.solid_cells.assign(base.solid_cells)
	variant.walk_cells.assign(base.walk_cells)
	variant.headroom_cells.assign(base.headroom_cells)
	variant.public_air_cells.assign(base.public_air_cells)
	variant.daylight_void_cells.assign(base.daylight_void_cells)
	variant.inhabited_cells.assign(base.inhabited_cells)
	variant.occluder_cells.assign(base.occluder_cells)
	variant.terrain_bearing_cells.assign(base.terrain_bearing_cells)
	for socket: Dictionary in base.sockets:
		variant.add_socket(StringName(socket.id), int(socket.kind),
			socket.cell as Vector3i, socket.facing as Vector3i)
	var entrance := base.entrances[0] as Dictionary
	var original := entrance.cell as Vector3i
	var facing := entrance.facing as Vector3i
	assert(facing == Vector3i.BACK)
	var shifted := original + Vector3i.LEFT
	for y_offset in 2:
		var old_cell := original + Vector3i.UP * y_offset
		var new_cell := shifted + Vector3i.UP * y_offset
		variant.headroom_cells.erase(old_cell)
		variant.inhabited_cells.erase(old_cell)
		_append_unique_cell(variant.solid_cells, old_cell)
		_append_unique_cell(variant.occluder_cells, old_cell)
		variant.solid_cells.erase(new_cell)
		variant.occluder_cells.erase(new_cell)
		_append_unique_cell(variant.headroom_cells, new_cell)
		_append_unique_cell(variant.inhabited_cells, new_cell)
	variant.add_entrance(StringName(entrance.id), shifted, facing)
	return variant


static func _is_feature_portal_base(recipe_value: FabricRecipe) -> bool:
	if recipe_value == null or not recipe_value.has_tag(&"generated_building"):
		return false
	var id := String(recipe_value.recipe_id)
	# Stone upper-storey recipes are reachable for low, terrain-near storeys and
	# may own a balcony or an occupied-link endpoint. They therefore need the
	# same finite, measured portal vocabulary as the timber families; omitting
	# them made an otherwise exact topology fail only during final asset binding.
	return id.begins_with("room.upper.") or id.begins_with("room.base.") \
		or id.begins_with("room.long.upper.") \
		or id.begins_with("room.long.base.") \
		or id.begins_with("room.slim.upper.") \
		or id.begins_with("room.slim.base.") \
		or id.begins_with("room.row.upper.") \
		or id.begins_with("room.row.base.") \
		or id.begins_with("room.tower.upper.") \
		or id.begins_with("room.tower.base.")


static func _feature_portal_variant(base: FabricRecipe, portal_mask: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	var tags: Array[StringName] = []
	tags.assign(base.role_tags)
	tags.append(&"feature_portal")
	var variant := FabricRecipe.new(feature_portal_recipe_id(base.recipe_id,
		portal_mask), tags, base.bearing_parent_count)
	var portal_by_placement: Dictionary = {}
	for bit in [FEATURE_PORTAL_NORTH, FEATURE_PORTAL_EAST,
			FEATURE_PORTAL_SOUTH, FEATURE_PORTAL_WEST]:
		if (portal_mask & bit) == 0:
			continue
		var spec := _feature_portal_spec(base.recipe_id, bit)
		assert(not spec.is_empty())
		portal_by_placement[StringName(spec.placement)] = spec
	for placement: Dictionary in base.placements:
		var placement_id := StringName(placement.id)
		# Front facade ivy/laundry/sign would otherwise hang across a newly
		# opened south portal. Its absence is itself part of the finite variant.
		if (portal_mask & FEATURE_PORTAL_SOUTH) != 0 \
				and String(placement_id).begins_with("facade."):
			continue
		if portal_by_placement.has(placement_id):
			var spec := portal_by_placement[placement_id] as Dictionary
			# Feature links are private occupied rooms, not public circulation. A
			# permanently open arch reads as a doorway into empty air whenever the
			# adjoining enclosed bridge or balcony is hidden by an oblique roofline.
			# Keep the exact clear aperture and threshold contract, but finish it with
			# the authored timber door leaf; a future interactive-door layer can own
			# opening state without making the static town shell visually dishonest.
			var door_asset := _mirrored_facade_asset(WOOD_DOOR_CLOSED) \
				if (spec.outward as Vector3i).x != 0 else WOOD_DOOR_CLOSED
			variant.add_placement(placement_id, door_asset,
				modules.facade_aligned_transform(door_asset,
					spec.pose as Transform3D, spec.outward as Vector3i,
					float(spec.boundary)))
		else:
			variant.add_placement(placement_id,
				StringName(placement.asset_id),
				placement.transform as Transform3D)
	# The portal is a complete architectural joint, not merely a wall texture
	# swap. Give every opened face two matching jambs that hide the repeat-module
	# seam. The adjoining balcony/skywalk recipe owns its walk surface; putting a
	# one-cell threshold in this room recipe would incorrectly enlarge the room's
	# visual envelope into neighboring roofs before the related feature is bound.
	for bit_value: Variant in portal_by_placement.values():
		var portal_spec := bit_value as Dictionary
		var outward := portal_spec.outward as Vector3i
		var wall_pose := portal_spec.pose as Transform3D
		var tangent := Vector3(float(outward.z), 0.0, float(-outward.x))
		for side in [-1, 1]:
			variant.add_placement(StringName("portal.jamb.%d.%s" % [
				_portal_bit_for_outward(outward), "left" if side < 0 else "right"]),
				PORTAL_JAMB, _pose(wall_pose.origin + tangent * (CELL - 0.12) \
					* float(side), 0.0))
	for run: Dictionary in base.construction_runs:
		var placement_ids: Array[StringName] = []
		placement_ids.assign(run.placement_ids as Array)
		variant.add_construction_run(StringName(run.id), StringName(run.kind),
			placement_ids, float(run.start_seam), float(run.end_seam),
			float(run.repeat_pitch), StringName(run.seam_profile),
			StringName(run.material_family))
	variant.solid_cells.assign(base.solid_cells)
	variant.walk_cells.assign(base.walk_cells)
	variant.headroom_cells.assign(base.headroom_cells)
	variant.public_air_cells.assign(base.public_air_cells)
	variant.daylight_void_cells.assign(base.daylight_void_cells)
	variant.inhabited_cells.assign(base.inhabited_cells)
	variant.occluder_cells.assign(base.occluder_cells)
	variant.terrain_bearing_cells.assign(base.terrain_bearing_cells)
	for spec_value: Variant in portal_by_placement.values():
		var aperture_base := (spec_value as Dictionary).cell as Vector3i
		for y in 2:
			var aperture := aperture_base + Vector3i.UP * y
			variant.solid_cells.erase(aperture)
			variant.occluder_cells.erase(aperture)
			_append_unique_cell(variant.headroom_cells, aperture)
			_append_unique_cell(variant.inhabited_cells, aperture)
	for socket: Dictionary in base.sockets:
		variant.add_socket(StringName(socket.id), int(socket.kind),
			socket.cell as Vector3i, socket.facing as Vector3i)
	for entrance: Dictionary in base.entrances:
		variant.add_entrance(StringName(entrance.id),
			entrance.cell as Vector3i, entrance.facing as Vector3i)
	return variant


static func _portal_bit_for_outward(outward: Vector3i) -> int:
	match outward:
		Vector3i.FORWARD:
			return FEATURE_PORTAL_NORTH
		Vector3i.RIGHT:
			return FEATURE_PORTAL_EAST
		Vector3i.BACK:
			return FEATURE_PORTAL_SOUTH
		Vector3i.LEFT:
			return FEATURE_PORTAL_WEST
		_:
			return 0


static func _feature_portal_spec(base_recipe_id: StringName,
		portal_bit: int) -> Dictionary:
	var id := String(base_recipe_id)
	var family := &"square"
	var minimum := Vector3i(-2, 0, -2)
	var size := Vector3i(4, 1, 4)
	if id.begins_with("room.long.upper.") \
			or id.begins_with("room.long.base."):
		family = &"long"
		minimum = Vector3i(-2, 0, -3)
		size = Vector3i(4, 1, 6)
	elif id.begins_with("room.slim.upper.") \
			or id.begins_with("room.slim.base."):
		family = &"slim"
		minimum = Vector3i(-1, 0, -2)
		size = Vector3i(2, 1, 4)
	elif id.begins_with("room.row.upper.") \
			or id.begins_with("room.row.base."):
		family = &"row"
		minimum = Vector3i(-2, 0, -1)
		size = Vector3i(4, 1, 2)
	elif id.begins_with("room.tower.upper.") \
			or id.begins_with("room.tower.base."):
		family = &"tower"
		minimum = Vector3i(-1, 0, -1)
		size = Vector3i(2, 1, 2)
	elif not id.begins_with("room.upper.") \
			and not id.begins_with("room.base."):
		return {}
	var centre := FabricModuleProgram.footprint_centre(minimum, size)
	var half_x := float(size.x) * CELL * 0.5
	var half_z := float(size.z) * CELL * 0.5
	var along_ns := 1.5 if family in [&"square", &"long", &"row"] else 0.0
	var along_ew := 1.5 if family in [&"square", &"slim"] else 0.0
	match portal_bit:
		FEATURE_PORTAL_NORTH:
			return {
				"placement": &"back.1" if family in [&"square", &"long", &"row"] \
					else &"north",
				"cell": Vector3i(0, 0, minimum.z),
				"pose": _pose(centre + Vector3(along_ns, 0.0, -half_z), PI),
				"outward": Vector3i.FORWARD,
				"boundary": centre.z - half_z,
			}
		FEATURE_PORTAL_EAST:
			return {
				"placement": &"right.1" if family == &"square" \
					else &"east.1" if family in [&"long", &"slim"] \
					else &"east.0" if family == &"row" else &"east",
				"cell": Vector3i(minimum.x + size.x - 1, 0, 0),
				"pose": _pose(centre + Vector3(half_x, 0.0, along_ew),
					-PI * 0.5),
				"outward": Vector3i.RIGHT,
				"boundary": centre.x + half_x,
			}
		FEATURE_PORTAL_SOUTH:
			return {
				"placement": &"front.1" if family in [&"square", &"long", &"row"] \
					else &"south",
				"cell": Vector3i(0, 0, minimum.z + size.z - 1),
				"pose": _pose(centre + Vector3(along_ns, 0.0, half_z), 0.0),
				"outward": Vector3i.BACK,
				"boundary": centre.z + half_z,
			}
		FEATURE_PORTAL_WEST:
			return {
				"placement": &"left.1" if family == &"square" \
					else &"west.1" if family in [&"long", &"slim"] \
					else &"west.0" if family == &"row" else &"west",
				"cell": Vector3i(minimum.x, 0, 0),
				"pose": _pose(centre + Vector3(-half_x, 0.0, along_ew),
					PI * 0.5),
				"outward": Vector3i.LEFT,
				"boundary": centre.x - half_x,
			}
		_:
			return {}


static func _append_unique_cell(cells: Array[Vector3i], cell: Vector3i) -> void:
	if not cells.has(cell):
		cells.append(cell)


static func _append_roof_seam_vocabulary(candidates: Array[FabricRecipe],
		modules: FabricModuleProgram) -> void:
	## Enumerate the finite native-pitch interval vocabulary. A partial contact
	## never stretches flashing: each legal segment is composed from complete
	## 3 m modules and remains bonded at the owning roof's canonical datum.
	var seen: Dictionary = {}
	for kind: StringName in [&"tower", &"slim", &"row", &"building", &"long"]:
		var owner_run_cells := 2 if kind == &"tower" else 4 \
			if kind in [&"slim", &"row", &"building"] else 6
		var width_m := 3.0 if kind in [&"tower", &"slim", &"row"] else 6.0
		for face_cells in range(2, owner_run_cells + 1, 2):
			for start_cell in range(0, owner_run_cells - face_cells + 1, 2):
				var offset_half_steps := start_cell * 2 + face_cells \
					- owner_run_cells
				for side in [FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
						FabricRoofTopologyPlan.Side.EAVE_POSITIVE]:
					var recipe_id := FabricRoofJunctionModuleTable \
						.eave_seam_recipe_id(kind, face_cells,
							offset_half_steps, side)
					if recipe_id.is_empty() or seen.has(recipe_id):
						continue
					seen[recipe_id] = true
					candidates.append(_roof_seam_recipe(recipe_id, width_m,
						float(owner_run_cells) * CELL,
						float(face_cells) * CELL, offset_half_steps,
						-1 if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else 1,
						modules))


static func _append_bisected_valley_vocabulary(
		candidates: Array[FabricRecipe], modules: FabricModuleProgram) -> void:
	## A perpendicular valley is a pair of finite recipe substitutions. The host
	## replaces exactly two ordinary slope repeats with left/right bisected tiles;
	## the branch omits exactly the gable that enters that opening. Enumerating the
	## legal signatures here keeps arbitrary offsets and overlay repairs out of
	## runtime construction.
	for kind: StringName in [&"building", &"long"]:
		var offsets: Array[int] = ([0] as Array[int]) \
			if kind == &"building" else ([-2, 2] as Array[int])
		for theme: StringName in [&"blue", &"orange"]:
			for offset in offsets:
				for side in [FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
						FabricRoofTopologyPlan.Side.EAVE_POSITIVE]:
					var recipe_id := FabricRoofJunctionModuleTable \
						.bisected_valley_recipe_id(kind, theme, offset, side)
					candidates.append(_atomic_gable_roof_recipe(recipe_id, kind,
						theme, modules, offset, side, -1))
			for side in [FabricRoofTopologyPlan.Side.RIDGE_NEGATIVE,
					FabricRoofTopologyPlan.Side.RIDGE_POSITIVE]:
				var recipe_id := FabricRoofJunctionModuleTable \
					.open_gable_recipe_id(kind, theme, side)
				candidates.append(_atomic_gable_roof_recipe(recipe_id, kind,
					theme, modules, 0, -1, side))


static func _atomic_gable_roof_recipe(recipe_id: StringName, kind: StringName,
		theme: StringName, modules: FabricModuleProgram,
		valley_offset_half_steps: int, valley_eave_side: int,
		open_gable_side: int) -> FabricRecipe:
	assert(not recipe_id.is_empty() and kind in [&"building", &"long"]
		and theme in [&"blue", &"orange"])
	var minimum := Vector3i(-2, 0, -2) if kind == &"building" \
		else Vector3i(-2, 0, -3)
	var size := Vector3i(4, 2, 4) if kind == &"building" \
		else Vector3i(4, 2, 6)
	var run_length := 6.0 if kind == &"building" else 9.0
	var roof_asset := ROOF_ORANGE if theme == &"orange" else ROOF_BLUE
	var left_asset := ROOF_BISECT_LEFT_ORANGE if theme == &"orange" \
		else ROOF_BISECT_LEFT_BLUE
	var right_asset := ROOF_BISECT_RIGHT_ORANGE if theme == &"orange" \
		else ROOF_BISECT_RIGHT_BLUE
	var replacements: Dictionary = {}
	if valley_eave_side >= 0:
		var first_repeat := 0 if kind == &"building" \
			else 0 if valley_offset_half_steps < 0 else 1
		var pair_name := "negative" \
			if valley_eave_side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE \
			else "positive"
		var first_asset := left_asset \
			if valley_eave_side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE \
			else right_asset
		var second_asset := right_asset \
			if valley_eave_side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE \
			else left_asset
		replacements["%d:%s" % [first_repeat, pair_name]] = first_asset
		replacements["%d:%s" % [first_repeat + 1, pair_name]] = second_asset
	var centre := FabricModuleProgram.footprint_centre(minimum,
		Vector3i(size.x, 1, size.z))
	var tags: Array[StringName] = [
		&"roof", &"occupied_mass", &"ridge_z", &"atomic_roof_junction",
	]
	if valley_eave_side >= 0:
		tags.append(&"bisected_valley_host")
	if open_gable_side >= 0:
		tags.append(&"open_gable_branch")
	var recipe_value := FabricRecipe.new(recipe_id, tags, 1)
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		centre, 0.0, 0.0, run_length, replacements,
		open_gable_side != FabricRoofTopologyPlan.Side.RIDGE_NEGATIVE,
		open_gable_side != FabricRoofTopologyPlan.Side.RIDGE_POSITIVE))
	recipe_value.solid_cells = FabricRecipe.box_cells(minimum, size)
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, minimum,
		Vector3i(size.x, 1, size.z))
	return recipe_value


static func _add_roof_junction_sockets(recipe_value: FabricRecipe,
		minimum: Vector3i, size: Vector3i) -> void:
	## Both sockets lie on the classified eave cells at the roof base datum.
	## Junction components use the same proposal transform, so the bond is an
	## exact lattice equality and cannot drift with an asset pivot.
	recipe_value.add_socket(&"bearing.junction.eave.negative",
		FabricRecipe.SocketKind.BEARING, Vector3i(minimum.x, 0, 0),
		Vector3i.UP)
	recipe_value.add_socket(&"bearing.junction.eave.positive",
		FabricRecipe.SocketKind.BEARING,
		Vector3i(minimum.x + size.x - 1, 0, 0), Vector3i.UP)


static func _add_row_roof_junction_sockets(recipe_value: FabricRecipe,
		minimum: Vector3i, size: Vector3i) -> void:
	## Row roofs rotate the standard ridge/eave basis by one quarter turn: their
	## flashing sockets therefore live on the local Z edges, not the X edges.
	recipe_value.add_socket(&"bearing.junction.eave.negative",
		FabricRecipe.SocketKind.BEARING, Vector3i(0, 0, minimum.z),
		Vector3i.UP)
	recipe_value.add_socket(&"bearing.junction.eave.positive",
		FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 0, minimum.z + size.z - 1), Vector3i.UP)


static func _short_slim_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	## A one-storey narrow/deep closer still needs a vertical roofline when its
	## six-metre side is visible. The chimney remains wholly inside that envelope
	## and uses the same complete gable run as every taller townhouse.
	var recipe_value := _slim_roof_recipe(recipe_id, roof_asset, modules)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2), Vector3i(2, 1, 4))
	recipe_value.add_placement(&"chimney", COMPACT_CHIMNEY,
		_pose(centre + Vector3(0.45, -1.5, -0.75), 0.0))
	return recipe_value


static func _chimney_slim_roof_recipe(recipe_id: StringName,
		roof_asset: StringName, modules: FabricModuleProgram) -> FabricRecipe:
	return _short_slim_roof_recipe(recipe_id, roof_asset, modules)


static func _outcrop_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram, bearing_drop_cells: int = 0,
		back_socket_x: int = -1) \
		-> FabricRecipe:
	assert(bearing_drop_cells >= 0 and bearing_drop_cells <= 1)
	assert(back_socket_x >= -2 and back_socket_x <= 1)
	var role_tags: Array[StringName] = [
		&"room", &"outcropping", &"overhead_occupied",
	]
	if back_socket_x != -1:
		role_tags.append(&"corner_outcropping")
		role_tags.append(&"corner_jetty")
	else:
		role_tags.append(&"oriel_window")
		role_tags.append(&"native_width_gabled_bay")
		role_tags.append(&"roofed_facade_bay")
	if bearing_drop_cells == 1:
		role_tags.append(&"half_raised_outcropping")
		role_tags.append(&"half_level_oriel")
	var recipe_value := FabricRecipe.new(recipe_id, role_tags, 1)
	var wall := _wood_window(theme)
	var roof_asset := COMPACT_ROOF_ORANGE_FRONT if theme == &"orange" \
		else COMPACT_ROOF_SLATE_FRONT
	# Centre bays occupy one 3 m facade module. Corner variants shift that same
	# complete envelope one fine cell left/right, so their overlap with the
	# parent is a deliberate square-at-a-corner composition rather than a larger
	# box protruding from the middle of the wall.
	var minimum_x := -2 if back_socket_x == -2 \
		else 0 if back_socket_x == 1 else -1
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(minimum_x, 0, -1), Vector3i(2, 1, 2))
	# A projection is a shallow roofed bay framed into the parent facade. One
	# reviewed floor and three complete wall modules keep it visibly smaller than
	# the parent room. The exact three-metre roof end keeps its exterior gable and
	# leaves its rear party seam open into the parent. Its ridge follows the bay's
	# projection, so its open end meets the facade exactly instead of broad eaves
	# colliding with neighbouring rooms.
	recipe_value.add_placement(&"floor", FLOOR,
		modules.walk_aligned_transform(FLOOR, _pose(centre, 0.0), 0.0))
	recipe_value.add_placement(&"front", wall,
		modules.facade_aligned_transform(wall,
			_pose(centre + Vector3(0.0, 0.0, 1.5), 0.0),
			Vector3i.BACK, centre.z + 1.5))
	# The rear is intentionally open at the declared room seam; the parent wall
	# supplies the framed opening. Closing it with a generic plain wall made the
	# object structurally connected but visibly inaccessible.
	for side: Dictionary in [
		# The bay is one authored 3 m module wide. Its side planes therefore sit
		# at the +/-1.5 m eaves, not at the +/-3 m boundary of a full room. The
		# former offsets left two open strips which read as missing/broken side
		# textures even though the correct complete wall asset was present.
		{"id": &"left", "x": -1.5, "yaw": PI * 0.5,
			"outward": Vector3i.LEFT},
		{"id": &"right", "x": 1.5, "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT},
	]:
		# Timber panels own one terminal post. Hand the left return its baked
		# mirror and the right return the source hand so the two outer corners each
		# receive one post; using the mirror on both sides doubled one corner and
		# left the other edge visually open in close-up captures.
		var side_asset := _mirrored_facade_asset(wall) \
			if StringName(side.id) == &"left" else wall
		recipe_value.add_placement(StringName(side.id), side_asset,
			modules.facade_aligned_transform(side_asset,
				_pose(centre + Vector3(float(side.x), 0.0, 0.0),
					float(side.yaw)), side.outward as Vector3i,
				centre.x + float(side.x)))
	recipe_value.add_placement(&"roof", roof_asset,
		modules.roof_bearing_aligned_transform(roof_asset,
			_pose(centre + Vector3.UP * 3.0, 0.0), 3.0))
	var bracket_contract := modules.contract(ATTACHMENT_BRACKET_M)
	if bracket_contract == null:
		return null
	# One complete 3 m wall bracket carries the bay. Its source pivot is at the
	# right/rear end, so the +1.5 m placement centres the authored -3..0 m run on
	# this bay and pins its measured top to the floor underside. The old pair of
	# generic wall braces crossed at the corners and read as protruding planks.
	recipe_value.add_placement(&"support.bracket", ATTACHMENT_BRACKET_M,
		_pose(centre + Vector3(1.5, -bracket_contract.visual_bounds.end.y,
			-1.5), 0.0))
	if bearing_drop_cells == 1:
		# A second authored course covers the half-level drop without scaling or
		# leaving a timber pole dangling below the projection.
		recipe_value.add_placement(&"support.bracket.low", ATTACHMENT_BRACKET_M,
			_pose(centre + Vector3(1.5,
				-bracket_contract.visual_bounds.end.y - CELL, -1.5), 0.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(2, 4, 2))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i(back_socket_x, -bearing_drop_cells, -1), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i(back_socket_x, 0, -1), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"bearing.front", FabricRecipe.SocketKind.BEARING,
		Vector3i(back_socket_x, 0, 0), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"room.front", FabricRecipe.SocketKind.ROOM,
		Vector3i(back_socket_x, 0, 0), Vector3i(0, 0, 1))
	return recipe_value


static func _embedded_oriel_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A true partial extrusion through the parent's facade plane. The former
	## construction used either a full-height room slice or a rotated dormer whose
	## source A-frame sprawled across the facade. Build the actual architectural
	## form: one paired half-width window face, two glazed return cheeks, a
	## sill/deck, a tiny window canopy, and two corbels. Pairing the authored
	## handed wall with its baked mirror puts one timber at each outside corner;
	## a single S panel always has a post on only one side and made the bay look
	## broken. The authored modules keep their UVs;
	## their construction transforms only shorten the bay below one storey and
	## keep its projection shallower than one fine cell.
	assert(theme in [&"blue", &"orange", &"amber"])
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"room", &"outcropping", &"overhead_occupied", &"shallow_bay",
		&"embedded_oriel", &"partial_extrusion", &"open_backed_bay",
		&"partial_height_bay", &"composed_window_bay",
		&"integrated_corbel_support", &"roofed_facade_bay",
	], 1)
	var window_asset := WALL_WOOD_WINDOW_S_BLUE
	var canopy_asset := WINDOW_ROOF_BLUE
	if theme == &"orange":
		window_asset = WALL_WOOD_WINDOW_S_ORANGE
		canopy_asset = WINDOW_ROOF_ORANGE
	elif theme == &"amber":
		window_asset = WALL_WOOD_WINDOW_S_AMBER
		canopy_asset = WINDOW_ROOF_ORANGE
	# This is a window-sized oriel, not a nearly full-storey room.  Half-height
	# keeps a 1.5 m authored window field while leaving an unmistakable band of
	# parent facade both below its sill and above its little roof.
	const BAY_HEIGHT_SCALE := 0.46
	# The feature origin is the centre of the exterior lattice cell. Its parent
	# facade is therefore at local Z = -0.75 m, not at zero. The previous recipe
	# treated zero as the wall plane and put the window at Z = -0.90 m: behind the
	# parent facade. Only the return cheeks projected outward, so every oblique
	# view read as a concave timber frame. Cross the parent seam by 3 cm, then run
	# one 0.90 m shallow box to the actual outer window plane. This is a convex
	# partial extrusion and remains well inside its one-cell reservation.
	const BAY_BACK_Z := -0.78
	const BAY_FRONT_Z := 0.12
	const BAY_CENTRE_Z := (BAY_BACK_Z + BAY_FRONT_Z) * 0.5
	const BAY_DEPTH_SCALE := (BAY_FRONT_Z - BAY_BACK_Z) / CELL
	const BAY_SILL_Y := 0.70
	const BAY_FACE_WIDTH_SCALE := 0.82
	# The authored S-window's terminal post is centred 0.615 m from the module
	# origin.  Scale that centre with the face instead of retaining its unscaled
	# coordinate: otherwise the added left jamb sits beside the authored timber,
	# thickens that corner, and widens the whole bay beyond its little canopy.
	const BAY_POST_CENTRE_X := 0.615 * BAY_FACE_WIDTH_SCALE
	# Return cheeks meet the scaled face envelope, not the original 1.5 m module
	# edges.  This keeps the oriel narrow and gives the canopy real drip coverage
	# on both sides.
	const BAY_FACE_EDGE_X := 0.75 * BAY_FACE_WIDTH_SCALE
	# Keep one normally proportioned authored window. Splitting two copies into
	# half-width panels squeezed their glazing and doubled every sill/header,
	# making the bay look like ornamental clutter instead of a small room volume.
	var face_pose := _scaled_pose(Vector3(0.0, BAY_SILL_Y, BAY_CENTRE_Z),
		0.0, Vector3(BAY_FACE_WIDTH_SCALE, BAY_HEIGHT_SCALE, 1.0))
	recipe_value.add_placement(&"bay.face", window_asset,
		modules.facade_aligned_transform(window_asset, face_pose,
			Vector3i.BACK, BAY_FRONT_Z))
	# The source facade owns only its left terminal post. Frame both edges with
	# the same pure timber jamb so its handed source geometry cannot leave one
	# heavy side and one absent side. The left jamb covers the authored post; the
	# right jamb supplies its exact reflected silhouette.
	for side in [-1, 1]:
		recipe_value.add_placement(StringName("bay.post.%s" % [
			"left" if side < 0 else "right"]), PORTAL_JAMB,
			_scaled_pose(Vector3(float(side) * BAY_POST_CENTRE_X, BAY_SILL_Y,
				BAY_FRONT_Z - 0.276), 0.0,
				Vector3(1.0, BAY_HEIGHT_SCALE, 1.0)))
	var mirrored_window := _mirrored_facade_asset(window_asset)
	for side: Dictionary in [
		{"id": &"bay.cheek.left", "x": -BAY_FACE_EDGE_X, "yaw": PI * 0.5,
			"outward": Vector3i.LEFT, "asset": mirrored_window},
		{"id": &"bay.cheek.right", "x": BAY_FACE_EDGE_X, "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT, "asset": window_asset},
	]:
		var side_asset := StringName(side.asset)
		# Scale in the cheek's authored local frame before yaw. Basis.scaled()
		# scales world rows, so using _scaled_pose here left the rotated wall at
		# its full 1.5 m length and buried 0.3 m behind the parent facade. The
		# local 60% course is the intended 0.9 m return between the real parent
		# boundary and the outer window face.
		# The S wall is 0.469 m thick. Leaving that full thickness on both
		# returns consumed almost two thirds of this 1.5 m-wide bay and produced
		# the huge one-sided C-shaped jamb in oblique views. Preserve its authored
		# length/UV face, but use a trim-depth shell at the two return planes.
		var cheek_basis := Basis(Vector3.UP, float(side.yaw)) \
			* Basis.from_scale(Vector3(BAY_DEPTH_SCALE, BAY_HEIGHT_SCALE, 0.30))
		var cheek_pose := Transform3D(cheek_basis,
			Vector3(float(side.x), BAY_SILL_Y, BAY_CENTRE_Z))
		recipe_value.add_placement(StringName(side.id), side_asset,
			modules.facade_aligned_transform(side_asset, cheek_pose,
				side.outward as Vector3i, float(side.x)))
	# The face module has real thickness outside BAY_FRONT_Z. Carry the sill and
	# canopy beneath/above that complete face, not merely beneath the return
	# cheeks; the latter left the window wall hanging off the front of its deck.
	# The deck source pivot is on its right edge. Shift it by half its authored
	# width so the sill sits under the bay instead of projecting 1.5 m to the left.
	var sill_pose := _scaled_pose(Vector3(0.75, 0.0, BAY_CENTRE_Z), 0.0,
		Vector3(1.0, 1.0, BAY_DEPTH_SCALE))
	recipe_value.add_placement(&"bay.sill", SETBACK_CAP,
		modules.walk_aligned_transform(SETBACK_CAP, sill_pose, BAY_SILL_Y))
	recipe_value.add_placement(&"bay.canopy", canopy_asset,
		_scaled_pose(Vector3(0.0, 2.15, BAY_CENTRE_Z), 0.0,
			Vector3(0.52, 0.42, 0.40)))
	# The brace source pivot sits at one end of its 1.94 m beam. Offset the two
	# mirrored instances back toward the bay centre so their visual centres land
	# beneath the sill corners; placing their pivots at the corners produced two
	# apparently detached planks projecting beyond the little bay.
	# No corbels under the sill: the ribbed brace reads as a stair flight hung
	# beneath the oriel. The sill and canopy carry the bay visually.
	# The grid conservatively owns the one exterior cell. The mesh deliberately
	# crosses its inward boundary (local Z = -0.75 m) through the semantic room
	# socket; only this declared parent seam may overlap the parent shell.
	recipe_value.solid_cells = FabricRecipe.box_cells(
		Vector3i.ZERO, Vector3i(1, 2, 1))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.FORWARD)
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i.ZERO, Vector3i.FORWARD)
	recipe_value.add_socket(&"bearing.front", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.BACK)
	recipe_value.add_socket(&"room.front", FabricRecipe.SocketKind.ROOM,
		Vector3i.ZERO, Vector3i.BACK)
	return recipe_value


static func _capped_outcrop_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram, minimum_x: int = -1,
		chimney_asset: StringName = &"") -> FabricRecipe:
	## Flat-capped shallow jetty: one cell deep, framed by the reviewed 1.5 m
	## side walls and symmetric corner posts, closed by the gallery deck module.
	## It reads as a jettied extension of the parent house, never as a second
	## building with its own roofline.
	assert(minimum_x == -1 or minimum_x == 0)
	var role_tags: Array[StringName] = [
		&"room", &"outcropping", &"overhead_occupied", &"capped_outcropping",
		&"shallow_bay", &"wood_walled_bay", &"corner_jetty",
	]
	var recipe_value := FabricRecipe.new(recipe_id, role_tags, 1)
	var wall := _wood_window(theme)
	var centre_x := (float(minimum_x) + 0.5) * FabricRecipe.CELL_SIZE
	var row_z := -1.5
	var front_plane := -0.75
	recipe_value.add_placement(&"front", wall,
		modules.facade_aligned_transform(wall,
			_pose(Vector3(centre_x, 0.0, row_z), 0.0),
			Vector3i.BACK, front_plane))
	for side: Dictionary in [
		{"id": &"left", "asset": WALL_WOOD_S_A, "x": -1.5, "yaw": PI * 0.5,
			"outward": Vector3i.LEFT},
		{"id": &"right", "asset": WALL_WOOD_S_B, "x": 1.5, "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT},
	]:
		var side_asset := StringName(side.asset)
		recipe_value.add_placement(StringName(side.id), side_asset,
			modules.facade_aligned_transform(side_asset,
				_pose(Vector3(centre_x, 0.0, row_z) \
					+ Vector3(float(side.x), 0.0, 0.0),
					float(side.yaw)), side.outward as Vector3i,
				centre_x + float(side.x)))
	# Symmetric corner posts frame the window from both sides; the earlier bay
	# left a lone trim strip on one corner only.
	for corner: Dictionary in [
		{"id": &"post.left", "x": -1.125}, {"id": &"post.right", "x": 1.125},
	]:
		recipe_value.add_placement(StringName(corner.id), WALL_WOOD_CORNER_S,
			_pose(Vector3(centre_x + float(corner.x), 0.0, front_plane - 0.35),
				0.0))
	# The cap is the reviewed 3 x 1.5 m gallery deck; its authored top snaps to
	# the storey boundary exactly like a street surface.
	recipe_value.add_placement(&"cap", GALLERY_FLOOR,
		modules.walk_aligned_transform(GALLERY_FLOOR,
			_pose(Vector3(centre_x, 3.0, row_z), 0.0), 3.0))
	# No ribbed braces under the jetty: they read as stairs from the street.
	if not chimney_asset.is_empty():
		# A flue standing on the bay's own deck, against the parent wall. It
		# claims no extra cell -- the bay's occupancy is untouched -- so the
		# only thing it changes is the silhouette this jetty cuts against the
		# sky, and the ordinary overhead transaction still refuses it wherever
		# the taller envelope will not fit.
		recipe_value.add_placement(&"chimney", chimney_asset,
			_pose(Vector3(centre_x, 3.0, row_z - 0.45), 0.0))
	_seal_shallow_bay_cells_and_sockets(recipe_value, minimum_x)
	return recipe_value


static func _dormer_outcrop_recipe(recipe_id: StringName,
		dormer_asset: StringName, warm: bool, modules: FabricModuleProgram,
		minimum_x: int = -1) -> FabricRecipe:
	## Single-piece attic-window bay. The authored dormer carries its own face,
	## cheeks, pitched or shed roof, and corbel feet; its deep tail frames
	## through the parent wall like the open-backed bay it replaces, so the
	## visible projection is one shallow module with a roof that matches the
	## parent's family.
	assert(minimum_x == -1 or minimum_x == 0)
	var role_tags: Array[StringName] = [
		&"room", &"outcropping", &"overhead_occupied", &"shallow_bay",
		&"dormer_bay", &"corner_jetty",
		&"warm_roof_bay" if warm else &"cool_roof_bay",
	]
	var recipe_value := FabricRecipe.new(recipe_id, role_tags, 1)
	var centre_x := (float(minimum_x) + 0.5) * FabricRecipe.CELL_SIZE
	var row_z := -1.5
	recipe_value.add_placement(&"dormer", dormer_asset,
		modules.facade_aligned_transform(dormer_asset,
			_pose(Vector3(centre_x, 0.0, row_z), 0.0),
			Vector3i.BACK, -0.75))
	# The authored dormer carries its own corbel feet; no ribbed braces below.
	_seal_shallow_bay_cells_and_sockets(recipe_value, minimum_x)
	return recipe_value


static func _corner_wrap_outcrop_recipe(recipe_id: StringName,
		theme: StringName, modules: FabricModuleProgram,
		hand: int) -> FabricRecipe:
	## Full room-scale diagonal union: a theoretical 3 m square is shifted across
	## the parent's 3 m square so they share one 1.5 m quadrant. That shared
	## quadrant remains entirely the parent's authored shell; this recipe emits
	## only the exposed L-shaped room body, two 3 m window faces, two 1.5 m return
	## cheeks, and the exterior-only roof. There is no second complete room mesh
	## or duplicate texture surface inside the structural overlap.
	assert(hand == -1 or hand == 1)
	# Not a generic capped_outcropping: two opposed, end-trimmed tiled pitches
	# close the shifted room crown without the crossing fascias that made the old
	# four-awning composition look concave from above.
	var role_tags: Array[StringName] = [
		&"room", &"outcropping", &"overhead_occupied", &"corner_wrap_bay",
		&"wood_walled_bay", &"corner_jetty",
		&"full_scale_diagonal_overlap", &"compound_union_shell",
		&"no_duplicate_overlap_shell", &"exterior_only_union_roof",
		&"low_gabled_corner_union", &"joined_corner_return",
	]
	var recipe_value := FabricRecipe.new(recipe_id, role_tags, 1)
	var wall := _wood_window(theme)
	var sign_x := float(hand)
	var square_centre_x := sign_x * 0.75
	# Outer long faces: one across both z rows on the outer x side, one across
	# both x columns on the north side.
	recipe_value.add_placement(&"face.north", wall,
		modules.facade_aligned_transform(wall,
			_pose(Vector3(square_centre_x, 0.0, -1.5), 0.0),
			Vector3i.FORWARD, -2.25))
	recipe_value.add_placement(&"face.outer", wall,
		modules.facade_aligned_transform(wall,
			_pose(Vector3(sign_x * 1.5, 0.0, -0.75), sign_x * PI * 0.5),
			Vector3i(hand, 0, 0), sign_x * 2.25))
	# Short cheeks close the L's inner notch back to the parent faces.
	recipe_value.add_placement(&"cheek.west", WALL_WOOD_S_A,
		modules.facade_aligned_transform(WALL_WOOD_S_A,
			_pose(Vector3(-sign_x * 0.0, 0.0, -1.5), -sign_x * PI * 0.5),
			Vector3i(-hand, 0, 0), -sign_x * 0.75))
	recipe_value.add_placement(&"cheek.south", WALL_WOOD_S_B,
		modules.facade_aligned_transform(WALL_WOOD_S_B,
			_pose(Vector3(sign_x * 1.5, 0.0, 0.0), PI),
			Vector3i.BACK, 0.75))
	recipe_value.add_placement(&"post.outer", WALL_WOOD_CORNER_S,
		_pose(Vector3(sign_x * 1.95, 0.0, -1.95), 0.0))
	# The source lean-to is 1.55 m deep. Opposing copies therefore cover the
	# theoretical 3 m shifted square without scaling. Their decorative upturned
	# end boards are removed by the reviewed derivative. The source high edge is
	# at local Z=-0.84278 m, so these origins put both high edges on Z=-1.5
	# exactly: no overlap, daylight gap, or oversized generic ridge cap. The roof
	# overlaps only the shared parent's exterior quarter; no second shell or flat
	# tabletop is emitted inside that structural union.
	var roof_asset := WINDOW_ROOF_BLUE_TRIMMED if theme == &"blue" \
		else WINDOW_ROOF_ORANGE_TRIMMED
	var roof_origin_y := 3.40
	recipe_value.add_placement(&"roof.pitch.north", roof_asset,
		_pose(Vector3(square_centre_x, roof_origin_y, -2.34278), PI))
	recipe_value.add_placement(&"roof.pitch.south", roof_asset,
		_pose(Vector3(square_centre_x, roof_origin_y, -0.65722), 0.0))
	# No ribbed braces under the wrap: they read as stairs hung under the room.
	# Solid cells stay the two-band exterior room body. The shallow eaves add no
	# fictitious full-band volume above the occupied room.
	recipe_value.solid_cells = [
		Vector3i(0, 0, -1), Vector3i(0, 1, -1),
		Vector3i(hand, 0, -1), Vector3i(hand, 1, -1),
		Vector3i(hand, 0, 0), Vector3i(hand, 1, 0),
	]
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 0, -1), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i(0, 0, -1), Vector3i(0, 0, -1))
	return recipe_value


static func _seal_shallow_bay_cells_and_sockets(recipe_value: FabricRecipe,
		minimum_x: int) -> void:
	recipe_value.solid_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(2, 2, 1))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 0, -1), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i(0, 0, -1), Vector3i(0, 0, -1))
	recipe_value.add_socket(&"bearing.front", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 0, -1), Vector3i(0, 0, 1))
	recipe_value.add_socket(&"room.front", FabricRecipe.SocketKind.ROOM,
		Vector3i(0, 0, -1), Vector3i(0, 0, 1))


static func _micro_room_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## Narrow two-bay terrain house used where a complete 6 m room cannot close a
	## winding street without colliding with its next turn. It remains a real
	## four-sided building with a floor and roof, never a proxy wall inserted to
	## game the frontage audit.
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"room", &"generated_building", &"terrain_bearing", &"micro_building",
	], 0)
	var wall := _wood_window(theme)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2), Vector3i(2, 1, 4))
	for index in 2:
		var z_offset := -1.5 + float(index) * 3.0
		recipe_value.add_placement(StringName("floor.%d" % index), FLOOR,
			modules.walk_aligned_transform(FLOOR,
				_pose(centre + Vector3(0.0, 0.0, z_offset), 0.0), 0.0))
	recipe_value.add_placement(&"south", WOOD_DOOR,
		modules.facade_aligned_transform(WOOD_DOOR,
			_pose(centre + Vector3(0.0, 0.0, 3.0), 0.0),
			Vector3i.BACK, centre.z + 3.0))
	recipe_value.add_placement(&"north", wall,
		modules.facade_aligned_transform(wall,
			_pose(centre + Vector3(0.0, 0.0, -3.0), PI),
			Vector3i.FORWARD, centre.z - 3.0))
	for index in 2:
		var z_offset := -1.5 + float(index) * 3.0
		var side_asset := _mirrored_facade_asset(wall)
		recipe_value.add_placement(StringName("west.%d" % index), side_asset,
			modules.facade_aligned_transform(side_asset,
				_pose(centre + Vector3(-1.5, 0.0, z_offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 1.5))
		recipe_value.add_placement(StringName("east.%d" % index), side_asset,
			modules.facade_aligned_transform(side_asset,
				_pose(centre + Vector3(1.5, 0.0, z_offset), -PI * 0.5),
				Vector3i.RIGHT, centre.x + 1.5))
	var roof_asset := ROOF_ORANGE if theme == &"orange" else ROOF_BLUE
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		centre, 3.0, PI * 0.5, 3.0))
	# A visible door is an access contract, not decoration. The former micro
	# recipe filled its complete lattice envelope with SOLID cells and declared no
	# entrance, so a search could use it to close frontage while producing a
	# house that no public path actually served. Keep one rear corner pier and
	# make the remaining narrow/deep volume honest headroom; the reviewed door is
	# part of the same public-address contract as every larger house.
	var pier_xz := Vector2i(-1, -2)
	var door_cell := Vector3i(0, 0, 1)
	for y in 2:
		for z in range(-2, 2):
			for x in range(-1, 1):
				var cell := Vector3i(x, y, z)
				var doorway := x == door_cell.x and z == door_cell.z
				if x == pier_xz.x and z == pier_xz.y:
					recipe_value.solid_cells.append(cell)
				elif not doorway:
					recipe_value.headroom_cells.append(cell)
				if not doorway:
					recipe_value.occluder_cells.append(cell)
	for y in 2:
		recipe_value.headroom_cells.append(Vector3i(door_cell.x, y,
			door_cell.z))
	recipe_value.add_entrance(&"front", door_cell, Vector3i.BACK)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.ROOM,
		&"room", 0, Vector3i(-1, 0, -2), 2, 4)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing", 0, Vector3i(-1, 0, -2), 2, 4)
	_set_terrain_bearing_rect(recipe_value, Vector3i(-1, 0, -2),
		Vector3i(2, 1, 4))
	return recipe_value


static func _skywalk_recipe(recipe_id: StringName, segments: int,
		theme: StringName, modules: FabricModuleProgram,
		bearing_parent_count: int) -> FabricRecipe:
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"room", &"skywalk", &"interior_walk", &"overhead_occupied"],
		bearing_parent_count)
	var length_cells := segments * 2
	var minimum_x := -length_cells / 2
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 1, 2))
	var wall := _wood_window(theme)
	for segment in segments:
		var x := (float(segment) - float(segments - 1) * 0.5) * 3.0
		recipe_value.add_placement(StringName("floor.%d" % segment), FLOOR,
			modules.walk_aligned_transform(FLOOR,
				_pose(centre + Vector3(x, 0.0, 0.0), 0.0), 0.0))
		recipe_value.add_placement(StringName("wall.n.%d" % segment), wall,
			modules.facade_aligned_transform(wall,
				_pose(centre + Vector3(x, 0.0, -1.5), 0.0),
				Vector3i.FORWARD, centre.z - 1.5))
		recipe_value.add_placement(StringName("wall.s.%d" % segment), wall,
			modules.facade_aligned_transform(wall,
				_pose(centre + Vector3(x, 0.0, 1.5), PI),
				Vector3i.BACK, centre.z + 1.5))
	# The full floor module owns the logical walk cells, but its beveled end trim
	# stops visibly short of the adjacent room shell. Small authored deck pieces
	# straddle the two typed ROOM seams so an open portal always has a tangible
	# threshold underfoot. They overlap only the connected room/corner lineage.
	var maximum_x := minimum_x + length_cells - 1
	for end: Dictionary in [
		{"id": &"west", "x": (float(minimum_x) - 0.5) * CELL},
		{"id": &"east", "x": (float(maximum_x) + 0.5) * CELL},
	]:
		var threshold_pose := _pose(Vector3(float(end.x), 0.0, centre.z), 0.0)
		recipe_value.add_placement(StringName("threshold.%s" % String(end.id)),
			SETBACK_CAP, modules.walk_aligned_transform(SETBACK_CAP,
				threshold_pose, 0.0))
	# A bridge-house is only 3 m wide. The ordinary SFV repeat gable spans 6.49 m
	# and its eaves clear away an entire neighboring facade on each side, which
	# makes several skywalks incompatible with a dense town. Repeat complete LPFV
	# compact roofs instead: every 3 m bay remains pitched, gable-closed, unscaled,
	# and visually articulated, while its measured envelope matches the tunnel.
	var compact_roof := COMPACT_ROOF_SLATE_03 if theme == &"blue" \
		else COMPACT_ROOF_06
	for segment in segments:
		var roof_x := (float(segment) - float(segments - 1) * 0.5) * 3.0
		recipe_value.add_placement(StringName("roof.%d" % segment),
			compact_roof, modules.roof_bearing_aligned_transform(compact_roof,
				_pose(centre + Vector3(roof_x, 3.0, 0.0), PI * 0.5), 3.0))
	recipe_value.walk_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 1, 2))
	recipe_value.headroom_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 2, 2))
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.solid_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 2, -1), Vector3i(length_cells, 2, 2))
	recipe_value.occluder_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 4, 2))
	recipe_value.add_socket(&"room.west", FabricRecipe.SocketKind.ROOM,
		Vector3i(minimum_x, 0, 0), Vector3i(-1, 0, 0))
	recipe_value.add_socket(&"room.east", FabricRecipe.SocketKind.ROOM,
		Vector3i(maximum_x, 0, 0), Vector3i(1, 0, 0))
	recipe_value.add_socket(&"bearing.west", FabricRecipe.SocketKind.BEARING,
		Vector3i(minimum_x, 0, 0), Vector3i(-1, 0, 0))
	recipe_value.add_socket(&"bearing.east", FabricRecipe.SocketKind.BEARING,
		Vector3i(maximum_x, 0, 0), Vector3i(1, 0, 0))
	return recipe_value


static func _balcony_recipe(recipe_id: StringName, theme: StringName,
		back_socket_x: int, modules: FabricModuleProgram,
		decorated: bool = false, depth_cells: int = 1,
		diagonal_support: bool = false) -> FabricRecipe:
	## One complete 6 m-wide occupied balcony. A 3 m deck forced the 1.5 m doorway
	## into one of its two halves, which left a side railing's terminal post on the
	## threshold even when the doorway's facade edge was correctly unguarded. The
	## four-cell platform puts the door in an inner bay and leaves at least one
	## whole cell of lateral clearance to either side rail. Compact fallback
	## recipes are 1.5 m deep; the preferred walkouts are 3 m deep so the outer
	## guard reads as a perimeter instead of a fence across the doorway. The front
	## guard is centred on one uninterrupted 3 m rail; its two joins sit at the
	## outer quarter points rather than putting a terminal post on the door axis.
	## The logical cells are exterior private walk/headroom, while continuous reviewed deck runs, every
	## exposed rail, and the selected support course are one atomic measured
	## construction. The parent room's finite
	## feature-portal variant owns the open doorway; placing another wall module
	## here would merely paste an arch over the room's still-closed facade. Left
	## and right attachment variants shift the room socket without changing the
	## usable floor, allowing a facade to stagger balconies instead of extruding
	## the same coordinate through every storey.
	assert(back_socket_x in [-1, 0] and depth_cells in [1, 2])
	assert(not diagonal_support or depth_cells == 2)
	var tags: Array[StringName] = [
		&"balcony", &"private_walk", &"exterior_occupied_floor",
		&"bracket_supported", &"requires_room_portal",
		&"overhead_occupied", theme,
	]
	if depth_cells == 2:
		tags.append(&"deep_walkout")
	if diagonal_support:
		tags.append(&"diagonal_support")
	var recipe_value := FabricRecipe.new(recipe_id, tags, 1)
	var deck_cells: Array[Vector3i] = []
	for z in depth_cells:
		for x in [-2, -1, 0, 1]:
			deck_cells.append(Vector3i(x, 0, z))
		# Two native 3 m gallery pieces span the 6 m facade. Adjacent width and
		# depth runs meet on their authored edges and never scale or overlap.
		for width_half in 2:
			var floor_x := (-1.5 + float(width_half) * 2.0) * CELL
			recipe_value.add_placement(StringName("floor.%d.%d" % [z,
					width_half]), GALLERY_FLOOR,
				modules.walk_aligned_transform(GALLERY_FLOOR,
					_pose(Vector3(floor_x, 0.0, float(z) * CELL), 0.0),
					0.0))
	# One 3 m centre run and two 1.5 m end runs close the same exact 6 m edge.
	# Joining two medium runs put their doubled terminal post on the facade's
	# central sightline: it was safely three metres from a deep-walkout threshold
	# but still read as a fence post directly in front of the door. The new seams
	# are at the outer quarter points, leaving uninterrupted horizontal rails (and
	# no post) across either handed doorway axis without opening the perimeter.
	var front_z := (float(depth_cells) - 0.5) * CELL
	recipe_value.add_placement(&"guard.front.centre", RAILING_MEDIUM,
		_pose(Vector3(-CELL * 0.5, 0.0, front_z), 0.0))
	recipe_value.add_placement(&"guard.front.left", RAILING,
		_pose(Vector3(-CELL * 2.0, 0.0, front_z), 0.0))
	recipe_value.add_placement(&"guard.front.right", RAILING,
		_pose(Vector3(CELL, 0.0, front_z), 0.0))
	# Both end runs close every exposed depth cell. The parent facade is the only
	# unguarded edge and contains the exact portal selected with this feature.
	for z in depth_cells:
		recipe_value.add_placement(StringName("guard.left.%d" % z), RAILING,
			_pose(Vector3(-CELL * 2.5, 0.0, float(z) * CELL), -PI * 0.5))
		recipe_value.add_placement(StringName("guard.right.%d" % z), RAILING,
			_pose(Vector3(CELL * 1.5, 0.0, float(z) * CELL), -PI * 0.5))
	if diagonal_support:
		var support_contract := modules.contract(DIAGONAL_BRACE)
		assert(support_contract != null)
		var support_bounds := support_contract.visual_bounds
		for index in 4:
			var brace_x := float(index - 2) * CELL
			recipe_value.add_placement(StringName("support.diagonal.%d" % index),
				DIAGONAL_BRACE, _pose(Vector3(brace_x, -support_bounds.end.y,
					-support_bounds.position.z), 0.0))
	# The bracketed variant carries no ribbed corbels: from the street they read
	# as a row of stair flights hung under the deck. The deck's authored
	# thickness against the parent facade is its visible bearing.
	if decorated:
		# Decoration is a separate measured construction variant. This prevents
		# plants from silently widening the long-standing structural balcony
		# contract used by older sectional fixtures, while production can prefer
		# this richer version wherever its complete envelope fits.
		# Keep decoration in the outer bay opposite the door rather than narrowing
		# the threshold that this wider construction was introduced to protect.
		var planter_x := -3.0 if back_socket_x == 0 else 1.35
		recipe_value.add_placement(&"balcony.planter", ROOF_PLANTER,
			_pose(Vector3(planter_x, 0.04, 0.26), 0.0))
		var balcony_flower := ROOF_FLOWER_TALL if theme == &"blue" \
			else TERRACE_PLANT_BROAD if theme == &"amber" \
			else ROOF_FLOWER_PALE
		recipe_value.add_placement(&"balcony.flowers", balcony_flower,
			_pose(Vector3(planter_x + 0.12, 0.04, 0.20), 0.0))
		recipe_value.role_tags.append(&"planted_balcony")
	recipe_value.walk_cells.assign(deck_cells)
	recipe_value.headroom_cells = FabricRecipe.box_cells(
		Vector3i(-2, 0, 0), Vector3i(4, 2, depth_cells))
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i(back_socket_x, 0, 0), Vector3i.FORWARD)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i(back_socket_x, 0, 0), Vector3i.FORWARD)
	return recipe_value


static func _wrap_balcony_recipe(recipe_id: StringName, theme: StringName,
		side: int, modules: FabricModuleProgram) -> FabricRecipe:
	## A true L-shaped corner balcony with one explicit full-storey switchback
	## stair. The door opens onto a three-cell-deep landing before the walk turns
	## to the stair and the side return. This keeps the outer guard a full 4.5 m
	## from the threshold instead of making it read as a fence across the door.
	## Production
	## admits the recipe only when that stair's low terminus lands on an existing
	## PUBLIC_FLOOR. Thus neither a rail nor a decorative support can masquerade
	## as circulation, and both ends of the authored flight meet real platforms.
	assert(side in [-1, 1])
	var corner_x := side
	var front_cells: Array[Vector3i] = [
		Vector3i.ZERO, Vector3i(corner_x, 0, 0),
		Vector3i(0, 0, 1), Vector3i(corner_x, 0, 1),
		Vector3i(0, 0, 2),
	]
	var deck_cells: Array[Vector3i] = front_cells.duplicate()
	deck_cells.append(Vector3i(corner_x, 0, -1))
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"balcony", &"wraparound_balcony", &"private_walk",
		&"exterior_occupied_floor", &"bracket_supported",
		&"requires_room_portal", &"overhead_occupied", &"planted_balcony",
		theme,
	], 1)
	var deck_set: Dictionary = {}
	for cell: Vector3i in deck_cells:
		deck_set[cell] = true
	# Two landing rows are native 3 m plank constructions. One native half-width
	# cap extends only the doorway's circulation line for the third row; the side
	# remains compact enough to compose inside dense fabric.
	recipe_value.add_placement(&"floor.front.inner", GALLERY_FLOOR,
		modules.walk_aligned_transform(GALLERY_FLOOR,
			_pose(Vector3(float(side) * CELL * 0.5, 0.0, 0.0), 0.0), 0.0))
	recipe_value.add_placement(&"floor.front.outer", GALLERY_FLOOR,
		modules.walk_aligned_transform(GALLERY_FLOOR,
			_pose(Vector3(float(side) * CELL * 0.5, 0.0, CELL), 0.0), 0.0))
	recipe_value.add_placement(&"floor.door.throat", SETBACK_CAP,
		modules.walk_aligned_transform(SETBACK_CAP,
			_pose(Vector3(0.0, 0.0, CELL * 2.0), 0.0), 0.0))
	var return_pose := _pose(Vector3(float(side) * CELL + CELL * 0.5,
		0.0, -CELL), 0.0)
	recipe_value.add_placement(&"floor.return", SETBACK_CAP,
		modules.walk_aligned_transform(SETBACK_CAP, return_pose, 0.0))
	var parent_edges: Dictionary = {}
	# Both cells in the 3 m inner row terminate against the parent facade.  The
	# former recipe opened only the exact socket cell and then emitted a railing
	# along the neighboring half of that same wall.  Its terminal post landed in
	# the authored arch's clear approach, so the door looked fenced off even
	# though the topology called the threshold open.  The building is already the
	# guard on this entire edge; keep both facade halves free of rails and posts.
	for parent_cell: Vector3i in [Vector3i.ZERO,
			Vector3i(corner_x, 0, 0)]:
		parent_edges[WarrenSpatialGrid._face_key(parent_cell,
			Vector3i.FORWARD)] = true
	var side_cell := Vector3i(corner_x, 0, -1)
	var side_to_room := Vector3i.RIGHT if side < 0 else Vector3i.LEFT
	parent_edges[WarrenSpatialGrid._face_key(side_cell, side_to_room)] = true
	# Preset 003 is a 3 m-wide, fully guarded switchback envelope, not a
	# two-lane straight
	# flight. Its low tread is on one half and its high tread returns on the
	# opposite half. These sockets name those actual tread centres.
	var stair_high_cell := Vector3i(corner_x, 0, 1 if side > 0 else 0)
	var stair_outward := Vector3i(side, 0, 0)
	var stair_open_edges: Dictionary = {}
	stair_open_edges[WarrenSpatialGrid._face_key(stair_high_cell,
		stair_outward)] = true
	var guard_index := 0
	for cell: Vector3i in deck_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if deck_set.has(cell + direction) or parent_edges.has(
					WarrenSpatialGrid._face_key(cell, direction)) \
					or stair_open_edges.has(WarrenSpatialGrid._face_key(cell,
						direction)):
				continue
			var edge_centre := Vector3(float(cell.x) * CELL,
				0.0, float(cell.z) * CELL) + Vector3(direction) * CELL * 0.5
			var yaw := -PI * 0.5 if direction.x != 0 else 0.0
			recipe_value.add_placement(StringName("guard.%02d" % guard_index),
				RAILING, _pose(edge_centre, yaw))
			guard_index += 1
	# Rotate the authored switchback so its high tread meets the one-cell guard
	# opening and its low tread lands on the public route one storey below. The
	# transform's two half-width phases are intentional: they align the actual
	# low/high treads rather than the decorative handrail's total AABB.
	var stair_low_cell := Vector3i(corner_x + side * 2, -2,
		0 if side > 0 else 1)
	var stair_frame := _pose(Vector3(float(corner_x + side * 2) * CELL,
		float(stair_low_cell.y) * CELL, 0.0), float(side) * PI * 0.5)
	var corridor_minimum_x := 0 if side < 0 else -1
	var stair_lanes := modules.stair_lane_transforms(STAIR_FULL,
		corridor_minimum_x, 2)
	assert(stair_lanes.size() == 1)
	var stair_placement := stair_frame * stair_lanes[0]
	stair_placement = modules.stair_high_aligned_transform(STAIR_FULL,
		stair_placement, 0.0)
	recipe_value.add_placement(&"stair.flight", STAIR_FULL, stair_placement)
	# Two complete one-storey pillars carry the outer corner to the same lower
	# datum as the switchback's real public landing.  The former diagonals were
	# attached on the doorway centreline; although their tops met the deck, their
	# feet ended against empty air whenever that facade stepped back.  Put both
	# vertical load paths under actual deck cells on the return side, away from
	# both the door throat and the stair's high-tread opening.
	var support_contract := modules.contract(DECK_PILLAR)
	assert(support_contract != null)
	var support_cells: Array[Vector3i] = [
		Vector3i(corner_x, -2, -1),
		Vector3i(corner_x, -2, 0 if side > 0 else 1),
	]
	for index in support_cells.size():
		var support_cell := support_cells[index]
		var support_pose := _pose(Vector3(float(support_cell.x) * CELL,
			float(support_cell.y) * CELL, float(support_cell.z) * CELL), 0.0)
		recipe_value.add_placement(StringName("support.pillar.%d" % index),
			DECK_PILLAR, support_pose)
	var planter_x := float(corner_x) * CELL
	recipe_value.add_placement(&"balcony.planter", ROOF_PLANTER,
		_pose(Vector3(planter_x, 0.04, -CELL), 0.0))
	var balcony_flower := ROOF_FLOWER_TALL if theme == &"blue" \
		else TERRACE_PLANT_BROAD if theme == &"amber" else ROOF_FLOWER_PALE
	recipe_value.add_placement(&"balcony.flowers", balcony_flower,
		_pose(Vector3(planter_x, 0.04, -CELL), 0.0))
	recipe_value.walk_cells.assign(deck_cells)
	for cell: Vector3i in deck_cells:
		recipe_value.headroom_cells.append(cell)
		recipe_value.headroom_cells.append(cell + Vector3i.UP)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i.ZERO, Vector3i.FORWARD)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.FORWARD)
	recipe_value.add_socket(&"stair.high", FabricRecipe.SocketKind.WALK,
		stair_high_cell, stair_outward)
	recipe_value.add_socket(&"stair.low", FabricRecipe.SocketKind.WALK,
		stair_low_cell, stair_outward)
	return recipe_value


static func _integrated_cantilever_support_recipe(
		modules: FabricModuleProgram) -> FabricRecipe:
	## One measured 3 m bracket course beneath a room-scale jetty. The parent
	## room remains the occupied construction authority; this zero-cell recipe is
	## an explicit visual/collision attachment derived from the sealed bearing
	## edge. A single broad attachment bracket hid its diagonal detail at skyline
	## distance and read as a loose horizontal plank. Use one native wall corbel
	## per bearing column instead. Each corbel projects along local BACK (the
	## solver's typed cantilever direction), never sideways beyond a corner, and
	## its measured top is pinned to the room underside. The measured two-piece
	## envelope still participates in the ordinary feature-clearance proof.
	var contract_value := modules.contract(BRACE)
	if contract_value == null:
		return null
	var bounds := contract_value.visual_bounds
	# The support course is a sealed attachment the compiler still proves and
	# audits once per bearing edge, but it renders NOTHING: the ribbed corbel it
	# used to place read as a flight of stairs hung under the jetty. It declares
	# exactly the envelope those two corbels occupied, so the feature-clearance
	# proof keeps the same input.
	var recipe_value := FabricRecipe.new(&"outcrop.support.bracketed.2", [
		&"visual_attachment", &"cantilever_support", &"bracket_supported",
		&"integrated_room_outcropping", &"paired_wall_corbels",
	], 0)
	var envelope := AABB()
	for column_index in 2:
		var box: AABB = _pose(Vector3(float(column_index) * CELL,
			-bounds.end.y, 0.0), PI * 0.5) * bounds
		envelope = box if column_index == 0 else envelope.merge(box)
	assert(recipe_value.set_local_clearance_bounds(envelope))
	return recipe_value


static func _integrated_cantilever_diagonal_support_recipe(
		modules: FabricModuleProgram) -> FabricRecipe:
	## A visually load-bearing alternative for a cantilever whose underside does
	## not contain public circulation. The reviewed support has its upright on
	## local -Z, its diagonal foot on local +Z, and its top at measured AABB end
	## Y. Pin those authored datums to the parent facade and room underside. This
	## is intentionally a separate recipe: a tunnel may retain the shallow
	## bracket without pretending that a 3.6 m post can pass through public air.
	var contract_value := modules.contract(DIAGONAL_BRACE)
	if contract_value == null:
		return null
	var bounds := contract_value.visual_bounds
	var recipe_value := FabricRecipe.new(&"outcrop.support.diagonal.2", [
		&"visual_attachment", &"cantilever_support", &"diagonal_support",
		&"bracket_supported", &"integrated_room_outcropping",
	], 0)
	for index in 2:
		recipe_value.add_placement(StringName("brace.%d" % index),
			DIAGONAL_BRACE, _pose(Vector3(float(index) * CELL,
				-bounds.end.y, -bounds.position.z), 0.0))
	return recipe_value


static func _integrated_cantilever_terminal_support_recipe(
		modules: FabricModuleProgram) -> FabricRecipe:
	## Odd 4.5/7.5 m bearing edges tile as native 3 m courses plus this final
	## unscaled brace. It is a measured terminal, not a half-width scaled copy.
	var contract_value := modules.contract(BRACE)
	if contract_value == null:
		return null
	var recipe_value := FabricRecipe.new(&"outcrop.support.bracketed.1", [
		&"visual_attachment", &"cantilever_support", &"bracket_supported",
		&"integrated_room_outcropping", &"terminal_support",
	], 0)
	# Sealed and audited like the paired course, and equally invisible.
	assert(recipe_value.set_local_clearance_bounds(
		_pose(Vector3(0.0, -0.55, 0.0), PI * 0.5) \
			* contract_value.visual_bounds))
	return recipe_value


static func _integrated_cantilever_terminal_diagonal_support_recipe(
		modules: FabricModuleProgram) -> FabricRecipe:
	var contract_value := modules.contract(DIAGONAL_BRACE)
	if contract_value == null:
		return null
	var bounds := contract_value.visual_bounds
	var recipe_value := FabricRecipe.new(&"outcrop.support.diagonal.1", [
		&"visual_attachment", &"cantilever_support", &"diagonal_support",
		&"bracket_supported", &"integrated_room_outcropping",
		&"terminal_support",
	], 0)
	recipe_value.add_placement(&"brace.0", DIAGONAL_BRACE,
		_pose(Vector3(0.0, -bounds.end.y, -bounds.position.z), 0.0))
	return recipe_value


static func arcade_overhang_foundation_recipe_id(open_mask: int) -> StringName:
	assert(open_mask > 0 and (open_mask & ~FEATURE_PORTAL_MASK_ALL) == 0)
	return StringName("overhang.support.arcade.rock.%x" % open_mask)


static func _arcade_overhang_foundation_recipe(open_mask: int,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The unsupported half of a tower-to-row/slim transition is a borne arcade,
	## not one facade floating beneath a room.  A 3 m masonry arch puts its jambs
	## on the centres of the two 1.5 m public lanes it is meant to protect; four
	## such wall panels therefore leave a visually plausible slit but invalidate
	## the route graph.  Use the reviewed one-storey support post at each exact
	## corner of the upper plate instead.  Their measured 0.28 x 0.59 m bases stay
	## outside both body lanes, while the complete four-corner frame transfers the
	## overhang to the lower course.  `open_mask` still identifies the topological
	## route continuation in the stable recipe id, but geometry no longer invents
	## a closed wall around that already-proved public air.
	var recipe_value := FabricRecipe.new(
		arcade_overhang_foundation_recipe_id(open_mask), [
		&"visual_attachment", &"cantilever_support", &"arcade_portal_support",
		&"route_spanning_overhang", &"four_corner_support_frame",
	], 0)
	var pillar_contract := modules.contract(DECK_PILLAR)
	if pillar_contract == null:
		return null
	var pillar_bounds := pillar_contract.visual_bounds
	var pillar_half_x := maxf(absf(pillar_bounds.position.x),
		absf(pillar_bounds.end.x))
	var pillar_half_z := maxf(absf(pillar_bounds.position.z),
		absf(pillar_bounds.end.z))
	# The logical portal boundary is a construction limit, not a post centreline.
	# Keeping each measured post wholly inside it fixes the old corner condition
	# where half a pillar occupied the neighboring house/roof envelope. The
	# authored reveal is capped by the exact radial clearance left between the
	# post's measured inner corner and the centre of either 1.5 m body lane. Thus
	# a changed pillar, player capsule, or import bound recomputes the frame; no
	# seed, town, or reported collision cell participates in construction.
	var lane_clearance_x := CELL * 0.5 - pillar_bounds.size.x
	var lane_clearance_z := CELL * 0.5 - pillar_bounds.size.z
	var required_radius := TraversalEnvelope.structural_clearance_radius()
	var clearance_discriminant := 2.0 * required_radius * required_radius \
		- pow(lane_clearance_x - lane_clearance_z, 2.0)
	if clearance_discriminant < 0.0:
		return null
	var maximum_reveal := (lane_clearance_x + lane_clearance_z \
		- sqrt(clearance_discriminant)) * 0.5
	if maximum_reveal < 0.0:
		return null
	var edge_reveal := minf(CELL * 0.05, maximum_reveal)
	var corner_x := CELL - pillar_half_x - edge_reveal
	var corner_z := CELL - pillar_half_z - edge_reveal
	assert(Vector2(lane_clearance_x - edge_reveal,
		lane_clearance_z - edge_reveal).length() + 0.000001 \
		>= required_radius)
	var centre := Vector3(CELL * 0.5, -CELL * 2.0, CELL * 1.5)
	for corner: Dictionary in [
		{"id": &"north_west", "offset": Vector3(-corner_x, 0.0, -corner_z)},
		{"id": &"north_east", "offset": Vector3(corner_x, 0.0, -corner_z)},
		{"id": &"south_east", "offset": Vector3(corner_x, 0.0, corner_z)},
		{"id": &"south_west", "offset": Vector3(-corner_x, 0.0, corner_z)},
	]:
		recipe_value.add_placement(StringName(corner.id), DECK_PILLAR,
			_pose(centre + corner.offset as Vector3, 0.0))
	return recipe_value


static func _skywalk_corner_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## A finite 3 m orthogonal tunnel knuckle. Two one-bearing tunnel arms form
	## an L as a strict support chain (building -> arm -> corner -> arm), while
	## the final arm also meets the destination facade. No diagonal transform or
	## uninhabited suspended platform is required.
	assert(theme in [&"blue", &"orange"])
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"room", &"skywalk", &"skywalk_corner", &"interior_walk",
			&"overhead_occupied"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	recipe_value.add_placement(&"floor", FLOOR,
		modules.walk_aligned_transform(FLOOR, _pose(centre, 0.0), 0.0))
	# A compact complete pitched shell fits the 3 m corner knuckle without the
	# 6.5 m eave span of the ordinary modular gable. This keeps the right-angle
	# tunnel roofed while preserving its two orthogonal attachment seams.
	var compact_roof := COMPACT_ROOF_SLATE_03 if theme == &"blue" \
		else COMPACT_ROOF_06
	recipe_value.add_placement(&"roof", compact_roof,
		modules.roof_bearing_aligned_transform(compact_roof,
			_pose(centre + Vector3.UP * 3.0, 0.0), 3.0))
	for side: Dictionary in [
		{"id": &"south", "offset": Vector3(0, 0, 1.5), "yaw": 0.0,
			"outward": Vector3i.BACK, "boundary": centre.z + 1.5},
		{"id": &"north", "offset": Vector3(0, 0, -1.5), "yaw": PI,
			"outward": Vector3i.FORWARD, "boundary": centre.z - 1.5},
		{"id": &"west", "offset": Vector3(-1.5, 0, 0), "yaw": PI * 0.5,
			"outward": Vector3i.LEFT, "boundary": centre.x - 1.5},
		{"id": &"east", "offset": Vector3(1.5, 0, 0), "yaw": -PI * 0.5,
			"outward": Vector3i.RIGHT, "boundary": centre.x + 1.5},
	]:
		var wall_asset := _mirrored_facade_asset(WOOD_DOOR) \
			if (side.outward as Vector3i).x != 0 else WOOD_DOOR
		recipe_value.add_placement(StringName(side.id), wall_asset,
			modules.facade_aligned_transform(wall_asset,
				_pose(centre + side.offset as Vector3, float(side.yaw)),
				side.outward as Vector3i, float(side.boundary)))
	recipe_value.walk_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 2, 2))
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-1, 2, -1),
		Vector3i(2, 2, 2))
	recipe_value.occluder_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 4, 2))
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.ROOM,
		&"room", 0, Vector3i(-1, 0, -1), 2, 2)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.BEARING,
		&"bearing", 0, Vector3i(-1, 0, -1), 2, 2)
	return recipe_value


static func _market_recipe(recipe_id: StringName, asset_id: StringName) \
		-> FabricRecipe:
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"market", &"themed_stall", &"terrain_bearing"], 0)
	recipe_value.add_placement(&"stall", asset_id)
	# Occupancy follows the reviewed structural proxy: four posts below a
	# three-panel canopy. The browsable volume remains open instead of becoming
	# a prefab-sized forbidden box.
	for y in 2:
		for x in [-2, 1]:
			for z in [-1, 0]:
				recipe_value.solid_cells.append(Vector3i(x, y, z))
	recipe_value.solid_cells.append_array(FabricRecipe.box_cells(
		Vector3i(-2, 2, -1), Vector3i(4, 1, 2)))
	recipe_value.occluder_cells = FabricRecipe.box_cells(Vector3i(-2, 0, -1),
		Vector3i(4, 3, 2))
	recipe_value.add_socket(&"market.back", FabricRecipe.SocketKind.MARKET,
		Vector3i(-1, 0, -1), Vector3i(0, 0, -1))
	_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -1),
		Vector3i(4, 1, 2))
	return recipe_value


static func _covered_market_recipe(recipe_id: StringName,
		canopy_asset_id: StringName, table_asset_id: StringName,
		decorated: bool = false) -> FabricRecipe:
	## One exact 6 x 3 m covered bazaar. The stocked counter is rotated into the
	## west structural post bay, while hanging vegetables and a market wheel stock
	## the opposite canopy edge above player headroom. The two centre columns stay
	## a physically unobstructed 3 x 3 m public aisle. Canopy, posts, goods, aisle,
	## and backing socket remain one measured all-or-nothing transaction.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"market", &"covered_market", &"themed_stall", &"terrain_bearing"], 0)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -1), Vector3i(4, 1, 2))
	recipe_value.add_placement(&"canopy", canopy_asset_id,
		_pose(centre + Vector3(-0.25, 0.0, 0.0), 0.0))
	# The table's rotated 1.41 m depth fits the x=-2 structural column. Its east
	# edge is x=-2.24 m, outside the x=-1 aisle cell whose west seam is -2.25 m.
	recipe_value.add_placement(&"stocked.counter", table_asset_id,
		_pose(Vector3(-3.05, 0.0, centre.z), PI * 0.5))
	# Both attachments are the authored market pieces from the same asset family.
	# Their lowest measured points stay above 1.84 m, so they enrich the covered
	# bay without turning the semantic headroom into a collision lie.
	recipe_value.add_placement(&"stocked.hanging",
		COVERED_MARKET_HANGING_GOODS,
		_pose(Vector3(0.8, 3.25, -1.55), 0.0))
	recipe_value.add_placement(&"stocked.wheel", COVERED_MARKET_WHEEL,
		_pose(Vector3(1.1, 2.5, -0.75), 0.0))
	if decorated:
		# As with planted balconies, this remains a distinct measured variant.
		# A barrel with a tabletop lantern and a leafy plant occupy only the two
		# structural post bays, outside the exact two-cell public aisle. This makes
		# the bazaar read as stocked after dusk without turning the aisle into a
		# scatter pass or inventing an unmeasured obstruction.
		var barrel_origin := Vector3(2.42, 0.02, 0.48)
		recipe_value.add_placement(&"stocked.barrel", TERRACE_BARREL_B,
			_pose(barrel_origin, 0.0))
		recipe_value.add_placement(&"stocked.lantern", TERRACE_LANTERN_TABLE,
			_pose(barrel_origin + Vector3.UP * 1.04, 0.0))
		recipe_value.add_placement(&"stocked.plant.west", TERRACE_PLANT_MID,
			_pose(Vector3(-2.55, 0.02, -0.48), PI))
		recipe_value.add_placement(&"stocked.flower.west", ROOF_FLOWER_SMALL,
			_pose(Vector3(-2.50, 0.02, -0.43), PI))
		# Small complete props turn the opposite post bay into an actual merchant's
		# work corner. Their measured footprints stay outside the two-cell aisle;
		# the crate carries its bag, while the bucket sits beside the counter.
		var crate_origin := Vector3(1.92, 0.02, -0.54)
		recipe_value.add_placement(&"stocked.crate", TERRACE_CRATE,
			_pose(crate_origin, PI * 0.5))
		recipe_value.add_placement(&"stocked.bag", TERRACE_BAG,
			_pose(crate_origin + Vector3.UP * 0.76, -0.12))
		recipe_value.add_placement(&"stocked.bucket", TERRACE_BUCKET,
			_pose(Vector3(-2.30, 0.02, 0.58), PI * 0.25))
		recipe_value.add_placement(&"stocked.flower.east", ROOF_FLOWER_PALE,
			_pose(Vector3(2.38, 0.02, 0.42), 0.0))
		recipe_value.role_tags.append(&"market_garden")
		recipe_value.role_tags.append(&"market_lantern")
		recipe_value.role_tags.append(&"market_work_corner")
	for y in 2:
		for x in [-2, 1]:
			for z in [-1, 0]:
				recipe_value.solid_cells.append(Vector3i(x, y, z))
	recipe_value.solid_cells.append_array(FabricRecipe.box_cells(
		Vector3i(-2, 2, -1), Vector3i(4, 1, 2)))
	recipe_value.occluder_cells = FabricRecipe.box_cells(
		Vector3i(-2, 0, -1), Vector3i(4, 3, 2))
	recipe_value.add_socket(&"market.back", FabricRecipe.SocketKind.MARKET,
		Vector3i(-1, 0, -1), Vector3i(0, 0, -1))
	_set_terrain_bearing_rect(recipe_value, Vector3i(-2, 0, -1),
		Vector3i(4, 1, 2))
	return recipe_value


static func _prefab_recipe(recipe_id: StringName, asset_id: StringName,
		catalog: EnvironmentCatalog, modules: FabricModuleProgram) -> FabricRecipe:
	var descriptor := catalog.descriptor(asset_id)
	if descriptor == null or not descriptor.measured_aabb.has_volume():
		return null
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"room", &"prefab_anchor", &"terrain_bearing"], 0)
	var bounds: AABB = descriptor.measured_aabb
	var x_radius := maxi(1, ceili(maxf(absf(bounds.position.x),
		absf(bounds.end.x)) / CELL))
	var z_radius := maxi(1, ceili(maxf(absf(bounds.position.z),
		absf(bounds.end.z)) / CELL))
	var height := maxi(1, ceili(bounds.end.y / CELL))
	var footprint_minimum := Vector3i(-x_radius, 0, -z_radius)
	var footprint_size := Vector3i(x_radius * 2, 1, z_radius * 2)
	var prefab_transform := modules.prefab_aligned_transform(asset_id,
		Transform3D.IDENTITY, footprint_minimum, footprint_size, 0.0)
	recipe_value.add_placement(&"building", asset_id, prefab_transform)
	var door_x := -1 if x_radius > 1 else 0
	var door_cell := Vector3i(door_x, 0, z_radius - 1)
	# LPFV complete houses deliberately ship with an empty doorway aperture. Their
	# centred `_01` jamb is part of the merged house, while the hinged `_02` leaf is
	# a separate authored asset. A finished static town must not expose that opening
	# as an apparently open door. Attach one complete leaf at the exact threshold
	# already owned by this recipe. It is a measured construction placement (visual
	# + collision), not a post-build prop, and its hinge derives from the source
	# jamb instead of the annex/roof's much larger total AABB.
	if String(asset_id).begins_with("lpfv.building.house."):
		var door_variant := int(String(asset_id).right(1).to_int()) % \
			LPFV_PREFAB_DOORS.size()
		var closed_door := LPFV_PREFAB_DOORS[door_variant]
		recipe_value.add_placement(&"front.closed_door", closed_door,
			prefab_transform * _pose(LPFV_PREFAB_DOOR_ORIGIN, 0.0))
	var bearing_cells: Dictionary = {}
	for point: Vector2 in descriptor.ground_contact_points:
		var transformed := prefab_transform * Vector3(point.x, bounds.position.y,
			point.y)
		bearing_cells[Vector3i(roundi(transformed.x / CELL), 0,
			roundi(transformed.z / CELL))] = true
	recipe_value.terrain_bearing_cells.assign(bearing_cells.keys())
	recipe_value.terrain_bearing_cells.sort_custom(func(a: Vector3i,
			b: Vector3i) -> bool:
		return a.z < b.z if a.z != b.z else a.x < b.x)
	if recipe_value.terrain_bearing_cells.is_empty():
		return null
	# Prefabs contribute a conservative shell and a real door opening. Their
	# exact baked trimesh remains the physics authority; the planning mask never
	# degenerates into a building-wide forbidden box.
	for y in height:
		for z in range(-z_radius, z_radius):
			for x in range(-x_radius, x_radius):
				var boundary := x == -x_radius or x == x_radius - 1 \
					or z == -z_radius or z == z_radius - 1
				if not boundary:
					continue
				var doorway := z == z_radius - 1 and x == door_x and y < 2
				if not doorway:
					var cell := Vector3i(x, y, z)
					recipe_value.solid_cells.append(cell)
					recipe_value.occluder_cells.append(cell)
	for y in mini(2, height):
		recipe_value.headroom_cells.append(Vector3i(door_x, y, z_radius - 1))
	recipe_value.add_entrance(&"front", door_cell, Vector3i.BACK)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	_add_room_sockets(recipe_value, x_radius, z_radius, maxi(0, height / 2))
	return recipe_value


static func _set_terrain_bearing_rect(recipe_value: FabricRecipe,
		minimum: Vector3i, size: Vector3i) -> void:
	## A single construction primitive owns the terrain interface for every
	## recipe. Callers declare a true load-bearing rectangle; downstream systems
	## never attempt to reconstruct it from shells, eaves, stairs, or visuals.
	assert(recipe_value != null and recipe_value.has_tag(&"terrain_bearing"))
	assert(minimum.y == 0 and size.y == 1 and size.x > 0 and size.z > 0)
	recipe_value.terrain_bearing_cells = FabricRecipe.box_cells(minimum, size)


static func _add_front_facade_detail(recipe_value: FabricRecipe,
		detail_kind: StringName, centre: Vector3, front_half_depth: float) -> void:
	## These soft, collisionless pieces are part of a complete facade recipe, so
	## their measured bounds participate in parcel clearance before a building is
	## accepted.  Alternating storeys therefore gain ivy, laundry, or a hanging
	## sign without a post-build decoration pass piercing a neighboring house.
	if detail_kind == &"windowbox":
		# A complete measured sill garden: the planter and leafy plant are
		# compiled into the room's visual envelope. It can therefore fall back to
		# the flush phase-A shell at a tight party wall instead of clipping a lane.
		var box_origin := centre + Vector3(0.0, 0.82,
			front_half_depth + 0.42)
		recipe_value.add_placement(&"facade.windowbox", ROOF_PLANTER,
			_pose(box_origin, 0.0))
		var windowbox_plant := TERRACE_PLANT_LOW if front_half_depth < 2.0 \
			else TERRACE_PLANT_MID if front_half_depth < 4.0 \
			else TERRACE_PLANT_BROAD
		recipe_value.add_placement(&"facade.windowbox.plant",
			windowbox_plant,
			_pose(box_origin + Vector3(0.0, 0.08, 0.0), 0.0))
		if not recipe_value.role_tags.has(&"facade_detail"):
			recipe_value.role_tags.append(&"facade_detail")
		recipe_value.role_tags.append(&"planted_facade")
		return
	var asset_id := FACADE_IVY if detail_kind == &"ivy" \
		else FACADE_CLOTHES if detail_kind == &"clothes" \
		else FACADE_SIGN if detail_kind == &"sign" else &""
	assert(not asset_id.is_empty())
	var local_origin := centre
	match detail_kind:
		&"ivy":
			local_origin += Vector3(1.10, 1.45, front_half_depth + 0.34)
		&"clothes":
			# The source pivot is the upper-left end of a three-metre line.
			local_origin += Vector3(-1.55, 2.62, front_half_depth + 0.34)
		&"sign":
			local_origin += Vector3(0.85, 2.02, front_half_depth + 0.38)
	recipe_value.add_placement(StringName("facade.%s" % detail_kind),
		asset_id, _pose(local_origin, 0.0))
	if not recipe_value.role_tags.has(&"facade_detail"):
		recipe_value.role_tags.append(&"facade_detail")


static func _upper_facade_detail_kind(theme: StringName,
		room_form: StringName, facade_phase: int = 1) -> StringName:
	## Detail families follow construction style and room width instead of every
	## `.b` storey receiving the same pasted sign. The selection is recipe-local,
	## while town-seed phase selection still decides which storeys receive it.
	var base_kind := &"ivy"
	match room_form:
		&"square":
			base_kind = &"ivy" if theme == &"blue" else &"sign" \
				if theme == &"stone" else &"windowbox"
		&"long":
			base_kind = &"clothes" if theme == &"blue" else &"ivy" \
				if theme == &"orange" else &"sign" \
				if theme == &"stone" else &"windowbox"
		&"tower":
			base_kind = &"sign" if theme in [&"blue", &"stone"] else &"ivy" \
				if theme == &"amber" else &"windowbox"
		&"slim":
			base_kind = &"ivy" if theme == &"blue" else &"sign" \
				if theme == &"orange" else &"clothes" \
				if theme == &"stone" else &"windowbox"
		&"row":
			base_kind = &"clothes" if theme == &"blue" else &"ivy" \
				if theme == &"orange" else &"sign" \
				if theme == &"stone" else &"windowbox"
	# Every odd phase is the detailed mate of an even lineage style. Rotate the
	# authored detail family as the style changes so `.d`/`.f` are not merely a
	# different window around the same pasted ivy/sign asset. Phase one retains
	# the original mapping exactly.
	var choices: Array[StringName] = [
		&"ivy", &"clothes", &"sign", &"windowbox",
	]
	var base_index := choices.find(base_kind)
	var style_index := maxi(0, facade_phase / 2)
	return choices[posmod(base_index + style_index, choices.size())]


static func _add_room_shell(recipe_value: FabricRecipe, door_asset: StringName,
		face_assets: Array[StringName], width: float,
		modules: FabricModuleProgram, door_face: StringName = &"") -> void:
	## `face_assets` is front/back/left/right, one authored module per face.
	assert(door_face in [&"", &"front", &"back", &"left", &"right"])
	assert(face_assets.size() == 4)
	var cell_count := roundi(width / CELL)
	assert(cell_count > 0 and cell_count % 2 == 0 \
		and is_equal_approx(float(cell_count) * CELL, width))
	var minimum := Vector3i(-cell_count / 2, 0, -cell_count / 2)
	var centre := FabricModuleProgram.footprint_centre(minimum,
		Vector3i(cell_count, 1, cell_count))
	var half := width * 0.5
	var door_contract := _room_door_contract(door_face)
	var door_index := int(door_contract.get("index", -1))
	for z_index in 2:
		for x_index in 2:
			var floor_offset := Vector3(-1.5 + x_index * 3.0, 0.0,
				-1.5 + z_index * 3.0)
			recipe_value.add_placement(StringName("floor.%d.%d" % [
				z_index, x_index]), FLOOR, modules.walk_aligned_transform(FLOOR,
					_pose(centre + floor_offset, 0.0), 0.0))
	for index in 2:
		var offset := -1.5 + index * 3.0
		var front_asset := door_asset \
			if door_face == &"front" and index == door_index else face_assets[0]
		var back_asset := door_asset \
			if door_face == &"back" and index == door_index else face_assets[1]
		var left_asset := door_asset \
			if door_face == &"left" and index == door_index else face_assets[2]
		var right_asset := door_asset \
			if door_face == &"right" and index == door_index else face_assets[3]
		left_asset = _mirrored_facade_asset(left_asset)
		right_asset = _mirrored_facade_asset(right_asset)
		recipe_value.add_placement(StringName("front.%d" % index),
			front_asset, modules.facade_aligned_transform(front_asset,
				_pose(centre + Vector3(offset, 0.0, half), 0.0),
				Vector3i.BACK, centre.z + half))
		recipe_value.add_placement(StringName("back.%d" % index), back_asset,
			modules.facade_aligned_transform(back_asset,
				_pose(centre + Vector3(offset, 0.0, -half), PI),
				Vector3i.FORWARD, centre.z - half))
		recipe_value.add_placement(StringName("left.%d" % index), left_asset,
			modules.facade_aligned_transform(left_asset,
				_pose(centre + Vector3(-half, 0.0, offset), PI * 0.5),
				Vector3i.LEFT, centre.x - half))
		recipe_value.add_placement(StringName("right.%d" % index), right_asset,
			modules.facade_aligned_transform(right_asset,
				_pose(centre + Vector3(half, 0.0, offset), -PI * 0.5),
				Vector3i.RIGHT, centre.x + half))


static func _add_room_occupancy(recipe_value: FabricRecipe,
		door_face: StringName = &"") -> void:
	# The lattice models the wall shell, door opening, and usable interior. A
	# room is never represented as a prefab-wide solid box.
	var contract := _room_door_contract(door_face)
	var has_exterior_door := not contract.is_empty()
	var door_cell := contract.get("cell", Vector3i.ZERO) as Vector3i
	for y in 2:
		for z in range(-2, 2):
			for x in range(-2, 2):
				var cell := Vector3i(x, y, z)
				var boundary := x == -2 or x == 1 or z == -2 or z == 1
				var doorway := has_exterior_door \
					and x == door_cell.x and z == door_cell.z
				if boundary and not doorway:
					recipe_value.solid_cells.append(cell)
					recipe_value.occluder_cells.append(cell)
	# Private floor area is occupied volume, not a public walk claim. Interior
	# navigation can project it through a separate profile later.
	recipe_value.headroom_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 2, 2))
	if has_exterior_door:
		for y in 2:
			recipe_value.headroom_cells.append(Vector3i(door_cell.x, y,
				door_cell.z))
		recipe_value.add_entrance(door_face, door_cell,
			contract.facing as Vector3i)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)


static func _room_door_contract(face: StringName) -> Dictionary:
	## The visual facade slot, open shell cells, and route-facing direction are a
	## single vocabulary fact. Supporting every cardinal facade here keeps door
	## variants data-driven instead of accumulating one-off shell exceptions.
	match face:
		&"front":
			return {"index": 0, "cell": Vector3i(-1, 0, 1),
				"facing": Vector3i.BACK}
		&"back":
			return {"index": 0, "cell": Vector3i(-1, 0, -2),
				"facing": Vector3i.FORWARD}
		&"left":
			return {"index": 0, "cell": Vector3i(-2, 0, -1),
				"facing": Vector3i.LEFT}
		&"right":
			# Index 1 is the low-flight end of the east facade; the doorway
			# therefore meets the public stair at equal elevation.
			return {"index": 1, "cell": Vector3i(1, 0, 0),
				"facing": Vector3i.RIGHT}
		&"":
			return {}
		_:
			assert(false, "unsupported room door facade: %s" % face)
			return {}


static func _add_passage_occluders(recipe_value: FabricRecipe) -> void:
	var door_cells: Dictionary = {
		Vector2i(-1, 1): true,
		Vector2i(1, -2): true,
		Vector2i(-2, -1): true,
		Vector2i(1, 1): true,
	}
	for y in 2:
		for z in range(-2, 2):
			for x in range(-2, 2):
				if x != -2 and x != 1 and z != -2 and z != 1:
					continue
				if not door_cells.has(Vector2i(x, z)):
					recipe_value.occluder_cells.append(Vector3i(x, y, z))


static func _add_passage_shell(recipe_value: FabricRecipe,
		theme: StringName, modules: FabricModuleProgram) -> void:
	var window_asset := _wood_window(theme)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	for index in 2:
		var offset := -1.5 + index * 3.0
		var face_asset := WOOD_DOOR if index == 0 else window_asset
		recipe_value.add_placement(StringName("south.%d" % index), face_asset,
			modules.facade_aligned_transform(face_asset,
				_pose(centre + Vector3(offset, 0.0, 3.0), 0.0),
				Vector3i.BACK, centre.z + 3.0))
		recipe_value.add_placement(StringName("north.%d" % index), face_asset,
			modules.facade_aligned_transform(face_asset,
				_pose(centre + Vector3(-offset, 0.0, -3.0), PI),
				Vector3i.FORWARD, centre.z - 3.0))
		var handed_asset := _mirrored_facade_asset(face_asset)
		recipe_value.add_placement(StringName("west.%d" % index), handed_asset,
			modules.facade_aligned_transform(handed_asset,
				_pose(centre + Vector3(-3.0, 0.0, offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 3.0))
		recipe_value.add_placement(StringName("east.%d" % index), handed_asset,
			modules.facade_aligned_transform(handed_asset,
				_pose(centre + Vector3(3.0, 0.0, -offset), -PI * 0.5),
				Vector3i.RIGHT, centre.x + 3.0))


static func _add_room_sockets(recipe_value: FabricRecipe, x_radius: int = 2,
		z_radius: int = 2, socket_y: int = 0) -> void:
	var east_cell := Vector3i(x_radius - 1, socket_y, 0)
	var west_cell := Vector3i(-x_radius, socket_y, 0)
	var north_cell := Vector3i(0, socket_y, -z_radius)
	var south_cell := Vector3i(0, socket_y, z_radius - 1)
	for prefix: StringName in [&"room", &"bearing"]:
		var kind := FabricRecipe.SocketKind.ROOM \
			if prefix == &"room" else FabricRecipe.SocketKind.BEARING
		recipe_value.add_socket(StringName("%s.east" % prefix), kind,
			east_cell, Vector3i(1, 0, 0))
		recipe_value.add_socket(StringName("%s.west" % prefix), kind,
			west_cell, Vector3i(-1, 0, 0))
		recipe_value.add_socket(StringName("%s.north" % prefix), kind,
			north_cell, Vector3i(0, 0, -1))
		recipe_value.add_socket(StringName("%s.south" % prefix), kind,
			south_cell, Vector3i(0, 0, 1))
		# End-of-face sockets carry corner-wrap bays only: an oriel straddling
		# the building corner bonds the face's end cell, not its centre. The
		# overhead solver keeps skywalks off these (".corner." in the id).
		for face: Dictionary in [
			{"name": "north", "facing": Vector3i(0, 0, -1),
				"a": Vector3i(-x_radius, socket_y, -z_radius), "a_side": "west",
				"b": Vector3i(x_radius - 1, socket_y, -z_radius),
				"b_side": "east"},
			{"name": "south", "facing": Vector3i(0, 0, 1),
				"a": Vector3i(-x_radius, socket_y, z_radius - 1),
				"a_side": "west",
				"b": Vector3i(x_radius - 1, socket_y, z_radius - 1),
				"b_side": "east"},
			{"name": "west", "facing": Vector3i(-1, 0, 0),
				"a": Vector3i(-x_radius, socket_y, -z_radius),
				"a_side": "north",
				"b": Vector3i(-x_radius, socket_y, z_radius - 1),
				"b_side": "south"},
			{"name": "east", "facing": Vector3i(1, 0, 0),
				"a": Vector3i(x_radius - 1, socket_y, -z_radius),
				"a_side": "north",
				"b": Vector3i(x_radius - 1, socket_y, z_radius - 1),
				"b_side": "south"},
		]:
			recipe_value.add_socket(StringName("%s.corner.%s.%s" % [prefix,
				face.name, face.a_side]), kind, face.a as Vector3i,
				face.facing as Vector3i)
			recipe_value.add_socket(StringName("%s.corner.%s.%s" % [prefix,
				face.name, face.b_side]), kind, face.b as Vector3i,
				face.facing as Vector3i)
	recipe_value.add_socket(&"bearing.top", FabricRecipe.SocketKind.BEARING,
		Vector3i(0, 1, 0), Vector3i(0, 1, 0))
	if recipe_value.bearing_parent_count > 0:
		recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
			Vector3i(0, 0, 0), Vector3i(0, -1, 0))
	# A volumetric composition may set an upper room back by one 1.5 m cell.
	# Bearing therefore belongs to the actual overlap columns, not only to the
	# footprint centre inherited from the retired extrusion chain.  These named
	# sockets do not authorize a cantilever: the spatial support solver must still
	# prove overlap and the compiler binds one matching top/bottom column exactly.
	for z in range(-z_radius, z_radius):
		for x in range(-x_radius, x_radius):
			recipe_value.add_socket(_bearing_cell_socket_id(&"top", x, z),
				FabricRecipe.SocketKind.BEARING, Vector3i(x, 1, z),
				Vector3i.UP)
			if recipe_value.bearing_parent_count > 0:
				recipe_value.add_socket(_bearing_cell_socket_id(&"bottom", x, z),
					FabricRecipe.SocketKind.BEARING, Vector3i(x, 0, z),
					Vector3i.DOWN)
	_add_cardinal_sockets(recipe_value, FabricRecipe.SocketKind.MARKET,
		&"market", socket_y, Vector3i(-x_radius, 0, -z_radius),
		x_radius * 2, z_radius * 2)


static func _bearing_cell_socket_id(side: StringName, x: int,
		z: int) -> StringName:
	return StringName("bearing.%s.cell.%d.%d" % [String(side), x, z])


static func _add_cardinal_sockets(recipe_value: FabricRecipe,
		kind: FabricRecipe.SocketKind, prefix: StringName, y: int,
		offset: Vector3i = Vector3i(-1, 0, -1), width: int = 2,
		depth: int = 2) -> void:
	recipe_value.add_socket(StringName("%s.east" % prefix), kind,
		offset + Vector3i(width - 1, y, (depth - 1) / 2), Vector3i(1, 0, 0))
	recipe_value.add_socket(StringName("%s.west" % prefix), kind,
		offset + Vector3i(0, y, (depth - 1) / 2), Vector3i(-1, 0, 0))
	recipe_value.add_socket(StringName("%s.north" % prefix), kind,
		offset + Vector3i((width - 1) / 2, y, 0), Vector3i(0, 0, -1))
	recipe_value.add_socket(StringName("%s.south" % prefix), kind,
		offset + Vector3i((width - 1) / 2, y, depth - 1), Vector3i(0, 0, 1))


static func _wood_window(theme: StringName) -> StringName:
	return facade_pool(theme)[0]


static func facade_pool(family: StringName) -> Array[StringName]:
	## Facade family is an authored construction vocabulary, not a tint. Stone
	## upper storeys therefore use the same measured rock modules as foundations
	## without inheriting terrain bearing; timber families retain their source
	## pack colour variants and UVs.
	if family == &"stone":
		return ROCK_FACADE
	if family == &"orange":
		return WOOD_FACADE_ORANGE
	if family == &"amber":
		return WOOD_FACADE_AMBER
	return WOOD_FACADE_BLUE


static func cell_facade_pool(family: StringName) -> Array[StringName]:
	## TASK I2. The one-cell facade vocabulary for a district family. Same three
	## names `facade_pool` answers to and the same default, so a caller that
	## hands over `architectural_district_theme`'s answer gets the timber family
	## of that district at either width. There is no `stone` pool: the retained
	## mass wears coursed rock through its own retaining course, never as a
	## facade storey.
	if family == &"orange":
		return WOOD_CELL_FACADE_ORANGE
	if family == &"amber":
		return WOOD_CELL_FACADE_AMBER
	return WOOD_CELL_FACADE_BLUE


static func door_pool(family: StringName) -> Array[StringName]:
	return ROCK_DOORS if family == &"stone" else WOOD_DOORS


static func _facade_window(family: StringName) -> StringName:
	return facade_pool(family)[0]


static func _facade_plain(family: StringName) -> StringName:
	return ROCK_PLAIN if family == &"stone" else WOOD_PLAIN


static func _facade_door(family: StringName, phase: int = 0) -> StringName:
	var pool := door_pool(family)
	return pool[posmod(phase, pool.size())]


static func _facade_asset(family: StringName, phase: int) -> StringName:
	## Complete facade modules only. Phase changes geometry (framing, shutters,
	## trim, or a blank board panel), never material overrides, so side textures
	## retain the source pack's authored UVs and every collision envelope
	## remains measured.
	var pool := facade_pool(family)
	return pool[posmod(phase, pool.size())]


static func _mirrored_facade_asset(asset_id: StringName) -> StringName:
	## Authored timber wall panels own the vertical post on local -X only. The
	## north/south faces use that handedness directly; east/west use this baked
	## counterpart so a clockwise shell contributes exactly one post at every
	## corner. Runtime transforms stay proper rotations (determinant +1).
	var text := String(asset_id)
	if text.begins_with("sfv.fabric.wall.wood.window.") \
			or text.begins_with("sfv.fabric.wall.wood.plain.") \
			or text.begins_with("sfv.fabric.wall.wood.door.") \
			or text.begins_with("sfv.fabric.wall.rock.door."):
		return StringName(text + ".mirror_x")
	return asset_id


static func _face_phase(phase: int, face_index: int) -> int:
	## One phase per face, so a room is four authored walls rather than the same
	## wall stamped four times. See FACE_PHASE_OFFSETS.
	return phase + FACE_PHASE_OFFSETS[posmod(face_index,
		FACE_PHASE_OFFSETS.size())]


static func _pose(origin: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), origin)


static func _scaled_pose(origin: Vector3, yaw: float,
		scale_value: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale_value), origin)
