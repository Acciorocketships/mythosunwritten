extends SceneTree

## Text-only planning probe for the in-progress fine-grid feature grammar. This
## intentionally creates no render resources; it exposes whether a sealed seed
## has genuine two-ended bridge corridors and room-scale offset opportunities.


func _init() -> void:
	var started_ms := Time.get_ticks_msec()
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	print("PROGRAM_MS=", Time.get_ticks_msec() - started_ms)
	for recipe: FabricRecipe in program.recipes():
		if recipe.has_tag(&"prefab_anchor"):
			print("PREFAB_RECIPE ", recipe.recipe_id, " bounds=",
				recipe.local_clearance_bounds, " solid=", recipe.solid_cells.size(),
				" headroom=", recipe.headroom_cells.size(), " bearing=",
				recipe.terrain_bearing_cells.size())
	var frontier := WarrenTownSolver.mass_first_frontier(7)
	var source: WarrenVolumePlan
	for candidate: WarrenVolumePlan in frontier:
		if String(candidate.stable_id).contains("4000019"):
			source = candidate
			break
	var parcel_probe := WarrenTownSolver.partition_parcels(source, 1, program)
	print("PLANNED_SKYWALKS=", 0 if parcel_probe == null \
		else parcel_probe.connection_reservations.size())
	if parcel_probe != null:
		for reservation: Dictionary in parcel_probe.connection_reservations:
			print("PLANNED ", reservation.get("owner_parcel_ids", []), " ",
				reservation.get("owner_endpoints", []), " components=",
				reservation.get("components", []))
	var solve_started_ms := Time.get_ticks_msec()
	var plan := WarrenVolumetricSolver.from_volume(source, 1, program)
	print("SPATIAL_SOLVE_MS=", Time.get_ticks_msec() - solve_started_ms)
	if plan == null:
		print("FAIL: ", WarrenVolumetricSolver.last_failure.left(1200))
		print("PREPLAN_SELECTION: selected=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"selected_count", -1), " candidates=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"compatible_candidate_count", -1), " fixed_reject=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"fixed_block_rejection_count", -1), " failures=",
			WarrenVolumetricSolver.last_preplan_skywalk_diagnostic.get(
				"endpoint_survival_failures", {}))
		print("SKY_DIAG: ", WarrenSpatialFeatureSolver.last_skywalk_diagnostic)
		print("MARKET_DIAG: ",
			WarrenVolumetricSolver.last_preplan_market_diagnostic)
		quit(1)
		return
	print("LANDMARK_DIAG: ",
		WarrenVolumetricSolver.last_preplan_landmark_diagnostic)
	_print_courtyard(plan)
	_print_offset_rooms(plan)
	_print_straight_skywalks(plan)
	_print_feature_compilation(plan, program)
	quit()


func _print_courtyard(plan: WarrenSpatialPlan) -> void:
	var volume := plan.source_volume
	print("COURT macro=", volume.courtyard_cells)
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			var below := PackedStringArray()
			for offset in range(1, 7):
				var cell := floor + Vector3i.DOWN * offset
				below.append("%d/%s" % [plan.grid.use_at(cell),
					String(plan.grid.owner_name_at(cell))])
			print("  ", floor, " below=", ",".join(below))
	for y in range(0, 11):
		print("COURT_LAYER y=", y)
		for z in range(9, 19):
			var row := ""
			for x in range(-4, 9):
				var cell := Vector3i(x, y, z)
				var use := plan.grid.use_at(cell)
				row += "P" if use == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else "B" if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					else "D" if use == WarrenSpatialGrid.Use.DAYLIGHT_AIR \
					else "."
			print("  z%02d %s" % [z, row])


func _print_offset_rooms(plan: WarrenSpatialPlan) -> void:
	var by_source: Dictionary = {}
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not by_source.has(room.source_parcel_id):
				by_source[room.source_parcel_id] = [] as Array[WarrenRoomStamp]
			(by_source[room.source_parcel_id] as Array[WarrenRoomStamp]).append(room)
	var shifted := 0
	for rooms_value: Variant in by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			var delta := Vector2i(upper.lattice_origin.x - lower.lattice_origin.x,
				upper.lattice_origin.z - lower.lattice_origin.z)
			if delta != Vector2i.ZERO:
				shifted += 1
				print("OFFSET ", lower.stable_id, " -> ", upper.stable_id,
					" delta=", delta, " kind=", upper.kind)
	print("OFFSET_COUNT=", shifted)


