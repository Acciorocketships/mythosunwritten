# Self-driving visual regression harness for the terrain issues reported on
# 2026-07-22/23. Every pin is the exact F3 player/crosshair pair from the
# screenshot; ReviewCam reconstructs the original orbit camera.
extends Node3D

const OUT := "/tmp/mythos-reported-terrain-qa"
const WORLD_SEED := 2697992464

# [name, player position, crosshair position, enable dense grass]
const SPOTS: Array = [
	["cliff_palette", Vector3(1026.8, 24.0, -1208.8),
		Vector3(1026.6, 24.2, -1209.1), false],
	["path_263", Vector3(263.9, 5.0, -109.3),
		Vector3(263.9, 5.2, -109.3), false],
	["path_375", Vector3(375.5, 4.7, -387.2),
		Vector3(375.1, 4.9, -387.1), false],
	["slope_tree", Vector3(-408.4, 1.4, 352.8),
		Vector3(-408.1, 1.6, 352.7), false],
	["grass_rock", Vector3(-782.0, 4.0, -229.3),
		Vector3(-781.7, 4.2, -229.3), true],
]

var _character: CharacterBody3D
var _camera: Camera3D
var _material_state: Dictionary
var _cliff_shadow_state: Dictionary

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(OUT)
	var spot := _requested_spot()
	if spot.is_empty():
		spot = SPOTS[0]
	var world: Node3D = load("res://scenes/world.tscn").instantiate()
	var streamer := world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	streamer.SEED_OVERRIDE = WORLD_SEED
	streamer.CHUNK_RADIUS = 1
	streamer.KEEP_RADIUS = 2
	streamer.GRASS_ENABLED = bool(spot[3])
	var initial_character := world.find_child("Character", true, false) as CharacterBody3D
	initial_character.position = Vector3(spot[1]) + Vector3.UP * 8.0
	add_child(world)
	_run.bind(spot).call_deferred()

func _requested_spot() -> Array:
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() < 2 or user_args[0] != "--spot":
		return []
	for spot: Array in SPOTS:
		if spot[0] == user_args[1]:
			return spot
	return []

func _wait_ground_neighbourhood(pos: Vector3, timeout_s: float) -> void:
	var streamer := find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	var centre := FieldTerrainStreamer.chunk_of(pos)
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_s:
		var built: Dictionary = streamer.get("_built")
		var complete := true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if not built.has(centre + Vector2i(dx, dz)):
					complete = false
		if complete:
			await get_tree().create_timer(3.0).timeout
			return
		await get_tree().create_timer(0.5).timeout
	push_error("Incomplete 3x3 terrain neighbourhood at reported pin %s" % pos)

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("[reported_terrain_qa] shot ", name, " cam=", _camera.global_position)

func _diagnostic_requested() -> bool:
	return OS.get_cmdline_user_args().has("--diagnose-material")

func _grass_diagnostic_requested() -> bool:
	return OS.get_cmdline_user_args().has("--diagnose-grass")

func _remember_material_state(material: StandardMaterial3D) -> void:
	_material_state = {
		"albedo_color": material.albedo_color,
		"albedo_texture": material.albedo_texture,
		"vertex_color_use_as_albedo": material.vertex_color_use_as_albedo,
		"shading_mode": material.shading_mode,
	}

func _restore_material(material: StandardMaterial3D) -> void:
	material.albedo_color = _material_state["albedo_color"]
	material.albedo_texture = _material_state["albedo_texture"]
	material.vertex_color_use_as_albedo = _material_state["vertex_color_use_as_albedo"]
	material.shading_mode = _material_state["shading_mode"]

