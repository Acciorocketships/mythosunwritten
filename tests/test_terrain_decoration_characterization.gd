extends GutTest

# Characterization net for the decoration/water/orphan/suppression engine.
# These tests lock the CURRENT behavior of the socket-expansion pipeline so
# that upcoming dead-code deletions are provably safe.
#
# Path A — heightfield structural coverage — is already tested in
# test_heightfield_cutover.gd and test_heightfield_coverage.gd; no duplication here.
#
# NOTE: lib.init() calls load_water_and_bank_modules() which references
# terrain/scenes/Cliff*.tscn — those are deleted in this branch (moved to
# terrain/scenes/cliff/ via slope integration). We build minimal libraries
# directly from the individual loaders that don't depend on the deleted scenes.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_generator() -> Variant:
	var gen = preload("res://scripts/terrain/TerrainGenerator.gd").new()
	return gen


# Build a library that contains only ground-plain and hill modules —
# sufficient for all socket-classification and fill-prob tests here.
# The library is a Node, so we add it via add_child_autofree to avoid orphan
# warnings. Callers must NOT free it separately.
func _make_minimal_lib() -> TerrainModuleLibrary:
	var lib: TerrainModuleLibrary = TerrainModuleLibrary.new()
	add_child_autofree(lib)
	lib.terrain_modules.append(TerrainModuleDefinitions.load_ground_tile())
	lib.terrain_modules.append(TerrainModuleDefinitions.load_8x8x2_tile())
	lib.terrain_modules.append(TerrainModuleDefinitions.load_12x12x2_tile())
	lib.terrain_modules.append(TerrainModuleDefinitions.load_4x4x4_tile())
	lib.sort_terrain_modules()
	return lib


func _spawn(lib: TerrainModuleLibrary, tag: String) -> TerrainModuleInstance:
	# spawn() sets .def (with tags); socket classification reads only def.tags
	# so no scene instantiation (create()) is needed.
	return lib.get_random(lib.get_by_tags(TagList.new([tag])), true).spawn()


# ---------------------------------------------------------------------------
# Test 1: Foliage socket is live (enqueue/fill)
# ---------------------------------------------------------------------------
# Asserts that a foliage top socket on ground-plain is NOT structural and that
# _effective_fill_prob returns > 0.0 at a low-density non-core position.
# This locks that foliage placement stays enabled.
#
# The socket used is "topfront" — a cardinal foliage socket present on all
# ground-plain tiles (confirmed in TerrainModuleDefinitions.load_ground_tile via
# surface_spawn_sockets which always adds topfront/topback/topleft/topright).
# Position chosen by scanning a grid far from origin where the origin falloff
# in macro_density01 is saturated (distance >= 180 units from origin).
func test_foliage_socket_is_live_enqueue_fill() -> void:
	var gen: Variant = _make_generator()
	var lib: TerrainModuleLibrary = _make_minimal_lib()
	var ground: TerrainModuleInstance = _spawn(lib, "ground-plain")

	# "topfront" is a foliage socket — must NOT be structural.
	assert_false(gen._is_structural_socket(ground, "topfront"),
		"ground topfront is a foliage socket and must NOT be structural")

	# Find a low-density non-core position deterministically by scanning a grid.
	# We use the generator's own world_seed (0 at construction, before _ready).
	var low_pos: Vector3 = Vector3.INF
	var seed: int = gen.world_seed
	for ix in range(40):
		for iz in range(40):
			var p: Vector3 = Vector3(300.0 + ix * 48.0, 0.0, 300.0 + iz * 48.0)
			var m: float = Helper.macro_density01(p, seed)
			if m < 0.40:  # clearly below CLIFF_CONTOUR_BASE (0.56) and low density
				low_pos = p
				break
		if low_pos != Vector3.INF:
			break

	assert_ne(low_pos, Vector3.INF,
		"must find a low-density non-core position in the sample grid")
	assert_false(gen._in_cliff_core(low_pos),
		"chosen position must not be in the cliff core")

	var fill: float = gen._effective_fill_prob(ground, "topfront", low_pos)
	assert_gt(fill, 0.0,
		"_effective_fill_prob for foliage socket at low-density non-core pos must be > 0 (foliage can spawn)")

	gen.free()


