extends GutTest
const WINDOWS = preload("res://scripts/terrain/features/villages/kit/KitRetainingWindows.gd")
func test_closed_native_panels_keep_structural_backing_and_clearance() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.retained"
	var storey := mass.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,6,3)),BuildingMass.MATERIAL_STONE)
	storey.retaining = true
	var before := storey.duplicate(true)
	var backing := BuildingKitAssembler.new(kit).assemble(mass)
	var parts := WINDOWS.fit([mass],backing,kit,catalog,[],[])
	assert_gt(parts.size(),0)
	assert_true(WINDOWS.fit([mass],[],kit,catalog,[],[]).is_empty(),"A planned face without an emitted wall cannot support ornaments.")
	assert_eq(storey,before,"Decorative panels cannot excavate the backing or invent rooms.")
	for part: Dictionary in parts:
		assert_eq(part.transform.basis.get_scale(),Vector3.ONE)
		assert_true(part.collision)
		assert_eq(part.bounds,part.transform*catalog.descriptor(part.asset_id).measured_aabb)
		assert_gte(part.bounds.position.y,2*kit.band_height())
		assert_lte(part.bounds.end.y,4*kit.band_height())
	var air: Array[Dictionary] = [{"bounds":AABB(Vector3(-100,-100,-100),Vector3(200,200,200))}]
	assert_true(WINDOWS.fit([mass],backing,kit,catalog,air,[]).is_empty())
	assert_true(WINDOWS.fit([mass],backing+parts,kit,catalog,[],[]).is_empty())

func test_real_retaining_panels_keep_original_native_geometry() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := WarrenVolumetricSolver.generate(41,{},program,WarrenVillageScaleProfile.for_id(&"large"))
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	assert_gt(int(built.roof_audit.retaining_windows),0)
	for part: Dictionary in built.placements:
		if part.get("role",&"")!=&"retaining.window": continue
		assert_eq(part.transform.basis.get_scale(),Vector3.ONE)
		for wall: Dictionary in built.walls:
			if wall.get("open",false): assert_false(part.bounds.intersects(wall.bounds))
		for other: Dictionary in built.placements:
			if other.get("role",&"")!=&"retaining.corbel": continue
			assert_false(part.bounds.intersects(other.bounds),"Competing facade treatments must not overlap.")
	assert_true(built.payload.validate())


func test_two_module_pier_can_carry_a_whole_backed_native_panel() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.retained"
	var storey := mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0,0,2,2)), BuildingMass.MATERIAL_STONE)
	storey.retaining = true
	var backing := BuildingKitAssembler.new(kit).assemble(mass)
	var parts := WINDOWS.fit([mass], backing, kit, catalog, [], [])
	assert_gt(parts.size(), 0, "A supported narrow pier need not remain a blank masonry box")
	for part: Dictionary in parts:
		assert_eq(part.transform.basis.get_scale(), Vector3.ONE)
		assert_eq(part.bounds, part.transform * catalog.descriptor(part.asset_id).measured_aabb)
	assert_true(WINDOWS.fit([mass], [], kit, catalog, [], []).is_empty())
	var air: Array[Dictionary] = [{"bounds": AABB(Vector3(-100,-100,-100), Vector3(200,200,200))}]
	assert_true(WINDOWS.fit([mass], backing, kit, catalog, air, []).is_empty())
