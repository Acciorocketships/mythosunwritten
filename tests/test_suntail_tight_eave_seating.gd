extends GutTest
const U = preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const FIT = preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd")


func test_complete_tight_panel_stays_on_roof_plane_and_out_of_public_air():
	var kit = SuntailBuildingKit.create()
	var geometry = FileAccess.open(kit.roof_geometry_path, FileAccess.READ).get_var()
	var air = U.box_volume(AABB(Vector3(-2, -1, 0), Vector3(4, 3, 2)))
	for colour in SuntailBuildingKit.ROOF_COLOURS:
		var role = StringName("roof.%s.eave_tight" % colour)
		var pose: Transform3D = kit.anchors.get(role, Transform3D.IDENTITY)
		assert_eq(pose.basis, Basis.IDENTITY, "Native panel retains scale and pitch")
		assert_almost_eq(
			pose.origin.y + 1.5 * pose.origin.z, 0.0, 0.00001, "Slide along the authored 3:2 plane"
		)
		var surfaces: Array = geometry[kit.asset(role)]
		var meshes: Array[Dictionary] = []
		for surface in surfaces:
			meshes.append(U.trim_surface(surface, pose, [air]))
		assert_false(
			FIT.removes_surface({"surfaces": surfaces, "meshes": meshes}, pose),
			"Whole tight eave must clear public air at the wall line"
		)
		var old_meshes: Array[Dictionary] = []
		for surface in surfaces:
			old_meshes.append(U.trim_surface(surface, Transform3D.IDENTITY, [air]))
		assert_true(
			FIT.removes_surface({"surfaces": surfaces, "meshes": old_meshes}, Transform3D.IDENTITY),
			"The source panel's protruding foot is a real overlap"
		)


func test_retracted_eave_has_native_fascia_closing_the_wall_head():
	var kit = SuntailBuildingKit.create()
	var catalog = EnvironmentCatalog.load_default()
	var mass = BuildingMass.new()
	mass.stable_id = &"tight-join"
	mass.add_storey(0, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_TIMBER)
	mass.add_roof(Rect2i(0, 0, 2, 2), 0, 2, &"red")
	mass.roofs[0].tight_eave_sides = 1
	var count = 0
	for part in BuildingKitAssembler.new(kit).assemble(mass):
		if part.role != &"trim.eave_tight":
			continue
		count += 1
		assert_eq(part.asset_id, &"suntail.decor.crossbar_2", "Use the existing native timber")
		var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_lte(box.end.z, 4.0, "Fascia stays behind the public wall plane")
		assert_lt(box.position.y, 3.07564, "Fascia overlaps the native wall head")
		assert_gt(box.end.y, 3.18, "Fascia closes the lifted roof foot")
	assert_eq(count, 2, "One contiguous stock beam per wall bay on the tight side")


func test_native_pure_roof_uses_its_own_measured_seat():
	var kit = (
		preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
		. roof_study()
	)
	assert_true(kit.has_role(&"trim.eave_tight"))
	for colour in SuntailBuildingKit.ROOF_COLOURS:
		assert_ne(kit.anchor(StringName("roof.%s.eave_tight" % colour)),
			SuntailBuildingKit.create().anchor(StringName("roof.%s.eave_tight" % colour)))
