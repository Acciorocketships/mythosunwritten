extends SceneTree
## Renders Suntail source modules/houses for kit study. Usage:
## Godot --path . -s res://tests/harness/suntail/kit_lineup.gd -- --output DIR --set houses|modules
const R := "res://assets/Raygeas/Models/"
var _out := "user://suntail_lineup"
var _set := "houses"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--output": _out = args[i + 1]
		if args[i] == "--set": _set = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_run")

func _light(root: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.35, 0.5, 0.25)
	ground.material_override = gm
	root.add_child(ground)

func _shoot(root: Node3D, eye: Vector3, target: Vector3, name: String, fov := 50.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.look_at_from_position(eye, target)
	cam.current = true
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	cam.queue_free()

func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var root := Node3D.new()
	get_root().add_child(root)
	_light(root)
	if _set == "houses":
		for i in 8:
			var s: PackedScene = load(R + "Buildings/House_%d.glb" % (i + 1))
			var n: Node3D = s.instantiate()
			n.position = Vector3((i % 4) * 22.0, 0, (i / 4) * 24.0)
			root.add_child(n)
		await _shoot(root, Vector3(33, 45, 70), Vector3(33, 2, 10), "houses_overview", 55)
		for i in 8:
			var c := Vector3((i % 4) * 22.0, 5, (i / 4) * 24.0)
			await _shoot(root, c + Vector3(14, 8, 16), c, "house_%d_a" % (i + 1), 50)
			await _shoot(root, c + Vector3(-16, 6, -13), c, "house_%d_b" % (i + 1), 50)
	else:
		var files: Array[String] = []
		for sub in ["Frame_Modules", "Stone_Modules", "Roofs/Red", "Decor", "Doors_And_Windows", "Stairs"]:
			for f in DirAccess.get_files_at(R + "Building_Modules/" + sub):
				if f.ends_with(".glb"): files.append(R + "Building_Modules/" + sub + "/" + f)
		var col := 0
		var row := 0
		for f in files:
			var n: Node3D = (load(f) as PackedScene).instantiate()
			n.position = Vector3(col * 4.0, 0, row * 5.0)
			root.add_child(n)
			var lbl := Label3D.new(); lbl.text = f.get_file().get_basename(); lbl.font_size = 48; lbl.pixel_size = 0.004
			lbl.position = n.position + Vector3(0, -0.3, 1.5); lbl.rotation_degrees.x = -40
			root.add_child(lbl)
			col += 1
			if col >= 10:
				col = 0; row += 1
		for r in row + 1:
			await _shoot(root, Vector3(18, 7, r * 5.0 + 11), Vector3(18, 1.2, r * 5.0), "modules_row_%d" % r, 60)
	quit()
