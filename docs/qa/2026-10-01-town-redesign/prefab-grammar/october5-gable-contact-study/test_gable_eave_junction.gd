extends GutTest
const PureVillageBuildingKit = preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const AUDIT = preload("res://tests/fixtures/kit_roof_audit.gd")

func _junction(kit: BuildingKit, mirrored: bool, transposed: bool) -> Dictionary:
	var mass := BuildingMass.new()
	mass.seed = 8
	mass.stable_id = &"gable-junction"
	var low := BuildingMass.rect_cells(Rect2i(-4,0,4,4))
	var high := BuildingMass.rect_cells(Rect2i(0,-2,2,4))
	var base := low.duplicate()
	base.merge(high)
	mass.add_storey(0,base,BuildingMass.MATERIAL_TIMBER)
	mass.add_storey(2,high,BuildingMass.MATERIAL_TIMBER)
	for spec in [[Rect2i(-4,0,4,4),0,2],[Rect2i(0,-2,2,2),0,4],[Rect2i(0,0,2,2),1,4]]:
		mass.roofs.append({"rect":spec[0],"axis":spec[1],"eave_band":spec[2],"colour":&"blue",
			"open_min":false,"open_max":false,"extend_min":0,"extend_max":0,"dormers":{},"ridge_peaks":false})
	for storey: Dictionary in mass.storeys:
		var moved := {}
		for cell: Vector2i in storey.cells:
			if mirrored: cell.x = -cell.x-1
			if transposed: cell = Vector2i(cell.y,cell.x)
			moved[cell] = true
		storey.cells = moved
	for roof: Dictionary in mass.roofs:
		var rect: Rect2i = roof.rect
		if mirrored: rect.position.x = -rect.end.x
		if transposed:
			rect = Rect2i(Vector2i(rect.position.y,rect.position.x),Vector2i(rect.size.y,rect.size.x))
			roof.axis = 1-int(roof.axis)
		roof.rect = rect
	return AUDIT.assemble([mass],kit)

func test_taller_cross_roof_does_not_strip_the_exposed_gable() -> void:
	var kit := SuntailBuildingKit.create()
	var built := _junction(kit,false,false)
	var result := AUDIT.audit(built,kit)
	assert_eq(int(result.gable_holes),0,str(result.examples))

func test_both_packs_close_the_junction_in_all_directions() -> void:
	for kit in [SuntailBuildingKit.create(),PureVillageBuildingKit.roof_study()]:
		for mirrored in [false,true]:
			for transposed in [false,true]:
				var result := AUDIT.audit(_junction(kit,mirrored,transposed),kit)
				assert_eq(int(result.gable_holes),0,str([kit.kit_id,mirrored,transposed,result.examples]))
				assert_eq(int(result.open_exposed),0,str(result.examples))
