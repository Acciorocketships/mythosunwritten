extends GutTest

func test_world_road_boundary_handoffs_rotate_and_preserve_exterior_roads() -> void:
	for quarter in 4:
		var angle := quarter*PI*0.5
		var axis := Vector2.RIGHT.rotated(angle).round()
		var domain := FeatureGroundShape.oriented_rect(Vector2.ZERO,Vector2(15,21),angle,FeatureGroundField.NATURAL,VillagePlan.SURFACE_PRIORITY-1,&"domain")
		var masks: Dictionary = {}
		for x in range(-2,3):
			masks[Vector2i((Vector2(x,0).rotated(angle)).round())] = 3 if quarter%2==0 else 12
		var ground := FeatureGroundField.new([],[],4.5,masks)
		var routes := VillageOutskirtsConstruction._world_road_handoffs(domain,ground,&"rotated")
		assert_eq(routes.size(),2,"each crossing publishes one boundary handoff")
		var shapes: Array[FeatureGroundShape] = [domain]
		for route: Dictionary in routes:
			assert_almost_eq(domain.signed_distance(route.points[0]),0.0,0.001)
			assert_gt(domain.signed_distance(route.points[1]),0.0)
			shapes.append_array(PathProgram.filleted_path_shapes(route.points,2,FeatureGroundField.WORN_PATH,VillagePlan.SURFACE_PRIORITY,&"handoff"))
		var composed := ground.extended(shapes,[])
		assert_eq(composed.surface_at(Vector2.ZERO),FeatureGroundField.NATURAL,"the country route does not cross the town interior")
		for sign_value in [-1,1]:
			for distance in range(15,43):
				assert_eq(composed.surface_at(axis*distance*sign_value),FeatureGroundField.WORN_PATH,"continuous exterior road to the circuit")
		assert_eq(ground.surface_at(Vector2.ZERO),FeatureGroundField.WORN_PATH,"source road field remains immutable")
