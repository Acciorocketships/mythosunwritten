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
