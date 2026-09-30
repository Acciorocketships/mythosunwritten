extends RefCounted
## Cached-world traversal, loaded chunks asserted before streaming is paused.
class WalkController extends CharacterController:
	var direction:=Vector2.ZERO
	func get_move_vector(_body:CharacterBody3D,_dt:float)->Vector2:return direction

func run(review:Node3D)->void:
	var _walks:Array[Dictionary]=[{"id":"p04-up","start":Vector3(280.5,41.7,901.7),"direction":Vector3(0,0,-1),"distance":4.0},{"id":"p04-down","start":Vector3(280.5,44,898.5),"direction":Vector3(0,0,1),"distance":4.0}]
	var _character:CharacterBody3D=review._character
	var _streamer:FieldTerrainStreamer=review._streamer
	var _output_dir=review._output_dir
	var iteration=0
	if _walks.is_empty():return
	var original:CharacterController=_character.controller
	var controller:=WalkController.new()
	_character.controller=controller
	_character.set_physics_process(false)
	_streamer.CHUNK_RADIUS=0
	var rows:=[]
	for walk:Dictionary in _walks:
		await review._grass_at(walk.start)
		# Camera teleports can demand an arrival halo beyond the review's loaded
		# set. Walk only through verified loaded chunks, with streaming paused;
		# retain the production character, controller and collision unchanged.
		for distance in range(0,ceili(float(walk.distance))+2):
			var point:Vector3=walk.start+walk.direction.normalized()*distance
			assert(_streamer._built.has(FieldTerrainStreamer.chunk_of(point)))
		_streamer.set_process(false)
		_streamer._freeze_player(false)
		await review.get_tree().physics_frame
		_character.global_position=walk.start+Vector3.UP*.06
		_character.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		for tick in 30:
			await review.get_tree().physics_frame
			_character._physics_process(1.0/60.0)
		var start:=_character.global_position
		var direction:Vector3=(walk.direction as Vector3).normalized()
		controller.direction=Vector2(direction.x,direction.z)
		var trace:=[];var contacts:={}
		for tick in 360:
			await review.get_tree().physics_frame
			_character._physics_process(1.0/60.0)
			if tick%15==0:trace.append([_character.position.x,_character.position.y,_character.position.z])
			for index in _character.get_slide_collision_count():
				var hit:=_character.get_slide_collision(index)
				contacts[str(hit.get_normal().snapped(Vector3.ONE*.05))]=true
			if (_character.position-start).dot(direction)>=float(walk.distance):break
		var finish:=_character.global_position
		rows.append({"id":walk.id,"start":[start.x,start.y,start.z],"end":[finish.x,finish.y,finish.z],"travel":(finish-start).dot(direction),"rise":finish.y-start.y,"on_floor":_character.is_on_floor(),"passed":(finish-start).dot(direction)>=float(walk.distance),"trace":trace,"contacts":contacts.keys()})
		controller.direction=Vector2.ZERO
		_streamer.set_process(true)
	_character.controller=original
	FileAccess.open("%s/%02d/walks.json"%[_output_dir,iteration],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("[cliff_site_review] walks ",JSON.stringify(rows))
