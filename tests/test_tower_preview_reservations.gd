extends GutTest

func test_reselection_does_not_leave_an_oversized_orphan_block() -> void:
	# This town replaces two early landmark sites after gaining a native tower
	# address. Keeping the old masks sealed the ground-level block's entrance
	# and forced its 62 columns into one orphan house.
	var plan := WarrenMazeSitePlanner.plan(53, {},
		WarrenVillageScaleProfile.for_id(&"grand"), &"", false)
	assert_not_null(plan, WarrenMazeSitePlanner.last_failure)
	if plan == null: return
	assert_true(plan.is_sealed(), plan.last_rejection)
	var largest := 0
	for plot: Dictionary in plan.plots:
		if plot.kind == WarrenMazeSourcePlan.PLOT_HOUSE:
			largest = maxi(largest, plot.cells.size())
	assert_lt(largest, 20, "Available frontage subdivides the captured 62-column orphan block")
	var towers := 0
	for outcome: Dictionary in WarrenPlotPlanner.outcomes(plan).get("assets", []):
		if not String(outcome.get("kind_id", "")).begins_with("anchor.z_native.turret."):
			continue
		var site: Dictionary = outcome.get("site", {})
		for plot: Dictionary in plan.plots:
			if plot.id != site.get("id", &""): continue
			towers += 1
			assert_true(plan.excavation.public_cells().has(plot.door_walk),
				"The accepted tower retains its actual street address")
			for column: Vector2i in plot.cells:
				assert_lt(plan.first_carved_band(column, plot.floor, plot.top), 0,
					"Replacing the preview must preserve the accepted native tower body")
	assert_gt(towers, 0)
	assert_gte(plan.excavation.bridge_spans.size(), 1,
		"The earlier supported bridge survives landmark reselection")
