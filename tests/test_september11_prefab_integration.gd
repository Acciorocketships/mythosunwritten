extends GutTest

func test_all_complete_native_buildings_remain_selectable_by_source_reservations() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var reference := preload("res://tests/test_warren_maze_plots.gd").new()
	var selected: Dictionary = {}
	for template: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
		var canonical := program.recipe(template.kind_id)
		var expected: Dictionary = reference._derived_asset_template(canonical)
		expected.erase("kind_id")
		for id: StringName in WarrenPlotReservations.asset_recipe_ids(template.kind_id):
			var recipe := program.recipe(id)
			assert_not_null(recipe)
			if recipe == null: continue
			var actual: Dictionary = reference._derived_asset_template(recipe)
			actual.erase("kind_id")
			assert_eq(actual,expected,"Every native alternative must retain the complete doorway-relative reservation and bearing profile")
			assert_false(selected.has(id),"A native building has one source reservation family")
			selected[id] = true
	for recipe: FabricRecipe in program.recipes():
		if recipe.has_tag(&"prefab_anchor"):
			assert_true(selected.has(recipe.recipe_id),
				"Complete native building %s must not disappear when equal footprints are deduplicated" % recipe.recipe_id)
	reference.free()


func test_prefab_budget_uses_the_second_complete_supported_site() -> void:
	var profile := WarrenVillageScaleProfile.for_id(&"compact")
	var source := WarrenMazeSitePlanner.plan(11,{},profile)
	assert_not_null(source,WarrenMazeSitePlanner.last_failure)
	if source == null: return
	var assets: Array[Dictionary] = []
	for plot: Dictionary in source.plots:
		if plot.kind == WarrenMazeSourcePlan.PLOT_ASSET: assets.append(plot)
	assert_eq(assets.size(),2,
		"This compact town has two complete supported street sites; an early quota must not discard the second prefab")
	var signature := source.deterministic_signature()
	var choices: Array = source.audit.plot_outcomes.assets
	var first: Dictionary = choices[0]
	var original_kind: StringName = first.kind_id
	first.kind_id = &"anchor.prefab.10" if original_kind != &"anchor.prefab.10" else &"anchor.prefab.16"
	assert_ne(source.deterministic_signature(),signature,
		"The source identity must distinguish two actual native buildings in the same reservation family")
	first.kind_id = original_kind
	choices.reverse()
	assert_eq(source.deterministic_signature(),signature,
		"Audit iteration order must not change the selected construction identity")
