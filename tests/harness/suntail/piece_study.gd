extends SceneTree
## Renders named source pieces side by side for close study.
## -s piece_study.gd -- --output DIR --pieces a.glb,b.glb [--eye x,y,z]
var _out := "user://piece_study"
var _pieces: PackedStringArray = []
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--output": _out = args[i + 1]
		if args[i] == "--pieces": _pieces = args[i + 1].split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_run")
func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var stage := Node3D.new(); get_root().add_child(stage)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.6, 0.72, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e; stage.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); sun.shadow_enabled = true; stage.add_child(sun)
	var x := 0.0
	for p in _pieces:
		var n: Node3D = (load("res://assets/Raygeas/Models/" + p) as PackedScene).instantiate()
		n.position = Vector3(x, 0, 0); stage.add_child(n)
		var l := Label3D.new(); l.text = p.get_file(); l.pixel_size = 0.004; l.position = Vector3(x, -0.4, 1.5); stage.add_child(l)
		x += 3.5
	var cam := Camera3D.new(); stage.add_child(cam)
	cam.look_at_from_position(Vector3(x * 0.5 - 1.5, 3.5, 9), Vector3(x * 0.5 - 1.5, 1.2, 0)); cam.current = true
	for i in 10: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/front.png")
	cam.look_at_from_position(Vector3(x * 0.5 - 1.5, 5, -8), Vector3(x * 0.5 - 1.5, 1.2, 0))
	for i in 10: await process_frame
	get_root().get_texture().get_image().save_png(_out + "/back.png")
	quit()
