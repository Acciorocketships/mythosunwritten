extends GutTest
## Town taste knobs task 3: courtyard clearings furnished for their purpose
## (`clearing_deco_density`). Density 0 places nothing; density 1 gives every
## clearing at least two props, none on a walk landing and none overlapping.

func _town(seed_value: int, scale: StringName, density: float) -> Dictionary:
	var profile := WarrenVillageScaleProfile.for_id(scale)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides({&"clearing_count": 3.0,
		&"clearing_deco_density": density})
	var spatial := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
	assert_not_null(spatial)
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric, false)
	var deco := {}
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in (batch.ids as Array).size():
			var id := String(batch.ids[index])
			if not id.begins_with(SettlementFabricAssembler.CLEARING_DECO_PREFIX): continue
			var plot := id.split("/")[1]
			if not deco.has(plot): deco[plot] = []
			deco[plot].append({"asset": asset, "id": id, "box": (batch.transforms[index] as Transform3D) \
				* (fabric.asset_visual_bounds[asset] as AABB)})
	return {"source": source, "fabric": fabric, "deco": deco}

func test_density_zero_places_nothing_and_carries_no_brief() -> void:
	var town := _town(53, &"grand", 0.0)
	assert_true((town.fabric as SettlementFabricPlan).clearing_decor.is_empty())
	assert_true((town.deco as Dictionary).is_empty())

func _assert_furnished(seed_value: int, scale: StringName) -> void:
	var town := _town(seed_value, scale, 1.0)
	var source: WarrenMazeSourcePlan = town.source
	var deco: Dictionary = town.deco
	var clearings := source.plots.filter(func(p: Dictionary) -> bool:
		return WarrenPlotReservations.is_clearing_plot(p))
	assert_gt(clearings.size(), 0, "%d/%s carries clearings" % [seed_value, scale])
	# Every walk landing of the town, as a world-space column box over its band.
	var landings: Array[AABB] = []
	for plot: Dictionary in source.plots:
		if not plot.has("door_walk"): continue
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(plot.door_walk):
			landings.append(AABB(Vector3(cell.x - 0.5, cell.y, cell.z - 0.5) * FabricRecipe.CELL_SIZE,
				Vector3(1.0, 2.0, 1.0) * FabricRecipe.CELL_SIZE).grow(-0.02))
	var all: Array = []
	for plot: Dictionary in clearings:
		var props: Array = deco.get(String(plot.id), [])
		assert_gte(props.size(), 2, "%d/%s %s (%s) gets at least two props" % [seed_value, scale,
			plot.id, plot.get("purpose", &"")])
		all.append_array(props)
	for i in all.size():
		var box: AABB = all[i].box
		for landing: AABB in landings:
			assert_false(box.intersects(landing), "%s stands on a walk landing" % all[i].id)
		for j in range(i + 1, all.size()):
			var same_group := String(all[i].id).get_slice("/", 2) == String(all[j].id).get_slice("/", 2) \
				and String(all[i].id).get_slice("/", 1) == String(all[j].id).get_slice("/", 1)
			if same_group and (String(all[i].id).contains(".goods.") or String(all[j].id).contains(".goods.")):
				continue
			assert_false(SettlementFabricAssembler._boxes_share_volume(box, all[j].box),
				"%s overlaps %s" % [all[i].id, all[j].id])

func test_density_one_furnishes_every_clearing_53_grand() -> void:
	_assert_furnished(53, &"grand")

func test_density_one_furnishes_every_clearing_103_standard() -> void:
	_assert_furnished(103, &"standard")
