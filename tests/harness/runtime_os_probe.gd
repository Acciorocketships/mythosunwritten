extends SceneTree
func _init() -> void:
	var script := load("res://scripts/native/NativeRuntimeProbe.cs") as Script
	var probe = script.new()
	var first: Dictionary = probe.OsUsage()
	if OS.get_name() != "macOS":
		assert(first.is_empty())
		quit()
		return
	var start := Time.get_ticks_usec()
	for i in 10000: probe.OsUsage()
	var usec := Time.get_ticks_usec()-start
	var last: Dictionary = probe.OsUsage()
	assert(first.physical_bytes > 0 and first.resident_bytes > 0)
	assert(last.pageins >= first.pageins)
	print("OS_PROBE ",JSON.stringify({"first":first,"last":last,"mean_usec":float(usec)/10000.0}))
	quit()