func _set_cliff_shadows(enabled: bool) -> void:
	for cliffs: Node in find_children("Cliffs", "Node3D", true, false):
		for geometry: Node in cliffs.find_children("*", "GeometryInstance3D", true, false):
			var instance := geometry as GeometryInstance3D
			if not _cliff_shadow_state.has(instance.get_instance_id()):
				_cliff_shadow_state[instance.get_instance_id()] = instance.cast_shadow
			instance.cast_shadow = (_cliff_shadow_state[instance.get_instance_id()]
					if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

func _apply_material_probe(material: StandardMaterial3D, probe: String) -> void:
	_restore_material(material)
	_set_cliff_shadows(true)
	match probe:
		"unshaded_full":
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"tint_only":
			material.albedo_color = Color.WHITE
			material.albedo_texture = null
			material.vertex_color_use_as_albedo = true
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"texture_only":
			material.albedo_color = Color.WHITE
			material.albedo_texture = _material_state["albedo_texture"]
			material.vertex_color_use_as_albedo = false
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"lighting_only", "lighting_no_cliff_shadows":
			material.albedo_color = Color.WHITE
			material.albedo_texture = null
			material.vertex_color_use_as_albedo = false
			if probe == "lighting_no_cliff_shadows":
				_set_cliff_shadows(false)

func _retexel_entire_grass_region(mesh: Mesh, uv: Vector2) -> Mesh:
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in uvs.size():
		if uvs[i].x < 0.15 and uvs[i].y < 0.15:
			uvs[i] = uv
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

func _apply_full_lip_retexel_candidate() -> void:
	CliffDressing._ensure_loaded()
	var pieces := {"Lips": "lip", "OuterLips": "outer_lip", "InnerLips": "inner_lip"}
	for node_name: String in pieces:
		var original := CliffDressing._pieces[pieces[node_name]][0] as Mesh
		var candidate := _retexel_entire_grass_region(original, CliffDressing.ground_uv())
		for node: Node in find_children(node_name, "MultiMeshInstance3D", true, false):
			var lips := node as MultiMeshInstance3D
			lips.multimesh.mesh = candidate

func _capture_material_probes(spot: Array) -> void:
	var material := CliffDressing.shared_material() as StandardMaterial3D
	_remember_material_state(material)
	for probe in ["normal", "unshaded_full", "tint_only", "texture_only",
			"lighting_only", "lighting_no_cliff_shadows"]:
		_apply_material_probe(material, probe)
		await get_tree().process_frame
		await get_tree().process_frame
		_shot(String(spot[0]) + "_diag_" + probe)
	_apply_full_lip_retexel_candidate()
	for probe in ["normal", "texture_only"]:
		_apply_material_probe(material, probe)
		await get_tree().process_frame
		await get_tree().process_frame
		_shot(String(spot[0]) + "_diag_candidate_full_retexel_" + probe)
	_restore_material(material)
	_set_cliff_shadows(true)

func _capture_grass_temporal_probe(spot: Array) -> void:
	var streamer := find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	var field := find_child("TrampleField", true, false) as TrampleField
	var target: Dictionary = {}
	var best_distance := INF
	var player_xz := Vector2(float(spot[1].x), float(spot[1].z))
	for stamps: Array in streamer._dressing_trample_by_chunk.values():
		for stamp: Dictionary in stamps:
			var position: Vector3 = stamp.position
			var distance := player_xz.distance_to(Vector2(position.x, position.z))
			if distance < best_distance:
				best_distance = distance
				target = stamp
	assert(not target.is_empty())
	var target_position: Vector3 = target.position
	print("[reported_terrain_qa] grass temporal target=", target_position,
		" radius=", target.radius, " player_distance=", best_distance)
	_shot(String(spot[0]) + "_temporal_static")
	field.stamp(target_position, Vector2.DOWN, TrampleField.PLAYER_RADIUS, 1.0)
	field._upload_if_due(TrampleField.UPLOAD_INTERVAL)
	var stamp_time := field._now
	for sample: Array in [["walked_0s", 0.0], ["walked_1_9s", 1.9],
			["walked_2_1s", 2.1], ["recovering_5s", 5.0], ["static_10s", 10.0]]:
		field._now = stamp_time + float(sample[1])
		field._publish_globals()
		await get_tree().process_frame
		await get_tree().process_frame
		_shot(String(spot[0]) + "_temporal_" + String(sample[0]))

func _write_lip_metrics() -> void:
	CliffDressing._ensure_loaded()
	var piece: Array = CliffDressing._pieces["lip"]
	var mesh := piece[0] as Mesh
	var local := piece[1] as Transform3D
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ground_uv := CliffDressing.ground_uv()
	var unique_uvs := {}
	var top_count := 0
	var uv_min := Vector2(INF, INF)
	var uv_max := Vector2(-INF, -INF)
	var normal_y_min := INF
	var normal_y_max := -INF
	var normal_xz_max := 0.0
	var transformed_y_min := INF
	var transformed_y_max := -INF
	for i in vertices.size():
		if normals[i].y <= 0.9 or uvs[i].x >= 0.15 or uvs[i].y >= 0.15:
			continue
		top_count += 1
		var uv := uvs[i]
		unique_uvs["%.6f,%.6f" % [uv.x, uv.y]] = true
		uv_min = Vector2(minf(uv_min.x, uv.x), minf(uv_min.y, uv.y))
		uv_max = Vector2(maxf(uv_max.x, uv.x), maxf(uv_max.y, uv.y))
		normal_y_min = minf(normal_y_min, normals[i].y)
		normal_y_max = maxf(normal_y_max, normals[i].y)
		normal_xz_max = maxf(normal_xz_max, Vector2(normals[i].x, normals[i].z).length())
		var transformed_y := (local * vertices[i]).y
		transformed_y_min = minf(transformed_y_min, transformed_y)
		transformed_y_max = maxf(transformed_y_max, transformed_y)
	var metrics := {
		"ground_uv": [ground_uv.x, ground_uv.y],
		"top_vertex_count": top_count,
		"top_unique_uv_count": unique_uvs.size(),
		"top_uv_min": [uv_min.x, uv_min.y],
		"top_uv_max": [uv_max.x, uv_max.y],
		"top_normal_y_min": normal_y_min,
		"top_normal_y_max": normal_y_max,
		"top_normal_xz_max": normal_xz_max,
		"top_local_y_min": transformed_y_min,
		"top_local_y_max": transformed_y_max,
	}
	var file := FileAccess.open(OUT + "/cliff_material_metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	file.close()
	print("[reported_terrain_qa] cliff material metrics: ", metrics)

func _run(spot: Array) -> void:
	await get_tree().create_timer(5.0).timeout
	_character = find_child("Character", true, false) as CharacterBody3D
	_camera = get_viewport().get_camera_3d()
	_camera.set("target", null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_character.velocity = Vector3.ZERO
	_character.global_position = Vector3(spot[1]) + Vector3.UP * 8.0
	_character.set_physics_process(false)
	await _wait_ground_neighbourhood(spot[1], 120.0)
	_character.global_position = spot[1]
	var exact_camera := ReviewCam.solve_cam(spot[1], spot[2])
	var relative := exact_camera - Vector3(spot[1])
	if _diagnostic_requested() and String(spot[0]) == "cliff_palette":
		_camera.global_position = exact_camera
		_camera.look_at(Vector3(spot[1]), Vector3.UP)
		_camera.force_update_transform()
		await get_tree().process_frame
		_write_lip_metrics()
		await _capture_material_probes(spot)
		print("[reported_terrain_qa] material diagnostics done: ", OUT)
		get_tree().quit()
		return
	if _grass_diagnostic_requested() and String(spot[0]) == "grass_rock":
		_camera.global_position = exact_camera
		_camera.look_at(Vector3(spot[1]), Vector3.UP)
		_camera.force_update_transform()
		await get_tree().process_frame
		await _capture_grass_temporal_probe(spot)
		print("[reported_terrain_qa] grass temporal diagnostics done: ", OUT)
		get_tree().quit()
		return
	for view: Array in [["exact", 0.0], ["near_left", -deg_to_rad(8.0)],
			["near_right", deg_to_rad(8.0)]]:
		_camera.global_position = Vector3(spot[1]) \
			+ relative.rotated(Vector3.UP, float(view[1]))
		_camera.look_at(Vector3(spot[1]), Vector3.UP)
		_camera.force_update_transform()
		await get_tree().process_frame
		_shot(String(spot[0]) + "_" + String(view[0]))
	print("[reported_terrain_qa] done: ", OUT)
	get_tree().quit()
