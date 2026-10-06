extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var stage := Node3D.new()
	get_root().add_child(stage)
	_light(stage)
	var house := House.instantiate(1, 1, House.sample(7), true)
	stage.add_child(house)
	for part: Dictionary in House.gable_details(House.derive()):
		var window: Node3D = load(R + "Architecture/WindowSolo_6.glb").instantiate()
		house.add_child(window)
		window.transform = part.transform
	await _shoot(stage, Vector3(15, 11, 19), Vector3(0, 5, 0), "gable_window")
	quit()
