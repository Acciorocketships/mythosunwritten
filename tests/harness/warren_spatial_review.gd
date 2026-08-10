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
	## Select actual canonical route cells with the strongest immediate walls and
	## overhead mass. The former generic south camera often looked across roofs
	## and said nothing about the player-scale negative space.
	var route_set: Dictionary = {}
	for cell: Vector3i in _spatial.route_floor_cells:
		route_set[cell] = true
	var candidates: Array[Dictionary] = []
	for cell: Vector3i in _spatial.route_floor_cells:
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK,
				Vector3i.LEFT, Vector3i.FORWARD]:
			if not route_set.has(cell + direction):
				continue
			var side := Vector3i(-direction.z, 0, direction.x)
			var wall_score := 0
			var overhead_score := 0
			for step in 4:
				var sample := cell + direction * step
				for sign_value in [-1, 1]:
					var side_cell: Vector3i = sample + side * int(sign_value)
					wall_score += int(_is_building_use(
						_spatial.grid.use_at(side_cell)) \
						or _is_building_use(_spatial.grid.use_at(
							side_cell + Vector3i.UP)))
				for height in range(2, 6):
					overhead_score += int(_is_building_use(
						_spatial.grid.use_at(sample + Vector3i.UP * height)))
			var score := wall_score * 3 + overhead_score * 2
			if wall_score >= 4:
				candidates.append({"cell": cell, "direction": direction,
					"score": score, "wall_score": wall_score,
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
		var eye := _route_eye(candidate.cell as Vector3i)
		var direction := candidate.direction as Vector3i
		out.append({"id": "street-%02d-w%d-o%d" % [index,
			int(candidate.wall_score), int(candidate.overhead_score)],
			"position": eye, "target": eye + Vector3(direction) * 7.5 \
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
		return [{"id": "market-aisle", "position": eye,
			"target": centre + Vector3.UP * 1.35, "fov": 66.0},
			{"id": "market-overhead", "position": centre \
				+ Vector3(outward3) * 6.0 + Vector3.UP * 8.0,
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
	var out: Array[Dictionary] = [
		{"id": "courtyard-eye", "position": centre + Vector3.UP * 1.45,
			"target": centre + Vector3(7.0, 1.8, 0.0), "fov": 72.0},
		{"id": "courtyard-overhead", "position": centre \
			+ Vector3(9.0, 12.0, 9.0), "target": centre,
			"fov": 58.0},
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
		out.append({"id": "courtyard-under-route", "position": eye,
			"target": eye + Vector3(7.0, 0.2, 0.0), "fov": 72.0})
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
		var centre := _cell_centroid(feature.reserved_cells)
		var a := (feature.endpoints[0] as Dictionary).cell as Vector3i
		var b := (feature.endpoints[1] as Dictionary).cell as Vector3i
		var delta := b - a
		var side3 := Vector3i(-delta.z, 0, delta.x)
		if side3 == Vector3i.ZERO:
			side3 = Vector3i.RIGHT
		var side := Vector3(side3).normalized()
		out.append({"id": "skywalk-%02d-span" % ordinal,
			"position": centre + side * 8.0 + Vector3.UP * 1.5,
			"target": centre, "fov": 58.0})
		out.append({"id": "skywalk-%02d-under" % ordinal,
			"position": centre + side * 5.5 - Vector3.UP * 2.5,
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


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z] as Array[float]


static func _is_building_use(use_value: int) -> bool:
	return use_value in [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
		WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]


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
