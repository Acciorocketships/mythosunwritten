extends GutTest

const FIT := preload("res://scripts/terrain/features/villages/kit/KitRoofEaveFits.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func panel(height := 1.0) -> Dictionary:
	return {
		"vertices":
		PackedVector3Array(
			[Vector3.ZERO, Vector3(2, 0, 0), Vector3(2, height, 0), Vector3(0, height, 0)]
		),
		"indices": PackedInt32Array([0, 1, 2, 0, 2, 3]),
		"normals": PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK]),
		"uvs": PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	}


func test_retriangulation_does_not_retract_an_intact_eave() -> void:
	var source := panel()
	var kept := panel()
	kept.indices = PackedInt32Array([0, 1, 3, 1, 2, 3])
	assert_false(
		FIT.removes_surface({"surfaces": [source], "meshes": [kept]}, Transform3D.IDENTITY)
	)


func test_real_trim_loss_is_not_hidden_by_roundoff_or_another_material() -> void:
	var source := panel()
	var cut := UNION.box_volume(AABB(Vector3(-1, .99, -1), Vector3(4, 2, 2)))
	var kept := UNION.trim_surface(source, Transform3D.IDENTITY, [cut])
	assert_true(
		FIT.removes_surface({"surfaces": [source], "meshes": [kept]}, Transform3D.IDENTITY),
		"One centimetre of eave is a real obstruction"
	)
	assert_true(
		FIT.removes_surface(
			{"surfaces": [source, source], "meshes": [panel(1.01), kept]}, Transform3D.IDENTITY
		),
		"An unrelated material's area cannot compensate for a damaged roof skin"
	)
	assert_false(
		FIT.removes_surface(
			{"surfaces": [source], "meshes": [panel(1.0 - UNION.EPS * .1)]}, Transform3D.IDENTITY
		),
		"Sub-precision boundary residue does not require a different assembly"
	)


func test_native_photo_contact_distinguishes_intact_courses_from_the_obstructed_corner() -> void:
	var kit := SuntailBuildingKit.create()
	var source := WarrenMazeSitePlanner.plan(
		85830433957479026, {}, WarrenVillageScaleProfile.for_id(&"compact"), &"", false
	)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial: WarrenSpatialPlan = load("res://tests/fixtures/frozen_maze_source.gd").spatial(
		source, program
	)
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var air: Array[Dictionary] = []
	for wall: Dictionary in built.walls:
		if bool(wall.get("open", false)):
			air.append(wall)
	var wing: Dictionary = built.roofs[0].duplicate(true)
	wing.union_index = 0
	wing.erase("tight_eave")
	wing.erase("tight_eave_sides")
	var mass := BuildingMass.new()
	mass.roofs.append(wing)
	var ctx := UNION.prepare(mass.roofs, air, kit)
	var preserved := 0
	var blocked := 0
	for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
		if not String(part.role).contains(".eave"):
			continue
		var result := UNION.realize(part, ctx)
		if result.is_empty():
			continue
		if FIT.removes_surface(result, part.transform):
			blocked += 1
		else:
			preserved += 1
	assert_gt(
		preserved, 0, "Native courses only re-triangulated by the stair keep their authored profile"
	)
	assert_gt(blocked, 0, "The actual roof–stair clash must still require a repair")
	# The same street passes beneath an interior run, with its verges already
	# joined to host roofs. None of these authored cornices loses material.
	var interior := wing.duplicate(true)
	interior.rect = Rect2i(-1, 4, 2, 2)
	interior.open_min = true
	interior.open_max = true
	var interiors: Array[Dictionary] = [interior]
	assert_eq(
		FIT.fit(interiors, kit, {}, air),
		0,
		"A tangent public surface must not select a different eave assembly"
	)
	assert_false(interior.has("tight_eave"), "Preserve the complete native overhang")
