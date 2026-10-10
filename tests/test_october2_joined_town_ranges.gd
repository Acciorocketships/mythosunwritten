extends GutTest

func test_current_town_keeps_bearing_and_public_headroom() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(13,{},program,
		WarrenVillageScaleProfile.for_id(&"large"))
	assert_not_null(spatial)
	if spatial == null: return
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
	var floating := KitFloatingMassAudit.audit(spatial,spatial.compiled_fabric_cache(),built.masses)
	assert_eq(int(floating.count),0,"the joined building keeps real bearing")
	var air := preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,SuntailBuildingKit.create())
	assert_eq(int(air.intrusions),0,"the larger roof preserves public headroom")


# Preserve the photographed pair itself; its original addresses no longer
# occur in seed 13 after the street and clearing layout changed.
func test_reported_two_four_by_two_lots_form_one_complete_roof() -> void:
	var houses := {&"house.032": _lot(Rect2i(-2,16,4,2)),
		&"house.033": _lot(Rect2i(-2,18,4,2))}
	for seed_value in range(16):
		var merged := KitVillageBuildings.merge_houses(houses,seed_value)
		assert_eq(merged.size(),1,"small adjoining ranges combine for every seed")
		if merged.size()!=1: continue
		var house: Dictionary = merged.values()[0]
		assert_eq(house.cells.size(),32,"both full storeys survive")
		assert_eq(house.doors.size(),2,"both original addresses survive")
		var mass := BuildingMass.new()
		mass.stable_id = &"kit.joined-pair"
		mass.seed = seed_value
		mass.ground_band = 0
		var storey := mass.add_storey(0,house.storeys[0],BuildingMass.MATERIAL_TIMBER)
		storey["roofed"] = house.roof_crowns[0]
		storey["crown_parts"] = house.crown_parts[0]
		BuildingDesigner.new(SuntailBuildingKit.create()).articulate(mass,
			{"terrain_storey":0,"terraced":true})
		assert_eq(mass.roofs.size(),1,"one roof replaces parallel twin gables")
		if mass.roofs.size()==1:
			assert_eq((mass.roofs[0].rect as Rect2i).get_area(),16,"roof covers both footprints")


func _lot(rect: Rect2i) -> Dictionary:
	var footprint := BuildingMass.rect_cells(rect)
	var cells: Array[Vector3i] = []
	for cell: Vector2i in footprint:
		cells.append(Vector3i(cell.x,0,cell.y))
		cells.append(Vector3i(cell.x,1,cell.y))
	return {"cells":cells,"storeys":{0:footprint},"terrain_band":0,
		"landmark":false,"doors":[{"cell":Vector3i(rect.position.x,0,rect.position.y),
			"direction":Vector3i.LEFT}]}
