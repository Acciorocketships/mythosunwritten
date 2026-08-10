class_name SettlementFabricProgram
extends RefCounted

## Compiled finite vocabulary for the sectional warren. Resource access is
## confined to compile(); topology-only route recipes contribute surface claims
## but never place their own floors.
const CELL := FabricRecipe.CELL_SIZE

const ROCK_PLAIN := &"sfv.fabric.wall.rock.plain.001"
const ROCK_DOOR := &"sfv.fabric.wall.rock.door.005"
const ROCK_WINDOW := &"sfv.fabric.wall.rock.window.010"
const WOOD_PLAIN := &"sfv.fabric.wall.wood.plain.001"
const WOOD_DOOR := &"sfv.fabric.wall.wood.door.001"
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
const FACADE_IVY := &"sfv.fabric.ivy.001"
const FACADE_CLOTHES := &"sfv.fabric.clothes.001"
const FACADE_SIGN := &"sfv.fabric.sign.tavern.001"
const GABLE := &"sfv.fabric.gable.wood.m.001"
const BRACE := &"sfv.fabric.brace.wood.002"
const WALL_WOOD_S_A := &"sfv.fabric.wall.wood.s.001"
const WALL_WOOD_S_B := &"sfv.fabric.wall.wood.s.002"
const WALL_WOOD_CORNER_S := &"sfv.fabric.wall.wood.corner.s.001"

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
const ROCK_FACADE: Array[StringName] = [
	&"sfv.fabric.wall.rock.window.010",
	&"sfv.fabric.wall.rock.plain.001",
	&"sfv.fabric.wall.rock.window.010",
	&"sfv.fabric.wall.rock.window.m.016",
	&"sfv.fabric.wall.rock.window.m.019",
	&"sfv.fabric.wall.rock.plain.002",
	&"sfv.fabric.wall.rock.window.s.003",
]
## Door modules follow the same rule: index 0 stays the shipped door so an
## existing addressed room is unchanged, and the later entries are alternative
## authored door frames of the same module width.
const WOOD_DOORS: Array[StringName] = [
	&"sfv.fabric.wall.wood.door.001",
	&"sfv.fabric.wall.wood.door.004",
	&"sfv.fabric.wall.wood.door.002",
	&"sfv.fabric.wall.wood.door.003",
]
const ROCK_DOORS: Array[StringName] = [
	&"sfv.fabric.wall.rock.door.005",
	&"sfv.fabric.wall.rock.door.006",
	&"sfv.fabric.wall.rock.door.001",
	&"sfv.fabric.wall.rock.door.009",
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
const STAIR_FULL := &"sfv.fabric.stair.preset.004"
const STAIR_HALF := &"sfv.stair.s.001"
const RAILING := &"sfv.deck.railing.s.001"

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
	&"sfm.stall.armory.001",
	&"sfm.stall.bakery.001",
	&"sfm.stall.veg.001",
	&"sfm.stall.fabric.001",
	&"sfm.stall.forge.003",
	&"sfm.stall.veg.003",
	&"sfm.stall.armory.002",
	&"sfm.stall.bakery.002",
	&"sfm.stall.fish.002",
	&"sfm.stall.veg.002",
	&"sfm.stall.fabric.002",
	&"sfm.stall.alchemy.001",
	&"sfm.stall.veg.004",
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
	&"sfm.stall.butcher.003",
]
const COVERED_MARKET_TABLE := &"sfm.table.fishmonger.001"

const PREFAB_ANCHORS: Array[StringName] = [
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
]

