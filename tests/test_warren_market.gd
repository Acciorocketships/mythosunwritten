extends GutTest

## Market stalls are part of the urban fabric: every accepted stall backs onto
## or flanks real building mass. A row of stalls strung along the open
## approach road reads as a detached camp, not a town market.

const PROBE_SEEDS := 4

static var _built: WarrenBuiltTownPlan
static var _searched := false


func _town_with_stalls() -> WarrenBuiltTownPlan:
	if _searched:
		return _built
	_searched = true
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert(program != null)
	for world_seed in PROBE_SEEDS:
		var candidate := WarrenBuiltTownSolver.solve(world_seed, program)
		if candidate == null:
			continue
		if _stall_units(candidate.fabric).size() > 0:
			_built = candidate
			break
	return _built


func test_probe_seed_produces_a_market_town() -> void:
	assert_not_null(_town_with_stalls(),
		"no probe seed accepted a town containing market stalls")


func test_every_stall_backs_onto_building_mass() -> void:
	var built := _town_with_stalls()
	if built == null:
		return
	var plan := built.fabric
	# Only non-market mass counts: a stall trivially neighbours its own cells
	# and other stalls, and a stall-beside-stall row is exactly the detached
	# camp this contract forbids.
	var solid_columns: Dictionary = {}
	for unit_value: FabricUnit in plan.units:
		if String(unit_value.stable_id).begins_with("volume.market."):
			continue
		var recipe_value := plan.recipe(unit_value.recipe_id)
		if recipe_value == null:
			continue
		for local_cell: Vector3i in recipe_value.solid_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			var column := Vector2i(cell.x, cell.z)
			if not solid_columns.has(column):
				solid_columns[column] = [] as Array[int]
			(solid_columns[column] as Array[int]).append(cell.y)
	for unit_value: FabricUnit in _stall_units(plan):
		var recipe_value := plan.recipe(unit_value.recipe_id)
		var near_mass := false
		for local_cell: Vector3i in recipe_value.solid_cells:
			var world_cell := FabricRecipe.transform_cell(local_cell,
				unit_value.lattice_origin, unit_value.yaw_quarters)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var levels := solid_columns.get(
						Vector2i(world_cell.x + dx, world_cell.z + dz),
						[]) as Array
					for level_value: Variant in levels:
						if absi(int(level_value) - world_cell.y) <= 4:
							near_mass = true
		assert_true(near_mass,
			("stall %s stands in the open with no building mass within one " \
			+ "module; markets belong against the fabric") % unit_value.stable_id)


func test_covered_market_is_one_local_street_episode() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert_not_null(program)
	if program == null:
		return
	var covered := program.recipe(&"market.covered.00")
	assert_not_null(covered)
	if covered == null:
		return
	assert_true(covered.has_tag(&"covered_market"))
	assert_eq(covered.placements.size(), 4,
		"the bazaar is one atomic canopy, counter, and hanging-goods composition")
	assert_eq(covered.asset_ids().size(), 4,
		"the covered market uses four distinct reviewed market pieces")
	assert_eq(covered.terrain_bearing_cells.size(), 8,
		"the compact six-by-three-metre market follows local terrain exactly")
	# The four public cells are the two centre columns. A semantic aisle is not
	# enough: every stocked piece must leave its complete player-height prism
	# physically empty. This caught the former fish counter placed squarely in
	# the route despite all topology tests passing.
	var aisle_clearance := AABB(Vector3(-2.25, 0.0, -2.25),
		Vector3(3.0, 1.8, 3.0))
	var stocked_piece_count := 0
	for placement: Dictionary in covered.placements:
		if StringName(placement.id) not in [&"stocked.counter",
				&"stocked.hanging", &"stocked.wheel"]:
			continue
		stocked_piece_count += 1
		var descriptor := catalog.descriptor(StringName(placement.asset_id))
		assert_not_null(descriptor)
		if descriptor == null:
			continue
		var placed_bounds := (placement.transform as Transform3D) \
			* descriptor.measured_aabb
		assert_false(placed_bounds.intersects(aisle_clearance),
			"%s intrudes into the exact two-lane player clearance" % placement.id)
	assert_eq(stocked_piece_count, 3,
		"counter and both overhead goods are part of the atomic bazaar")


static func _stall_units(plan: SettlementFabricPlan) -> Array[FabricUnit]:
	var out: Array[FabricUnit] = []
	for unit_value: FabricUnit in plan.units:
		if String(unit_value.stable_id).begins_with("volume.market."):
			out.append(unit_value)
	return out
