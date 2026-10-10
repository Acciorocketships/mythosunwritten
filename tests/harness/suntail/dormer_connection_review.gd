extends "res://tests/harness/suntail/building_gallery.gd"
## Complete roofs using the native overlay dormer connection in each palette.
func _run() -> void:
	get_root().size=Vector2i(1200,900)
	for palette:StringName in [&"native",&"wood_blue",&"wood_red",&"sage"]:
		var kit:=preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
		if palette!=&"native":preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd").apply(kit,palette)
		var mass:=BuildingMass.new()
		mass.stable_id=StringName("dormer.review."+String(palette))
		mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,4,4)),BuildingMass.MATERIAL_TIMBER)
		var wing:=mass.add_roof(Rect2i(0,0,4,4),0,2,&"blue")
		wing.dormers={Vector2i(0,1):true,Vector2i(1,2):true}
		var payload:=EnvironmentInstancePayload.new()
		BuildingKitAssembler.append_to_payload(BuildingKitAssembler.new(kit).assemble(mass),Transform3D.IDENTITY,payload)
		var stage:=_stage()
		await _commit(stage,payload)
		await _shoot(stage,Vector3(-6,12,18),Vector3(4,4,4),String(palette),45)
		stage.queue_free()
		await process_frame
	quit()
