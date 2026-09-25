extends SceneTree

func _init() -> void:
	var rows:Array[Dictionary]=[]
	var depth:=WaterPlan.JOIN_DEPTH if OS.get_cmdline_user_args().has("--joined") else 0
	for seed_value:int in [2697992464,991177,314159]:
		var water:=TerrainWorldTuning.make_water(seed_value)
		for z in range(-4,5):
			for x in range(-4,5):
				var trace:=water.river_for(Vector2i(x,z),depth)
				if trace==null: continue
				var bars:Array=[]
				for bar:Dictionary in trace.land_bars:
					bars.append({"x":bar.center.x,"z":bar.center.y})
				var drop:=0.0
				var steepest:=Vector2.ZERO
				for i in range(trace.points.size()-1):
					if trace.beds[i]-trace.beds[i+1]>drop:
						drop=trace.beds[i]-trace.beds[i+1]
						steepest=trace.points[i]
				rows.append({"seed":seed_value,"source":[x,z],"length":(trace.points.size()-1)*12,
					"bars":bars,"width":trace.widths[-1],"drop":drop,"drop_point":[steepest.x,steepest.y],
					"joined":trace.joined,"pond":[trace.pond.center.x,trace.pond.center.y] if trace.pond!=null else null,
					"island_radius":trace.pond.island_radius if trace.pond!=null else 0,"peninsula":trace.pond.peninsula if trace.pond!=null else false})
		print("RIVER_SURVEY ",seed_value," cumulative=",rows.size())
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/river-survey%s.json" % ("-joined" if depth>0 else ""),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
