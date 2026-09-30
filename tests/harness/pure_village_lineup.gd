extends SceneTree
## Renders a sample of the converted BK Pure Village pack (assets/PureVillage) to check
## scale, orientation and materials after a Unity conversion. Usage:
## Godot --path . -s res://tests/harness/pure_village_lineup.gd -- --output DIR
const R := "res://assets/PureVillage/Models/"
const HOUSES := ["Houses/House_1", "Houses/House_5", "Houses/StreetHouse_3", "HouseWarp/WARP_House_1",
	"Houses/BigHouse_1", "HouseWarp/WARP_House_12"]
const SMALL := ["Props", "Garden", "Plants", "Furniture", "Structures", "Trees"]
var _out := "user://pure_village_lineup"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--output":
			_out = args[i + 1]
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
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.5, 0.25)
	ground.material_override = gm
	root.add_child(ground)


func _shoot(root: Node3D, eye: Vector3, target: Vector3, name: String, fov := 50.0) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	root.add_child(cam)
	cam.look_at_from_position(eye, target)
	cam.current = true
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	cam.queue_free()


func _label(root: Node3D, text: String, at: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.position = at
	lbl.rotation_degrees.x = -40
	root.add_child(lbl)


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var root := Node3D.new()
	get_root().add_child(root)
	_light(root)
	# Whole houses in a row, 30 m apart.
	for i in HOUSES.size():
		var n: Node3D = (load(R + HOUSES[i] + ".glb") as PackedScene).instantiate()
		n.position = Vector3(i * 30.0, 0, 0)
		root.add_child(n)
		var b := _aabb(n)
		print("%s size %s min %s" % [HOUSES[i], b.size, b.position])
		_label(root, HOUSES[i], n.position + Vector3(0, 0.2, 14))
	await _shoot(root, Vector3(75, 45, 75), Vector3(75, 4, 0), "houses_overview", 55)
	for i in HOUSES.size():
		var c := Vector3(i * 30.0, 6, 0)
		await _shoot(root, c + Vector3(16, 6, 20), c, "house_%d" % i, 50)
	# Small props per category on a grid beyond the houses (first 12 per folder).
	var row := 0
	for sub: String in SMALL:
		var col := 0
		for f in DirAccess.get_files_at(R + sub):
			if not f.ends_with(".glb") or col >= 12:
				continue
			var n: Node3D = (load(R + sub + "/" + f) as PackedScene).instantiate()
			n.position = Vector3(col * 4.0, 0, 60.0 + row * 8.0)
			root.add_child(n)
			col += 1
		await _shoot(root, Vector3(22, 7, 60.0 + row * 8.0 + 12), Vector3(22, 0.8, 60.0 + row * 8.0), "cat_" + sub, 55)
		row += 1
	# Modular architecture sample.
	var files: Array = Array(DirAccess.get_files_at(R + "Architecture")).filter(func(f: String) -> bool: return f.ends_with(".glb"))
	for k in 24:
		var f: String = files[(k * files.size()) / 24]
		var n: Node3D = (load(R + "Architecture/" + f) as PackedScene).instantiate()
		n.position = Vector3((k % 8) * 5.0, 0, 120.0 + (k / 8) * 7.0)
		root.add_child(n)
	await _shoot(root, Vector3(18, 14, 150), Vector3(18, 1, 126), "architecture_sample", 60)
	quit()
