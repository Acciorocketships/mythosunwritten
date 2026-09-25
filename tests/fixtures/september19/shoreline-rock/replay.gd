extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/121-shoreline-rock"
const SOURCE="res://docs/qa/2026-09-19-manual/119-small-town/world.scn"
func _init()->void:run.call_deferred()
func run()->void:
	Engine.max_fps=30;root.size=Vector2i(1280,800)
	var stage:Node3D=load(SOURCE).instantiate();root.add_child(stage)
	for key:StringName in stage.get_meta("shader_globals",{}):
		if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
	var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
	rocks.prepare()
	var forms:Array=FileAccess.open(OUT.path_join("banks.bin"),FileAccess.READ).get_var()
	var added:=rocks.build({"placements":forms},2697992464);root.add_child(added)
	await physics_frame;await physics_frame
	var samples:=0;var unbacked:=0;var blocked:=0;var max_depth:=0.0;var feet_floating:=0;var feet_count:=0;var errors:Array=[]
	var space:=root.world_3d.direct_space_state
	for form:Dictionary in forms:
		var unique:Dictionary={}
		var pose:Transform3D=form.transform
		var level:float=form.replay_recipe.shore_level
		for local:Vector3 in form.faces:
			if unique.has(local):continue
			unique[local]=true
			var p:Vector3=pose*local
			if absf(p.y-form.base)<.001:
				feet_count+=1
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*200,p-Vector3.UP*200,1))
				if hit.is_empty() or hit.position.y<p.y-.02:feet_floating+=1
			if p.y>level+.1 or p.y<form.base+.1:continue
			var upper:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*200,p-Vector3.UP*200,1))
			if not upper.is_empty() and upper.position.y>=p.y-.02:continue
			var direction:=Vector3.BACK
			if form.replay_recipe.kind=="corner":
				if local.x>=-1.5 and local.z>=-1.5:direction=Vector3(local.x+1.5,0,local.z+1.5).normalized()
				elif local.z<=-1.5:direction=Vector3.RIGHT
			elif form.replay_recipe.kind=="inner_corner":direction=Vector3.RIGHT if local.z>local.x else Vector3.BACK
			direction=pose.basis*direction
			var wall:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+direction*8,p-direction*8,1))
			samples+=1
			if wall.is_empty():unbacked+=1
			else:max_depth=maxf(max_depth,(p-wall.position).dot(direction))
			var clear:=p+direction*3
			var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(clear+Vector3.UP*200,clear-Vector3.UP*200,1))
			if floor_hit.is_empty() or floor_hit.position.y>level-.75:
				blocked+=1
				if errors.size()<20:errors.append({"point":p,"clear":clear,"hit":floor_hit.get("position",null)})
	var report:={"wet_attachment_samples":samples,"missing_backing":unbacked,"maximum_projection":max_depth,"channel_obstructions":blocked,"feet_samples":feet_count,"floating_feet":feet_floating,"errors":errors}
	FileAccess.open(OUT.path_join("native-contact.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SHORE_NATIVE ",report)
	var feet:=Vector3(-519.5,20,326.4);var aim:=Vector3(-499.7,8,306.5)
	var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
	var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	for angle in [0,-10,10,-35,35]:
		camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
		for after:bool in [false,true]:
			added.visible=after
			for i in 5:await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUT.path_join("bank-%s-%d.png"%["after" if after else "before",angle]))
	for node:MultiMeshInstance3D in added.get_children():
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color.MAGENTA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		node.material_override=mat
	camera.position=eye;camera.look_at(pivot)
	for i in 5:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT.path_join("bank-highlight.png"))
	print("SHORE_RENDER children=",added.get_child_count())
	quit()
