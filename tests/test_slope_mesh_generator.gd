# tests/test_slope_mesh_generator.gd
extends GutTest

const MAT := "res://terrain/materials/ground.tres"

func _gen() -> SlopeMeshGenerator:
	var g := SlopeMeshGenerator.new()
	g.grass_uv = Vector2(0.25, 0.25)  # deterministic UV for tests
	g.material = load(MAT)
	return g

func _aabb(mesh: ArrayMesh) -> AABB:
	return mesh.get_aabb()

func test_top_is_flat() -> void:
	var mesh := _gen().build_top()
	var box := _aabb(mesh)
	assert_almost_eq(box.position.y, 0.0, 1e-4)
	assert_almost_eq(box.size.y, 0.0, 1e-4)
	assert_almost_eq(box.size.x, 12.0, 1e-3)
	assert_almost_eq(box.size.z, 12.0, 1e-3)

func test_edge_spans_full_drop() -> void:
	var box := _aabb(_gen().build_edge())
	assert_almost_eq(box.position.y, -4.0, 1e-3)   # bottom reaches -4
	assert_almost_eq(box.position.y + box.size.y, 0.0, 1e-3)  # top at 0
	assert_almost_eq(box.size.x, 12.0, 1e-3)
	assert_almost_eq(box.size.z, 12.0, 1e-3)

func test_all_uvs_are_grass() -> void:
	var mesh := _gen().build_edge()
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 0)
	for uv in uvs:
		assert_almost_eq(uv.x, 0.25, 1e-6)
		assert_almost_eq(uv.y, 0.25, 1e-6)

func test_components_have_material_and_normals() -> void:
	for mesh in [_gen().build_top(), _gen().build_edge(), _gen().build_outer_corner(), _gen().build_inner_corner()]:
		assert_not_null(mesh.surface_get_material(0))
		var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		assert_gt(normals.size(), 0)

func test_collision_slabs_are_convex() -> void:
	var g := _gen()
	var seg := SlopeMeshGenerator.COLLISION_SEG
	# edge is flat across x, so only its curved (z) axis is subdivided -> `seg` slabs;
	# corners curve in both axes -> seg*seg slabs.
	var cases := [
		[g.build_edge_collision(), seg],
		[g.build_outer_corner_collision(), seg * seg],
		[g.build_inner_corner_collision(), seg * seg],
	]
	for case in cases:
		var arr: Array = case[0]
		assert_eq(arr.size(), case[1], "unexpected slab count")
		for s in arr:
			assert_true(s is ConvexPolygonShape3D)
			assert_gt((s as ConvexPolygonShape3D).points.size(), 0)
	assert_true(g.build_top_collision() is BoxShape3D)

func test_edge_collision_not_split_across_flat_axis() -> void:
	# The edge profile is flat across x (derivative 0), so collision must NOT waste
	# slabs splitting x: expect exactly COLLISION_SEG slabs (curved z axis only), each
	# spanning the full 12u width in x.
	var slabs := _gen().build_edge_collision()
	assert_eq(slabs.size(), SlopeMeshGenerator.COLLISION_SEG, "edge should subdivide only the curved axis")
	for s in slabs:
		var min_x := 100.0
		var max_x := -100.0
		for p in (s as ConvexPolygonShape3D).points:
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
		assert_almost_eq(max_x - min_x, 12.0, 1e-3)

func test_edge_collision_follows_the_drop() -> void:
	# The edge slabs must actually track the slope (not sit flat) and skirt downward:
	# their points span the full [-4, 0] drop plus the skirt below the bottom.
	var min_y := 1.0
	var max_y := -100.0
	for s in _gen().build_edge_collision():
		for p in (s as ConvexPolygonShape3D).points:
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
	assert_almost_eq(max_y, 0.0, 1e-3)                                  # reaches the plateau top
	assert_almost_eq(min_y, -4.0 - SlopeMeshGenerator.SKIRT, 1e-3)     # bottom + downward skirt

func test_stacked_corner_meshes_build() -> void:
	var g := _gen()
	# outer_corner_stacked is the 2-storey diagonal ramp (bottoms at -8); the
	# (deprecated) inner_corner_stacked still bottoms at -4.
	var cases := [[g.build_outer_corner_stacked(), -8.0], [g.build_inner_corner_stacked(), -4.0]]
	for case in cases:
		var mesh: ArrayMesh = case[0]
		var bottom: float = case[1]
		var box: AABB = mesh.get_aabb()
		assert_almost_eq(box.size.x, 12.0, 1e-3)
		assert_almost_eq(box.size.z, 12.0, 1e-3)
		assert_almost_eq(box.position.y, bottom, 1e-3)
		assert_almost_eq(box.position.y + box.size.y, 0.0, 1e-3)
		assert_not_null(mesh.surface_get_material(0))
	# both stacked corners curve in x and z -> seg*seg slabs
	var n := SlopeMeshGenerator.COLLISION_SEG * SlopeMeshGenerator.COLLISION_SEG
	for arr in [g.build_outer_corner_stacked_collision(), g.build_inner_corner_stacked_collision()]:
		assert_eq(arr.size(), n)
		for s in arr:
			assert_true(s is ConvexPolygonShape3D)
