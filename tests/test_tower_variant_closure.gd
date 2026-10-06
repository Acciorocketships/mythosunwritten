extends GutTest
## Material variants retain a cap's closure geometry. Removing that actual
## cap must still expose the gable cutout: stale cutter metadata proves nothing.
const AUDIT = preload("res://tests/fixtures/kit_roof_audit.gd")
const FROZEN = preload("res://tests/fixtures/frozen_maze_source.gd")


func test_finished_tower_cap_closes_gable_but_missing_cap_does_not():
	var kit = SuntailBuildingKit.create()
	var program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source = WarrenMazeSitePlanner.plan(
		53, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"", false
	)
	var spatial = FROZEN.spatial(source, program)
	var built = KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var caps = 0
	for tower in built.towers:
		for part in tower.parts:
			if part.role == &"tower.roof" and String(part.asset_id).contains(".finish_"):
				caps += 1
	assert_gt(caps, 0, "Exercise actual material variants, not just canonical blue roofs.")
	assert_eq(
		int(AUDIT.audit(built, kit).gable_holes),
		0,
		"Present variant caps close their native cutouts."
	)
	for tower in built.towers:
		tower.parts = tower.parts.filter(
			func(part: Dictionary) -> bool: return part.role != &"tower.roof"
		)
	var missing = AUDIT.audit(built, kit)
	assert_gt(int(missing.uncapped_towers), 0)
	assert_gt(
		int(missing.gable_holes),
		0,
		"The removed cap exposes its original cutout despite retained cutter metadata."
	)
