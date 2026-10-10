extends GutTest
const GROWTH := preload("res://scripts/terrain/features/villages/kit/KitGrowingFronts.gd")
const PALETTE := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")


func test_lean_suffix_names_the_depth_in_centimetres() -> void:
	assert_eq(BuildingKitAssembler.lean_suffix(0.25), "d025")
	assert_eq(BuildingKitAssembler.lean_suffix(1.5), "d150")
	assert_eq(BuildingKitAssembler.lean_suffix(2.0), "d200")


## Exactly the depths the assembler can ask for (KitGrowingFronts.FRONT_DEPTHS): whole
## 0.5 steps up to one module, the module left over by a trimmed floor or cut panel, and
## the wrapped corner's 0.25 filler beam. No unused depth is baked.
const USED := {
	&"frontage.floor": ["d050", "d100", "d150"],
	&"frontage.corner": ["d050", "d100", "d150"],
	&"frontage.return": ["d050", "d100", "d150", "d200"],
	&"frontage.return_beam": ["d025", "d050", "d100", "d150", "d200"],
}


func test_the_baked_depth_family_is_exactly_the_used_set() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	var family := RegEx.create_from_string("^town\\.frontage\\.[a-z_]+\\.d\\d{3}(\\.finish_[a-z]+)?$")
	var expected := []
	for role: StringName in USED:
		for suffix: String in USED[role]:
			expected.append("%s.%s" % [role, suffix])
	expected.sort()
	var baked := []
	for id: StringName in catalog.ids():
		if family.search(String(id)) != null:
			baked.append(String(id))
	baked.sort()
	var with_finishes := []
	for role: String in expected:
		for finish: String in ["", ".finish_oak", ".finish_walnut"]:
			with_finishes.append("town." + role + finish)
	with_finishes.sort()
	assert_eq(baked, with_finishes, "catalogue: each used depth and its two finishes, nothing else")
	var roles := []
	for role: StringName in kit.roles:
		if family.search("town." + String(role)) != null:
			roles.append(String(role))
	roles.sort()
	assert_eq(roles, expected, "kit roles")
	for role: StringName in GROWTH.FRONT_ROLES:
		var depths := []
		for depth: float in GROWTH.FRONT_DEPTHS[role]:
			depths.append(BuildingKitAssembler.lean_suffix(depth))
		assert_eq(depths, USED[role], String(role))


func test_every_baked_depth_is_measured() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	for role: StringName in GROWTH.FRONT_ROLES:
		for depth: float in GROWTH.FRONT_DEPTHS[role]:
			var suffix := BuildingKitAssembler.lean_suffix(depth)
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
				&"frontage.corner":
					assert_almost_eq(box.size.x, depth, 0.001, String(id))
					assert_almost_eq(box.size.z, depth, 0.001, String(id))
					assert_almost_eq(box.get_center().x, 0.0, 0.001, String(id))
					assert_almost_eq(box.get_center().z, 0.0, 0.001, String(id))


func test_existing_projection_fronts_are_unchanged() -> void:
	var catalog := EnvironmentCatalog.load_default()
	assert_eq(catalog.descriptor(&"town.frontage.return").measured_aabb,
		AABB(Vector3(-0.325, 0, -0.125), Vector3(0.65, 3, 0.25)))
	assert_almost_eq(catalog.descriptor(&"town.frontage.floor").measured_aabb.size.z, 0.65, 1e-6)
	assert_almost_eq(catalog.descriptor(&"town.frontage.return_beam").measured_aabb.size.x, 0.65, 1e-6)
