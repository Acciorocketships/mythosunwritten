extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageStreetHouse.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	for specimen: String in ["reference", "reconstructed", "sample_7", "sample_31"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var house: Node3D = (
			load(R + "Houses/StreetHouse_1.glb").instantiate()
			if specimen == "reference"
			else (
				House.instantiate(3, House.sample(7 if specimen == "sample_7" else 31, 3))
				if specimen.begins_with("sample_")
				else House.instantiate(2)
			)
		)
		stage.add_child(house)
		for view: Dictionary in [
			{"name": "front", "eye": Vector3(12, 9, 18)},
			{"name": "back", "eye": Vector3(-12, 9, -18)},
			{"name": "under", "eye": Vector3(-8, 2, 12)},
			{"name": "above", "eye": Vector3(8, 22, 6)}
		]:
			await _shoot(stage, view.eye, Vector3(0, 4, 0), specimen + "_" + view.name)
		stage.queue_free()
		await process_frame
	quit()
