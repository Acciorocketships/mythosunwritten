extends Node3D

# Native-asset lighting study supplements the real-world replay.
func _ready() -> void:
	Engine.max_fps=30
	get_window().size=Vector2i(1280,720)
	var output:=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var world_environment:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("18202d")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("8093bd")
	environment.ambient_light_energy=0.18
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled=true
	environment.glow_intensity=0.85
	world_environment.environment=environment
	add_child(world_environment)
	var floor_mesh:=MeshInstance3D.new()
	var floor_plane:=PlaneMesh.new()
	floor_plane.size=Vector2(40,40)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("92928c")
	material.roughness=1.0
	floor_plane.material=material
	floor_mesh.mesh=floor_plane
	add_child(floor_mesh)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-30,0)
	sun.light_energy=0.12
	add_child(sun)
	var camera:=Camera3D.new()
	add_child(camera)
	camera.make_current()
	var catalogue:=EnvironmentCatalog.load_default()
	var cache:=EnvironmentRenderCache.new(catalogue)
	var rows:Array=[]
	for id:StringName in [&"sfv.light_pole.001",&"lpfv.fabric.prop.lantern.table.01",&"lpfv.fabric.prop.lantern.post.02"]:
		var parent:=Node3D.new()
		add_child(parent)
		var queue:=EnvironmentCommitQueue.new(cache,&"Visuals")
		var payload:=EnvironmentInstancePayload.new()
		payload.add(id,Transform3D.IDENTITY,Color.WHITE)
		queue.register_chunk(Vector2i.ZERO,1)
		queue.enqueue(Vector2i.ZERO,1,parent,payload)
		queue.drain(100)
		var bounds:=catalogue.descriptor(id).measured_aabb
		var target:=bounds.get_center()
		var scale:=maxf(bounds.size.y,1.0)
		for view in ["close","wide"]:
			camera.global_position=target+Vector3(1.0,0.6,1.3)*scale if view=="close" else Vector3(7,7,9)
			camera.look_at(target,Vector3.UP)
			await get_tree().create_timer(0.4).timeout
			RenderingServer.force_draw()
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(output+"/%s_%s.png"%[String(id).replace(".","_"),view])
			rows.append({"asset":String(id),"view":view,"camera":str(camera.global_transform),"lights":parent.find_children("*","OmniLight3D",true,false).size()})
		parent.free()
		await get_tree().process_frame
	FileAccess.open(output+"/gallery.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	get_tree().quit()
