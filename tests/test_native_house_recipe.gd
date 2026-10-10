extends GutTest
const Recipe = preload("res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd")
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeHouseSite.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func test_planner_recipe_round_trip_preserves_every_native_module_in_world_space() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var frame := Transform3D(Basis.from_scale(VillageWorldScale.frame_scale()), Vector3.ZERO)
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		for seed_value in [7, 31]:
			var recipe := Recipe.cross(
				catalog, &"native.fixture", dimensions.x, dimensions.y, seed_value
			)
			assert_not_null(recipe)
			if recipe == null:
				continue
			assert_true(recipe.is_sealed())
			assert_true(recipe.has_tag(&"native_grammar"))
			assert_true(recipe.has_tag(&"prefab_anchor"))
			assert_eq(recipe.entrances[0].cell, Vector3i.ZERO)
			assert_eq(recipe.entrances[0].facing, Vector3i.BACK)
			assert_true(recipe.sockets.is_empty(), "No unproved upper-floor connections")
			var site := Site.cross(
				catalog, dimensions.x, dimensions.y, seed_value, 2.0, Vector3.ZERO, Vector3.BACK
			)
			assert_eq(recipe.placements.size(), site.parts.size())
			var body: Dictionary = {}
			for cell in recipe.solid_cells:
				body[cell] = true
			for cell in recipe.headroom_cells:
				assert_false(body.has(cell))
			for index in site.parts.size():
				var part: Dictionary = site.parts[index]
				var placement: Dictionary = recipe.placements[index]
				var expected: Transform3D = site.pose * part.transform
				expected.origin.y += VillageWorldScale.GROUND_DATUM_GUARD
				var actual: Transform3D = frame * placement.transform
				var reflected: bool = String(placement.asset_id).ends_with(".mirror_x")
				assert_eq(
					String(placement.asset_id).trim_suffix(".mirror_x"),
					String(Compiler.asset_id(part.module))
				)
				assert_gt(actual.basis.determinant(), 0.0)
				if reflected:
					actual.basis = actual.basis * Basis.from_scale(Vector3(-1, 1, 1))
				assert_almost_eq(actual.origin, expected.origin, Vector3.ONE * .0001)
				for axis in 3:
					assert_almost_eq(actual.basis[axis], expected.basis[axis], Vector3.ONE * .0001)
				var bounds: AABB = (
					placement.transform * catalog.descriptor(placement.asset_id).measured_aabb
				)
				assert_true(
					recipe.local_clearance_bounds.grow(.001).encloses(bounds),
					"Complete native overhang must be reserved"
				)
				assert_gt(recipe.placement_collision_pieces[index], 0)


func test_fabric_assembler_preserves_the_native_derivation_without_extra_joints() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var recipe := Recipe.cross(catalog, &"native.fixture", 2, 1, 31)
	assert_not_null(recipe)
	if recipe == null:
		return
	for yaw in 4:
		var plan := preload("res://tests/fixtures/native_house_plan.gd").build(recipe, catalog, yaw)
		assert_true(plan.is_sealed())
		var unit: FabricUnit = plan.units[0]
		var payload := SettlementFabricAssembler.payload(plan)
		assert_eq(
			payload.instance_count,
			recipe.placements.size(),
			"No facade/roof postprocessing may add or drop native pieces"
		)
		assert_true(payload.surface_meshes.is_empty(), "No procedural substitute roof")
		var expected: Dictionary = {}
		for placement: Dictionary in recipe.placements:
			var key := String(placement.asset_id)
			if not expected.has(key):
				expected[key] = []
			expected[key].append(unit.transform() * placement.transform)
		for asset_id in payload.asset_ids():
			var actual: Array = payload.batches[asset_id].transforms
			assert_eq(
				actual, expected[String(asset_id)], "Assembler retains every original transform"
			)
