extends GutTest

func test_streamed_fire_props_get_one_effect_per_complete_placement() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := EnvironmentCommitQueue.new(cache,&"Visuals")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	var boxes: Array[AABB] = []
	for id: StringName in [&"sfbp.campfire.001",&"suntail.prop.bonfire"]:
		for turn in 2:
			var pose := Transform3D(Basis(Vector3.UP,turn*PI/2)*1.7,
				Vector3(boxes.size()*10,2,-7))
			payload.add(id,pose,Color.WHITE)
			boxes.append(pose*cache.descriptor(id).measured_aabb)
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,parent,payload)
	queue.drain(100)
	var fires := parent.find_children("*","GPUParticles3D",true,false)
	assert_eq(fires.size(),4,"multi-piece cooking rigs must not multiply effects")
	assert_eq(parent.find_children("*","OmniLight3D",true,false).size(),4)
	for fire: GPUParticles3D in fires:
		var attached := false
		for box: AABB in boxes: attached = attached or box.has_point(fire.global_position)
		assert_true(attached,"the flame base remains inside the placed log/rig envelope")
		assert_true(fire.local_coords,"scaled/rotated props retain their fire")
		assert_gt(fire.visibility_range_end,0.0,"distant emitters have a finite drawing range")
		assert_false(fire.draw_pass_1 == null)

func test_retired_streaming_work_never_creates_fire_effects() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := EnvironmentCommitQueue.new(cache,&"Visuals")
	var parent := Node3D.new()
	add_child_autofree(parent)
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"sfbp.campfire.001",Transform3D.IDENTITY,Color.WHITE)
	queue.register_chunk(Vector2i.ZERO,1)
	queue.enqueue(Vector2i.ZERO,1,parent,payload)
	queue.invalidate_chunk(Vector2i.ZERO)
	assert_eq(queue.drain(100),0)
	assert_eq(parent.get_child_count(),0,"no orphan particles/lights after a cancelled chunk")


func test_completed_fire_effects_retire_and_reenter_with_the_chunk() -> void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	var queue := EnvironmentCommitQueue.new(cache,&"Visuals")
	var payload := EnvironmentInstancePayload.new()
	payload.add(&"sfbp.campfire.001",Transform3D.IDENTITY,Color.WHITE,&"same-camp")
	for generation in range(1,4):
		var owner := Node3D.new()
		add_child(owner)
		queue.register_chunk(Vector2i.ZERO,generation)
		queue.enqueue(Vector2i.ZERO,generation,owner,payload)
		queue.drain(100)
		var fires := owner.find_children("*","GPUParticles3D",true,false)
		var lights := owner.find_children("*","OmniLight3D",true,false)
		assert_eq(fires.size(),1,"reentering the same camp creates exactly one effect")
		assert_eq(lights.size(),1)
		queue.invalidate_chunk(Vector2i.ZERO)
		owner.queue_free()
		await get_tree().process_frame
		for fire in fires:
			assert_false(is_instance_valid(fire),"the retired chunk owns the particle lifetime")
		for light in lights:
			assert_false(is_instance_valid(light),"no orphan light survives chunk retirement")
