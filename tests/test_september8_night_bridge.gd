extends GutTest

func test_bridge_support_tracks_plank_arch_without_bank_lips() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	assert_true(cache.prepare([&"sfv.bridge.001"] as Array[StringName]))
	var visual := cache.visual(&"sfv.bridge.001")
	var stage := Node3D.new()
	add_child_autofree(stage)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"sfv.bridge.001",Transform3D.IDENTITY,Color.WHITE,&"bridge")
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"Bridge")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var faces := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:
		faces.append_array(piece.local_transform*piece.mesh.get_faces())
	var largest_error := 0.0
	var misses := 0
	for x in [-1.8,0.0,1.8]:
		for z in range(-30,31):
			var start := Vector3(x,5,z)
			var physical := get_viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+Vector3.DOWN*10))
			if physical.is_empty():
				misses+=1
				continue
			var visible_y := -INF
			for i in range(0,faces.size(),3):
				var hit = Geometry3D.ray_intersects_triangle(start,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
				if hit != null: visible_y=maxf(visible_y,(hit as Vector3).y)
			if is_finite(visible_y): largest_error=maxf(largest_error,absf(physical.position.y-visible_y))
	assert_eq(misses,0,"every walking lane has continuous support across plank gaps")
	assert_lt(largest_error,0.15,"collision follows the arch within plank relief, rather than a sunken flat floor")
	for z in [-30.0,30.0]:
		var hit := get_viewport().world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,5,z),Vector3(0,-5,z)))
		assert_lt(float(hit.position.y),0.25,"end contact introduces no raised collision lip")
