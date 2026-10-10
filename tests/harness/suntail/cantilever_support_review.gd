extends "res://tests/harness/suntail/building_gallery.gd"
func _run()->void:
	get_root().size=Vector2i(1200,900)
	var kit:=preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
	var mass:=BuildingMass.new()
	mass.stable_id=&"cantilever.fixture"
	mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,3,3)),BuildingMass.MATERIAL_TIMBER)
	mass.add_storey(2,BuildingMass.rect_cells(Rect2i(0,0,4,3)),BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(Rect2i(0,0,4,3),0,4,&"blue")
	var payload:=EnvironmentInstancePayload.new()
	BuildingKitAssembler.append_to_payload(BuildingKitAssembler.new(kit).assemble(mass),Transform3D.IDENTITY,payload)
	var stage:=_stage()
	await _commit(stage,payload)
	await _shoot(stage,Vector3(18,6,13),Vector3(5,4,3),"support",50)
	await _shoot(stage,Vector3(12,2.8,10),Vector3(6,2.5,3),"support-close",50)
	quit()
