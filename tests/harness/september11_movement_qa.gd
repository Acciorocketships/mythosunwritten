extends "res://tests/harness/village_reported_qa.gd"
var _frozen := false
const SNAPSHOT := "res://docs/qa/2026-09-11-manual/01-movement/village.scn"
var _ticks := 180

func _read_args() -> void:
	super._read_args()
	var args := OS.get_cmdline_user_args()
	var index := args.find("--ticks")
	if index >= 0 and index+1 < args.size(): _ticks = int(args[index+1])

func _grass_enabled() -> bool:
	return OS.get_cmdline_user_args().has("--grass")

func _ready() -> void:
	_frozen = OS.get_cmdline_user_args().has("--frozen")
	if not _frozen:
		super._ready()
		return
	Engine.max_fps = 30
	_read_args()
	DirAccess.make_dir_recursive_absolute(_output_dir)
	get_window().size = Vector2i(1920,1080)
	var snapshot := SNAPSHOT.get_base_dir().path_join("village-no-grass.scn") if OS.get_cmdline_user_args().has("--no-grass-snapshot") else SNAPSHOT
	var snapshot_argument := OS.get_cmdline_user_args().find("--snapshot")
	if snapshot_argument >= 0: snapshot = OS.get_cmdline_user_args()[snapshot_argument+1]
	var world := (load(snapshot) as PackedScene).instantiate() as Node3D
	for key: StringName in world.get_meta("shader_globals"):
		RenderingServer.global_shader_parameter_set(key,world.get_meta("shader_globals")[key])
	add_child(world)
	var characters := Node3D.new()
	world.add_child(characters)
	_character = preload("res://characters/character.tscn").instantiate()
	_character.position = _spot[2]
	characters.add_child(_character)
	_character.set_physics_process(false)
	_camera = Camera3D.new()
	_camera.set_script(preload("res://scripts/camera/camera.gd"))
	_camera.camera = _camera
	_camera.target = _character
	_camera.position = Vector3(_spot[2])+Vector3(0,16,26)
	world.add_child(_camera)
	_camera.make_current()
	_camera.set_physics_process(false)
	_streamer = FieldTerrainStreamer.new()
	_run.call_deferred()
## Production town, actor and camera. Distinguish collision, lost requested
## input, streaming holds and expensive visibility updates in one replay.
func _spots() -> Array:
	return [
		["04_village", "Screenshot 2026-09-11 at 6.37.38 PM.png", Vector3(-409.0,25.1,-262.7), Vector3(-409.0,26.3,-262.4)],
		["03_block", "Screenshot 2026-09-11 at 6.37.47 PM.png", Vector3(-409.0,25.1,-262.7), Vector3(-409.4,26.3,-262.7)],
		["02_bubble", "Screenshot 2026-09-11 at 6.38.05 PM.png", Vector3(-389.1,18.5,-268.5), Vector3(-398.9,25.1,-268.1)],
		["01_black", "Screenshot 2026-09-11 at 6.39.15 PM.png", Vector3(-389.3,19.1,-274.1), Vector3(-398.6,27.2,-266.2)]
	]