var referenced_asset_ids: Array[StringName] = []
var module_program: FabricModuleProgram
var _recipes: Dictionary = {}


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
		_complete_room_roof_recipe(&"roof.square.01", ROOM_ROOF_01),
		_complete_room_roof_recipe(&"roof.square.02", ROOM_ROOF_02),
		_complete_room_roof_recipe(&"roof.square.04", ROOM_ROOF_04, true),
		_complete_room_roof_recipe(&"roof.square.05", ROOM_ROOF_05, true),
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
		_tower_roof_recipe(&"roof.tower.blue", COMPACT_ROOF_03, modules),
		_tower_roof_recipe(&"roof.tower.orange", COMPACT_ROOF_06, modules),
		_chimney_tower_roof_recipe(&"roof.tower.chimney.blue",
			COMPACT_ROOF_03, modules),
		_chimney_tower_roof_recipe(&"roof.tower.chimney.orange",
			COMPACT_ROOF_06, modules),
		_short_tower_roof_recipe(&"roof.tower.short.blue", COMPACT_ROOF_03,
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
		_setback_cap_recipe(&"roof.setback.cap.1", 1, modules),
		_setback_cap_recipe(&"roof.setback.cap.2", 2, modules),
		_setback_cap_recipe(&"roof.setback.cap.4", 4, modules),
		_setback_cap_recipe(&"roof.setback.cap.6", 6, modules),
		_slim_roof_recipe(&"roof.slim.blue", ROOF_BLUE, modules),
		_slim_roof_recipe(&"roof.slim.orange", ROOF_ORANGE, modules),
		_chimney_slim_roof_recipe(&"roof.slim.chimney.blue", ROOF_BLUE,
			modules),
		_chimney_slim_roof_recipe(&"roof.slim.chimney.orange", ROOF_ORANGE,
			modules),
		_short_slim_roof_recipe(&"roof.slim.short.blue", ROOF_BLUE, modules),
		_short_slim_roof_recipe(&"roof.slim.short.orange", ROOF_ORANGE, modules),
		_outcrop_recipe(&"outcrop.blue", &"blue", modules),
		_outcrop_recipe(&"outcrop.orange", &"orange", modules),
		_outcrop_recipe(&"outcrop.corner.left.blue", &"blue", modules, 0, -2),
		_outcrop_recipe(&"outcrop.corner.left.orange", &"orange", modules, 0, -2),
		_outcrop_recipe(&"outcrop.corner.right.blue", &"blue", modules, 0, 1),
		_outcrop_recipe(&"outcrop.corner.right.orange", &"orange", modules, 0, 1),
		_outcrop_recipe(&"outcrop.half.blue", &"blue", modules, 1),
		_outcrop_recipe(&"outcrop.half.orange", &"orange", modules, 1),
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
		_skywalk_corner_recipe(modules),
	]
	_append_roof_seam_vocabulary(candidates, modules)
	_append_bisected_valley_vocabulary(candidates, modules)
	for index in MARKET_STALLS.size():
		var market_descriptor := catalog.descriptor(MARKET_STALLS[index])
		# `stocked_market` and `themed_stall` are the two reviewed goods-laden
		# stall tags the bake manifests carry; both mean a complete stall prefab
		# with its wares modelled. Admitting only the first pinned every town's
		# bazaar to the seven pieces that predated the bake wave.
		if market_descriptor == null \
				or not (market_descriptor.tags.has(&"stocked_market") \
					or market_descriptor.tags.has(&"themed_stall")):
			push_error("Market vocabulary asset is not a reviewed stocked prefab: %s" %
				MARKET_STALLS[index])
			return null
		candidates.append(_market_recipe(StringName("market.stall.%02d" % index),
			MARKET_STALLS[index]))
		candidates.append(_covered_market_recipe(
			StringName("market.covered.%02d" % index),
			COVERED_MARKET_CANOPIES[index % COVERED_MARKET_CANOPIES.size()],
			COVERED_MARKET_TABLE))
	for index in PREFAB_ANCHORS.size():
		candidates.append(_prefab_recipe(StringName("anchor.prefab.%02d" % index),
			PREFAB_ANCHORS[index], catalog, modules))
	for candidate: FabricRecipe in candidates:
		if candidate == null or not modules.apply_visual_envelope(candidate) \
				or not candidate.seal(catalog) \
				or not program._add_recipe(candidate):
			push_error("Could not compile settlement fabric recipe %s: %s" % [
				"<null>" if candidate == null else candidate.recipe_id,
				"null recipe" if candidate == null else candidate.last_rejection])
			return null
	var unique_assets: Dictionary = {}
	for recipe_value: FabricRecipe in program._recipes.values():
		for asset_id: StringName in recipe_value.asset_ids():
			unique_assets[asset_id] = true
	program.referenced_asset_ids.assign(unique_assets.keys())
	program.referenced_asset_ids.sort_custom(func(a: StringName,
			b: StringName) -> bool: return String(a) < String(b))
	return program


