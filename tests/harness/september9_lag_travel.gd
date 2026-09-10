extends "res://tests/harness/travel_profile.gd"

## A repeatable out-and-back residency stress, explicitly obstacle-bypassing.
## Ordinary walking acceptance belongs to september9_stream_walk instead.
## Travel crosses new terrain, returns to the same location, then settles so
## retained cache/node counts can be separated from changing local content.
class IdleController extends CharacterController:
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2:
		return Vector2.ZERO

func _ready()->void:
	super._ready()
	_mode="residency_out_and_back"
	_player.controller=IdleController.new()
	var camera:=_world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.set_process(false)
	camera.set("target",null)
	camera.global_position=Vector3(_x,5,_z)+Vector3(4,9,10)
	camera.look_at(Vector3(_x,5,_z),Vector3.UP)

func _process(delta:float)->void:
	if _running:
		var elapsed:=float(Time.get_ticks_msec()-_run_start)/1000.0
		# 120 seconds out, 120 back, then 120 seconds at the initial view.
		var offset:=minf(elapsed,240.0-elapsed)*10.0 if elapsed<240.0 else 0.0
		_player.position=Vector3(_x,32.0,_z-offset)
		_player.velocity=Vector3.ZERO
		_phase="outbound" if elapsed<120.0 else ("return" if elapsed<240.0 else "returned_settling")
	super._process(delta)
