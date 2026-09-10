extends GutTest

func test_deep_doorway_owns_a_whole_panel_and_the_return_ends_at_its_back() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var room := program.recipe(&"room.tower.base.rock")
	var front: Dictionary = room.facade_end_owners[&"south"]
	assert_eq(room.realized_facade_asset({"id":&"south","asset_id":front.base_asset},[]),
		front.base_asset,"the complete door panel must close both deep reveal corners")
	var side: Dictionary = room.facade_end_owners[&"east"]
	assert_true(String(room.realized_facade_asset({"id":&"east","asset_id":side.base_asset},[])).contains(".doorreturn."),
		"the side wall must meet the actual back of the doorway instead of an open diagonal cut")

func test_removed_party_wall_cannot_leave_an_unserved_corner_cut() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var room := program.recipe(&"room.tower.base.rock")
	var plan := SettlementFabricPlan.new(&"party.fixture")
	assert_true(plan.register_recipe(room))
	var unit := FabricUnit.new(&"room",room.recipe_id,Vector3i.ZERO,0)
	plan.units.append(unit)
	unit.suppressed_placement_ids.assign([&"west", &"east"])
	for placement: Dictionary in plan.expanded_placements():
		if placement.placement_id == &"south":
			assert_eq(placement.asset_id, &"sfv.fabric.wall.rock.door.closed.005",
				"without either side wall the front panel needs two square party ends")

func test_timber_facades_use_the_same_owned_corner_join_as_rock() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for recipe_id: StringName in [&"room.tower.upper.blue", &"room.tower.base.rock"]:
		var room := program.recipe(recipe_id)
		assert_not_null(room)
		if room == null: continue
		for face: StringName in [&"north", &"south", &"east", &"west"]:
			assert_true(room.facade_end_owners.has(face),
				"%s/%s must join its perpendicular neighbours without full-depth overlap" % [recipe_id, face])

func test_separated_facade_details_do_not_fill_the_empty_corner_between_rooms() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var plan := SettlementFabricPlan.new(&"reported.empty.corner")
	plan.register_recipe(program.recipe(&"room.row.upper.blue.f"))
	plan.register_recipe(program.recipe(&"room.tower.upper.blue.d"))
	plan.append_constructed_unit(FabricUnit.new(&"row", &"room.row.upper.blue.f", Vector3i(5,6,3),1))
	var tower := FabricUnit.new(&"tower", &"room.tower.upper.blue.d", Vector3i(7,8,1),0)
	plan.append_constructed_unit(tower)
	assert_eq(plan.visual_envelope_conflicts().size(), 0,
		"the two combined room bounds overlap in empty space; no authored pieces do")
	tower.lattice_origin = Vector3i(6,7,3)
	assert_gt(plan.visual_envelope_conflicts().size(), 0,
		"moving the tower into the row must still expose the real module collision")
