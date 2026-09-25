extends GutTest

func test_generated_facades_omit_rejected_ivy_and_tavern_signs() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var unwanted := []
	var laundry := 0
	var gardens := 0
	for recipe: FabricRecipe in program.recipes():
		for placement: Dictionary in recipe.placements:
			if placement.asset_id in [SettlementFabricProgram.FACADE_IVY,SettlementFabricProgram.FACADE_SIGN]:
				unwanted.append(str(recipe.recipe_id)+"/"+str(placement.id))
			if placement.asset_id == SettlementFabricProgram.FACADE_CLOTHES: laundry += 1
			if str(placement.id) == "facade.windowbox": gardens += 1
	assert_true(unwanted.is_empty(),"The rejected white ivy and mug signs still occur in %d native recipes"%unwanted.size())
	assert_gt(laundry,0,"Keep supported laundry details")
	assert_gt(gardens,0,"Keep complete planted window boxes")

func test_reported_east_town_contains_neither_rejected_detail_family() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
	var payload := SettlementFabricAssembler.payload(spatial.compiled_fabric_cache())
	assert_false(payload.batches.has(SettlementFabricProgram.FACADE_IVY),"P38/P41 white clusters")
	assert_false(payload.batches.has(SettlementFabricProgram.FACADE_SIGN),"P38 floating dark mugs")
