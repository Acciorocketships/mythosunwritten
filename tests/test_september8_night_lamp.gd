extends GutTest

func test_photographed_lamp_base_meets_final_town_ground() -> void:
	var seed_value := 2697992464
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value,water)
	var fields := WorldFieldBlockCache.new(heights,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value,water,fields,program,SettlementPlan.new(seed_value,water))
	var context := world.context_for(WorldFieldBlockCache.key_of(Vector2(357.2,433.7)))
	var path_payload := world.path_plan().context_for(WorldFieldBlockCache.key_of(Vector2(357.2,433.7))).placements()
	var raw_batch: Dictionary = path_payload.batches.get(&"sfv.light_pole.001",{})
	var final_batch: Dictionary = context.placements().batches.get(&"sfv.light_pole.001",{})
	assert_false(raw_batch.is_empty(),"the photographed block contains path lamps")
	var checked := 0
	for index in raw_batch.get("transforms",[]).size():
		var original: Transform3D = raw_batch.transforms[index]
		var anchor := Vector2(original.origin.x,original.origin.z)
		if anchor.distance_to(Vector2(357.2,433.7))>20:continue
		var final_index: int = final_batch.ids.find(raw_batch.ids[index])
		assert_gte(final_index,0,"grading preserves the lamp identity")
		var seated: Transform3D = final_batch.transforms[final_index]
		var surface := TerrainSurfaceField.surface_y(context.graded_region(fields.region_at(anchor)),anchor.x,anchor.y)
		print("LAMP_GROUND ",original.origin," final=",seated.origin," surface=",surface)
		assert_almost_eq(seated.origin.y,surface,0.01,"lamp base must meet final graded terrain")
		assert_eq(seated.basis,original.basis,"authored size and orientation are preserved")
		assert_eq(Vector2(seated.origin.x,seated.origin.z),anchor,"the reserved footprint is preserved")
		checked+=1
	assert_gt(checked,0,"the lamp near the photo is exercised")

func test_ground_attachment_preserves_reservations_and_structural_props() -> void:
	for yaw in [0.0,PI/2,PI,3*PI/2]:
		for final_height in [-3.0,6.0]:
			var payload := EnvironmentInstancePayload.new()
			var original := Transform3D(Basis(Vector3.UP,yaw),Vector3(3,2,5))
			payload.add(&"ground_prop",original,Color.WHITE,&"stable-ground")
			payload.add(&"structural_prop",original,Color.WHITE,&"stable-structural")
			var contact := Vector3(.2,.3,.4)
			WorldFeaturePlan._seat_ground_assets(payload,{&"ground_prop":{"ground_contact":contact}},func(_point:Vector2)->float:return final_height)
			var actual: Transform3D = payload.batches[&"ground_prop"].transforms[0]
			assert_almost_eq((actual*contact).y,final_height,.00001)
			assert_eq(actual.basis,original.basis)
			assert_eq(Vector2(actual.origin.x,actual.origin.z),Vector2(3,5))
			assert_eq(payload.batches[&"ground_prop"].ids,[&"stable-ground"])
			assert_eq(payload.batches[&"structural_prop"].transforms[0],original,"structural attachments retain their own datum")
			var first := actual
			WorldFeaturePlan._seat_ground_assets(payload,{&"ground_prop":{"ground_contact":contact}},func(_point:Vector2)->float:return final_height)
			assert_eq(payload.batches[&"ground_prop"].transforms[0],first,"resolving the same datum twice is stable")
