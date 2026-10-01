extends "res://tests/harness/september13_visibility_qa.gd"

var _comparison_meshes: Array = [[],[]]
var _comparison_grass: Array = []
var _comparison_regions: Dictionary = {}

func _spots() -> Array:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/photo-poses.json"))
	var result := []
	for entry: Dictionary in records:
		result.append([entry.id, entry.source, Vector3(entry.player[0],entry.player[1],entry.player[2]),
			Vector3(entry.crosshair[0],entry.crosshair[1],entry.crosshair[2])])
	return result

func _run() -> void:
	await get_tree().create_timer(5).timeout
	var world := _character.get_parent().get_parent()
	if _frozen:
		_capture_view = SubViewport.new()
		_capture_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_capture_view)
		world.reparent(_capture_view)
		_show_capture_view()
		_camera.make_current()
	_capture_view.size = Vector2i(1920,1080)
	_camera = _capture_view.get_camera_3d()
	_camera.set_physics_process(false)
	_camera._visibility.clear()
	_character.set_physics_process(false)
	_character.global_position = _spot[2]
	if not _frozen:
		assert(await _wait_for_site())
		preload("res://tests/harness/september11_snapshot.gd").save(world,_character,_output_dir.path_join("world.scn"))
	_camera.set_physics_process(false)
	_camera.set_process_input(false)
	_camera.set_process_unhandled_input(false)
	_camera._visibility.clear()
	for body: Node in world.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.visible = false
	if "--compare-grass" in OS.get_cmdline_user_args():
		await _prepare_grass_comparison(world)
	await _capture_views(world)
	if "--hold" in OS.get_cmdline_user_args(): await _hold_review(world)
	if _frozen: _streamer.free()
	get_tree().quit()

func _capture_views(world:Node3D) -> void:
	await _prepare_review_grass()
	_character.anim_tree.active = false
	_freeze_material_clocks(world)
	_character.global_position = _spot[2]
	_character.step_visual_offset_y = 0
	_character._update_step_visual_smoothing(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var feet: Vector3 = _spot[2]
	var crosshair: Vector3 = _spot[3]
	var space := _camera.get_world_3d().direct_space_state
	var obstruction := CameraObstructionSolver.new()
	var excluded: Array[RID] = [_character.get_rid()]
	var pivot := obstruction.resolve_ceiling(space,feet,1.0,CameraMouseView.PIVOT_HEIGHT,excluded)
	var backward := (pivot-crosshair).normalized()
	var eye := ReviewCam.solve_cam(feet,crosshair,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,
		pivot.y-feet.y+backward.y*CameraMouseView.BOOM_LENGTH,pivot.y-feet.y)
	var poses := []
	var recorded: Array = []
	if "--native-topology" in OS.get_cmdline_user_args():
		var path := "res://docs/qa/2026-09-15-manual/01-grass/candidate-07/%s/poses.json" % _spot[0]
		if FileAccess.file_exists(path): recorded = JSON.parse_string(FileAccess.get_file_as_string(path))
	var review_args:=OS.get_cmdline_user_args()
	if "--camera-poses-root" in review_args:
		var camera_root:String=review_args[review_args.find("--camera-poses-root")+1]
		var camera_path:=camera_root.path_join(_spot[0]).path_join("poses.json")
		assert(FileAccess.file_exists(camera_path),"Matched control needs actual saved camera poses")
		recorded=JSON.parse_string(FileAccess.get_file_as_string(camera_path))
	var wide := "--wide" in OS.get_cmdline_user_args()
	var tactical := "--tactical" in OS.get_cmdline_user_args()
	if wide or tactical:
		eye = ReviewCam.solve_cam(feet,crosshair,26,16,1)
		pivot = feet+Vector3.UP
	for angle: float in ([0,-30,30,90,180,-90] if wide else [0,-8,8]):
		_camera.fov = 50 if wide or tactical else 75
		var desired := pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle))
		_camera.global_position = desired if wide or tactical else obstruction.resolve_boom(space,pivot,desired,excluded)
		_camera.look_at(pivot)
		for record: Dictionary in recorded:
			if float(record.angle) != angle: continue
			var numbers := RegEx.new()
			numbers.compile("-?[0-9]+(?:\\.[0-9]+)?")
			var values: Array[float] = []
			for match in numbers.search_all(record.camera): values.append(float(match.get_string()))
			assert(values.size()==12)
			_camera.global_transform=Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
			_camera.fov=record.fov
		var pose := {"angle":angle,"camera":str(_camera.global_transform),"fov":_camera.fov,"feet":str(feet),"crosshair":str(crosshair)}
		pose["camera_source"] = ("saved reference reconstruction" if "--camera-poses-root" in review_args else "saved candidate-07 reconstruction") if not recorded.is_empty() else "ReviewCam reconstruction"
		# A saved camera is authoritative; a freshly resolved obstruction pivot
		# did not produce it and must not be reported as though it did.
		if recorded.is_empty(): pose["pivot"] = str(pivot)
		poses.append(pose)
		var output := _output_dir
		if "--compare-grass" in OS.get_cmdline_user_args():
			for phase in 2:
				_character.global_position=feet
				var chunk := FieldTerrainStreamer.chunk_of(feet)
				if phase==1 and _comparison_regions.has(chunk):
					_character.global_position.y=maxf(feet.y,TerrainTileField.surface_y(_comparison_regions[chunk],feet.x,feet.z))
				pose["before_feet" if phase==0 else "after_feet"] = str(_character.global_position)
				for index in _comparison_grass.size(): _comparison_grass[index].visible=index==phase
				for index in 2:
					for node:Node3D in _comparison_meshes[index]: node.visible=index==phase
				_output_dir=output.path_join("before" if phase==0 else "after")
				DirAccess.make_dir_recursive_absolute(_output_dir)
				await _shot("%s_%d"%[_spot[0],int(angle)])
			_output_dir=output
		else:
			await _shot("%s_%d"%[_spot[0],int(angle)])
	FileAccess.open(_output_dir.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))


