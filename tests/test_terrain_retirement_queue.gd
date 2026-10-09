extends GutTest
const RetirementQueue = preload("res://scripts/terrain/field/TerrainRetirementQueue.gd")

func test_detaches_immediately_and_destroys_at_most_the_requested_nodes() -> void:
	var queue := RetirementQueue.new()
	var world := Node.new()
	add_child(world)
	var chunk := Node.new()
	world.add_child(chunk)
	var weak: Array[WeakRef] = [weakref(chunk)]
	for i in 10:
		var branch := Node.new()
		chunk.add_child(branch)
		weak.append(weakref(branch))
		for j in 5:
			var leaf := Node.new()
			branch.add_child(leaf)
			weak.append(weakref(leaf))
	queue.enqueue(chunk)
	assert_false(chunk.is_inside_tree(), "no retired physics, process or render nodes remain in the world")
	assert_eq(world.get_child_count(), 0)
	var count := 0
	while queue.pending():
		var freed := queue.drain(1000000, 7)
		assert_lte(freed, 7)
		count += freed
	assert_eq(count, weak.size())
	for ref: WeakRef in weak: assert_null(ref.get_ref())
	world.free()

func test_shutdown_frees_a_partly_walked_tree_and_waiting_roots() -> void:
	var queue := RetirementQueue.new()
	var weak: Array[WeakRef] = []
	for i in 3:
		var root := Node.new()
		weak.append(weakref(root))
		for j in 10:
			var child := Node.new()
			root.add_child(child)
			weak.append(weakref(child))
		queue.enqueue(root)
	queue.drain(1000000, 2)
	queue.clear()
	assert_false(queue.pending())
	for ref: WeakRef in weak: assert_null(ref.get_ref())
