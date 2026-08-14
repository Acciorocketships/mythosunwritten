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
const WOOD_DOOR_OPEN := &"sfv.fabric.wall.wood.door.open.001"
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
const GABLE := &"sfv.fabric.gable.wood.m.001"
const BRACE := &"sfv.fabric.brace.wood.002"
const DIAGONAL_BRACE := &"sfbp.wwall.support.s.002"
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
const FEATURE_PORTAL_NORTH := 1
const FEATURE_PORTAL_EAST := 2
const FEATURE_PORTAL_SOUTH := 4
const FEATURE_PORTAL_WEST := 8
const FEATURE_PORTAL_MASK_ALL := FEATURE_PORTAL_NORTH \
	| FEATURE_PORTAL_EAST | FEATURE_PORTAL_SOUTH | FEATURE_PORTAL_WEST
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
	## Both phases use the same complete authored 3 m facade module. The suffix
	## records which 1.5 m half-cell is the topological threshold so stairs can
	## stay two lanes wide without a decorative door opening into swept air.
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
		_bridge_room_recipe(&"room.bridge.tower.orange", &"orange", modules),
		_bridge_room_recipe(&"room.bridge.slim.blue", &"blue", modules),
		_bridge_room_recipe(&"room.bridge.slim.orange", &"orange", modules),
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
		_tower_roof_recipe(&"roof.tower.blue", COMPACT_ROOF_SLATE_03, modules),
		_tower_roof_recipe(&"roof.tower.orange", COMPACT_ROOF_06, modules),
		_dormered_tower_roof_recipe(&"roof.tower.blue.dormer.left",
			COMPACT_ROOF_SLATE_03, ROOF_WINDOW_02, -1, modules),
		_dormered_tower_roof_recipe(&"roof.tower.blue.dormer.right",
			COMPACT_ROOF_SLATE_03, ROOF_WINDOW_02, 1, modules),
		_dormered_tower_roof_recipe(&"roof.tower.orange.dormer.left",
			COMPACT_ROOF_06, ROOF_WINDOW_01, -1, modules),
		_dormered_tower_roof_recipe(&"roof.tower.orange.dormer.right",
			COMPACT_ROOF_06, ROOF_WINDOW_01, 1, modules),
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
			ROOF_ORANGE, ROOF_WINDOW_01, -1, modules),
		_dormered_slim_roof_recipe(&"roof.slim.orange.dormer.right",
			ROOF_ORANGE, ROOF_WINDOW_01, 1, modules),
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
		WOOD_DOOR_OPEN,
		STAIR_FULL, STAIR_HALF,
		WALL_WOOD_S_A, WALL_WOOD_S_B, WALL_WOOD_CORNER_S,
		COMPACT_CHIMNEY, ROOM_ROOF_01, ROOM_ROOF_04,
		ROOF_WINDOW_01, ROOF_WINDOW_02, ROOF_WINDOW_03, ROOF_WINDOW_04,
		ROOF_SEAM,
		ROOF_BISECT_LEFT_BLUE, ROOF_BISECT_RIGHT_BLUE,
		ROOF_BISECT_LEFT_ORANGE, ROOF_BISECT_RIGHT_ORANGE,
		ROOF_TERRACE_AWNING, DIAGONAL_BRACE,
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
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"square"),
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
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"long"), centre, 4.5)
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


static func _bridge_room_recipe(recipe_id: StringName, theme: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
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
	recipe_value.bearing_parent_count = 2
	recipe_value.role_tags.append(&"bridge_room")
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
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"tower"), centre, 1.5)
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
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"slim"), centre, 3.0)
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
		for facade_phase in 2:
			var phase_suffix := ".b" if facade_phase == 1 else ""
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
			"asset": ROOF_WINDOW_01, "side": -1},
		{"id": &"roof.row.orange.dormer.right", "theme": ROOF_ORANGE,
			"asset": ROOF_WINDOW_01, "side": 1},
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
		recipe_value.add_placement(StringName(side.id), side_asset,
			modules.facade_aligned_transform(side_asset,
				_pose(centre + Vector3(float(side.x), 0.0, 0.0),
					float(side.yaw)), side.outward as Vector3i,
				float(side.boundary)))
	if not terrain_bearing and facade_phase == 1:
		_add_front_facade_detail(recipe_value,
			_upper_facade_detail_kind(theme, &"row"), centre, 1.5)
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
	var dormer_yaw := PI * 0.5 if eave_side > 0 else -PI * 0.5
	recipe_value.add_placement(&"dormer", dormer_asset,
		_pose(centre + Vector3(float(eave_side) * 0.65, 0.35, 0.0),
			dormer_yaw))
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
	var first_asset := COMPACT_ROOF_SLATE_06 if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_03
	var second_asset := COMPACT_ROOF_SLATE_03 if roof_asset == ROOF_BLUE \
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


