extends GutTest

func test_market_and_bridge_house_keep_complete_nonintersecting_supports() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({},catalog)
	var heights := {}
	for z in range(-24,25):
		for x in range(-24,25): heights[Vector2i(x,z)] = 0
	var region := HeightfieldRegion.new(heights,heights)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region = region
	water._coverage = Rect2(-576,-576,1152,1152)
	var frame := VillageFrame.from_mask({"id":&"hamlet.production","cell":Vector2i.ZERO},0,region,water)
	var record := VillagePlan.new(3,program).record_for(frame)
	assert_true(record.validate(program),"market and complete bearing frames satisfy the unchanged validator")
	var plan := record.urban_fabric.fabric_plan
	var market := plan.unit(&"spatial.fabric.spatial.feature.market.00.component.00")
	assert_not_null(market)
	assert_false(market.suppressed_placement_ids.has(&"canopy"),"the stocked stall retains its whole canopy")
	var endpoint := "spatial.fabric.spatial.parcel.maze.bridge.01.end.0.lower.part00.room00"
	var native_ids := {}
	for entry: Dictionary in record.urban_fabric.entries: native_ids[String(entry.stable_id)] = entry
	var columns := {}
	var courses := {}
	var payload := EnvironmentInstancePayload.new()
	var inverse := record.urban_fabric.world_transform.affine_inverse()
	for entry: Dictionary in record.urban_fabric.entries:
		payload.add(entry.asset_id,inverse*(entry.transform as Transform3D),Color.WHITE,entry.stable_id,true)
	for unit: FabricUnit in plan.units:
		if not String(unit.stable_id).begins_with(endpoint+"/ground-frame/"): continue
		var native_found := false
		var native_bounds := AABB()
		for native_id: String in native_ids:
			if native_id.ends_with("/"+String(unit.stable_id)+"/post") or native_id.contains("/"+String(unit.stable_id)+"/post/tile"):
				var entry: Dictionary = native_ids[native_id]
				var piece_bounds: AABB = inverse*(entry.transform as Transform3D)*catalog.descriptor(entry.asset_id).measured_aabb
				native_bounds = native_bounds.merge(piece_bounds) if native_found else piece_bounds
				native_found = true
		assert_true(native_found,"the production kit retains each complete support course")
		var key := String(unit.stable_id).get_slice("/",2)
		if not courses.has(key): courses[key] = []
		courses[key].append(unit)
		columns[key] = (columns[key] as AABB).merge(native_bounds) if columns.has(key) else native_bounds
		var recipe := plan.recipe(unit.recipe_id)
		assert_false(plan._continuous_roof_bounds_enter_public_route(unit.bounds))
		assert_false(SettlementFabricPlan._visual_placements_overlap(unit,recipe,market,plan.recipe(market.recipe_id)))
	for key: String in columns:
		var shaft: AABB = columns[key]
		var members: Array = courses[key]
		members.sort_custom(func(a: FabricUnit,b: FabricUnit) -> bool: return a.bounds.position.y<b.bounds.position.y)
		for i in members.size():
			assert_eq(members[i].yaw_quarters,members[0].yaw_quarters,"a whole column stays vertically aligned")
			if i>0: assert_almost_eq(members[i-1].bounds.end.y,members[i].bounds.position.y,.002,"successive post courses meet")
		var center := shaft.get_center()
		var contacts := [shaft.position.y<=0.0,false]
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			for index in batch.ids.size():
				if String(batch.ids[index]).contains("/ground-frame/"): continue
				var pose: Transform3D = batch.transforms[index]
				var bounds := pose * catalog.descriptor(asset).measured_aabb
				if center.x<bounds.position.x or center.x>bounds.end.x or center.z<bounds.position.z or center.z>bounds.end.z: continue
				var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
				for piece: EnvironmentVisualPiece in visual.pieces:
					var faces := pose*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh)
					for sample in 2:
						var point := Vector3(center.x,shaft.position.y if sample==0 else shaft.end.y,center.z)
						for face in range(0,faces.size(),3):
							if Geometry3D.segment_intersects_triangle(point+Vector3.DOWN*(.002 if sample==0 else .2),point+Vector3.UP*(.17 if sample==0 else .002),faces[face],faces[face+1],faces[face+2])!=null: contacts[sample]=true
		assert_true(contacts[0],"post reaches a real lower bearing")
		assert_true(contacts[1],"post meets the actual upper floor")
	assert_eq(columns.size(),4,"the bridge-house keeps all four support columns")
