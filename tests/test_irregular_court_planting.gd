extends GutTest
const COURT = preload("res://scripts/terrain/features/villages/TownCourtTrees.gd")


func test_tree_can_use_an_l_shaped_bed_without_occupying_the_door_approach():
	var bed := {Vector3i.ZERO: true, Vector3i.RIGHT: true, Vector3i.BACK: true}
	var catalog := EnvironmentCatalog.load_default()
	var bounds := {}
	for asset: StringName in SettlementFabricAssembler.PLAZA_COURT_TREES:
		bounds[asset] = catalog.descriptor(asset).measured_aabb
	var feature := SettlementFabricAssembler.maze_plaza_centre_feature(
		bed, {}, {"asset_bounds": bounds}, [], {}, true, 1
	)
	assert_false(
		feature.is_empty(), "The doorway notch must not discard a tree whose measured roots fit"
	)
	if feature.is_empty():
		return
	assert_true(COURT.clear(feature, {"asset_bounds": bounds}, []))
	assert_false(
		feature.cells.has(Vector3i(1, 0, 1)), "The paved doorway approach remains unplanted"
	)
	assert_gte(
		float(feature.scale) * (bounds[feature.asset] as AABB).size.y,
		7.5,
		"Keep the mature-height candidate"
	)


func test_notched_bed_never_overrides_an_entrance_or_a_roof():
	var bed := {Vector3i.ZERO: true, Vector3i.RIGHT: true, Vector3i.BACK: true}
	var catalog := EnvironmentCatalog.load_default()
	var bounds := {}
	for asset: StringName in SettlementFabricAssembler.PLAZA_COURT_TREES:
		bounds[asset] = catalog.descriptor(asset).measured_aabb
	var blocked := {
		"asset_bounds": bounds, "boxes": [AABB(Vector3(-20, 0, -20), Vector3(40, 40, 40))]
	}
	assert_true(
		(
			SettlementFabricAssembler
			. maze_plaza_centre_feature(bed, {}, blocked, [], {}, true, 1)
			. is_empty()
		),
		"A building can rule out every measured tree"
	)
	assert_true(
		(
			SettlementFabricAssembler
			. maze_plaza_centre_feature(bed, bed, {"asset_bounds": bounds}, [], {}, true, 1)
			. is_empty()
		),
		"Public entrances own their cells even when the remaining planting has no tree"
	)


func test_large_planted_islands_use_living_canopies_instead_of_the_bare_centre_tree():
	var catalog := EnvironmentCatalog.load_default()
	var bounds := {}
	for asset: StringName in (
		SettlementFabricAssembler.PLAZA_COURT_TREES + SettlementFabricAssembler.PLAZA_WIDE_FEATURES
	):
		bounds[asset] = catalog.descriptor(asset).measured_aabb
	var trees := 0
	for offset in 12:
		var bed := {}
		for x in 3:
			for z in 3:
				bed[Vector3i(x + offset * 4, 0, z)] = true
		var feature := SettlementFabricAssembler.maze_plaza_centre_feature(
			bed, {}, {"asset_bounds": bounds}, [], {}, true, 1
		)
		assert_false(feature.is_empty())
		if feature.is_empty():
			continue
		assert_ne(
			feature.asset,
			SettlementFabricAssembler.PLAZA_TREE,
			"A large planted court must not bypass the leafy canopy grammar"
		)
		if feature.asset in SettlementFabricAssembler.PLAZA_COURT_TREES:
			trees += 1
			assert_true(COURT.clear(feature, {"asset_bounds": bounds}, []))
	assert_gt(trees, 0, "Seeded large courts retain tree choices alongside wells and market stalls")
