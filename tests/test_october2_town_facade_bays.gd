extends GutTest
const BAYS := preload("res://scripts/terrain/features/villages/kit/KitTownFacadeBays.gd")

func _host() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.host"
	mass.seed = 3
	for band in [0,2,4]:
		var storey := mass.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,8,4)),BuildingMass.MATERIAL_TIMBER)
		storey.default_opening = BuildingMass.OPENING_WINDOW
		storey.bay_colour = &"red"
	return mass

func test_complete_supported_bays_fit_above_paths_but_not_inside_them() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var host := _host()
	var doors := Vector3i(3,0,3)
	host.storeys[1].openings[doors] = BuildingMass.OPENING_DOOR
	var low: Array[Dictionary] = [{"bounds":AABB(Vector3(-5,0,-5),Vector3(30,1.2,20))}]
	var admitted := BAYS.fit([host],{&"host":kit},kit,catalog,low,[],Callable())
	assert_gt(admitted.size(),0)
	assert_eq(host.storeys[1].openings[doors],BuildingMass.OPENING_DOOR)
	for bay: Dictionary in admitted:
		assert_false(bay.bounds.intersects(low[0].bounds))
		assert_eq(bay.bounds,bay.pose*catalog.descriptor(bay.asset_id).measured_aabb)
	assert_eq(BAYS.fit([host],{&"host":kit},kit,catalog,low,[],Callable()).size(),0,"Repeating the pass cannot accumulate more bays.")
	var blocked := _host()
	var original := blocked.storeys.duplicate(true)
	var high: Array[Dictionary] = [{"bounds":AABB(Vector3(-5,0,-5),Vector3(30,20,20))}]
	assert_true(BAYS.fit([blocked],{&"host":kit},kit,catalog,high,[],Callable()).is_empty())
	assert_eq(blocked.storeys,original,"Rejected candidates cannot replace facade openings.")

func test_tower_and_private_reservations_win_over_optional_facade_relief() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	assert_true(BAYS.fit([_host()],{&"host":kit},kit,catalog,[],[],
		func(_own:StringName,_cell:Vector2i,_band:int)->bool:return true).is_empty())
	var tower: Array[Dictionary] = [{"bounds":AABB(Vector3(-5,0,-5),Vector3(30,20,20))}]
	assert_true(BAYS.fit([_host()],{&"host":kit},kit,catalog,[],tower,Callable()).is_empty())
