extends GutTest

const Refiner = preload("res://scripts/terrain/water/WaterSurfaceRefinement.gd")


func _mesh(rect: Rect2, level: Callable) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var weld: Dictionary = {}
	for p: Vector2 in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		var y: float = level.call(p)
		weld[Vector3i(roundi(p.x * 64), roundi(p.y * 64), roundi(y * 64))] = vertices.size()
		vertices.append(Vector3(p.x, y, p.y))
		normals.append(Vector3.UP)
	return {
		"rect": rect,
		"verts": vertices,
		"normal_accum": normals,
		"weld": weld,
		"idx": PackedInt32Array([0, 3, 2, 0, 2, 1])
	}


func test_planar_water_keeps_identical_geometry() -> void:
	var level := func(p: Vector2) -> float: return 2.0 + p.x * .3 + p.y * .5
	var st := _mesh(Rect2(0, 0, 2, 2), level)
	var before := var_to_bytes(st)
	var stats: Dictionary = Refiner.refine(st, level)
	assert_eq(stats.rounds, 0)
	assert_eq(var_to_bytes(st), before)


func test_curved_water_refines_without_opening_internal_edges() -> void:
	var level := func(p: Vector2) -> float: return 1.0 + .4 * p.x * (2.0 - p.x) * p.y * (2.0 - p.y)
	var st := _mesh(Rect2(0, 0, 2, 2), level)
	var stats: Dictionary = Refiner.refine(st, level)
	assert_gt(stats.final_triangles, stats.initial_triangles)
	var counts := _edges(st)
	var holes := 0
	for edge: Vector2i in counts:
		if counts[edge] != 1:
			continue
		var a: Vector3 = st.verts[edge.x]
		var b: Vector3 = st.verts[edge.y]
		if not Refiner._border_edge(st.rect, a, b):
			holes += 1
	assert_eq(holes, 0, "shared-edge splits never open an interior crack")
	var max_error := 0.0
	for ti in range(0, st.idx.size(), 3):
		var middle: Vector3 = (
			(st.verts[st.idx[ti]] + st.verts[st.idx[ti + 1]] + st.verts[st.idx[ti + 2]]) / 3.0
		)
		max_error = maxf(max_error, level.call(Vector2(middle.x, middle.z)) - middle.y)
	assert_lt(max_error, .08, "refinement resolves the formerly 0.4m submerged chord")


func test_neighbours_agree_on_curved_border_with_different_interiors() -> void:
	var level := func(p: Vector2) -> float: return 1.0 + (.5 + maxf(0.0, -p.x)) * p.y * (2.0 - p.y)
	var left := _mesh(Rect2(-2, 0, 2, 2), level)
	var right := _mesh(Rect2(0, 0, 2, 2), level)
	Refiner.refine(left, level)
	Refiner.refine(right, level)
	var a := _border_vertices(left)
	var b := _border_vertices(right)
	assert_gt(a.size(), 2, "curved shared border is actually refined")
	assert_eq(a, b, "opposite chunks choose identical border vertices and heights")
	assert_true(
		a.has(Vector3(0, 1.5, 1)),
		"border water follows its field instead of preserving the low chord"
	)


func test_buried_rim_is_not_raised_to_surface() -> void:
	var level := func(_p: Vector2) -> float: return 3.0
	var st := _mesh(Rect2(0, 0, 2, 2), func(_p: Vector2) -> float: return 2.0)
	var before := var_to_bytes(st)
	Refiner.refine(st, level)
	assert_eq(var_to_bytes(st), before, "buried rim faces retain their authored shape")


func _edges(st: Dictionary) -> Dictionary:
	var counts := {}
	for ti in range(0, st.idx.size(), 3):
		for k in 3:
			var a: int = st.idx[ti + k]
			var b: int = st.idx[ti + (k + 1) % 3]
			var edge := Vector2i(mini(a, b), maxi(a, b))
			counts[edge] = int(counts.get(edge, 0)) + 1
	return counts


func _border_vertices(st: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for v: Vector3 in st.verts:
		if absf(v.x) < .0001:
			result.append(v)
	result.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
	return result
