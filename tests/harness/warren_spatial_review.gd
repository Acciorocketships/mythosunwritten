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
	print("[warren_spatial_review] seed=%d features=%d balconies=%d instances=%d" \
		% [_world_seed, _spatial.features.size(),
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
		{"id": "street-south", "position": centre + Vector3(0.0, 2.0,
			span * 0.55), "target": centre + Vector3(0.0, 3.0, 0.0),
			"fov": 70.0},
	]
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
