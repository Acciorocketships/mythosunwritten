extends GutTest

func test_room_sized_projection_is_not_a_shallow_jetty() -> void:
	var lower := {}
	var deep := {}
	var shallow := {}
	for z in 2:
		for x in 4:
			lower[Vector2i(x,z)] = true
			deep[Vector2i(x-2,z)] = true
			shallow[Vector2i(x-1,z)] = true
	assert_false(WarrenRoomCompositionPlanner._floorplate_transition_is_structurally_legible(
		deep,lower,4,{},null), "An entire room-sized projection needs actual bearing, not shallow jetty brackets")
	assert_true(WarrenRoomCompositionPlanner._floorplate_transition_is_structurally_legible(
		shallow,lower,4,{},null), "A shallow projecting edge remains legal")
	assert_true(WarrenRoomCompositionPlanner._floorplate_transition_is_structurally_legible(
		lower,lower,4,{},null), "A fully borne room remains legal")
