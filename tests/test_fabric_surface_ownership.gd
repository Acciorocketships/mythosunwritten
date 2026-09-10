extends GutTest

func _square() -> Dictionary:
	var points := [Vector3(0, 3, 0), Vector3(2, 3, 0), Vector3(0, 3, 2),
		Vector3(2, 3, 0), Vector3(2, 3, 2), Vector3(0, 3, 2)]
	var triangles: Array[Dictionary] = []
	for point: Vector3 in points:
		triangles.append({"position": point, "normal": Vector3.UP,
			"uv": Vector2(point.x, point.z), "color": Color.WHITE})
	return {"triangles": triangles}


func test_partial_floor_preserves_exposed_cap_and_source_attributes() -> void:
	var floor_rect := Rect2(0.001, 0, 2, 2)
	var mesh := FabricSurfaceOwnership.uncovered_surface(_square(), Transform3D.IDENTITY,
		[floor_rect], &"wall", &"cap")
	assert_almost_eq(_area(mesh), 0.002, 0.000001, "retain the millimetre-wide exposed strip")
	for index in mesh.vertices.size():
		var vertex: Vector3 = mesh.vertices[index]
		assert_almost_eq(vertex.y, 3.0, 0.000001, "never offset the surface")
		assert_almost_eq(vertex.x, (mesh.uvs[index] as Vector2).x, 0.000001)
		assert_almost_eq(vertex.z, (mesh.uvs[index] as Vector2).y, 0.000001)


func test_overlapping_floor_owners_form_a_union_without_duplicate_cap_fragments() -> void:
	var mesh := FabricSurfaceOwnership.uncovered_surface(_square(), Transform3D.IDENTITY,
		[Rect2(0, 0, 1.25, 1), Rect2(0.75, 0, 1.25, 1)], &"wall", &"cap")
	assert_almost_eq(_area(mesh), 2.0, 0.000001)
	for vertex: Vector3 in mesh.vertices:
		assert_gte(vertex.z, 1.0)


func test_full_coverage_emits_no_cap_and_absent_floor_preserves_all_source_area() -> void:
	var empty := FabricSurfaceOwnership.uncovered_surface(_square(), Transform3D.IDENTITY,
		[Rect2(-1, -1, 4, 4)], &"wall", &"cap")
	assert_eq(empty.vertices.size(), 0)
	var unchanged := FabricSurfaceOwnership.uncovered_surface(_square(), Transform3D.IDENTITY,
		[], &"wall", &"cap")
	assert_almost_eq(_area(unchanged), 4.0, 0.000001)


func _area(mesh: Dictionary) -> float:
	var area := 0.0
	var vertices: PackedVector3Array = mesh.vertices
	for offset in range(0, vertices.size(), 3):
		area += (vertices[offset + 1] - vertices[offset]).cross(
			vertices[offset + 2] - vertices[offset]).length() * 0.5
	return area

func test_floor_owns_vertical_skin_exactly_on_its_rectangle_boundary() -> void:
	var source := _square()
	for vertex:Dictionary in source.triangles:
		var old:Vector3=vertex.position
		vertex.position=Vector3(old.x,3.0-old.z*0.08,2.0)
	var owned := FabricSurfaceOwnership.uncovered_surface(source,Transform3D.IDENTITY,
		[Rect2(0,0,2,2)],&"floor",&"edge")
	assert_almost_eq(_area(owned),0.0,0.000001,"Exact boundary has one owner, including vertical perimeter faces")
	for vertex:Dictionary in source.triangles: vertex.position.z+=0.001
	var exposed := FabricSurfaceOwnership.uncovered_surface(source,Transform3D.IDENTITY,
		[Rect2(0,0,2,2)],&"floor",&"edge")
	assert_almost_eq(_area(exposed),0.32,0.000001,"The neighboring exposed edge must not disappear")
