extends GutTest
const Frozen=preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_climb_constructs_a_larger_open_destination_before_houses() -> void:
	var original:=Frozen.read("res://tests/fixtures/september7-manual-source.txt")
	var source:=WarrenMazeCarver.carve(original.world_seed,original.massif,original.scale_profile,false,false)
	assert_not_null(source)
	if source==null:return
	assert_eq(source.excavation.route,original.excavation.route,"The photographed climb keeps its itinerary")
	var lookout:Dictionary={}
	for feature:Dictionary in source.feature_stamps:
		if feature.kind==&"terminal_lookout":lookout=feature
	assert_false(lookout.is_empty(),"The terminal stair needs an explicitly reserved destination")
	if lookout.is_empty():return
	assert_eq(lookout.cells.size(),4,"The destination is twice as wide and twice as deep as one landing")
	for cell:Vector3i in lookout.cells:
		assert_true(source.excavation.public_cells().has(cell))
		assert_false(bool(source.excavation.covered.get(cell,false)),"A lookout must retain open sky")
		for band in range(cell.y,source.massif.top_at(Vector2i(cell.x,cell.z))):
			assert_true(source.excavation.carved.has(Vector3i(cell.x,band,cell.z)))
	WarrenPlotPlanner.reserve(source,source.scale_profile)
	WarrenPlotPlanner.partition(source,source.scale_profile)
	source.finish_construction(false)
	for plot:Dictionary in source.plots:
		for cell:Vector3i in lookout.cells:
			if not (plot.cells as Array).has(Vector2i(cell.x,cell.z)):continue
			assert_true(int(plot.top)<=cell.y or int(plot.floor)>=cell.y+WarrenExcavation.HEADROOM_BANDS,
				"House reservation must respect the complete lookout air")
	var volume:=WarrenMazeVolumeAdapter.to_volume_plan(source)
	assert_not_null(volume)
	if volume==null:return
	for cell:Vector3i in lookout.cells:assert_true(volume.has_walk(cell))
	var link:=false
	for transition:WarrenVolumeTransition in volume.transitions:
		if transition.from_cell==lookout.cells[0] and transition.to_cell==lookout.cells[1]:link=true
	assert_true(link,"The larger platform must have an explicit walkable join")

func test_lookout_reservation_rotates_and_never_consumes_existing_public_air() -> void:
	for forward:Vector3i in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]:
		var columns:Dictionary={}
		for x in range(-2,3):
			for z in range(-2,3):columns[Vector2i(x,z)]={"base":0,"top":9}
		var massif:=WarrenMassif.with_columns(17,columns,9)
		massif.finish_construction()
		var excavation:=WarrenExcavation.new(17)
		var end:=Vector3i(0,4,0)
		var start:=end-forward*2-Vector3i.UP
		excavation.route.assign([start,end-forward,end])
		excavation.transitions.append({"from":start,"to":end,"kind":WarrenVolumeTransition.Kind.STAIR})
		var platform:=WarrenMazeCarver._stamp_terminal_lookout(massif,excavation)
		assert_eq(platform.size(),4)
		assert_true(platform.has(end))
		assert_true(platform.has(end+forward))
		for cell:Vector3i in platform:
			for band in range(cell.y,9):assert_true(excavation.carved.has(Vector3i(cell.x,band,cell.z)))
		var before:=excavation.carved.duplicate()
		assert_true(WarrenMazeCarver._stamp_terminal_lookout(massif,excavation).is_empty(),"An existing destination is not extended again")
		assert_eq(excavation.carved,before)
