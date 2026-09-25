extends GutTest

const Frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
const PHOTOS := [
	"res://docs/qa/2026-09-13-manual/13-floating-lawn/current-source.txt",
	"res://docs/qa/2026-09-13-manual/14-deck-purpose/current-source.txt"]

func test_terminal_flights_do_not_climb_above_every_actual_destination() -> void:
	for path: String in PHOTOS:
		var source := Frozen.read(path,false)
		var plots := var_to_str(source.plots)
		var portals := source.excavation.portals.duplicate()
		var highest_door := 0
		for plot: Dictionary in source.plots:
			highest_door=maxi(highest_door,(plot.door_walk as Vector3i).y)
		WarrenMazeSitePlanner.finish_public_destinations(source)
		assert_lte(source.excavation.route.back().y,highest_door,path)
		assert_eq(var_to_str(source.plots),plots,"Native houses and their actual entrances remain fixed")
		assert_eq(source.excavation.portals,portals,"External road gates remain fixed")
		assert_true(source.excavation.validate_construction(),source.excavation.last_rejection)
		for plot: Dictionary in source.plots:
			assert_true(source.passage_kinds.has(plot.door_walk),"Each destination retains its public address")

func test_a_real_upper_destination_keeps_its_complete_flight() -> void:
	for path: String in PHOTOS:
		var source := Frozen.read(path,false)
		var old_route := source.excavation.route.duplicate()
		source.plots.append({"door_walk":source.excavation.route.back(),"floor":source.excavation.route.back().y})
		WarrenMazeSitePlanner.finish_public_destinations(source)
		assert_eq(source.excavation.route,old_route)


func test_upper_external_connections_are_not_pruned() -> void:
	for path: String in PHOTOS:
		var source := Frozen.read(path,false)
		var old_route := source.excavation.route.duplicate()
		source.excavation.portals.append(source.excavation.route.back())
		WarrenMazeSitePlanner.finish_public_destinations(source)
		assert_eq(source.excavation.route,old_route,"An upper exit remains connected")


func test_ordinary_lane_attachment_prevents_terminal_pruning() -> void:
	for path: String in PHOTOS:
		var source := Frozen.read(path,false)
		var old_route := source.excavation.route.duplicate()
		var end: Vector3i = old_route.back()
		source.excavation.lanes.append({"anchor":end,"cells":[end+Vector3i.RIGHT]})
		WarrenMazeSitePlanner.finish_public_destinations(source)
		assert_eq(source.excavation.route,old_route,"A connecting lane retains its approach flight")
