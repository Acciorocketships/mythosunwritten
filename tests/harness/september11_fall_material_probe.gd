extends SceneTree
## Actual GPU falsification: steep moving water changes; calm, stationary,
## transverse shore faces and the near-shore closure do not become cloudy.
func _init() -> void: call_deferred("_run")

func _run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	var stage:=Node3D.new()
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.12,.32,.10)
	stage.add_child(environment)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=23
	camera.position=Vector3(0,14,18)
	if OS.get_cmdline_user_args().has("--reverse"): camera.position.z=-18
	camera.look_at(Vector3.ZERO)
	camera.current=true
	var materials:Array[ShaderMaterial]=[]
	var centers:Array[Vector3]=[]
	for case_index:int in 5:
		var angle:=deg_to_rad(60.0) if case_index!=2 else 0.0
		var along:=Vector3(0,sin(angle),cos(angle))*1.5
		var across:=Vector3.RIGHT*1.5
		var center:=Vector3((case_index-2)*4,0,0)
		centers.append(center)
		var n:=Vector3(0,cos(angle),-sin(angle))
		var vertices:=PackedVector3Array([center-across-along,center+across-along,center+across+along,center-across+along])
		var normals:=PackedVector3Array([n,n,n,n])
		var frame:=PackedFloat32Array()
		var flow:=PackedFloat32Array()
		var colors:=PackedColorArray()
		for i:int in 4:
			# Even the flat control inherits a descending nearby trace profile;
			# its own face must independently keep the pool clear.
			frame.append_array(PackedFloat32Array([0,0,.7,1 if case_index==4 else 8]))
			var velocity:=Vector2(0,-4)
			if case_index==1: velocity=Vector2.ZERO
			if case_index==3: velocity=Vector2(4,0)
			flow.append_array(PackedFloat32Array([velocity.x,velocity.y,0,0]))
			colors.append(Color(0,.16,.55,.56))
		var arrays:Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_CUSTOM0]=frame
		arrays[Mesh.ARRAY_CUSTOM1]=flow
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		var node:=MeshInstance3D.new()
		node.mesh=mesh
		var material:=WaterSurfaceBuilder.sheet_material().duplicate() as ShaderMaterial
		material.set_shader_parameter("wave_height",0.0)
		material.set_shader_parameter("ripple_height",0.0)
		node.material_override=material
		materials.append(material)
		stage.add_child(node)
	var folder:="res://docs/qa/2026-09-11-manual/12-landforms/fall-material-probe"
	var legacy:=OS.get_cmdline_user_args().has("--legacy")
	if legacy: folder+="-red"
	if OS.get_cmdline_user_args().has("--reverse"): folder+="-reverse"
	DirAccess.make_dir_recursive_absolute(folder)
	var images:Array[Image]=[]
	for phase:String in ["before","after"]:
		var source:="res://tests/fixtures/september11/landforms/WaterBeforeFallScattering.txt" if phase=="before" or legacy else "res://terrain/water/water_unified.gdshader"
		var shader:=Shader.new()
		shader.code=FileAccess.get_file_as_string(source).replace("TIME","0.0")
		for material:ShaderMaterial in materials: material.shader=shader
		for frame_index:int in 15: await process_frame
		_draw.call_deferred()
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image()
		image.save_png(folder.path_join(phase+".png"))
		images.append(image)
	var results:Array[Dictionary]=[]
	var passed:=true
	for i:int in centers.size():
		var screen:=Vector2i(camera.unproject_position(centers[i]))
		var delta:=0.0
		for y:int in range(-10,11):
			for x:int in range(-10,11):
				var a:=images[0].get_pixel(screen.x+x,screen.y+y)
				var b:=images[1].get_pixel(screen.x+x,screen.y+y)
				delta+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
		delta/=441.0
		var valid:=delta>.03 if i==0 else delta<.002
		passed=passed and valid
		results.append({"case":i,"pixel":str(screen),"mean_abs_rgb":delta,"passed":valid})
	FileAccess.open(folder.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("FALL_MATERIAL passed=",passed," ",results)
	quit(0 if passed else 1)

func _draw() -> void: RenderingServer.force_draw(true)
