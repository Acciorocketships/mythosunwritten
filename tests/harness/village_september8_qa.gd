extends "res://tests/harness/village_september7_qa.gd"

## Attachment order; rounded F3 coordinates reconstructed by ReviewCam.
func _spots() -> Array:
	var spots: Array = [
		["01_garden_trim", "9.33.47 AM", Vector3(-389.2,25.4,-257.8), Vector3(-389.1,25.6,-257.4)],
		["02_town_slope", "9.34.04 AM", Vector3(-415,13,-241.4), Vector3(-414.7,13.2,-241.1)],
		["03_door_edges", "9.30.47 AM", Vector3(236.9,14.1,-343.7), Vector3(236.7,14.4,-344)],
		["04_wall_end", "9.29.41 AM", Vector3(242.7,8,-368.4), Vector3(242.8,8.2,-368.8)],
		["05_path_notches", "9.31.26 AM", Vector3(242.2,8,-378.3), Vector3(242.2,8.2,-378.6)],
		["06_door_paths", "9.31.03 AM", Vector3(279.9,8,-362.1), Vector3(279.6,8.2,-362)],
		["07_wall_seams", "9.30.21 AM", Vector3(237.5,23.1,-357.6), Vector3(237.7,23.4,-357.9)],
		["08_dead_end", "9.29.57 AM", Vector3(242.2,23.1,-358), Vector3(242,23.4,-358.3)],
		["09_facade_return", "9.28.36 AM", Vector3(222.9,12.3,-330.2), Vector3(222.9,12.6,-329.8)],
		["10_river_bank", "9.34.33 AM", Vector3(-518.4,12,-229.6), Vector3(-518.5,12.2,-229.9)],
		["11_floor_caps", "9.29.25 AM", Vector3(223.8,14.1,-374.1), Vector3(224.1,14.3,-374)],
		["12_floor_overlap", "9.33.26 AM", Vector3(-402.8,25.1,-274), Vector3(-403.1,25.4,-273.9)],
		["13_ground_slope", "9.28.57 AM", Vector3(251.9,11,-346), Vector3(252,11.2,-345.7)],
	]
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "--only":
			var names := args[i+1].split(",")
			return spots.filter(func(spot: Array) -> bool: return String(spot[0]) in names)
	return spots

func _ready() -> void:
	super._ready()
	# Image viewport inside the editor chrome is 1920 by 1080.
	get_window().size = Vector2i(1920,1080)

func _capture_spot(spot: Array) -> void:
	_spot = spot
	_character.global_position = spot[2]
	assert(await _wait_for_site(), "Photographed site must finish streaming")
	await super._capture_spot(spot)
