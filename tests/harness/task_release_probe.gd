extends SceneTree
## Where does a WorkerThreadPool task's bound payload die? The task is added
## from a helper (so no GDScript temporary of this frame keeps the Callable),
## runs and finishes; then this, the main thread, times
## wait_for_task_completion. Direct: the payload's last reference is the
## Callable's bound argument. Boxed: the task clears the box itself.
## Run: godot --headless --path . -s res://tests/harness/task_release_probe.gd

static func _noop(_value) -> void:
	pass

static func _clear(box: Array) -> void:
	box.clear()

static func _payload() -> Dictionary:
	var items: Array = []
	for i in 200000:
		items.append({"i": i, "v": PackedFloat32Array([i, i, i]), "s": "x%d" % i})
	return {"items": items}

static func _submit_direct() -> int:
	return WorkerThreadPool.add_task(_noop.bind(_payload()))

static func _submit_boxed() -> int:
	return WorkerThreadPool.add_task(_clear.bind([_payload()]))

static func _wait(task: int) -> Array:
	while not WorkerThreadPool.is_task_completed(task):
		OS.delay_msec(1)
	OS.delay_msec(20)
	var mem0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	WorkerThreadPool.wait_for_task_completion(task)
	return [(Time.get_ticks_usec() - t0) / 1000.0, (mem0 - OS.get_static_memory_usage()) / 1e6]

func _init() -> void:
	for round in 3:
		var direct := _wait(_submit_direct())
		var boxed := _wait(_submit_boxed())
		print("TASK_RELEASE round=%d direct: wait_ms=%.1f freed_mb=%.1f  boxed: wait_ms=%.1f freed_mb=%.1f" % [
			round, direct[0], direct[1], boxed[0], boxed[1]])
	quit()
