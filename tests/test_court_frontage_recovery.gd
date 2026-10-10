extends GutTest


func test_committed_court_frontage_survives_height_trimming():
	var plan := WarrenMazeSitePlanner.plan(53, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"", false)
	assert_not_null(plan)
	if plan == null: return
	var frontage := false
	var broad_square := false
	for plot: Dictionary in plan.plots:
		if plot.id == &"plaza.00":
			var cells := {}
			for column: Vector2i in plot.cells: cells[column] = true
			var bounds := BuildingDesigner._bounds(cells)
			broad_square = mini(bounds.size.x, bounds.size.y) >= 3
		if plot.kind == WarrenMazeSourcePlan.PLOT_HOUSE and int(plot.floor) == 1:
			frontage = frontage or (plot.cells as Array).has(Vector2i(0, 8))
	assert_true(frontage, "A viable court-facing seed absorbed then dropped by a taller neighbor must get its own roofed house")
	assert_true(broad_square, "Keep the broad court whose frontage is being recovered")
