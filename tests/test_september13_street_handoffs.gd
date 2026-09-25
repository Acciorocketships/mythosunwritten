extends GutTest

func _spec() -> Dictionary:
	var cells: Array[Vector3i] = [Vector3i.ZERO,Vector3i.BACK]
	return {"cells":cells,"outward":Vector3i.RIGHT,"lateral":Vector3i.BACK,"ground_band":0,"stable_suffix":&"gate"}

func test_unused_level_exit_does_not_paint_a_detached_spur() -> void:
	for quarter in 4:
		var urban := VillageUrbanFabricPlan.new()
		urban.world_transform=Transform3D(VillageWorldScale.production_basis(quarter*PI*.5),Vector3.ZERO)
		var specs: Array[Dictionary] = [_spec()]
		VillageWarrenFabricSolver._append_terrain_handoffs(urban,specs,&"test")
		VillageWarrenFabricSolver._append_terrain_handoff_paint(urban,specs,[],&"test")
		assert_eq(urban.surfaces.size(),0,"An exit into open ground ends at the public street boundary")
		assert_false(urban.clearances.is_empty(),"The exit retains its walkable approach")

func test_a_real_road_keeps_its_entire_continuous_gate_connection() -> void:
	for quarter in 4:
		var urban := VillageUrbanFabricPlan.new()
		urban.world_transform=Transform3D(VillageWorldScale.production_basis(quarter*PI*.5),Vector3(80,12,-40))
		var spec := _spec()
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		var a: Vector3 = urban.world_transform * geometry.inner_centre
		var b: Vector3 = urban.world_transform * geometry.outer_centre
		var endpoint := Vector2(b.x,b.z)
		var points: Array[Vector2] = [endpoint+Vector2(b.x-a.x,b.z-a.z)*4,endpoint]
		var paths: Array[Dictionary] = [{"points":points,"owner":&"actual-road"}]
		var specs: Array[Dictionary] = [spec]
		VillageWarrenFabricSolver._append_terrain_handoffs(urban,specs,&"test")
		VillageWarrenFabricSolver._append_terrain_handoff_paint(urban,specs,paths,&"test")
		var field := FeatureGroundField.new(urban.surfaces,[],0)
		for step in 11:
			var point := a.lerp(b,float(step)/10)
			assert_eq(field.surface_at(Vector2(point.x,point.z)),FeatureGroundField.WORN_PATH)

func test_raised_exit_keeps_its_built_stair_approach_without_a_road() -> void:
	var urban := VillageUrbanFabricPlan.new()
	urban.world_transform=Transform3D(VillageWorldScale.production_basis(0),Vector3.ZERO)
	var spec := _spec()
	spec.ground_band=-1
	var specs: Array[Dictionary] = [spec]
	VillageWarrenFabricSolver._append_terrain_handoffs(urban,specs,&"test")
	VillageWarrenFabricSolver._append_terrain_handoff_paint(urban,specs,[],&"test")
	assert_eq(urban.surfaces.size(),1)
	assert_eq(urban.entrance_stair_count,1)
	assert_false(urban.surface_meshes.is_empty())
