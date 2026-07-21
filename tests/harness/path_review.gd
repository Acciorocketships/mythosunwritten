extends Node3D

## Actual terrain-mesher review of the centred path coordinate system.
## Run interactively or capture a stable frame:
##   godot --path /Users/ryko/story res://tests/harness/path_review.tscn \
##     -- --capture /tmp/path-review.png
## `--verify-only` builds the same payload headlessly and exits.

const CORE := Rect2(Vector2.ZERO, Vector2.ONE * TerrainChunkMesher.CHUNK_WORLD)
var _capture_path := ""
var _focus := "overview"

func _ready() -> void:
	_read_args()
	_build_stage()
	_build_paths()
	if OS.get_cmdline_user_args().has("--verify-only"):
		print("[path_review] verified centred straight/L/T/X/village-node terrain payload")
		get_tree().quit()
	elif not _capture_path.is_empty():
		_capture.call_deferred()

func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--capture":
			_capture_path = args[i + 1]
		elif args[i] == "--focus":
			_focus = args[i + 1]

func _build_stage() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#92adba")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#dce6df")
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -28.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	var camera_target := Vector3(96.0, 0.0, 88.0)
	match _focus:
		"corner":
			camera.position = Vector3(96.0, 52.0, 88.0)
			camera_target = Vector3(96.0, 0.0, 48.0)
			camera.fov = 34.0
		"plaza":
			camera.position = Vector3(144.0, 52.0, 136.0)
			camera_target = Vector3(144.0, 0.0, 96.0)
			camera.fov = 34.0
		_:
			camera.position = Vector3(96.0, 155.0, 235.0)
			camera.fov = 48.0
	camera.look_at_from_position(camera.position, camera_target)
	add_child(camera)

func _build_paths() -> void:
	var masks := {
		Vector2i(2, 2): 3,   # straight
		Vector2i(4, 2): 6,   # L
		Vector2i(2, 4): 7,   # T
		Vector2i(4, 4): 15,  # X
		Vector2i(6, 4): 2,   # future-village approach
	}
	var nodes := {Vector2i(6, 4): true}
	var corridors: Array[Rect2] = []
	for cell: Vector2i in masks:
		var centre := Vector2(cell) * TerrainSurfaceField.TILE
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.DOWN, Vector2i.UP]:
			var bit: int = {Vector2i.RIGHT: 1, Vector2i.LEFT: 2,
				Vector2i.DOWN: 4, Vector2i.UP: 8}[direction]
			if (int(masks[cell]) & bit) != 0:
				corridors.append(PathPlan._connection_rect(centre, direction))
	var paths := PathContext.new(CORE, corridors, corridors,
		EnvironmentInstancePayload.new(), 2.0, masks, nodes)
	var height_plan := HeightfieldPlan.new(1, 1.0, 1, "mean", 1)
	height_plan.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var region := height_plan.compute_region(4, 4, 8)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._region = region
	water._coverage = CORE
	water._shore_limit = 0.0
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	add_child(mesher.commit_chunk(mesher.compute_chunk(Vector2i.ZERO,
		region, water, paths)))
	_add_rejected_strip()
	_add_character_marker(Vector3(48.0, 1.0, 58.0))
	for item: Dictionary in [
		{"text": "straight 4 m", "cell": Vector2i(2, 2)},
		{"text": "L", "cell": Vector2i(4, 2)},
		{"text": "T", "cell": Vector2i(2, 4)},
		{"text": "X", "cell": Vector2i(4, 4)},
		{"text": "village circle 16 m", "cell": Vector2i(6, 4)},
	]:
		var label := Label3D.new()
		label.text = item.text
		label.position = Vector3(item.cell.x * 24.0, 3.0, item.cell.y * 24.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 48
		add_child(label)

func _add_rejected_strip() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(6.0, 0.04, 58.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.15, 0.12, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var rejected := MeshInstance3D.new()
	rejected.mesh = mesh
	rejected.position = Vector3(166.0, 0.08, 48.0)
	add_child(rejected)
	var label := Label3D.new()
	label.text = "rejected offset 6 m"
	label.position = Vector3(166.0, 3.0, 48.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	add_child(label)

func _add_character_marker(position: Vector3) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#4059c7")
	capsule.material = material
	var marker := MeshInstance3D.new()
	marker.mesh = capsule
	marker.position = position
	add_child(marker)

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_capture_path)
	assert(error == OK, "failed to save path review capture")
	print("[path_review] captured %s" % _capture_path)
	get_tree().quit()
