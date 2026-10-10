extends GutTest
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")

func test_turret_shafts_leave_inhabited_bridge_routes_and_endpoints_clear() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var shaft_count := 0
	for case: Array in [[13,&"large"],[31,&"large"],[43,&"grand"]]:
		var spatial := WarrenVolumetricSolver.generate(case[0],{},program,WarrenVillageScaleProfile.for_id(case[1]))
		assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
		if spatial==null:continue
		var kit := SuntailBuildingKit.create()
		var fabric := spatial.compiled_fabric_cache()
		var circulation := CLEARANCE.inhabited_bridge_rooms(spatial,kit)
		assert_gt(circulation.size(),0)
		var built := KitVillageBuildings.build(spatial,fabric,kit)
		assert_true(built.payload.validate())
		assert_eq(int(KitFloatingMassAudit.audit(spatial,fabric,built.masses).count),0)
		assert_eq(int(preload("res://tests/fixtures/kit_roof_public_air_audit.gd").audit(built,kit).intrusions),0)
		for tower: Dictionary in built.towers:
			shaft_count+=1
			for room_air: Dictionary in circulation:
				assert_false((tower.bounds as AABB).intersects(room_air.bounds),"Private bridge rooms and endpoint rooms carry a through-route")
	assert_gt(shaft_count,0,"Keep fitting towers where the complete native shaft is clear")

func test_inhabited_route_clearance_is_not_a_roof_cutting_volume() -> void:
	var spatial := WarrenSpatialPlan.new(&"fixture",0,null)
	var building := WarrenBuildingVolume.new(&"fixture",2)
	var bridge := WarrenRoomStamp.new(&"fixture",&"fixture",&"room",Vector3i.ZERO,0,0,false,false)
	bridge.stable_id=&"bridge"
	bridge.private_cells.assign([Vector3i(0,4,0),Vector3i(0,5,0)])
	bridge.audit["bridge_support_room_ids"]=[&"near",&"far"]
	building.room_records.append(bridge)
	for item: Array in [[&"near",-1],[&"far",1]]:
		var room := WarrenRoomStamp.new(&"fixture",&"fixture",&"room",Vector3i.ZERO,0,0,false,false)
		room.stable_id=item[0]
		room.private_cells.assign([Vector3i(item[1],2,0),Vector3i(item[1],3,0),Vector3i(item[1],4,0),Vector3i(item[1],5,0)])
		building.room_records.append(room)
	spatial.buildings.append(building)
	var kit := SuntailBuildingKit.create()
	var air := CLEARANCE.inhabited_bridge_rooms(spatial,kit)
	assert_eq(air.size(),3,"The span and both endpoints at the shared passage level")
	for volume: Dictionary in air:
		assert_eq((volume.bounds as AABB).position.y,4*kit.band_height())
		assert_false(volume.has("planes"),"This reservation only rejects optional shafts; it never slices the passage walls")
