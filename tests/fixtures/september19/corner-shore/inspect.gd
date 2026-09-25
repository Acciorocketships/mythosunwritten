extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/120-corner-shore"
const SOURCE="res://docs/qa/2026-09-19-manual/119-small-town/world.scn"
func _init()->void:run.call_deferred()
func run()->void:
	Engine.max_fps=30;root.size=Vector2i(1280,800)
	var stage:Node3D=load(SOURCE).instantiate();root.add_child(stage)
	for key:StringName in stage.get_meta("shader_globals",{}):
		if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
	var report:Dictionary={};var detached:Dictionary={}
	var names:Array=[]
	for node:MultiMeshInstance3D in stage.find_children("*","MultiMeshInstance3D",true,false):
		names.append([str(node.name),node.multimesh.mesh.resource_path,node.multimesh.instance_count])
	FileAccess.open(OUT.path_join("names.json"),FileAccess.WRITE).store_string(JSON.stringify(names,"  "))
	for site in [{"id":"N03","feet":Vector3(-441.4,20,494.7),"aim":Vector3(-444.2,20,492.5)},{"id":"N04","feet":Vector3(-519.5,20,326.4),"aim":Vector3(-499.7,8,306.5)}]:
		var feet:Vector3=site.feet;var aim:Vector3=site.aim
		var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
		var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
		var rows:Array=[];var forms:Array=[];var native:Dictionary={"wall":[],"outer_wall":[],"inner_wall":[]}
		for node:MultiMeshInstance3D in stage.find_children("*","MultiMeshInstance3D",true,false):
			var recipe:Dictionary=node.get_meta("relief_recipe",{})
			for j in node.multimesh.instance_count:
				var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(j)
				if Vector2(pose.origin.x-feet.x,pose.origin.z-feet.z).length()>42:continue
				if not recipe.is_empty():forms.append({"pose":pose,"recipe":recipe,"bounds":pose*node.multimesh.mesh.get_aabb()})
				else:
					var kind:=""
					var mesh_path:String=node.multimesh.mesh.resource_path
					if mesh_path.ends_with("kaykit_cliff_wall_piece_00.res"):kind="wall"
					elif mesh_path.ends_with("kaykit_cliff_outer_wall_piece_00.res"):kind="outer_wall"
					elif node.multimesh.mesh==stage.get_node("InnerWalls").multimesh.mesh:kind="inner_wall"
					if not kind.is_empty():
						rows.append({"name":kind,"pose":pose});native[kind].append(pose)
		for angle in [0,-10,10]:
			camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
			for i in 5:await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUT.path_join(site.id+"-before-%d.png"%angle))
		report[site.id]={"rows":rows,"formations":forms,"camera":camera.transform}
		detached[site.id]=native
	FileAccess.open(OUT.path_join("native.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open(OUT.path_join("native.bin"),FileAccess.WRITE).store_var(detached)
	quit()
