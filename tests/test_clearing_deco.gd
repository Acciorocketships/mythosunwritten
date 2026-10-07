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
				* SettlementFabricAssembler.clearing_deco_envelope(asset,
					fabric.asset_visual_bounds[asset] as AABB)})
	return {"source": source, "fabric": fabric, "deco": deco, "volume": spatial.source_volume}

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

func _kept_walk_cells(volume: WarrenVolumePlan, source: WarrenMazeSourcePlan) -> Dictionary:
	## Every walk cell a prop must stay off, derived independently of the
	## brief: each clearing's ring (green: floor minus lawn) or ringless walk
	## (`_ringless_court_walk`: landings, street mouths, strips), and every
	## door landing in town. Walk-band cells.
	var landings := {}
	for plot: Dictionary in source.plots:
		if not plot.has("door_walk"): continue
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(plot.door_walk): landings[cell] = true
	var planting := WarrenVolumetricSolver._maze_court_planting_cells(volume)
	var out := landings.duplicate()
	for plot: Dictionary in source.plots:
		if not WarrenPlotReservations.is_clearing_plot(plot): continue
		var floor_cells := {}
		for column: Vector2i in WarrenMazeSourcePlan.deck_flat_columns(plot):
			for cell: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(column.x, plot.floor, column.y)):
				floor_cells[cell] = true
		if WarrenPlotReservations.is_green_court(plot):
			for cell: Vector3i in floor_cells:
				if not planting.has(cell): out[cell] = true
		else:
			out.merge(WarrenVolumetricSolver._ringless_court_walk(source, plot, floor_cells, landings))
	return out

func _assert_props_stay_off_the_walk(seed_value: int, scale: StringName) -> void:
	var town := _town(seed_value, scale, 1.0)
	var walk := _kept_walk_cells(town.volume, town.source)
	var margin := SettlementFabricAssembler.CLEARING_DECO_WALK_MARGIN
	assert_gt(margin, TraversalEnvelope.CAPSULE_RADIUS / VillageWorldScale.HORIZONTAL_SCALE - 0.001)
	var checked := 0
	for props: Array in (town.deco as Dictionary).values():
		for prop: Dictionary in props:
			var box: AABB = prop.box
			var reach := box.grow(margin)
			reach.position.y = box.position.y
			reach.size.y = box.size.y
			for cell: Vector3i in walk:
				var column := AABB(Vector3(cell.x - 0.5, cell.y, cell.z - 0.5) * FabricRecipe.CELL_SIZE,
					Vector3(1.0, 2.0, 1.0) * FabricRecipe.CELL_SIZE).grow(-0.01)
				assert_false(reach.intersects(column), "%s (%s, collider-or-visual + capsule) reaches walk cell %s" % [
					prop.id, prop.asset, cell])
			checked += 1
	assert_gt(checked, 0)

func test_props_stay_a_capsule_off_the_kept_walk_53_grand() -> void:
	_assert_props_stay_off_the_walk(53, &"grand")

func test_props_stay_a_capsule_off_the_kept_walk_103_standard() -> void:
	_assert_props_stay_off_the_walk(103, &"standard")

func test_collision_hulls_mirror_the_baked_colliders() -> void:
	## Every deco asset (stall goods included): a collider union that reaches
	## past the visual must be in CLEARING_DECO_COLLISION_HULLS, and every row
	## there must cover the baked colliders.
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var ids := {}
	for purpose: StringName in SettlementFabricAssembler.CLEARING_DECO_GROUPS:
		for group: Array in SettlementFabricAssembler.CLEARING_DECO_GROUPS[purpose]:
			for item: Dictionary in group: ids[StringName(item.asset)] = true
	for goods: StringName in SettlementFabricAssembler.STALL_GOODS: ids[goods] = true
	ids[SettlementFabricAssembler.STALL_COUNTER] = true
	ids[SettlementFabricAssembler.STALL_HANGING_GOODS] = true
	for id: StringName in ids:
		var visual := cache.visual(id)
		assert_not_null(visual, String(id))
		if visual == null: continue
		var hull := AABB()
		var started := false
		for piece: EnvironmentCollisionPiece in visual.collisions:
			var shape_box: AABB = piece.shape.get_debug_mesh().get_aabb()
			for corner in 8:
				var point: Vector3 = piece.local_transform * (shape_box.position + shape_box.size \
					* Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1))
				hull = hull.expand(point) if started else AABB(point, Vector3.ZERO)
				started = true
		if not started: continue
		var envelope := SettlementFabricAssembler.clearing_deco_envelope(id,
			catalog.descriptor(id).measured_aabb).grow(0.001)
		assert_true(envelope.encloses(hull), "%s colliders %s leave its deco envelope %s" % [id, hull, envelope])

func test_density_one_furnishes_every_clearing_53_grand() -> void:
	_assert_furnished(53, &"grand")

func test_density_one_furnishes_every_clearing_103_standard() -> void:
	_assert_furnished(103, &"standard")
