extends Node3D

const SPOTS := [
	["cliff_backing", Vector3(564.9, 13.3, -760.7), Vector3(565.2, 13.5, -760.5)],
	["slope_apron", Vector3(765.1, 24.0, -1476.3), Vector3(764.8, 24.2, -1476.0)],
	["ground_hole", Vector3(930.6, 2.4, -2767.1), Vector3(930.5, 2.6, -2766.7)],
	["missing_town", Vector3(1953.3, 5.1, -4915.8), Vector3(1953.2, 5.3, -4915.4)],
]
var _phase := "before"
var _spot_index := 0
var _out := "res://docs/qa/2026-09-06-terrain"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_phase = args[0]
	if args.size() > 1:
		_spot_index = int(args[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var world: Node = load("res://scenes/world.tscn").instantiate()
	var terrain_streamer := world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	terrain_streamer.CHUNK_RADIUS = 1
	terrain_streamer.KEEP_RADIUS = 2
	var character := world.find_child("Character", true, false) as CharacterBody3D
	character.position = SPOTS[_spot_index][1]
	character.set_physics_process(false)
	add_child(world)
	_run.call_deferred()

func _shot(suffix: String) -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s%s.png" % [_out, SPOTS[_spot_index][0], _phase, suffix]
	get_viewport().get_texture().get_image().save_png(path)
	print("TERRAIN_QA shot=", path)

func _run() -> void:
	var spot: Array = SPOTS[_spot_index]
	var character := find_child("Character", true, false) as CharacterBody3D
	var camera := get_viewport().get_camera_3d()
	camera.set("target", null)
	camera.set_physics_process(false)
	camera.set_process(false)
	camera.global_position = ReviewCam.solve_cam(spot[1], spot[2])
	camera.look_at(spot[1], Vector3.UP)
	var streamer := find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	var centre := FieldTerrainStreamer.chunk_of(spot[1])
	var started := Time.get_ticks_msec()
	while true:
		character.global_position = spot[1]
		var built: Dictionary = streamer.get("_built")
		var complete := true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				complete = complete and built.has(centre + Vector2i(dx, dz))
		if complete:
			break
		if Time.get_ticks_msec() - started > 900000:
			push_error("TERRAIN_QA incomplete neighbourhood: %s" % built.keys())
			get_tree().quit(1)
			return
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(8.0).timeout
	character.global_position = spot[1]
	await _shot("")
	await get_tree().create_timer(1.0).timeout
	await _shot("_later")
	if _phase == "diagnostic":
		var lights := find_children("*", "DirectionalLight3D", true, false)
		for light: DirectionalLight3D in lights:
			light.shadow_enabled = false
		await _shot("_no_shadows")
		var material := CliffDressing.shared_material() as StandardMaterial3D
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		await _shot("_unshaded")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var materials := {}
	for n: Node in find_children("*", "GeometryInstance3D", true, false):
		var colors := {"Surface": Color.RED, "Aprons": Color.BLUE, "CliffFaces": Color.MAGENTA}
		if colors.has(String(n.name)):
			materials[n] = n.material_override
			n.material_override = ReviewCam._flat(colors[String(n.name)])
	await _shot("_owners")
	for n: Node in materials:
		n.material_override = materials[n]
	camera.global_position += Vector3.UP * 2.0
	camera.look_at(spot[1], Vector3.UP)
	await _shot("_raised")
	if spot[0] == "missing_town":
		# The restored settlement can occupy the formerly empty camera position.
		# Keep that exact view, then show the same location from outside its mass.
		var original_camera := ReviewCam.solve_cam(spot[1],spot[2])
		camera.global_position = spot[1] + (original_camera-spot[1])*10.0 + Vector3.UP*30.0
		camera.look_at(spot[1],Vector3.UP)
		await _shot("_overview")
	print("TERRAIN_QA complete ", spot[0])
	get_tree().quit()
