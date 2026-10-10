extends SceneTree
## Inspect the real photographed conflict without starting rendering or grass.
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var traces: Array[RiverTrace] = []
	for source: Vector2i in [Vector2i(0,2), Vector2i(-1,0)]:
		var trace := water.river_for(source)
		traces.append(trace)
		print("TRACE ", source, " priority=", trace.priority, " joined=", trace.joined, " stations=", trace.points.size())
	var upper := traces[0]
	var lower := traces[1]
	for i in range(maxi(0,upper.points.size()-5), upper.points.size()):
		var p := upper.points[i]
		var nearest := INF
		var lower_bed := INF
		var station := -1
		for j in range(lower.points.size()-1):
			var a := lower.points[j]
			var ab := lower.points[j+1]-a
			var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),.00001),0,1)
			var distance := p.distance_to(a+ab*t)
			if distance < nearest:
				nearest = distance
				lower_bed = lerpf(lower.beds[j],lower.beds[j+1],t)
				station = j
		print("OVERLAP ",JSON.stringify({"station":i,"point":str(p),"bed":upper.beds[i],"width":upper.widths[i],"receiver_station":station,"distance":nearest,"receiver_bed":lower_bed}))
	quit()
