extends GutTest
const PAINT := preload("res://scripts/terrain/features/villages/TownStreetPaint.gd")

func _painted(shapes: Array[FeatureGroundShape], point: Vector2) -> bool:
	for shape: FeatureGroundShape in shapes:
		if shape.contains(point): return true
	return false

func test_exposed_corners_leave_green_but_street_centres_and_thresholds_remain() -> void:
	var shapes := PAINT.shapes([Vector3i.ZERO],Transform3D.IDENTITY,&"test")
	assert_false(_painted(shapes,Vector2(0.74,0.74)),"the square outside corner becomes green")
	for point: Vector2 in [Vector2.ZERO,Vector2(0.74,0),Vector2(-0.74,0),
			Vector2(0,0.74),Vector2(0,-0.74)]:
		assert_true(_painted(shapes,point),"full width remains at an approached edge")
	assert_false(_painted(shapes,Vector2(0.8,0)),"paint stays inside its public footprint")

func test_shared_edges_and_interior_junctions_do_not_get_round_holes() -> void:
	var cells: Array[Vector3i] = [Vector3i.ZERO,Vector3i.RIGHT,Vector3i.BACK,Vector3i(1,0,1)]
	var shapes := PAINT.shapes(cells,Transform3D.IDENTITY,&"test")
	for z in range(0,31):
		for x in range(0,31):
			assert_true(_painted(shapes,Vector2(x,z)*0.05),"interior is continuously painted")
	assert_false(_painted(shapes,Vector2(2.24,2.24)),"only the union's outside corner is rounded")

func test_rotation_and_scale_preserve_the_same_boundary() -> void:
	var frame := Transform3D(Basis(Vector3.UP,0.71).scaled(Vector3(3,2,3)),Vector3(27,9,-13))
	var shapes := PAINT.shapes([Vector3i.ZERO],frame,&"rotated")
	for point: Vector3 in [Vector3.ZERO,Vector3(0.74,0,0),Vector3(0,0,-0.74)]:
		var p := frame*point
		assert_true(_painted(shapes,Vector2(p.x,p.z)))
	var corner := frame*Vector3(0.74,0,0.74)
	assert_false(_painted(shapes,Vector2(corner.x,corner.z)))

func test_native_street_skin_matches_the_paint_and_keeps_upward_faces() -> void:
	var cells: Array[Vector3i] = [Vector3i.ZERO,Vector3i.RIGHT,Vector3i.BACK]
	var shapes := PAINT.shapes(cells,Transform3D.IDENTITY,&"test")
	var mesh := PAINT.mesh(cells)
	for i in range(0,mesh.indices.size(),3):
		var a: Vector3 = mesh.vertices[mesh.indices[i]]
		var b: Vector3 = mesh.vertices[mesh.indices[i+1]]
		var c: Vector3 = mesh.vertices[mesh.indices[i+2]]
		var centre := (a+b+c)/3.0
		assert_true(_painted(shapes,Vector2(centre.x,centre.z)))
		assert_lt((b-a).cross(c-a).y,0.0,"Godot clockwise front face, with upward lighting normals")
	assert_eq(mesh.vertices.size(),mesh.normals.size())
	assert_eq(mesh.vertices.size(),mesh.uvs.size())

func test_inside_bends_round_without_filling_the_green_square() -> void:
	for sx in [-1,1]:
		for sz in [-1,1]:
			var cells: Array[Vector3i] = [Vector3i.ZERO,Vector3i(sx,0,0),Vector3i(0,0,sz)]
			var shapes := PAINT.shapes(cells,Transform3D.IDENTITY,&"bend")
			assert_true(_painted(shapes,Vector2(sx*0.82,sz*0.82)),"the concave notch gets a tangent fillet")
			assert_false(_painted(shapes,Vector2(sx*1.2,sz*1.2)),"the interior green remains open")
			var mesh := PAINT.mesh(cells)
			for i in range(0,mesh.indices.size(),3):
				var a: Vector3 = mesh.vertices[mesh.indices[i]]
				var b: Vector3 = mesh.vertices[mesh.indices[i+1]]
				var c: Vector3 = mesh.vertices[mesh.indices[i+2]]
				assert_lt((b-a).cross(c-a).y,0.0)

func test_polygon_clearance_checks_concave_boundary_and_all_primitive_pairs() -> void:
	var shapes := PAINT.shapes([Vector3i.ZERO,Vector3i.RIGHT,Vector3i.BACK],Transform3D.IDENTITY,&"bend")
	var fillet: FeatureGroundShape = shapes[-1]
	for other: FeatureGroundShape in [FeatureGroundShape.circle(Vector2(.82,.82),.01),
			FeatureGroundShape.capsule(Vector2(.8,.8),Vector2(.85,.85),.01),
			FeatureGroundShape.oriented_rect(Vector2(.82,.82),Vector2(.01,.02),.7),
			FeatureGroundShape.polygon(PackedVector2Array([Vector2(.8,.8),Vector2(.85,.8),Vector2(.8,.85)]))]:
		assert_true(fillet.intersects(other))
		assert_true(other.intersects(fillet))
	var green := FeatureGroundShape.circle(Vector2(1.2,1.2),.02)
	assert_false(fillet.intersects(green))
	assert_false(green.intersects(fillet))
	assert_true(fillet.bounds().has_point(Vector2(.82,.82)))
	assert_lt(fillet.signed_distance(Vector2(.82,.82)),0.0)
	assert_gt(fillet.signed_distance(Vector2(1.2,1.2)),0.0)

func test_retained_street_fillets_keep_the_walk_datum() -> void:
	var mesh := PAINT.mesh([Vector3i(0,4,0),Vector3i(1,4,0),Vector3i(0,4,1)])
	for vertex: Vector3 in mesh.vertices:
		assert_almost_eq(vertex.y,6.025,.0001)
