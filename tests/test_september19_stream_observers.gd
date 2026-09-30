extends GutTest

func test_pending_ground_reports_exact_missing_feature_generations() -> void:
	var stream := FieldTerrainStreamer.new()
	stream._feature_program = FeatureProgram.compile(EnvironmentCatalog.load_default())
	var center := Vector2i(-3,0)
	stream._pending_terrain = [{"chunk":center}]
	stream._built[Vector2i(-2,0)] = true
	var keys := stream._feature_halo_keys(center)
	for key:Vector2i in keys: stream._feature_ready[key] = 0
	stream._feature_generation[keys[0]] = 1
	var before := stream._feature_ready.duplicate(true)
	var state := stream.loading_boundary_snapshot()
	assert_eq(state.loaded_ground,[Vector2i(-2,0)])
	assert_eq(state.waiting_ground[0].missing_features,[keys[0]])
	assert_eq(stream._feature_ready,before,"observation cannot publish feature readiness")
	assert_false(stream._feature_square_ready(center))
	stream.free()

func test_mesh_stage_observer_preserves_the_complete_detached_payload() -> void:
	var plan := HeightfieldPlan.new(7,56.0,12,"mean")
	var region := plan.compute_region(8,8,16)
	var mesher := TerrainChunkMesher.new()
	mesher.prepare_resources()
	var before := mesher.compute_chunk(Vector2i.ZERO,region)
	var stages:Array[StringName]=[]
	mesher.phase_callback = func(_chunk:Vector2i,phase:StringName)->void: stages.append(phase)
	var after := mesher.compute_chunk(Vector2i.ZERO,region)
	assert_eq(stages,[&"terrain_arches",&"cliff_formations"])
	assert_eq(var_to_bytes(before),var_to_bytes(after),"diagnostics must not change geometry, collision, water or grass support")
