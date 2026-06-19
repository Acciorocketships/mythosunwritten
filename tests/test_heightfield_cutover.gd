extends GutTest

# Phase 3c: the heightfield cutover flag suppresses emergent structural growth.

func _make_generator(use_hf: bool) -> Node:
	var gen = preload("res://scripts/terrain/TerrainGenerator.gd").new()
	gen.use_heightfield = use_hf
	return gen

func test_flag_defaults_off() -> void:
	var gen = _make_generator(false)
	assert_false(gen.use_heightfield, "heightfield path is off by default")
	gen.free()

func test_structural_seeding_suppressed_when_flag_on() -> void:
	var gen = _make_generator(true)
	assert_true(gen.structural_seeding_suppressed(), "structural seeds off under heightfield")
	gen.free()

func test_structural_seeding_active_when_flag_off() -> void:
	var gen = _make_generator(false)
	assert_false(gen.structural_seeding_suppressed(), "emergent structural seeds on by default")
	gen.free()

func _spawn(lib: TerrainModuleLibrary, tag: String) -> TerrainModuleInstance:
	# spawn() sets .def (with tags); _is_structural_socket reads only def.tags,
	# so no create() / scene instantiation is needed.
	return lib.get_random(lib.get_by_tags(TagList.new([tag])), true).spawn()

func test_is_structural_socket_classifies_seeds_vs_decoration() -> void:
	var gen = _make_generator(true)
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	lib.init()
	var ground: TerrainModuleInstance = _spawn(lib, "ground-plain")
	assert_true(gen._is_structural_socket(ground, "topcenter"), "ground topcenter seeds structure")
	assert_false(gen._is_structural_socket(ground, "front"), "ground laterals tile the base plane, not structure")
	var cliff: TerrainModuleInstance = _spawn(lib, "cliff-side")
	assert_true(gen._is_structural_socket(cliff, "front"), "cliff lateral is structural")
	assert_true(gen._is_structural_socket(cliff, "topcenter"), "cliff topcenter (stacking) is structural")
	assert_false(gen._is_structural_socket(cliff, "topfront"), "cliff foliage socket is NOT structural")
	var water: TerrainModuleInstance = _spawn(lib, "water")
	assert_false(gen._is_structural_socket(water, "topcenter"), "water is not structural")
	gen.free()

func test_heightfield_places_and_indexes_structural_tiles() -> void:
	var gen = _make_generator(true)
	add_child_autofree(gen)         # so child nodes (terrain_parent, player, tiles) clean up
	gen.init_for_test()
	gen.HEIGHTFIELD_PLACE_RADIUS = 1   # keep the (reference, slow) placement tiny for the test
	gen._drive_heightfield_structure(Vector3.ZERO)
	var plan: HeightfieldPlan = gen.heightfield_plan
	var found: int = 0
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var center: Vector3 = Vector3(cx * 24.0, plan.surface_height(cx, cz), cz * 24.0)
			var box: AABB = AABB(center - Vector3(1, 2, 1), Vector3(2, 4, 2))
			for hit in gen.terrain_index.query_box(box):
				if hit is TerrainModuleInstance:
					found += 1
					break
	assert_gt(found, 0, "structural tiles were placed and indexed near the origin")

func test_eviction_removes_distant_tiles_no_double_placement() -> void:
	# Place around origin, then drive far away: the origin cluster must be removed
	# from the index (not just forgotten), so returning never double-places it.
	var gen = _make_generator(true)
	add_child_autofree(gen)
	gen.init_for_test()
	gen.HEIGHTFIELD_PLACE_RADIUS = 1
	gen._drive_heightfield_structure(Vector3.ZERO)
	# Drive far enough that the origin cells fall outside keep_radius (R+2 = 3).
	gen._drive_heightfield_structure(Vector3(100 * 24.0, 0, 0))
	var origin_box: AABB = AABB(Vector3(-13, -6, -13), Vector3(26, 12, 26))
	var near_origin: int = 0
	for hit in gen.terrain_index.query_box(origin_box):
		if hit is TerrainModuleInstance:
			near_origin += 1
	assert_eq(near_origin, 0, "evicted origin tiles were removed from the index")
	gen.free()

func test_no_start_tile_when_heightfield_on() -> void:
	# With the flag on, _ready must NOT place the emergent start tile (the
	# heightfield covers the origin cell), avoiding an overlap at (0,0).
	var gen = _make_generator(true)
	gen.terrain_parent = Node3D.new()
	add_child_autofree(gen.terrain_parent)
	add_child_autofree(gen)   # fires _ready with the flag on and terrain_parent set
	assert_eq(gen.terrain_parent.get_child_count(), 0, "no start tile placed under heightfield")
