extends "res://tests/harness/september10_city_complete_qa.gd"

func _ready() -> void:
	_read_args()
	get_window().size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_environment()
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({}, catalog)
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-24, 25):
		for x in range(-24, 25):
			storeys[Vector2i(x,z)] = 0
			levels[Vector2i(x,z)] = 0
	_flat_region = HeightfieldRegion.new(storeys, levels)
	_production_urban = VillageHamletConstruction.solve(
		VillageTerrainView.from_region(_flat_region), _world_seed,
		StringName("hamlet.%d" % _world_seed), Vector2.ZERO, Vector2.DOWN,
		&"orange", program, null, _world_seed)
	assert(_production_urban.accepted)
	_build_production_terrain(_production_urban.world_transform)
	var root := Node3D.new()
	add_child(root)
	_commit_production_entries(root, catalog)
	add_child(_camera)
	_camera.current = true
	await _capture_all()

func _capture_all() -> void:
	for view: Dictionary in [
		{"id":"NE", "eye":Vector3(55,48,55)},
		{"id":"SW", "eye":Vector3(-55,38,-55)},
		{"id":"plan", "eye":Vector3(0,95,0.1)},
		{"id":"square", "eye":Vector3(20,9,20)},
	]:
		_camera.fov = 50
		_camera.look_at_from_position(view.eye, Vector3(0,2,0))
		for frame in 12:
			await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var path := _output_dir.path_join("%s.png" % view.id)
		assert(get_viewport().get_texture().get_image().save_png(path) == OK)
		_captures.append({"id": view.id, "eye": str(view.eye), "target": "(0,2,0)",
			"fov": 50, "path": path})
	var output := {"audit": _production_urban.fabric_audit, "views": _captures,
		"entries": _production_urban.entries}
	FileAccess.open(_output_dir.path_join("census.json"), FileAccess.WRITE).store_string(
		JSON.stringify(output, "  "))
	get_tree().quit()
