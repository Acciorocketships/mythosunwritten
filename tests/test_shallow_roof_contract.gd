extends GutTest

func test_shallow_roof_runs_align_to_their_cells_and_high_wall_edge() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for theme: String in ["blue", "orange"]:
		for length_cells: int in [2, 4, 6]:
			for side: int in [-1, 1]:
				var id := StringName("roof.setback.shed.%s.%d.%s" % [theme,
					length_cells, "negative" if side < 0 else "positive"])
				var recipe := program.recipe(id)
				assert_not_null(recipe)
				if recipe == null: continue
				assert_almost_eq(recipe.local_bounds.get_center().x,
					float(length_cells - 1) * FabricRecipe.CELL_SIZE * 0.5,
					0.001, "%s centres its run on the occupied cells" % id)
				assert_almost_eq(recipe.local_bounds.position.y, 0.0, 0.001)
				var high_edge := recipe.local_bounds.position.z if side > 0 \
					else recipe.local_bounds.end.z
				assert_almost_eq(high_edge, -float(side) * 0.75, 0.001,
					"the high edge meets the continuing wall")
				assert_true(SettlementFabricPlan._pitched_roof_alignment_holds(recipe),
					"the shallow roof has a valid typed construction contract")
				# Moving the measured weather skin leaves its declared cells and
				# wall edge unchanged; a bad alignment must remain detectable.
				var original := recipe.local_bounds
				for offset: Vector3 in [Vector3(0.05, 0, 0),
					Vector3(0, 0.05, 0), Vector3(0, 0, 0.05)]:
					recipe.local_bounds = AABB(original.position + offset, original.size)
					assert_false(SettlementFabricPlan._pitched_roof_alignment_holds(recipe))
				recipe.local_bounds = original
