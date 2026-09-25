extends Node3D
const ROOT="res://docs/qa/2026-09-15-manual/05-water-drops/"
func _ready() -> void:
	get_window().size=Vector2i(1280,720)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("a3bec8")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.65
	add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=1.2
	add_child(sun)
	var camera:=Camera3D.new()
	camera.fov=75
	add_child(camera)
	var water:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd").make_water(2697992464)
	var plan:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd").make_heightfield(2697992464,water)
	var mesher:=TerrainChunkMesher.new()
	mesher.set_seed(2697992464)
	mesher.prepare_resources()
	var builder:=WaterSurfaceBuilder.new()
	for phase in ["before","after"]:
		var data:Dictionary=FileAccess.open(ROOT+"legacy-"+phase+".bin",FileAccess.READ).get_var()
		var region:=HeightfieldRegion.new(data.storeys,data.levels,data.carved,plan)
		var ctx:=WaterField.ctx(water,Vector2i(3,-10))
		ctx.region=region;ctx.fill=data.fill;ctx.fill_base=data.fill_base
		var field:=WaterFieldContext.new()
		field._ctx=ctx;field._region=region;field._coverage=Rect2(Vector2(576,-1920),Vector2.ONE*192)
		var terrain:=mesher.commit_chunk(mesher.compute_chunk(Vector2i(3,-10),region))
		add_child(terrain)
		var water_node:=builder.commit_chunk(builder.compute_chunk(water,Vector2i(3,-10),region,field))
		add_child(water_node)
		if "--opaque-water" in OS.get_cmdline_user_args():
			var diagnostic:=StandardMaterial3D.new()
			diagnostic.albedo_color=Color("35b7dd")
			diagnostic.cull_mode=BaseMaterial3D.CULL_DISABLED
			for sheet:MeshInstance3D in water_node.find_children("*","MeshInstance3D",true,false):sheet.material_override=diagnostic
		var mat:=WaterSurfaceBuilder.sheet_material()
		var shader:=Shader.new();shader.code=mat.shader.code.replace("TIME","0.0");mat.shader=shader
		var feet:=Vector3(678.8,12.6,-1744.2)
		var crosshair:=Vector3(678.6,12.9,-1744.5)
		var pivot:=feet+Vector3.UP
		var eye:=ReviewCam.solve_cam(feet,crosshair,26,24,1)
		var output:String=ROOT+("legacy-opaque-" if "--opaque-water" in OS.get_cmdline_user_args() else "legacy-render-")+phase
		DirAccess.make_dir_recursive_absolute(output)
		for angle:float in [0,90,180,270]:
			camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(pivot)
			await get_tree().process_frame
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output+"/legacy_"+str(int(angle))+".png")
		terrain.free();water_node.free()
	get_tree().quit()