static func _row_roof_recipe(recipe_id: StringName, roof_asset: StringName,
		modules: FabricModuleProgram) -> FabricRecipe:
	## The wide/shallow counterpart to the slim roof. Two complete compact gables
	## share one rowhouse transaction and run along local X; their deliberate
	## 0.6 m step reads as a grown building while avoiding coincident tile planes.
	assert(roof_asset == ROOF_BLUE or roof_asset == ROOF_ORANGE)
	assert(modules != null)
	var recipe_value := FabricRecipe.new(recipe_id,
		[&"roof", &"occupied_mass", &"row_building", &"ridge_x",
			&"staggered_roof"], 1)
	var centre := FabricModuleProgram.footprint_centre(
		Vector3i(-2, 0, -1), Vector3i(4, 1, 2))
	var first_asset := COMPACT_ROOF_SLATE_06 if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_03
	var second_asset := COMPACT_ROOF_SLATE_03 if roof_asset == ROOF_BLUE \
		else COMPACT_ROOF_06
	recipe_value.add_placement(&"roof.left", first_asset,
		_pose(centre + Vector3(-1.5, 0.0, 0.0), PI * 0.5))
	recipe_value.add_placement(&"roof.right", second_asset,
		_pose(centre + Vector3(1.5, 0.6, 0.0), PI * 0.5))
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
	var dormer_yaw := 0.0 if eave_side > 0 else PI
	recipe_value.add_placement(&"dormer", dormer_asset,
		_pose(centre + Vector3(1.5, 0.95, float(eave_side) * 0.65),
			dormer_yaw))
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
	var dormer_yaw := PI * 0.5 if eave_side > 0 else -PI * 0.5
	recipe_value.add_placement(&"dormer", dormer_asset,
		_pose(centre + Vector3(float(eave_side) * 0.65, 0.95, 1.5),
			dormer_yaw))
	recipe_value.role_tags.append(&"dormer")
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
		variant.add_placement(StringName(placement.id),
			StringName(placement.asset_id), placement.transform as Transform3D)
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
			variant.add_placement(placement_id, WOOD_DOOR_OPEN,
				modules.facade_aligned_transform(WOOD_DOOR_OPEN,
					spec.pose as Transform3D, spec.outward as Vector3i,
					float(spec.boundary)))
		else:
			variant.add_placement(placement_id,
				StringName(placement.asset_id),
				placement.transform as Transform3D)
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
	if bearing_drop_cells == 1:
		role_tags.append(&"half_raised_outcropping")
		role_tags.append(&"half_level_oriel")
	var recipe_value := FabricRecipe.new(recipe_id, role_tags, 1)
	var wall := _wood_window(theme)
	var roof_asset := COMPACT_ROOF_03 if theme == &"orange" \
		else COMPACT_ROOF_SLATE_06
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
	var roof_asset := COMPACT_ROOF_03 if theme == &"orange" \
		else COMPACT_ROOF_SLATE_06
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
			compact_roof, _pose(centre + Vector3(roof_x, 3.0, 0.0), PI * 0.5))
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


