extends GutTest

func _mass(depth:int=1)->BuildingMass:
	var mass:=BuildingMass.new()
	mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,3,3)),BuildingMass.MATERIAL_TIMBER)
	mass.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,3+depth,3)),BuildingMass.MATERIAL_TIMBER)
	return mass

func test_native_brackets_bear_at_wall_joints_under_one_module_upper_room()->void:
	var kit:=SuntailBuildingKit.create()
	var parts:=BuildingKitAssembler.new(kit).assemble(_mass())
	var brackets:=parts.filter(func(p:Dictionary)->bool:return p.role==&"bracket.cantilever")
	assert_eq(brackets.size(),4,"Four unique joints, not three window centres")
	var seen:Dictionary={}
	for p:Dictionary in brackets:
		var t:Transform3D=p.transform
		assert_true(t.basis.get_scale().is_equal_approx(Vector3.ONE),"Native support must not be stretched")
		assert_almost_eq(t.origin.x,6.0+kit.wall_face,.001)
		assert_almost_eq(t.origin.y,3.04,.001)
		assert_true(t.origin.z in [0.0,2.0,4.0,6.0])
		assert_false(seen.has(t.origin));seen[t.origin]=true
		assert_true(t.basis.z.is_equal_approx(Vector3.RIGHT))

func test_longer_overhang_does_not_get_short_unconnected_brackets()->void:
	var parts:=BuildingKitAssembler.new(SuntailBuildingKit.create()).assemble(_mass(2))
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role==&"bracket.cantilever").size(),0)

func test_blocked_brackets_are_omitted_whole_without_removing_the_room()->void:
	var assembler:=BuildingKitAssembler.new(SuntailBuildingKit.create())
	assembler.ornament_clear=func(_id:StringName,_at:Transform3D)->bool:return false
	var parts:=assembler.assemble(_mass())
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role==&"bracket.cantilever").size(),0)
	assert_gt(parts.filter(func(p:Dictionary)->bool:return String(p.role).begins_with("wall.")).size(),0)

func test_generated_cantilever_brackets_clear_public_headroom()->void:
	var catalog:=EnvironmentCatalog.load_default()
	var kit:=SuntailBuildingKit.create()
	var program:=SettlementFabricProgram.compile(catalog)
	var spatial:=WarrenVolumetricSolver.generate(7,{},program,WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(spatial,WarrenVolumetricSolver.last_failure)
	if spatial==null:return
	var fabric:=spatial.compiled_fabric_cache()
	var built:=KitVillageBuildings.build(spatial,fabric,kit)
	var clearance:=preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
	var air:=clearance.build(spatial,fabric,kit)
	var count:=0
	for part:Dictionary in built.placements:
		if part.role!=&"bracket.cantilever":continue
		count+=1
		assert_false(clearance.intersects_air(catalog.descriptor(part.asset_id).measured_aabb,part.transform,air),String(part.stable_id))
	assert_gt(count,0,"Visible supports must survive actual-town clearance")

func test_support_placement_rotates_with_the_building()->void:
	var kit:=SuntailBuildingKit.create()
	for rotation in range(1,4):
		var mass:=_mass()
		for floor:Dictionary in mass.storeys:
			var cells:Dictionary={}
			for original:Vector2i in floor.cells:
				var cell:=original
				for turn in rotation:cell=Vector2i(-cell.y-1,cell.x)
				cells[cell]=true
			floor.cells=cells
		var expected:Dictionary={}
		for along in 4:
			var point:=Vector3(6.0+kit.wall_face,3.04,float(along)*2)
			for turn in rotation:point=Vector3(-point.z,point.y,point.x)
			expected[point.snapped(Vector3.ONE*.0001)]=true
		var count:=0
		for part:Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if part.role!=&"bracket.cantilever":continue
			count+=1
			assert_true(expected.has((part.transform as Transform3D).origin.snapped(Vector3.ONE*.0001)))
		assert_eq(count,4)

func test_neighbor_supported_floor_is_not_a_cantilever()->void:
	var assembler:=BuildingKitAssembler.new(SuntailBuildingKit.create())
	assembler.external_blocked=func(cell:Vector2i,band:int)->bool:return cell.x==3 and band<2
	var parts:=assembler.assemble(_mass())
	assert_eq(parts.filter(func(p:Dictionary)->bool:return p.role==&"bracket.cantilever").size(),0,"A neighboring room already carries the floor")
