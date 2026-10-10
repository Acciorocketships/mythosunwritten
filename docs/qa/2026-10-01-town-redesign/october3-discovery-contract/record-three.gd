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
	for seed_value in [3]:
		var plan := VillagePlan.new(seed_value,program)
		var record := plan.record_for(frame)
		var town := record.urban_fabric
		print("CHECKS sealed=",town.volumetric_spatial.is_sealed()," sig=",String(town.fabric_audit.get("spatial_signature",""))==town.volumetric_spatial.deterministic_signature().sha256_text()," unfloored=",town.fabric_audit.get("rejected_unfloored_address_count",-1)," contract=",town._scale_feature_contract_matches(town.fabric_audit)," compiled=",town._validate_compiled_fabric(program)," audit_match=",town._fabric_audit_matches_plan())
		print("PLAN valid=",town.fabric_plan.validate()," rejection=",town.fabric_plan.last_rejection," sealed=",town.fabric_plan.is_sealed()," xf=",town.world_transform.is_finite()," entries=",town.entries.size()," volumes=",town.volumes.size()," clearances=",town.clearances.size())
		for mesh: Dictionary in town.surface_meshes:
			if not EnvironmentInstancePayload._surface_mesh_is_valid(mesh): print("BAD MESH ",mesh.get("stable_id","?"))
		for box: Dictionary in town.collision_boxes:
			var t: Transform3D = box.get("transform",Transform3D())
			var size: Vector3 = box.get("size",Vector3.ZERO)
			if not t.is_finite() or not size.is_finite() or size.x<=0 or size.y<=0 or size.z<=0: print("BAD BOX ",box)
		var roles := {}
		for v: VillageOccupancyVolume in town.volumes: roles[v.role]=true
		print("ROLES ",roles," guards=",town.fabric_plan.surface_plan.guard_segments.size())
		var fp := town.fabric_plan
		var left := fp.unit(&"spatial.fabric.spatial.feature.market.00.component.00")
		var right := fp.unit(&"spatial.fabric.spatial.parcel.maze.bridge.01.end.0.lower.part00.room00/ground-frame/2/0")
		var lr := fp.recipe(left.recipe_id)
		var rr := fp.recipe(right.recipe_id)
		for i in lr.placements.size():
			if left.suppressed_placement_ids.has(StringName(lr.placements[i].id)): continue
			for j in rr.placements.size():
				var a: AABB = left.transform()*lr.placement_bounds[i]
				var b: AABB = right.transform()*rr.placement_bounds[j]
				if SettlementFabricPlan._aabb_overlaps_volume(a,b): print("OVERLAP ",lr.placements[i]," BOX ",a," POST ",b," INTERSECTION ",a.intersection(b))
		var inspection := SettlementFabricSolver.audit_plan(town.fabric_plan,town.fabric_audit)
		for key in ["walk_surface_component_count","stair_endpoint_gap_count","stair_endpoint_missing_landing_count","stair_to_stair_edge_count","unserved_entrance_count"]: print("INSPECT ",key,"=",inspection.get(key,-1))
		print("LIFT ",town.terrain_entrance_lift_m," RELIEF ",town.terrain_relief_m," BUILDINGS ",town.buildings.size()," / ",town.fabric_audit.get("building_stack_count",-1))
		var missing := {}
		for entry: Dictionary in record.urban_fabric.entries:
			if not program.referenced_asset_ids.has(StringName(entry.asset_id)): missing[entry.asset_id]=true
		print("GRADE ",record.urban_fabric.terrain_grade.bounds," without_grade=",VillagePlan._record_bounds(record.centre,record.payload,record.surface_shapes,record.clearance_shapes,record.occupancy,program))
		print("MISSING ",seed_value," ",missing.keys())
		var permitted := program.record_bound(record.centre).grow(TerrainGradePatch.NATIVE_CONTROL_MARGIN+0.001)
		print("RECORD ",seed_value," valid=",record.validate(program)," payload=",record.payload.validate()," bounds=",record.bounds," permitted=",permitted," enclosed=",permitted.encloses(record.bounds)," urban=",record.urban_fabric.validate(program,record.tier)," accepted=",record.urban_fabric.accepted," reason=",record.urban_fabric.reason)
	quit()
