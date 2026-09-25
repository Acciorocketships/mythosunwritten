extends SceneTree

func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var study := preload("res://tests/fixtures/september19/hillside-retained-network/reach_study.gd").new(water)
	var cells: Array[Vector2i] = [Vector2i(-2,-1), Vector2i(-3,-4), Vector2i(-4,-1), Vector2i(-3,-2), Vector2i(-2,-2), Vector2i(-3,-1), Vector2i(-4,-3)]
	if "--reverse" in OS.get_cmdline_user_args(): cells.reverse()
	var routes: Array[Dictionary] = []
	for cell: Vector2i in cells:
		var route := study.route(cell)
		routes.append(route)
		var summary := route.duplicate()
		summary.erase("nodes")
		summary["node_count"] = route.nodes.size()
		print("REACH_STUDY ", JSON.stringify(summary))
	routes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.source < b.source)
	var suffix := "reverse" if "--reverse" in OS.get_cmdline_user_args() else "forward"
	FileAccess.open("res://docs/qa/2026-09-19-manual/110-hillside-retained-network/reach-" + suffix + ".json", FileAccess.WRITE).store_string(JSON.stringify(routes,"  "))
	quit()
