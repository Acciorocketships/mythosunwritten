extends GutTest
const UNION = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

func test_cap_ends_where_eave_covers_its_bearing() -> void:
	var mesh := {"vertices": PackedVector3Array([Vector3(0,1,0),Vector3(2,1,0),Vector3(0,1,2)]),
		"normals": PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]),
		"uvs": PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP]),
		"indices": PackedInt32Array([0,1,2])}
	var cap := AABB(Vector3(0.2,0.8,0.2),Vector3(0.3,0.8,2))
	var cuts := UNION._ridge_eave_cutters(mesh,cap)
	assert_eq(cuts.size(),1)
	var covered := Vector3(0.3,1.5,0.3)
	for plane: Plane in cuts[0].planes:
		assert_lte(plane.distance_to(covered),0.0,"Covered cap tip must end even above the covering skin")
	var exposed := Vector3(0.3,1.2,2.1)
	var outside := false
	for plane: Plane in cuts[0].planes: outside = outside or plane.distance_to(exposed)>0
	assert_true(outside,"Exposed ridge continues outside the eave")
	assert_true(UNION._ridge_eave_cutters(mesh,AABB(Vector3(0,2,0),Vector3.ONE)).is_empty(),"An eave below the cap cannot terminate it")
	mesh.normals = PackedVector3Array([Vector3.DOWN,Vector3.DOWN,Vector3.DOWN])
	assert_true(UNION._ridge_eave_cutters(mesh,cap).is_empty(),"The underside is not a covering skin")

func test_contact_fitting_only_changes_the_foreign_ridge() -> void:
	var surface := {"vertices": PackedVector3Array([Vector3(0,1,0),Vector3(2,1,0),Vector3(0,1,2)]),
		"normals": PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]),
		"uvs": PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP]),
		"indices": PackedInt32Array([0,1,2])}
	var ridge := surface.duplicate(true)
	ridge.vertices = PackedVector3Array([Vector3(0.2,0.8,0.2),Vector3(0.5,1.5,0.2),Vector3(0.2,1.5,2.2)])
	var kit := SuntailBuildingKit.create()
	var ctx := {"data": {&"eave": [surface], &"ridge": [ridge]}, "kit": kit, "roof_kits": {},
		"roofs": [{"eave_band":1,"axis":1},{"eave_band":0,"axis":1}], "walls": [], "volumes": [], "enclosed": [],
		"clips": [[],[]], "gable_clips": [[],[]]}
	var parts: Array[Dictionary] = [
		{"asset_id":&"eave","role":&"roof.red.eave","roof_index":0,"transform":Transform3D.IDENTITY},
		{"asset_id":&"ridge","role":&"trim.ridge","roof_index":1,"transform":Transform3D.IDENTITY},
		{"asset_id":&"ridge","role":&"trim.ridge","roof_index":0,"transform":Transform3D.IDENTITY}]
	UNION.fit_ridge_contacts(parts,ctx)
	assert_false(parts[0].has("clip_volumes"),"Keep the covering authored eave intact")
	assert_true(parts[1].has("clip_volumes"),"Fit the other roof's cap")
	assert_false(parts[2].has("clip_volumes"),"Do not cut a roof's own cap")
	assert_false(UNION.realize(parts[1],ctx).is_empty(),"The fitting reaches the emitted geometry")

func test_contact_terminates_all_flutes_across_cap_width() -> void:
	var mesh := {"vertices": PackedVector3Array([Vector3(0,1,0),Vector3(0.3,1,0),Vector3(0,1,1)]),
		"normals": PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]),
		"uvs": PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP]),
		"indices": PackedInt32Array([0,1,2])}
	var cap := AABB(Vector3(0,0.8,0),Vector3(0.7,0.8,2))
	var cuts := UNION._ridge_eave_cutters(mesh,cap,1)
	assert_eq(cuts.size(),1)
	assert_true(UNION._ridge_eave_cutters(mesh,cap,1,0.7).is_empty(),"Higher pitch faces must not notch another ridge")
	for plane: Plane in cuts[0].planes:
		assert_lte(plane.distance_to(Vector3(0.65,1.5,0.2)),0.0,"No separate cap tip remains across the contact's width")
	assert_lt(cuts[0].bounds.end.z,cap.end.z,"The exposed longitudinal run remains")
