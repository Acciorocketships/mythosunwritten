extends GutTest


func test_competing_private_crossings_keep_the_lower_street_ceiling() -> void:
	var wrong: Array[Vector3i] = []
	for x in range(-4, 5):
		var inhabited := {}
		var low := Vector3i(x, 4, -9)
		for band in [4, 6]:
			for rise in 2:
				inhabited[Vector3i(x, band + rise, -9)] = StringName("near.%d" % band)
				inhabited[Vector3i(x, band + rise, -6)] = StringName("far.%d" % band)
		var walked := {Vector2i(x, -8): [2], Vector2i(x, -7): [2]}
		var candidates := SettlementFabricAssembler._maze_passage_house_candidates(
			inhabited, {}, {}, {}, {}, {}, walked
		)
		assert_eq(candidates.size(), 2, "Both complete connected alternatives must be available")
		var selected: Array[Dictionary] = []
		var claimed := {}
		for candidate: Dictionary in candidates:
			SettlementFabricAssembler._maze_accept_private_skywalk(candidate, claimed, selected)
		assert_eq(selected.size(), 1, "Their complete native shells compete for the same air")
		if selected.size() == 1 and selected[0].cell != low:
			wrong.append(selected[0].cell)
	assert_eq(
		wrong,
		[] as Array[Vector3i],
		"Seed ordering must not replace a low ceiling with a higher competing bridge"
	)
