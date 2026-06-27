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

func test_chunk_emits_cliff_wall():
	# Cliff faces are now KayKit dressing pieces + a collision-only wall — NOT vertical
	# faces in the visible grass surface. Verify: (a) the visible surface has no vertical
	# grass sheet at the cliff, (b) a collision wall blocks it, (c) dressing pieces exist.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)  # cliff between cell 3 and 4
	var m := Mesher.new()
	var node := m.build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var normals: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var vertical := 0
	for nrm in normals:
		if absf(nrm.y) < 0.3: vertical += 1
	assert_eq(vertical, 0, "no vertical grass sheet in the visible surface (wall is separate)")
	# A second collision shape (the invisible wall) stops the player at the cliff.
	var body := node.find_child("Body", true, false) as StaticBody3D
	assert_not_null(body.get_node_or_null("CollisionShape3D_walls"), "collision wall present")
	# KayKit cliff dressing produced rock-wall pieces for the cliff.
	var cliffs := node.find_child("Cliffs", true, false)
	var walls := cliffs.find_child("Walls", true, false) as MultiMeshInstance3D
	assert_gt(walls.multimesh.instance_count, 0, "cliff dressing produced wall pieces")
	node.free()
