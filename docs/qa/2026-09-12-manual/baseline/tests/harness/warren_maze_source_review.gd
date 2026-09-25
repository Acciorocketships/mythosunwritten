extends Node3D

## Rendered review of the sealed maze source before the building partition and
## authored-asset compiler exist. The opaque views show the actual retained
## SOLID/AIR/PASSAGE lattice. The network view changes only the material to a
## translucent diagnostic so covered paths can be inspected without pretending
## the unfinished partition has already produced buildings.
const CELL_M := WarrenVolumePlan.HORIZONTAL_CELL_SIZE_M
const BAND_M := WarrenVolumePlan.VERTICAL_BAND_SIZE_M
const PROFILE_IDS: Array[StringName] = [
	WarrenVillageScaleProfile.COMPACT,
	WarrenVillageScaleProfile.STANDARD,
	WarrenVillageScaleProfile.LARGE,
	WarrenVillageScaleProfile.GRAND,
]
const INVALID_CELL := Vector3i(2147483647, 2147483647, 2147483647)

var _output_dir := "/tmp/mythos-maze-source-review"
var _world_seed := 29
var _profile_id := WarrenVillageScaleProfile.STANDARD
var _camera := Camera3D.new()
var _source: WarrenMazeSourcePlan
var _opaque_mass := MeshInstance3D.new()
var _ghost_mass := MeshInstance3D.new()
var _captures: Array[Dictionary] = []


func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	var profile := WarrenVillageScaleProfile.for_id(_profile_id)
	var massif := WarrenMassifBuilder.build(_world_seed, {}, profile)
	_source = WarrenMazeCarver.carve(_world_seed, massif, profile) \
		if massif != null else null
	if _source == null:
		printerr("[maze_source_review] seed=%d rejected: massif=%s maze=%s %s" % [
			_world_seed, WarrenMassifBuilder.last_failure,
			WarrenMazeCarver.last_failure, WarrenMazeCarver.last_diagnostic])
		get_tree().quit(1)
		return
	_build_ground()
	_build_mass()
	_build_passage_surfaces()
	_build_transition_surfaces()
	_build_frontage_markers()
	_camera.current = true
	_camera.near = 0.08
	_camera.far = 500.0
	add_child(_camera)
	print(("[maze_source_review] seed=%d profile=%s passages=%d spine=%d " \
		+ "alleys=%d frontage=%.3f two_sided=%.3f covered=%.3f solid=%.3f") % [
		_world_seed, String(_profile_id), int(_source.audit.passage_cell_count),
		int(_source.audit.spine_cell_count), int(_source.audit.alley_cell_count),
		float(_source.audit.frontage_ratio),
		float(_source.audit.two_sided_passage_ratio),
		float(_source.audit.covered_passage_ratio),
		float(_source.audit.source_solid_retention_ratio)])
	if DisplayServer.get_name() == "headless":
		_write_manifest()
		get_tree().quit()
		return
	_capture_all.call_deferred()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output_dir = args[index + 1]
		elif args[index] == "--seed" and index + 1 < args.size():
			_world_seed = int(args[index + 1])
		elif args[index] == "--profile" and index + 1 < args.size():
			var requested := StringName(args[index + 1])
			if requested in PROFILE_IDS:
				_profile_id = requested


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("486d94")
	sky_material.sky_horizon_color = Color("d8d3bf")
	sky_material.ground_bottom_color = Color("4e514c")
	sky_material.ground_horizon_color = Color("a6aa94")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("ffe1b0")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	add_child(sun)


func _build_ground() -> void:
	var radius := float(_source.scale_profile.radius_cells + 4) * CELL_M
	var instance := MeshInstance3D.new()
	instance.name = "ReviewGround"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(radius * 2.0, 0.35, radius * 2.0)
	instance.mesh = mesh
	instance.position = Vector3(0.0, -0.2, 0.0)
	instance.material_override = _material(Color("71814d"))
	add_child(instance)


