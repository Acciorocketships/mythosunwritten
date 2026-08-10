extends Node3D

## Fast rendered review of the authoritative fine-grid volumetric town. This
## bypasses the expensive whole-corpus selector deliberately: it renders one
## already sealed `WarrenSpatialPlan` candidate through the same measured fabric
## compiler and assembler that production consumes. It is a falsification
## harness, never evidence that the wider candidate selector accepted the seed.
##
##   Godot --path . res://tests/harness/warren_spatial_review.tscn -- \
##     --seed 7 --output /tmp/warren-spatial-review
var _output_dir := "/tmp/mythos-warren-spatial-review"
var _world_seed := 7
var _candidate_token := "4000019"
var _camera := Camera3D.new()
var _spatial: WarrenSpatialPlan
var _fabric: SettlementFabricPlan
var _captures: Array[Dictionary] = []


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	_build_ground()
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert(program != null)
	var source := _select_source()
	assert(source != null, "no requested volumetric source candidate")
	_spatial = WarrenVolumetricSolver.from_volume(source, 1, program)
	assert(_spatial != null, WarrenVolumetricSolver.last_failure)
	_fabric = WarrenSpatialFabricCompiler.solve(_spatial, program)
	assert(_fabric != null, WarrenSpatialFabricCompiler.last_failure)
	var root := Node3D.new()
	root.name = "AuthoritativeSpatialWarren"
	add_child(root)
	var committed := SettlementFabricAssembler.commit(root, _fabric, catalog,
		false)
	print("[warren_spatial_review] seed=%d features=%d landmarks=%d balconies=%d instances=%d" \
		% [_world_seed, _spatial.features.size(),
			int(_spatial.audit.get("prefab_landmark_count", 0)),
			int(_spatial.audit.get("usable_balcony_count", 0)),
			int(committed.instance_count)])
	_camera.current = true
	_camera.near = 0.08
	_camera.far = 400.0
	add_child(_camera)
	_capture_all.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seed" and index + 1 < args.size():
			_world_seed = int(args[index + 1])
		elif args[index] == "--candidate-token" and index + 1 < args.size():
			_candidate_token = args[index + 1]


func _select_source() -> WarrenVolumePlan:
	var frontier := WarrenTownSolver.mass_first_frontier(_world_seed)
	for candidate: WarrenVolumePlan in frontier:
		if _candidate_token.is_empty() \
				or String(candidate.stable_id).contains(_candidate_token):
			return candidate
	return null


func _capture_all() -> void:
	for unused in 12:
		await get_tree().process_frame
	var bounds := _fabric_bounds()
	var centre := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z)
	var views: Array[Dictionary] = [
		{"id": "overview-ne", "position": centre + Vector3(span,
			span * 0.8, span), "target": centre, "fov": 52.0},
		{"id": "overview-sw", "position": centre + Vector3(-span,
			span * 0.65, -span), "target": centre, "fov": 54.0},
	]
	views.append_array(_street_views())
	views.append_array(_market_views())
	views.append_array(_courtyard_views())
	views.append_array(_skywalk_views())
	views.append_array(_room_outcropping_views())
	views.append_array(_tower_annex_views())
	views.append_array(_landmark_views())
	views.append_array(_balcony_views())
	for view: Dictionary in views:
		_camera.fov = float(view.fov)
		_camera.look_at_from_position(view.position as Vector3,
			view.target as Vector3)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/seed-%03d-%s.png" % [_output_dir, _world_seed,
			String(view.id)]
		var image := get_viewport().get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		_captures.append({"screenshot_id": view.id, "image": path,
			"position": _v3(view.position as Vector3),
			"target": _v3(view.target as Vector3), "fov": view.fov,
			"review_disposition": "UNREVIEWED"})
		print("[warren_spatial_review] captured ", path)
	_write_manifest()
	get_tree().quit()


