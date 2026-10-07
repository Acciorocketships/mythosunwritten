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
