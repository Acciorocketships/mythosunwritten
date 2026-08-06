extends GutTest


func _terraced_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-12, 13):
		for x in range(-12, 13):
			var cell := Vector2i(x, z)
			storeys[cell] = 0 if x <= -1 else (1 if x == 0 else 2)
			levels[cell] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_all_elevated_public_fabric_uses_one_fixed_cell_materializer() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var terrain := VillageTerrainView.from_region(_terraced_region())
	var urban := VillageUrbanFabricSolver.solve(terrain, &"fabric",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program)
	assert_true(urban.accepted, String(urban.reason))
	if not urban.accepted:
		return
	var fabric := urban.timber
	assert_not_null(fabric)
	var cells := fabric.cells
	var kinds: Dictionary = {}
	for cell: VillageTimberCell in cells:
		kinds[cell.kind] = true
	assert_true(kinds.has(VillageTimberCell.Kind.SKIRT))
	assert_true(kinds.has(VillageTimberCell.Kind.PLATFORM))
	assert_true(kinds.has(VillageTimberCell.Kind.WALKWAY))
	assert_true(fabric.accepted, String(fabric.reason))
	assert_true(fabric.validate())
	assert_gt(fabric.support_count, 0)
	assert_gt(fabric.railing_count, 0)
	for entry: Dictionary in fabric.entries:
		assert_true((entry.transform as Transform3D).basis.get_scale(
			).is_equal_approx(Vector3.ONE),
			"collision-bearing timber fabric must never be stretched")