func _street_views() -> Array[Dictionary]:
	## Select complete same-level, two-lane route runs. Merely finding one
	## neighboring route cell can point through the next corner and photograph a
	## facade at zero range; a five-cell run keeps both eye and target inside the
	## actual negative-space street the player traverses.
	var route_set: Dictionary = {}
	for cell: Vector3i in _spatial.route_floor_cells:
		route_set[cell] = true
	var candidates: Array[Dictionary] = []
	for cell: Vector3i in _spatial.route_floor_cells:
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
			if not _has_route_run(route_set, cell, direction, 5):
				continue
			var side := Vector3i(-direction.z, 0, direction.x)
			for lane_side: Vector3i in [side, -side]:
				if not _has_route_run(route_set, cell + lane_side,
						direction, 5):
					continue
				var wall_score := 0
				var overhead_score := 0
				for step in 5:
					var lane_a := cell + direction * step
					var lane_b := lane_a + lane_side
					for outside: Vector3i in [lane_a - lane_side,
							lane_b + lane_side]:
						wall_score += int(_is_building_use(
							_spatial.grid.use_at(outside)) \
							or _is_building_use(_spatial.grid.use_at(
								outside + Vector3i.UP)))
					for height in range(2, 6):
						overhead_score += int(_is_building_use(
							_spatial.grid.use_at(lane_a \
								+ Vector3i.UP * height)))
						overhead_score += int(_is_building_use(
							_spatial.grid.use_at(lane_b \
								+ Vector3i.UP * height)))
				var score := wall_score * 3 + overhead_score * 2
				if wall_score >= 6:
					candidates.append({"cell": cell, "direction": direction,
						"lane_side": lane_side, "score": score,
						"wall_score": wall_score,
						"overhead_score": overhead_score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return _cell_key(a.cell as Vector3i) < _cell_key(b.cell as Vector3i))
	var selected: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var separated := true
		for prior: Dictionary in selected:
			var delta := (candidate.cell as Vector3i) - (prior.cell as Vector3i)
			if absi(delta.x) + absi(delta.z) < 8 and absi(delta.y) < 3:
				separated = false
				break
		if not separated:
			continue
		selected.append(candidate)
		if selected.size() >= 4:
			break
	var out: Array[Dictionary] = []
	for index in selected.size():
		var candidate := selected[index]
		var eye := (Vector3(candidate.cell as Vector3i) \
			+ Vector3(candidate.lane_side as Vector3i) * 0.5) \
			* FabricRecipe.CELL_SIZE + Vector3.UP * 1.45
		var direction := candidate.direction as Vector3i
		out.append({"id": "street-%02d-w%d-o%d" % [index,
			int(candidate.wall_score), int(candidate.overhead_score)],
			"position": eye, "target": eye + Vector3(direction) * 6.0 \
				+ Vector3.UP * 0.25, "fov": 72.0})
	return out


func _market_views() -> Array[Dictionary]:
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"covered_market" \
				or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var centre := _cell_centroid(feature.public_cells)
		var outward3 := FabricRecipe.transform_direction(Vector3i.BACK,
			int(record.yaw_quarters))
		var eye := centre + Vector3(outward3) * 7.0 + Vector3.UP * 1.45
		var overview_eye := _best_orbit_position(centre + Vector3.UP * 1.0,
			12.0, 11.0, [StringName("spatial.fabric.%s" % feature.stable_id)])
		return [{"id": "market-aisle", "position": eye,
			"target": centre + Vector3.UP * 1.35, "fov": 66.0},
			{"id": "market-overhead", "position": overview_eye,
				"target": centre + Vector3.UP, "fov": 58.0}] \
			as Array[Dictionary]
	return [] as Array[Dictionary]


func _courtyard_views() -> Array[Dictionary]:
	var floors: Array[Vector3i] = []
	for macro: Vector3i in _spatial.source_volume.courtyard_cells:
		floors.append_array(WarrenVolumetricSolver._fine_square(macro))
	if floors.is_empty():
		return [] as Array[Dictionary]
	var centre := _cell_centroid(floors)
	var minimum := floors[0]
	var maximum := floors[0]
	for floor: Vector3i in floors:
		minimum = minimum.min(floor)
		maximum = maximum.max(floor)
	var along_x := maximum.x - minimum.x >= maximum.z - minimum.z
	var eye_cell := Vector3(
		float(minimum.x) if along_x else float(minimum.x + maximum.x) * 0.5,
		float(minimum.y),
		float(minimum.z + maximum.z) * 0.5 if along_x else float(minimum.z))
	var target_cell := Vector3(
		float(maximum.x) if along_x else float(minimum.x + maximum.x) * 0.5,
		float(minimum.y),
		float(minimum.z + maximum.z) * 0.5 if along_x else float(maximum.z))
	var court_eye := eye_cell * FabricRecipe.CELL_SIZE + Vector3.UP * 1.45
	var court_target := target_cell * FabricRecipe.CELL_SIZE \
		+ Vector3.UP * 1.45
	var out: Array[Dictionary] = [
		{"id": "courtyard-eye", "position": court_eye,
			"target": court_target, "fov": 74.0},
		{"id": "courtyard-overhead", "position": centre \
			+ Vector3(0.4, 18.0, 0.4), "target": centre,
			"fov": 46.0},
	]
	var floor_columns: Dictionary = {}
	var court_y := floors[0].y
	for cell: Vector3i in floors:
		floor_columns[Vector2i(cell.x, cell.z)] = true
	var lower: Array[Vector3i] = []
	var upper: Array[Vector3i] = []
	for route: Vector3i in _spatial.route_floor_cells:
		if not floor_columns.has(Vector2i(route.x, route.z)):
			continue
		if route.y < court_y:
			lower.append(route)
		elif route.y > court_y:
			upper.append(route)
	if not lower.is_empty():
		lower.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.y > b.y)
		var eye := _route_eye(lower[0])
		var direction := _best_route_direction(lower[0])
		out.append({"id": "courtyard-under-route", "position": eye,
			"target": eye + Vector3(direction) * 6.0 \
				+ Vector3.UP * 0.2, "fov": 72.0})
	if not upper.is_empty():
		upper.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.y < b.y)
		var eye := _route_eye(upper[0])
		out.append({"id": "courtyard-upper-route", "position": eye,
			"target": centre + Vector3.UP * 1.0, "fov": 68.0})
	return out


