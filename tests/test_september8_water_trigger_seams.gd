extends GutTest

func test_real_physics_queries_cover_shared_water_tile_faces_and_corners() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD])
	var triggers: Array = []
	for z in [-240.0,-216.0]:
		for x in [-552.0,-528.0]:
			triggers.append({"rect":Rect2(x,z,24,24),"top":2.0,"bottom":-2.0})
	var water := WaterSurfaceBuilder.new().commit_chunk({"arrays":arrays,
		"triggers":triggers,"sampler":WaterSampler.new()})
	add_child_autofree(water)
	for tick in 3: await get_tree().physics_frame
	for z in [-228.0,-216.01,-216.0,-215.99]:
		for x in [-528.01,-528.0,-527.99]:
			var query := PhysicsPointQueryParameters3D.new()
			query.position=Vector3(x,0.3,z)
			query.collide_with_areas=true
			query.collide_with_bodies=false
			query.collision_mask=128
			assert_gt(water.get_world_3d().direct_space_state.intersect_point(query,4).size(),0,
				"a live water query must not fall between boxes at %s" % query.position)
