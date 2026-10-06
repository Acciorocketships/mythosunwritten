extends GutTest


func test_excavation_uses_the_same_passage_clearance_as_transitions() -> void:
	assert_eq(WarrenExcavation.HEADROOM_BANDS, WarrenVolumePlan.HEADROOM_BANDS)
	assert_gt(
		(
			WarrenExcavation.HEADROOM_BANDS
			* WarrenVolumePlan.VERTICAL_BAND_SIZE_M
			* VillageWorldScale.VERTICAL_SCALE
		),
		TraversalEnvelope.MIN_HEADROOM
	)


func test_supported_passages_keep_complete_inhabited_rooms_above_the_street() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var kit := SuntailBuildingKit.create()
	for example: Dictionary in [
		{"seed": 13, "cell": Vector3i(2, 0, -4)}, {"seed": 31, "cell": Vector3i(-2, 0, 0)}
	]:
		var spatial := WarrenVolumetricSolver.generate(
			example.seed, {}, program, WarrenVillageScaleProfile.for_id(&"large")
		)
		assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
		if spatial == null:
			continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
		var cell: Vector3i = example.cell
		assert_true(source.passage_kinds.has(cell))
		for dx in 2:
			for dz in 2:
				var column := Vector2i(cell.x * 2 + dx, cell.z * 2 + dz)
				var borne := false
				for house: BuildingMass in built.houses:
					if house.cells_at_band(cell.y + WarrenExcavation.HEADROOM_BANDS).has(column):
						borne = true
				assert_true(
					borne,
					"Every quarter of the passage bears an inhabited room, not an uncarried crown"
				)
		assert_eq(int(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count), 0)
		assert_eq(
			int(
				(
					preload("res://tests/fixtures/kit_roof_public_air_audit.gd")
					. audit(built, kit)
					. intrusions
				)
			),
			0
		)
