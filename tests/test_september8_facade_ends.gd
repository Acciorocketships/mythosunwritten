extends GutTest

func test_photographed_retaining_remnant_is_not_a_single_panel_house_facade() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var plan := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(plan)
	assert_eq(int(transaction.shell.treatments[Vector4i(-3,2,9,3)]),
		SettlementFabricAssembler.SkinTreatment.MASONRY,
		"The photographed isolated retained shoulder must continue its masonry body")

func test_facade_continuity_uses_aligned_complete_bank_courses() -> void:
	for turn in 4:
		var normal := FabricRecipe.transform_cell(Vector3i.BACK,Vector3i.ZERO,turn)
		var tangent := FabricRecipe.transform_cell(Vector3i.RIGHT,Vector3i.ZERO,turn)
		var side := SettlementFabricAssembler.STONE_FACE_DIRECTIONS.find(normal)
		var bank := {}
		for height in 4:
			bank[Vector4i(0,height,0,side)]=true
			bank[Vector4i(tangent.x,height,tangent.z,side)]=true
		assert_true(SettlementFabricAssembler._maze_has_facade_course_neighbor(bank,Vector4i(0,3,0,side)))
		bank.erase(Vector4i(tangent.x,3,tangent.z,side))
		assert_false(SettlementFabricAssembler._maze_has_facade_course_neighbor(bank,Vector4i(0,3,0,side)),
			"A staggered neighbor cannot lend its mismatched facade course")

func test_shared_corner_does_not_cancel_a_deep_door_return() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for recipe_id: StringName in [&"room.tower.base.rock",&"room.slim.base.amber"]:
		var recipe := program.recipe(recipe_id)
		for panel: Dictionary in recipe.placements:
			var finish: Dictionary = recipe.facade_end_owners.get(StringName(panel.id),{})
			var depths: Vector2 = finish.get("door_return_depths",Vector2.ZERO)
			if depths.is_zero_approx(): continue
			var realized := String(recipe.realized_facade_asset(panel,[],false,3))
			for end in 2:
				if depths[end]<=0.0: continue
				assert_true(realized.contains("back%d" % roundi(depths[end]*1000000.0)),
					"A corner post owns miters, but the doorway still owns its return boundary")
