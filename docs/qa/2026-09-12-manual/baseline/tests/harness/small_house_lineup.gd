extends SceneTree

## Source-only visual qualification for compact complete-house candidates.
const SOURCES: Array[Dictionary] = [
	{"label": "Small House 02", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_02.glb"},
	{"label": "Small House 03", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_03.glb"},
	{"label": "Small House 04", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_04.glb"},
	{"label": "Small House 06", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_06.glb"},
	{"label": "Small House 07", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_07.glb"},
	{"label": "Small House 08", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/SmallHouse_08.glb"},
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
	environment.ambient_light_energy = 0.75
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	for index in SOURCES.size():
		var source := SOURCES[index]
		var scene := load(String(source.path)) as PackedScene
		assert(scene != null)
		var instance := scene.instantiate() as Node3D
		instance.position = Vector3(float(index % 3) * 6.0 - 6.0, 0.0,
			float(index / 3) * 6.0 - 3.0)
		world.add_child(instance)
		var label := Label3D.new()
		label.text = String(source.label)
		label.font_size = 64
		label.outline_size = 10
		label.position = instance.position + Vector3(0.0, 6.2, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.position = Vector3(9.0, 7.0, 12.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.5, 0.0))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var capture_path := "/tmp/warren-small-house-lineup.png"
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(capture_path) == OK)
	print("[small_house_lineup] captured %s" % capture_path)
	quit()
