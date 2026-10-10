extends GutTest

# October 3 owner correction supersedes the original October 2 spawn rule.
# Keep the asset-envelope test for library compatibility; generated spires
# now belong only to the full tower/host fitting pipeline.
func test_seeded_buildings_do_not_add_independent_spire_appliques() -> void:
	var kit := SuntailBuildingKit.create()
	var bays := 0
	for seed_value in range(1,21):
		var mass := BuildingDesigner.new(kit).design_standalone(seed_value)
		for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			assert_ne(part.role,&"bay.spire")
			bays+=int(String(part.role).begins_with("bay."))
	assert_gt(bays,0,"Removing the rejected spire must retain ordinary projecting windows")

func test_oriel_respects_the_whole_spire_envelope_not_only_its_window_storey() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,3,3)),&"stone")
	var upper := mass.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,3,3)),&"timber")
	var designer := BuildingDesigner.new(kit)
	var slot: Dictionary = designer.slots_of(mass,upper)[1]
	assert_true(designer._oriel_clear(mass,slot,2))
	designer.forbidden = func(_cell: Vector2i,band: int) -> bool: return band==5
	assert_false(designer._oriel_clear(mass,slot,2),"an overhead walk or neighbour blocks the spire even above the window")
	designer.forbidden = func(_cell: Vector2i,band: int) -> bool: return band==2
	assert_false(designer._oriel_clear(mass,slot,2),"the bay may not occupy a street beside its floor")
	var actual := EnvironmentCatalog.load_default().descriptor(&"pure_village.bay.spire").measured_aabb
	assert_true(actual.position.is_equal_approx(kit.oriel_bounds.position))
	assert_true(actual.size.is_equal_approx(kit.oriel_bounds.size),"the complete baked support, window, backing and roof determine clearance")

func test_real_towns_do_not_restore_the_rejected_spire_appliques() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var count := 0
	for case: Array in [[13,&"large"],[7,&"standard"],[58,&"large"]]:
		var spatial := WarrenVolumetricSolver.generate(case[0],{},program,WarrenVillageScaleProfile.for_id(case[1]))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial==null: continue
		var kit := SuntailBuildingKit.create()
		var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
		assert_true((built.payload as EnvironmentInstancePayload).validate())
		for part: Dictionary in built.placements:
			if part.role!=&"bay.spire": continue
			count += 1
			var bounds: AABB = (part.transform*catalog.descriptor(part.asset_id).measured_aabb).grow(-0.01)
			for volume: Dictionary in built.walls:
				if not bool(volume.get("open",false)): continue
				assert_false(bounds.intersects(volume.bounds),"the complete spire stays outside finished public headroom")
	assert_eq(count,0,"Owner rejected independent facade spires; full native towers have separate coverage")
