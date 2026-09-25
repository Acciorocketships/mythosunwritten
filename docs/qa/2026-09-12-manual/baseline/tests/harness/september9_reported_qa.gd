extends "res://tests/harness/village_september7_qa.gd"

## Rounded F3 pins in the user's attachment order. Photo 1 has no crosshair
## terrain hit and therefore cannot supply a ReviewCam azimuth.
func _spots() -> Array:
	var spots:Array=[
		["02_grass_lip", "2026-09-09 10.25.52 PM", Vector3(229.8,8,-370.3), Vector3(229.7,8.3,-369.9)],
		["03_doors", "2026-09-09 10.26.22 PM", Vector3(235.2,20.1,-370.8), Vector3(235.5,20.4,-370.6)],
		["04_path_end", "2026-09-09 10.28.43 PM", Vector3(291.5,6,-1235), Vector3(291.5,6.2,-1234.7)],
		["05_water_edge", "2026-09-09 10.30.15 PM", Vector3(82,12.2,-1510), Vector3(82.2,12.5,-1509.7)],
		["06_stair_rail", "2026-09-09 10.26.34 PM", Vector3(251,10.3,-344.9), Vector3(250.4,10.7,-345.1)],
		["07_water_mound", "2026-09-09 10.31.42 PM", Vector3(132.3,12,-1737), Vector3(132.4,12.2,-1736.7)],
		["08_water_crease", "2026-09-09 10.31.53 PM", Vector3(169.9,7.9,-1792.5), Vector3(169.6,8.1,-1792.3)],
		["09_thin_turf", "2026-09-09 10.34.55 PM", Vector3(474,21.8,-2076.1), Vector3(473.8,22.1,-2076.3)],
		["10_roof_end", "2026-09-09 10.35.30 PM", Vector3(468.5,15.1,-2053.9), Vector3(468.4,15.4,-2054.2)],
		["11_fern", "2026-09-09 10.38.09 PM", Vector3(76.8,12,-2437.9), Vector3(77.1,12.2,-2437.7)],
		["12_offset_room", "2026-09-09 10.28.23 PM", Vector3(255.7,10.5,-1139.2), Vector3(255.7,10.8,-1138.8)],
		["13_wall_seam", "2026-09-09 10.36.02 PM", Vector3(483.7,12.1,-2066.2), Vector3(483.6,12.3,-2065.8)],
		["14_tiny_roof", "2026-09-09 10.35.20 PM", Vector3(468.6,18.8,-2064.7), Vector3(468.2,19.2,-2064.6)],
	]
	if OS.get_cmdline_user_args().has("--water"):
		return spots.filter(func(spot:Array)->bool:return String(spot[0]).begins_with("05_") or String(spot[0]).begins_with("07_") or String(spot[0]).begins_with("08_"))
	return spots

func _grass_enabled() -> bool:
	return true

func _capture_spot(spot: Array) -> void:
	_spot = spot
	_character.global_position = spot[2]
	assert(await _wait_for_site(), "Reported neighborhood must finish streaming")
	await super._capture_spot(spot)
	FileAccess.open(_output_dir + "/" + String(spot[0]) + "_camera.json",
		FileAccess.WRITE).store_string(JSON.stringify({"seed": WORLD_SEED,
		"source": spot[1], "player": str(spot[2]), "crosshair": str(spot[3]),
		"reconstructed_camera": str(ReviewCam.solve_cam(spot[2], spot[3])),
		"original_precision_recoverable": false}, "  "))
