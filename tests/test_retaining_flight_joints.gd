extends GutTest
const JOINT = preload("res://scripts/terrain/features/villages/kit/KitRetainingFlightJoints.gd")


func test_native_panels_stay_behind_the_upper_landing_in_each_direction():
	var catalog := EnvironmentCatalog.load_default()
	var id := &"pure_village.wall.stone.plain"
	var local: AABB = catalog.descriptor(id).measured_aabb
	for direction: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
		for descending in [false, true]:
			var low := Vector3i.ZERO
			var high := direction * 3 + Vector3i.UP * 2
			# One-band transition, on top of a full native wall.
			low.y = 1
			var t := WarrenVolumeTransition.new(
				&"flight",
				high if descending else low,
				low if descending else high,
				WarrenVolumeTransition.Kind.RAMP,
				[]
			)
			assert_true(t.seal())
			var ends := WarrenTransitionSurfaceBuilder._span_endpoints(t)
			var upper: Vector3 = ends.start if descending else ends.end
			var out := -Vector3(direction)
			var basis := Basis(Vector3.UP, atan2(out.x, out.z))
			var pose := Transform3D(basis, upper - Vector3.UP * local.end.y)
			var part := {
				"asset_id": id,
				"role": &"wall.stone.retaining",
				"transform": pose,
				"retaining_ceiling": upper.y
			}
			var untouched := part.duplicate()
			untouched.erase("retaining_ceiling")
			var partial := part.duplicate()
			partial.transform.origin += basis.x * 2
			var original_partial: Transform3D = partial.transform
			var parts: Array[Dictionary] = [part, untouched, partial]
			assert_eq(JOINT.fit(parts, [t], Transform3D.IDENTITY, catalog), 1)
			var after: Transform3D = part.transform
			assert_eq(after.basis, pose.basis, "Native dimensions and relief are preserved")
			assert_almost_eq(
				(after * Vector3(0, local.end.y, local.end.z) - upper).dot(out), 0.0, 0.001
			)
			assert_eq(after.origin.y, pose.origin.y, "No vertical seam below the wall")
			assert_eq(untouched.transform, pose, "Ordinary facade is unaffected")
			assert_eq(
				partial.transform,
				original_partial,
				"Do not move a panel beyond this flight's width"
			)
			assert_eq(
				JOINT.fit(parts, [t], Transform3D.IDENTITY, catalog),
				0,
				"Joint fitting is idempotent"
			)


func test_reported_landing_has_no_stone_above_its_ramp():
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var source := WarrenMazeSitePlanner.plan(
		53, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"", false
	)
	var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source, program)
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var map := KitVillageBuildings.native_to_lattice(kit)
	var checked := 0
	for part: Dictionary in built.placements:
		if String(part.stable_id) not in ["kit.retained/k0121", "kit.retained/k0122"]:
			continue
		var box: AABB = map * part.transform * catalog.descriptor(part.asset_id).measured_aabb
		assert_true(part.get("retaining_flight_joint", false))
		assert_gte(box.position.z, 11.249, "All masonry stays behind the landing edge")
		assert_almost_eq(box.end.y, 3.0, 0.001)
		checked += 1
	assert_eq(checked, 2, "Both complete native panels at the photographed joint are checked")


func test_attached_windows_follow_a_seated_panel_face():
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.retained"
	var storey := mass.add_storey(
		0, BuildingMass.rect_cells(Rect2i(0, 0, 2, 2)), BuildingMass.MATERIAL_STONE
	)
	storey.retaining = true
	var backing := BuildingKitAssembler.new(kit).assemble(mass)
	var windows = preload("res://scripts/terrain/features/villages/kit/KitRetainingWindows.gd")
	var original := windows.fit([mass], backing, kit, catalog, [], [])
	for wall: Dictionary in backing:
		if wall.get("role", &"") != &"wall.stone.retaining":
			continue
		wall.transform.origin -= wall.transform.basis.z * 0.2
		wall["retaining_flight_joint"] = true
	var seated := windows.fit([mass], backing, kit, catalog, [], [])
	assert_gt(original.size(), 0)
	assert_eq(
		seated.size(), original.size(), "Seating a wall does not discard its supported windows"
	)
	for window: Dictionary in seated:
		var attached := false
		var local: AABB = catalog.descriptor(window.asset_id).measured_aabb
		for wall: Dictionary in backing:
			if wall.get("role", &"") != &"wall.stone.retaining":
				continue
			var relative: Transform3D = window.transform.affine_inverse() * wall.transform
			if relative.basis.z.dot(Vector3.BACK) < 0.99:
				continue
			var box: AABB = relative * catalog.descriptor(wall.asset_id).measured_aabb
			if box.position.x > local.position.x or box.end.x < local.end.x:
				continue
			if box.position.y > local.position.y or box.end.y < local.end.y:
				continue
			attached = absf(local.position.z - box.end.z - 0.01) < 0.001
			if attached:
				break
		assert_true(attached, "Window must be on the moved masonry face")
