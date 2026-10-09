extends GutTest

func _payload() -> EnvironmentInstancePayload:
	var payload := EnvironmentInstancePayload.new()
	for i in 70:
		payload.add_collision_box(Transform3D(Basis.IDENTITY, Vector3(i, 0, 0)), Vector3.ONE, StringName("box_%d" % i))
	return payload

func test_abandoning_unstarted_collision_commit_allocates_no_orphan_nodes() -> void:
	var parent := Node3D.new()
	var cache := EnvironmentRenderCache.new(null)
	var payload := _payload()
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var pending := EnvironmentCollisionBuilder.commit_steps(parent, payload, cache, &"Collision")
	assert_eq(pending.count, 70)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)
	pending.clear()
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before)
	parent.free()

func test_started_collision_commit_is_owned_and_keeps_all_shapes_in_order() -> void:
	var parent := Node3D.new()
	var pending := EnvironmentCollisionBuilder.commit_steps(parent, _payload(), EnvironmentRenderCache.new(null), &"Collision")
	pending.steps[0].call()
	var body: StaticBody3D = parent.get_child(0)
	var ref := weakref(body)
	for i in range(1, pending.steps.size()): pending.steps[i].call()
	assert_eq(body.get_child_count(), 70)
	for i in 70:
		assert_eq(body.get_child(i).position, Vector3(i, 0, 0))
	parent.free()
	assert_null(ref.get_ref(), "parent destruction owns the started body even while steps retain their state")
	pending.clear()
