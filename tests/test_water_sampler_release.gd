extends GutTest
const Release = preload("res://scripts/terrain/water/WaterSamplerRelease.gd")
class Tracked:
	extends RefCounted
	var report: Array
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE: report.append(OS.get_thread_caller_id())

func test_metadata_and_ripple_owners_release_only_after_their_frames_return() -> void:
	var report := []
	var payload := Tracked.new()
	payload.report = report
	var water := Node.new()
	var area := Node.new()
	water.add_child(area)
	water.set_meta("sampler",payload)
	area.set_meta("sampler",payload)
	var ripple := Release.new()
	var terrain := Release.new()
	ripple.hold([payload])
	terrain.hold(Release.take_from(water))
	payload = null
	water.free()
	assert_true(report.is_empty(),"node destruction must not release the frozen water data")
	terrain.finish()
	assert_true(report.is_empty(),"the ripple owner still pins its sampler")
	ripple.finish()
	assert_eq(report.size(),1)
	assert_ne(report[0],OS.get_main_thread_id(),"last reference must die on the worker")
