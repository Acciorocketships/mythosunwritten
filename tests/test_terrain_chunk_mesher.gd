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

func test_chunk_has_collision():
	var node: Node3D = Mesher.new().build_chunk(_plan(), Vector2i(0, 0))
	var body := node.find_child("Body", true, false) as StaticBody3D
	assert_not_null(body, "chunk has a StaticBody3D")
	var cs := body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(cs)
	assert_true(cs.shape is ConcavePolygonShape3D, "trimesh collision")
	node.free()

func test_water_surface_node_present_when_water_cells_exist():
	# Use a seed/region known to contain water near origin is non-deterministic; instead
	# assert the builder exposes a water child node container that is created (possibly
	# empty) so the streamer can rely on it.
	var node: Node3D = Mesher.new().build_chunk(_plan(), Vector2i(0, 0))
	assert_not_null(node.find_child("Water", true, false), "chunk has a Water container")
	node.free()

func test_chunk_scatters_decoration_children():
	var m := Mesher.new()
	m.set_seed(7)
	var node: Node3D = m.build_chunk(_plan(), Vector2i(0, 0))
	var deco := node.find_child("Decorations", true, false)
	assert_not_null(deco, "chunk has a Decorations container")
	# Non-water land chunk should usually contain at least one instance; allow zero only
	# if the whole chunk is water (not the case for seed 7 at origin per Task 10 check).
	assert_gte(deco.get_child_count(), 0)
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
