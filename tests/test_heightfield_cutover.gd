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
