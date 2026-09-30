extends SceneTree
## Controlled production Meadow render: identical mesh/pose/light, changing
## only the normal used to project and grade the top's shared green material.
const ROCKS = preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	STYLE.apply("sheet_bedrock")
	root.size = Vector2i(1200,800)
	var scene := Node3D.new()
	root.add_child(scene)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	scene.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.2,.24,.27)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = .6
	scene.add_child(world)
	var entries := {}
	for i in 3:
		var point := Vector3(i*6,0,0)
		entries["angry_%02d" % (i+1)] = [{"transform":Transform3D(Basis.IDENTITY,point),
			"normal":Vector3(.98,.2,0).normalized(),"point":point,"ground":0.0}]
	scene.add_child(ROCKS.build(entries,2697992464))
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(12,13,17),Vector3(6,0,0))
	camera.current = true
	var dir := "res://docs/qa/2026-09-26-manual-cliffs/material"
	DirAccess.make_dir_recursive_absolute(dir)
	var original := Shader.new()
	original.code = FileAccess.get_file_as_string("res://terrain/materials/meadow_rock.gdshader").replace("slope_green(world_position,normalize(world_normal)","slope_green(world_position,normalize(support_normal)")
	for name: String in entries:
		(ROCKS._pieces[name][2] as ShaderMaterial).shader = original
	await _capture(dir+"/before.png")
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://terrain/materials/meadow_rock.gdshader").replace(
		"slope_green(world_position,normalize(support_normal)",
		"slope_green(world_position,normalize(world_normal)")
	for name: String in entries:
		(ROCKS._pieces[name][2] as ShaderMaterial).shader = shader
	await _capture(dir+"/candidate.png")
	quit()

func _capture(path: String) -> void:
	for unused in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
