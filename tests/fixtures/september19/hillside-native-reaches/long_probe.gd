extends SceneTree
func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var study := preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_study.gd").new(water)
	var routes: Array[Dictionary] = []
	for source: Vector2i in [Vector2i(-4,-7),Vector2i(-8,4)]:
		var route: Dictionary = study.route(source)
		routes.append(route)
		print("LONG_ROUTE ",source," ",route.termination," stations=",route.nodes.size()," arc=",route.arc," basin=",route.terminal_owner)
	FileAccess.open("res://docs/qa/2026-09-19-manual/112-hillside-native-reaches/long-routes.json",FileAccess.WRITE).store_string(JSON.stringify(routes,"  "))
	quit()
