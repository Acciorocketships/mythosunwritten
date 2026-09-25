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
	var corners=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
	var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd")
	rocks.prepare();CliffDressing._ensure_loaded()
	var native:Dictionary=FileAccess.open(OUT.path_join("native.bin"),FileAccess.READ).get_var()
	var rows:Array=native.N03.outer_wall.filter(func(p:Transform3D)->bool:return p.origin==Vector3(-445.5,20,490.5))
	var forms:=corners.formations(rows,2697992464)
	assert(forms.size()==1)
	var published:Dictionary=FileAccess.open(OUT.path_join("production-corner.bin"),FileAccess.READ).get_var()
	assert(published.faces==forms[0].faces,"The rendered study must use the exact production-owned solid")
	forms=[published]
	var added:Node3D=rocks.build({"placements":forms},2697992464);root.add_child(added)
	await physics_frame;await physics_frame
	var feet_samples:Dictionary={};var floating:=0
	for form:Dictionary in forms:
		for p:Vector3 in form.faces:
			var world:Vector3=form.transform*p
			if absf(world.y-form.base)>.001:continue
			feet_samples[world]=true
	for point:Vector3 in feet_samples:
		var q:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*150,point-Vector3.UP*150,1)
		var hit:=root.world_3d.direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.position.y<point.y+.05:floating+=1
	assert(floating==0,"Added corner feet must stay buried in actual native ground")
	var body:=StaticBody3D.new();body.collision_layer=8;root.add_child(body)
	var shape:=ConcavePolygonShape3D.new();var world_faces:=PackedVector3Array()
	for p:Vector3 in forms[0].faces:world_faces.append(forms[0].transform*p)
	shape.set_faces(world_faces)
	var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
	await physics_frame;await physics_frame
	var contacts:=0
	for degrees:float in [25,45,65]:
		var direction:=Vector3(sin(deg_to_rad(degrees)),0,cos(deg_to_rad(degrees)))
		for y:float in [.5,1.2,2.0,2.8,3.5]:
			var center:Vector3=forms[0].transform*Vector3(-1.5,y,-1.5)
			var origin:=center+direction*20;var nearest:=INF
			for i in range(0,world_faces.size(),3):
				var hit=Geometry3D.ray_intersects_triangle(origin,-direction,world_faces[i],world_faces[i+1],world_faces[i+2])
				if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
			var q:=PhysicsRayQueryParameters3D.create(origin,center-direction*5,8)
			var hit:=root.world_3d.direct_space_state.intersect_ray(q)
			assert(is_finite(nearest) and not hit.is_empty())
			assert(absf(origin.distance_to(hit.position)-nearest)<.002,"Native collision and displayed rock must coincide")
			contacts+=1
	var feet:=Vector3(-441.4,20,494.7);var aim:=Vector3(-444.2,20,492.5)
	var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
	var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
	for angle in [0,-10,10,-40,40]:
		camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
		for after:bool in [false,true]:
			added.visible=after
			for i in 5:await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUT.path_join("corner-%s-%d.png"%["after" if after else "before",angle]))
	FileAccess.open(OUT.path_join("corner-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"native_storeys":rows.size(),"added_formations":forms.size(),"collision_contacts":contacts,"production_faces_identical":true,"root_samples":feet_samples.size(),"floating_roots":floating,"pose":forms[0].transform,"bounds":forms[0].bounds},"  "))
	quit()
