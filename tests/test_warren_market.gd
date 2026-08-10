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
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	if program == null:
		return
	var covered := program.recipe(&"market.covered.00")
	assert_not_null(covered)
	if covered == null:
		return
	assert_true(covered.has_tag(&"covered_market"))
	assert_eq(covered.placements.size(), 2,
		"the bazaar is one atomic canopy-and-stocked-counter composition")
	assert_eq(covered.asset_ids().size(), 2,
		"the covered stall enriches its canopy with a separate market asset")
	assert_eq(covered.terrain_bearing_cells.size(), 8,
		"the compact six-by-three-metre market follows local terrain")


static func _stall_units(plan: SettlementFabricPlan) -> Array[FabricUnit]:
	var out: Array[FabricUnit] = []
	for unit_value: FabricUnit in plan.units:
		if String(unit_value.stable_id).begins_with("volume.market."):
			out.append(unit_value)
	return out
