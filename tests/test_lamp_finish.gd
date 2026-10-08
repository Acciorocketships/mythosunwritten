extends GutTest
## Owner, October 7: every lamp post is dark brown wood. The kit's garden/plaza
## lamp resolves to the dark-wood descriptor; the path pole is tinted in place.

const SUBSTITUTION := preload("res://scripts/terrain/features/villages/kit/KitSubstitution.gd")
const SUNTAIL := preload("res://scripts/terrain/features/villages/kit/SuntailBuildingKit.gd")

var _catalog := EnvironmentCatalog.load_default()


func _is_brown(tint: Color) -> bool:
	return tint.r > tint.g and tint.g > tint.b and tint.r < 0.8


func test_kit_lamp_role_resolves_to_dark_wood_variant() -> void:
	var kit = SUNTAIL.create()
	var ids: Array = kit.roles[&"prop.lamp"]
	assert_eq(ids, [&"suntail.prop.lamp_1.dark_wood"] as Array)
	for id: StringName in ids:
		var descriptor := _catalog.descriptor(id)
		assert_not_null(descriptor, "catalog knows %s" % id)
		assert_true(descriptor.material_tints.has("Lamp_1"))
		assert_true(_is_brown(descriptor.material_tints["Lamp_1"]))


func test_lantern_post_prefix_is_substituted_to_the_lamp_role() -> void:
	assert_eq(SUBSTITUTION.PROP_ROLE_FOR_PREFIX["lpfv.fabric.prop.lantern.post."], &"prop.lamp")


func test_path_pole_is_tinted_dark_wood_in_place() -> void:
	var descriptor := _catalog.descriptor(&"sfv.light_pole.001")
	assert_true(descriptor.material_tints.has("SFV_MAIN_MATERIAL"))
	assert_true(_is_brown(descriptor.material_tints["SFV_MAIN_MATERIAL"]))


func test_no_town_lamp_still_points_at_the_untinted_kit_lamp() -> void:
	var kit = SUNTAIL.create()
	for role: StringName in kit.roles:
		assert_false((kit.roles[role] as Array).has(&"suntail.prop.lamp_1"), "role %s" % role)


func test_frame_finishes_never_derive_a_lamp_variant() -> void:
	var pure := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
	var palette := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")
	for finish: StringName in [&"walnut", &"oak"]:
		var kit = pure.roof_study(1)
		palette.apply(kit, finish)
		for id: StringName in kit.all_asset_ids():
			assert_true(_catalog.has(id), "%s (%s)" % [id, finish])


# The dark-wood finishes are declared in the bake manifests, so a rebake
# rewrites them identically and the unmanifested-descriptor prune keeps them.
const BAKE := preload("res://tools/environment_bake/environment_bake.gd")


func _manifest_entry(manifest: String, id: String) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/environment_bake/manifests/%s.json" % manifest))
	for entry: Dictionary in parsed.get("assets", []):
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func test_manifest_declares_the_dark_wood_kit_lamp_and_the_prune_keeps_it() -> void:
	var entry := _manifest_entry("suntail_village_kit", "suntail.prop.lamp_1")
	assert_false(entry.is_empty())
	assert_true(BAKE.descriptor_ids(entry).has("suntail.prop.lamp_1.dark_wood"),
		"prune keeps the dark-wood descriptor")
	var declared := BAKE.material_tints_of(
		(entry.get("material_tint_variants", {}) as Dictionary).get("dark_wood", {}))
	var committed := _catalog.descriptor(&"suntail.prop.lamp_1.dark_wood")
	assert_eq(committed.material_tints, declared, "a rebake reproduces the committed tint")
	assert_eq(committed.visual_path, _catalog.descriptor(&"suntail.prop.lamp_1").visual_path,
		"the variant shares the source visual")


func test_manifest_declares_the_path_pole_tint() -> void:
	var entry := _manifest_entry("fantasy_village_features", "sfv.light_pole.001")
	var declared := BAKE.material_tints_of(entry.get("material_tints", {}))
	assert_false(declared.is_empty(), "a rebake keeps the pole's dark wood")
	assert_eq(_catalog.descriptor(&"sfv.light_pole.001").material_tints, declared)
