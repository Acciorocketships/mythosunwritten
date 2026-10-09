extends RefCounted
func run(review: Node) -> void:
	var streamer = review._streamer
	streamer.set_process(false)
	var chunk = streamer._built.keys()[0]
	var root: Node = streamer._built[chunk]
	streamer._retire_terrain(root)
	streamer._built.erase(chunk)
	var queue = streamer._retirement
	while queue.pending():
		if queue._walk.is_empty(): queue._walk.append(queue._roots.pop_front())
		var node: Node = queue._walk.back()
		if node.get_child_count():
			queue._walk.append(node.get_child(node.get_child_count()-1))
		else:
			queue._walk.pop_back()
			var label := str(node.name)+" "+node.get_class()+" "+str(node.get_meta_list())
			var started := Time.get_ticks_usec()
			node.free()
			var elapsed := Time.get_ticks_usec()-started
			if elapsed > 1000: print("RETIRE_NODE ",elapsed," ",label)
		await review.get_tree().process_frame
	streamer.set_process(true)
	print("RETIRE_DETAIL_DONE")
