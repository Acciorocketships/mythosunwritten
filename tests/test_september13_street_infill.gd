extends GutTest

const Frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
const PHOTO := "res://docs/qa/2026-09-13-manual/14-deck-purpose/current-source.txt"
const GAP := Vector3i(2,0,1)

func test_unused_ground_parcel_inside_four_streets_becomes_public() -> void:
	var source := Frozen.read(PHOTO,false)
	var plots := var_to_str(source.plots)
	var route := source.excavation.route.duplicate()
	WarrenMazeSitePlanner.finish_ground_streets(source)
	assert_true(source.passage_kinds.has(GAP),"P23: the enclosed unused parcel must join the surrounding street")
	assert_true(GAP in source.excavation.public_cells(),"The paving must be an actual public destination")
	assert_eq(var_to_str(source.plots),plots,"Existing plots and addresses remain fixed")
	assert_eq(source.excavation.route,route,"The original itinerary remains fixed")
	assert_true(source.excavation.validate_construction(),source.excavation.last_rejection)

func test_reclaimed_parcel_compiles_to_four_ground_street_cells() -> void:
	var source := Frozen.read(PHOTO,false)
	WarrenMazeSitePlanner.finish_public_destinations(source)
	WarrenMazeSitePlanner.finish_ground_streets(source)
	source.finish_construction()
	assert_true(source.validate_construction(),source.last_rejection)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := Frozen.spatial(source,program)
	var streets := spatial.compiled_fabric_cache().surface_plan.cells_for_kind(
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET)
	for dx in 2:
		for dz in 2:
			assert_true(Vector3i(GAP.x*2+dx,GAP.y,GAP.z*2+dz) in streets,
				"All four native floor cells must share the public ground classification")

func test_intentional_deck_or_house_column_is_not_reclaimed() -> void:
	for kind: StringName in [&"deck",&"house"]:
		var source := Frozen.read(PHOTO,false)
		source.plots.append({"id":&"protected","kind":kind,"cells":[Vector2i(GAP.x,GAP.z)],"floor":0,"top":2})
		WarrenMazeSitePlanner.finish_ground_streets(source)
		assert_false(source.passage_kinds.has(GAP),"An allocated %s owns its column" % kind)

func test_open_sided_space_and_upper_courts_are_not_filled() -> void:
	var source := Frozen.read(PHOTO,false)
	source.passage_kinds.erase(GAP+Vector3i.RIGHT)
	WarrenMazeSitePlanner.finish_ground_streets(source)
	assert_false(source.passage_kinds.has(GAP),"An open lawn is not an enclosed street gap")
	source=Frozen.read(PHOTO,false)
	for direction: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		source.passage_kinds.erase(GAP+direction)
		source.passage_kinds[GAP+direction+Vector3i.UP*4]=&"alley"
	WarrenMazeSitePlanner.finish_ground_streets(source)
	assert_false(source.passage_kinds.has(GAP+Vector3i.UP*4),"Upper courtyards require real structural support")
