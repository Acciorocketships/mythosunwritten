extends GutTest

## The native ports' gate state is read on every height sample and river walk
## from many pool threads while a gate (or reset) publishes new state. A
## GDScript static Dictionary is not safe to read while another thread
## reassigns it: the reader's copy can catch the old Dictionary's _p between
## the writer's unref (freed, nulled) and the new pointer, so the reader
## dereferences null or freed memory (the intermittent startup SIGSEGV in
## NativeRiverWalk.ready_for / _gate). These loops crashed the process before
## the fix; now they must simply finish.

const NativeHeightField := preload("res://scripts/native/NativeHeightField.gd")
const NativeRiverWalk := preload("res://scripts/native/NativeRiverWalk.gd")
const READERS := 6
const READS := 200000
const SEED := 424242   # never set up: readers never gate, they only read state


func after_all() -> void:
	NativeHeightField.reset()
	NativeRiverWalk.reset()


func _hammer(ready_for: Callable, reset: Callable) -> int:
	var hits := [0]
	var job := func(_i: int) -> void:
		var n := 0
		for k in READS:
			if ready_for.call(SEED):
				n += 1
		if n > 0:
			hits[0] = n
	var group := WorkerThreadPool.add_group_task(job, READERS, READERS, true, "gate readers")
	var writes := 0
	while not WorkerThreadPool.is_group_task_completed(group):
		reset.call()
		writes += 1
	WorkerThreadPool.wait_for_group_task_completion(group)
	assert_gt(writes, 0, "the writer published while readers ran")
	return hits[0]


func test_height_field_state_survives_concurrent_readers_and_resets() -> void:
	assert_eq(_hammer(NativeHeightField.ready_for, NativeHeightField.reset), 0,
		"an unregistered seed is never served")


func test_river_walk_state_survives_concurrent_readers_and_resets() -> void:
	assert_eq(_hammer(NativeRiverWalk.ready_for, NativeRiverWalk.reset), 0,
		"an unregistered seed is never served")