func _prepare_grass_comparison(world:Node3D) -> void:
	assert(not _frozen)
	await _prepare_review_grass()
	# The frozen September 15 "before" mesher was retired with the 24 m cell-keyed
	# kernel (September 30 dual-grid tiles); both sides now use the live mesher.
	var original = TerrainChunkMesher.new()
	original.set_seed(WORLD_SEED)
	original.prepare_resources()
	var current:=TerrainChunkMesher.new()
	current.set_seed(WORLD_SEED)
	current.prepare_resources()
	var keys:=_streamer._built.keys()
	# The normal generator has finished and the world is paused. Only this
	# review worker accesses its prepared field/context cache during comparison.
	assert(_streamer._active_job.is_empty() and _streamer._queued.is_empty())
	var worker:=Thread.new()
	worker.start(func() -> Array:
		var result:=[]
		for key:Vector2i in keys:
			var context:=_streamer._features.context_for(key)
			var region:=context.graded_region(_streamer._fields.region(key))
			var baseline_region:=region
			if "--native-topology" in OS.get_cmdline_user_args():
				var natural:=_streamer._fields.region(key)
				baseline_region=HeightfieldRegion.new(natural._storeys,natural._levels,natural._carved,natural.plan)
				baseline_region.terrain_grades.assign(context.terrain_grades)
			var water:=_streamer._fields.water(key)
			result.append([key,original.compute_chunk(key,baseline_region,water,context),current.compute_chunk(key,region,water,context),region])
		return result)
	while worker.is_alive(): await get_tree().process_frame
	var result:Array=worker.wait_to_finish()
	var roles:=["Surface","Aprons","Cliffs","GradedCliffs"]
	if "--native-topology" in OS.get_cmdline_user_args(): roles.append_array(["CliffFaces","CliffTerraces"])
	for entry:Array in result:
		_comparison_regions[entry[0]]=entry[3]
		var old:Node3D=_streamer._built[entry[0]]
		for role:String in roles:
			var node:=old.get_node_or_null(role)
			if node!=null: node.visible=false
		for phase in 2:
			var built:Node3D=original.commit_chunk(entry[1]) if phase==0 else current.commit_chunk(entry[2])
			var group:=Node3D.new()
			world.add_child(group)
			for node:Node in built.get_children():
				if str(node.name) in roles:
					built.remove_child(node)
					group.add_child(node)
			group.visible=false
			_comparison_meshes[phase].append(group)
			built.free()
	if "--native-topology" in OS.get_cmdline_user_args():
		var old_grass:=Node3D.new()
		world.add_child(old_grass)
		var samples: Dictionary = {}
		for tile: Vector2i in _streamer._grass_streamer._built:
			var key := GrassField.parent_chunk(tile)
			if _streamer._built.has(key): samples[tile]=_streamer._built[key].get_meta("grass_sampling")
		var grass_worker:=Thread.new()
		grass_worker.start(func()->Array:
			var payloads:=[]
			for tile:Vector2i in samples:
				var key:=GrassField.parent_chunk(tile)
				var sampling:GrassSamplingContext=samples[tile]
				var context:=_streamer._features.context_for(key)
				var source:=_streamer._fields.region(key)
				var old_region:=HeightfieldRegion.new(source._storeys,source._levels,source._carved)
				old_region.terrain_grades.assign(context.terrain_grades)
				payloads.append(GrassField.compute(_streamer._grass_program,WORLD_SEED,tile,old_region,
					sampling.water,sampling.features,sampling.supports))
			return payloads)
		while grass_worker.is_alive(): await get_tree().process_frame
		for payload:GrassPayload in grass_worker.wait_to_finish():
			var node:=_streamer._grass_streamer._new_tile_node(payload.tile)
			for id:StringName in payload.asset_ids():
				_streamer._grass_streamer._add_batch(node,id,payload.batches[id])
			old_grass.add_child(node)
		_comparison_grass=[old_grass,_streamer._grass_root]
	print("GRASS_COMPARISON_READY chunks=",result.size())