# ---------------------------------------------------------------------------
# Test 2: Hill-stacking path is live
# ---------------------------------------------------------------------------
# Spawns an 8x8x2 hill (def-only, no scene) and asserts that its topcenter
# socket has a non-trivial fill probability (stacking is live) and a non-empty
# size distribution (the data driving the stack roll is present).
#
# proxy: tests the data/predicate path rather than a full multi-frame placement
# run, which would be stochastic. This is the correct deterministic proxy for
# "the hill-stack branch in add_piece_to_queue is reachable".
func test_hill_stacking_path_is_live() -> void:
	var gen: Variant = _make_generator()
	var lib: TerrainModuleLibrary = _make_minimal_lib()
	# "8x8x2" is a tag on the hill module (tags: ["hill", "8x8x2"])
	var hill: TerrainModuleInstance = _spawn(lib, "8x8x2")

	# The topcenter socket_fill_prob must be positive (stacking is enabled).
	var fill_prob: float = gen._get_socket_fill_prob(hill, "topcenter")
	assert_gt(fill_prob, 0.0,
		"8x8x2 hill topcenter fill_prob must be > 0 (stacking path is live)")

	# The topcenter socket must have a non-empty size distribution.
	var size_dist: Distribution = hill.def.socket_size.get("topcenter", null)
	assert_ne(size_dist, null, "8x8x2 hill must have a topcenter socket_size distribution")
	assert_false(size_dist.is_empty(),
		"8x8x2 hill topcenter socket_size distribution must not be empty")

	# The socket is NOT structural (hills are decoration/stacking, not cliff seeds).
	assert_false(gen._is_structural_socket(hill, "topcenter"),
		"hill topcenter is not structural — it is a stacking/decoration socket")

	# proxy: _effective_fill_prob at a low-density non-core position reflects
	# the stacking probability (> 0). Same position strategy as test 1.
	var low_pos: Vector3 = Vector3.INF
	var seed: int = gen.world_seed
	for ix in range(40):
		for iz in range(40):
			var p: Vector3 = Vector3(300.0 + ix * 48.0, 0.0, 300.0 + iz * 48.0)
			if Helper.macro_density01(p, seed) < 0.40:
				low_pos = p
				break
		if low_pos != Vector3.INF:
			break

	assert_ne(low_pos, Vector3.INF, "must find a low-density position for hill stacking test")
	var eff: float = gen._effective_fill_prob(hill, "topcenter", low_pos)
	assert_gt(eff, 0.0,
		"_effective_fill_prob for hill topcenter at a low-density pos must be > 0 (stacking enqueue fires)")

	gen.free()


# ---------------------------------------------------------------------------
# Test 3: Surface-support predicate (_has_surface_support)
# ---------------------------------------------------------------------------
# Tests the support predicate that _purge_orphaned_stacks relies on, directly.
# We use def-only instances (no scenes) placed in a bare TerrainIndex so the
# spatial query runs against real indexed data.
#
# Chosen approach: verify the support predicate rather than a full orphan-sweep
# loop, because the sweep needs terrain_parent, rules, and scene instantiation.
# The predicate is the invariant the sweep enforces — locking it is the correct
# deterministic proxy.
#
# We do NOT call add_child_autofree(gen) here because firing _ready() would
# call library.init() which tries to load terrain/scenes/CliffSide.tscn (deleted
# in this branch — moved to terrain/scenes/cliff/ via slope integration).
# Instead we create the generator bare and inject terrain_index directly.
#
# The 8x8x2 hill AABB comes from load_8x8x2_tile via Helper.compute_scene_mesh_aabb.
# def-only spawn() exposes def.aabb; TerrainModuleInstance.aabb applies the transform.
func test_has_surface_support_predicate() -> void:
	var gen: Variant = _make_generator()
	# Do NOT add_child_autofree — that fires _ready() which calls library.init()
	# and fails on deleted cliff scenes. Manually wire just what we need.
	gen.terrain_index = TerrainIndex.new()

	var lib: TerrainModuleLibrary = _make_minimal_lib()

	# Create a ground tile def-only instance and insert into terrain_index.
	# Ground-plain AABB: AABB(Vector3(-12,0,-12), Vector3(24,0.5,24)) — top at y=0.5.
	var ground: TerrainModuleInstance = _spawn(lib, "ground-plain")
	ground.set_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)))
	gen.terrain_index.insert(ground)

	# Create a hill def-only instance placed above the ground tile.
	# Place hill origin at y=0.5 (the ground tile's top surface) so its AABB
	# bottom rests on the probe plane that _has_surface_support searches.
	var hill: TerrainModuleInstance = _spawn(lib, "8x8x2")
	hill.set_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0)))
	gen.terrain_index.insert(hill)

	# With ground tile present, the probe should find it.
	assert_true(gen._has_surface_support(hill),
		"hill should be supported when a ground tile is directly below it")

	# Remove the ground tile and verify support is lost.
	gen.terrain_index.remove(ground)
	assert_false(gen._has_surface_support(hill),
		"hill should have NO support after the ground tile is removed from the index")

	gen.free()


