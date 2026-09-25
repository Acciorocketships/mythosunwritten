extends SceneTree

func _init() -> void:
	var rows: Array = []
	for index in 4:
		var record: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/36-world-paths/route-%d.bin" % index,FileAccess.READ).get_var()
		var adjacency: Dictionary = record.edges.duplicate(true)
		for cell: int in record.edges:
			for edge: Dictionary in record.edges[cell]:
				if not adjacency.has(int(edge.to)): adjacency[int(edge.to)] = []
				var reverse := edge.duplicate(true)
				reverse.to = cell
				(adjacency[int(edge.to)] as Array).append(reverse)
		var pending: Array[int] = [int(record.start)]
		var seen := {int(record.start):true}
		while not pending.is_empty():
			var cell: int = pending.pop_back()
			for edge: Dictionary in adjacency.get(cell,[]):
				if seen.has(int(edge.to)): continue
				seen[int(edge.to)] = true
				pending.append(int(edge.to))
		rows.append({"route":index,"undirected_reaches_goal":seen.has(int(record.goal)),"reachable":seen.size(),"total":record.heights.size()})
	print(JSON.stringify(rows,"  "))
	FileAccess.open("res://docs/qa/2026-09-13-manual/36-world-paths/reachability.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
