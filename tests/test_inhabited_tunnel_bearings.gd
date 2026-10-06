extends GutTest


func test_room_variation_keeps_required_tunnel_support_columns() -> void:
	var block := {"tunnel_bearing_columns": {Vector2i(-1, -1): true, Vector2i(-1, 0): true}}
	assert_true(
		WarrenRoomCompositionPlanner._candidate_matches_constraints(
			&"tower", Vector3i.ZERO, 0, block
		)
	)
	assert_false(
		WarrenRoomCompositionPlanner._candidate_matches_constraints(
			&"tower", Vector3i.RIGHT, 0, block
		),
		"A shifted room cannot abandon its tunnel jamb"
	)
	assert_true(
		WarrenRoomCompositionPlanner._candidate_matches_constraints(
			&"building", Vector3i.ZERO, 0, block
		),
		"A wider inhabited room may still preserve the support"
	)
	assert_true(WarrenRoomCompositionPlanner._block_has_interface_constraint(block))
	assert_true(WarrenRoomCompositionPlanner._block_has_non_address_identity(block))


func test_only_admitted_covers_publish_bearing_contacts() -> void:
	var volume := WarrenVolumePlan.new(&"test", 1, null)
	assert_true(WarrenRoomCompositionPlanner._tunnel_bearing_cells(volume).is_empty())
	var source := WarrenMazeSourcePlan.new(
		1, WarrenVillageScaleProfile.for_id(&"large"), null, null
	)
	source.plots = [
		{
			"kind": WarrenMazeSourcePlan.PLOT_OVER,
			"crown": 6,
			"jambs": [Vector2i(-1, 1), Vector2i(-1, 3)]
		}
	]
	volume.mass_context[&"maze_source_plan"] = source
	var cells := WarrenRoomCompositionPlanner._tunnel_bearing_cells(volume)
	assert_eq(cells.size(), 16)
	assert_true(cells.has(Vector3i(-2, 6, 2)))
	assert_false(cells.has(Vector3i(-2, 6, 4)), "The passage itself is not a side wall")
	assert_false(cells.has(Vector3i(-2, 8, 2)), "Higher rooms remain free to vary")


func test_joint_inhabited_jamb_and_flat_roof_support_reaches_finished_cover() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		101, {}, program, WarrenVillageScaleProfile.for_id(&"large")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var source: WarrenMazeSourcePlan = spatial.source_volume.mass_context[&"maze_source_plan"]
	var cover := {}
	for plot: Dictionary in source.plots:
		if plot.kind == WarrenMazeSourcePlan.PLOT_OVER and plot.cells.has(Vector2i(-1, 2)):
			cover = plot
	assert_false(cover.is_empty())
	if cover.is_empty():
		return
	var private_cells := WarrenVolumetricSolver.building_private_cells(spatial.buildings)
	for fine: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(-1, int(cover.floor), 2)):
		assert_true(
			private_cells.has(fine), "The admitted passage must have an inhabited room above it"
		)
	for jamb: Vector2i in cover.jambs:
		for band in [int(cover.crown) - 1, int(cover.crown)]:
			for fine: Vector3i in WarrenVolumetricSolver._fine_square(
				Vector3i(jamb.x, band, jamb.y)
			):
				assert_true(
					(
						private_cells.has(fine)
						or spatial.grid.use_at(fine) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME
					),
					"Both complete jambs must survive construction"
				)
	var fabric := spatial.compiled_fabric_cache()
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, fabric, kit)
	assert_eq(KitFloatingMassAudit.audit(spatial, fabric, built.masses).count, 0)
	assert_eq(
		preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built, kit).intrusions, 0
	)