static func _balcony_recipe(recipe_id: StringName, theme: StringName,
		back_socket_x: int, modules: FabricModuleProgram,
		decorated: bool = false) -> FabricRecipe:
	## One complete 3 x 1.5 m occupied balcony. The logical cells are exterior
	## private walk/headroom, while the reviewed deck tiles, four rail runs, and
	## brackets are one atomic measured construction. The parent room's finite
	## feature-portal variant owns the open doorway; placing another wall module
	## here would merely paste an arch over the room's still-closed facade. Left
	## and right attachment variants shift the room socket without changing the
	## usable floor, allowing a facade to stagger balconies instead of extruding
	## the same coordinate through every storey.
	assert(back_socket_x in [-1, 0])
	var recipe_value := FabricRecipe.new(recipe_id, [
		&"balcony", &"private_walk", &"exterior_occupied_floor",
		&"bracket_supported", &"requires_room_portal",
		&"overhead_occupied", theme,
	], 1)
	var deck_cells: Array[Vector3i] = [
		Vector3i(-1, 0, 0), Vector3i(0, 0, 0),
	]
	for cell: Vector3i in deck_cells:
		# The S deck pivot lies on its +X seam; this is the same measured datum
		# correction used by setback caps, not a scaled or guessed placement.
		var floor_pose := _pose(Vector3(float(cell.x) * CELL + CELL * 0.5,
			0.0, 0.0), 0.0)
		recipe_value.add_placement(StringName("floor.%d" % (cell.x + 1)),
			SETBACK_CAP, modules.walk_aligned_transform(SETBACK_CAP,
				floor_pose, 0.0))
		recipe_value.add_placement(StringName("guard.front.%d" % (cell.x + 1)),
			RAILING, _pose(Vector3(float(cell.x) * CELL, 0.0, CELL * 0.5),
				0.0))
	# The two end rails close the 1.5 m depth; the parent facade is the only
	# unguarded edge and contains the exact portal selected with this feature.
	recipe_value.add_placement(&"guard.left", RAILING,
		_pose(Vector3(-CELL * 1.5, 0.0, 0.0), -PI * 0.5))
	recipe_value.add_placement(&"guard.right", RAILING,
		_pose(Vector3(CELL * 0.5, 0.0, 0.0), -PI * 0.5))
	for index in 2:
		var brace_x := float(index - 1) * CELL
		recipe_value.add_placement(StringName("brace.%d" % index), BRACE,
			_pose(Vector3(brace_x, -0.55, -CELL * 0.35), 0.0))
	if decorated:
		# Decoration is a separate measured construction variant. This prevents
		# plants from silently widening the long-standing structural balcony
		# contract used by older sectional fixtures, while production can prefer
		# this richer version wherever its complete envelope fits.
		var planter_x := -0.78 if back_socket_x == 0 else -0.18
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
		Vector3i(-1, 0, 0), Vector3i(2, 2, 1))
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i(back_socket_x, 0, 0), Vector3i.FORWARD)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i(back_socket_x, 0, 0), Vector3i.FORWARD)
	return recipe_value