static func _compile_module_program(catalog: EnvironmentCatalog) \
		-> FabricModuleProgram:
	var modules := FabricModuleProgram.new(catalog)
	var facade_assets: Array[StringName] = [
		ROCK_PLAIN, ROCK_DOOR, ROCK_WINDOW, WOOD_PLAIN, WOOD_DOOR,
		STAIR_FULL, STAIR_HALF,
		WALL_WOOD_S_A, WALL_WOOD_S_B, WALL_WOOD_CORNER_S,
		COMPACT_CHIMNEY, ROOM_ROOF_01, ROOM_ROOF_04,
		ROOF_WINDOW_01, ROOF_WINDOW_02, ROOF_WINDOW_03, ROOF_WINDOW_04,
		ROOF_SEAM,
		ROOF_BISECT_LEFT_BLUE, ROOF_BISECT_RIGHT_BLUE,
		ROOF_BISECT_LEFT_ORANGE, ROOF_BISECT_RIGHT_ORANGE,
	]
	for pool: Array[StringName] in [WOOD_FACADE_BLUE, WOOD_FACADE_ORANGE,
			WOOD_FACADE_AMBER, ROCK_FACADE, WOOD_DOORS, ROCK_DOORS,
			ROOF_CHIMNEYS]:
		for asset_id: StringName in pool:
			if not facade_assets.has(asset_id):
				facade_assets.append(asset_id)
	for wall_asset: StringName in facade_assets:
		if not modules.add_generic(wall_asset):
			push_error("Could not compile facade contract %s: %s" % [
				wall_asset, modules.last_rejection])
			return null
	if not modules.add_walk_surface(FLOOR) \
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
		recipe_value.add_placement(StringName("stair.%02d" % lane), asset_id,
			stair_transforms[lane])
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
	if not terrain_bearing and facade_phase == 1:
		_add_front_facade_detail(recipe_value, &"ivy",
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
	assert(facade_phase == 0 or facade_phase == 1)
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
		recipe_value.add_placement(StringName("west.%d" % index), west_asset,
			modules.facade_aligned_transform(west_asset,
				_pose(centre + Vector3(-3.0, 0.0, z_offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 3.0))
		recipe_value.add_placement(StringName("east.%d" % index), east_asset,
			modules.facade_aligned_transform(east_asset,
				_pose(centre + Vector3(3.0, 0.0, z_offset), -PI * 0.5),
				Vector3i.RIGHT, centre.x + 3.0))
	if not terrain_bearing and facade_phase == 1:
		_add_front_facade_detail(recipe_value, &"clothes", centre, 4.5)
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
		recipe_value.add_placement(StringName(side.id), wall,
			modules.facade_aligned_transform(wall,
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
		recipe_value.add_placement(StringName(side.id), asset_id,
			modules.facade_aligned_transform(asset_id,
				_pose(centre + side.offset as Vector3, float(side.yaw)),
				side.outward as Vector3i, float(side.boundary)))
	if not terrain_bearing and facade_phase == 1:
		_add_front_facade_detail(recipe_value, &"sign", centre, 1.5)
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
	if not terrain_bearing and facade_phase == 1:
		_add_front_facade_detail(recipe_value, &"sign", centre, 3.0)
	for index in 2:
		var z_offset := -1.5 + float(index) * 3.0
		var west_asset := side_asset if index == int(theme == &"blue") \
			else window_asset
		var east_asset := side_asset if index == int(theme == &"orange") \
			else window_asset
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
				window_asset, modules.facade_aligned_transform(window_asset,
					_pose(room_centre + Vector3(-3.0, y, offset), PI * 0.5),
					Vector3i.LEFT, room_centre.x - 3.0))
			recipe_value.add_placement(StringName("east.%d.%d" % [level, index]),
				window_asset, modules.facade_aligned_transform(window_asset,
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
		roof_asset: StringName, include_chimney: bool = false) -> FabricRecipe:
	## The measured complete roof is 5.87 m across its eaves and 6.65 m along
	## its ridge. It closes the 6 m room without a separate triangle whose UVs or
	## peak can drift, and the ridge is longer than the transverse width by
	## construction.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"complete_gable", &"ridge_z"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -2), Vector3i(4, 1, 4))
	recipe_value.add_placement(&"roof", roof_asset, _pose(centre, 0.0))
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
	var dormer_yaw := PI * 0.5 if eave_side > 0 else -PI * 0.5
	recipe_value.add_placement(&"dormer", dormer_asset,
		_pose(centre + Vector3(float(eave_side) * 1.55, 0.45, 0.0),
			dormer_yaw))
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
	var dormer_yaw := PI * 0.5 if eave_side > 0 else -PI * 0.5
	recipe_value.add_placement(&"dormer", dormer_asset,
		_pose(centre + Vector3(float(eave_side) * 1.55, 0.45, 0.0),
			dormer_yaw))
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
	var dormer_yaw := PI * 0.5 if eave_side > 0 else -PI * 0.5
	for index in 2:
		var ridge_offset := -2.0 + float(index) * 4.0
		recipe_value.add_placement(StringName("dormer.%d" % index),
			dormer_asset, _pose(centre + Vector3(
				float(eave_side) * 1.55, 0.45, ridge_offset), dormer_yaw))
	recipe_value.role_tags.append(&"dormer")
	recipe_value.role_tags.append(&"paired_dormer")
	return recipe_value


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
	recipe_value.add_placement(&"roof", roof_asset, _pose(centre, 0.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
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
	_add_roof_junction_sockets(recipe_value, minimum, size)
	return recipe_value


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
	## Two complete compact gables form a deliberately staggered roofline over the
	## 3 x 6 m townhouse.  Each authored ridge runs along local Z and is longer
	## than its eave span; their half-cell longitudinal offset makes the combined
	## silhouette narrow/deep without scaling a 6.49 m modular gable sideways.
	## The small vertical stagger prevents coincident tiles in their shared seam
	## and reads as one older section having grown onto another.
	assert(roof_asset == ROOF_BLUE or roof_asset == ROOF_ORANGE)
	assert(modules != null)
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"slim_building", &"ridge_z",
			&"staggered_roof"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -2), Vector3i(2, 1, 4))
	var first_asset := COMPACT_ROOF_06 if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_03
	var second_asset := COMPACT_ROOF_03 if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_06
	recipe_value.add_placement(&"roof.rear", first_asset,
		_pose(centre + Vector3(0.0, 0.0, -1.5), 0.0))
	recipe_value.add_placement(&"roof.front", second_asset,
		_pose(centre + Vector3(0.0, 0.6, 1.5), 0.0))
	recipe_value.solid_cells = FabricRecipe.box_cells(Vector3i(-1, 0, -2),
		Vector3i(2, 2, 4))
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	recipe_value.add_socket(&"bearing.bottom", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.DOWN)
	_add_roof_junction_sockets(recipe_value, Vector3i(-1, 0, -2),
		Vector3i(2, 1, 4))
	return recipe_value


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


static func _append_roof_seam_vocabulary(candidates: Array[FabricRecipe],
		modules: FabricModuleProgram) -> void:
	## Enumerate the finite native-pitch interval vocabulary. A partial contact
	## never stretches flashing: each legal segment is composed from complete
	## 3 m modules and remains bonded at the owning roof's canonical datum.
	var seen: Dictionary = {}
	for kind: StringName in [&"tower", &"slim", &"building", &"long"]:
		var owner_run_cells := 2 if kind == &"tower" else 4 \
			if kind == &"slim" or kind == &"building" else 6
		var width_m := 3.0 if kind == &"tower" or kind == &"slim" else 6.0
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
	if bearing_drop_cells == 1:
		role_tags.append(&"half_raised_outcropping")
		role_tags.append(&"half_level_oriel")
	var recipe_value := FabricRecipe.new(recipe_id, role_tags, 1)
	var wall := _wood_window(theme)
	var roof_asset := COMPACT_ROOF_03 if theme == &"orange" \
		else COMPACT_ROOF_06
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
	# the parent room. The compact roof is a closed authored gable: rotating it a
	# quarter turn makes its 4.16 m ridge follow the facade while its 3.66 m eave
	# span remains the projection depth. This removes the dark exposed underside
	# and missing-end behavior of the former single-slope lean-to.
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
		recipe_value.add_placement(StringName(side.id), wall,
			modules.facade_aligned_transform(wall,
				_pose(centre + Vector3(float(side.x), 0.0, 0.0),
					float(side.yaw)), side.outward as Vector3i,
				centre.x + float(side.x)))
	recipe_value.add_placement(&"roof", roof_asset,
		_pose(centre + Vector3.UP * 3.0, PI * 0.5))
	recipe_value.add_placement(&"brace.left", BRACE,
		_pose(centre + Vector3(-0.9, -0.55, -1.5), 0.0))
	recipe_value.add_placement(&"brace.right", BRACE,
		_pose(centre + Vector3(0.9, -0.55, -1.5), 0.0))
	if bearing_drop_cells == 1:
		# A second fixed brace course makes the half-level offset visibly borne by
		# its parent. No asset is stretched to bridge the extra datum.
		recipe_value.add_placement(&"brace.low.left", BRACE,
			_pose(centre + Vector3(-0.9, -2.05, -1.5), 0.0))
		recipe_value.add_placement(&"brace.low.right", BRACE,
			_pose(centre + Vector3(0.9, -2.05, -1.5), 0.0))
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
	recipe_value.add_placement(&"brace.left", BRACE,
		_pose(Vector3(centre_x - 0.9, -0.55, row_z + 0.3), 0.0))
	recipe_value.add_placement(&"brace.right", BRACE,
		_pose(Vector3(centre_x + 0.9, -0.55, row_z + 0.3), 0.0))
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
	recipe_value.add_placement(&"brace.left", BRACE,
		_pose(Vector3(centre_x - 0.9, -0.55, row_z + 0.3), 0.0))
	recipe_value.add_placement(&"brace.right", BRACE,
		_pose(Vector3(centre_x + 0.9, -0.55, row_z + 0.3), 0.0))
	_seal_shallow_bay_cells_and_sockets(recipe_value, minimum_x)
	return recipe_value


static func _corner_wrap_outcrop_recipe(recipe_id: StringName,
		theme: StringName, modules: FabricModuleProgram,
		hand: int) -> FabricRecipe:
	## Corner oriel: a 2 x 2 module square straddling the parent's corner —
	## two squares overlapping on one diagonal. The quadrant inside the parent
	## stays visual-only (declared stack seam); the outside L carries the solid
	## cells, two 3 m window faces, two 1.5 m cheeks, a symmetric corner post,
	## and the gallery-deck cap.
	assert(hand == -1 or hand == 1)
	# Not a capped_outcropping: review round 5 showed the bare deck cap reads as
	# an unfinished open frame from above, so the oriel owns a compact roof.
	var role_tags: Array[StringName] = [
		&"room", &"outcropping", &"overhead_occupied", &"corner_wrap_bay",
		&"wood_walled_bay", &"corner_jetty",
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
	# A closed compact gable finishes the turret; the former flat deck cap read
	# as a bare tabletop over an open frame from every above vantage. The 3.66 m
	# eave span overhangs the 3 m square like the projection bays.
	var roof_asset := COMPACT_ROOF_03 if theme == &"orange" else COMPACT_ROOF_06
	recipe_value.add_placement(&"roof", roof_asset,
		_pose(Vector3(square_centre_x, 3.0, -0.75), 0.0))
	recipe_value.add_placement(&"brace.north", BRACE,
		_pose(Vector3(square_centre_x, -0.55, -1.8), 0.0))
	recipe_value.add_placement(&"brace.outer", BRACE,
		_pose(Vector3(sign_x * 1.8, -0.55, -0.75), sign_x * PI * 0.5))
	# Solid cells stay the two-band room body: extending them to four bands for
	# the roof rejected the pinned production seed 4242 (embedding shrank).
	# The roof mass is declared through occluder_cells below instead.
	recipe_value.solid_cells = [
		Vector3i(0, 0, -1), Vector3i(0, 1, -1),
		Vector3i(hand, 0, -1), Vector3i(hand, 1, -1),
		Vector3i(hand, 0, 0), Vector3i(hand, 1, 0),
	]
	# The compact gable extends two visual bands above the body; declare that
	# mass for occlusion honesty without shrinking the embeddable volume.
	recipe_value.occluder_cells.assign(recipe_value.solid_cells)
	for column: Vector3i in [Vector3i(0, 0, -1), Vector3i(hand, 0, -1),
			Vector3i(hand, 0, 0)]:
		recipe_value.occluder_cells.append(column + Vector3i(0, 2, 0))
		recipe_value.occluder_cells.append(column + Vector3i(0, 3, 0))
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
		recipe_value.add_placement(StringName("west.%d" % index), wall,
			modules.facade_aligned_transform(wall,
				_pose(centre + Vector3(-1.5, 0.0, z_offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 1.5))
		recipe_value.add_placement(StringName("east.%d" % index), wall,
			modules.facade_aligned_transform(wall,
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
	var roof_asset := ROOF_ORANGE if theme == &"orange" else ROOF_BLUE
	# An occupied skywalk is a narrow building, not a floor module used twice.
	# The former flat FLOOR ceiling produced a large blank cream rectangle in
	# top-down review and visually read as a roofless room. A measured repeat run
	# closes both slopes and both gable ends without scaling any source asset.
	assert(modules.add_roof_run(recipe_value, &"roof", roof_asset, GABLE,
		centre, 3.0, PI * 0.5, float(segments) * 3.0))
	recipe_value.walk_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 1, 2))
	recipe_value.headroom_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 2, 2))
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.solid_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 2, -1), Vector3i(length_cells, 2, 2))
	recipe_value.occluder_cells = FabricRecipe.box_cells(
		Vector3i(minimum_x, 0, -1), Vector3i(length_cells, 4, 2))
	var maximum_x := minimum_x + length_cells - 1
	recipe_value.add_socket(&"room.west", FabricRecipe.SocketKind.ROOM,
		Vector3i(minimum_x, 0, 0), Vector3i(-1, 0, 0))
	recipe_value.add_socket(&"room.east", FabricRecipe.SocketKind.ROOM,
		Vector3i(maximum_x, 0, 0), Vector3i(1, 0, 0))
	recipe_value.add_socket(&"bearing.west", FabricRecipe.SocketKind.BEARING,
		Vector3i(minimum_x, 0, 0), Vector3i(-1, 0, 0))
	recipe_value.add_socket(&"bearing.east", FabricRecipe.SocketKind.BEARING,
		Vector3i(maximum_x, 0, 0), Vector3i(1, 0, 0))
	return recipe_value


static func _skywalk_corner_recipe(modules: FabricModuleProgram) -> FabricRecipe:
	## A finite 3 m orthogonal tunnel knuckle. Two one-bearing tunnel arms form
	## an L as a strict support chain (building -> arm -> corner -> arm), while
	## the final arm also meets the destination facade. No diagonal transform or
	## uninhabited suspended platform is required.
	var recipe_value := FabricRecipe.new(&"skywalk.corner.orange",
		[&"room", &"skywalk", &"skywalk_corner", &"interior_walk",
			&"overhead_occupied"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-1, 0, -1), Vector3i(2, 1, 2))
	recipe_value.add_placement(&"floor", FLOOR,
		modules.walk_aligned_transform(FLOOR, _pose(centre, 0.0), 0.0))
	# A compact complete pitched shell fits the 3 m corner knuckle without the
	# 6.5 m eave span of the ordinary modular gable. This keeps the right-angle
	# tunnel roofed while preserving its two orthogonal attachment seams.
	recipe_value.add_placement(&"roof", COMPACT_ROOF_06,
		_pose(centre + Vector3.UP * 3.0, 0.0))
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
		recipe_value.add_placement(StringName(side.id), WOOD_DOOR,
			modules.facade_aligned_transform(WOOD_DOOR,
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
		canopy_asset_id: StringName, table_asset_id: StringName) -> FabricRecipe:
	## One exact 6 x 3 m bazaar: a reviewed covered canopy plus its authored
	## stocked fishmonger table attachment. The table offset comes from the
	## original VillageAssetSpec, so this is a composed prefab rather than two
	## guessed bounds. Exact construction admits or rejects the whole market once.
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"market", &"covered_market", &"themed_stall", &"terrain_bearing"], 0)
	recipe_value.add_placement(&"canopy", canopy_asset_id)
	recipe_value.add_placement(&"stocked_table", table_asset_id,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.15)))
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
	var door_x := -1 if x_radius > 1 else 0
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
	var door_cell := Vector3i(door_x, 0, z_radius - 1)
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
		recipe_value.add_placement(StringName("west.%d" % index), face_asset,
			modules.facade_aligned_transform(face_asset,
				_pose(centre + Vector3(-3.0, 0.0, offset), PI * 0.5),
				Vector3i.LEFT, centre.x - 3.0))
		recipe_value.add_placement(StringName("east.%d" % index), face_asset,
			modules.facade_aligned_transform(face_asset,
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


static func _face_phase(phase: int, face_index: int) -> int:
	## One phase per face, so a room is four authored walls rather than the same
	## wall stamped four times. See FACE_PHASE_OFFSETS.
	return phase + FACE_PHASE_OFFSETS[posmod(face_index,
		FACE_PHASE_OFFSETS.size())]


static func _pose(origin: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), origin)
