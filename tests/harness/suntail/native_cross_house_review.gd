extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	for specimen: String in ["reference", "reconstructed", "extended", "sample_7", "sample_31"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var roof: Node3D
		if specimen == "reference":
			roof = load(R + "Houses/House_5.glb").instantiate()
			for mesh: MeshInstance3D in roof.find_children("*", "MeshInstance3D", true, false):
				mesh.visible = (
					String(mesh.name).begins_with("Roof_")
					or String(mesh.name).begins_with("Wall_")
					or String(mesh.name).begins_with("Wall_Cut")
					or String(mesh.name).begins_with("Wall_Peak")
					or String(mesh.name).contains("_30x10_")
					or String(mesh.name).contains("_15x10_")
				)
		else:
			var extended := specimen == "extended" or specimen.begins_with("sample_")
			roof = House.instantiate(
				2 if extended else 1,
				1,
				(
					House.sample(7 if specimen == "sample_7" else 31, 2, 1)
					if specimen.begins_with("sample_")
					else {}
				)
			)
		stage.add_child(roof)
		for view: Dictionary in [
			{"name": "front", "eye": Vector3(19, 17, 22)},
			{"name": "back", "eye": Vector3(-19, 17, -22)},
			{"name": "above", "eye": Vector3(3, 32, 2)},
			{"name": "eaves", "eye": Vector3(17, 4.5, 17)}
		]:
			await _shoot(stage, view.eye, Vector3(0, 6, 0), specimen + "_" + view.name)
		stage.queue_free()
		await process_frame
	quit()
