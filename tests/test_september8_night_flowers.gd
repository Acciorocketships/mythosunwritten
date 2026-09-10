extends GutTest

func test_photographed_roof_flower_has_a_container_between_its_roots_and_wood() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var plan:=frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program).compiled_fabric_cache()
	var payload:=SettlementFabricAssembler.payload(plan)
	var prefix:="spatial.roof.spatial.maze_back.00.room00.garden/"
	var flower_pose:=Transform3D.IDENTITY
	var found:=false
	var containers:Array[AABB]=[]
	for asset:StringName in payload.batches:
		var batch:Dictionary=payload.batches[asset]
		for i in batch.ids.size():
			if not String(batch.ids[i]).begins_with(prefix):continue
			if asset==SettlementFabricProgram.ROOF_FLOWER_SMALL:
				flower_pose=batch.transforms[i];found=true
			if asset==SettlementFabricProgram.TERRACE_BUCKET or asset==SettlementFabricProgram.ROOF_PLANTER:
				containers.append((batch.transforms[i] as Transform3D)*catalog.descriptor(asset).measured_aabb)
	assert_true(found,"The photographed flower stays part of the roof garden")
	var contained:=false
	for box:AABB in containers:
		contained=contained or box.has_point(flower_pose.origin)
	assert_true(contained,"A real container must enclose the flower footing above the wooden roof")

func test_all_micro_roof_recipes_include_and_measure_the_complete_container() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var count:=0
	for recipe:FabricRecipe in program.recipes():
		if not recipe.has_tag(&"micro_roof_garden"):continue
		count+=1
		assert_true(recipe.asset_ids().has(SettlementFabricProgram.TERRACE_BUCKET),String(recipe.recipe_id))
		for placement:Dictionary in recipe.placements:
			if placement.asset_id!=SettlementFabricProgram.TERRACE_BUCKET:continue
			var bounds:AABB=(placement.transform as Transform3D)*catalog.descriptor(placement.asset_id).measured_aabb
			assert_true(recipe.local_bounds.grow(0.00001).encloses(bounds),"The placement solver must reserve the complete container")
			assert_almost_eq(bounds.position.y,0.0,0.00001,"Container stands on the roof")
	assert_gt(count,0)
