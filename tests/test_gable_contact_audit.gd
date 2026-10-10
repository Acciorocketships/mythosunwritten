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

func test_buried_native_gable_face_is_not_an_exterior_hole() -> void:
	var kit := SuntailBuildingKit.create()
	var built := _junction(kit,false,false)
	var result := AUDIT.audit(built,kit)
	assert_eq(int(result.gable_holes),0,str(result.examples))

func test_native_face_enclosure_in_both_packs_and_all_directions() -> void:
	for kit in [SuntailBuildingKit.create(),PureVillageBuildingKit.roof_study()]:
		for mirrored in [false,true]:
			for transposed in [false,true]:
				var result := AUDIT.audit(_junction(kit,mirrored,transposed),kit)
				assert_eq(int(result.gable_holes),0,str([kit.kit_id,mirrored,transposed,result.examples]))
				assert_eq(int(result.open_exposed),0,str(result.examples))

func test_missing_native_gable_is_still_reported() -> void:
	var kit := SuntailBuildingKit.create()
	var built := _junction(kit,false,false)
	var original := AUDIT.audit(built,kit)
	var pieces: Array[Dictionary] = []
	for placement: Dictionary in built.placements:
		if not String(placement.role).begins_with("gable."):
			pieces.append(placement)
	built.placements = pieces
	assert_gt(int(AUDIT.audit(built,kit).gable_holes),int(original.gable_holes),
		"Removing real wall panels must expose additional holes, even with a neighbouring attic.")

func test_trimmed_face_without_its_enclosing_attic_is_a_real_hole() -> void:
	var kit := SuntailBuildingKit.create()
	var built := _junction(kit,false,false)
	var ctx := AUDIT.UNION.prepare(built.roofs,built.walls,kit,built.get("roof_kits",{})).duplicate(true)
	var cutter_index := -1
	var target := -1
	for i in built.roofs.size():
		if built.roofs[i].rect==Rect2i(0,0,2,2): cutter_index=i
		if built.roofs[i].rect==Rect2i(-4,0,4,4): target=i
	assert_gte(cutter_index,0)
	assert_gte(target,0)
	if cutter_index<0 or target<0: return
	var pieces: Array[Dictionary] = []
	for placement: Dictionary in built.placements:
		if int(placement.get("roof_index",-1))!=target: continue
		var copy := placement.duplicate(true)
		if String(copy.role).begins_with("gable."):
			# Preserve the actual cut while moving away the attic that hid it.
			copy["clip_volumes"] = [ctx.enclosed[cutter_index]]
		pieces.append(copy)
	ctx.enclosed[cutter_index] = {"planes":[],"bounds":AABB(Vector3.ONE*1e6,Vector3.ZERO)}
	ctx.roofs[cutter_index].rect.position += Vector2i(100,100)
	assert_gt(AUDIT._gable_holes(built.roofs[target],1,target,pieces,ctx),1,
		"The same removed outer plaster must be detected once the enclosing attic is absent.")

func test_frozen_court43_has_no_exposed_gable_hole() -> void:
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var source := frozen.read("res://tests/fixtures/october5-court43-gable-source.txt")
	var spatial := frozen.spatial(source,SettlementFabricProgram.compile(EnvironmentCatalog.load_default()))
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	assert_eq(int(AUDIT.audit(built,kit).gable_holes),0)