# ---------------------------------------------------------------------------
# Test 4: Cliff-core foliage suppression (KEY GUARD)
# ---------------------------------------------------------------------------
# This is the most important test for guarding later deletions. It directly
# exercises the suppression branch in _route_fill_prob / _effective_fill_prob
# that returns 0.0 for non-cliff decoration sockets inside a cliff contour core.
#
# Exact assertions locked:
#   a) A cliff-core position is found deterministically (_in_cliff_core true).
#   b) _effective_fill_prob for ground-plain "topfront" at core_pos == 0.0.
#      Source: _route_fill_prob branch:
#        if _socket_can_spawn_point(piece, socket_name):
#          if _in_cliff_core(pos) and not piece.def.tags.has("cliff"):
#            return 0.0
#   c) _effective_fill_prob at a low-density non-core position > 0.0.
#   d) _in_cliff_core(low_pos) == false.
#
# Finding positions: CLIFF_CONTOUR_BASE = 0.56. macro_density01 origin falloff
# saturates (= 1.0) at distance >= SPAWN_CLEAR_RADIUS+SPAWN_CLEAR_FADE = 180.
# We scan a 60x60 grid starting at (200, 0, 200) — all points are at distance
# ~283+ from origin, so falloff = 1.0 and the raw noise is exposed.
func test_cliff_core_foliage_suppression() -> void:
	var gen: Variant = _make_generator()
	var lib: TerrainModuleLibrary = _make_minimal_lib()
	var ground: TerrainModuleInstance = _spawn(lib, "ground-plain")
	var seed: int = gen.world_seed

	var core_pos: Vector3 = Vector3.INF
	var low_pos: Vector3 = Vector3.INF

	for ix in range(60):
		for iz in range(60):
			var p: Vector3 = Vector3(200.0 + ix * 48.0, 0.0, 200.0 + iz * 48.0)
			var m: float = Helper.macro_density01(p, seed)
			if core_pos == Vector3.INF and m >= 0.56:  # TerrainSpawnConfig.CLIFF_CONTOUR_BASE
				core_pos = p
			if low_pos == Vector3.INF and m < 0.35:
				low_pos = p
		if core_pos != Vector3.INF and low_pos != Vector3.INF:
			break

	# Guard assertions: if these fail the scan radius needs widening, NOT production code.
	assert_ne(core_pos, Vector3.INF,
		"must find a cliff-core position (macro >= 0.56) in the scan grid for seed %d" % seed)
	assert_ne(low_pos, Vector3.INF,
		"must find a low-density position (macro < 0.35) in the scan grid for seed %d" % seed)

	# (a) _in_cliff_core agrees with the macro threshold.
	assert_true(gen._in_cliff_core(core_pos),
		"_in_cliff_core must be true at the found core position")

	# (b) KEY GUARD: foliage fill is 0.0 inside a cliff core for non-cliff tiles.
	# The _route_fill_prob branch: socket_can_spawn_point + in_cliff_core + not cliff => 0.0
	var fill_at_core: float = gen._effective_fill_prob(ground, "topfront", core_pos)
	assert_eq(fill_at_core, 0.0,
		"foliage _effective_fill_prob must be 0.0 for ground-plain inside cliff core (suppression active)")

	# (c) At the low-density non-core position, fill is > 0.0 (foliage can spawn).
	var fill_at_low: float = gen._effective_fill_prob(ground, "topfront", low_pos)
	assert_gt(fill_at_low, 0.0,
		"foliage _effective_fill_prob must be > 0.0 at a low-density non-core position")

	# (d) _in_cliff_core is false at the non-core position.
	assert_false(gen._in_cliff_core(low_pos),
		"_in_cliff_core must be false at the low-density position")

	gen.free()
