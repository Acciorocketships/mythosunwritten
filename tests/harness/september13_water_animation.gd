extends SceneTree
func _init()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,800);Engine.max_fps=30
	var folder:="res://docs/qa/2026-09-13-manual/22-water/diagnostic-before/P39"
	var output:="res://docs/qa/2026-09-13-manual/22-water/P39-animation-before"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):folder=arg.trim_prefix("--source=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var scene:Node3D=(load(folder+"/geometry.scn") as PackedScene).instantiate();root.add_child(scene)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("91adbb");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.7;root.add_child(environment)
	environment.environment.ambient_light_color=Color.WHITE
	var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-45,-30,0)
	var camera:=Camera3D.new();root.add_child(camera);camera.fov=75;camera.current=true
	var feet:=Vector3(829.8,16,341.5);var cross:=Vector3(830.4,16,346.4)
	var target:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(target-cross).normalized()
	camera.position=ReviewCam.solve_cam(feet,cross,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT);camera.look_at(target)
	var original:=WaterSurfaceBuilder.sheet_material()
	var source:=FileAccess.get_file_as_string("res://terrain/water/water_unified.gdshader")
	var prefix:=source.substr(0,source.find("void fragment()"))
	for frame in 15:
		var time:=float(frame-1)
		var frame_prefix:=prefix
		if frame == 0: frame_prefix=frame_prefix.replace("water_dynamic_height(base_world.xz) * surface_scale", "0.0")
		if frame >= 13: frame_prefix=frame_prefix.replace("water_dynamic_height(base_world.xz) * surface_scale", ("-1.4" if frame == 13 else "1.4")+" * surface_scale")
		var shader:=Shader.new()
		shader.code=(frame_prefix+"void fragment() { ALBEDO=vec3(0.05,0.65,0.9); }").replace("TIME",str(maxf(time,0.0)))
		# Bind a completed shader to a fresh material. Mutating the shader on
		# the deserialized material left its old render binding in this replay.
		var material:=ShaderMaterial.new();material.shader=shader
		material.set_shader_parameter("noise_tex",original.get_shader_parameter("noise_tex"))
		for node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
			if node.is_in_group("tactical_preserve_surface"):node.material_override=material
		for tick in 8:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(output+"/phase_%02d.png"%frame)
	print("WATER_ANIMATION_DONE")
	quit()