func _hold_review(world:Node3D) -> void:
	var command_path:=_output_dir.path_join("review-command.json")
	print("GRASS_REVIEW_READY ",command_path)
	while true:
		await get_tree().create_timer(.25).timeout
		if not FileAccess.file_exists(command_path): continue
		var command:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(command_path))
		DirAccess.remove_absolute(command_path)
		if command.get("action","")=="quit": return
		if command.has("spot"):
			for record:Array in _spots():
				if record[0]==command.spot: _spot=record
		if command.has("output"):
			_output_dir=command.output
			DirAccess.make_dir_recursive_absolute(_output_dir)
		if command.get("action","")=="reload":
			for phase:Array in _comparison_meshes:
				for node:Node3D in phase: node.free()
			_comparison_meshes=[[],[]]
			if not _comparison_grass.is_empty(): _comparison_grass[0].free()
			_comparison_grass=[]
			_comparison_regions.clear()
			for path:String in ["res://scripts/terrain/field/CliffDressing.gd","res://scripts/terrain/field/TerrainChunkMesher.gd"]:
				var script:=load(path) as GDScript
				script.source_code=FileAccess.get_file_as_string(path)
				assert(script.reload(true)==OK)
			await _prepare_grass_comparison(world)
		await _capture_views(world)
		print("GRASS_REVIEW_READY ",command_path)

func _prepare_review_grass() -> void:
	if _streamer._grass_work==null: return
	var origin:=Vector2(_spot[2].x,_spot[2].z)
	for node:Node3D in _streamer._grass_streamer.begin_frame(origin):
		if node!=null: node.queue_free()
	_streamer._grass_work.update_origin(origin)
	_streamer._queue_grass_jobs(origin)
	var deadline:=Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		for result:Dictionary in _streamer._grass_work.drain_results():
			_streamer._grass_streamer.accept_result(result.tile,int(result.generation),result.grass,int(result.compute_usec))
		for item:Dictionary in _streamer._grass_streamer.drain_commits():
			_streamer._grass_root.add_child(item.node)
		var stats:Dictionary=_streamer._grass_work.stats()
		if stats.queued==0 and stats.active_tile=="" and stats.completed_waiting==0 and _streamer._grass_streamer.pending_count()==0:
			print("GRASS_CAPTURE_READY ",_spot[0]," ",_streamer._grass_streamer.stats())
			return
		await get_tree().process_frame
	assert(false,"Review grass did not complete")
