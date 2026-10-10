extends SceneTree
func _initialize() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var heights: Dictionary = {}
	for z in range(-24,25):
		for x in range(-24,25): heights[Vector2i(x,z)] = 0
	var region := HeightfieldRegion.new(heights,heights)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region = region
	water._coverage = Rect2(-576,-576,1152,1152)
	var frame := VillageFrame.from_mask({"id":&"hamlet.production","cell":Vector2i.ZERO},
		0,region,water)
	var rows := []
	for seed_value in range(1,17):
		var plan := VillagePlan.new(seed_value,program)
		var record := plan.record_for(frame)
		var geometry := AABB()
		var initialized := false
		for entry: Dictionary in record.urban_fabric.entries:
			var box: AABB = entry.transform * program.runtime_aabbs[entry.asset_id]
			geometry = geometry.merge(box) if initialized else box
			initialized = true
		for mesh: Dictionary in record.payload.surface_meshes:
			for vertex: Vector3 in mesh.vertices: geometry = geometry.expand(vertex)
		var worst_halo := 0
		for x in range(0,192,24):
			for z in range(0,192,24):
				for corner: Vector2 in [Vector2(geometry.position.x,geometry.position.z),Vector2(geometry.end.x,geometry.end.z)]:
					var key := WorldFieldBlockCache.key_of(corner+Vector2(x,z))
					worst_halo = maxi(worst_halo,maxi(absi(key.x),absi(key.y)))
		var row := {"world_seed":seed_value,"valid":record.validate(program),"geometry":str(geometry),"required_halo":worst_halo,"declared_halo":program.geometry_halo,"discovery_radius":record.discovery_bound.size.x*0.5}
		rows.append(row)
		print("OWNER_REACH ",JSON.stringify(row))
	FileAccess.open("/tmp/october3-owner-reach-fixed.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
