extends GutTest

## Pack-agnostic building kit layer: the Suntail kit's roles, the assembler's
## grammar (measured against the pack's own House_1 prefab), designer
## determinism and clearance, and the kit-derived world metric.
const GALLERY := preload("res://tests/harness/suntail/gallery_masses.gd")


func _count_roles(placements: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for placement: Dictionary in placements:
		var role := StringName(placement.role)
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func test_every_suntail_role_resolves_to_a_catalog_asset() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	for asset_id: StringName in kit.all_asset_ids():
		assert_true(catalog.has(asset_id), "catalog lacks %s" % asset_id)


func test_world_frame_realizes_the_kit_metric() -> void:
	assert_true(VillageWorldScale.matches_kit(SuntailBuildingKit.create()))
	var basis := VillageWorldScale.production_basis(0.0)
	var native := KitVillageBuildings.native_to_lattice(SuntailBuildingKit.create())
	var world := basis * native.basis
	# A kit piece renders at one uniform world scale through the frame.
	assert_almost_eq(world.get_scale().x, VillageWorldScale.KIT_WORLD_SCALE, 1e-5)
	assert_almost_eq(world.get_scale().y, VillageWorldScale.KIT_WORLD_SCALE, 1e-5)
	assert_almost_eq(world.get_scale().z, VillageWorldScale.KIT_WORLD_SCALE, 1e-5)


func test_house_one_replica_matches_the_source_prefab_inventory() -> void:
	# Module inventory of assets/Raygeas/Models/Buildings/House_1.glb.
	var placements := BuildingKitAssembler.new(SuntailBuildingKit.create()) \
		.assemble(GALLERY.house_one())
	var roles := _count_roles(placements)
	assert_eq(int(roles.get(&"wall.stone.window", 0)) + int(roles.get(&"wall.stone.plain", 0))
		+ int(roles.get(&"wall.stone.door", 0)), 10, "stone ground walls")
	assert_eq(int(roles.get(&"plinth.stone", 0)), 10, "plinth courses")
	assert_eq(int(roles.get(&"wall.timber.window", 0)) + int(roles.get(&"wall.timber.plain", 0)),
		14, "jettied upper walls")
	assert_eq(int(roles.get(&"bracket.jetty", 0)), 14, "jetty brackets")
	assert_eq(int(roles.get(&"roof.red.eave", 0)) + int(roles.get(&"roof.red.eave_dormer", 0)),
		10, "eave rows")
	assert_eq(int(roles.get(&"roof.red.eave_dormer", 0)), 2, "dormers")
	assert_eq(int(roles.get(&"roof.red.top", 0)), 5, "ridge-top row")
	assert_eq(int(roles.get(&"gable.left", 0)), 2)
	assert_eq(int(roles.get(&"gable.right", 0)), 2)
	assert_eq(int(roles.get(&"gable.small", 0)), 2)
	assert_eq(int(roles.get(&"gable.wall", 0)), 2)
	assert_eq(int(roles.get(&"trim.barge.eave", 0)), 4)
	assert_eq(int(roles.get(&"trim.barge.top", 0)), 2)
	assert_eq(int(roles.get(&"trim.floor_beam", 0)) + int(roles.get(&"trim.floor_beam_corner", 0)),
		14, "jetty floor beams")
	assert_eq(int(roles.get(&"trim.floor_beam_corner", 0)), 4, "one corner beam per corner")


func test_house_one_replica_places_the_ridge_top_where_the_prefab_does() -> void:
	# House_1: Roof_Top_1 at native (x, 10, 0) over an eave at y = 7 and
	# upper walls x in [-4, 4], z in [-3, 3]. The replica's upper storey is the
	# same 4 x 3 module rectangle with its floor at y = 3 (band 2).
	var placements := BuildingKitAssembler.new(SuntailBuildingKit.create()) \
		.assemble(GALLERY.house_one())
	var tops: Array[Vector3] = []
	for placement: Dictionary in placements:
		if placement.role == &"roof.red.top":
			tops.append((placement.transform as Transform3D).origin)
	assert_eq(tops.size(), 5)
	for origin: Vector3 in tops:
		assert_almost_eq(origin.y, 6.0 + 3.0, 1e-4)
		assert_almost_eq(origin.z, 3.0, 1e-4)


func test_assembly_is_deterministic() -> void:
	var kit := SuntailBuildingKit.create()
	var designer := BuildingDesigner.new(kit)
	var a := BuildingKitAssembler.new(kit).assemble(designer.design_standalone(77))
	var b := BuildingKitAssembler.new(kit).assemble(designer.design_standalone(77))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].asset_id, b[i].asset_id)
		assert_eq(a[i].transform, b[i].transform)


func test_blocked_roof_turns_its_ridge_then_becomes_a_terrace() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id = &"test.blocked"
	mass.seed = 5
	mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0, 0, 4, 2)),
		BuildingMass.MATERIAL_TIMBER)
	var designer := BuildingDesigner.new(kit)
	# Everything above the crown is kept clear: no roof can fit.
	designer.forbidden = func(_cell: Vector2i, band: int) -> bool: return band >= 2
	designer.articulate(mass, {"terrain_storey": 0})
	assert_eq(mass.roofs.size(), 0)
	assert_eq(mass.decks.size(), 1)


func test_jetty_insets_every_wall_by_half_a_module() -> void:
	var slots := BuildingKitAssembler.wall_slots(
		BuildingMass.rect_cells(Rect2i(0, 0, 4, 3)), true)
	# A 4 x 3 footprint inset by half a module is a 3 x 2 wall ring.
	assert_eq(slots.size(), 10)
	for slot: Dictionary in slots:
		var centre := slot.centre as Vector2
		assert_true(centre.x >= 0.5 and centre.x <= 3.5)
		assert_true(centre.y >= 0.5 and centre.y <= 2.5)


func test_kit_town_replaces_every_building_room_unit() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(12, {},
		WarrenVillageScaleProfile.for_id(&"compact"), &"", false)
	var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	var replaced: Dictionary = built.replaced_units
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			assert_true(replaced.has(StringName("spatial.fabric.%s" % room.stable_id)),
				"room %s left to the legacy vocabulary" % room.stable_id)
	var payload := KitVillageBuildings.legacy_payload_without(fabric, replaced)
	for asset_id: StringName in payload.asset_ids():
		var id := String(asset_id)
		assert_false(id.contains(".roof.") or id.begins_with("lpfv.building")
			or id.contains("anchor.prefab"), "legacy building art %s survives" % id)
	assert_gt((built.payload as EnvironmentInstancePayload).instance_count, 100)
