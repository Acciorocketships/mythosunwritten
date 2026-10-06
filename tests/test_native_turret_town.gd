extends "res://tests/test_native_house_town.gd"


func test_complete_corner_houses_survive_assembly_and_public_clearance() -> void:
	_assert_native_town(8, &"grand", "anchor.z_native.turret.")
	_assert_native_town(9, &"grand", "anchor.z_native.turret.")