func _skywalk_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"enclosed_skywalk":
			continue
		var visual_bounds := _feature_visual_bounds(feature)
		var centre := visual_bounds.get_center() if visual_bounds.size.length() \
			> 0.0 else _cell_centroid(feature.reserved_cells)
		var ignored: Array[StringName] = [StringName("spatial.fabric.%s" \
			% feature.stable_id)]
		var orbit_distance := maxf(15.0, maxf(visual_bounds.size.x,
			visual_bounds.size.z) + 10.0)
		var span_eye := _best_orbit_position(centre, orbit_distance, 3.5,
			ignored, visual_bounds)
		var under_eye := _best_orbit_position(centre - Vector3.UP * 1.0,
			orbit_distance, -2.0, ignored, visual_bounds)
		out.append({"id": "skywalk-%02d-span" % ordinal,
			"position": span_eye,
			"target": centre, "fov": 52.0})
		out.append({"id": "skywalk-%02d-under" % ordinal,
			"position": under_eye,
			"target": centre - Vector3.UP, "fov": 62.0})
		ordinal += 1
	return out


func _tower_annex_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"tower_annex" \
				or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var centre := _cell_centroid(feature.reserved_cells)
		var outward := Vector3(FabricRecipe.transform_direction(Vector3i.BACK,
			int(record.yaw_quarters)))
		out.append({"id": "tower-annex-%02d" % ordinal,
			"position": centre + outward * 7.0 + Vector3.UP * 1.5,
			"target": centre, "fov": 58.0})
		ordinal += 1
	return out


