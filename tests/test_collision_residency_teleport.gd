extends GutTest
const RESIDENCY := preload("res://scripts/terrain/field/TerrainCollisionResidency.gd")
const ACTORS := preload("res://scripts/terrain/field/TerrainCollisionActors.gd")

func test_teleported_character_waits_for_restored_ground_then_collides() -> void:
	var root := Node3D.new()
	var body := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([Vector3.ZERO,Vector3(192,0,0),Vector3(0,0,192),
		Vector3(192,0,0),Vector3(192,0,192),Vector3(0,0,192)]))
	shape.backface_collision = true
	shape_node.shape = shape
	body.add_child(shape_node)
	root.add_child(body)
	add_child(root)
	var actor := CharacterBody3D.new()
	var actor_shape := CollisionShape3D.new()
	actor_shape.shape = SphereShape3D.new()
	actor_shape.shape.radius = .5
	actor.add_child(actor_shape)
	add_child(actor)
	actor.global_position = Vector3(800,2,96)
	var residency := RESIDENCY.new()
	residency.register_chunk(Vector2i.ZERO,root)
	var actors := ACTORS.new()
	actors.start(get_tree())
	residency.update_interests(actors.interests())
	residency.drain(1000000)
	assert_null(shape_node.shape)
	actor.global_position = Vector3(96,2,96)
	residency.update_interests(actors.interests())
	var ready := func(_position:Vector3)->bool:return residency.is_ready(Vector2i.ZERO)
	actors.guard_except(null,ready)
	assert_eq(actor.process_mode,Node.PROCESS_MODE_DISABLED)
	residency.drain(1000000)
	actors.guard_except(null,ready)
	assert_eq(actor.process_mode,Node.PROCESS_MODE_DISABLED,"restoration alone does not bypass registration")
	await get_tree().physics_frame
	await get_tree().physics_frame
	actors.guard_except(null,ready)
	assert_eq(actor.process_mode,Node.PROCESS_MODE_INHERIT)
	await get_tree().physics_frame
	var hit := actor.move_and_collide(Vector3.DOWN*3.0)
	assert_not_null(hit,"restored terrain supports the released character")
	if hit != null: assert_same(hit.get_collider(),body)
	assert_gt(actor.global_position.y,.49)
	actors.stop()
	actor.free()
	root.free()
