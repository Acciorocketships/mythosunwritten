extends Node
## Repeated real-player relocation through the unchanged production queue.
## Short visits intentionally abandon active work; every fourth destination
## waits for real activation and then uses ordinary character movement.
class ProbeController extends CharacterController:
	var motion:=Vector2.ZERO
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2:return motion
const SITES := [Vector3(1820.8,27.1,-259),Vector3(1957.3,19.2,-987.5),Vector3(892.5,8.6,-1828.3),Vector3(475,21.1,-2077.8),Vector3(982.2,9.3,-2079.8),Vector3(268.2,8,-359.4),Vector3(1618,12,-571),Vector3(1820.8,27.1,-259),Vector3(1148.6,16,407.9),Vector3(2010,16,408),Vector3(-1296,16,1296),Vector3(-1440,16,-3360),Vector3(892.5,8.6,-1828.3),Vector3(475,21.1,-2077.8),Vector3(268.2,8,-359.4),Vector3(1618,12,-571)]
var _stream:FieldTerrainStreamer
var _player:CharacterBody3D
var _controller:=ProbeController.new()
var _world:Node3D
var _phase:="startup"
var _site:=-1
var _start:=0
var _last_sample:=0
var _last_event:=0
var _report:="/private/tmp/september10-stream.json"
var _log:FileAccess
var _events:FileAccess
var _visits:Array=[]
var _startup_ms:=0
var _hold:=false
var _hold_position:=Vector3.ZERO
var _dwell:=10.0
var _walk_seconds:=40.0
var _count:=16
var _first:=0
var _long_route:=false
var _frozen:=0.0
var _distance:=0.0
var _previous:=Vector3.ZERO
func _ready()->void:
	var args:=OS.get_cmdline_user_args()
	for i in args.size():
		if args[i]=="--report":_report=args[i+1]
		if args[i]=="--dwell":_dwell=float(args[i+1])
		if args[i]=="--walk":_walk_seconds=float(args[i+1])
		if args[i]=="--count":_count=mini(int(args[i+1]),SITES.size())
		if args[i]=="--first":_first=maxi(0,int(args[i+1]))
		if args[i]=="--long-route":_long_route=true
	_log=FileAccess.open(_report+".jsonl",FileAccess.WRITE)
	_events=FileAccess.open(_report+".events.jsonl",FileAccess.WRITE)
	Engine.max_fps=60
	_start=Time.get_ticks_msec()
	WaterField.profile_source_cost=true
	_world=preload("res://scenes/world.tscn").instantiate()
	_player=_world.get_node("Characters/Character")
	_stream=_world.get_node("FieldTerrain")
	_stream.SEED_OVERRIDE=2697992464;_stream.PROFILE_STREAMING=true
	_player.position=Vector3(1618,12,-571);_player.controller=_controller
	add_child(_world)
	_previous=_player.position
	_run.call_deferred()
func _process(delta:float)->void:
	if _stream==null:return
	if _hold:
		_player.position=_hold_position;_player.velocity=Vector3.ZERO
	if _phase=="walk":
		_distance+=Vector2(_player.position.x-_previous.x,_player.position.z-_previous.z).length()
		if _stream._player_frozen:_frozen+=delta
	_previous=_player.position
	var now:=Time.get_ticks_msec()
	if now-_last_sample<1000:return
	_last_sample=now
	var snap:=_stream.streaming_profile_snapshot()
	for event:Dictionary in snap.recent_events:
		if int(event.serial)<=_last_event:continue
		_last_event=event.serial;_events.store_line(JSON.stringify(event))
	_events.flush()
	var row:={"msec":now,"elapsed_ms":now-_start,"phase":_phase,"site":_site,"position":str(_player.position),"frozen":_stream._player_frozen,"worker":_stream.worker_progress_snapshot(),"active":snap.active_job,"queue_head":snap.queue_head,"queued":snap.queued,"built":snap.built,"pending":snap.pending_terrain,"feature_pending":snap.feature_pending,"counts":snap.counts,"cache":snap.field_cache,"memory":Performance.get_monitor(Performance.MEMORY_STATIC)}
	_log.store_line(JSON.stringify(row));_log.flush()
	if int(now/1000)%15==0:print("TELEPORT_PROFILE ",_site," ",_phase," queued=",snap.queued," worker=",row.worker)
