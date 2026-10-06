extends "res://tests/harness/pure_village_lineup.gd"
const Jetty = preload("res://scripts/terrain/features/villages/grammar/PureVillageJetty.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	for specimen: String in ["reference", "reconstructed", "component"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		if specimen != "component":
			var house: Node3D = load(R + "Houses/StreetHouse_1.glb").instantiate()
			stage.add_child(house)
			if specimen == "reconstructed":
				for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
					var name := String(mesh.name)
					if (
						name.begins_with("Window_3_1")
						or name.begins_with("Floor_Down_")
						or name.begins_with("Support_4")
						or (
							name.begins_with("Wall_End_10x30")
							and mesh.global_position.x < 0
							and mesh.global_position.y > 2
						)
					):
						mesh.visible = false
				# The source right-hand side is one continuous host/jetty wall.
				stage.add_child(
					Jetty.instantiate(Transform3D(Basis.IDENTITY, Vector3(0, 3, 3)), [1])
				)
		else:
			stage.add_child(Jetty.instantiate(Transform3D(Basis.IDENTITY, Vector3(0, 3, 3))))
		await _shoot(stage, Vector3(10, 7, 16), Vector3(0, 4, 2), specimen + "_front")
		await _shoot(stage, Vector3(-8, 2, 12), Vector3(0, 3, 3), specimen + "_under")
		stage.queue_free()
		await process_frame
	quit()
