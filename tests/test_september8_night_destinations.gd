extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_both_photographed_terminal_stairs_have_broad_destinations() -> void:
	for fixture: String in ["september7-manual-source.txt", "september8-night-center-source.txt"]:
		var original := Frozen.read("res://tests/fixtures/" + fixture)
		var source := WarrenMazeCarver.carve(original.world_seed, original.massif, original.scale_profile, false, false)
		assert_not_null(source, fixture)
		if source == null: continue
		assert_eq(source.excavation.route, original.excavation.route, "Keep the photographed itinerary")
		var cells: Array[Vector3i] = []
		for feature: Dictionary in source.feature_stamps:
			if feature.kind == &"terminal_lookout": cells.assign(feature.cells)
		assert_eq(cells.size(), 4, "The destination needs a full square, not a bent walkway: " + fixture)
		if cells.is_empty(): continue
		var bounds := AABB(Vector3(cells[0]), Vector3.ZERO)
		for cell: Vector3i in cells: bounds = bounds.expand(Vector3(cell))
		assert_gte(bounds.size.x, 1.0, "Destination must widen across the walkway")
		assert_gte(bounds.size.z, 1.0, "Destination must have usable depth")
		assert_true(cells.has(source.excavation.route.back()))
		for cell: Vector3i in cells:
			assert_true(source.excavation.public_cells().has(cell))
			for band in range(cell.y, cell.y + WarrenExcavation.HEADROOM_BANDS):
				assert_true(source.excavation.carved.has(Vector3i(cell.x, band, cell.z)))
		WarrenPlotPlanner.reserve(source, source.scale_profile)
		WarrenPlotPlanner.partition(source, source.scale_profile)
		source.finish_construction(false)
		var volume := WarrenMazeVolumeAdapter.to_volume_plan(source)
		assert_not_null(volume, WarrenMazeVolumeAdapter.last_failure)
		if volume == null: continue
		assert_eq(volume.terminal_lookout_cells.size(), cells.size())
		for cell: Vector3i in cells:
			assert_true(volume.envelope.contains_air_column(cell, WarrenVolumePlan.HEADROOM_BANDS), "Envelope includes terrace standing clearance " + str(cell))
			assert_true(volume.has_walk(cell))
		assert_true(volume._has_one_terminal_lookout())
		assert_eq(volume._same_datum_public_square_count(), 0, "Only the typed terrace receives the broad-floor exemption")

func test_widened_terrace_does_not_put_a_fence_across_the_rear_house_wall() -> void:
	var original := Frozen.read("res://tests/fixtures/september7-manual-source.txt")
	var source := WarrenMazeCarver.carve(original.world_seed,original.massif,original.scale_profile,false,false)
	WarrenPlotPlanner.reserve(source,source.scale_profile)
	WarrenPlotPlanner.partition(source,source.scale_profile)
	source.finish_construction(false)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var fabric := Frozen.spatial(source,program).compiled_fabric_cache()
	var blocked := 0
	for segment: Dictionary in fabric.surface_plan.guard_segments:
		if String(segment.stable_key) in ["2:5:2:0:-1", "3:5:2:0:-1"]: blocked += 1
	assert_eq(blocked,0,"The full-height native house wall already encloses the terrace")

func test_wall_boundary_keeps_guards_at_parapets_and_open_gaps() -> void:
	for quarter in 4:
		var pose := Transform3D(Basis(Vector3.UP,float(quarter)*PI*0.5),Vector3.ZERO)
		var segment := {"a":pose*Vector3(-0.75,0,0),"b":pose*Vector3(0.75,0,0)}
		var plan := PublicRealmSurfacePlan.new(&"guard-wall-extent")
		plan.finish_transition_guards([pose*AABB(Vector3(-0.8,0,-0.2),Vector3(1.6,2,0.4))] as Array[AABB])
		assert_true(plan._guard_is_backed_by_wall(segment),"Full-height wall encloses the complete edge")
		plan.finish_transition_guards([pose*AABB(Vector3(-0.8,0,-0.2),Vector3(1.6,0.5,0.4))] as Array[AABB])
		assert_false(plan._guard_is_backed_by_wall(segment),"A low parapet keeps the guard")
		plan.finish_transition_guards([pose*AABB(Vector3(-0.8,0,-0.2),Vector3(0.6,2,0.4)),pose*AABB(Vector3(0.2,0,-0.2),Vector3(0.6,2,0.4))] as Array[AABB])
		assert_false(plan._guard_is_backed_by_wall(segment),"An open gap keeps the guard")
		plan.finish_transition_guards([pose*AABB(Vector3(-0.8,0,-0.2),Vector3(0.8,2,0.4)),pose*AABB(Vector3(0,0,-0.2),Vector3(0.8,2,0.4))] as Array[AABB])
		assert_true(plan._guard_is_backed_by_wall(segment),"Two joining wall modules enclose one edge")

func test_terrace_clearance_measures_the_whole_lower_flight_in_all_directions() -> void:
	var columns: Dictionary = {}
	for x in range(-2,3):
		for z in range(-2,3): columns[Vector2i(x,z)]={"base":0,"top":8}
	var massif := WarrenMassif.with_columns(17,columns,8)
	massif.finish_construction()
	for forward: Vector3i in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]:
		var excavation := WarrenExcavation.new(17)
		excavation.transitions.append({"from":-forward,"to":forward+Vector3i.UP,"kind":WarrenVolumeTransition.Kind.STAIR})
		assert_false(WarrenMazeCarver._terminal_lookout_slot(massif,excavation,Vector3i(0,2,0)),"A deck cannot intrude on the upper tread's standing clearance")
		assert_true(WarrenMazeCarver._terminal_lookout_slot(massif,excavation,Vector3i(0,3,0)),"A thin deck may bridge a flight with the full public headroom below")