func _run()->void:
	while not _stream.startup_loading_complete():
		if Time.get_ticks_msec()-_start>900000:_finish("startup_timeout");return
		await get_tree().create_timer(.2).timeout
	_startup_ms=Time.get_ticks_msec()-_start
	for i in range(_first, _count):
		_site=i;_phase="arrival";_hold=true;_hold_position=SITES[i]
		_player.position=_hold_position;_player.velocity=Vector3.ZERO
		_controller.motion=Vector2.ZERO
		var started:=Time.get_ticks_msec()
		var visit:={"index":i,"target":str(SITES[i]),"arrival_msec":started,"settle":i%4==3 or i==_count-1}
		print("TELEPORT_BEGIN ",JSON.stringify(visit))
		await get_tree().create_timer(_dwell).timeout
		if visit.settle:
			_phase="settle"
			while _stream._player_frozen:
				if Time.get_ticks_msec()-started>900000:visit["timeout"]=true;break
				await get_tree().create_timer(.2).timeout
			visit["ready_msec"]=Time.get_ticks_msec()-started
			if not _stream._player_frozen:
				_phase="walk";_hold=false;_frozen=0;_distance=0
				_controller.motion=Vector2(0,-1)
				await get_tree().create_timer(_walk_seconds).timeout
				_controller.motion=Vector2.ZERO
				visit["walk_meters"]=_distance;visit["walk_frozen_seconds"]=_frozen
		visit["depart_position"]=str(_player.position)
		visit["depart_frozen"]=_stream._player_frozen
		visit["duration_msec"]=Time.get_ticks_msec()-started
		_visits.append(visit)
		FileAccess.open(_report,FileAccess.WRITE).store_string(JSON.stringify({"status":"running","startup_msec":_startup_ms,"visits":_visits},"  "))
		print("TELEPORT_END ",JSON.stringify(visit))
	if _long_route: await _extended_walk()
	_finish("complete")

func _extended_walk() -> void:
	_site=16;_phase="arrival";_hold=true
	_hold_position=Vector3(287.4,32,-1238)
	_player.position=_hold_position;_player.velocity=Vector3.ZERO
	var started:=Time.get_ticks_msec()
	for frame in 3: await get_tree().process_frame
	while _stream._player_frozen:
		if Time.get_ticks_msec()-started>900000:
			_visits.append({"index":16,"timeout":true});return
		await get_tree().create_timer(.2).timeout
	var ready_ms:=Time.get_ticks_msec()-started
	var query:=PhysicsRayQueryParameters3D.create(
		Vector3(287.4,256,-1238),Vector3(287.4,-256,-1238),1,[_player.get_rid()])
	var hit:=_player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_visits.append({"index":16,"no_ground":true});return
	_player.position=hit.position+Vector3.UP*.2
	_hold=false
	await get_tree().create_timer(1).timeout
	_phase="walk";_frozen=0;_distance=0;_previous=_player.position
	var origin:=_player.position
	_controller.motion=Vector2(0,-1)
	await get_tree().create_timer(120).timeout
	_controller.motion=Vector2.ZERO
	_visits.append({"index":16,"route":"September 9 south walk after 16 teleports",
		"ready_msec":ready_ms,"start":str(origin),"end":str(_player.position),
		"walk_seconds":120,"walk_meters":_distance,"walk_frozen_seconds":_frozen})
	print("TELEPORT_LONG_WALK ",JSON.stringify(_visits[-1]))

func _finish(status:String)->void:
	_phase="done";_controller.motion=Vector2.ZERO
	FileAccess.open(_report,FileAccess.WRITE).store_string(JSON.stringify({"status":status,"startup_msec":_startup_ms,"visits":_visits,"streaming":_stream.streaming_profile_snapshot()},"  "))
	print("TELEPORT_RESULT ",status," visits=",_visits.size()," report=",_report)
	get_tree().quit(0 if status=="complete" else 1)
