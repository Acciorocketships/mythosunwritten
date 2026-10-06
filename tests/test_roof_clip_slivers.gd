extends GutTest

const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _panel(width: float, height: float) -> Dictionary:
	return {
		"vertices":
		PackedVector3Array(
			[Vector3.ZERO, Vector3(width, 0, 0), Vector3(width, height, 0), Vector3(0, height, 0)]
		),
		"normals": PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK]),
		"uvs": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]),
		"indices": PackedInt32Array([0, 1, 2, 0, 2, 3])
	}


func _cut_below(height: float) -> Dictionary:
	return UNION.box_volume(AABB(Vector3(-1, -1, -1), Vector3(102, height + 1, 2)))


func test_sub_tolerance_clipping_strip_cannot_become_an_invisible_collision_fence() -> void:
	for width: float in [2.0, 80.0]:
		var mesh := UNION.trim_surface(
			_panel(width, 1.0), Transform3D.IDENTITY, [_cut_below(1.0 - UNION.EPS * .1)]
		)
		assert_true(mesh.changed)
		assert_true(
			mesh.vertices.is_empty(),
			"A long strip below clipping precision must disappear from both render and collision"
		)


func test_real_thin_roof_trim_survives_clipping() -> void:
	var mesh := UNION.trim_surface(_panel(80.0, 1.0), Transform3D.IDENTITY, [_cut_below(.99)])
	assert_false(mesh.vertices.is_empty(), "A centimetre of trim is real geometry")
	var area := 0.0
	for i in range(0, mesh.indices.size(), 3):
		var a: Vector3 = mesh.vertices[mesh.indices[i]]
		var b: Vector3 = mesh.vertices[mesh.indices[i + 1]]
		var c: Vector3 = mesh.vertices[mesh.indices[i + 2]]
		area += (b - a).cross(c - a).length() * .5
	assert_almost_eq(area, .8, .001)


func test_untouched_authored_detail_is_not_filtered_by_fragment_tolerance() -> void:
	var surface := _panel(2.0, UNION.EPS * .1)
	var mesh := UNION.trim_surface(surface, Transform3D.IDENTITY, [_cut_below(-.5)])
	assert_false(mesh.changed)
	assert_eq(
		mesh.indices.size(),
		6,
		"The tolerance applies to generated fragments, not original authored triangles"
	)
