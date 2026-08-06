extends GutTest


func _flat_region() -> HeightfieldRegion:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-6, 7):
		for x in range(-6, 7):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	return HeightfieldRegion.new(storeys, levels)


func test_optional_shelter_uses_annular_terrain_and_a_short_public_lane() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var urban := VillageUrbanFabricPlan.new()
	urban.accepted = true
	urban.massing = VillageMassingPlan.new()
	urban.massing.placements = []
	urban.market = VillageMarketPlan.new()
	urban.market.accepted = true
	urban.circulation = VillageCirculationPlan.new()
	urban.circulation.accepted = true
	for value: Vector2 in [Vector2(18.0, 0.0), Vector2(-18.0, 0.0),
			Vector2(0.0, 18.0), Vector2(0.0, -18.0)]:
		urban.circulation.nodes.append(VillageCirculationNode.new(
			StringName("contact.%d.%d" % [roundi(value.x), roundi(value.y)]),
			VillageCirculationNode.Kind.TERRAIN_CONTACT, value, 0.0))
	var plan := VillageOutskirtsSolver.solve(
		VillageTerrainView.from_region(_flat_region()), &"outskirts.test",
		Vector2.ZERO, Vector2.RIGHT, &"village", &"blue", program,
		urban, [])
	assert_true(plan.accepted, String(plan.reason))
	assert_eq(plan.placements.size(), 1, JSON.stringify(plan.audit, "  "))
	assert_gt(plan.surfaces.size(), 0,
		"an outer shelter is part of town only when a short lane joins it")
	assert_gt(plan.volumes.size(), 1)
	assert_true(plan.validate(program.outskirts_program, &"village"))
	var radius := plan.placements[0].solid_centre.length()
	assert_gte(radius, VillageOutskirtsProgram.INNER_RADIUS - 12.0,
		"the shelter belongs to the porous edge, not the market core")
