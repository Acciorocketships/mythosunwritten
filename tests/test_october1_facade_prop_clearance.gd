extends GutTest
const CLEARANCE := preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_rotated_prop_bounds_clear_sloping_walking_air() -> void:
	var mesh := {"vertices":PackedVector3Array([Vector3(0,0,0),Vector3(3,3,0),Vector3(0,0,3)]),
		"normals":PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]),"indices":PackedInt32Array([0,1,2])}
	var air := CLEARANCE.from_mesh(mesh,Transform3D.IDENTITY,2.0)
	var box := AABB(Vector3(-0.1,-0.1,-0.1),Vector3.ONE*0.2)
	assert_true(CLEARANCE.intersects_air(box,Transform3D(Basis(Vector3.UP,0.7),Vector3(1,2,1)),air))
	assert_false(CLEARANCE.intersects_air(box,Transform3D(Basis.IDENTITY,Vector3(1,0,1)),air),"below the stair is not public headroom")
	assert_false(CLEARANCE.intersects_air(box,Transform3D(Basis.IDENTITY,Vector3(2,3,2)),air),"outside the tread triangle is clear")

func test_nested_town_keeps_only_clear_window_boxes_and_doorstep_props() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var spatial := WarrenVolumetricSolver.generate(13,{},SettlementFabricProgram.compile(catalog),WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial)
	if spatial == null: return
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
	var kept := 0
	for part: Dictionary in built.placements:
		if part.role not in [&"window_box",&"prop.doorstep"]: continue
		kept += 1
		assert_false(CLEARANCE.intersects_air(catalog.descriptor(part.asset_id).measured_aabb,part.transform,built.walls),String(part.stable_id))
	assert_gt(kept,20,"retain facade dressing on clear walls")
	assert_gt(int(built.roof_audit.decor_clearance.get(&"window_box",0)),0,"the reproduced stair obstruction removes whole boxes")
