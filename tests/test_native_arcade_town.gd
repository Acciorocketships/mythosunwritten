extends "res://tests/test_native_house_town.gd"


func test_arcade_variants_survive_generated_town_assembly_with_public_clearance() -> void:
	_assert_native_town(
		7, &"standard", "anchor.z_native.arcade.02.", &"pure_village.arcade.arch_end_30x60"
	)
	_assert_native_town(
		31, &"large", "anchor.z_native.arcade.01.", &"pure_village.arcade.arch_end_30x60"
	)


func test_arcade_holdout_keeps_full_geometry_and_public_air_clearance() -> void:
	_assert_native_town(
		103, &"grand", "anchor.z_native.arcade.", &"pure_village.arcade.arch_end_30x60"
	)
