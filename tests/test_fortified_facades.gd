extends GutTest

const FACADES := preload("res://scripts/terrain/features/villages/kit/KitFortifiedFacades.gd")
const RECESS := preload("res://scripts/terrain/features/villages/kit/KitRetainingRecesses.gd")
const CONTACTS := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")


func _wall(pose: Transform3D, id := &"kit.platform-wall/test") -> Dictionary:
	return {
		"asset_id": &"pure_village.wall.stone.plain",
		"transform": pose,
		"role": &"wall.fort",
		"stable_id": id
	}


func test_native_window_replaces_full_facade_in_each_orientation() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var context := CONTACTS.prepare([], kit, {})
	for yaw: float in [0.0, PI / 2, PI, 3 * PI / 2]:
		var basis := Basis(Vector3.UP, yaw)
		var pose := Transform3D(basis, basis * Vector3(kit.module_width * 1.5, 0, 0))
		var parts: Array[Dictionary] = [_wall(pose)]
		assert_eq(FACADES.fit(parts, kit, catalog, [], context), 1)
		assert_eq(parts[0].asset_id, RECESS.WINDOW)
		assert_eq(parts[0].role, &"wall.fort")
		assert_eq(FACADES.fit(parts, kit, catalog, [], context), 0, "No repeated inward seating")


func test_small_piers_and_neighboring_assets_cannot_admit_a_window() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var context := CONTACTS.prepare([], kit, {})
	for scale: Vector3 in [Vector3(.35, 1, 1), Vector3(1, .5, 1), Vector3(1, 1, .5)]:
		var parts: Array[Dictionary] = [
			_wall(Transform3D(Basis.from_scale(scale), Vector3(3, 0, 0)))
		]
		assert_eq(
			FACADES.fit(parts, kit, catalog, [], context),
			0,
			"Native window cannot be squashed into a pier or half-course"
		)
	var pose := Transform3D(Basis.IDENTITY, Vector3(3, 0, 0))
	var parts: Array[Dictionary] = [_wall(pose), _wall(pose, &"neighbor")]
	assert_eq(
		FACADES.fit(parts, kit, catalog, [], context),
		0,
		"Another facade occupying the frame rejects the window"
	)
	parts = [_wall(pose, &"ordinary-wall/test")]
	assert_eq(
		FACADES.fit(parts, kit, catalog, [], context), 0, "No windows added to unrelated masses"
	)


func test_finished_fortifications_preserve_native_frames_and_public_air() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(catalog)
	for seed_value: int in [63, 83, 103]:
		var spatial := WarrenVolumetricSolver.generate(
			seed_value, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
		)
		assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
		if spatial == null:
			continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, kit)
		assert_gt(int(built.roof_audit.fortified_windows), 0, "Exercise an actual citadel facade")
		var context := CONTACTS.prepare(built.roofs, kit, built.roof_kits, built.walls)
		var ground_windows := 0
		var contacts_count := 0
		var air := (
			preload("res://scripts/terrain/features/villages/kit/KitPublicClearance.gd")
			. build(spatial, fabric, kit)
		)
		for part: Dictionary in built.placements:
			if not part.get("fortified_window", false):
				continue
			ground_windows += int(is_zero_approx(part.transform.origin.y))
			assert_false(
				CONTACTS.obstructed(part.asset_id, part.transform, context),
				"Roof and floor must leave the native opening intact"
			)
			for component: AABB in context.frames[RECESS.WINDOW]:
				var box: AABB = part.transform * component
				for other: Dictionary in built.placements:
					if other == part:
						continue
					contacts_count += int(
						box.intersects(
							other.transform * catalog.descriptor(other.asset_id).measured_aabb
						)
					)
			var original: Transform3D = part.transform
			var plain_box: AABB = catalog.descriptor(&"pure_village.wall.stone.plain").measured_aabb
			var window_box: AABB = catalog.descriptor(RECESS.WINDOW).measured_aabb
			original.origin -= original.basis * Vector3(0, 0, plain_box.end.z - window_box.end.z)
			var plain := _wall(original)
			assert_true(
				RECESS.replace(plain, catalog, air, context),
				"Added inward depth cannot occupy public air"
			)
		assert_eq(contacts_count, 0, "Native frames remain free of trim and neighboring assets")
		if seed_value == 83:
			assert_gt(ground_windows, 0, "Footing must fit below the native ground-storey sill")


func test_obstructed_bay_yields_to_the_next_clear_bay_with_spacing() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var context := CONTACTS.prepare([], kit, {})
	var parts: Array[Dictionary] = []
	for x: float in [1.0, 3.0, 5.0, 7.0]:
		parts.append(
			_wall(
				Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)),
				StringName("kit.platform-wall/" + str(x))
			)
		)
	parts.append(_wall(parts[0].transform, &"neighbor"))
	assert_eq(FACADES.fit(parts, kit, catalog, [], context), 2)
	assert_false(parts[0].get("fortified_window", false), "Occupied bay rejected")
	assert_true(parts[1].get("fortified_window", false), "Next clear bay takes the opening")
	assert_false(parts[2].get("fortified_window", false), "One plain bay separates windows")
	assert_true(parts[3].get("fortified_window", false))
	assert_eq(
		FACADES.fit(parts, kit, catalog, [], context), 0, "Repeated fitting preserves the spacing"
	)
