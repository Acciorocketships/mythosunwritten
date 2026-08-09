extends GutTest

## The bake wave grew the catalog from 177 to 375 assets; this suite pins the
## contract that lets the facade tables consume the new wall modules WITHOUT
## moving any geometry.
##
## `FabricModuleProgram.facade_aligned_transform` pins a wall module's OUTER
## face to the wall plane, so a module no wider than the widest module its
## family already places cannot grow a recipe's clearance envelope. That is the
## whole safety argument for widening the pools: the parcel search reads
## clearance envelopes through `WarrenAssetCompiler.parcels_are_visually_
## compatible`, so an unchanged envelope means an unchanged search. These tests
## measure the widths against the catalog rather than trusting the claim, and
## pin the envelopes of the rooms the pools feed.

const WOOD_MODULE_WIDTH := 3.0
## The widest rock module the pre-wave pool already placed on a wall face
## (`sfv.fabric.wall.rock.window.010`). Doors have their own, wider precedent.
const ROCK_MODULE_WIDTH := 3.086
const ROCK_DOOR_WIDTH := 3.104
const MODULE_HEIGHT := 3.041
const WIDTH_EPSILON := 0.001

static var _program: SettlementFabricProgram
static var _catalog: EnvironmentCatalog


func before_all() -> void:
	_catalog = EnvironmentCatalog.load_default()
	_program = SettlementFabricProgram.compile(_catalog)


func _measured(asset_id: StringName) -> AABB:
	var descriptor := _catalog.descriptor(asset_id)
	assert_not_null(descriptor, "uncatalogued facade module %s" % asset_id)
	return AABB() if descriptor == null else descriptor.measured_aabb


func test_every_timber_facade_module_is_exactly_one_bay_wide() -> void:
	## A timber module wider than 3.000 m would push a room's clearance box past
	## its own footprint and could newly conflict with a corner neighbour.
	for pool: Array[StringName] in [SettlementFabricProgram.WOOD_FACADE_BLUE,
			SettlementFabricProgram.WOOD_FACADE_ORANGE,
			SettlementFabricProgram.WOOD_FACADE_AMBER,
			SettlementFabricProgram.WOOD_DOORS]:
		for asset_id: StringName in pool:
			var bounds := _measured(asset_id)
			assert_almost_eq(bounds.size.x, WOOD_MODULE_WIDTH, WIDTH_EPSILON,
				"%s is not one 3 m bay wide" % asset_id)
			assert_lt(bounds.size.y, MODULE_HEIGHT,
				"%s is taller than one storey" % asset_id)


func test_every_rock_facade_module_stays_within_the_shipped_width() -> void:
	for asset_id: StringName in SettlementFabricProgram.ROCK_FACADE:
		var bounds := _measured(asset_id)
		assert_lt(bounds.size.x, ROCK_MODULE_WIDTH,
			"%s is wider than the widest shipped rock wall" % asset_id)
		assert_lt(bounds.size.y, MODULE_HEIGHT,
			"%s is taller than one storey" % asset_id)
	for asset_id: StringName in SettlementFabricProgram.ROCK_DOORS:
		var bounds := _measured(asset_id)
		assert_lt(bounds.size.x, ROCK_DOOR_WIDTH,
			"%s is wider than the widest shipped rock door" % asset_id)


func test_the_frozen_phases_still_name_the_pre_wave_modules() -> void:
	## Phases 0-2 are the pre-wave vocabulary in its pre-wave order, so any
	## recipe asking for a bare phase renders what it rendered before the wave.
	assert_eq(SettlementFabricProgram.WOOD_FACADE_BLUE.slice(0, 3),
		[&"sfv.fabric.wall.wood.window.001", &"sfv.fabric.wall.wood.window.040",
			&"sfv.fabric.wall.wood.window.010"] as Array[StringName])
	assert_eq(SettlementFabricProgram.WOOD_FACADE_ORANGE.slice(0, 3),
		[&"sfv.fabric.wall.wood.window.020", &"sfv.fabric.wall.wood.window.060",
			&"sfv.fabric.wall.wood.window.010"] as Array[StringName])
	assert_eq(SettlementFabricProgram.ROCK_FACADE.slice(0, 3),
		[&"sfv.fabric.wall.rock.window.010", &"sfv.fabric.wall.rock.plain.001",
			&"sfv.fabric.wall.rock.window.010"] as Array[StringName])
	assert_eq(SettlementFabricProgram.WOOD_DOORS[0],
		&"sfv.fabric.wall.wood.door.001")
	assert_eq(SettlementFabricProgram.ROCK_DOORS[0],
		&"sfv.fabric.wall.rock.door.005")