static func _wrap_balcony_recipe(recipe_id: StringName, theme: StringName,
		side: int, modules: FabricModuleProgram) -> FabricRecipe:
	## A true L-shaped corner balcony: two cells span the front corner, then one
	## turns along the side facade. This is not the exposed roof of a
	## shifted room. The complete deck, return guards, planters, and braces form
	## one measured occupied recipe and reserve their full 3D clearance.
	assert(side in [-1, 1])
	var corner_x := side
	var front_cells: Array[Vector3i] = [Vector3i.ZERO,
		Vector3i(corner_x, 0, 0)]
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
		var floor_pose := _pose(Vector3(float(cell.x) * CELL + CELL * 0.5,
			0.0, float(cell.z) * CELL), 0.0)
		recipe_value.add_placement(StringName("floor.%d.%d" % [cell.x,
			cell.z]), SETBACK_CAP, modules.walk_aligned_transform(SETBACK_CAP,
				floor_pose, 0.0))
	var parent_edges: Dictionary = {}
	parent_edges[WarrenSpatialGrid._face_key(Vector3i.ZERO,
		Vector3i.FORWARD)] = true
	var side_cell := Vector3i(corner_x, 0, -1)
	var side_to_room := Vector3i.RIGHT if side < 0 else Vector3i.LEFT
	parent_edges[WarrenSpatialGrid._face_key(side_cell, side_to_room)] = true
	var guard_index := 0
	for cell: Vector3i in deck_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if deck_set.has(cell + direction) or parent_edges.has(
					WarrenSpatialGrid._face_key(cell, direction)):
				continue
			var edge_centre := Vector3(float(cell.x) * CELL,
				0.0, float(cell.z) * CELL) + Vector3(direction) * CELL * 0.5
			var yaw := -PI * 0.5 if direction.x != 0 else 0.0
			recipe_value.add_placement(StringName("guard.%02d" % guard_index),
				RAILING, _pose(edge_centre, yaw))
			guard_index += 1
	for index in 2:
		var brace_x := float(index * side) * CELL
		recipe_value.add_placement(StringName("brace.front.%d" % index), BRACE,
			_pose(Vector3(brace_x, -0.55, -CELL * 0.35), 0.0))
	recipe_value.add_placement(&"brace.return", BRACE,
		_pose(Vector3(float(corner_x) * CELL - float(side) * CELL * 0.35,
			-0.55, -CELL), PI * 0.5))
	var planter_x := float(corner_x) * CELL
	recipe_value.add_placement(&"balcony.planter", ROOF_PLANTER,
		_pose(Vector3(planter_x, 0.04, -0.32), 0.0))
	var balcony_flower := ROOF_FLOWER_TALL if theme == &"blue" \
		else TERRACE_PLANT_BROAD if theme == &"amber" else ROOF_FLOWER_PALE
	recipe_value.add_placement(&"balcony.flowers", balcony_flower,
		_pose(Vector3(planter_x, 0.04, -0.40), 0.0))
	recipe_value.walk_cells.assign(deck_cells)
	for cell: Vector3i in deck_cells:
		recipe_value.headroom_cells.append(cell)
		recipe_value.headroom_cells.append(cell + Vector3i.UP)
	recipe_value.inhabited_cells.assign(recipe_value.headroom_cells)
	recipe_value.add_socket(&"room.back", FabricRecipe.SocketKind.ROOM,
		Vector3i.ZERO, Vector3i.FORWARD)
	recipe_value.add_socket(&"bearing.back", FabricRecipe.SocketKind.BEARING,
		Vector3i.ZERO, Vector3i.FORWARD)
	return recipe_value


static func _integrated_cantilever_support_recipe(
		modules: FabricModuleProgram) -> FabricRecipe:
	## One measured 3 m bracket course beneath a room-scale jetty. The parent
	## room remains the occupied construction authority; this zero-cell recipe is
	## an explicit visual/collision attachment derived from the sealed bearing
	## edge. Rotating the authored stair-wall support by a quarter turn makes its
	## 1.94 m long axis project outward from the facade rather than run along it.
	## Two unscaled supports sit beneath the two 1.5 m attachment columns.
	var recipe_value := FabricRecipe.new(&"outcrop.support.bracketed.2", [
		&"visual_attachment", &"cantilever_support", &"bracket_supported",
		&"integrated_room_outcropping",
	], 0)
	for index in 2:
		recipe_value.add_placement(StringName("brace.%d" % index), BRACE,
			_pose(Vector3(float(index) * CELL, -0.55, 0.0), PI * 0.5))
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
	var recipe_value := FabricRecipe.new(&"outcrop.support.bracketed.1", [
		&"visual_attachment", &"cantilever_support", &"bracket_supported",
		&"integrated_room_outcropping", &"terminal_support",
	], 0)
	recipe_value.add_placement(&"brace.0", BRACE,
		_pose(Vector3(0.0, -0.55, 0.0), PI * 0.5))
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
		room_form: StringName) -> StringName:
	## Detail families follow construction style and room width instead of every
	## `.b` storey receiving the same pasted sign. The selection is recipe-local,
	## while town-seed phase selection still decides which storeys receive it.
	match room_form:
		&"square":
			return &"ivy" if theme == &"blue" else &"sign" \
				if theme == &"stone" else &"windowbox"
		&"long":
			return &"clothes" if theme == &"blue" else &"ivy" \
				if theme == &"orange" else &"sign" \
				if theme == &"stone" else &"windowbox"
		&"tower":
			return &"sign" if theme in [&"blue", &"stone"] else &"ivy" \
				if theme == &"amber" else &"windowbox"
		&"slim":
			return &"ivy" if theme == &"blue" else &"sign" \
				if theme == &"orange" else &"clothes" \
				if theme == &"stone" else &"windowbox"
		&"row":
			return &"clothes" if theme == &"blue" else &"ivy" \
				if theme == &"orange" else &"sign" \
				if theme == &"stone" else &"windowbox"
	return &"ivy"


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
