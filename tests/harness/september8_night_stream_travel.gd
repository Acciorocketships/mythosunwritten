extends "res://tests/harness/village_reported_qa.gd"

var _trace: Array = []
class TravelController extends CharacterController:
	func get_move_vector(_character: CharacterBody3D,_delta: float)->Vector2:
		return Vector2.RIGHT
func _spots() -> Array:
	return [
		["03_loading_gap","11.02.20 PM",Vector3(1148.6,15.4,407.9),Vector3(1148.3,15.6,407.8)],
		["06_loading_gap","11.06.55 PM",Vector3(1911.3,11.5,408.1),Vector3(1911.3,11.7,408.4)]]

func _ready() -> void:
	Engine.max_fps=60
	_read_args()
	get_window().size=Vector2i(1718,1035)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer=world.find_child("FieldTerrain",true,false) as FieldTerrainStreamer
	_character=world.find_child("Character",true,false) as CharacterBody3D
	_streamer.SEED_OVERRIDE=WORLD_SEED
	_streamer.CHUNK_RADIUS=1
	_streamer.KEEP_RADIUS=2
	_streamer.GRASS_ENABLED=false
	_streamer.PROFILE_STREAMING=true
	_character.position=Vector3(_spot[2])-Vector3.RIGHT*96
	_character.velocity=Vector3.RIGHT*10
	_character.set_physics_process(false)
	add_child(world)
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	_camera=get_viewport().get_camera_3d()
	_camera.set("target",null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	_camera.global_position=ReviewCam.solve_cam(_spot[2],_spot[3])
	_camera.look_at(_spot[2],Vector3.UP)
	var timeout := Time.get_ticks_msec()+900000
	while not _streamer.startup_loading_complete():
		assert(Time.get_ticks_msec()<timeout)
		await get_tree().process_frame
	_character.set_physics_process(false)
	_character.velocity=Vector3.RIGHT*10
	var start: Vector3=Vector3(_spot[2])-Vector3.RIGHT*96
	var began := Time.get_ticks_usec()
	var next_sample := 0.0
	var photographed := false
	while true:
		var elapsed := (Time.get_ticks_usec()-began)/1000000.0
		if elapsed>=9.6 and photographed:break
		_character.global_position=start+Vector3.RIGHT*minf(elapsed,9.6)*10
		if elapsed>=next_sample:
			_record(elapsed)
			next_sample+=0.25
		if elapsed>=9.6 and not photographed:
			photographed=true
			_character.global_position=_spot[2]
			await _shot(String(_spot[0])+"_timed_exact")
		await get_tree().process_frame
	_character.global_position=_spot[2]
	_character.velocity=Vector3.ZERO
	_character.controller=TravelController.new()
	var frozen_frames := 0
	var crossing_trace: Array=[]
	for tick in 240:
		await get_tree().physics_frame
		if _streamer._player_frozen:
			frozen_frames+=1
		else:
			_character._physics_process(1.0/60)
		if tick%15==0:
			_record((Time.get_ticks_usec()-began)/1000000.0)
			crossing_trace.append(str(_character.global_position))
		if _character.global_position.x>Vector3(_spot[2]).x+12:break
	var crossing := {"frozen_frames":frozen_frames,"end":str(_character.global_position),
		"crossed":_character.global_position.x>Vector3(_spot[2]).x+12,
		"grounded":_character.is_on_floor(),"trace":crossing_trace}
	_character.velocity=Vector3.ZERO
	_character.global_position=_spot[2]
	FileAccess.open(_output_dir+"/travel.json",FileAccess.WRITE).store_string(JSON.stringify({
		"seed":WORLD_SEED,"start":str(start),"speed_m_s":10,"pin":str(_spot[2]),
		"camera":str(_camera.global_transform),"trace":_trace,"crossing":crossing},"  "))
	assert(await _wait_for_site())
	await _capture_spot(_spot)
	get_tree().quit()

func _record(elapsed: float) -> void:
	var target := FieldTerrainStreamer.chunk_of(Vector3(_spot[2])+Vector3.RIGHT*12)
	_trace.append({"seconds":elapsed,"position":str(_character.global_position),
		"next_chunk":str(target),"next_terrain_ready":_streamer._built.has(target),
		"next_features_ready":_streamer._feature_square_ready(target),
		"worker":_streamer.worker_progress_snapshot()})
