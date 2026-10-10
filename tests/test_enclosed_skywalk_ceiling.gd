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
