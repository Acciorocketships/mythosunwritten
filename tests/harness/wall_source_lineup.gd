extends SceneTree

## Editor-only comparison of complete textured wall modules before admitting
## them to the finite runtime construction vocabulary.
const SOURCES: Array[Dictionary] = [
	{"label": "window 001", "path": "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Windows/SFV_Wall_Wooden_Window_M_001.fbx"},
	{"label": "window 010", "path": "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Windows/SFV_Wall_Wooden_Window_M_010.fbx"},
	{"label": "window 020", "path": "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Windows/SFV_Wall_Wooden_Window_M_020.fbx"},
	{"label": "window 040", "path": "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Windows/SFV_Wall_Wooden_Window_M_040.fbx"},
	{"label": "window 060", "path": "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Windows/SFV_Wall_Wooden_Window_M_060.fbx"},
	{"label": "plain 005", "path": "res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Walls/SFV_Wall_Wooden_M_005.fbx"},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a6b4bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
	sun.light_energy = 1.2
	world.add_child(sun)
	for index in SOURCES.size():
		var source := SOURCES[index]
		var scene := load(String(source.path)) as PackedScene
		assert(scene != null)
		var instance := scene.instantiate() as Node3D
		instance.position = Vector3(float(index % 3) * 5.0 - 5.0, 0.0,
			float(index / 3) * 5.0 - 2.5)
		world.add_child(instance)
		var label := Label3D.new()
		label.text = String(source.label)
		label.font_size = 48
		label.outline_size = 8
		label.position = instance.position + Vector3(0.0, 4.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	var camera := Camera3D.new()
	camera.fov = 46.0
	camera.position = Vector3(12.0, 9.0, 17.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, 0.0))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var capture_path := "/tmp/warren-wall-source-lineup.png"
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(capture_path) == OK)
	print("[wall_source_lineup] captured %s" % capture_path)
	quit()
