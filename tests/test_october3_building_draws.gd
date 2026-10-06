extends GutTest


func test_neighbor_reservation_does_not_reroll_surviving_houses() -> void:
	var massif := WarrenMassif.new(37)
	for x in range(-2, 3):
		for z in range(-2, 3):
			massif.columns[Vector2i(x, z)] = {"base": 0, "top": 12}
	var excavation := WarrenExcavation.new(37)
	excavation.route.assign([Vector3i.ZERO])
	var source := WarrenMazeSourcePlan.new(
		37, WarrenVillageScaleProfile.for_id(&"large"), massif, excavation
	)
	var original := WarrenPlotPlanner._seed_buildings(source, {}, {}, {}, {}, [])
	assert_eq(original.size(), 4)
	if original.size() != 4:
		return
	var blocked := {original[0].seed: true}
	var revised := WarrenPlotPlanner._seed_buildings(source, {}, blocked, {}, {}, [])
	assert_eq(revised.size(), 3)
	var draws := {}
	for building: Dictionary in original:
		draws[building.seed] = Vector2i(
			WarrenPlotPlanner._building_roll(
				source, building, WarrenPlotPlanner.FOOTPRINT_SALT, Vector2i(2, 12)
			),
			WarrenPlotPlanner._rolled_seed_top(source, building)
		)
	for building: Dictionary in revised:
		var revised_draw := Vector2i(
			WarrenPlotPlanner._building_roll(
				source, building, WarrenPlotPlanner.FOOTPRINT_SALT, Vector2i(2, 12)
			),
			WarrenPlotPlanner._rolled_seed_top(source, building)
		)
		assert_eq(
			revised_draw,
			draws[building.seed],
			"A reservation removes one seed without rerolling its surviving neighbors"
		)
	var distinct := {}
	for value: Vector2i in draws.values():
		distinct[value] = true
	assert_gt(distinct.size(), 1, "Houses sharing a doorway retain individual variation")
