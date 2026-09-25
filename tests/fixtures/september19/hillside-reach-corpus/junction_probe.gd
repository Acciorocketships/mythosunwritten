extends SceneTree
const STUDY = preload("res://tests/fixtures/september19/hillside-retained-network/reach_study.gd")

func _initialize() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var study := STUDY.new(water)
	var rows: Array[Dictionary] = []
	for cell: Vector2i in [Vector2i(-6,-4),Vector2i(-4,-3),Vector2i(-2,-1),Vector2i(-2,-2)]:
		var route: Dictionary = study.route(cell)
		for jump: Dictionary in route.jumps:
			var from := _cell(jump.from_owner)
			var to := _cell(jump.to_owner)
			var a := water.river_for(from,0)
			var b := water.river_for(to,0)
			var p := a.points[jump.from_station]
			var q := b.points[jump.to_station]
			var row: Dictionary = jump.duplicate()
			row.merge({"source":str(cell),"from_count":a.points.size(),"to_count":b.points.size(),
				"distance":p.distance_to(q),"own_pond_t":a.pond.footprint_t(p),
				"own_pond_surface":a.pond.surface_y(),"target_pond_t":b.pond.footprint_t(q),
				"from_ground":water.noise_h(p),"to_ground":water.noise_h(q)})
			rows.append(row)
			print("JUNCTION ",JSON.stringify(row))
	FileAccess.open("res://docs/qa/2026-09-19-manual/111-hillside-reach-corpus/junctions.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()

func _cell(value: String) -> Vector2i:
	var parts := value.trim_prefix("(").trim_suffix(")").split(",")
	return Vector2i(int(parts[0]),int(parts[1]))
