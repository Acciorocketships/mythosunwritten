extends SceneTree

## Review the authored valley vocabulary in isolation and in a candidate atomic
## T-junction. Source paths stay in tooling; production consumes only baked IDs.
const HALF_BLUE := "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_S_Blue_002.fbx"
const HALF_ORANGE := "res://assets/FantasyVillageFBX/FBX/Roof/Orange/SOrange/SFV_Roof_S_Orange_002.fbx"
const BISECT_LEFT_BLUE := "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_Bisect_L_S_Blue_001.fbx"
const BISECT_RIGHT_BLUE := "res://assets/FantasyVillageFBX/FBX/Roof/Blue/SBlue/SFV_Roof_Bisect_R_S_Blue_001.fbx"
const BISECT_LEFT_ORANGE := "res://assets/FantasyVillageFBX/FBX/Roof/Orange/SOrange/SFV_Roof_Bisect_L_S_Orange_001.fbx"
const BISECT_RIGHT_ORANGE := "res://assets/FantasyVillageFBX/FBX/Roof/Orange/SOrange/SFV_Roof_Bisect_R_S_Orange_001.fbx"
const HALF_SPAN := 1.6217227


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_build_environment(world)
	var sources := [
		{"label": "bisect left blue", "path": BISECT_LEFT_BLUE},
		{"label": "bisect right blue", "path": BISECT_RIGHT_BLUE},
		{"label": "bisect left orange", "path": BISECT_LEFT_ORANGE},
		{"label": "bisect right orange", "path": BISECT_RIGHT_ORANGE},
	]
	for index in sources.size():
		var centre := Vector3(-14.0 + float(index) * 9.0, 0.0, -9.0)
		_add_scene(world, String(sources[index].path), centre, 0.0)
		_add_label(world, String(sources[index].label), centre + Vector3.UP * 5.0)
	# Candidate valley: one six-metre blue gable approaches the orange eave.
	# Each row tests the only two atomic handedness assignments. The ordinary
	# orange half-tiles are omitted at the contact instead of left underneath.
	for row in 2:
		var centre := Vector3(-7.0 + float(row) * 14.0, 0.0, 7.0)
		var left_path := BISECT_LEFT_ORANGE if row == 0 else BISECT_RIGHT_ORANGE
		var right_path := BISECT_RIGHT_ORANGE if row == 0 else BISECT_LEFT_ORANGE
		_add_scene(world, left_path, centre + Vector3(-HALF_SPAN, 0.0, -1.5), PI)
		_add_scene(world, right_path, centre + Vector3(-HALF_SPAN, 0.0, 1.5), PI)
		# Preserve the opposite orange slope of the host ridge.
		for z in [-1.5, 1.5]:
			_add_scene(world, HALF_ORANGE,
				centre + Vector3(HALF_SPAN, 0.0, z), 0.0)
		# Perpendicular blue branch ends at the host ridge/eave line.
		for x in [-1.5, 1.5]:
			_add_scene(world, HALF_BLUE,
				centre + Vector3(-3.0 + x, 0.0, -HALF_SPAN), PI * 0.5)
			_add_scene(world, HALF_BLUE,
				centre + Vector3(-3.0 + x, 0.0, HALF_SPAN), -PI * 0.5)
		_add_label(world, "T valley L/R" if row == 0 else "T valley R/L",
			centre + Vector3.UP * 6.0)
	var camera := Camera3D.new()
	camera.fov = 46.0
	camera.position = Vector3(28.0, 25.0, 33.0)
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	for unused in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var output := _argument("--output", "/tmp/warren-roof-bisect-review.png")
	var captured := root.get_texture().get_image()
	assert(captured != null and captured.save_png(output) == OK)
	print("[roof_bisect_review] captured %s" % output)
	quit()


static func _add_scene(parent: Node3D, path: String, position: Vector3,
		yaw: float) -> void:
	var scene := load(path) as PackedScene
	assert(scene != null)
	var instance := scene.instantiate() as Node3D
	instance.position = position
	instance.rotation.y = yaw
	parent.add_child(instance)


static func _add_label(parent: Node3D, value: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 72
	label.pixel_size = 0.007
	label.outline_size = 10
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


static func _build_environment(world: Node3D) -> void:
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
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50.0, 35.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718d50")
	material.roughness = 1.0
	plane.material = material
	ground.mesh = plane
	world.add_child(ground)


static func _argument(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			return args[index + 1]
	return fallback
