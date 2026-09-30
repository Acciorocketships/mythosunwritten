extends SceneTree
## Geometry-only culling control for the saved photo 11 envelope probe.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200,800)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.04,.05,.06)
	scene.add_child(env)
	var player := Vector3(296.7,53.5,772.2)
	var hit := Vector3(299.4,55.4,773.3)
	var pivot := player + Vector3.UP*CameraMouseView.PIVOT_HEIGHT
	var delta := hit-pivot
	var pitch := atan2(-delta.y,Vector2(delta.x,delta.z).length())
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 75
	camera.look_at_from_position(ReviewCam.solve_cam(player,hit,
		CameraMouseView.BOOM_LENGTH*cos(pitch),CameraMouseView.PIVOT_HEIGHT+CameraMouseView.BOOM_LENGTH*sin(pitch),
		CameraMouseView.PIVOT_HEIGHT),pivot)
	camera.current = true
	var dir := "res://docs/qa/2026-09-26-manual-cliffs"
	for variant: String in ["before","true-distance","heightfield"]:
		var data: Dictionary = FileAccess.open(dir+"/probe-%s.var"%variant,FileAccess.READ).get_var()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data.faces
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.35,.65,.22)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = mat
		scene.add_child(node)
		for two_sided: bool in [false,true]:
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
			for unused in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(dir+"/mesh-%s-%s.png"%[variant,"two" if two_sided else "one"])
		node.free()
	quit()
