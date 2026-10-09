extends SceneTree
func _init()->void:
	var failures:=0;var checked:=0
	for seed_value:int in [2697992464,23,771,99]:
		var plan:=TerrainWorldTuning.make_water(seed_value)
		for z in range(-2,3):
			for x in range(-2,3):
				var cell:=Vector2i(x,z)
				if not plan.has_source(cell):continue
				var dependency:=plan.river_for(cell,1)
				var realized:=plan.river_for(cell,WaterPlan.JOIN_DEPTH)
				checked+=1
				if realized.points.slice(0,dependency.points.size())!=dependency.points:
					failures+=1
					print("JOIN_DEPENDENCY_FAIL seed=",seed_value," cell=",cell," dependency=",dependency.points.size()," realized=",realized.points.size())
	print("JOIN_DEPENDENCIES checked=",checked," failures=",failures)
	quit(1 if failures else 0)
