extends GutTest

func test_porch_path_meets_actual_first_step_in_both_themes_and_all_orientations() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({},catalog)
	var spec := program.spec_for_asset(&"sfv.building.interior.blue.006")
	var cache := EnvironmentRenderCache.new(catalog)
	for theme: StringName in [&"blue",&"orange"]:
		var asset := spec.asset_for_theme(theme)
		cache.prepare([asset] as Array[StringName])
		var body := StaticBody3D.new()
		for piece: EnvironmentCollisionPiece in cache.visual(asset).collisions:
			var shape := CollisionShape3D.new()
			shape.shape=piece.shape;shape.transform=piece.local_transform
			body.add_child(shape)
		add_child(body)
		for quarter in 4:
			body.transform=Transform3D(Basis(Vector3.UP,quarter*PI/2).scaled(Vector3.ONE*2),Vector3(200,8,-345))
			for frame in 2: await get_tree().physics_frame
			var end := VillageOutskirtsConstruction._ground_entrance(spec,body.global_transform)
			var outward := spec.world_entrance_outward(body.global_transform)
			var side := Vector2(-outward.y,outward.x)
			for offset in [-1.5,0.0,1.5]:
				var p: Vector2 = end-outward*0.1+side*float(offset)
				var hit := body.get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(Vector3(p.x,9,p.y),Vector3(p.x,7.9,p.y),1))
				assert_false(hit.is_empty(),"The painted approach meets a real porch tread: %s/%d/%s" % [theme,quarter,offset])
				if not hit.is_empty():
					assert_lt((hit.position as Vector3).y-8,0.55,"The first contact remains a walkable step")
		body.queue_free()
		await get_tree().physics_frame
