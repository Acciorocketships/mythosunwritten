extends "res://tests/harness/travel_profile.gd"

## Ordinary character physics and production freeze/streaming, aimed south at
## photo 1's chunk boundary. Its missing crosshair cannot determine a camera;
## screenshots explicitly use an inferred, identically pinned review camera.
class SouthController extends CharacterController:
	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return Vector2(0, -1)

const PIN := Vector3(287.4, 5, -1344)
var _walk_started := false
var _pin_captured := false
var _timed_captured := false
var _walk_camera: Camera3D
var _crossing: Dictionary = {}

func _ready() -> void:
	super._ready()
	_mode = "south_walk"
	_player.controller = SouthController.new()
	_walk_camera = _world.get_node("Camera3D")
	_walk_camera.set_process(false)
	_walk_camera.set_process(false)
	_walk_camera.set("target", null)
	_walk_camera.global_position = PIN + Vector3(4, 9, 10)
	_walk_camera.look_at(PIN, Vector3.UP)

func _process(delta: float) -> void:
	super._process(delta)
	if not _running: return
	if not _walk_started:
		_walk_started = true
		_crossing = {"start": str(_player.position), "camera_kind": "inferred",
			"camera": str(_walk_camera.global_transform), "pin": str(PIN)}
	if _player.position.z < PIN.z - 12 and not _crossing.has("crossed_seconds"):
		_crossing.crossed_seconds = (Time.get_ticks_msec() - _run_start) / 1000.0
		_crossing.frozen_seconds_at_crossing = _frozen_seconds
		_crossing.crossed_position = str(_player.position)
		_crossing.grounded = _player.is_on_floor()
	if not _pin_captured and _player.position.z <= PIN.z:
		_pin_captured = true
		_capture.call_deferred("crossing_inferred")
	if not _timed_captured and Time.get_ticks_msec() - _run_start >= 15000:
		_timed_captured = true
		_capture.call_deferred("15s_inferred")

func _capture(label: String) -> void:
	if Helper.is_headless(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_report_path.get_basename()+"_"+label+".png")

func _finish(status: String) -> void:
	_crossing["end"] = str(_player.position)
	_crossing["final_max_fps"] = Engine.max_fps
	_crossing["frozen_seconds"] = _frozen_seconds
	FileAccess.open(_report_path+".crossing.json",FileAccess.WRITE).store_string(JSON.stringify(_crossing,"  "))
	super._finish(status)
