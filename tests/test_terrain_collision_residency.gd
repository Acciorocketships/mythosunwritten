extends GutTest
const RESIDENCY := preload("res://scripts/terrain/field/TerrainCollisionResidency.gd")

func _chunk(count := 2) -> Node3D:
	var root := Node3D.new()
	for i in count:
		var node := CollisionShape3D.new()
		node.shape = ConcavePolygonShape3D.new()
		node.shape.set_faces(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK]))
		root.add_child(node)
	return root

func test_near_actor_and_prediction_keep_collision_resident() -> void:
	var root := _chunk()
	var residency := RESIDENCY.new()
	residency.register_chunk(Vector2i.ZERO,root)
	# Actor 1 is far away; actor 2's prediction approaches this chunk.
	residency.update_interests(PackedVector3Array([Vector3(2000,0,2000),Vector3(100,0,100)]))
	residency.drain(1000000)
	assert_not_null(root.get_child(0).shape)
	assert_eq(residency._entries[Vector2i.ZERO].archive.pending(),0)
	root.free()

func test_hysteresis_restore_budget_and_physics_registration() -> void:
	var root := _chunk(3)
	var residency := RESIDENCY.new()
	residency.register_chunk(Vector2i.ZERO,root)
	residency.update_interests(PackedVector3Array([Vector3(600,0,100)]))
	assert_eq(residency.drain(1000000,1),1)
	assert_false(residency.is_ready(Vector2i.ZERO))
	residency.drain(1000000)
	assert_eq(residency._entries[Vector2i.ZERO].archive.pending(),3)
	residency.update_interests(PackedVector3Array([Vector3(500,0,100)]))
	residency.drain(1000000)
	assert_eq(residency._entries[Vector2i.ZERO].archive.pending(),3,"stay suspended inside the hysteresis band")
	residency.update_interests(PackedVector3Array([Vector3(400,0,100)]))
	assert_eq(residency.drain(1000000,1),1)
	assert_false(residency.is_ready(Vector2i.ZERO),"partial restore cannot release an arrival")
	residency.drain(1000000)
	assert_false(residency.is_ready(Vector2i.ZERO),"wait for physics registration")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(residency.is_ready(Vector2i.ZERO))
	for node: Node in root.get_children(): assert_not_null(node.shape)
	root.free()

func test_empty_actor_inventory_restores_and_retirement_drops_ownership() -> void:
	var root := _chunk()
	var residency := RESIDENCY.new()
	residency.register_chunk(Vector2i.ZERO,root)
	residency.update_interests(PackedVector3Array([Vector3(2000,0,2000)]))
	residency.drain(1000000)
	residency.update_interests(PackedVector3Array())
	residency.drain(1000000)
	assert_not_null(root.get_child(0).shape)
	var retired := residency.unregister_chunk(Vector2i.ZERO)
	assert_false(retired.is_empty())
	assert_false(residency.is_ready(Vector2i.ZERO))
	root.free()
	assert_null(retired.root.get_ref())

func test_turning_back_during_suspension_restores_before_more_retirement() -> void:
	var root := _chunk(3)
	var other := _chunk(3)
	var residency := RESIDENCY.new()
	residency.register_chunk(Vector2i.ZERO,root)
	residency.register_chunk(Vector2i(4,0),other)
	residency.update_interests(PackedVector3Array([Vector3(4000,0,0)]))
	residency.drain(1000000,4)
	assert_gt(residency._entries[Vector2i.ZERO].archive.pending(),0)
	residency.update_interests(PackedVector3Array([Vector3(100,0,100)]))
	var prior: int = residency._entries[Vector2i.ZERO].archive.pending()
	residency.drain(1000000,1)
	assert_eq(residency._entries[Vector2i.ZERO].archive.pending(),prior-1,"nearest restoration precedes far suspension")
	residency.drain(1000000)
	for node: Node in root.get_children(): assert_not_null(node.shape)
	# Leave again: the suspension cursor must restart, not skip shapes that
	# were restored after the earlier partial pass.
	residency.update_interests(PackedVector3Array([Vector3(4000,0,0)]))
	residency.drain(1000000)
	assert_eq(residency._entries[Vector2i.ZERO].archive.pending(),3)
	root.free()
	other.free()
