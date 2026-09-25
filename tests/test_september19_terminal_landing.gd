extends GutTest
const FROZEN = preload("res://tests/fixtures/frozen_maze_source.gd")
const SOURCE = "res://docs/qa/2026-09-19-manual/119-small-town/source.txt"

func test_reported_upper_walk_stops_at_its_final_house_entrance() -> void:
	var source := FROZEN.read(SOURCE,false)
	var houses := var_to_bytes(source.plots)
	var entrance := Vector3i(-1,2,-2)
	WarrenMazeSitePlanner.finish_public_destinations(source)
	assert_eq(source.excavation.route.back(),entrance,"Unused terminal floor beyond the last entrance has no destination")
	assert_eq(var_to_bytes(source.plots),houses,"All existing house plots and doors stay fixed")
	assert_true(source.excavation.validate_construction(),source.excavation.last_rejection)
	assert_true(source.passage_kinds.has(entrance),"The upper house remains accessible")
	assert_false(source.passage_kinds.has(Vector3i(-1,2,-1)))

func test_an_occupied_level_endpoint_stays_connected() -> void:
	for kind in ["entrance","gate","lane"]:
		var source := FROZEN.read(SOURCE,false)
		var route := source.excavation.route.duplicate()
		var end:Vector3i=route.back()
		if kind=="entrance":source.plots.append({"door_walk":end,"floor":end.y})
		elif kind=="gate":source.excavation.portals.append(end)
		else:source.excavation.lanes.append({"anchor":end,"cells":[end+Vector3i.RIGHT]})
		WarrenMazeSitePlanner.finish_public_destinations(source)
		assert_eq(source.excavation.route,route,kind)
