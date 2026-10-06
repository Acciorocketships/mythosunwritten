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
	for seed_value in [1]:
		var plan := VillagePlan.new(seed_value,program)
		var record := plan.record_for(frame)
		var missing := {}
		for entry: Dictionary in record.urban_fabric.entries:
			if not program.referenced_asset_ids.has(StringName(entry.asset_id)): missing[entry.asset_id]=true
		print("GRADE ",record.urban_fabric.terrain_grade.bounds," without_grade=",VillagePlan._record_bounds(record.centre,record.payload,record.surface_shapes,record.clearance_shapes,record.occupancy,program))
		print("MISSING ",seed_value," ",missing.keys())
		var permitted := program.record_bound(record.centre).grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN+0.001)
		print("RECORD ",seed_value," valid=",record.validate(program)," payload=",record.payload.validate()," bounds=",record.bounds," permitted=",permitted," enclosed=",permitted.encloses(record.bounds)," urban=",record.urban_fabric.validate(program,record.tier)," accepted=",record.urban_fabric.accepted," reason=",record.urban_fabric.reason)
	quit()