func test_each_timber_family_offers_at_least_eight_distinct_modules() -> void:
	for pool: Array[StringName] in [SettlementFabricProgram.WOOD_FACADE_BLUE,
			SettlementFabricProgram.WOOD_FACADE_ORANGE,
			SettlementFabricProgram.WOOD_FACADE_AMBER]:
		var distinct: Dictionary = {}
		for asset_id: StringName in pool:
			distinct[asset_id] = true
		assert_gte(distinct.size(), 8,
			"a timber family still offers fewer than eight wall modules")


func test_a_third_upper_facade_family_carries_its_own_modules() -> void:
	## Two colours leave the streetscape graph-colouring no move on a degree-2
	## neighbourhood. The third family is only worth having if it is genuinely
	## different art rather than the same pool re-phased.
	assert_eq(WarrenAssetCompiler.UPPER_FACADE_FAMILIES.size(), 3)
	assert_true(WarrenAssetCompiler.UPPER_FACADE_FAMILIES.has(&"amber"))
	var shared := 0
	for asset_id: StringName in SettlementFabricProgram.WOOD_FACADE_AMBER:
		if SettlementFabricProgram.WOOD_FACADE_BLUE.has(asset_id) \
				or SettlementFabricProgram.WOOD_FACADE_ORANGE.has(asset_id):
			shared += 1
	assert_lte(shared, 1,
		"the amber family is mostly a re-phasing of the other two pools")


func test_a_square_room_draws_a_different_module_on_each_face() -> void:
	## The single biggest source of "one repeated wall texture": the square room
	## used to stamp ONE window module on all four faces.
	assert_not_null(_program)
	for recipe_id: StringName in [&"room.upper.blue", &"room.upper.orange",
			&"room.upper.amber", &"room.base.rock.closed"]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, "missing recipe %s" % recipe_id)
		if recipe_value == null:
			continue
		var faces: Dictionary = {}
		for placement: Dictionary in recipe_value.placements:
			var placement_id := String(StringName(placement.id))
			for face: String in ["front.0", "back.0", "left.0", "right.0"]:
				if placement_id == face:
					faces[StringName(placement.asset_id)] = true
		assert_gte(faces.size(), 3,
			"%s still repeats one wall module around its shell" % recipe_id)


func test_widening_the_pools_left_every_room_envelope_where_it_was() -> void:
	## Pinned from the pre-wave compile. If a widened pool ever admits a module
	## that projects or over-spans, these boxes move and the parcel search this
	## wave promised not to touch changes with them.
	assert_not_null(_program)
	var expected := {
		&"room.upper.blue": AABB(Vector3(-3.7510, -0.1611, -3.7500),
			Vector3(6.0010, 3.1611, 6.0000)),
		&"room.upper.orange": AABB(Vector3(-3.7510, -0.1611, -3.7500),
			Vector3(6.0010, 3.1611, 6.0000)),
		&"room.upper.stone": AABB(Vector3(-3.7926, -0.1611, -3.7926),
			Vector3(6.0852, 3.1611, 6.0852)),
		&"room.base.rock": AABB(Vector3(-3.8017, -0.1611, -3.7926),
			Vector3(6.0943, 3.2011, 6.0852)),
		&"room.tower.upper.blue": AABB(Vector3(-2.2510, -0.1611, -2.2500),
			Vector3(3.0010, 3.1611, 3.0000)),
		&"room.slim.upper.orange": AABB(Vector3(-2.2510, -0.1611, -3.7500),
			Vector3(3.0010, 3.1611, 6.0000)),
		&"room.long.upper.blue.a": AABB(Vector3(-3.7510, -0.1611, -5.2500),
			Vector3(6.0010, 3.1611, 9.0000)),
	}
	for recipe_id: StringName in expected.keys():
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, "missing recipe %s" % recipe_id)
		if recipe_value == null:
			continue
		var actual := recipe_value.local_clearance_bounds
		var target := expected[recipe_id] as AABB
		assert_almost_eq(actual.position.x, target.position.x, 0.001,
			"%s clearance x origin moved" % recipe_id)
		assert_almost_eq(actual.position.z, target.position.z, 0.001,
			"%s clearance z origin moved" % recipe_id)
		assert_almost_eq(actual.size.x, target.size.x, 0.001,
			"%s clearance width moved" % recipe_id)
		assert_almost_eq(actual.size.z, target.size.z, 0.001,
			"%s clearance depth moved" % recipe_id)


