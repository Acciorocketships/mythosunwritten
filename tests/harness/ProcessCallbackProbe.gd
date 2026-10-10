extends RefCounted

## Main-thread diagnostic, installed before the world's nodes are instantiated.
static var samples: Dictionary = {}


static func begin_frame() -> void:
	samples.clear()


static func record(path: String, usec: int) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return
	samples[path] = int(samples.get(path, 0)) + usec


static func install(path: String) -> void:
	var script := load(path) as GDScript
	assert(script != null)
	if script.source_code.contains("func _profiled_process_body("):
		return
	assert(script.source_code.contains("func _process("))
	var wrapper := "\nfunc _process(_profile_delta: float) -> void:\n"
	wrapper += "\tvar _profile_start := Time.get_ticks_usec()\n"
	wrapper += "\t_profiled_process_body(_profile_delta)\n"
	wrapper += (
		'\tpreload("res://tests/harness/ProcessCallbackProbe.gd").record("%s", Time.get_ticks_usec() - _profile_start)\n'
		% path
	)
	if path.ends_with("WaterRippleSim.gd"):
		wrapper += '\tpreload("res://tests/harness/ProcessCallbackProbe.gd").capture_ripple(self)\n'
	script.source_code = (
		script.source_code.replace("func _process(", "func _profiled_process_body(") + wrapper
	)
	assert(script.reload(true) == OK)


static func install_method(
	path: String, method: String, arguments: String, call_arguments: String, result_type: String
) -> void:
	var script := load(path) as GDScript
	var body := "_profiled_" + method
	if script.source_code.contains("func " + body + "("):
		return
	assert(script.source_code.contains("func " + method + "("))
	var wrapper := "\nfunc %s(%s) -> %s:\n" % [method, arguments, result_type]
	wrapper += "\tvar _profile_start := Time.get_ticks_usec()\n"
	wrapper += (
		"\t"
		+ ("var _profile_result = " if result_type != "void" else "")
		+ "%s(%s)\n" % [body, call_arguments]
	)
	wrapper += (
		'\tpreload("res://tests/harness/ProcessCallbackProbe.gd").record("%s:%s", Time.get_ticks_usec() - _profile_start)\n'
		% [path, method]
	)
	if result_type != "void":
		wrapper += "\treturn _profile_result\n"
	script.source_code = (
		script.source_code.replace("func " + method + "(", "func " + body + "(") + wrapper
	)
	assert(script.reload(true) == OK)


## Replay serialization is deliberately opt-in: doing it automatically after a
## slow callback creates a large unmeasured hitch in the profiling harness.
static var capture_ripple_enabled := false
static var ripple_captured := false


static func capture_ripple(sim: Node) -> void:
	if (
		not capture_ripple_enabled
		or ripple_captured
		or sim._packets.size() < 12
		or (
			int(samples.get("res://scripts/terrain/water/WaterRippleSim.gd:_update_packets", 0))
			< 20000
		)
	):
		return
	ripple_captured = true
	var capture_start := Time.get_ticks_usec()
	var state := {
		"samplers": [],
		"packets": sim._packets.duplicate(true),
		"packet_n": sim._packet_n,
		"packet_timer": sim._packet_timer,
		"packet_origin": sim._packet_origin
	}
	for sampler: WaterSampler in sim._samplers:
		var row := {}
		for property: Dictionary in sampler.get_property_list():
			var key: String = property.name
			if key.begins_with("_") and typeof(sampler.get(key)) != TYPE_OBJECT:
				row[key] = sampler.get(key)
		var ctx: Dictionary = row._fill_ctx.duplicate()
		if ctx.has("region"):
			var ground := {}
			for key: String in ["_first", "_w", "_h", "_heights", "_storeys"]:
				ground[key] = ctx.region.get(key)
			ctx.region = ground
		row._fill_ctx = ctx
		state.samplers.append(row)
	FileAccess.open("/tmp/oct9-ripple-replay.bin", FileAccess.WRITE).store_var(state)
	print("REPLAY_CAPTURE excluded_from_gameplay=true total_usec=",Time.get_ticks_usec()-capture_start)
