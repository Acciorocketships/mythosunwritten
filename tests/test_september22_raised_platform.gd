extends GutTest
## September 22 manual review, photo 3 (town N02): one prefab stood on a raised
## platform reached by a long timber climb that served nothing else. A raised
## public level must be shared by several buildings; a prefab may only take a
## raised site that leaves that level room for companions.
const N02_CITY_SEED := 9045190421882749890


func _plan() -> WarrenMazeSourcePlan:
	return WarrenMazeSitePlanner.plan(N02_CITY_SEED, {},
		WarrenVillageScaleProfile.for_id(&"compact"), &"partition", false)


func test_photographed_town_shares_its_raised_levels() -> void:
	var plan := _plan()
	assert_not_null(plan)
	if plan == null: return
	var entry: int = (plan.excavation.route.front() as Vector3i).y
	var buildings_by_level: Dictionary = {}
	for cell: Vector3i in plan.excavation.route:
		if cell.y > entry: buildings_by_level[cell.y] = 0
	for plot: Dictionary in plan.plots:
		var level: int = (plot.door_walk as Vector3i).y
		if plot.kind != WarrenMazeSourcePlan.PLOT_DECK and buildings_by_level.has(level):
			buildings_by_level[level] = int(buildings_by_level[level]) + 1
	var top: int = (plan.excavation.route.back() as Vector3i).y
	assert_true(top <= entry or int(buildings_by_level.get(top, 0)) >= 2,
		"the terminal raised level serves %s buildings" % buildings_by_level.get(top, 0))
	var raised := 0
	for level: int in buildings_by_level: raised += int(buildings_by_level[level])
	assert_true(top <= entry or raised >= 2, "the raised network serves %d buildings" % raised)


func test_no_prefab_stands_alone_on_a_raised_level() -> void:
	var plan := _plan()
	assert_not_null(plan)
	if plan == null: return
	var entry: int = (plan.excavation.route.front() as Vector3i).y
	for plot: Dictionary in plan.plots:
		if plot.kind != WarrenMazeSourcePlan.PLOT_ASSET or int(plot.floor) <= entry: continue
		var level: int = (plot.door_walk as Vector3i).y
		var neighbours := 0
		for other: Dictionary in plan.plots:
			if other.id != plot.id and other.kind != WarrenMazeSourcePlan.PLOT_DECK \
					and (other.door_walk as Vector3i).y == level:
				neighbours += 1
		assert_gt(neighbours, 0, "raised prefab %s shares level %d" % [plot.id, level])
