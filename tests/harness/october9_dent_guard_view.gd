extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var stage := Node3D.new(); root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.24, 0.28, 0.32)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.35
	stage.add_child(world)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -35, 0); stage.add_child(sun)
	var camera := Camera3D.new(); stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 58
	camera.look_at_from_position(Vector3(-284, 86, 1380), Vector3(-307, 48, 1344))
	var modes := ["baseline", "slope_guard_2", "slope_guard_4"]
	if "--tile-profiles" in OS.get_cmdline_user_args(): modes = ["baseline", "tile_4", "tile_7", "tile_10"]
	for mode in modes:
		var data: Dictionary = FileAccess.open("/tmp/oct9-dent-" + mode + ".var", FileAccess.READ).get_var()
		var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var indices := PackedInt32Array()
		var w := 121; var h := 97
		for z in h:
			for x in w:
				var p := Vector2(-336, 1332) + Vector2(x, z) * 0.5
				var at := Vector2i(((p - data.origin) / 0.5).round())
				var idx: int = at.y * data.w + at.x
				vertices.append(Vector3(p.x, data.surface[idx], p.y))
				normals.append(Vector3(data.surface[idx-1]-data.surface[idx+1], 1, data.surface[idx-data.w]-data.surface[idx+data.w]).normalized())
				if x < w - 1 and z < h - 1:
					var i := z * w + x
					indices.append_array(PackedInt32Array([i, i+1, i+w, i+1, i+w+1, i+w]))
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new(); instance.mesh = mesh
		var material := StandardMaterial3D.new(); material.albedo_color = Color(0.55, 0.67, 0.32); material.roughness = 1; material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material; stage.add_child(instance)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oct9-dent-" + mode + ".png")
		instance.free()
	quit()
