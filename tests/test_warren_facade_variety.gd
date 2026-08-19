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
	assert_eq(SettlementFabricProgram.WOOD_DOORS,
		[SettlementFabricProgram.WOOD_DOOR_CLOSED] as Array[StringName],
		"static timber thresholds must all render a closed leaf")
	assert_eq(SettlementFabricProgram.ROCK_DOORS,
		[SettlementFabricProgram.ROCK_DOOR_CLOSED] as Array[StringName],
		"static stone thresholds must all render a closed leaf")


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


func test_timber_boxes_use_baked_handed_panels_on_both_side_faces() -> void:
	## Every source timber panel owns its local -X post. If all four sides use
	## that same handedness, two diagonal corners receive doubled perpendicular
	## posts and the other two receive none. East/west must use baked mirror
	## assets while north/south retain the authored panel and every runtime pose
	## remains a proper rotation.
	assert_not_null(_program)
	for recipe_id: StringName in [
			&"room.upper.blue", &"room.long.upper.orange.a",
			&"room.tower.upper.amber", &"room.slim.upper.blue",
			&"room.row.upper.orange",
	]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, "missing handed-shell recipe %s" % recipe_id)
		if recipe_value == null:
			continue
		var side_count := 0
		var cardinal_count := 0
		for placement: Dictionary in recipe_value.placements:
			var placement_id := String(placement.id)
			if not (placement_id.begins_with("left") \
					or placement_id.begins_with("right") \
					or placement_id.begins_with("west") \
					or placement_id.begins_with("east") \
					or placement_id.begins_with("front") \
					or placement_id.begins_with("back") \
					or placement_id in ["south", "north"]):
				continue
			cardinal_count += 1
			var side := placement_id.begins_with("left") \
				or placement_id.begins_with("right") \
				or placement_id.begins_with("west") \
				or placement_id.begins_with("east")
			var asset_text := String(placement.asset_id)
			assert_eq(asset_text.ends_with(".mirror_x"), side,
				"%s/%s violates clockwise post ownership" % [recipe_id,
					placement_id])
			var pose := placement.transform as Transform3D
			assert_almost_eq(pose.basis.determinant(), 1.0, 0.0001,
				"handed facade variants must not leak negative runtime scale")
			side_count += int(side)
		assert_gt(cardinal_count, 0)
		assert_gt(side_count, 0)


func test_mirrored_facades_preserve_the_source_envelope() -> void:
	for source_id: StringName in [
			&"sfv.fabric.wall.wood.window.001",
			&"sfv.fabric.wall.wood.window.020",
			&"sfv.fabric.wall.wood.plain.005",
			&"sfv.fabric.wall.wood.door.001",
	]:
		var mirror_id := SettlementFabricProgram._mirrored_facade_asset(source_id)
		var source := _catalog.descriptor(source_id)
		var mirror := _catalog.descriptor(mirror_id)
		assert_not_null(source)
		assert_not_null(mirror, "missing baked facade hand %s" % mirror_id)
		if source == null or mirror == null:
			continue
		assert_almost_eq(mirror.measured_aabb.size.x,
			source.measured_aabb.size.x, WIDTH_EPSILON)
		assert_almost_eq(mirror.measured_aabb.size.y,
			source.measured_aabb.size.y, WIDTH_EPSILON)
		assert_almost_eq(mirror.measured_aabb.size.z,
			source.measured_aabb.size.z, WIDTH_EPSILON)


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


func test_every_segmented_footprint_has_three_exact_building_styles() -> void:
	## Segmentation owns the room footprint and topology. Style selection may
	## change complete authored wall/door/detail compositions, but it may not
	## mutate the segment's solids, inhabited volume, sockets, or entrances.
	assert_not_null(_program)
	var forms: Array[Dictionary] = [
		{"prefix": "room.upper.blue", "long": false},
		{"prefix": "room.tower.upper.blue", "long": false},
		{"prefix": "room.slim.upper.blue", "long": false},
		{"prefix": "room.row.upper.blue", "long": false},
		{"prefix": "room.long.upper.blue", "long": true},
	]
	for form: Dictionary in forms:
		var reference: FabricRecipe
		var style_signatures: Dictionary = {}
		for facade_phase in SettlementFabricProgram.FACADE_PHASE_COUNT:
			var suffix := SettlementFabricProgram._facade_phase_suffix(
				facade_phase, bool(form.long))
			var recipe_id := StringName("%s%s%s" % [String(form.prefix),
				"." if bool(form.long) else "", suffix])
			var recipe_value := _program.recipe(recipe_id)
			assert_not_null(recipe_value, "missing segmented style %s" % recipe_id)
			if recipe_value == null:
				continue
			if reference == null:
				reference = recipe_value
			else:
				assert_eq(recipe_value.solid_cells, reference.solid_cells,
					"%s changed the segmented structural footprint" % recipe_id)
				assert_eq(recipe_value.inhabited_cells, reference.inhabited_cells,
					"%s changed the segmented inhabited volume" % recipe_id)
				assert_eq(recipe_value.sockets, reference.sockets,
					"%s changed the segmented connection contract" % recipe_id)
				assert_eq(recipe_value.entrances, reference.entrances,
					"%s changed the segmented entrance contract" % recipe_id)
			if facade_phase % 2 == 0:
				var assignment: Array[String] = []
				for placement: Dictionary in recipe_value.placements:
					assignment.append("%s=%s" % [String(placement.id),
						String(placement.asset_id)])
				style_signatures["|".join(assignment)] = true
		assert_eq(style_signatures.size(),
			SettlementFabricProgram.BUILDING_STYLE_COUNT,
			"%s still collapses segmentation to one repeated shell" % form.prefix)


