extends SceneTree
## Pass --reference PATH to a saved pre-change TrampleField.gd for matched runs.

func _init() -> void:
	var reference := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--reference": reference = args[i + 1]
	if reference.is_empty():
		push_error("Expected --reference PATH to the pre-change TrampleField.gd")
		quit(1)
		return
	var source := GDScript.new()
	source.source_code = FileAccess.get_file_as_string(reference).replace("class_name TrampleField\n", "")
	if source.reload() != OK:
		quit(1)
		return
	for variant in 2:
		var field: Node = source.new() if variant == 0 else TrampleField.new()
		field._initialize(Vector2.ZERO)
		var stamps: Array[int] = []
		var scrolls: Array[int] = []
		var rebases: Array[int] = []
		for frame in 7200:
			var seconds := frame / 60.0
			var p := Vector3(sin(seconds * 0.11) * 25.0, 0, seconds * 4.0)
			var t := Time.get_ticks_usec()
			field._update_time(1.0 / 60.0)
			if frame > 3500 and frame < 3700 or frame > 7100:
				rebases.append(Time.get_ticks_usec() - t)
			t = Time.get_ticks_usec()
			field._scroll_if_needed(Vector2(p.x, p.z))
			scrolls.append(Time.get_ticks_usec() - t)
			t = Time.get_ticks_usec()
			field.stamp(p, Vector2(0.2, 1), 1.1, 1.0)
			stamps.append(Time.get_ticks_usec() - t)
		stamps.sort(); scrolls.sort(); rebases.sort()
		print("TRAMPLE_WALK variant=", variant, " stamp_p50_us=", stamps[3600],
			" stamp_p95_us=", stamps[6840], " scroll_max_us=", scrolls[-1],
			" epoch_max_us=", rebases[-1], " strength=", field.effective_strength(Vector2(sin(119.983333 * 0.11) * 25, 119.983333 * 4)))
		field.free()
	quit()
