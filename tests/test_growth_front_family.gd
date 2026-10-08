extends GutTest
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const PALETTE := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")


func test_lean_suffix_names_the_depth_in_centimetres() -> void:
	assert_eq(BuildingKitAssembler.lean_suffix(0.25), "d025")
	assert_eq(BuildingKitAssembler.lean_suffix(1.5), "d150")
	assert_eq(BuildingKitAssembler.lean_suffix(2.0), "d200")


func test_every_lean_depth_has_a_measured_floor_return_and_beam() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	for depth: float in GROWTH.LEAN_DEPTHS:
		var suffix := BuildingKitAssembler.lean_suffix(depth)
		for role: StringName in GROWTH.FRONT_ROLES:
			var variant := StringName("%s.%s" % [role, suffix])
			assert_true(kit.has_role(variant), String(variant))
			var id := kit.asset(variant)
			assert_true(catalog.has(id), String(id))
			for finish: StringName in [&"walnut", &"oak"]:
				assert_true(catalog.has(PALETTE.variant_id(id, finish)), "%s %s" % [id, finish])
			var box := catalog.descriptor(id).measured_aabb
			match role:
				&"frontage.floor":
					assert_almost_eq(box.size.z, depth, 0.001, String(id))
					assert_almost_eq(box.position.z, -depth * 0.5, 0.001, String(id))
					assert_gt(catalog.descriptor(id).collision_piece_count, 0, String(id))
				&"frontage.return":
					assert_almost_eq(box.size.x, depth, 0.001, String(id))
					assert_almost_eq(box.position.x, -depth * 0.5, 0.001, String(id))
					assert_almost_eq(box.size.y, 3.0, 0.001, String(id))
					assert_gt(catalog.descriptor(id).collision_piece_count, 0, String(id))
				&"frontage.return_beam":
					assert_almost_eq(box.size.x, depth, 0.001, String(id))


func test_existing_projection_fronts_are_unchanged() -> void:
	var catalog := EnvironmentCatalog.load_default()
	assert_eq(catalog.descriptor(&"town.frontage.return").measured_aabb,
		AABB(Vector3(-0.325, 0, -0.125), Vector3(0.65, 3, 0.25)))
	assert_almost_eq(catalog.descriptor(&"town.frontage.floor").measured_aabb.size.z, 0.65, 1e-6)
	assert_almost_eq(catalog.descriptor(&"town.frontage.return_beam").measured_aabb.size.x, 0.65, 1e-6)
