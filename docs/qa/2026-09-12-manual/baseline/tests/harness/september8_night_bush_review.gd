extends SceneTree
var scene := Node3D.new()
var camera := Camera3D.new()
var output := ""
func _init()->void: call_deferred("run")
func bush(id: StringName, point: Vector3, tint: Color)->void:
	var visual := load(EnvironmentCatalog.load_default().descriptor(id).visual_path) as EnvironmentVisual
	for piece: EnvironmentVisualPiece in visual.pieces:
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.use_colors=true
		mm.mesh=piece.mesh
		mm.instance_count=1
		mm.set_instance_transform(0,Transform3D(Basis.IDENTITY,point)*piece.local_transform)
		mm.set_instance_color(0,tint)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh=mm
		instance.material_override=piece.material_override
		scene.add_child(instance)
func label_at(value: String, point: Vector3)->void:
	var label := Label3D.new()
	label.text=value
	label.font_size=40
	label.pixel_size=0.01
	label.position=point
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	scene.add_child(label)
func box(point: Vector3, size: Vector3)->void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=size
	instance.mesh=mesh
	instance.position=point
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(0.4,0.45,0.4)
	instance.material_override=material
	scene.add_child(instance)
func shot(name: String)->void:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run()->void:
	var args:=OS.get_cmdline_user_args()
	output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1718,1034)
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.15,0.18,0.22)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.7
	scene.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-30,0)
	scene.add_child(sun)
	scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=50
	camera.position=Vector3(20,22,38)
	camera.look_at(Vector3(20,0,0))
	var biomes:=BiomeRegistry.biome_ids()
	for i in biomes.size():
		var weights:Dictionary={biomes[i]:1.0}
		var tint:=BiomeRegistry.blended_environment_tint(weights,&"bush")
		bush(&"kaykit.bush.01",Vector3(i*6,0,0),tint)
		bush(&"kaykit.bush.02",Vector3(i*6,0,6),tint)
		label_at(String(biomes[i]),Vector3(i*6,5,0))
	await shot("palette")
	for child in scene.get_children():
		if child is MultiMeshInstance3D or child is Label3D: child.queue_free()
	await process_frame
	box(Vector3(-18,-1,12),Vector3(12,2,16))
	box(Vector3(-6,3,12),Vector3(12,10,16))
	var storeys:Dictionary={};var levels:Dictionary={}
	for z in range(-4,5):
		for x in range(-4,5):
			storeys[Vector2i(x,z)]=2 if x>=0 else 0
			levels[Vector2i(x,z)]=0
	var region:=HeightfieldRegion.new(storeys,levels)
	var water:=WaterFieldContext.new()
	water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region=region;water._coverage=Rect2(Vector2(-96,-96),Vector2(192,192));water._shore_limit=.5
	var program:=DressingCompiler.compile(load("res://terrain/dressing/index.tres"),EnvironmentCatalog.load_default())
	var set_data:Dictionary={}
	for row:Dictionary in program.sets:
		if row.id==&"ambient.bush":set_data=row
	var results:Array=[]
	for index in 2:
		var point:=Vector2(-10.9 if index==0 else -4,12)
		var choice:Dictionary=set_data.choices[0]
		var qualification:=DressingField._qualify(set_data,point,region,water,null,choice,Basis.IDENTITY)
		results.append({"position":str(point),"accepted":not qualification.is_empty(),"support":str(choice.support_points)})
		if not qualification.is_empty():bush(choice.asset_id,Vector3(point.x,qualification.y,point.y),BiomeRegistry.blended_environment_tint({&"meadow":1.0},&"bush"))
		label_at("Cliff edge" if index==0 else "Flat control",Vector3(point.x,13,point.y))
	camera.size=24
	camera.position=Vector3(-28,23,35)
	camera.look_at(Vector3(-10,6,12))
	await shot("cliff_support")
	FileAccess.open(output.path_join("qualification.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	# A one-storey slope uses the production continuous terrain evaluator.
	for child in scene.get_children():
		if child is MeshInstance3D or child is MultiMeshInstance3D or child is Label3D: child.queue_free()
	await process_frame
	for cell: Vector2i in storeys: storeys[cell]=1 if cell.x>=0 else 0
	region=HeightfieldRegion.new(storeys,levels)
	water._region=region;water._ctx.region=region
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in 64:
		for ix in 128:
			var x:float=-24.0+float(ix)*0.25
			var z:float=4.0+float(iz)*0.25
			var a:=Vector3(x,TerrainSurfaceField.surface_y(region,x,z),z)
			var b:=Vector3(x+0.25,TerrainSurfaceField.surface_y(region,x+0.25,z),z)
			var c:=Vector3(x,TerrainSurfaceField.surface_y(region,x,z+0.25),z+0.25)
			var d:=Vector3(x+0.25,TerrainSurfaceField.surface_y(region,x+0.25,z+0.25),z+0.25)
			for vertex:Vector3 in [a,b,c,b,d,c]: surface.add_vertex(vertex)
	surface.generate_normals()
	var slope:=MeshInstance3D.new()
	slope.mesh=surface.commit()
	var slope_material:=StandardMaterial3D.new()
	slope_material.albedo_color=Color(0.4,0.45,0.4)
	slope_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	slope.material_override=slope_material
	scene.add_child(slope)
	var slope_results:Array=[]
	for point:Vector2 in [Vector2(-6,12),Vector2(5,12)]:
		var choice:Dictionary=set_data.choices[0]
		var qualification:=DressingField._qualify(set_data,point,region,water,null,choice,Basis.IDENTITY)
		slope_results.append({"position":str(point),"accepted":not qualification.is_empty()})
		if not qualification.is_empty():bush(choice.asset_id,Vector3(point.x,qualification.y,point.y),BiomeRegistry.blended_environment_tint({&"meadow":1.0},&"bush"))
		label_at("Slope" if point.x<0 else "Flat control",Vector3(point.x,8,point.y))
	camera.position=Vector3(-22,13,35)
	camera.look_at(Vector3(-5,2,12))
	await shot("slope_support")
	FileAccess.open(output.path_join("slope-qualification.json"),FileAccess.WRITE).store_string(JSON.stringify(slope_results,"\t"))
	quit()
