extends SceneTree
func _init() -> void:
	var script := load("res://scripts/native/NativeRuntimeProbe.cs") as Script
	var probe = script.new()
	var first: Dictionary = probe.OsUsage()
	if OS.get_name() != "macOS":
		assert(first.is_empty())
		quit()
		return
	var cpu_before: int = probe.ThreadCpuUsec()
	OS.delay_msec(100)
	var cpu_after: int = probe.ThreadCpuUsec()
	assert(cpu_before > 0 and cpu_after >= cpu_before and cpu_after - cpu_before < 50000, "sleep must not count as CPU time")
	var work := 0
	for i in 100000: work += i % 31
	var cpu_busy: int = probe.ThreadCpuUsec()
	assert(work > 0 and cpu_busy > cpu_after, "busy work must advance CPU time")
	var start := Time.get_ticks_usec()
	for i in 10000: probe.OsUsage()
	var usec := Time.get_ticks_usec()-start
	var last: Dictionary = probe.OsUsage()
	assert(first.physical_bytes > 0 and first.resident_bytes > 0)
	assert(last.pageins >= first.pageins)
	print("OS_PROBE ",JSON.stringify({"first":first,"last":last,"mean_usec":float(usec)/10000.0}))
	quit()
