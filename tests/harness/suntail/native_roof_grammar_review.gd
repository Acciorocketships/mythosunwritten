extends "res://tests/harness/pure_village_lineup.gd"
const Grammar = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	for specimen: String in ["reference", "reconstructed", "novel_one", "novel_four"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var roof: Node3D
		if specimen == "reference":
			roof = load(R + "Houses/House_1.glb").instantiate()
			for mesh: MeshInstance3D in roof.find_children("*", "MeshInstance3D", true, false):
				mesh.visible = (
					String(mesh.name).begins_with("Roof_")
					or String(mesh.name).begins_with("Wall_Cut")
				)
		else:
			roof = Grammar.instantiate(
				1 if specimen == "novel_one" else (4 if specimen == "novel_four" else 2), 3.0
			)
		stage.add_child(roof)
		for view: Dictionary in [
			{"name": "oblique", "eye": Vector3(15, 12, 19)},
			{"name": "back", "eye": Vector3(-15, 12, -19)},
			{"name": "end", "eye": Vector3(20, 7, 0)},
			{"name": "above", "eye": Vector3(1, 26, 3)}
		]:
			await _shoot(stage, view.eye, Vector3(0, 6, 0), specimen + "_" + view.name)
		stage.queue_free()
		await process_frame
	quit()
