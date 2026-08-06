extends GutTest

## The massif is the primary object of the mass-first pipeline: a tall,
## terraced, deterministic solid. These tests pin its hard gates.


func test_massif_builds_tall_terraced_and_deterministic() -> void:
	var a := WarrenMassifBuilder.build(1)
	var b := WarrenMassifBuilder.build(1)
	assert_not_null(a, WarrenMassifBuilder.last_failure)
	assert_true(a.is_sealed())
	assert_gte(a.core_top_bands, 16,
		"core must reach 16 bands so excavation has vertical room")
	assert_gte(a.terrace_levels().size(), 5,
		"a smooth dome is not a terraced town silhouette")
	assert_lte(a.widest_plateau_cells(), 6,
		"wide flat plateaus read as empty platforms, not terraces")
	assert_eq(a.columns.size(), b.columns.size())
	for column: Vector2i in a.columns:
		assert_eq(a.top_at(column), b.top_at(column),
			"same seed must give identical column heights")


func test_massif_seeds_differ_and_respect_ground_bands() -> void:
	var flat := WarrenMassifBuilder.build(2)
	var raised_bands: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			raised_bands[Vector2i(x, z)] = 2
	var raised := WarrenMassifBuilder.build(2, raised_bands)
	assert_not_null(flat, WarrenMassifBuilder.last_failure)
	assert_not_null(raised, WarrenMassifBuilder.last_failure)
	var differing := 0
	var other := WarrenMassifBuilder.build(3)
	for column: Vector2i in flat.columns:
		if other.has_column(column) \
				and flat.top_at(column) != other.top_at(column):
			differing += 1
	assert_gt(differing, 10, "different seeds must differ meaningfully")
	for column: Vector2i in raised.columns:
		assert_gte(raised.base_at(column), 2,
			"terrain ground bands lift the massif base")