func _build_mass() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_count := 0
	for column_value: Variant in _source.massif.columns.keys():
		var column := column_value as Vector2i
		for band in range(_source.massif.base_at(column),
				_source.massif.top_at(column)):
			var cell := Vector3i(column.x, band, column.y)
			if _source.state_at(cell) != WarrenMazeSourcePlan.CellState.SOLID:
				continue
			for face: Dictionary in _faces():
				var neighbor := cell + face.delta as Vector3i
				if _source.state_at(neighbor) \
						== WarrenMazeSourcePlan.CellState.SOLID:
					continue
				_add_face(surface, cell, face, _mass_color(cell,
					bool(face.roof)))
				face_count += 1
	var mesh := surface.commit()
	_opaque_mass.name = "RetainedSolidOpaque"
	_opaque_mass.mesh = mesh
	_opaque_mass.material_override = _vertex_material(false)
	add_child(_opaque_mass)
	_ghost_mass.name = "RetainedSolidGhost"
	_ghost_mass.mesh = mesh
	_ghost_mass.material_override = _vertex_material(true)
	_ghost_mass.visible = false
	add_child(_ghost_mass)
	print("[maze_source_review] exposed solid faces=", face_count)


func _faces() -> Array[Dictionary]:
	return [
		{"delta": Vector3i.LEFT, "normal": Vector3.LEFT, "roof": false,
			"corners": [Vector3(0, 0, 0), Vector3(0, 0, 1),
				Vector3(0, 1, 1), Vector3(0, 1, 0)]},
		{"delta": Vector3i.RIGHT, "normal": Vector3.RIGHT, "roof": false,
			"corners": [Vector3(1, 0, 1), Vector3(1, 0, 0),
				Vector3(1, 1, 0), Vector3(1, 1, 1)]},
		{"delta": Vector3i(0, 0, -1), "normal": Vector3.BACK, "roof": false,
			"corners": [Vector3(1, 0, 0), Vector3(0, 0, 0),
				Vector3(0, 1, 0), Vector3(1, 1, 0)]},
		{"delta": Vector3i(0, 0, 1), "normal": Vector3.FORWARD, "roof": false,
			"corners": [Vector3(0, 0, 1), Vector3(1, 0, 1),
				Vector3(1, 1, 1), Vector3(0, 1, 1)]},
		{"delta": Vector3i.DOWN, "normal": Vector3.DOWN, "roof": false,
			"corners": [Vector3(0, 0, 1), Vector3(0, 0, 0),
				Vector3(1, 0, 0), Vector3(1, 0, 1)]},
		{"delta": Vector3i.UP, "normal": Vector3.UP, "roof": true,
			"corners": [Vector3(0, 1, 0), Vector3(0, 1, 1),
				Vector3(1, 1, 1), Vector3(1, 1, 0)]},
	]


func _add_face(surface: SurfaceTool, cell: Vector3i, face: Dictionary,
		color: Color) -> void:
	var origin := Vector3((float(cell.x) - 0.5) * CELL_M,
		float(cell.y) * BAND_M, (float(cell.z) - 0.5) * CELL_M)
	var corners := face.corners as Array
	var vertices: Array[Vector3] = []
	for corner_value: Variant in corners:
		var corner := corner_value as Vector3
		vertices.append(origin + Vector3(corner.x * CELL_M,
			corner.y * BAND_M, corner.z * CELL_M))
	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(face.normal as Vector3)
		surface.set_color(color)
		surface.add_vertex(vertices[index])


func _mass_color(cell: Vector3i, roof: bool) -> Color:
	var palette: Array[Color] = [Color("8f5544"), Color("a66f48"),
		Color("b69367"), Color("6f7770"), Color("8a6a78"),
		Color("6f8290"), Color("b07d67")]
	# The broad hash patches are a diagnostic stand-in for future building
	# lineages. They deliberately avoid the per-cell colour confetti that made
	# the old modular town look assembled from unrelated boxes.
	var district_x := floori(float(cell.x) / 3.0)
	var district_z := floori(float(cell.z) / 3.0)
	var index := posmod(_world_seed * 31 + district_x * 17
		+ district_z * 47, palette.size())
	var color := palette[index]
	return color.lightened(0.17) if roof else color


