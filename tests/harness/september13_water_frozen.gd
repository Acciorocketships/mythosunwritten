extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	Engine.max_fps=30;root.size=Vector2i(1280,800)
	var folder:="res://docs/qa/2026-09-13-manual/22-water/after"
	var output:="res://docs/qa/2026-09-13-manual/22-water/rebound"
	var selected:="P01,P02,P13,P19,P25,P48".split(",")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):folder=arg.trim_prefix("--source=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--spots="):selected=arg.trim_prefix("--spots=").split(",")
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("91adbb")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;root.add_child(env)
	var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true
	for id:String in selected:
		var stage:Node3D=(load(folder+"/"+id+"/geometry.scn") as PackedScene).instantiate();root.add_child(stage)
		var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/"+id+"/audit.json"))
		var spot:Dictionary=audit.spot
		var feet:=Vector3(spot.player[0],spot.player[1],spot.player[2]);var cross:=Vector3(spot.crosshair[0],spot.crosshair[1],spot.crosshair[2])
		var tactical:=Vector2(feet.x-cross.x,feet.z-cross.z).length()<1
		var target:=feet+Vector3.UP;var eye:=ReviewCam.solve_cam(feet,cross,26,16,1)
		if not tactical:
			target=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT
			var backward:=(target-cross).normalized()
			eye=ReviewCam.solve_cam(feet,cross,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
		camera.fov=50 if tactical else 75
		var material:=ShaderMaterial.new();var shader:=Shader.new()
		shader.code=FileAccess.get_file_as_string("res://terrain/water/water_unified.gdshader").replace("TIME","0.0");material.shader=shader
		material.set_shader_parameter("noise_tex",WaterSurfaceBuilder.sheet_material().get_shader_parameter("noise_tex"))
		for node:MeshInstance3D in stage.find_children("*","MeshInstance3D",true,false):
			if node.is_in_group("tactical_preserve_surface"):
				node.material_override=material
				if "--opaque-water" in OS.get_cmdline_user_args():
					var opaque:=StandardMaterial3D.new();opaque.albedo_color=Color(.05,.65,.9);opaque.cull_mode=BaseMaterial3D.CULL_DISABLED;opaque.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=opaque
		DirAccess.make_dir_recursive_absolute(output+"/"+id)
		for angle:int in [0,-8,8]:
			camera.position=target+(eye-target).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(target)
			for tick in 10:await process_frame
			RenderingServer.force_draw(false);root.get_texture().get_image().save_png(output+"/"+id+"/view_%d.png"%angle)
		stage.free();await process_frame
		print("WATER_REBOUND ",id)
	quit()
