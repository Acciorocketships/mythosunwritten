extends GutTest

func test_only_the_named_support_post_can_flash_through_its_bearers_roof() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var plan := SettlementFabricPlan.new(&"frame-roof-junction")
	var roof_recipe := program.recipe(&"roof.partial.gable.orange.2.negative")
	var post_recipe := program.recipe(&"foundation.timber.post.2")
	assert_true(plan.register_recipe(roof_recipe))
	assert_true(plan.register_recipe(post_recipe))
	var roof := FabricUnit.new(&"roof", roof_recipe.recipe_id, Vector3i(-4, 3, -4), 0)
	var post := FabricUnit.new(&"post", post_recipe.recipe_id,
		Vector3i(-3, 3, -4), 1, [], [], &"", [&"roof"])
	plan._by_id[roof.stable_id] = roof
	plan._by_id[post.stable_id] = post
	var roof_bounds := roof.transform() * roof_recipe.local_bounds
	var post_bounds := post.transform() * post_recipe.placement_bounds[0]
	assert_true(SettlementFabricPlan._aabb_overlaps_volume(roof_bounds, post_bounds))
	assert_true(plan._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, roof_bounds, post, post_recipe, post_bounds, &"post"))
	assert_false(plan._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, roof_bounds, post, post_recipe, post_bounds, &"unrelated"))
	var wide := AABB(roof_bounds.position, Vector3(1.5, 3, 1.5))
	assert_false(plan._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, roof_bounds, post, post_recipe, wide, &"post"),
		"declaring a seam never permits a wide column through the roof")
	post.visual_seam_ids.clear()
	assert_false(plan._continuous_component_has_measured_roof_junction(
		{roof.stable_id: true}, roof_bounds, post, post_recipe, post_bounds, &"post"),
		"a nearby roof with no declared bearing junction remains an overlap")
