extends SceneTree

## Editor-only visual probe for choosing a roof construction vocabulary. Source
## pack paths stay confined to this tooling harness and the bake manifest.
const SOURCES: Array[Dictionary] = [
	{"label": "S preset", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Preset_Blue_001.fbx"},
	{"label": "S 001", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Blue_001.fbx"},
	{"label": "S 002", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Blue_002.fbx"},
	{"label": "S front L", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_Front_L_S_Blue_001.fbx"},
	{"label": "S bisect L", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_Bisect_L_S_Blue_001.fbx"},
	{"label": "M preset", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Blue/MBlue/SFV_Roof_M_Preset_Blue_001.fbx"},
	{"label": "LPFV 01", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_01.glb"},
	{"label": "LPFV 02", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_02.glb"},
	{"label": "LPFV 04", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_04.glb"},
	{"label": "LPFV 05", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_05.glb"},
	{"label": "LPFV 03", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_03.glb"},
	{"label": "LPFV 06", "path": "res://assets/LowPolyFantasyVillage/Models/HouseParts/Roof_06.glb"},
	{"label": "dormer 001", "path": "res://assets/FantasyVillageFBX/FBX/Building Attachables/Attachable Attic Window/SFV_Roof_Window_Attachable_001.fbx"},
	{"label": "dormer 002", "path": "res://assets/FantasyVillageFBX/FBX/Building Attachables/Attachable Attic Window/SFV_Roof_Window_Attachable_002.fbx"},
	{"label": "dormer 003", "path": "res://assets/FantasyVillageFBX/FBX/Building Attachables/Attachable Attic Window/SFV_Roof_Window_Attachable_003.fbx"},
	{"label": "dormer 004", "path": "res://assets/FantasyVillageFBX/FBX/Building Attachables/Attachable Attic Window/SFV_Roof_Window_Attachable_004.fbx"},
	{"label": "attach M 001", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_M/SFV_Roof_Attachable_M_001.fbx"},
	{"label": "attach M 002", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_M/SFV_Roof_Attachable_M_002.fbx"},
	{"label": "attach M preset 001", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_M/SFV_Roof_Attachable_Preset_M_001.fbx"},
	{"label": "attach L 001", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_L/SFV_Roof_Attachable_L_001.fbx"},
	{"label": "attach L 002", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_L/SFV_Roof_Attachable_L_002.fbx"},
	{"label": "attach L preset 001", "path": "res://assets/FantasyVillageFBX/FBX/Roof/Roof Attachable/RA_L/SFV_Roof_Attachable_L_Preset_001.fbx"},
	{"label": "Market roof 01", "path": "res://assets/LowPolyFantasyVillage/Models/Props/Market_Roof_01.glb"},
	{"label": "Market roof 02", "path": "res://assets/LowPolyFantasyVillage/Models/Props/Market_Roof_02.glb"},
	{"label": "Market roof 03", "path": "res://assets/LowPolyFantasyVillage/Models/Props/Market_Roof_03.glb"},
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
	environment.ambient_light_energy = 0.7
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
		instance.position = Vector3(float(index % 3) * 11.0 - 11.0, 0.0,
			float(index / 3) * 10.0 - 5.0)
		world.add_child(instance)
		instances.append(instance)
		var label := Label3D.new()
		label.text = String(source.label)
		label.font_size = 64
		label.outline_size = 10
		label.position = instance.position + Vector3(0.0, 7.5, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		labels.append(label)
	var camera := Camera3D.new()
	camera.fov = 48.0
	var row_count := ceili(float(SOURCES.size()) / 3.0)
	var centre_z := float(row_count - 2) * 5.0
	camera.position = Vector3(32.0, 38.0,
		centre_z + maxf(38.0, float(row_count) * 7.0))
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 2.5, centre_z))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var capture_path := "/tmp/warren-roof-source-lineup.png"
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(capture_path) == OK)
	print("[roof_source_lineup] captured %s" % capture_path)
	# The town review can only choose the correct dormer-facing camera after this
	# source-local falsification. Capture both authored families from both Z
	# directions; one view shows the glazed facade and the other the roof tail
	# intended to disappear into the parent slope.
	for instance: Node3D in instances:
		instance.visible = false
	for label: Label3D in labels:
		label.visible = false
	for source_index: int in SOURCES.size():
		if not String(SOURCES[source_index].label).begins_with("dormer"):
			continue
		var dormer := instances[source_index]
		dormer.visible = true
		dormer.position = Vector3.ZERO
		for view: Dictionary in [
			{"id": "front-z", "position": Vector3(0.0, 2.4, 7.5)},
			{"id": "back-z", "position": Vector3(0.0, 2.4, -7.5)},
		]:
			camera.position = view.position as Vector3
			camera.look_at(Vector3(0.0, 1.35, 0.0))
			for unused in 3:
				await process_frame
			RenderingServer.force_draw()
			await process_frame
			var closeup_path := "/tmp/warren-roof-source-%s-%s.png" % [
				String(SOURCES[source_index].label).replace(" ", "-"),
				String(view.id)]
			var closeup := root.get_texture().get_image()
			assert(closeup != null and closeup.save_png(closeup_path) == OK)
			print("[roof_source_lineup] captured %s" % closeup_path)
		dormer.visible = false
	quit()
