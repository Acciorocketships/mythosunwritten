extends GutTest
const FIT = preload("res://scripts/terrain/features/villages/kit/KitWindowBoxes.gd")


func _fixture(y: float) -> Dictionary:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var openings: Dictionary = (
		FileAccess
		. open("res://terrain/environment/geometry/window_openings.bin", FileAccess.READ)
		. get_var()
	)
	var window_id: StringName = &"pure_village.wall.plaster.window_arch"
	var pane: AABB = openings[window_id]
	var window_pose := Transform3D(Basis.IDENTITY, Vector3(0, y, 0))
	var parts: Array[Dictionary] = [
		{"role": &"wall.timber.window", "asset_id": window_id, "transform": window_pose},
		{
			"role": &"window_box",
			"asset_id": &"suntail.decor.flovers_1",
			"transform": Transform3D(Basis.IDENTITY, Vector3(pane.get_center().x, y + .75, .17)),
			"window_wall_centre": Vector2(pane.get_center().x, pane.get_center().z),
			"window_storey_y": y,
			"window_ground_y": 0.0
		}
	]
	return {
		"parts": parts,
		"catalog": catalog,
		"kit": kit,
		"openings": openings,
		"pane": window_pose * pane
	}


func test_foliage_keeps_most_of_an_arched_window_visible() -> void:
	var f := _fixture(3.0)
	var original: Transform3D = f.parts[1].transform
	assert_eq(FIT.fit(f.parts, f.kit, f.catalog, f.openings), 1)
	assert_eq(f.parts.size(), 2)
	var box: AABB = f.parts[1].transform * f.catalog.descriptor(f.parts[1].asset_id).measured_aabb
	assert_almost_eq(box.end.y, f.pane.position.y + f.pane.size.y * FIT.MAX_PANE_OVERLAP, .001)
	assert_eq(
		f.parts[1].transform.basis, original.basis, "Keep the authored asset at its native scale"
	)
	assert_eq(
		FIT.fit(f.parts, f.kit, f.catalog, f.openings),
		0,
		"Fitting twice does not keep lowering the box"
	)


func test_low_sill_does_not_bury_a_flower_box() -> void:
	var f := _fixture(0.0)
	FIT.fit(f.parts, f.kit, f.catalog, f.openings)
	for part: Dictionary in f.parts:
		if part.role != &"window_box":
			continue
		var box: AABB = part.transform * f.catalog.descriptor(part.asset_id).measured_aabb
		assert_gte(box.position.y, .02)
	assert_eq(
		f.parts.size(), 1, "The low arched sill has no space for the complete native hanging box"
	)


func test_orphan_box_is_removed_without_touching_the_window() -> void:
	var f := _fixture(3.0)
	f.parts[1].window_wall_centre = Vector2(20, 20)
	assert_eq(FIT.fit(f.parts, f.kit, f.catalog, f.openings), 1)
	assert_eq(f.parts.size(), 1)
	assert_eq(f.parts[0].role, &"wall.timber.window")