func _print_straight_skywalks(plan: WarrenSpatialPlan) -> void:
	var candidates: Array[Dictionary] = []
	var directions: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.BACK]
	for building: WarrenBuildingVolume in plan.buildings:
		for room: WarrenRoomStamp in building.room_records:
			for endpoint: Vector3i in room.private_cells:
				if endpoint.y != room.lattice_origin.y:
					continue
				for direction: Vector3i in directions:
					if plan.grid.use_at(endpoint + direction) \
							== WarrenSpatialGrid.Use.PRIVATE_VOLUME:
						continue
					for distance: int in [3, 5, 7]:
						var other: Vector3i = endpoint + direction * distance
						if plan.grid.use_at(other) \
								!= WarrenSpatialGrid.Use.PRIVATE_VOLUME:
							continue
						var other_owner := plan.grid.owner_name_at(other)
						if other_owner == building.stable_id:
							continue
						var clear := true
						var lower_public := 0
						for step in range(1, distance):
							var bridge_cell := endpoint + direction * step
							for y_offset in 4:
								var use: int = plan.grid.use_at(bridge_cell \
									+ Vector3i.UP * y_offset)
								if use not in [WarrenSpatialGrid.Use.OUTSIDE,
										WarrenSpatialGrid.Use.SERVICE_VOID]:
									clear = false
							for down in range(1, 9):
								if plan.grid.use_at(bridge_cell \
										+ Vector3i.DOWN * down) \
										== WarrenSpatialGrid.Use.PUBLIC_AIR:
									lower_public += 1
									break
						if clear and lower_public > 0:
							candidates.append({"a": endpoint,
								"a_owner": building.stable_id, "b": other,
								"b_owner": other_owner, "distance": distance,
								"direction": direction,
								"lower_public": lower_public})
	print("SKYWALK_COUNT=", candidates.size())
	for index in mini(candidates.size(), 30):
		print("SKY ", candidates[index])


func _print_feature_compilation(plan: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> void:
	var rooms := WarrenSpatialFabricCompiler.compile_room_units(plan, program)
	var features := WarrenSpatialFabricCompiler.compile_feature_units(plan,
		program, rooms)
	print("FEATURE_COMPILE_COUNT=", features.size(), " failure=",
		WarrenSpatialFabricCompiler.last_failure)
	if not features.is_empty():
		var roofs := WarrenSpatialFabricCompiler.compile_roof_units(plan, program,
			rooms, features)
		print("ROOF_COMPILE_COUNT=", roofs.size(), " failure=",
			WarrenSpatialFabricCompiler.last_failure)
		if not roofs.is_empty():
			var sealed := WarrenSpatialFabricCompiler.solve(plan, program)
			print("FABRIC_SEALED=", sealed != null, " failure=",
				WarrenSpatialFabricCompiler.last_failure)
	for feature: WarrenFeatureReservation in plan.features:
		if feature.construction_records.is_empty():
			continue
		print("FEATURE ", feature.stable_id, " audit=", feature.audit,
			" endpoints=", feature.endpoints)
		for record: Dictionary in feature.construction_records:
			var recipe := program.recipe(StringName(record.recipe_id))
			var feature_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* recipe.local_clearance_bounds
			for room_unit: FabricUnit in rooms:
				var room_recipe := program.recipe(room_unit.recipe_id)
				var room_bounds := room_unit.transform() \
					* room_recipe.local_clearance_bounds
				if SettlementFabricPlan._aabb_overlaps_volume(feature_bounds,
						room_bounds):
					print("  OVERLAP component=", record.role, " bounds=",
						feature_bounds, " room=", room_unit.stable_id,
						" recipe=", room_unit.recipe_id, " bounds=", room_bounds)
