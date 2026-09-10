extends GutTest

const Legacy = preload("res://tests/fixtures/legacy_cantilever_search.gd")

func test_support_courses_construct_one_choice_matching_the_exhaustive_oracle() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var records: Array[Dictionary] = []
	for i in 4:
		records.append({"recipe_id": &"outcrop.support.diagonal.2",
			"origin": Vector3i(i * 12, 6, 0), "yaw_quarters": i,
			"role": StringName("course.%d" % i)})
	var buildings: Array[WarrenBuildingVolume] = []
	var features: Array[WarrenFeatureReservation] = []
	var old := Legacy._cantilever_support_options(records, {}, buildings,
		features, program, 1)
	var actual := WarrenSpatialFeatureSolver._construct_cantilever_supports(
		records, {}, buildings, features, program, 1)
	assert_eq(old.size(), 16, "the fixture exercises all four independent courses")
	assert_eq((actual.records as Array).size(), records.size())
	if not actual.is_empty() and not old.is_empty():
		assert_eq(actual.records, old[0].records)
		assert_eq(actual.analysis, old[0].analysis)

func test_each_blocked_diagonal_selects_its_bracket_without_revising_other_courses() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var records: Array[Dictionary] = []
	var obstacle_recipes: Array[StringName] = []
	for i in 4:
		var record := {"recipe_id": &"outcrop.support.diagonal.2",
			"origin": Vector3i(i * 12, 6, 0), "yaw_quarters": i}
		records.append(record)
		var transform := FabricRecipe.lattice_transform(record.origin, i)
		var diagonal := transform * program.recipe(record.recipe_id).local_clearance_bounds
		var bracket := transform * program.recipe(&"outcrop.support.bracketed.2").local_clearance_bounds
		var exposed := AABB()
		for x in 5:
			for y in 5:
				for z in 5:
					var point := diagonal.position + diagonal.size * Vector3(
						(x + 0.5)/5.0, (y + 0.5)/5.0, (z + 0.5)/5.0)
					var probe := AABB(point-Vector3.ONE*0.025, Vector3.ONE*0.05)
					if not bracket.intersects(probe): exposed = probe
		assert_gt(exposed.size.length(), 0.0, "the authored bracket has a smaller reach")
		var id := StringName("test.obstacle.%d" % i)
		var recipe := FabricRecipe.new(id, [] as Array[StringName], 0)
		recipe.local_clearance_bounds = exposed
		program._recipes[id] = recipe
		obstacle_recipes.append(id)
	for mask in 16:
		var features: Array[WarrenFeatureReservation] = []
		for i in 4:
			if mask & (1 << i):
				var feature := WarrenFeatureReservation.new(StringName("obstacle.%d" % i), &"test")
				feature.construction_records.append({"recipe_id": obstacle_recipes[i],
					"origin": Vector3i.ZERO, "yaw_quarters": 0})
				features.append(feature)
		var buildings: Array[WarrenBuildingVolume] = []
		var old := Legacy._cantilever_support_options(records, {}, buildings, features, program, 1)
		var actual := WarrenSpatialFeatureSolver._construct_cantilever_supports(
			records, {}, buildings, features, program, 1)
		assert_false(old.is_empty())
		if not old.is_empty(): assert_eq(actual.records, old[0].records)
		var independent := WarrenSpatialFeatureSolver._outcrop_support_analysis(
			actual.records, {}, buildings, features, program, 1)
		assert_eq(independent.conflict, &"", "selected geometry clears every reserved feature")
