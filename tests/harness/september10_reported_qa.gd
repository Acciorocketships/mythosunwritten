extends "res://tests/harness/september9_reported_qa.gd"

## Attachment order, seed 2697992464. Rounded overlay pins, not full poses.
func _spots() -> Array:
	return [
		["01_rail", "5.57.41 PM", Vector3(475,21.1,-2077.8), Vector3(474.6,21.4,-2077.9)],
		["02_prefab_base", "5.45.14 PM", Vector3(1957.3,19.2,-987.5), Vector3(1957.6,19.6,-987.8)],
		["03_skywalk", "5.58.06 PM", Vector3(482.7,31.3,-2069.3), Vector3(483,31.6,-2069.2)],
		["04_ceiling", "5.44.25 PM", Vector3(1923.3,18.7,-1040.1), Vector3(1923.1,19.1,-1040.5)],
		["05_guard", "5.40.51 PM", Vector3(1820.8,27.1,-259), Vector3(1821.1,27.4,-259.1)],
		["06_stone_gap", "5.42.39 PM", Vector3(1846.8,12,-276.7), Vector3(1847,12.2,-276.4)],
		["07_bench", "5.41.02 PM", Vector3(1794,24.1,-279), Vector3(1793.8,24.3,-279.3)],
		["08_hanging_stone", "5.55.54 PM", Vector3(982.2,9.3,-2079.8), Vector3(982.4,9.6,-2080.1)],
		["09_stone_course", "5.56.03 PM", Vector3(991.4,9.2,-2055.4), Vector3(991.7,9.4,-2055.5)],
		["10_overhang", "5.42.21 PM", Vector3(1861.4,16.6,-265.7), Vector3(1861.8,16.9,-265.7)],
		["11_orbs_streaming", "5.39.36 PM", Vector3(1618,12,-571), Vector3(1617.7,12.2,-570.9)],
		["12_rail_texture", "5.41.25 PM", Vector3(1828,18.1,-248.1), Vector3(1827.7,18.4,-248.3)],
		["13_plaster_gap", "5.35.26 PM", Vector3(268.2,8,-359.4), Vector3(268.2,8.2,-359)],
		["14_roof", "5.58.45 PM", Vector3(490.6,16.6,-2090.7), Vector3(490.3,16.9,-2091)],
		["15_water_cliffs", "5.50.04 PM", Vector3(892.5,8.6,-1828.3), Vector3(892.8,8.9,-1828.6)],
		["16_water_sheet", "5.52.33 PM", Vector3(678.8,12.6,-1744.2), Vector3(678.6,12.9,-1744.5)],
		["17_prefab_support", "5.40.41 PM", Vector3(1825.6,24.1,-274.8), Vector3(1826,24.4,-274.7)],
		["18_water_dry_strip", "5.51.21 PM", Vector3(815.2,8.8,-1777.9), Vector3(815.6,9,-1777.8)],
		["19_water_fold", "5.50.20 PM", Vector3(899.7,4.5,-1765.8), Vector3(899.5,4.7,-1766.1)],
	]

func _ready() -> void:
	super._ready()
	# Half-resolution copy of the image's 3436 x 2070 game area.
	get_window().size = Vector2i(1718,1035)

func _capture_spot(spot: Array) -> void:
	# These photos predate the tactical-camera change. Keep its original FOV.
	_camera.fov = 75.0
	await super._capture_spot(spot)
