extends GutTest

func test_reported_house_keeps_a_visible_collidable_open_leaf() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for theme: String in ["blue","orange"]:
		var id := StringName("sfv.building.interior.%s.001" % theme)
		var visual := load(catalog.descriptor(id).visual_path) as EnvironmentVisual
		var body := StaticBody3D.new()
		for piece: EnvironmentCollisionPiece in visual.collisions:
			var shape := CollisionShape3D.new()
			shape.shape=piece.shape;shape.transform=piece.local_transform
			body.add_child(shape)
		add_child(body)
		for frame in 2: await get_tree().physics_frame
		var hit := body.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(0.4,1.5,6.55),Vector3(1.4,1.5,6.55)))
		assert_false(hit.is_empty(),"The native open door is present beside the passage: "+theme)
		var leaf_vertices := 0
		for piece: EnvironmentVisualPiece in visual.pieces:
			for vertex: Vector3 in piece.mesh.get_faces():
				var p := piece.local_transform*vertex
				if p.x>0.65 and p.x<1.1 and p.z>6.3 and p.z<7.2 and p.y>0.55 and p.y<2.7: leaf_vertices+=1
		assert_gt(leaf_vertices,20,"The visible leaf has authored geometry, not only invisible collision")
		for x: float in [-0.1,0.222,0.5]:
			var passage := body.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(Vector3(x,1.5,7.1),Vector3(x,1.5,5.5)))
			assert_true(passage.is_empty(),"Open door preserves passage")
		body.queue_free()
		await get_tree().physics_frame
