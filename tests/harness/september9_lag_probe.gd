extends "res://tests/harness/travel_profile.gd"

## A pinned view as the world fills, followed by bracketed graphics ablations.
## Movement is intentionally stationary: this first probe distinguishes scene
## completion from degradation attributable to travelling through new regions.
class IdleController extends CharacterController:
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2:
		return Vector2.ZERO

func _ready()->void:
	super._ready()
	_mode="stationary"
	_player.controller=IdleController.new()
	var camera:=_world.get_node("Camera3D") as Camera3D
	camera.set_physics_process(false)
	camera.set_process(false)
	camera.set("target",null)
	var target:=Vector3(_x,5,_z)
	camera.global_position=target+Vector3(4,9,10)
	camera.look_at(target,Vector3.UP)

func _process(delta:float)->void:
	var previous_sample:=_last_sample
	super._process(delta)
	if _last_sample!=previous_sample and not _samples.is_empty() and _streamer._grass_streamer!=null:
		_samples[-1]["grass"]=_streamer._grass_streamer.stats()

func _render_probe()->void:
	var args:=OS.get_cmdline_user_args()
	if args.has("--capture-only"):
		_phase="settling"
		_player.process_mode=Node.PROCESS_MODE_DISABLED
		_streamer.set_process(false)
		_streamer._mutex.lock()
		_streamer._jobs.clear()
		_streamer._queued.clear()
		_streamer._grass_queued.clear()
		_streamer._followups.clear()
		_streamer._mutex.unlock()
		while not _streamer.streaming_profile_snapshot().active_job.is_empty():
			await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_report_path.get_basename()+".png")
	else:
		await super._render_probe()
	var index:=args.find("--save-fixture")
	if index>=0 and index+1<args.size():
		var helper:=load("res://tests/harness/september9_render_fixture.gd")
		print("RENDER_FIXTURE saved=",helper.save_world(_world,args[index+1])," path=",args[index+1])
