extends GutTest

## Focused fixtures for the typed interstitial_join transaction: a
## sub-tolerance residual course trapped between occupied walls must classify
## as exactly one authored closure (stepped shoulder lean-to or sealed
## infill), and anything without a complete closure must refuse with a typed
## reason instead of silently exposing two unrelated facade meshes.


func _grid_with_massif(size: Vector3i) -> WarrenSpatialGrid:
	var grid := WarrenSpatialGrid.new(Vector3i.ZERO, size)
	var cells: Array[Vector3i] = []
	for x in size.x:
		for y in size.y:
			for z in size.z:
				cells.append(Vector3i(x, y, z))
	var massif := grid.begin_transaction(&"massif")
	assert_true(massif.assign_use(cells, WarrenSpatialGrid.Use.ALLOCATABLE,
		&"massif"))
	assert_true(massif.commit())
	return grid


func _claim_private(grid: WarrenSpatialGrid, owner: StringName,
		cells: Array[Vector3i]) -> void:
	var tx := grid.begin_transaction(owner)
	assert_true(tx.assign_use(cells, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
		owner), "could not claim %s for %s" % [cells, owner])
	assert_true(tx.commit())


func _column(x: int, z: int, y_top: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in range(0, y_top + 1):
		out.append(Vector3i(x, y, z))
	return out


func test_two_cell_shoulder_between_offset_walls_is_a_stepped_lean_to() -> void:
	var grid := _grid_with_massif(Vector3i(6, 6, 6))
	# Lower building fills z<=1 to y=3 (so it continues above the slot);
	# the neighbor fills z=3 only to y=1, leaving the slot (x 1..2, y 2, z 2)
	# with bearing below (its own mass at y<=1 under the slot column).
	for x in range(1, 3):
		_claim_private(grid, &"spatial.parcel.solid.0001.part00",
			_column(x, 1, 3))
		_claim_private(grid, &"spatial.parcel.solid.0002.part00",
			_column(x, 3, 2))
		_claim_private(grid, &"spatial.parcel.solid.0001.part01",
			_column(x, 2, 1))
	var slot: Array[Vector3i] = [Vector3i(1, 2, 2), Vector3i(2, 2, 2)]
	for cell: Vector3i in slot:
		assert_true(WarrenVolumetricSolver._is_one_cell_interstitial_gap(
			grid, cell), "%s must audit as a one-cell interstitial gap" % cell)
	var classified := WarrenSpatialFeatureSolver._classify_interstitial_run(
		grid, {}, slot, &"z")
	assert_eq(StringName(classified.get("class", &"")), &"stepped_shoulder")
	assert_eq(int(classified.get("wall_side", 0)), -1,
		"the continuing upper wall is on the negative z side")
	assert_eq(StringName(classified.get("bearing_kind", &"")), &"below")


func test_slit_between_two_continuing_walls_is_sealed_infill() -> void:
	var grid := _grid_with_massif(Vector3i(6, 6, 6))
	for x in range(1, 3):
		_claim_private(grid, &"spatial.parcel.solid.0003.part00",
			_column(x, 1, 4))
		_claim_private(grid, &"spatial.parcel.solid.0004.part00",
			_column(x, 3, 4))
		_claim_private(grid, &"spatial.parcel.solid.0003.part01",
			_column(x, 2, 1))
	var slot: Array[Vector3i] = [Vector3i(1, 2, 2), Vector3i(2, 2, 2)]
	var classified := WarrenSpatialFeatureSolver._classify_interstitial_run(
		grid, {}, slot, &"z")
	assert_eq(StringName(classified.get("class", &"")), &"sealed_infill",
		"a slit flanked by two continuing walls is never a lean-to")


func test_strip_buried_under_bridging_mass_is_buried_sealed_infill() -> void:
	var grid := _grid_with_massif(Vector3i(6, 6, 6))
	for x in range(1, 3):
		_claim_private(grid, &"spatial.parcel.solid.0005.part00",
			_column(x, 1, 2))
		_claim_private(grid, &"spatial.parcel.solid.0006.part00",
			_column(x, 3, 2))
		# The bridging storey spans the slit from above.
		_claim_private(grid, &"spatial.parcel.solid.0005.part01",
			[Vector3i(x, 3, 1), Vector3i(x, 3, 2), Vector3i(x, 3, 3)])
	var slot: Array[Vector3i] = [Vector3i(1, 2, 2), Vector3i(2, 2, 2)]
	var classified := WarrenSpatialFeatureSolver._classify_interstitial_run(
		grid, {}, slot, &"z")
	assert_eq(StringName(classified.get("class", &"")), &"sealed_infill")
	assert_true(bool(classified.get("buried", false)),
		"a covered strip must omit its cap so no plate fights the soffit")


func test_shoulder_may_not_bear_on_an_earlier_feature_strip() -> void:
	var grid := _grid_with_massif(Vector3i(6, 6, 6))
	for x in range(1, 3):
		_claim_private(grid, &"spatial.parcel.solid.0007.part00",
			_column(x, 1, 3))
		_claim_private(grid, &"spatial.parcel.solid.0008.part00",
			_column(x, 3, 1))
		# The support below the slot is an earlier sealed strip, not room mass.
		_claim_private(grid, &"spatial.feature.interstitial_join.00",
			_column(x, 2, 1))
	var slot: Array[Vector3i] = [Vector3i(1, 2, 2), Vector3i(2, 2, 2)]
	var classified := WarrenSpatialFeatureSolver._classify_interstitial_run(
		grid, {}, slot, &"z")
	assert_ne(StringName(classified.get("class", &"")), &"stepped_shoulder",
		"lean-to bearing requires real room mass with authored top sockets")


func test_flush_parapet_slot_seals_side_anchored() -> void:
	var grid := _grid_with_massif(Vector3i(6, 6, 6))
	# One-band walltops on both sides, nothing continuing above, air below:
	# the course seals flush as a joined parapet, side-anchored because no
	# room mass sits beneath it.
	for x in range(1, 3):
		_claim_private(grid, &"spatial.parcel.solid.0009.part00",
			[Vector3i(x, 2, 1)])
		_claim_private(grid, &"spatial.parcel.solid.0010.part00",
			[Vector3i(x, 2, 3)])
	var slot: Array[Vector3i] = [Vector3i(1, 2, 2), Vector3i(2, 2, 2)]
	var classified := WarrenSpatialFeatureSolver._classify_interstitial_run(
		grid, {}, slot, &"z")
	assert_eq(StringName(classified.get("class", &"")), &"sealed_infill",
		"two flush walltops join as one deliberate parapet course")
	assert_false(bool(classified.get("buried", true)),
		"an open-sky parapet keeps its flush cap")
	assert_eq(StringName(classified.get("bearing_kind", &"")), &"side")


func test_interstitial_chunks_split_into_authored_lengths() -> void:
	var run: Array[Vector3i] = []
	for z in range(0, 5):
		run.append(Vector3i(1, 2, z))
	var shoulder_chunks := WarrenSpatialFeatureSolver._interstitial_chunks(
		run, true)
	assert_eq(shoulder_chunks.size(), 2)
	assert_eq((shoulder_chunks[0] as Array).size(), 4,
		"shoulders use the largest even authored bay")
	assert_eq((shoulder_chunks[1] as Array).size(), 1,
		"the odd remainder becomes a capped sealed end")
	var seal_chunks := WarrenSpatialFeatureSolver._interstitial_chunks(
		run, false)
	assert_eq(seal_chunks.size(), 3)
	assert_eq((seal_chunks[0] as Array).size(), 2)
	assert_eq((seal_chunks[2] as Array).size(), 1)


func test_sealed_infill_recipes_are_registered_measured_constructions() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert_not_null(program)
	for recipe_id: StringName in [&"interstitial.seal.1.capped",
			&"interstitial.seal.1.buried", &"interstitial.seal.2.capped",
			&"interstitial.seal.2.buried"]:
		var recipe := program.recipe(recipe_id)
		assert_not_null(recipe, "missing %s" % recipe_id)
		if recipe == null:
			continue
		assert_true(recipe.has_tag(&"interstitial_join"))
		assert_eq(recipe.bearing_parent_count, 0,
			"sealed infill is anchored mass and declares no bearing parent")
		assert_eq(recipe.solid_cells.size(),
			int(String(recipe_id).get_slice(".", 2)),
			"the strip's solid cells exactly cover its slot")
