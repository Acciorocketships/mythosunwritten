extends GutTest

const Frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
const PHOTO := "res://docs/qa/2026-09-13-manual/15-tower-massing/current-source.txt"

func test_reported_detached_towers_keep_their_addresses_as_low_houses() -> void:
	var source := Frozen.read(PHOTO,false)
	var streets := var_to_str(source.excavation.public_cells())
	var original := source.plots.duplicate(true)
	preload("res://docs/qa/2026-09-13-manual/15-tower-massing/rejected_lower_massing.gd").finish_house_massing(source)
	for index in source.plots.size():
		var plot: Dictionary = source.plots[index]
		assert_eq(plot.cells,original[index].cells,"Owned footprints stay fixed")
		assert_eq(plot.door_walk,original[index].door_walk,"Each house keeps its actual entrance")
		if plot.id in [&"house.018", &"house.020", &"house.027"]:
			assert_eq(int(plot.top),int(plot.floor)+4,"A detached narrow plot is a cottage, not an isolated spire")
	assert_eq(var_to_str(source.excavation.public_cells()),streets)
	assert_true(source.finish_construction(),source.last_rejection)


func test_complete_upper_party_walls_keep_towers_in_four_directions() -> void:
	for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var source := Frozen.read(PHOTO,false)
		var tower := _tower(source)
		source.plots.append(_neighbor(tower,direction,0,8))
		preload("res://docs/qa/2026-09-13-manual/15-tower-massing/rejected_lower_massing.gd").finish_house_massing(source)
		assert_eq(int(tower.top),8,"A complete upper party wall retains the tall group")


func test_roofs_and_partial_height_contacts_do_not_substitute_for_walls() -> void:
	for interval: Vector2i in [Vector2i(0,6),Vector2i(5,9)]:
		var source := Frozen.read(PHOTO,false)
		var tower := _tower(source)
		source.plots.append(_neighbor(tower,Vector2i.LEFT,interval.x,interval.y))
		preload("res://docs/qa/2026-09-13-manual/15-tower-massing/rejected_lower_massing.gd").finish_house_massing(source)
		assert_lt(int(tower.top),8,"An adjoining roof or half wall cannot support a tall skyline claim")


func test_diagonal_neighbors_do_not_count_as_party_walls() -> void:
	var source := Frozen.read(PHOTO,false)
	var tower := _tower(source)
	source.plots.append(_neighbor(tower,Vector2i(-1,-1),0,8))
	preload("res://docs/qa/2026-09-13-manual/15-tower-massing/rejected_lower_massing.gd").finish_house_massing(source)
	assert_eq(int(tower.top),4)


func test_real_upper_loads_are_not_shortened() -> void:
	var source := Frozen.read(PHOTO,false)
	var tower := _tower(source)
	var deck := _neighbor(tower,Vector2i.ZERO,8,8)
	deck.kind=WarrenMazeSourcePlan.PLOT_DECK
	source.plots.append(deck)
	preload("res://docs/qa/2026-09-13-manual/15-tower-massing/rejected_lower_massing.gd").finish_house_massing(source)
	assert_eq(int(tower.top),8,"A real upper deck retains its existing bearing")


func _tower(source: WarrenMazeSourcePlan) -> Dictionary:
	for plot: Dictionary in source.plots:
		if plot.id == &"house.027": return plot
	return {}


func _neighbor(tower: Dictionary,direction: Vector2i,base: int,top: int) -> Dictionary:
	return {"id":&"test.neighbor","building_id":&"test.neighbor",
		"kind":WarrenMazeSourcePlan.PLOT_HOUSE,
		"cells":[(tower.cells[0] as Vector2i)+direction] as Array[Vector2i],
		"floor":base,"top":top,"door_walk":tower.door_walk}
