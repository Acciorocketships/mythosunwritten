extends GutTest

static func mass_at_step() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.seed = 8
	mass.stable_id = &"backed-shed"
	mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,3)),BuildingMass.MATERIAL_TIMBER)
	mass.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,2,2)),BuildingMass.MATERIAL_TIMBER)
	return mass

func test_narrow_lower_crown_meets_tall_wall_as_shed() -> void:
	var mass := mass_at_step()
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden = func(cell: Vector2i, _band: int) -> bool: return not Rect2i(0,0,2,3).has_point(cell)
	designer._assign_roofs(mass,designer._rng(8),&"red")
	var sheds := 0
	for roof: Dictionary in mass.roofs:
		if int(roof.eave_band)!=2: continue
		assert_gte(mini(roof.rect.size.x,roof.rect.size.y),2,"Use a complete native slope into the higher wall, not a miniature double pitch.")
		if roof.get("backed_shed",false): sheds+=1
	assert_eq(sheds,1)

func test_shed_cannot_close_an_upper_door() -> void:
	var mass := mass_at_step()
	mass.storeys[1].openings[BuildingMass.edge_key(Vector2i(0,1),1)] = BuildingMass.OPENING_DOOR
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	assert_true(designer._backed_shed(mass,Rect2i(0,2,2,1),2).is_empty())

func test_shed_keeps_public_headroom_and_needs_a_flush_wall() -> void:
	var mass := mass_at_step()
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden = func(cell:Vector2i,band:int)->bool:return cell.y==2 and band==3
	assert_true(designer._backed_shed(mass,Rect2i(0,2,2,1),2).is_empty())
	designer.forbidden=Callable()
	mass.storeys[1].inset=true
	assert_true(designer._backed_shed(mass,Rect2i(0,2,2,1),2).is_empty())

func test_native_shed_parts_stop_at_the_backing_wall() -> void:
	var audit := preload("res://tests/fixtures/kit_roof_audit.gd")
	for kit in [SuntailBuildingKit.create(),preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()]:
		var mass := mass_at_step()
		var designer := BuildingDesigner.new(kit)
		designer.forbidden=func(cell:Vector2i,_band:int)->bool:return not Rect2i(0,0,2,3).has_point(cell)
		designer._assign_roofs(mass,designer._rng(8),&"red")
		var built := audit.assemble([mass],kit)
		var ctx := audit.UNION.prepare(built.roofs,built.walls,kit)
		var escaped := 0
		var vertices := 0
		for part:Dictionary in built.placements:
			var index := int(part.get("roof_index",-1))
			if index<0 or not built.roofs[index].get("backed_shed",false):continue
			var realized := audit.UNION.realize(part,ctx)
			if realized.is_empty():
				for surface:Dictionary in ctx.data[part.asset_id]:
					for point:Vector3 in surface.vertices:
						vertices+=1
						if (part.transform*point).z<4.0-0.002:escaped+=1
			else:
				for mesh:Dictionary in realized.meshes:
					for point:Vector3 in mesh.vertices:
						vertices+=1
						if point.z<4.0-0.002:escaped+=1
		assert_gt(vertices,0,"The lower crown retains a real roof.")
		assert_eq(escaped,0,"No hidden uphill gable or trim can poke through the higher roof.")

func test_wall_backed_shed_has_no_freestanding_ridge_caps() -> void:
	var mass := mass_at_step()
	var kit := SuntailBuildingKit.create()
	var designer := BuildingDesigner.new(kit)
	designer.forbidden=func(cell:Vector2i,_band:int)->bool:return not Rect2i(0,0,2,3).has_point(cell)
	designer._assign_roofs(mass,designer._rng(8),&"red")
	var built := preload("res://tests/fixtures/kit_roof_audit.gd").assemble([mass],kit)
	var caps := 0
	for part:Dictionary in built.placements:
		var index := int(part.get("roof_index",-1))
		if index>=0 and built.roofs[index].get("backed_shed",false) and String(part.role).begins_with("trim.ridge"):caps+=1
	assert_eq(caps,0,"The uphill end terminates against a wall; it is not a freestanding ridge.")

func test_backing_and_clip_follow_mirrored_and_transposed_wings() -> void:
	for mirrored in [false,true]:
		for transposed in [false,true]:
			var mass := mass_at_step()
			for storey:Dictionary in mass.storeys:
				var moved := {}
				for original:Vector2i in storey.cells:
					var cell := original
					if mirrored: cell.y=-cell.y-1
					if transposed: cell=Vector2i(cell.y,cell.x)
					moved[cell]=true
				storey.cells=moved
			var strip := Rect2i(0,-3 if mirrored else 2,2,1)
			if transposed: strip=Rect2i(Vector2i(strip.position.y,strip.position.x),Vector2i(1,2))
			var kit:=SuntailBuildingKit.create()
			var candidate:=BuildingDesigner.new(kit)._backed_shed(mass,strip,2)
			assert_false(candidate.is_empty())
			if candidate.is_empty():continue
			var wing:Dictionary={"axis":candidate.axis}
			wing[candidate.cut_key]=candidate.cut_at
			var clips:=preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").clip_volumes(wing,kit)
			assert_eq(clips.size(),1)
			var exposed:=Vector3((strip.position.x+.5)*kit.module_width,4,(strip.position.y+.5)*kit.module_width)
			var backing:=exposed
			backing[0 if transposed else 2]+=kit.module_width*(1 if mirrored else -1)
			assert_false(preload("res://tests/fixtures/kit_roof_audit.gd")._inside(clips[0],exposed))
			assert_true(preload("res://tests/fixtures/kit_roof_audit.gd")._inside(clips[0],backing))
