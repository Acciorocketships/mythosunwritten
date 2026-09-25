extends GutTest

func test_complete_prefab_neighborhood_does_not_require_an_extra_modular_house() -> void:
	var source:=preload("res://tests/fixtures/frozen_maze_source.gd").read("res://tests/fixtures/september11/landforms/VillageRejectedSource.txt")
	var volume:=WarrenMazeVolumeAdapter.to_volume_plan(source)
	var parcels:=WarrenMazeBlockPartitioner.partition(source,volume)
	assert_not_null(parcels,WarrenMazeBlockPartitioner.last_failure)
	if parcels==null: return
	assert_eq(parcels.parcels.size(),0)
	assert_eq(parcels.audit.maze_assets.size(),3)
	for value:Variant in parcels.audit.values():
		if value is float: assert_true(is_finite(value),"An absent modular denominator has a finite empty census")
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial:=WarrenVolumetricSolver.generate(source.world_seed,{},program,source.scale_profile)
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial!=null:
		assert_eq(spatial.compiled_fabric_cache().audit.spatial_prefab_landmark_building_count,3)
		assert_gt(SettlementFabricAssembler.payload(spatial.compiled_fabric_cache()).instance_count,0)
		assert_true(spatial.has_compiled_room_units(),"An empty modular subset is still a completed compile")
		for feature:WarrenFeatureReservation in spatial.features:
			if feature.kind!=&"prefab_landmark": continue
			assert_true(spatial.support_graph.reaches_terrain(feature.stable_id))
			spatial.support_graph._terrain_roots.erase(feature.stable_id)
			assert_false(spatial.validate_construction(),"A native building cannot bypass the shared bearing graph")
			spatial.support_graph._terrain_roots[feature.stable_id]=true

func test_unowned_native_records_cannot_admit_an_empty_parcel_plan() -> void:
	var source:=preload("res://tests/fixtures/frozen_maze_source.gd").read("res://tests/fixtures/september11/landforms/VillageRejectedSource.txt")
	var volume:=WarrenMazeVolumeAdapter.to_volume_plan(source)
	var empty:=WarrenParcelPlan.new(&"empty",volume)
	assert_false(empty.seal([]))
	var counterfeit:=WarrenParcelPlan.new(&"counterfeit",volume)
	var native:={"id":&"unowned","kind_id":&"anchor.prefab.10"}
	assert_false(counterfeit.seal([],[],[native]))
