extends GutTest
const RECESS = preload("res://scripts/terrain/features/villages/kit/KitRetainingRecesses.gd")
const CONTACTS = preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
func test_recess_preserves_outer_envelope_and_rejects_inward_passage():
	var catalog := EnvironmentCatalog.load_default()
	var context := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	var id := &"pure_village.wall.stone.plain"
	var before: AABB = catalog.descriptor(id).measured_aabb
	for yaw in [0.0,PI/2,PI,3*PI/2]:
		var original := Transform3D(Basis(Vector3.UP,yaw),Vector3(5,3,7))
		var wall := {"asset_id":id,"transform":original}
		assert_true(RECESS.replace(wall,catalog,[],context))
		var local: AABB = original.affine_inverse()*wall.transform*catalog.descriptor(wall.asset_id).measured_aabb
		assert_almost_eq(local.end.z,before.end.z,0.001,"No projection into street")
		assert_almost_eq(local.size.x,before.size.x,0.001)
		assert_almost_eq(local.end.y,before.end.y,0.001)
		assert_false(RECESS.replace(wall,catalog,[],context),"Do not replace a panel twice")
		var blocked := {"asset_id":id,"transform":original}
		var air: Array[Dictionary] = [{"bounds":original*AABB(Vector3(-0.5,1,-0.29),Vector3(1,1,0.08))}]
		assert_false(RECESS.replace(blocked,catalog,air,context),"A rear passage rejects the added inward depth")
		assert_eq(blocked.asset_id,id)

func test_existing_roof_cannot_cover_recessed_glazing():
	var catalog := EnvironmentCatalog.load_default()
	var ctx := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	ctx.volumes = [preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd").box_volume(AABB(Vector3(-1,0,-1),Vector3(2,3,2)))]
	var wall := {"asset_id":&"pure_village.wall.stone.plain","transform":Transform3D.IDENTITY}
	assert_false(RECESS.replace(wall,catalog,[],ctx))

func test_real_town_uses_recesses_on_blocked_projecting_window_sites():
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var source := WarrenMazeSitePlanner.plan(7,{},WarrenVillageScaleProfile.for_id(&"standard"),&"",false)
	var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	assert_gt(int(built.roof_audit.retaining_recesses),0,"The native town uses the new wall-panel fallback")
	var context := CONTACTS.prepare(built.roofs,kit,built.roof_kits,built.walls)
	for part: Dictionary in built.placements:
		if not part.get("retaining_recess",false): continue
		assert_eq(part.role,&"wall.stone.retaining","Replacement remains part of the structural facade")
		assert_eq(part.asset_id,RECESS.WINDOW)
		assert_false(CONTACTS.obstructed(part.asset_id,part.transform,context))

func test_recess_rejects_contact_with_native_header_above_clear_glass():
	var catalog := EnvironmentCatalog.load_default()
	var ctx := CONTACTS.prepare([],SuntailBuildingKit.create(),{})
	assert_eq(ctx.frames[RECESS.WINDOW].size(),5,"The stone opening carries five authored timber components")
	var vertices := PackedVector3Array([Vector3(-1,2.3,-1),Vector3(1,2.3,-1),Vector3(1,2.3,1),Vector3(-1,2.3,1)])
	ctx.skins = [{"vertices":vertices,"indices":PackedInt32Array([0,1,2,0,2,3]),"bounds":AABB(Vector3(-1,2.299,-1),Vector3(2,0.002,2))}]
	var old := ctx.duplicate()
	old.frames = {}
	var plain := {"asset_id":&"pure_village.wall.stone.plain","transform":Transform3D.IDENTITY}
	assert_true(RECESS.replace(plain.duplicate(),catalog,[],old),"Glazing-only admission misses this header contact")
	assert_false(RECESS.replace(plain,catalog,[],ctx),"Whole native header must remain clear")
	assert_eq(plain.asset_id,&"pure_village.wall.stone.plain","Rejected candidate leaves its backing intact")
