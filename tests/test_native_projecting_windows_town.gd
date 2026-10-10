extends "res://tests/test_native_house_town.gd"


func test_projecting_bays_survive_holdout_assembly_without_blocking_public_air() -> void:
	_assert_native_town(53, &"grand", "anchor.z_native.street.", &"pure_village.native.window_5_2")
