extends GutTest

func _house(axis:int)->BuildingMass:
	var mass:=BuildingMass.new()
	var a:=Rect2i(2,14,6,2)
	var b:=Rect2i(0,16,8,2)
	if axis==1:
		a=Rect2i(a.position.y,a.position.x,a.size.y,a.size.x)
		b=Rect2i(b.position.y,b.position.x,b.size.y,b.size.x)
	mass.add_roof(a,axis,4,&"blue")
	mass.add_roof(b,axis,4,&"blue")
	return mass

func _coverage(mass:BuildingMass)->Dictionary:
	var out:={}
	for roof:Dictionary in mass.roofs:
		for cell:Vector2i in BuildingMass.rect_cells(roof.rect):
			out[cell]=int(out.get(cell,0))+1
	return out

func test_unequal_ranges_keep_the_notched_footprint_and_end_wing():
	for axis in 2:
		var mass:=_house(axis)
		var original:=_coverage(mass)
		var masses:Array[BuildingMass]=[mass]
		assert_eq(KitRoofJunctions.combine_parallel(masses,func(_a,_b,_r,_axis,_band):return true),1)
		assert_eq(_coverage(mass),original,"Joining cannot fill a courtyard notch or double-roof a cell")
		assert_eq(mass.roofs.size(),2,"One main range and the original projecting end")
		assert_true(mass.roofs.any(func(r:Dictionary)->bool:return r.rect.get_area()==24))
		assert_eq(KitRoofJunctions.combine_parallel(masses,func(_a,_b,_r,_axis,_band):return true),0)

func test_refused_envelope_preserves_original_ranges():
	var mass:=_house(0)
	var original:=mass.roofs.duplicate(true)
	var masses:Array[BuildingMass]=[mass]
	assert_eq(KitRoofJunctions.combine_parallel(masses,func(_a,_b,_r,_axis,_band):return false),0)
	assert_eq(mass.roofs,original)


func test_column_bounds_include_native_ridge_spikes():
	var Union=preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var checked:=0
	var catalog:=EnvironmentCatalog.load_default()
	for kit:BuildingKit in [SuntailBuildingKit.create(),preload('res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd').roof_study()]:
		for depth in range(2,5):
			for axis in 2:
				var mass:=BuildingMass.new()
				var rect:=Rect2i(0,0,6,depth) if axis==0 else Rect2i(0,0,depth,6)
				var roof:=mass.add_roof(rect,axis,4,&'red')
				roof.ridge_peaks=true
				var parts:=BuildingKitAssembler.new(kit).assemble(mass)
				var ctx:=Union.prepare(mass.roofs,[],kit)
				var max_error:=-INF

				for part:Dictionary in parts:
					if not ctx.data.has(part.asset_id):continue
					for surface:Dictionary in ctx.data[part.asset_id]:
						for vertex:Vector3 in surface.vertices:
							var point:Vector3=part.transform*vertex
							var row:=clampi(floori(point[2 if axis==0 else 0]/kit.module_width),0,depth-1)
							var bound:=KitRoofJunctions.column_clearance_height(kit,depth,row,KitRoofJunctions.ridge_clearance_head(kit,catalog))
							var error:=point.y-4*kit.band_height()-bound
							max_error=maxf(max_error,error)
							checked+=1
				assert_lte(max_error,0.0001,"Column bounds include native slopes, gables and ridge spikes: %s depth %d axis %d" % [kit.kit_id,depth,axis])
	assert_gt(checked,100000)