func _run() -> void:
	await get_tree().create_timer(5.0).timeout
	_camera = get_viewport().get_camera_3d()
	_camera.set_physics_process(false)
	if not _frozen:
		assert(await _wait_for_site())
		_camera._visibility.clear()
		preload("res://tests/harness/september11_snapshot.gd").save(_character.get_parent().get_parent(),_character,SNAPSHOT)
	_character.set_physics_process(false)
	if not OS.get_cmdline_user_args().has("--skip-pairs"): await _matched_pairs()
	var rows := []
	for spot: Array in ([_spot] if OS.get_cmdline_user_args().has("--single") else _spots()):
		_character.global_position = spot[2]
		_character.velocity = Vector3.ZERO
		_character.step_visual_offset_y = 0.0
		_character._update_step_visual_smoothing(0.0)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26.0,16.0,1.0)
		_camera.global_position = eye
		_camera.reset_orbit()
		_camera._physics_process(0.0)
		for frame in 30:
			_camera._physics_process(1.0/60)
			await get_tree().process_frame
		await _shot(String(spot[0]))
		for implementation: String in (["after"] if OS.get_cmdline_user_args().has("--only-after") else ["before", "after", "disabled"]):
			var enabled := implementation != "disabled"
			_replace_bubble(implementation == "before")
			_camera.visibility_bubble_enabled = enabled
			_character.global_position = spot[2]
			_character.velocity = Vector3.ZERO
			_character.step_visual_offset_y = 0.0
			_character._update_step_visual_smoothing(0.0)
			_camera.global_position = eye
			_camera.reset_orbit()
			var samples := []
			var previous_tick := Time.get_ticks_usec()
			Input.action_press("forward")
			for tick in _ticks:
				await get_tree().physics_frame
				var wall_us := Time.get_ticks_usec()-previous_tick
				previous_tick = Time.get_ticks_usec()
				var before := _character.global_position
				var start := Time.get_ticks_usec()
				_camera._yaw += 0.025
				_camera._physics_process(1.0/60)
				var camera_us := Time.get_ticks_usec()-start
				if not _streamer._player_frozen: _character._physics_process(1.0/60)
				var collisions := []
				for index in _character.get_slide_collision_count():
					var hit := _character.get_slide_collision(index)
					var collider := hit.get_collider() as CollisionObject3D
					var owner_id := collider.shape_find_owner(hit.get_collider_shape_index())
					collisions.append({"normal":str(hit.get_normal()),"position":str(hit.get_position()),
						"shape":str(collider.shape_owner_get_owner(owner_id).get_path()),"collider":str(collider.get_path())})
				samples.append({"tick":tick,"position":str(_character.global_position),"step":before.distance_to(_character.global_position),
					"camera_us":camera_us,"wall_us":wall_us,"input":str(_character.streaming_velocity()),"frozen":_streamer._player_frozen,"collisions":collisions,
					"profile":_camera._visibility.timings.duplicate() if OS.get_cmdline_user_args().has("--profile") and implementation=="after" else null})
				if tick % 60 == 0: print("MOVEMENT spot=",spot[0]," bubble=",enabled," tick=",tick," camera_us=",camera_us)
			Input.action_release("forward")
			rows.append({"spot":spot[0],"bubble":enabled,"implementation":implementation,
				"screen_diameter":_camera.visibility_screen_diameter,"samples":samples})
		_camera.visibility_bubble_enabled = true
	FileAccess.open(_output_dir+"/movement.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	if _frozen: _streamer.free()
	get_tree().quit()

func _replace_bubble(before: bool) -> void:
	_camera._visibility.clear()
	_camera._visibility.free()
	_camera._visibility = preload("res://tests/fixtures/september11/VisibilityBefore.gd").new() if before else CameraVisibilityBubble.new()
	if not before and OS.get_cmdline_user_args().has("--profile"):
		_camera._visibility.free()
		_camera._visibility = preload("res://tests/fixtures/september11/ProfiledBubble.gd").new()
	_camera.add_child(_camera._visibility)

func _matched_pairs() -> void:
	var output := _output_dir
	var world := _character.get_parent().get_parent()
	var previous_mode: ProcessMode = world.process_mode
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_character.anim_tree.active = false
	var poses := []
	for spot: Array in ([_spot] if OS.get_cmdline_user_args().has("--single") else _spots()):
		_character.global_position = spot[2]
		_character.step_visual_offset_y = 0.0
		_character._update_step_visual_smoothing(0.0)
		var eye := ReviewCam.solve_cam(spot[2],spot[3],26.0,16.0,1.0)
		for angle: float in [0.0,-8.0,8.0]:
			var pose := Vector3(spot[2])+(eye-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			_camera.global_position = pose
			_camera.look_at(Vector3(spot[2])+Vector3.UP)
			poses.append({"spot":spot[0],"angle":angle,"eye":str(pose),"player":str(spot[2]),"crosshair":str(spot[3])})
			for before: bool in [true,false]:
				_replace_bubble(before)
				for frame in 12:
					_camera._visibility.update_bubble(_camera,_character,spot[2],3.8,.12,.1)
					await get_tree().process_frame
				_output_dir = output.path_join("matched-before" if before else "matched-after")
				DirAccess.make_dir_recursive_absolute(_output_dir)
				await _shot("%s_%d" % [spot[0],int(angle)])
	_output_dir = output
	FileAccess.open(output+"/poses.json",FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	_character.anim_tree.active = true
	world.process_mode = previous_mode
