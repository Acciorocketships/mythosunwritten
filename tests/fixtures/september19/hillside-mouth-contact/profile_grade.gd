extends RefCounted
## Experimental longitudinal shaping, before river heads enter the shared fill.
## The floor is the downstream envelope of actual terrain clearance, bounded
## by the supplied head. A real sill may require a steeper descent.
static func constrain(points: PackedVector2Array, levels: PackedFloat32Array,
		ground: PackedFloat32Array, grade: float) -> PackedFloat32Array:
	var out := levels.duplicate()
	var floor := -INF
	for i in range(out.size()-1,-1,-1):
		floor=maxf(floor,minf(levels[i],ground[i]+WaterField.DESCENT_CLAMP))
		if i+1<out.size():
			out[i]=minf(levels[i],maxf(floor,out[i+1]+grade*points[i].distance_to(points[i+1])))
	return out

static func shape(trace: RiverTrace, region, levels: PackedFloat32Array, descents: Array) -> Dictionary:
	if region==null or levels.size()<2 or levels[0]-levels[-1]<.1:
		return {"levels":levels,"descents":descents}
	var positions := PackedVector2Array()
	var widths := PackedFloat32Array()
	var dense := PackedFloat32Array()
	var bank_sources := PackedInt32Array()
	var anchors := PackedInt32Array(); anchors.resize(levels.size())
	var anchor_ranges: Dictionary = {}
	var spans: Dictionary = {}
	for d: Dictionary in descents: spans[int(d.lo)]=d
	var i := 0
	while i<levels.size()-1:
		anchors[i]=positions.size()
		if spans.has(i):
			var d: Dictionary = spans[i]
			for j in d.pos.size()-1:
				positions.append(d.pos[j]); widths.append(d.w[j]); dense.append(d.lvl[j])
				bank_sources.append(-1)
			# Original stations inside a shaped span need their nearest dense
			# interpolation below, rather than a guessed uniform index.
			for k in range(i+1,int(d.hi)):
				anchors[k]=-1
				anchor_ranges[k]=Vector2i(anchors[i],positions.size())
			i=int(d.hi)
		else:
			var steps := maxi(1,ceili(trace.points[i].distance_to(trace.points[i+1])/4.0))
			for j in steps:
				var t := float(j)/steps
				positions.append(trace.points[i].lerp(trace.points[i+1],t))
				widths.append(lerpf(trace.widths[i],trace.widths[i+1],t))
				dense.append(lerpf(levels[i],levels[i+1],t))
				bank_sources.append(i)
			i+=1
	anchors[-1]=positions.size()
	positions.append(trace.points[-1]); widths.append(trace.widths[-1]); dense.append(levels[-1])
	var ground := PackedFloat32Array()
	for p: Vector2 in positions: ground.append(TerrainSurfaceField.surface_y(region,p.x,p.y))
	var receivers: Array[Dictionary] = []
	for station: int in trace.get_meta("receiver_stations",PackedInt32Array()):
		if station+1>=trace.points.size(): continue
		var dense_station: int = anchors[station]
		if dense_station<0:
			var bounds: Vector2i = anchor_ranges[station]
			var best := INF
			for k in range(bounds.x,mini(bounds.y+1,positions.size())):
				var distance := positions[k].distance_squared_to(trace.points[station])
				if distance<best: best=distance; dense_station=k
		receivers.append({"index":dense_station,"a":trace.points[station],"b":trace.points[station+1],"wa":trace.widths[station],"wb":trace.widths[station+1],"head":levels[station]})
	dense=receiver_caps(positions,dense,ground,receivers)
	dense=constrain(positions,dense,ground,.22)
	var result := levels.duplicate()
	for k in levels.size():
		if anchors[k]>=0:
			result[k]=dense[anchors[k]]
		else:
			var best := INF
			for j in positions.size()-1:
				var ab := positions[j+1]-positions[j]
				var t := clampf((trace.points[k]-positions[j]).dot(ab)/maxf(ab.length_squared(),.000001),0,1)
				var distance := trace.points[k].distance_squared_to(positions[j]+ab*t)
				if distance<best:
					best=distance; result[k]=lerpf(dense[j],dense[j+1],t)
	return {"levels":result,"descents":[{"lo":0,"hi":levels.size()-1,"pos":positions,"w":widths,"lvl":dense,"bank_sources":bank_sources}]}

## Resolve only the contiguous tributary mouth inside its declared receiver.
## The receiver cannot lower an upstream reach through real intervening ground.
static func receiver_caps(points: PackedVector2Array, levels: PackedFloat32Array,
		ground: PackedFloat32Array, receivers: Array[Dictionary]) -> PackedFloat32Array:
	var out := levels.duplicate()
	for rindex in range(receivers.size()-1,-1,-1):
		var receiver: Dictionary = receivers[rindex]
		var head := minf(receiver.head,out[receiver.index])
		var ab: Vector2 = receiver.b-receiver.a
		for i in range(receiver.index-1,-1,-1):
			var t := clampf((points[i]-receiver.a).dot(ab)/maxf(ab.length_squared(),.000001),0,1)
			var width := lerpf(receiver.wa,receiver.wb,t)
			if points[i].distance_to(receiver.a+ab*t)>width: break
			if ground[i]+WaterField.EPS>=head: break
			out[i]=minf(out[i],head)
	return out
