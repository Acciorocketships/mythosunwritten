extends GutTest

func test_required_entrances_are_reserved_before_optional_building_envelopes() -> void:
	for seed_value in [8,9]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},
			WarrenVillageScaleProfile.select(seed_value),&"",false)
		assert_not_null(source,WarrenMazeSitePlanner.last_failure)
		if source == null: continue
		assert_true(source.validate_construction(),source.last_rejection)
		assert_gte(source.excavation.portals.size(),2)

func test_perimeter_streets_do_not_orbit_reserved_gardens() -> void:
	for seed_value in [7,17,24,32]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},
			WarrenVillageScaleProfile.for_id(&"large"),&"",false)
		assert_not_null(source,WarrenMazeSitePlanner.last_failure)
		if source == null: continue
		assert_true(source.validate_construction(),source.last_rejection)
		for lane: Dictionary in source.excavation.lanes:
			if lane.get("feature_kind",&"") != &"perimeter": continue
			for cell: Vector3i in lane.cells:
				assert_false(source.massif.is_reserved_ground(Vector2i(cell.x,cell.z)),
					"gardens allow direct access but must not grow perimeter road circuits")

func test_existing_gate_count_prevents_redundant_access_lanes() -> void:
	var source := WarrenMazeSitePlanner.plan(24,{},
		WarrenVillageScaleProfile.for_id(&"large"),&"",false)
	assert_not_null(source)
	if source == null: return
	var before := source.excavation.lanes.duplicate(true)
	var added := WarrenMazeCarver._carve_secondary_gate_lanes(24,source.massif,
		source.excavation,source.excavation.route[0],source.scale_profile)
	assert_true(added.is_empty())
	assert_eq(source.excavation.lanes,before)

func test_open_district_connection_does_not_add_turns_to_satisfy_alley_style() -> void:
	var massif := WarrenMassif.new(1)
	for x in range(11):
		for z in range(-1,2):
			massif.columns[Vector2i(x,z)] = {"base":0,"top":2,"reserved_ground":true}
	var excavation := WarrenExcavation.new(1)
	excavation.route.assign([Vector3i.ZERO])
	var public := {Vector3i.ZERO:true}
	var route := WarrenMazeCarver._level_gate_connection(massif,excavation,public,public,Vector3i(10,0,0),true)
	assert_false(route.is_empty())
	assert_eq(route.cells.size(),10,"Open-ground access should attain the Manhattan lower bound.")
	for cell: Vector3i in route.cells: assert_eq(cell.z,0,"No gratuitous side jog.")

func test_reserved_cottage_gets_one_short_direct_entrance() -> void:
	var massif := WarrenMassif.new(1)
	for x in range(10):
		for z in range(-1,3):
			massif.columns[Vector2i(x,z)] = {"base":0,"top":4,"reserved_ground":true}
	for column: Vector2i in [Vector2i(8,0),Vector2i(9,0),Vector2i(8,1),Vector2i(9,1)]:
		massif.columns[column] = {"base":0,"top":4,"house_site":1,"house_storeys":1}
	var excavation := WarrenExcavation.new(1)
	excavation.route.assign([Vector3i.ZERO,Vector3i.RIGHT])
	excavation.transitions.append({"from":Vector3i.ZERO,"to":Vector3i.RIGHT,"kind":WarrenVolumeTransition.Kind.LEVEL})
	WarrenMazeCarver._carve_house_site_access(massif,excavation,{})
	assert_eq(excavation.lanes.size(),1)
	if excavation.lanes.size()!=1: return
	var lane: Dictionary = excavation.lanes[0]
	assert_eq(lane.cells.size(),6,"Shortest approach from x=1 to the cottage doorstep at x=7.")
	for cell: Vector3i in lane.cells: assert_eq(cell.z,0,"No garden circuit or side jog.")
	WarrenMazeCarver._carve_house_site_access(massif,excavation,{})
	assert_eq(excavation.lanes.size(),1,"Existing frontage needs no additional entrance.")
	var source := WarrenMazeSourcePlan.new(1,WarrenVillageScaleProfile.for_id(&"compact"),massif,excavation)
	assert_eq(source._max_alley_straight_run(),0,"Cottage access is not constrained by dense-alley cadence.")
