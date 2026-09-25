extends SceneTree

func _init() -> void:
	var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
	terraces.prepare()
	var rows: Array[Dictionary] = []
	for orientation in 4:
		for stepped: bool in [false,true]:
			var plan := HeightfieldPlan.new(17,64,12,"mean",4)
			plan.set_raw_height_override(func(cx: int, cz: int) -> float:
				var p := Vector2(cx-3,cz-3).rotated(orientation*PI/2)
				if p.x > .1 and p.y > .1: return 0.0
				return 12.0 if stepped and p.x > .1 else 16.0)
			var region := plan.compute_region(4,4,12)
			for seed_value in 16:
				var start := Time.get_ticks_usec()
				var data := terraces.compute(region,0,0,8,seed_value)
				var elapsed := Time.get_ticks_usec()-start
				var kinds: Dictionary = {}
				for p: Dictionary in data.placements:
					kinds[p.kind] = int(kinds.get(p.kind,0))+1
				rows.append({"orientation":orientation,"stepped":stepped,"seed":seed_value,
					"kinds":kinds,"usec":elapsed,"triangles":data.collision_faces.size()/3})
	FileAccess.open("res://docs/qa/2026-09-11-manual/11-cliffs/census.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