func _build_passage_surfaces() -> void:
	var cells := _source.passage_cells()
	var box := BoxMesh.new()
	box.size = Vector3(CELL_M * 0.86, 0.08, CELL_M * 0.86)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = cells.size()
	var market_set: Dictionary = {}
	for cell: Vector3i in _source.market_zone:
		market_set[cell] = true
	for cell: Vector3i in _source.market_square_cells:
		market_set[cell] = true
	for index in cells.size():
		var cell := cells[index]
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY,
			Vector3(float(cell.x) * CELL_M, float(cell.y) * BAND_M + 0.05,
				float(cell.z) * CELL_M)))
		var color := Color("e2b45e") if market_set.has(cell) else \
			Color("c98b51") if _source.passage_kinds[cell] \
				== WarrenMazeSourcePlan.PASSAGE_SPINE else Color("c36a4d")
		if bool(_source.excavation.covered.get(cell, false)):
			color = color.darkened(0.18)
		multimesh.set_instance_color(index, color)
	var instance := MultiMeshInstance3D.new()
	instance.name = "CarvedPublicRealm"
	instance.multimesh = multimesh
	instance.material_override = _instance_color_material()
	add_child(instance)


func _build_transition_surfaces() -> void:
	var transitions: Array[Dictionary] = []
	transitions.append_array(_source.excavation.transitions)
	for lane: Dictionary in _source.excavation.lanes:
		transitions.append_array(lane.transitions as Array[Dictionary])
	for index in transitions.size():
		var value := transitions[index]
		var from_cell := value.from as Vector3i
		var to_cell := value.to as Vector3i
		if from_cell.y == to_cell.y:
			continue
		var from_position := _floor_position(from_cell) + Vector3.UP * 0.09
		var to_position := _floor_position(to_cell) + Vector3.UP * 0.09
		var direction := to_position - from_position
		var mesh := BoxMesh.new()
		mesh.size = Vector3(CELL_M * 0.74, 0.09, direction.length())
		var instance := MeshInstance3D.new()
		instance.name = "ConnectedRise%03d" % index
		instance.mesh = mesh
		instance.transform = Transform3D(Basis.looking_at(direction.normalized(),
			Vector3.UP), (from_position + to_position) * 0.5)
		instance.material_override = _material(Color("d39754"))
		add_child(instance)


func _build_frontage_markers() -> void:
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.9, 1.55, 0.06)
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(1.15, 0.68, 0.045)
	var door_transforms: Array[Transform3D] = []
	var window_transforms: Array[Transform3D] = []
	for cell: Vector3i in _source.passage_cells():
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(cell.x + direction.x,
				cell.z + direction.y)
			if not _column_carries_house_at(column, cell.y):
				continue
			var yaw := 0.0 if direction.y != 0 else PI * 0.5
			var face_offset := Vector3(float(direction.x) * (CELL_M * 0.5 + 0.03),
				0.0, float(direction.y) * (CELL_M * 0.5 + 0.03))
			var basis := Basis(Vector3.UP, yaw)
			door_transforms.append(Transform3D(basis,
				_floor_position(cell) + face_offset + Vector3.UP * 0.8))
			window_transforms.append(Transform3D(basis,
				_floor_position(cell) + face_offset + Vector3.UP * 2.35))
	_add_multimesh("FrontageDoors", door_mesh, door_transforms,
		Color("51382d"))
	_add_multimesh("FrontageWindows", window_mesh, window_transforms,
		Color("f3c879"), true)


