extends GutTest

func test_enclosed_crossing_has_a_complete_native_timber_ceiling() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	for width in [1,2]:
		for step in [Vector3i.RIGHT,Vector3i.BACK]:
			var span := {"cell":Vector3i(1,2,-14),"step":step,"gap":2,"width":width,
				"cross":Vector3i(step.z,0,step.x),"enclosed":true}
			var mass := KitVillageBuildings._skywalk_mass(span,43)
			var parts := BuildingKitAssembler.new(kit).assemble(mass)
			var top := float(mass.top_band())*kit.band_height()
			var covered := {}
			for part: Dictionary in parts:
				if part.role != &"deck.board":continue
				var box: AABB = part.transform*catalog.descriptor(part.asset_id).measured_aabb
				if absf(box.end.y-top)>0.2:continue
				assert_gte(box.position.y-2*kit.band_height(),TraversalEnvelope.MIN_HEADROOM/VillageWorldScale.VERTICAL_SCALE)
				for cell: Vector2i in mass.storeys[0].cells:
					var center := Vector3((cell.x+0.5)*kit.module_width,box.get_center().y,(cell.y+0.5)*kit.module_width)
					if box.has_point(center):covered[cell]=true
			assert_eq(covered.size(),mass.storeys[0].cells.size(),"Close the attic over every passage bay with kit timber")

func test_open_crossing_keeps_open_sky() -> void:
	var mass := KitVillageBuildings._skywalk_mass({"cell":Vector3i.ZERO,"step":Vector3i.RIGHT,"gap":2,"width":1,"enclosed":false},43)
	assert_true(mass.storeys.is_empty())
	assert_true(mass.roofs.is_empty())

func test_roof_foot_does_not_enter_an_equal_height_endpoint_room() -> void:
	var kit := SuntailBuildingKit.create()
	var bridge := KitVillageBuildings._skywalk_mass({"cell":Vector3i(1,2,-14),"step":Vector3i.RIGHT,"gap":2,"width":1,"enclosed":true},43)
	var host := BuildingMass.new()
	host.stable_id = &"endpoint"
	host.add_storey(2,BuildingMass.rect_cells(Rect2i(4,-14,2,1)),BuildingMass.MATERIAL_TIMBER)
	var audit := preload("res://tests/fixtures/kit_roof_audit.gd")
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var built := audit.assemble([bridge,host],kit)
	var ctx := union_script.prepare(built.roofs,built.walls,kit)
	var room := AABB(Vector3(8.02,3.1,-27.98),Vector3(3.96,2.88,1.96))
	var intrusion := 0
	for part: Dictionary in built.placements:
		if int(part.get("roof_index",-1))<0:continue
		var realized := union_script.realize(part,ctx)
		var meshes: Array = ctx.data.get(part.asset_id,[]) if realized.is_empty() else realized.meshes
		for mesh: Dictionary in meshes:
			for point: Vector3 in mesh.vertices:
				var placed: Vector3 = part.transform*point if realized.is_empty() else point
				if room.has_point(placed):intrusion+=1
	assert_eq(intrusion,0,"No roof skin or trim inside the endpoint room below its ceiling")
