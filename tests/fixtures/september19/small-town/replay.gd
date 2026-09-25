extends SceneTree
const OUT := "res://docs/qa/2026-09-19-manual/119-small-town"
func _init()->void:run.call_deferred()
func shot(name:String)->void:
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT.path_join(name+".png"))
func run()->void:
	Engine.max_fps=30;root.size=Vector2i(1280,800)
	var stage:Node3D=load(OUT.path_join("world.scn")).instantiate();root.add_child(stage)
	for key:StringName in stage.get_meta("shader_globals",{}):
		if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:
			RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
	var feet:=Vector3(-231.7,18.1,422.5);var aim:=Vector3(-233.5,18.1,424.2)
	var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
	var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	var changes:Array=[];var changed_vertices:=0
	for node:Node in stage.find_children("*","MeshInstance3D",true,false):
		if not str(node.name).begins_with("Surface") and not str(node.name).begins_with("Aprons"):continue
		var original:Mesh=node.mesh;var replacement:=ArrayMesh.new();var count:=0
		for surface in original.get_surface_count():
			var a:=original.surface_get_arrays(surface)
			var u:PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var colours:PackedColorArray=a[Mesh.ARRAY_COLOR].duplicate()
			for j in u.size():
				if u[j].distance_to(SlopeAtlas.path_uv())<.001:
					colours[j]=SlopeAtlas.path_tint();count+=1
				elif u[j].distance_to(SlopeAtlas.path_spot_uv())<.001:
					colours[j]=SlopeAtlas.path_tint(true);count+=1
			a[Mesh.ARRAY_COLOR]=colours
			replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
			replacement.surface_set_material(surface,original.surface_get_material(surface))
			for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:
				assert(var_to_bytes(a[channel])==var_to_bytes(original.surface_get_arrays(surface)[channel]),"Only input colours may change")
		if count>0:changes.append([node,original,replacement]);changed_vertices+=count
	for angle:int in [0,-12,12]:
		camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
		for change in changes:change[0].mesh=change[1]
		await shot("path-before-%d"%angle)
		for change in changes:change[0].mesh=change[2]
		await shot("path-after-%d"%angle)
	FileAccess.open(OUT.path_join("path-replay.json"),FileAccess.WRITE).store_string(JSON.stringify({"meshes":changes.size(),"path_vertices":changed_vertices,"geometry_unchanged":true,"collision_unchanged":true},"  "))
	quit()
