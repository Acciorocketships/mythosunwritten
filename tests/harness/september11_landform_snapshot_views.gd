extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1920,1080)
	var args:=OS.get_cmdline_user_args()
	var site:=args[args.find("--site")+1]
	var base:="res://docs/qa/2026-09-11-manual/12-landforms/"
	var snapshot:=base+("arch-arrival-fixed" if site=="arch" else "delta-live")+"/village.scn"
	if args.has("--snapshot"): snapshot=args[args.find("--snapshot")+1]
	var world:Node3D=(load(snapshot) as PackedScene).instantiate()
	for key:StringName in world.get_meta("shader_globals"):
		RenderingServer.global_shader_parameter_set(key,world.get_meta("shader_globals")[key])
	root.add_child(world)
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	camera.fov=50
	var target:=Vector3(-720,18,48) if site=="arch" else Vector3(-1417,6,1605)
	var heights:Array=[14,45] if site=="arch" else [80,170]
	var distance:=65.0 if site=="arch" else 200.0
	if site=="town":
		target=Vector3(1224,24,528)
		heights=[30,65]
		distance=95.0
	if site=="lake":
		target=Vector3(-1146.394,6,1874.850)
		heights=[60,130]
		distance=180.0
	if site=="island":
		target=Vector3(763.818,4,-208.6394)
		heights=[30,70]
		distance=100.0
	if site=="gorge":
		target=Vector3(-1316.635,20,-354.345)
		heights=[35,80]
		distance=100.0
	if args.has("--ground-target"):
		for body:Node in world.find_children("*","StaticBody3D",true,false):
			body.process_mode=Node.PROCESS_MODE_ALWAYS
		await physics_frame
		await physics_frame
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(target.x,256,target.z),Vector3(target.x,-20,target.z),1))
		assert(not hit.is_empty(),"The replay target must meet actual loaded terrain")
		target.y=hit.position.y+4.0
		heights=[12,40]
		distance=65.0
		print("GROUND_TARGET ",target)
	var folder:=base+site+"-world-overviews"
	if args.has("--output"): folder=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(folder)
	var phases:Array[String]=["context"]
	var water_materials:Array[ShaderMaterial]=[]
	var shaders:Dictionary={}
	if args.has("--shader-pairs"):
		phases=["before","after"]
		for phase:String in phases:
			var shader:=Shader.new()
			var source_path:="res://tests/fixtures/september11/landforms/WaterBeforeFallScattering.txt" if phase=="before" else "res://terrain/water/water_unified.gdshader"
			shader.code=FileAccess.get_file_as_string(source_path).replace("TIME","0.0")
			shaders[phase]=shader
		for mesh_node:Node in world.find_children("*","MeshInstance3D",true,false):
			var mesh:=mesh_node as MeshInstance3D
			var material:=mesh.material_override as ShaderMaterial
			if material!=null and material.shader.code.contains("water_dynamic_height"):
				var private_material:=material.duplicate() as ShaderMaterial
				mesh.material_override=private_material
				water_materials.append(private_material)
		assert(not water_materials.is_empty(),"A material comparison needs actual water meshes")
		print("WATER_MATERIALS ",water_materials.size())
	var poses:Array[Dictionary]=[]
	for height:float in heights:
		for angle:float in [0,90,180,270]:
			camera.position=target+Vector3(0,height,distance).rotated(Vector3.UP,deg_to_rad(angle))
			if args.has("--ground-target"):
				var camera_hit:=world.get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(Vector3(camera.position.x,256,camera.position.z),Vector3(camera.position.x,-20,camera.position.z),1))
				if not camera_hit.is_empty(): camera.position.y=maxf(camera.position.y,camera_hit.position.y+6.0)
			camera.look_at(target)
			var id:="%d_%d"%[height,angle]
			poses.append({"id":id,"camera":str(camera.transform)})
			for phase:String in phases:
				var output:=folder if phase=="context" else folder.path_join(phase)
				DirAccess.make_dir_recursive_absolute(output)
				if phase!="context":
					for material:ShaderMaterial in water_materials: material.shader=shaders[phase]
				for frame in 10: await process_frame
				_draw.call_deferred()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join(id+".png"))
	FileAccess.open(folder.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify(poses,"  "))
	quit()

func _draw() -> void: RenderingServer.force_draw(true)
