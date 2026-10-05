extends Object
class_name PriorityQueue

var heap: Array = []

func push(item, priority: float) -> void:
	heap.append({"item": item, "priority": priority})
	_bubble_up(heap.size() - 1)

func pop():
	if heap.is_empty():
		return null
	var root = heap[0]["item"]
	var last = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		_bubble_down(0)
	return root

func peek():
	if heap.is_empty():
		return null
	return heap[0]["item"]

func size() -> int:
	return heap.size()

func is_empty() -> bool:
	return heap.is_empty()

func remove_where(predicate: Callable) -> int:
	var new_heap: Array = []
	var removed: int = 0
	for entry in heap:
		if not predicate.call(entry["item"]):
			new_heap.append(entry)
		else:
			removed += 1
	heap = new_heap
	_rebuild_heap()
	return removed


func _rebuild_heap() -> void:
	if heap.is_empty():
		return
	var i: int = int(heap.size() / 2) - 1
	while i >= 0:
		_bubble_down(i)
		i -= 1

## Sift with a hole: the moving entry's priority is read once and parents
## (children) shift into the hole. The comparisons are the swap version's,
## so the heap ends identical; this was the hydraulic fill's hottest code.
func _bubble_up(i: int) -> void:
	var entry: Dictionary = heap[i]
	var priority: float = entry["priority"]
	while i > 0:
		var p := int((i - 1) / 2)
		var parent: Dictionary = heap[p]
		if priority >= float(parent["priority"]):
			break
		heap[i] = parent
		i = p
	heap[i] = entry

func _bubble_down(i: int) -> void:
	var n: int = heap.size()
	var entry: Dictionary = heap[i]
	var priority: float = entry["priority"]
	while true:
		var l := i * 2 + 1
		if l >= n:
			break
		var smallest := i
		var smallest_priority := priority
		var left_priority: float = heap[l]["priority"]
		if left_priority < smallest_priority:
			smallest = l
			smallest_priority = left_priority
		var r := l + 1
		if r < n:
			var right_priority: float = heap[r]["priority"]
			if right_priority < smallest_priority:
				smallest = r
		if smallest == i:
			break
		heap[i] = heap[smallest]
		i = smallest
	heap[i] = entry