func test_phase_b_facades_use_multiple_measured_detail_families() -> void:
	assert_eq(SettlementFabricProgram._upper_facade_detail_kind(
		&"orange", &"square"), &"windowbox")
	assert_eq(SettlementFabricProgram._upper_facade_detail_kind(
		&"blue", &"long"), &"clothes")
	assert_eq(SettlementFabricProgram._upper_facade_detail_kind(
		&"amber", &"tower"), &"ivy")
	assert_eq(SettlementFabricProgram._upper_facade_detail_kind(
		&"orange", &"slim"), &"sign")
	var detail_assets: Dictionary = {}
	for recipe_id: StringName in [&"room.upper.orange.b",
			&"room.long.upper.blue.b", &"room.tower.upper.amber.b",
			&"room.slim.upper.orange.b"]:
		var recipe_value := _program.recipe(recipe_id)
		assert_not_null(recipe_value, "missing decorated recipe %s" % recipe_id)
		if recipe_value == null:
			continue
		assert_true(recipe_value.has_tag(&"facade_detail"),
			"%s lost its measured facade detail role" % recipe_id)
		for placement: Dictionary in recipe_value.placements:
			var asset_id := StringName(placement.asset_id)
			if asset_id in [SettlementFabricProgram.FACADE_IVY,
					SettlementFabricProgram.FACADE_CLOTHES,
					SettlementFabricProgram.FACADE_SIGN,
					SettlementFabricProgram.ROOF_PLANTER]:
				detail_assets[asset_id] = true
	assert_eq(detail_assets.size(), 4,
		"the reviewed phase-B sample should contain ivy, laundry, sign, and planter")
	var planted := _program.recipe(&"room.upper.orange.b")
	assert_true(planted.has_tag(&"planted_facade"))
	var planted_asset_ids := planted.asset_ids()
	assert_true(planted_asset_ids.has(SettlementFabricProgram.TERRACE_PLANT_MID))


func test_addressed_facades_never_place_soft_props_across_the_door() -> void:
	## Ivy, signs, window boxes, and especially the 3.135 m clothesline are
	## valuable on windowed upper facades. On an addressed recipe their shared
	## front-face anchor crosses the authored arch even when the exact public
	## landing and guard opening are otherwise correct.
	assert_not_null(_program)
	var addressed_count := 0
	for recipe_value: FabricRecipe in _program.recipes():
		if not recipe_value.has_tag(&"generated_building") \
				or recipe_value.entrances.is_empty():
			continue
		addressed_count += 1
		assert_false(recipe_value.has_tag(&"facade_detail"),
			"%s may not decorate its exterior door plane" \
				% recipe_value.recipe_id)
		for placement: Dictionary in recipe_value.placements:
			assert_false(StringName(placement.asset_id) in [
				SettlementFabricProgram.FACADE_IVY,
				SettlementFabricProgram.FACADE_CLOTHES,
				SettlementFabricProgram.FACADE_SIGN,
				SettlementFabricProgram.ROOF_PLANTER,
			], "%s/%s crosses an addressed doorway" % [
				recipe_value.recipe_id, placement.id])
	assert_gt(addressed_count, 0)


func test_the_market_pool_is_the_reviewed_stocked_seven() -> void:
	## The other loose stall pieces are not complete stocked-market envelopes;
	## only these seven prefabs are safe atomic fabric recipes.
	assert_eq(SettlementFabricProgram.MARKET_STALLS.size(), 7,
		"the market pool drifted away from the reviewed stocked prefabs")
	var distinct: Dictionary = {}
	for asset_id: StringName in SettlementFabricProgram.MARKET_STALLS:
		distinct[asset_id] = true
	assert_eq(distinct.size(), SettlementFabricProgram.MARKET_STALLS.size(),
		"the market stall pool repeats an asset")


