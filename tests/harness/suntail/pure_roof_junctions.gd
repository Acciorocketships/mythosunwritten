extends "res://tests/harness/suntail/building_gallery.gd"
## Native and mixed-family junctions through the production union and commit.
func _run() -> void:
	get_root().size = Vector2i(1600,900)
	var pure := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
	var suntail := SuntailBuildingKit.create()
	var pairs := [[pure,pure],[pure,suntail],[suntail,pure]]
	for pair_index in pairs.size():
		for shape in 2:
			var stage := _stage()
			var a := BuildingMass.new()
			var b := BuildingMass.new()
			a.stable_id = &"host"
			b.stable_id = &"branch"
			var ra := Rect2i(0,0,6,4)
			var rb := Rect2i(2,4,2,3) if shape == 0 else Rect2i(6,0,3,2)
			for floor_band in [0,2]:
				a.add_storey(floor_band,BuildingMass.rect_cells(ra),&"timber")
				b.add_storey(floor_band,BuildingMass.rect_cells(rb),&"timber")
			a.add_roof(ra,0,4,&"red")
			b.add_roof(rb,1 if shape == 0 else 0,4,&"red")
			var masses: Array[BuildingMass] = [a,b]
			KitRoofJunctions.join(masses)
			var roofs: Array[Dictionary] = [a.roofs[0],b.roofs[0]]
			var placements: Array[Dictionary] = []
			for i in 2:
				roofs[i].union_index = i
				placements.append_array(BuildingKitAssembler.new(pairs[pair_index][i]).assemble(masses[i]))
			var payload := EnvironmentInstancePayload.new()
			preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").append(
				placements,roofs,[],suntail,Transform3D.IDENTITY,payload,{0:pairs[pair_index][0],1:pairs[pair_index][1]})
			await _commit(stage,payload)
			var centre := Vector3(7,8,5)
			await _shoot(stage,centre+Vector3(16,15,22),centre,"pair%d_shape%d_above" % [pair_index,shape],50)
			await _shoot(stage,centre+Vector3(17,-3,19),centre,"pair%d_shape%d_street" % [pair_index,shape],60)
			stage.queue_free()
			await process_frame
	print("PURE_JUNCTIONS_DONE ",_out)
	quit()
