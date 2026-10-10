extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		for child in stage.get_children():
			if child is MeshInstance3D:
				child.position.y = -1.5
		var choices := House.sample(31, dimensions.x, dimensions.y)
		stage.add_child(House.instantiate(dimensions.x, dimensions.y, choices, true))
		for view: Dictionary in [
			{"name": "front", "eye": Vector3(18, 10, 20)},
			{"name": "back", "eye": Vector3(-18, 10, -20)},
			{"name": "base", "eye": Vector3(14, 1, 17)}
		]:
			await _shoot(
				stage,
				view.eye,
				Vector3(0, 3, 0),
				"%s_%s_%s" % [dimensions.x, dimensions.y, view.name]
			)
		for part in House.derive(dimensions.x, dimensions.y, choices):
			if String(part.module).begins_with("Door_"):
				await _shoot(
					stage,
					part.transform * Vector3(3, 2.5, 8),
					part.transform * Vector3(0, -.5, .5),
					"%s_%s_entry" % [dimensions.x, dimensions.y]
				)
		stage.queue_free()
		await process_frame
	quit()
