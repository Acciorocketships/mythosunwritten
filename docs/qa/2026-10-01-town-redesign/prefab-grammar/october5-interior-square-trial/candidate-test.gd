extends GutTest

func test_supported_interior_square_wins_over_small_cheap_patch() -> void:
	var plan := WarrenMazeSitePlanner.plan(31,{},WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	assert_not_null(plan)
	assert_true(plan.is_sealed(),"The larger court must preserve a valid connected town plan")
	var found := false
	for plot: Dictionary in plan.plots:
		if plot.id != &"plaza.00": continue
		found = true
		var cells: Array[Vector2i] = []
		cells.assign(plot.cells)
		assert_gte(cells.size(),9,"Reserve a broad square within the cluster")
		assert_gte(WarrenPlotReservations._plaza_enclosing_sides(plan,cells,int(plot.floor)),3,
			"Massif fronts enclose the square on at least three sides")
		assert_true(plan.passage_kinds.has(plot.door_walk),"Keep the square's published street entrance")
	assert_true(found)