func test_every_market_stall_is_a_reviewed_stall_prefab() -> void:
	for asset_id: StringName in SettlementFabricProgram.MARKET_STALLS:
		var descriptor := _catalog.descriptor(asset_id)
		assert_not_null(descriptor, "uncatalogued stall %s" % asset_id)
		if descriptor == null:
			continue
		assert_true(descriptor.tags.has(&"stall"),
			"%s is not tagged as a stall" % asset_id)


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


## A wider pool must widen CHOICE, not multiply SEARCH. Both properties below
## pin that separation at the two places this wave crossed it, because both
## regressions were invisible to every other suite: they cost time, not
## correctness, and a slow solve fails no assertion.


func test_a_placement_offers_no_more_stall_families_than_the_pre_wave_pool()\
		-> void:
	## Each candidate WarrenMarketSolver emits costs _admit_markets one complete
	## WarrenFabricCompiler.solve whether it is admitted or refused, so the
	## per-placement family walk multiplies the whole market pass. Seven is the
	## width the pool itself had before the bake wave, so this is the count the
	## reviewed code already paid -- and it may not grow again with the pool.
	assert_lte(WarrenMarketSolver.MAX_FAMILIES_PER_PLACEMENT, 7,
		"one placement now costs the market pass more than it did pre-wave")
	assert_gte(WarrenMarketSolver.MAX_FAMILIES_PER_PLACEMENT, 2,
		"a placement with no alternative family cannot recover from a refusal")


func test_the_bounded_family_walk_still_reaches_every_stall_in_the_pool()\
		-> void:
	## The bound is only free if the POOL is still what a town draws from. The
	## window's start is a function of the placement origin and the world seed,
	## so it slides: this asserts the union of windows over ordinary placement
	## origins covers every entry, for each of several seeds independently --
	## i.e. no stall is unreachable in any given town.
	var pool := SettlementFabricProgram.MARKET_STALLS.size()
	for world_seed in [0, 7, 11, 4242]:
		var reached: Dictionary = {}
		for x in range(-12, 13):
			for z in range(-12, 13):
				var first := WarrenMarketSolver._family(Vector3i(x, 0, z),
					world_seed)
				for offset in mini(WarrenMarketSolver.MAX_FAMILIES_PER_PLACEMENT,
						pool):
					reached[posmod(first + offset, pool)] = true
		assert_eq(reached.size(), pool,
			"seed %d can never draw %d of the %d stalls" % [world_seed,
				pool - reached.size(), pool])


func test_the_style_invariant_envelope_union_repeats_no_box() -> void:
	## parcels_are_visually_compatible compares every box of one house against
	## every box of the other, so a duplicate box costs the pair search
	## QUADRATICALLY while proving nothing -- an overlap against a repeat is an
	## overlap that was already found. Almost every style leaves the geometry
	## alone (the facade families draw different authored walls at identical
	## widths), so the raw union over the style table is mostly repeats and the
	## table's width was silently a search multiplier.
	var proposal := {
		"stable_id": &"style.union.probe",
		"kind": &"tower",
		"origin": Vector3i.ZERO,
		"yaw_quarters": 0,
		"storeys": 2,
		"route_y": 0,
	}
	var bounds := WarrenAssetCompiler._style_invariant_proposal_bounds(proposal,
		_program)
	assert_gt(bounds.size(), 0, "the probe proposal compiled no envelope")
	var seen: Dictionary = {}
	for box: AABB in bounds:
		assert_false(seen.has(box), "the style union repeats %s" % box)
		seen[box] = true


func test_the_style_invariant_envelope_union_still_covers_every_style() -> void:
	## The dedup may only remove REPEATS. Any box a legal style produces must
	## still be in the union, or a later colour choice could make two roofs
	## intersect on a pair the search qualified.
	var proposal := {
		"stable_id": &"style.union.probe",
		"kind": &"tower",
		"origin": Vector3i.ZERO,
		"yaw_quarters": 0,
		"storeys": 2,
		"route_y": 0,
	}
	var union: Dictionary = {}
	for box: AABB in WarrenAssetCompiler._style_invariant_proposal_bounds(
			proposal, _program):
		union[box] = true
	for theme: StringName in [&"blue", &"orange", &"amber", &"stone"]:
		for roof_theme: StringName in [&"blue", &"orange"]:
			for facade_phase in 2:
				var styled := proposal.duplicate(true)
				styled["theme"] = theme
				styled["roof_theme"] = roof_theme
				styled["facade_phase"] = facade_phase
				for box: AABB in WarrenAssetCompiler._proposal_component_bounds(
						styled, _program):
					assert_true(union.has(box),
						"%s/%s/%d lost the envelope %s" % [theme, roof_theme,
							facade_phase, box])
