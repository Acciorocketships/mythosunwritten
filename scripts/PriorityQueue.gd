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

func _bubble_up(i):
	while i > 0:
		var p = int((i - 1) / 2)
		if heap[i]["priority"] >= heap[p]["priority"]:
			break
		var tmp = heap[i]
		heap[i] = heap[p]
		heap[p] = tmp
		i = p

func _bubble_down(i):
	var n = heap.size()
	while true:
		var l = i * 2 + 1
		var r = l + 1
		var smallest = i
		if l < n and heap[l]["priority"] < heap[smallest]["priority"]:
			smallest = l
		if r < n and heap[r]["priority"] < heap[smallest]["priority"]:
			smallest = r
		if smallest == i:
			break
		var tmp = heap[i]
		heap[i] = heap[smallest]
		heap[smallest] = tmp
		i = smallest