func _room_outcropping_views() -> Array[Dictionary]:
	## These are not attached facade props: each reservation names a complete
	## inhabited upper WarrenRoomStamp whose floorplate leaves the room below.
	## Photograph the exposed displacement side and its underside so review can
	## falsify whether the volumetric recomposition actually reads as a room-scale
	## projection in the assembled town.
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"room_outcropping":
			continue
		var upper := _room_by_id(StringName(
			feature.audit.outcrop_upper_room_id))
		var lower := _room_by_id(StringName(
			feature.audit.outcrop_lower_room_id))
		if upper == null or lower == null:
			continue
		var upper_bounds := _unit_visual_bounds(StringName(
			"spatial.fabric.%s" % upper.stable_id))
		if upper_bounds.size.length_squared() <= 0.0:
			continue
		var upper_centre := upper_bounds.get_center()
		var lower_centre := _cell_centroid(lower.private_cells)
		var offset := upper_centre - lower_centre
		offset.y = 0.0
		if offset.length_squared() <= 0.01:
			continue
		var outward := offset.normalized()
		var distance := maxf(10.0, maxf(upper_bounds.size.x,
			upper_bounds.size.z) + 7.0)
		var ignored: Array[StringName] = [StringName(
			"spatial.fabric.%s" % upper.stable_id)]
		var front_eye := _best_directional_position(upper_centre, outward,
			distance, 2.0, ignored, upper_bounds)
		var underside_target := Vector3(upper_centre.x,
			upper_bounds.position.y + 0.35, upper_centre.z)
		var underside_eye := _best_directional_position(underside_target,
			outward, distance * 0.8, -1.0, ignored, upper_bounds)
		out.append({"id": "room-outcrop-%02d-front" % ordinal,
			"position": front_eye, "target": upper_centre,
			"fov": 52.0})
		out.append({"id": "room-outcrop-%02d-under" % ordinal,
			"position": underside_eye, "target": underside_target,
			"fov": 58.0})
		ordinal += 1
	return out


func _balcony_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"balcony" or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var origin := record.origin as Vector3i
		var yaw := int(record.yaw_quarters)
		var outward3 := FabricRecipe.transform_direction(Vector3i.BACK, yaw)
		var outward := Vector3(outward3)
		var target := Vector3(origin) * FabricRecipe.CELL_SIZE \
			+ Vector3.UP * 1.25
		out.append({"id": "balcony-%02d-front" % ordinal,
			"position": target + outward * 5.0 + Vector3.UP * 0.5,
			"target": target, "fov": 56.0})
		out.append({"id": "balcony-%02d-underside" % ordinal,
			"position": target + outward * 3.5 + Vector3.UP * -1.2,
			"target": target + Vector3.UP * -0.4, "fov": 58.0})
		ordinal += 1
	return out


