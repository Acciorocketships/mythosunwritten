extends SceneTree

func _init() -> void:
	var start := Time.get_ticks_msec()
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	print("EVENING_PROFILE compile_ms=", Time.get_ticks_msec()-start)
	var water := TerrainWorldTuning.make_water(2697992464)
	var heightfield := TerrainWorldTuning.make_heightfield(2697992464, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var world := WorldFeaturePlan.new(2697992464, water, fields, program,
		SettlementPlan.new(2697992464, water))
	start = Time.get_ticks_msec()
	var frame := world.frame_for(Vector2i.ZERO)
	print("EVENING_PROFILE frame_ms=", Time.get_ticks_msec()-start)
	var vp := world.village_plan()
	var axis := vp._street_axis(frame)
	var urban := VillageWarrenFabricSolver.solve(VillageTerrainView.from_fields(fields), VillagePlan.warren_seed_for_cell(2697992464,frame.cell),frame.settlement_id,frame.centre,axis,program.villages,2697992464)
	_scan(catalog,urban)
	quit()

func _scan(catalog: EnvironmentCatalog, urban: VillageUrbanFabricPlan) -> void:
	var buckets: Dictionary = {}
	var region := AABB(Vector3(244,22,292),Vector3(30,16,30))
	for entry: Dictionary in urban.entries:
		var descriptor := catalog.descriptor(entry.asset_id)
		var transform: Transform3D = entry.transform
		if not region.intersects(transform * descriptor.measured_aabb): continue
		var visual: EnvironmentVisual = load(descriptor.visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			var world := transform * piece.local_transform
			for surface in piece.mesh.get_surface_count():
				var arrays := piece.mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for offset in range(0,indices.size(),3):
					var a := world * verts[indices[offset]]
					var b := world * verts[indices[offset+1]]
					var c := world * verts[indices[offset+2]]
					var normal := (b-a).cross(c-a).normalized()
					var axis := normal.abs().max_axis_index()
					if absf(normal[axis])<0.99999 or axis == 1: continue
					var key := "%d/%d" % [axis,roundi(a[axis]*1000)]
					var poly := PackedVector2Array()
					for v: Vector3 in [a,b,c]: poly.append(Vector2(v[(axis+1)%3],v[(axis+2)%3]))
					var rect := Rect2(poly[0],Vector2.ZERO).expand(poly[1]).expand(poly[2])
					if not buckets.has(key): buckets[key]=[]
					buckets[key].append({"id":str(entry.stable_id),"asset":str(entry.asset_id),"p":poly,"box":rect,"n":normal})
	var pairs: Dictionary = {}
	for plane: String in buckets:
		var faces: Array = buckets[plane]
		for i in faces.size():
			var left: Dictionary = faces[i]
			for j in range(i+1,faces.size()):
				var right: Dictionary = faces[j]
				if left.id==right.id or (left.n as Vector3).dot(right.n) < 0.99 or not (left.box as Rect2).intersects(right.box): continue
				var area := 0.0
				for poly in Geometry2D.intersect_polygons(left.p,right.p):
					var sum := 0.0
					for k in poly.size(): sum += poly[k].cross(poly[(k+1)%poly.size()])
					area += absf(sum)*0.5
				if area<0.0001: continue
				var key: String = left.id+" | "+right.id+" @ "+plane
				pairs[key]=float(pairs.get(key,0.0))+area
	var keys:=pairs.keys()
	keys.sort_custom(func(a,b): return pairs[a]>pairs[b])
	for key in keys.slice(0,40): print("COPLANAR ",pairs[key]," ",key)
