extends GutTest

func test_both_native_benches_support_the_seat_in_every_orientation() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var assets: Array[StringName] = [SettlementFabricProgram.TERRACE_BENCH, SettlementFabricProgram.TERRACE_BENCH_ALT]
	cache.prepare(assets)
	var stage := Node3D.new()
	add_child_autofree(stage)
	var payload := EnvironmentInstancePayload.new()
	for i in assets.size():
		for yaw in 4:
			var pose := Transform3D(Basis(Vector3.UP, yaw * PI * .5).scaled(Vector3.ONE * 2), Vector3(i*20,0,yaw*10))
			payload.add(assets[i], pose, Color.WHITE, StringName("bench.%d.%d" % [i,yaw]))
	EnvironmentCollisionBuilder.commit(stage, payload, cache, &"BenchTest")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := stage.get_world_3d().direct_space_state
	for i in assets.size():
		for yaw in 4:
			var centre := Vector3(i*20,0,yaw*10)
			var ray := PhysicsRayQueryParameters3D.create(centre+Vector3.UP*2, centre+Vector3.UP*.1)
			var hit := space.intersect_ray(ray)
			assert_false(hit.is_empty(), "%s yaw %d must have a physical seat" % [assets[i],yaw])
			if hit.is_empty():
				continue
			var top := catalog.descriptor(assets[i]).measured_aabb.end.y * 2
			assert_almost_eq(float(hit.position.y), top, .05, "Collision must follow the native seat")

func test_character_cannot_walk_through_city_scale_bench_seats() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var assets: Array[StringName] = [SettlementFabricProgram.TERRACE_BENCH, SettlementFabricProgram.TERRACE_BENCH_ALT]
	cache.prepare(assets)
	var stage := Node3D.new()
	add_child_autofree(stage)
	var payload := EnvironmentInstancePayload.new()
	for i in assets.size():
		payload.add(assets[i], Transform3D(Basis.from_scale(Vector3.ONE*2), Vector3(i*10,0,0)), Color.WHITE, StringName("bench.%d" % i))
	EnvironmentCollisionBuilder.commit(stage, payload, cache, &"BenchWalkTest")
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40,.1,20)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -.05
	stage.add_child(floor_body)
	var bodies: Array[CharacterBody3D] = []
	for i in assets.size():
		var body := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .35
		capsule.height = 1.8
		shape.shape = capsule
		body.add_child(shape)
		stage.add_child(body)
		body.position = Vector3(i*10,.91,2)
		bodies.append(body)
	for step in 80:
		await get_tree().physics_frame
		for body: CharacterBody3D in bodies:
			body.velocity = Vector3(0,-2,-3)
			body.move_and_slide()
	for i in bodies.size():
		assert_gt(bodies[i].position.z, .2, "%s must stop a walking capsule at the seat" % assets[i])
