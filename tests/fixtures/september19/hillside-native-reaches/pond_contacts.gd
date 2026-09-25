extends SceneTree
func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var study := preload("res://tests/fixtures/september19/hillside-reach-corpus/terminal_reach_study.gd").new(water)
	var contacts: Array[Dictionary] = []
	for source: Vector2i in [Vector2i(-4,-7),Vector2i(-8,4)]:
		var route: Dictionary = study.route(source)
		var seen: Dictionary = {}
		for i in route.nodes.size():
			var node: Dictionary = route.nodes[i]
			var parts: PackedStringArray = String(node.owner).trim_prefix("(").trim_suffix(")").split(",")
			var current := water.river_for(Vector2i(int(parts[0]),int(parts[1])),0)
			var candidates: Array = study._index(current).rivers.duplicate()
			candidates.append(current)
			var p := Vector2(node.point[0],node.point[1])
			for receiver: RiverTrace in candidates:
				if seen.has(receiver.source_cell): continue
				if receiver.pond.footprint_t(p)>=1: continue
				if receiver.beds[-1]>float(node.bed): continue
				if receiver.pond.surface_y()>float(node.bed)+WaterField.SURFACE_RIDE: continue
				seen[receiver.source_cell]=true
				contacts.append({"source":str(source),"index":i,"owner":node.owner,"station":node.station,"receiver":str(receiver.source_cell),"receiver_stations":receiver.points.size(),"distance_to_center":p.distance_to(receiver.pond.center),"bed":node.bed,"pond_surface":receiver.pond.surface_y()})
				print("POND_CONTACT ",contacts[-1])
	FileAccess.open("res://docs/qa/2026-09-19-manual/112-hillside-native-reaches/pond-contacts.json",FileAccess.WRITE).store_string(JSON.stringify(contacts,"  "))
	quit()