func _column_carries_house_at(column: Vector2i, street_band: int) -> bool:
	if not _source.massif.has_column(column) \
			or street_band < _source.massif.base_at(column) \
			or street_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS \
				> _source.massif.top_at(column):
		return false
	for band in range(street_band,
			street_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
		if _source.excavation.carved.has(
				Vector3i(column.x, band, column.y)):
			return false
	return true


func _add_multimesh(node_name: String, mesh: Mesh,
		transforms: Array[Transform3D], color: Color, emission := false) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	var material := _material(color)
	if emission:
		material.emission_enabled = true
		material.emission = color.darkened(0.15)
		material.emission_energy_multiplier = 0.65
	instance.material_override = material
	add_child(instance)


func _capture_all() -> void:
	for unused in 10:
		await get_tree().process_frame
	for view: Dictionary in _views():
		var ghost := bool(view.get("ghost", false))
		_opaque_mass.visible = not ghost
		_ghost_mass.visible = ghost
		_camera.fov = float(view.fov)
		_camera.look_at_from_position(view.position as Vector3,
			view.target as Vector3)
		for unused in 3:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := "%s/seed-%d-%s.png" % [_output_dir, _world_seed,
			String(view.id)]
		var image := get_viewport().get_texture().get_image()
		assert(image != null and image.save_png(path) == OK)
		_captures.append({"screenshot_id": view.id, "image": path,
			"ghosted_mass": ghost, "position": _v3(view.position as Vector3),
			"target": _v3(view.target as Vector3), "fov": view.fov,
			"review_disposition": "UNREVIEWED"})
		print("[maze_source_review] captured ", path)
	_write_manifest()
	get_tree().quit()


func _views() -> Array[Dictionary]:
	var span := float(_source.scale_profile.radius_cells + 2) * CELL_M
	var peak := float(_source.massif.core_top_bands) * BAND_M
	var center := Vector3(0.0, peak * 0.35, 0.0)
	var entry := _floor_position(_source.excavation.route[0])
	var entry_next := _floor_position(_source.excavation.route[1])
	var entry_direction := (entry_next - entry).normalized()
	var market := _floor_position(_source.market_zone[
		_source.market_zone.size() / 2])
	return [
		{"id": "overview-ne", "position": Vector3(span, peak + span * 0.45,
			span), "target": center, "fov": 51.0},
		{"id": "overview-sw", "position": Vector3(-span, peak + span * 0.35,
			-span * 0.85), "target": center, "fov": 54.0},
		{"id": "network-cutaway", "position": Vector3(span * 0.8,
			peak + span * 0.75, span * 0.95), "target": center,
			"fov": 47.0, "ghost": true},
		{"id": "entry", "position": entry - entry_direction * 5.0
			+ Vector3.UP * 1.7, "target": entry_next + Vector3.UP * 1.3,
			"fov": 70.0},
		{"id": "market-approach", "position": entry - entry_direction * 2.0
			+ Vector3.UP * 2.0, "target": market + Vector3.UP * 1.1,
			"fov": 68.0},
		{"id": "roofline", "position": Vector3(-span * 1.15,
			peak * 0.58, span * 0.25), "target": center,
			"fov": 49.0},
	]


func _write_manifest() -> void:
	var path := "%s/manifest.json" % _output_dir
	var payload := {"world_seed": _world_seed, "profile": String(_profile_id),
		"source_signature": _source.deterministic_signature().sha256_text(),
		"audit": _source.audit, "captures": _captures,
		"render_scope": "sealed maze source; authored building partition pending",
		"legend": {"gold": "market approach", "orange": "spine",
			"red": "alleys", "dark_floor": "covered/tunnel passage",
			"lit_panels": "source-proven inhabitable frontage"}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(payload, "  "))
	print("[maze_source_review] manifest ", path)


func _floor_position(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) * CELL_M, float(cell.y) * BAND_M,
		float(cell.z) * CELL_M)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material


func _vertex_material(ghost: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	if ghost:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.18)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _instance_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color("4a291a")
	material.emission_energy_multiplier = 0.16
	return material


func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
