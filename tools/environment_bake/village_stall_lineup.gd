extends Node3D

## Phase-0 visual selector for the market atlas variants. Source scenes are
## intentionally loaded only by this bake-side probe; runtime village code
## continues to consume self-contained catalog assets.
const SOURCE_FORMAT := "res://assets/FantasyMarketFBX/FBX/Stall Color Variations/SFM_Stall_%03d.fbx"
const COLUMNS := 4
const SPACING := Vector2(7.0, 6.0)

func _ready() -> void:
	_build_environment()
	_build_lineup()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_path := _output_path()
	var error := get_viewport().get_texture().get_image().save_png(output_path)
	print("[village_stall_lineup] output=%s error=%d" % [output_path, error])
	get_tree().quit(0 if error == OK else 1)


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.78, 0.91)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 29.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.58, 0.24)
	material.roughness = 1.0
	plane.material = material
	ground.mesh = plane
	add_child(ground)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 31.0
	camera.position = Vector3(0.0, 25.0, 27.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.6, 0.0))
	camera.current = true
	add_child(camera)


func _build_lineup() -> void:
	var variants: Array[int] = []
	for index in range(1, 18):
		if ResourceLoader.exists(SOURCE_FORMAT % index):
			variants.append(index)
	var rows := ceili(float(variants.size()) / float(COLUMNS))
	for item_index in variants.size():
		var variant := variants[item_index]
		var packed := load(SOURCE_FORMAT % variant) as PackedScene
		assert(packed != null)
		var column := item_index % COLUMNS
		var row := item_index / COLUMNS
		var x := (float(column) - float(COLUMNS - 1) * 0.5) * SPACING.x
		var z := (float(row) - float(rows - 1) * 0.5) * SPACING.y
		var stall := packed.instantiate() as Node3D
		stall.position = Vector3(x, 0.0, z)
		add_child(stall)

		var label := Label3D.new()
		label.text = "%03d" % variant
		label.font_size = 72
		label.pixel_size = 0.006
		label.outline_size = 10
		label.modulate = Color.WHITE
		label.position = Vector3(x, 0.45, z + 2.3)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)


static func _output_path() -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			return args[index + 1]
	return "/tmp/mythos-village-stall-lineup.png"
