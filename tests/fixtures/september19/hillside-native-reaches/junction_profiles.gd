extends SceneTree
const FOLDER := "res://docs/qa/2026-09-19-manual/112-hillside-native-reaches/"
func owner(value: String) -> Vector2i:
	var parts := value.trim_prefix("(").trim_suffix(")").split(",")
	return Vector2i(int(parts[0]),int(parts[1]))
func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"inventory-long.json"))
	var reports: Array[Dictionary] = []
	for key: String in ["(-2, -1)","(-2, -2)","(-3, -4)"]:
		for jump: Dictionary in inventory.routes[key].jumps:
			var a := water.river_for(owner(jump.from_owner),0)
			var b := water.river_for(owner(jump.to_owner),0)
			var ai := int(jump.from_station)
			var bi := int(jump.to_station)
			var p: Vector2 = a.points[ai]
			var q: Vector2 = b.points[bi]
			var samples: Array[Dictionary] = []
			for i in 13:
				var t := float(i)/12.0
				var x := p.lerp(q,t)
				samples.append({"point":[x.x,x.y],"uncarved_height":water.noise_h(x),"connector_bed":lerpf(a.beds[ai],b.beds[bi],t)})
			var row := jump.duplicate()
			row.route_source=key
			row.from_point=[p.x,p.y]
			row.to_point=[q.x,q.y]
			row.distance=p.distance_to(q)
			row.from_width=a.widths[ai]
			row.to_width=b.widths[bi]
			row.samples=samples
			reports.append(row)
	FileAccess.open(FOLDER+"junction-profiles.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	print("JUNCTION_PROFILES ",reports.size())
	quit()
