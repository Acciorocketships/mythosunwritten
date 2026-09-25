extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(600,600)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("738080");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;stage.add_child(env)
	var sun:=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-45,-30,0)
	var cam:=Camera3D.new();stage.add_child(cam);cam.current=true;cam.position=Vector3(0,1.5,7);cam.look_at(Vector3(0,1.5,0));cam.fov=45
	var dir:="res://docs/qa/2026-09-13-manual/39-door-panels/stock-scan";DirAccess.make_dir_recursive_absolute(dir)
	var source_node:Node=load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Door/SFV_Door_Wall_Wooden_001_1.fbx").instantiate()
	var source:=EnvironmentBakeGeometry.merge_pieces(source_node,Transform3D.IDENTITY);source_node.free()
	for family:String in ["M","S"]:
		for index in range(1,16 if family=="M" else 8):
			var id:="SFV_Wall_Wooden_%s_%03d"%[family,index]
			var node:Node=load("res://assets/FantasyVillageFBX/FBX/Walls/Wooden/Walls/"+id+".fbx").instantiate()
			var stock:=EnvironmentBakeGeometry.merge_pieces(node,Transform3D.IDENTITY);node.free()
			var housing:=EnvironmentBakeGeometry.finish_facade_sides(source,stock,stock.get_aabb().size.z)
			var faces:=EnvironmentBakeGeometry.triangle_faces(housing)
			var missed:=0
			for hand:float in [-1,1]:
				for level in 15:
					var y:=lerpf(.1,2.9,float(level)/14);var blocked:=false
					for n in range(0,faces.size(),3):
						if Geometry3D.segment_intersects_triangle(Vector3(hand*1.49,y,2),Vector3(hand*1.49,y,-2),faces[n],faces[n+1],faces[n+2])!=null:blocked=true;break
					if not blocked:missed+=1
			print(id," depth=",stock.get_aabb().size.z," edge_misses=",missed)
			var inst:=MeshInstance3D.new();inst.mesh=stock;stage.add_child(inst)
			for tick in 3:await process_frame
			RenderingServer.force_draw(false);root.get_texture().get_image().save_png(dir.path_join(id+".png"));inst.free()
	quit()
