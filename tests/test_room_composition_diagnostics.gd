extends GutTest

func test_upper_room_contacts_reserve_bearing_across_parcel_ids() -> void:
	var block := WarrenRoomCompositionPlanner._record(&"building", Vector3i.ZERO, 0, 0, 1)
	var occupied: Dictionary = {}
	for cell: Vector3i in block.cells:
		occupied[cell] = &"lower"
	assert_eq(WarrenRoomCompositionPlanner._occupied_bearing_columns_above(block,
		occupied), Rect2i(), "the room's internal storey cells are not upper contacts")
	occupied[Vector3i(-1, 2, -1)] = &"other.parcel"
	occupied[Vector3i(1, 2, 1)] = &"own.parcel"
	occupied[Vector3i(100, 2, 100)] = &"distant.parcel"
	assert_eq(WarrenRoomCompositionPlanner._occupied_bearing_columns_above(block,
		occupied), Rect2i(-1, -1, 3, 3), "both actual contacts constrain the complete room footprint")

func test_inspection_reports_a_floating_room_without_rebuilding_it() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8), Vector3i(16, 16, 16))
	var block := WarrenRoomCompositionPlanner._record(&"tower", Vector3i(0, 4, 0), 0, 1, 2)
	block["source_block_index"] = 1
	var lineages := {&"floating": {"blocks": [block] as Array[Dictionary]}}
	var before := lineages.duplicate(true)
	var facts := WarrenRoomCompositionPlanner.construction_diagnostics(lineages, grid)
	assert_eq(int(facts.unsupported_transition_count), 1)
	assert_eq(lineages, before, "inspection cannot lower, replace or remove the floating room")

func test_exposed_roof_space_belongs_to_its_building_before_upper_rooms_are_selected() -> void:
	var block := WarrenRoomCompositionPlanner._record(&"tower", Vector3i.ZERO, 0, 0, 1)
	var occupied: Dictionary = {}
	for cell: Vector3i in block.cells: occupied[cell] = &"lower"
	occupied[Vector3i(0, 2, 0)] = &"upper"
	var owners: Dictionary = {Vector3i(-1, 2, -1): {&"public.clearance": true}}
	WarrenRoomCompositionPlanner._reserve_block_roof_space(block, &"lower", occupied, owners)
	assert_has(owners[Vector3i(-1, 2, -1)], &"lower")
	assert_has(owners[Vector3i(-1, 2, -1)], &"public.clearance",
		"roof ownership cannot erase another construction reservation")
	assert_does_not_have(owners, Vector3i(0, 2, 0), "an occupied upper room owns this plate")
	assert_does_not_have(owners, Vector3i(0, 1, 0), "internal storey cells are not roof space")
	assert_eq(owners.size(), 3, "the three exposed top cells each publish one reservation")

func test_diagnostics_preserve_complete_optional_and_required_crowns() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8), Vector3i(24, 16, 16))
	var lineages: Dictionary = {}
	for index in 2:
		var blocks: Array[Dictionary] = []
		for storey in 4:
			var block := WarrenRoomCompositionPlanner._record(&"building",
				Vector3i(index * 8, storey * 2, 0), 0, storey, storey + 1)
			block["source_block_index"] = storey
			block["forced"] = index == 1 and storey == 2
			blocks.append(block)
		lineages[StringName("building.%d" % index)] = {"blocks": blocks}
	var before := lineages.duplicate(true)
	var facts := WarrenRoomCompositionPlanner.construction_diagnostics(lineages, grid)
	assert_eq(int(facts.unsupported_transition_count), 0)
	assert_eq(int(facts.overlap_cell_count), 0)
	assert_eq(lineages, before, "neither optional nor required upper storeys may be cut by inspection")

func test_upper_room_underside_owns_only_unoccupied_interface_cells() -> void:
	var block := WarrenRoomCompositionPlanner._record(&"tower", Vector3i(0, 3, 0), 0, 1, 2)
	var occupied: Dictionary = {}
	for cell: Vector3i in block.cells: occupied[cell] = &"upper"
	occupied[Vector3i(0, 2, 0)] = &"existing.bearer"
	var owners: Dictionary = {}
	WarrenRoomCompositionPlanner._reserve_block_underside_space(block, &"upper", occupied, owners)
	assert_eq(owners.size(), 3, "the half-storey phase uses the actual world-space underside")
	assert_has(owners[Vector3i(-1, 2, -1)], &"upper")
	assert_does_not_have(owners, Vector3i(0, 2, 0), "existing bearing keeps its ownership")
	assert_does_not_have(owners, Vector3i(0, 3, 0), "the room's own mass is not reserved twice")

func test_inspection_reports_overlapping_rooms_without_selecting_a_survivor() -> void:
	var grid := WarrenSpatialGrid.new(Vector3i(-8, -2, -8), Vector3i(16, 16, 16))
	var block := WarrenRoomCompositionPlanner._record(&"tower", Vector3i.ZERO, 0, 0, 1)
	block["source_block_index"] = 0
	var lineages := {&"left": {"blocks": [block] as Array[Dictionary]},
		&"right": {"blocks": [block.duplicate(true)] as Array[Dictionary]}}
	var before := lineages.duplicate(true)
	var facts := WarrenRoomCompositionPlanner.construction_diagnostics(lineages, grid)
	assert_eq(int(facts.overlap_cell_count), 8)
	assert_eq(lineages, before, "inspection must retain both invalid owners for the test to diagnose")
