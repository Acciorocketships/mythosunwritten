extends Node3D

## Rendered diagnostic of what the SOLID-FIRST maze solver actually produces:
## the carved passage network, the retained solid it leaves standing, and the
## building parcels the block partitioner substitutes into that solid.
##
## This deliberately stops BEFORE composition. The maze source and its partition
## are the stages that currently work (M1/M2 sealed, M4 pinned as a compatibility
## fixture); composition is the stage that still rejects them. Rendering the
## source is therefore the only honest picture of the carver's own output.
##
## GUI mode only — headless capture scenes hang.
##
##   Godot --path . res://tests/harness/maze_source_review.tscn -- \
##     --seeds 1,4,7 --output /tmp/maze-shots

const CELL := 3.0        # macro lattice cell, metres
const BAND := 3.0        # one vertical band, metres

var _output_dir := "/tmp/maze-source-review"
var _seeds: Array[int] = [4]
var _camera := Camera3D.new()
var _captures: Array[Dictionary] = []


func _ready() -> void:
	_read_args()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_build_environment()
	add_child(_camera)
	_camera.current = true
	_run.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seeds" and index + 1 < args.size():
			_seeds.clear()
			for token: String in args[index + 1].split(",", false):
				_seeds.append(int(token.strip_edges()))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_output_dir)
	for city_seed: int in _seeds:
		await _render_seed(city_seed)
	var file := FileAccess.open("%s/index.json" % _output_dir, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"captures": _captures}, "  "))
		file.close()
	print("[maze_source_review] done: ", _captures.size(), " captures")
	get_tree().quit()


func _render_seed(city_seed: int) -> void:
	for child in get_children():
		if child.is_in_group(&"maze_geometry"):
			child.queue_free()
	await get_tree().process_frame

	var profile := WarrenVillageScaleProfile.select(city_seed)
	var massif := WarrenMassifBuilder.build(city_seed, {}, profile)
	if massif == null:
		push_warning("seed %d massif rejected" % city_seed)
		return
	var source := WarrenMazeCarver.carve(city_seed, massif, profile)
	if source == null:
		push_warning("seed %d carve rejected: %s" % [city_seed,
			WarrenMazeCarver.last_failure])
		return
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	var parcels: WarrenParcelPlan = null
	if volume != null:
		parcels = WarrenMazeBlockPartitioner.partition(source, volume)

	var root := Node3D.new()
	root.add_to_group(&"maze_geometry")
	add_child(root)

	var bounds := _draw(root, source, parcels)
	var parcel_count := parcels.parcels.size() if parcels != null else 0
	print("[maze_source_review] seed=%d scale=%s passages=%d parcels=%d" % [
		city_seed, String(profile.scale_id), source.passage_cells().size(),
		parcel_count])

	var centre: Vector3 = bounds.get("centre", Vector3.ZERO)
	var radius: float = maxf(20.0, float(bounds.get("radius", 40.0)))
	for view: Dictionary in [
		{"id": "iso", "dir": Vector3(1.0, 0.95, 1.0), "dist": 2.1},
		{"id": "iso-rear", "dir": Vector3(-1.0, 0.9, -0.85), "dist": 2.1},
		{"id": "top", "dir": Vector3(0.02, 1.0, 0.02), "dist": 1.9},
		{"id": "street", "dir": Vector3(0.9, 0.22, 0.5), "dist": 0.85},
	]:
		var direction := (view.dir as Vector3).normalized()
		var position := centre + direction * radius * float(view.dist)
		_camera.fov = 55.0
		_camera.look_at_from_position(position, centre)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/maze-seed-%d-%s.png" % [_output_dir, city_seed,
			String(view.id)]
		var image := get_viewport().get_texture().get_image()
		if image != null and image.save_png(path) == OK:
			_captures.append({"seed": city_seed, "view": view.id,
				"image": path, "parcels": parcel_count,
				"passages": source.passage_cells().size()})
			print("[maze_source_review] captured ", path)


func _draw(root: Node3D, source: WarrenMazeSourcePlan,
		parcels: WarrenParcelPlan) -> Dictionary:
	## Passages are the carved public network; parcels are the houses the
	## partitioner substituted into the solid the carve left behind. Colouring
	## them separately is the whole point: it shows bore and building as two
	## products of ONE pass, which is what the solid-first thesis claims.
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)

	var passage_colors := {
		WarrenMazeSourcePlan.PASSAGE_SPINE: Color("e8c76a"),
		WarrenMazeSourcePlan.PASSAGE_ALLEY: Color("cf9350"),
		WarrenMazeSourcePlan.PASSAGE_MARKET: Color("6fc4b8"),
	}
	for cell: Vector3i in source.passage_cells():
		var kind := StringName(source.passage_kinds.get(cell,
			WarrenMazeSourcePlan.PASSAGE_ALLEY))
		var colour := passage_colors.get(kind, Color("cf9350")) as Color
		var origin := Vector3(float(cell.x) * CELL, float(cell.y) * BAND,
			float(cell.z) * CELL)
		_box(root, origin + Vector3(0.0, -BAND * 0.42, 0.0),
			Vector3(CELL * 0.94, BAND * 0.16, CELL * 0.94), colour)
		minimum = _minv(minimum, origin)
		maximum = _maxv(maximum, origin)

	if parcels != null:
		var index := 0
		for parcel: WarrenBuildingParcel in parcels.parcels:
			# Distinct hue per parcel so adjacency and footprint are legible.
			var hue := fposmod(float(index) * 0.6180339887, 1.0)
			var colour := Color.from_hsv(hue, 0.42, 0.86)
			index += 1
			var height := float(maxi(1, parcel.top_band - parcel.base_band + 1))
			for column: Vector2i in parcel.footprint:
				var origin := Vector3(float(column.x) * CELL,
					(float(parcel.base_band) + height * 0.5 - 0.5) * BAND,
					float(column.y) * CELL)
				_box(root, origin, Vector3(CELL * 0.92, BAND * height * 0.96,
					CELL * 0.92), colour)
				minimum = _minv(minimum, origin)
				maximum = _maxv(maximum, origin)

	if minimum.x == INF:
		return {"centre": Vector3.ZERO, "radius": 40.0}
	var centre := (minimum + maximum) * 0.5
	return {"centre": centre, "radius": (maximum - minimum).length() * 0.5}


func _box(root: Node3D, origin: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	root.add_child(instance)


func _minv(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))


func _maxv(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_horizon_color = Color("c5dce0")
	sky_material.ground_bottom_color = Color("596152")
	sky_material.ground_horizon_color = Color("aebd9f")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -37.0, 0.0)
	sun.light_color = Color("ffe4b9")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
