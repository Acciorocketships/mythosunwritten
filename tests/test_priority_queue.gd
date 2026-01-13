extends GutTest

func test_priority_queue():
	var queue = PriorityQueue.new()
	queue.push("a", 3)
	queue.push("b", 4)
	queue.push("c", 2)
	queue.push("d", 5)
	queue.push("e", 1)
	var o1 = queue.pop()
	assert_eq(o1, "e")
	var o2 = queue.pop()
	assert_eq(o2, "c")
	var o3 = queue.pop()
	assert_eq(o3, "a")
	var o4 = queue.pop()
	assert_eq(o4, "b")
	assert_true(not queue.is_empty())
	var o5 = queue.pop()
	assert_eq(o5, "d")
	assert_true(queue.is_empty())
	# PriorityQueue extends Object (not RefCounted), so free explicitly to avoid leaks.
	queue.free()
	
	