func test_the_stone_shells_that_moved_stay_inside_the_overlap_tolerance() -> void:
	## Three masonry shells DID move: the per-face spread replaced a 1.770 m
	## half-bay panel (`wall.rock.plain.001`) with a full 3.085 m module on faces
	## whose only other module was that panel, so their clearance box grew by up
	## to 0.043 m. That is the whole measured delta of this wave outside new
	## recipes -- every timber shell is byte-identical.
	##
	## It is safe for exactly one reason, and this test is that reason rather
	## than the argument for it: two corner-adjacent 6 m houses overlap by
	## `2 * (width/2) - 6.0`, and SettlementFabricPlan only calls an overlap a
	## conflict past 0.10 m on all three axes. Any future module that pushed a
	## shell past that turns a corner-adjacent pair the search accepts today into
	## one it refuses, which is precisely the route-first change this wave
	## promised not to make.
	assert_not_null(_program)
	var footprints := {
		&"room.upper.stone.b": Vector2(6.0, 6.0),
		&"room.upper.address.stone.b": Vector2(6.0, 6.0),
		&"room.long.base.rock.closed": Vector2(6.0, 9.0),
		&"room.upper.stone": Vector2(6.0, 6.0),
		&"room.base.rock": Vector2(6.0, 6.0),
	}
	for recipe_id: StringName in footprints.keys():
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, "missing recipe %s" % recipe_id)
		if recipe_value == null:
			continue
		var footprint := footprints[recipe_id] as Vector2
		var bounds := recipe_value.local_clearance_bounds
		assert_lte(bounds.size.x - footprint.x, 0.10,
			"%s now overhangs its own footprint in x by more than the "
			% recipe_id + "corner-overlap tolerance")
		# Z is deliberately exempt on the `.b` shells: their authored facade
		# detail (ivy, laundry, tavern sign) has always projected off the front
		# face, and both the pre-wave and post-wave boxes exceed the tolerance
		# there. Only shells with no such detail are checked on both axes.
		if not String(recipe_id).ends_with(".b"):
			assert_lte(bounds.size.z - footprint.y, 0.10,
				"%s now overhangs its own footprint in z by more than the "
				% recipe_id + "corner-overlap tolerance")


func test_the_amber_family_compiles_a_complete_recipe_set() -> void:
	## StaggeredFabricCompiler builds recipe ids by string, so a missing amber
	## variant would surface as a null recipe deep inside a town solve.
	assert_not_null(_program)
	for prefix: String in ["room.upper", "room.upper.address",
			"room.tower.upper", "room.tower.upper.address",
			"room.slim.upper", "room.slim.upper.address"]:
		for suffix: String in ["", ".b"]:
			var recipe_id := StringName("%s.amber%s" % [prefix, suffix])
			assert_not_null(_program.recipe(recipe_id),
				"missing %s" % recipe_id)
	for prefix: String in ["room.long.upper", "room.long.upper.address"]:
		for suffix: String in [".a", ".b"]:
			var recipe_id := StringName("%s.amber%s" % [prefix, suffix])
			assert_not_null(_program.recipe(recipe_id),
				"missing %s" % recipe_id)


func test_the_chimney_pool_offers_more_than_one_stack() -> void:
	for asset_id: StringName in SettlementFabricProgram.ROOF_CHIMNEYS:
		var descriptor := _catalog.descriptor(asset_id)
		assert_not_null(descriptor, "uncatalogued chimney %s" % asset_id)
		if descriptor == null:
			continue
		assert_true(descriptor.tags.has(&"chimney"),
			"%s is not tagged as a chimney" % asset_id)
	assert_gte(SettlementFabricProgram.ROOF_CHIMNEYS.size(), 3,
		"the roof still has one chimney silhouette")
