extends GutTest
const ARCHIVE := preload("res://scripts/terrain/field/TerrainCollisionArchive.gd")

func test_generated_collision_round_trips_exactly_and_releases_its_shape() -> void:
	var node := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array([Vector3(-12.375,4.125,2.5),Vector3(8,4.5,3),Vector3(0,4,-7)])
	shape.set_faces(faces)
	shape.custom_solver_bias = .37
	shape.resource_name = "review_ground"
	shape.resource_local_to_scene = true
	shape.margin = .123
	shape.backface_collision = true
	var weak := weakref(shape)
	node.shape = shape
	node.position = Vector3(123,45,-67)
	node.disabled = true
	node.set_meta(&"terrain_faces",faces)
	shape = null
	var archive := ARCHIVE.new()
	assert_true(archive.suspend(node))
	assert_null(node.shape)
	assert_null(weak.get_ref(),"no strong reference keeps the expensive physics shape alive")
	assert_false(archive.suspend(node),"a suspended node is not archived twice")
	assert_eq(archive.pending(),1)
	assert_true(archive.restore_one())
	assert_eq(node.shape.get_faces(),faces)
	assert_almost_eq(node.shape.margin,.123,.000001)
	assert_almost_eq(node.shape.custom_solver_bias,.37,.000001)
	assert_eq(node.shape.resource_name,"review_ground")
	assert_true(node.shape.resource_local_to_scene)
	assert_true(node.shape.backface_collision)
	assert_true(node.disabled)
	assert_eq(node.position,Vector3(123,45,-67))
	assert_eq(node.get_meta(&"terrain_faces"),faces)
	assert_eq(archive.pending(),0)
	assert_eq(archive.compressed_bytes,0)
	node.free()

func test_retired_nodes_are_not_kept_alive_or_recreated() -> void:
	var node := CollisionShape3D.new()
	node.shape = ConcavePolygonShape3D.new()
	node.shape.set_faces(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK]))
	var archive := ARCHIVE.new()
	assert_true(archive.suspend(node))
	node.free()
	assert_true(archive.restore_one())
	assert_eq(archive.pending(),0)

func test_scripted_shapes_keep_their_custom_behavior() -> void:
	var node := CollisionShape3D.new()
	node.shape = ConcavePolygonShape3D.new()
	var script := GDScript.new()
	script.source_code = "extends ConcavePolygonShape3D\nvar special_contact_rule := true\n"
	assert_eq(script.reload(),OK)
	node.shape.set_script(script)
	var archive := ARCHIVE.new()
	assert_false(archive.suspend(node),"a custom resource must not be replaced by a plain shape")
	assert_true(node.shape != null)
	assert_eq(archive.pending(),0)
	node.free()
