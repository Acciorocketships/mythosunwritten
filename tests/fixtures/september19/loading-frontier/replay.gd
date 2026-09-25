extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/117-loading-frontier"
func _init()->void: run.call_deferred()
func shot(name:String)->void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT.path_join(name+".png"))
func run()->void:
	Engine.max_fps=30; root.size=Vector2i(1280,800)
	var stage:=load(OUT.path_join("world.scn")).instantiate() as Node3D
	root.add_child(stage)
	for key:StringName in stage.get_meta("shader_globals",{}):
		if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:
			RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
	var camera:=Camera3D.new(); root.add_child(camera); camera.current=true; camera.fov=75
	var feet:=Vector3(-566.9,32,127.4);var aim:=Vector3(-568.9,32,130.9)
	var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
	var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	var fog:=preload("res://scripts/terrain/diagnostics/LoadingFrontierFog.gd").new();root.add_child(fog)
	var env:WorldEnvironment=stage.find_children("*","WorldEnvironment",true,false)[0]
	var full:={}
	for x in range(-4,-1):
		for z in range(-1,2): full[Vector2i(x,z)]=true
	var partial:=full.duplicate();partial.erase(Vector2i(-4,0));partial.erase(Vector2i(-4,1));partial.erase(Vector2i(-3,1))
	var omitted:Array[GeometryInstance3D]=[]
	# Controlled reconstruction of incomplete ground: retain all cliff/features
	# and water so the fog must obscure hanging pieces, rather than deleting them.
	for node:Node in stage.get_children():
		if not node is MeshInstance3D:continue
		if not String(node.name).begins_with("Surface") and not String(node.name).begins_with("Aprons"):continue
		var center:Vector3=node.global_transform*node.get_aabb().get_center()
		if not partial.has(FieldTerrainStreamer.chunk_of(center)):omitted.append(node)
	var report:={"omitted_ground_meshes":omitted.size(),"partial":partial.keys(),"full":full.keys(),"poses":[]}
	for angle:int in [0,-8,8]:
		camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
		report.poses.append({"angle":angle,"transform":camera.transform})
		for node in omitted:node.visible=false
		fog.clear();await shot("partial-before-%d"%angle)
		fog.update_view(camera,partial,env.environment.fog_light_color);await shot("partial-fog-%d"%angle)
		for node in omitted:node.visible=true
		fog.update_view(camera,full,env.environment.fog_light_color);await shot("loaded-fog-%d"%angle)
		fog.clear();await shot("loaded-before-%d"%angle)
	FileAccess.open(OUT.path_join("replay.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
