extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeHouse.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	for specimen: String in ["reference", "reconstructed", "sample_7", "sample_31"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var house: Node3D
		if specimen == "reference":
			house = load(R + "Houses/House_4.glb").instantiate()
		elif specimen == "reconstructed":
			house = House.instantiate(3)
		else:
			var seed_value := 7 if specimen == "sample_7" else 31
			var bays := 2 if seed_value == 7 else 3
			house = House.instantiate(bays, House.sample(seed_value, bays))
		stage.add_child(house)
		for view: Dictionary in [
			{"name": "front", "eye": Vector3(15, 10, 19)},
			{"name": "back", "eye": Vector3(-15, 10, -19)}
		]:
			await _shoot(stage, view.eye, Vector3(0, 4, 0), specimen + "_" + view.name)
		stage.queue_free()
		await process_frame
	quit()
