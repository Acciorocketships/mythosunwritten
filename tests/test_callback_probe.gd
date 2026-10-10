extends GutTest
const Probe = preload("res://tests/harness/ProcessCallbackProbe.gd")
func test_profiling_never_captures_replay_unless_requested() -> void:
	assert_false(Probe.capture_ripple_enabled)
	# An ordinary profile must return without even inspecting the simulator.
	Probe.capture_ripple(null)
	assert_false(Probe.ripple_captured)
