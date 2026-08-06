extends GutTest

## Same-height roofs that visually join must be built from one measured
## construction profile. A parallel-valley or ridge-continuation pair whose
## recipes differ in real ridge height by half a metre reads as a mistake, not
## as intentional variety; height variety belongs to stepped junctions.

const PROFILE_TOLERANCE_M := 0.05


func _program() -> SettlementFabricProgram:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert_not_null(program)
	return program


func _building_pair(left_feature: int, right_feature: int) \
		-> Array[Dictionary]:
	## Two 6 m houses eave-to-eave at one band: the classifier sees a
	## PARALLEL_VALLEY join between equal roof bases.
	return [
		{"stable_id": &"left", "kind": &"building", "origin": Vector3i.ZERO,
			"yaw_quarters": 0, "storeys": 2, "route_y": 0,
			"roof_feature": left_feature},
		{"stable_id": &"right", "kind": &"building",
			"origin": Vector3i(4, 0, 0), "yaw_quarters": 0, "storeys": 2,
			"route_y": 0, "roof_feature": right_feature},
	]


static var _catalog: EnvironmentCatalog


func _roof_height(program: SettlementFabricProgram,
		proposal: Dictionary) -> float:
	## Highest point of the roof's actual weather surface. Chimneys poke above
	## every ridge by design and are excluded from the profile comparison.
	if _catalog == null:
		_catalog = EnvironmentCatalog.load_default()
	for component: Dictionary in StaggeredFabricCompiler.proposal_components(
			proposal):
		if StringName(component.role) != &"roof":
			continue
		var recipe_value := program.recipe(StringName(component.recipe_id))
		assert_not_null(recipe_value,
			"missing roof recipe %s" % component.recipe_id)
		if recipe_value == null:
			return -1.0
		var top := -1.0
		for placement: Dictionary in recipe_value.placements:
			# Chimneys and dormer windows are intentional punctuations above
			# the weather plane, not part of the joined ridge profile.
			if String(placement.id).contains("chimney") \
					or String(placement.id).contains("dormer"):
				continue
			var descriptor := _catalog.descriptor(
				StringName(placement.asset_id))
			var world := (placement.transform as Transform3D) \
				* descriptor.measured_aabb
			top = maxf(top, world.end.y)
		return top
	return -1.0


func test_equal_band_flashed_neighbors_share_one_measured_roof_profile() \
		-> void:
	var program := _program()
	for features: Array in [[0, 1], [0, 0], [3, 2], [1, 2], [0, 3]]:
		for world_seed in [7, 701]:
			var proposals := _building_pair(int(features[0]), int(features[1]))
			var topology := FabricRoofTopologyPlan.build(proposals)
			assert_not_null(topology)
			if topology == null:
				continue
			assert_eq(int(topology.audit.parallel_valley_count), 1,
				"the fixture pair must classify as one parallel valley")
			assert_true(WarrenAssetCompiler._assign_neighborhood_styles(
				proposals, topology, world_seed))
			var left_height := _roof_height(program, proposals[0])
			var right_height := _roof_height(program, proposals[1])
			assert_almost_eq(left_height, right_height, PROFILE_TOLERANCE_M,
				("features %s seed %d: joined equal-band roofs use profiles " \
				+ "%.3f m vs %.3f m — a visible ridge mismatch") % [
					features, world_seed, left_height, right_height])


func test_square_roof_recipes_keep_their_ridge_on_local_z() -> void:
	## The classifier hardcodes local +Z as every roof's ridge. The joined
	## plain modular runs must honour that axis; the legacy gable-fronted
	## roof.blue/roof.orange ids stay X-run for the authored fixture path and
	## are deliberately not part of this contract.
	var program := _program()
	for recipe_id: StringName in [&"roof.square.blue.plain",
			&"roof.square.orange.plain"]:
		var recipe_value := program.recipe(recipe_id)
		assert_not_null(recipe_value, String(recipe_id))
		if recipe_value == null:
			continue
		assert_true(recipe_value.has_tag(&"ridge_z"),
			"%s must run its ridge along local Z like every other roof" \
			% recipe_id)
		# The reviewed pair-run is square within centimetres (eave pair span
		# 6.487 m vs 6.469 m ridge); the contract is the run axis, not
		# elongation, so allow that authored rounding.
		assert_gt(recipe_value.local_bounds.size.z,
			recipe_value.local_bounds.size.x - 0.05,
			"%s measured ridge axis must not be transverse" % recipe_id)
