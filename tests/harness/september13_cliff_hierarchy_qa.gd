extends "res://tests/harness/september13_terrace_qa.gd"

func _read_args() -> void:
	assert("--offscreen" in OS.get_cmdline_user_args() or "--frozen" in OS.get_cmdline_user_args(),"Fresh hierarchy capture needs --offscreen")
	super._read_args()

func _spots() -> Array:
	var poses: Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/photo-poses.json"))
	var out:=[]
	for spot: Dictionary in poses:
		if String(spot.id) in ["P15","P17","P18"]:
			out.append([spot.id,"Cliff hierarchy",Vector3(spot.player[0],spot.player[1],spot.player[2]),Vector3(spot.crosshair[0],spot.crosshair[1],spot.crosshair[2])])
	return out

func _walk_corridor(_world: Node3D) -> void:
	var terraces:=preload("res://scripts/terrain/field/CliffTerraces.gd")
	var closest: Dictionary={}
	var distance:=INF
	for chunk: Vector2i in _streamer._built:
		var node: Node=_streamer._built[chunk]
		if not node.has_meta(&"grass_sampling"):continue
		var sampling: GrassSamplingContext=node.get_meta(&"grass_sampling")
		var data:=terraces.compute(sampling.region,chunk.x*8,chunk.y*8,8,2697992464,sampling.features,sampling.water)
		for p: Dictionary in data.placements:
			if p.get("layers",[]).size()!=2:continue
			var centre: Vector3=p.transform.origin
			var d:=centre.distance_to(_spot[2])
			if d<distance:closest=p;distance=d
	assert(not closest.is_empty())
	var columns: Array=[closest]+closest.layers
	var outward: Vector2=closest.outward
	var tangent:=Vector2(-outward.y,outward.x)
	var anchor:=Vector2(closest.transform.origin.x,closest.transform.origin.z)-outward*.5
	var control:=TerraceJumpController.new()
	_character.controller=control
	var centre:=Vector3(anchor.x,closest.base+5,anchor.y)
	_camera.global_position=centre+Vector3(outward.x*18,9,outward.y*18)+Vector3(tangent.x*14,0,tangent.y*14)
	_camera.look_at(centre)
	var rows:=[]
	for side: float in [-1,1]:
		for level in 3:
			var target: Dictionary=columns[level]
			var offset:=outward*(4.3 if level==0 else 2.7)
			var axis:=outward
			if level==1:offset+=tangent*3.0*side
			if level==2:offset=outward*.6+tangent*3.2*side;axis=tangent*side
			_character.global_position=Vector3(anchor.x+offset.x,target.base+.03,anchor.y+offset.y)
			_character.velocity=Vector3.ZERO
			control.direction=-axis
			control.jumping=false
			for tick in 40:
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
			var start:=_character.global_position
			var highest:=start.y
			var ceiling:=0
			var reached:=false
			for tick in 100:
				control.jumping=tick==0
				var current:=Vector2(_character.global_position.x,_character.global_position.z)-anchor
				if current.dot(axis)<(.6 if level==2 else (.7 if level==1 else 2.5)):control.direction=Vector2.ZERO
				await get_tree().physics_frame
				_character._physics_process(1.0/60)
				highest=maxf(highest,_character.global_position.y)
				for c in _character.get_slide_collision_count():
					if _character.get_slide_collision(c).get_normal().y<-.05:ceiling+=1
				if _character.is_on_floor() and _character.global_position.y>=target.top-.1:reached=true;break
			var row:={"id":target.id,"asset":target.asset,"side":side,"level":level,"start":str(start),"end":str(_character.global_position),"highest":highest,"reached":reached,"ceiling_contacts":ceiling}
			print("CLIFF_STACK_GAME ",JSON.stringify(row))
			rows.append(row)
			await _shot("stack_%d_%d"%[int(side),level])
	FileAccess.open(_output_dir.path_join("stack-jumps.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
