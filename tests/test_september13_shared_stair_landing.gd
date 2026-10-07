extends GutTest

func test_p07_deck_has_full_width_orthogonal_stair_to_existing_upper_landing() -> void:
	var reservations := WarrenPlotReservations.new()
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var source := frozen.read("res://docs/qa/2026-09-13-manual/04-path/source.txt",false)
	if reservations.has_method("_reserve_deck_access"):
		reservations.call("_reserve_deck_access",source)
	source.finish_construction()
	var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
	assert_not_null(volume)
	if volume==null: return
	var found := false
	for flight: WarrenVolumeTransition in volume.transitions:
		if flight.from_cell!=Vector3i(1,2,5) or flight.to_cell!=Vector3i(1,3,3): continue
		found=true
		assert_eq(flight.kind,WarrenVolumeTransition.Kind.STAIR)
		assert_eq(flight.surface_cells().size(),4,"Two full fine-cell lanes through the whole flight")
		assert_true(volume.has_walk(Vector3i(1,3,3)),"Both stairs meet the existing upper walk landing")
	assert_true(found,"P07 has a normal orthogonal staircase, not a half-width side ramp")
	assert_eq(int(volume.audit.get("path_outside_bore_count",-1)),0)
	var original := false
	for flight: WarrenVolumeTransition in volume.transitions:
		if flight.from_cell==Vector3i(3,2,3) and flight.to_cell==Vector3i(1,3,3):
			original = true
	assert_true(original,"The original full-width flight also reaches the common landing")
	var spatial := WarrenVolumetricSolver.from_volume(volume,-1,
		SettlementFabricProgram.compile(EnvironmentCatalog.load_default()),true)
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial != null:
		var fabric := WarrenSpatialFabricCompiler.generate(spatial,
			SettlementFabricProgram.compile(EnvironmentCatalog.load_default()),true)
		assert_not_null(fabric,WarrenSpatialFabricCompiler.last_failure)


func test_shared_landing_rule_rotates_translates_and_keeps_both_lanes() -> void:
	for turn in 4:
		for hand in [-1,1]:
			var source := _layout(turn,hand)
			WarrenPlotReservations._reserve_deck_access(source)
			var plot: Dictionary = source.plots[0]
			assert_true(plot.has("access_transition"),"orientation %d hand %d"%[turn,hand])
			if not plot.has("access_transition"): continue
			var flights := WarrenMazeVolumeAdapter._deck_access_transitions(source)
			assert_eq(flights.size(),1)
			var flight := flights[0]
			assert_true(flight.seal())
			assert_eq(flight.from_cell,_turn(Vector3i(1,2,5),turn,hand))
			assert_eq(flight.to_cell,_turn(Vector3i(1,3,3),turn,hand))
			assert_eq(flight.surface_cells().size(),4)
			var ends := WarrenTransitionSurfaceBuilder._span_endpoints(flight)
			assert_almost_eq((ends.end as Vector3).distance_to(ends.start),sqrt(11.25),.001)
			# Running planning twice does not add or move a second flight.
			var saved: Dictionary = plot.access_transition.duplicate(true)
			WarrenPlotReservations._reserve_deck_access(source)
			assert_eq(plot.access_transition,saved)


func test_occupied_or_short_court_cannot_squeeze_the_stair() -> void:
	var occupied := _layout(0,1)
	occupied.plots.append({"id":&"room","kind":WarrenMazeSourcePlan.PLOT_HOUSE,
		"cells":[Vector2i(18,-7)],"floor":3,"top":5})
	WarrenPlotReservations._reserve_deck_access(occupied)
	assert_false(occupied.plots[0].has("access_transition"))
	var short_court := _layout(0,1)
	short_court.plots[0].cells.erase(Vector2i(18,-6))
	WarrenPlotReservations._reserve_deck_access(short_court)
	assert_false(short_court.plots[0].has("access_transition"))


func test_plaza_stairs_keep_only_flat_ground_in_the_green() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for seed_value in [3,7]:
		var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,
			WarrenVillageScaleProfile.for_id(&"standard"))
		assert_not_null(spatial,"seed %d: %s"%[seed_value,WarrenVolumetricSolver.last_failure])


func _layout(turn: int, hand: int) -> WarrenMazeSourcePlan:
	var excavation := WarrenExcavation.new(17)
	excavation.transitions.append({"from":_turn(Vector3i(3,2,3),turn,hand),
		"to":_turn(Vector3i(1,3,3),turn,hand),"kind":WarrenVolumeTransition.Kind.STAIR})
	var source := WarrenMazeSourcePlan.new(17,
		WarrenVillageScaleProfile.for_id(&"compact"),null,excavation)
	var cells: Array[Vector2i] = []
	for x in [1,2]:
		for z in [4,5]:
			var cell := _turn(Vector3i(x,2,z),turn,hand)
			cells.append(Vector2i(cell.x,cell.z))
	source.plots.append({"id":&"court","kind":WarrenMazeSourcePlan.PLOT_DECK,
		"cells":cells,"floor":2,"top":2,"door_walk":_turn(Vector3i(2,2,3),turn,hand)})
	return source


func _turn(cell: Vector3i, turn: int, hand: int) -> Vector3i:
	cell.z *= hand
	for i in turn: cell = Vector3i(-cell.z,cell.y,cell.x)
	return cell+Vector3i(17,0,-11)
