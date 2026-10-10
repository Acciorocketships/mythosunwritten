extends GutTest

func test_offset_wing_reclaims_its_own_second_crown_row() -> void:
	var crown := BuildingMass.rect_cells(Rect2i(0,1,10,2))
	crown.merge(BuildingMass.rect_cells(Rect2i(6,0,4,1)))
	var mass := BuildingMass.new()
	mass.add_storey(0,crown,BuildingMass.MATERIAL_TIMBER)
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden=func(cell:Vector2i,_band:int)->bool:return not crown.has(cell)
	var rectangles := designer._absorb_slivers(mass,BuildingDesigner.decompose(crown),crown,crown,2)
	assert_eq(BuildingDesigner._slivers(rectangles),0,
		"An offset wing must borrow its own crown row from the long range's packing")
	var covered := {}
	for rect:Rect2i in rectangles:
		for cell:Vector2i in BuildingMass.rect_cells(rect):
			assert_true(crown.has(cell),"Repacking must not borrow external space")
			assert_false(covered.has(cell),"No doubled roof patches")
			covered[cell]=true
	assert_eq(covered.size(),crown.size())

func test_repacking_never_overrides_reserved_roof_air() -> void:
	var crown := BuildingMass.rect_cells(Rect2i(0,1,10,2))
	crown.merge(BuildingMass.rect_cells(Rect2i(6,0,4,1)))
	var mass := BuildingMass.new()
	mass.add_storey(0,crown,BuildingMass.MATERIAL_TIMBER)
	var designer := BuildingDesigner.new(SuntailBuildingKit.create())
	designer.forbidden=func(_cell:Vector2i,band:int)->bool:return band>=2
	var original := BuildingDesigner.decompose(crown)
	assert_eq(designer._repack_slivers(mass,original,crown,2),original,
		"Better silhouette cannot override the roof's existing clearance contract")

func test_repacking_is_valid_on_both_axes_and_mirrored_wings() -> void:
	for flip in [false,true]:
		for mirror in [false,true]:
			var original := BuildingMass.rect_cells(Rect2i(0,1,10,2))
			original.merge(BuildingMass.rect_cells(Rect2i(6,0,4,1)))
			var crown := {}
			for cell:Vector2i in original:
				if mirror:cell.x=-cell.x-1
				if flip:cell=Vector2i(cell.y,cell.x)
				crown[cell]=true
			var mass := BuildingMass.new()
			mass.add_storey(0,crown,BuildingMass.MATERIAL_TIMBER)
			var designer := BuildingDesigner.new(SuntailBuildingKit.create())
			designer.forbidden=func(cell:Vector2i,_band:int)->bool:return not crown.has(cell)
			var result := designer._absorb_slivers(mass,BuildingDesigner.decompose(crown),crown,crown,2)
			assert_eq(BuildingDesigner._slivers(result),0)
			var actual := {}
			for rect:Rect2i in result:actual.merge(BuildingMass.rect_cells(rect))
			assert_eq(actual,crown)
