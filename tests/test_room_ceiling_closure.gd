extends GutTest
const Closure = preload("res://scripts/terrain/features/villages/kit/KitRoomCeilings.gd")


func _room() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_TIMBER)
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.covered = func(_cell: Vector2i, _band: int) -> bool: return true
	designer.articulate(mass, {"terrain_storey": 0})
	return mass


func test_retaining_occupancy_does_not_leave_a_room_open() -> void:
	var room := _room()
	assert_true(room.roofs.is_empty())
	var stone := BuildingMass.new()
	stone.add_storey(2, room.storeys[0].cells, BuildingMass.MATERIAL_STONE)["retaining"] = true
	var masses: Array[BuildingMass] = [room, stone]
	assert_eq(Closure.close(masses), 4)
	assert_eq(room.decks.size(), 1)
	assert_false(room.decks[0].rails)
	assert_eq(room.decks[0].band, 2)
	assert_eq(Closure.close(masses), 0, "Closure is idempotent")
	var parts := BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(room)
	var boards := parts.filter(
		func(p: Dictionary) -> bool:
			return p.role == &"deck.board" and is_equal_approx(p.transform.origin.y, 3.0)
	)
	assert_eq(boards.size(), 4, "Native boards actually close the top")


func test_real_upper_room_floor_owns_the_shared_interface() -> void:
	var room := _room()
	var upper := BuildingMass.new()
	upper.add_storey(2, room.storeys[0].cells, BuildingMass.MATERIAL_TIMBER)
	var masses: Array[BuildingMass] = [room, upper]
	assert_eq(Closure.close(masses), 0)
	assert_true(room.decks.is_empty(), "No duplicate coplanar boards under another room floor")


func test_partial_upper_floor_only_replaces_its_own_ceiling_cells() -> void:
	var room := _room()
	var upper := BuildingMass.new()
	upper.add_storey(2, {Vector2i.ZERO: true}, BuildingMass.MATERIAL_TIMBER)
	var masses: Array[BuildingMass] = [room, upper]
	assert_eq(Closure.close(masses), 3)
	assert_false(room.decks[0].cells.has(Vector2i.ZERO))
	assert_eq(room.decks[0].cells.size(), 3)


func test_reported_301_room_is_closed_without_changing_its_rooms() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		301, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
	)
	assert_not_null(spatial)
	if spatial == null:
		return
	var built := KitVillageBuildings.build(
		spatial, spatial.compiled_fabric_cache(), SuntailBuildingKit.create()
	)
	var found := false
	for mass: BuildingMass in built.houses:
		if mass.stable_id != &"kit.spatial.parcel.maze.house.006":
			continue
		found = true
		assert_eq(mass.storeys.size(), 1)
		assert_eq(mass.storeys[0].floor_band, 3)
		var covered := {}
		for deck: Dictionary in mass.decks:
			if deck.band == 5:
				covered.merge(deck.cells)
		assert_eq(
			covered.size(), 12, "All twelve room modules receive a ceiling beneath the stone span"
		)
	assert_true(found)
