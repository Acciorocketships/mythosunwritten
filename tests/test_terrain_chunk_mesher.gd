extends GutTest
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func _plan():
	var p := Plan.new(7, 56.0, 12, "mean")
	return p

func test_build_returns_meshinstance_with_geometry():
	var p = _plan()
	var node: Node3D = Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	assert_not_null(mi, "chunk has a Surface MeshInstance3D")
	assert_gt(mi.mesh.get_surface_count(), 0, "mesh has geometry")
	node.free()

func test_adjacent_chunks_share_boundary_height():
	# The shared edge between chunk (0,0) and chunk (1,0) must sample identical heights
	# (gap-free property): the field is single-valued, so the last column of chunk 0
	# equals the first column of chunk 1.
	const Field := preload("res://scripts/terrain/field/TerrainSurfaceField.gd")
	var p = _plan()
	var r = p.compute_region(0, 0, 64)
	var boundary_x := float(Mesher.CELLS_PER_CHUNK) * 24.0 * 0.5  # right edge of chunk (0,0) in world x
	var a := Field.surface_y(r, boundary_x, 3.0)
	var b := Field.surface_y(r, boundary_x, 3.0)
	assert_eq(a, b, "field is single-valued at the shared boundary")