func _landmark_views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ordinal := 0
	for feature: WarrenFeatureReservation in _spatial.features:
		if feature.kind != &"prefab_landmark" \
				or feature.construction_records.size() != 1:
			continue
		var record := feature.construction_records[0]
		var origin := record.origin as Vector3i
		var entrance := feature.audit.landmark_entrance_cell as Vector3i
		var landing := feature.audit.landmark_public_landing_cell as Vector3i
		var outward3 := landing - entrance
		var outward := Vector3(outward3)
		var side := Vector3(-outward3.z, 0.0, outward3.x)
		var height_m := float(feature.audit.landmark_height_cell_count) \
			* FabricRecipe.CELL_SIZE
		var target := Vector3(origin) * FabricRecipe.CELL_SIZE \
			+ Vector3.UP * height_m * 0.48
		out.append({"id": "landmark-%02d-front" % ordinal,
			"position": target + outward * 18.0 + Vector3.UP * 2.5,
			"target": target, "fov": 56.0})
		out.append({"id": "landmark-%02d-side" % ordinal,
			"position": target + outward * 10.0 + side * 13.0 \
				+ Vector3.UP * 4.0,
			"target": target + Vector3.UP * 1.0, "fov": 58.0})
		for skywalk: WarrenFeatureReservation in _spatial.features:
			if skywalk.kind != &"enclosed_skywalk":
				continue
			for endpoint: Dictionary in skywalk.endpoints:
				if StringName(endpoint.owner_id) != feature.stable_id:
					continue
				var socket_target := Vector3(endpoint.cell as Vector3i) \
					* FabricRecipe.CELL_SIZE + Vector3.UP * 1.5
				out.append({"id": "landmark-%02d-skywalk-seam" % ordinal,
					"position": socket_target + side * 8.0 \
						+ outward * 5.0 + Vector3.UP * 2.0,
					"target": socket_target, "fov": 55.0})
		ordinal += 1
	return out


func _fabric_bounds() -> AABB:
	var out := AABB()
	var initialized := false
	for bounds: AABB in _fabric.transformed_visual_clearance_bounds():
		out = bounds if not initialized else out.merge(bounds)
		initialized = true
	return out


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("527faf")
	sky_material.sky_horizon_color = Color("c5dce0")
	sky_material.ground_bottom_color = Color("596152")
	sky_material.ground_horizon_color = Color("aebd9f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -37.0, 0.0)
	sun.light_color = Color("ffe4b9")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(120.0, 0.4, 120.0)
	instance.mesh = mesh
	instance.position = Vector3(0.0, -0.2, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718d50")
	material.roughness = 1.0
	instance.material_override = material
	add_child(instance)


func _write_manifest() -> void:
	var path := "%s/index.json" % _output_dir
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"world_seed": _world_seed,
		"spatial_signature": _spatial.deterministic_signature().sha256_text(),
		"audit": _spatial.audit, "captures": _captures}, "  "))


func _best_route_direction(cell: Vector3i) -> Vector3i:
	var route_set: Dictionary = {}
	for route: Vector3i in _spatial.route_floor_cells:
		route_set[route] = true
	var best := Vector3i.RIGHT
	var best_length := 0
	for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
			Vector3i.LEFT, Vector3i.FORWARD]:
		var length := 0
		for step in range(1, 7):
			if not route_set.has(cell + direction * step):
				break
			length += 1
		if length > best_length:
			best = direction
			best_length = length
	return best


func _feature_visual_bounds(feature: WarrenFeatureReservation) -> AABB:
	var prefix := "spatial.fabric.%s" % feature.stable_id
	var bounds := AABB()
	var has_bounds := false
	for unit: FabricUnit in _fabric.units:
		if not String(unit.stable_id).begins_with(prefix):
			continue
		var recipe := _fabric.recipe(unit.recipe_id)
		if recipe == null or recipe.placements.is_empty():
			continue
		var unit_bounds := unit.transform() * recipe.local_clearance_bounds
		bounds = bounds.merge(unit_bounds) if has_bounds else unit_bounds
		has_bounds = true
	return bounds


func _unit_visual_bounds(stable_id: StringName) -> AABB:
	for unit: FabricUnit in _fabric.units:
		if unit.stable_id != stable_id:
			continue
		var recipe := _fabric.recipe(unit.recipe_id)
		if recipe != null and not recipe.placements.is_empty():
			return unit.transform() * recipe.local_clearance_bounds
	return AABB()


func _room_by_id(stable_id: StringName) -> WarrenRoomStamp:
	for building: WarrenBuildingVolume in _spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.stable_id == stable_id:
				return room
	return null


