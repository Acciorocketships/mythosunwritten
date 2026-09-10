extends GutTest

func test_reported_town_gate_handoffs_are_painted_and_graded_to_the_street() -> void:
	var seed_value := 2697992464
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(heightfield, water, program.query_margin,
		program.shore_distance_limit, program.field_cache_cap)
	var urban := VillageWarrenFabricSolver.solve(VillageTerrainView.from_fields(fields),
		VillagePlan.warren_seed_for_cell(seed_value, Vector2i(11,12)),
		&"reported-town", Vector2(264,288), Vector2.DOWN, program.villages, seed_value)
	assert_true(urban.accepted)
	if not urban.accepted: return
	var contacts := VillageWarrenFabricSolver.terrain_contact_specs(
		urban.volumetric_spatial, urban.fabric_plan)
	assert_gte(contacts.size(), 2)
	for spec: Dictionary in contacts:
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		var inner: Vector3 = geometry.inner_centre
		var outer: Vector3 = geometry.outer_centre
		var lateral := Vector3(spec.lateral as Vector3i)
		var painted_half_width:=PathProgram.PATH_HALF_WIDTH/VillageWorldScale.scale_of(urban.world_transform)
		for t: float in [0.1, 0.5, 0.9]:
			for width: float in [-0.9, 0.0, 0.9]:
				var local := inner.lerp(outer,t) + lateral * painted_half_width * width
				var world := urban.world_transform * local
				var painted := false
				for shape: FeatureGroundShape in urban.surfaces:
					painted = painted or (shape.surface_id == FeatureGroundField.WORN_PATH \
						and shape.contains(Vector2(world.x,world.z)))
				assert_true(painted, "gate %s must not leave a grass break at %s" % [spec.stable_suffix,world])
