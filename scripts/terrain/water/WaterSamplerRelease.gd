extends RefCounted
## Frozen water data can be large. Keep it alive until its callers return,
## then release on a worker. The task's bound box is empty when reaped.
var _pending: Array = []
var _tasks: Array[int] = []

func hold(value) -> void:
	_pending.append(value)

func flush() -> void:
	for i in range(_tasks.size()-1,-1,-1):
		if WorkerThreadPool.is_task_completed(_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_tasks[i])
			_tasks.remove_at(i)
	if _pending.is_empty(): return
	var box := _pending
	_pending = []
	_tasks.append(WorkerThreadPool.add_task(_drop.bind(box)))

func finish() -> void:
	flush()
	for task in _tasks: WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()

static func _drop(box: Array) -> void:
	box.clear()

static func take_from(root: Node) -> Array:
	var held: Array = []
	if root.has_meta(&"sampler"):
		held.append(root.get_meta(&"sampler"))
		root.remove_meta(&"sampler")
	for child in root.get_children():
		if child.has_meta(&"sampler"):
			held.append(child.get_meta(&"sampler"))
			child.remove_meta(&"sampler")
	return held
