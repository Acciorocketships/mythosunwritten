extends SceneTree

## Visual selection probe for authored stair presets. The production recipe must
## choose a complete flight whose real low/high treads meet the two logical
## landings; an AABB alone cannot reveal a switchback's handed tread phases.
const SOURCES: Array[Dictionary] = [
	{"label": "preset 001", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_001.fbx"},
	{"label": "preset 002", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_002.fbx"},
	{"label": "preset 003", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_003.fbx"},
	{"label": "preset 004", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_004.fbx"},
	{"label": "preset 005", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_005.fbx"},
	{"label": "preset 006", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_006.fbx"},
	{"label": "preset 007", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_007.fbx"},
	{"label": "preset 008", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Preset/SFV_Stair_Preset_008.fbx"},
	{"label": "straight half", "path": "res://assets/FantasyVillageFBX/FBX/Stairs/Stair Parts/SFV_Stair_S_001.fbx"},
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
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var instances: Array[Node3D] = []
	var labels: Array[Label3D] = []
	for index in SOURCES.size():
		var source := SOURCES[index]
		var scene := load(String(source.path)) as PackedScene
		assert(scene != null)
		var instance := scene.instantiate() as Node3D
		instance.position = Vector3(float(index % 3) * 6.0 - 6.0, 0.0,
			float(index / 3) * 6.5 - 6.5)
		world.add_child(instance)
		instances.append(instance)
		var label := Label3D.new()
		label.text = String(source.label)
		label.font_size = 56
		label.outline_size = 8
		label.position = instance.position + Vector3(0.0, 5.2, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		labels.append(label)
	var camera := Camera3D.new()
	camera.fov = 46.0
	camera.position = Vector3(20.0, 22.0, 26.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, 0.0))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var capture_path := "/tmp/warren-stair-source-lineup.png"
	var capture := root.get_texture().get_image()
	assert(capture != null and capture.save_png(capture_path) == OK)
	print("[stair_source_lineup] captured %s" % capture_path)
	for instance: Node3D in instances:
		instance.visible = false
	for label: Label3D in labels:
		label.visible = false
	for index in SOURCES.size():
		var instance := instances[index]
		instance.visible = true
		instance.position = Vector3.ZERO
		camera.position = Vector3(6.5, 4.8, 7.5)
		camera.look_at(Vector3(0.0, 1.55, -0.7))
		for unused in 3:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var closeup_path := "/tmp/warren-stair-source-%03d.png" % (index + 1)
		var closeup := root.get_texture().get_image()
		assert(closeup != null and closeup.save_png(closeup_path) == OK)
		print("[stair_source_lineup] captured %s" % closeup_path)
		instance.visible = false
	quit()