func _best_directional_position(target: Vector3, preferred: Vector3,
		distance: float, height: float,
		ignored_prefixes: Array[StringName], own_bounds: AABB) -> Vector3:
	var directions: Array[Vector3] = [
		preferred.normalized(),
		preferred.rotated(Vector3.UP, PI * 0.25).normalized(),
		preferred.rotated(Vector3.UP, -PI * 0.25).normalized(),
		preferred.rotated(Vector3.UP, PI * 0.5).normalized(),
		preferred.rotated(Vector3.UP, -PI * 0.5).normalized(),
	]
	var distance_scales: Array[float] = [1.0, 1.35]
	var best := target + directions[0] * distance + Vector3.UP * height
	var best_score := 1 << 30
	for distance_scale: float in distance_scales:
		for direction: Vector3 in directions:
			var candidate: Vector3 = target \
				+ direction * distance * distance_scale \
				+ Vector3.UP * height
			var score := _view_occlusion_score(candidate, target,
				ignored_prefixes)
			if own_bounds.grow(0.25).has_point(candidate):
				score += 1000
			if score < best_score:
				best = candidate
				best_score = score
	return best


func _best_orbit_position(target: Vector3, distance: float, height: float,
		ignored_prefixes: Array[StringName] = [], own_bounds := AABB()) -> Vector3:
	## Pick the least-occluded of eight deterministic orbit positions against the
	## same measured envelopes that gate construction. This is not image scoring;
	## it only prevents a review camera from spawning inside an unrelated house or
	## aiming through several buildings before reaching its requested feature.
	var directions: Array[Vector3] = [
		Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD,
		(Vector3.RIGHT + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.FORWARD).normalized(),
		(Vector3.RIGHT + Vector3.FORWARD).normalized(),
	]
	var distance_scales: Array[float] = [1.0, 1.35]
	var best := target + directions[0] * distance + Vector3.UP * height
	var best_score := 1 << 30
	for distance_scale: float in distance_scales:
		for direction: Vector3 in directions:
			var candidate: Vector3 = target \
				+ direction * distance * distance_scale \
				+ Vector3.UP * height
			var score := _view_occlusion_score(candidate, target,
				ignored_prefixes)
			if own_bounds.size.length_squared() > 0.0 \
					and own_bounds.grow(0.25).has_point(candidate):
				score += 1000
			if score < best_score:
				best = candidate
				best_score = score
	return best


func _view_occlusion_score(position: Vector3, target: Vector3,
		ignored_prefixes: Array[StringName]) -> int:
	var score := 0
	for sample_index in 24:
		# Stop short of the target because the feature being photographed may join
		# an endpoint room there. The ignored feature prefix handles its own shell.
		var weight := 100 if sample_index == 0 else 1
		var point := position.lerp(target, float(sample_index) / 26.0)
		for unit: FabricUnit in _fabric.units:
			var ignored := false
			for prefix: StringName in ignored_prefixes:
				if String(unit.stable_id).begins_with(String(prefix)):
					ignored = true
					break
			if ignored:
				continue
			var recipe := _fabric.recipe(unit.recipe_id)
			if recipe == null or recipe.placements.is_empty():
				continue
			var bounds := unit.transform() * recipe.local_clearance_bounds
			if bounds.grow(0.1).has_point(point):
				score += weight
	return score


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z] as Array[float]


static func _is_building_use(use_value: int) -> bool:
	return use_value in [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
		WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]


static func _has_route_run(route_set: Dictionary, start: Vector3i,
		direction: Vector3i, length: int) -> bool:
	for step in length:
		if not route_set.has(start + direction * step):
			return false
	return true


static func _route_eye(cell: Vector3i) -> Vector3:
	return Vector3(cell) * FabricRecipe.CELL_SIZE + Vector3.UP * 1.45


static func _cell_centroid(cells: Array[Vector3i]) -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for cell: Vector3i in cells:
		total += Vector3(cell) * FabricRecipe.CELL_SIZE
	return total / float(cells.size())


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
