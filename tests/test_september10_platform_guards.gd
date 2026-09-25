extends GutTest

func test_photographed_platform_keeps_guards_beside_the_sloping_roof() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september10-stone-source.txt"), program).compiled_fabric_cache()
	var keys: Dictionary = {}
	for segment: Dictionary in fabric.surface_plan.guard_segments:
		keys[String(segment.stable_key)] = true
	for z in range(2,6):
		assert_true(keys.has("-2:5:%d:-1:0" % z),
			"Photo 5: roof reservation cannot replace the exposed platform guard at z=%d" % z)

func test_photographed_guard_has_baked_collision_in_four_orientations() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fabric := frozen.spatial(frozen.read("res://tests/fixtures/september10-stone-source.txt"), program).compiled_fabric_cache()
	var guards := EnvironmentInstancePayload.new()
	SettlementFabricAssembler._append_guard_instances(guards, fabric.surface_plan.guard_segments)
	var batch: Dictionary = guards.batches[SettlementFabricAssembler.PLANK_RAILING]
	var payload := EnvironmentInstancePayload.new()
	for z in range(2,6):
		var id := StringName("public-guard/-2:5:%d:-1:0" % z)
		var index: int = batch.ids.find(id)
		assert_gte(index, 0)
		if index < 0: continue
		for quarter in 4:
			var rotate := Transform3D(Basis(Vector3.UP,quarter*PI*.5),Vector3(quarter*40,0,0))
			payload.add(SettlementFabricAssembler.PLANK_RAILING,rotate*batch.transforms[index],Color.WHITE,StringName("%s/%d" % [id,quarter]))
	var cache := EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var stage := Node3D.new()
	add_child_autofree(stage)
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"PhotographedGuards")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := stage.get_world_3d().direct_space_state
	for z in range(2,6):
		for quarter in 4:
			var rotate := Transform3D(Basis(Vector3.UP,quarter*PI*.5),Vector3(quarter*40,0,0))
			var center := rotate*Vector3(-3.75,7.525+.7,float(z)*1.5)
			var across := rotate.basis*Vector3.RIGHT*.3
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center-across,center+across))
			assert_false(hit.is_empty(),"The baked barrier must stop a transverse probe in every orientation")
