extends GutTest
const TOWERS := preload("res://scripts/terrain/features/villages/kit/KitTownTowers.gd")

func test_tower_requires_stacked_rooms_not_just_multiple_wings() -> void:
	var mass := BuildingMass.new()
	mass.storeys.append({"floor_band":0,"cells":{Vector2i.ZERO:true}})
	assert_false(TOWERS.has_tower_storeys(mass))
	mass.storeys.append({"floor_band":2,"cells":{Vector2i(2,0):true}})
	assert_false(TOWERS.has_tower_storeys(mass),"Two cottages on different datums are still short houses")
	mass.storeys.append({"floor_band":2,"cells":{Vector2i.ZERO:true}})
	assert_true(TOWERS.has_tower_storeys(mass))

func test_reported_town_keeps_towers_only_on_stacked_houses() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(7,{},program,WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial==null:return
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
	assert_gt(built.towers.size(),0,"The rule does not remove towers from eligible taller houses")
	for tower: Dictionary in built.towers:
		assert_true(TOWERS.has_tower_storeys(tower.host),"No tower on a single-storey host")
