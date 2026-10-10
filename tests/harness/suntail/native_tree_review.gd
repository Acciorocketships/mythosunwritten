extends "res://tests/harness/pure_village_lineup.gd"


func _run() -> void:
	get_root().size = Vector2i(1200, 900)
	for index in range(1, 7):
		var stage := Node3D.new()
		root.add_child(stage)
		_light(stage)
		var tree := (
			(load("res://assets/PureVillage/Models/Trees/Maple%d.glb" % index) as PackedScene)
			. instantiate()
		)
		stage.add_child(tree)
		var box := _aabb(tree)
		print("MAPLE ", index, " bounds=", box)
		var target := box.get_center()
		await _shoot(
			stage, target + Vector3(1, .35, 1) * box.size.length(), target, "maple%d" % index
		)
		stage.queue_free()
		await process_frame
	quit()
