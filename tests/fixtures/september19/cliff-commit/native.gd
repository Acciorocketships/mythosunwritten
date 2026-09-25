extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/118-cliff-commit"
const SOURCE="res://docs/qa/2026-09-19-manual/117-loading-frontier/world.scn"
const OLD=preload("res://tests/fixtures/september19/cliff-commit/baseline_crags.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
func _init()->void:run.call_deferred()
func shot(name:String)->void:
	for i in 4:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT.path_join(name+".png"))
func run()->void:
	Engine.max_fps=30;root.size=Vector2i(1280,800)
	var stage:Node3D=load(SOURCE).instantiate();root.add_child(stage)
	for key:StringName in stage.get_meta("shader_globals",{}):
		if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:
			RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
	CRAGS.prepare();OLD.prepare();CORNER.prepare();CliffDressing._ensure_loaded()
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
	var feet:=Vector3(-566.9,32,127.4);var aim:=Vector3(-568.9,32,130.9)
	var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
	var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	camera.position=eye;camera.look_at(pivot)
	var nodes:Array=[]
	for node:Node in stage.find_children("*","MultiMeshInstance3D",true,false):
		if node.has_meta("relief_recipe"):nodes.append(node)
	nodes.sort_custom(func(a,b)->bool:return a.multimesh.get_instance_transform(0).origin.distance_squared_to(feet)<b.multimesh.get_instance_transform(0).origin.distance_squared_to(feet))
	nodes=nodes.slice(0,16)
	var rocks:Array[Dictionary]=[]
	for node:MultiMeshInstance3D in nodes:
		var pose:=node.multimesh.get_instance_transform(0)
		var rock:=REPLAY.rebuild(pose,node.get_meta("relief_faces"),node.get_meta("relief_recipe"),CRAGS,CORNER)
		assert(rock.faces==node.get_meta("relief_faces"),"Replay must retain exact production geometry")
		rocks.append(rock)
	var old_meshes:Array[ArrayMesh]=[];var prepared:Array=[];var meshes:Array[ArrayMesh]=[]
	var started:=Time.get_ticks_usec()
	for rock:Dictionary in rocks:old_meshes.append(OLD.mesh(rock))
	var baseline_usec:=Time.get_ticks_usec()-started
	for i in nodes.size():nodes[i].multimesh.mesh=old_meshes[i]
	await shot("before")
	var worker:=Thread.new()
	started=Time.get_ticks_usec()
	assert(worker.start(func()->Array:
		var result:Array=[]
		for rock:Dictionary in rocks:result.append(CRAGS.mesh_arrays(rock))
		return result)==OK)
	while worker.is_alive():await process_frame
	prepared=worker.wait_to_finish()
	var worker_usec:=Time.get_ticks_usec()-started
	for i in rocks.size():rocks[i]["render_arrays"]=prepared[i]
	started=Time.get_ticks_usec()
	for rock:Dictionary in rocks:meshes.append(CRAGS.mesh(rock))
	var commit_usec:=Time.get_ticks_usec()-started
	var vertices:=0;var surfaces:=0
	for i in nodes.size():
		assert(meshes[i].get_surface_count()==old_meshes[i].get_surface_count())
		for surface in meshes[i].get_surface_count():
			var arrays:=meshes[i].surface_get_arrays(surface)
			assert(var_to_bytes(arrays)==var_to_bytes(old_meshes[i].surface_get_arrays(surface)),"Prepared native mesh differs")
			vertices+=(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size();surfaces+=1
		nodes[i].multimesh.mesh=meshes[i]
	await shot("after")
	var report:={"formations":nodes.size(),"surfaces":surfaces,"vertices":vertices,"baseline_main_usec":baseline_usec,"worker_usec":worker_usec,"prepared_main_usec":commit_usec,"camera":camera.transform,"unchanged_collision":true}
	FileAccess.open(OUT.path_join("native.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CLIFF_COMMIT ",JSON.stringify(report));quit()
