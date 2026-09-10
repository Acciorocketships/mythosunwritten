extends GutTest

func test_prefab_approaches_center_on_the_measured_door_leaf_in_every_orientation() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=VillageProgram.compile({},catalog)
	for index in range(1,8):
		var spec:=program.spec_for_asset(StringName("lpfv.building.house.%02d"%index))
		assert_not_null(spec)
		for attachment:VillageAttachedAssetSpec in spec.attachments:
			if attachment.stable_key!=&"closed_door":continue
			for quarter in 4:
				var transform:=Transform3D(Basis(Vector3.UP,quarter*PI/2).scaled(Vector3.ONE*2),Vector3(279,8,-362))
				var leaf:AABB=attachment.world_transform(transform)*catalog.descriptor(attachment.asset_id).measured_aabb
				var door_center:=Vector2(leaf.get_center().x,leaf.get_center().z)
				var outward:=spec.world_entrance_outward(transform)
				var tangent:=Vector2(-outward.y,outward.x)
				assert_almost_eq((spec.world_entrance(transform)-door_center).dot(tangent),0.0,0.005,
					"The street must address the opening center, not the door hinge")

func test_centered_approach_clears_the_actual_prefab_jambs() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=VillageProgram.compile({},catalog)
	var cache:=EnvironmentRenderCache.new(catalog)
	var capsule:=CapsuleShape3D.new()
	capsule.radius=TraversalEnvelope.CAPSULE_RADIUS
	capsule.height=TraversalEnvelope.CAPSULE_HEIGHT
	for index in range(1,8):
		var spec:=program.spec_for_asset(StringName("lpfv.building.house.%02d"%index))
		cache.prepare([spec.asset_id] as Array[StringName])
		var body:=StaticBody3D.new()
		add_child(body)
		body.scale=Vector3.ONE*2
		for piece:EnvironmentCollisionPiece in cache.visual(spec.asset_id).collisions:
			var shape:=CollisionShape3D.new()
			shape.shape=piece.shape
			shape.transform=piece.local_transform
			body.add_child(shape)
		for quarter in 4:
			body.rotation.y=quarter*PI/2
			await get_tree().physics_frame
			await get_tree().physics_frame
			var entrance:=spec.world_entrance(body.global_transform)
			var outward:=spec.world_entrance_outward(body.global_transform)
			var start:=entrance+outward*2
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,Vector3(start.x,0.02+capsule.height/2,start.y))
			query.motion=Vector3(-outward.x,0,-outward.y)*2.2
			var fractions:=get_viewport().world_3d.direct_space_state.cast_motion(query)
			assert_gte(fractions[0],0.999,"The centered path reaches the real jamb opening: %s / %d"%[spec.asset_id,quarter])
		body.queue_free()
		await get_tree().physics_frame
