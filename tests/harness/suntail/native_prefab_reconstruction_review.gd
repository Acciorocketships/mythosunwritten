extends "res://tests/harness/pure_village_lineup.gd"
## Exact stock reconstruction review; source and generated cameras are identical.
const ORACLE := preload("res://tests/fixtures/native_prefab_reconstruction.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var fixture := "res://tests/fixtures/native_house11c_derivation.json"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--fixture":
			fixture = args[i + 1]
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	for specimen: String in ["source", "reconstructed"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var reference: Node3D = load("res://" + String(document.source)).instantiate()
		var house := reference if specimen == "source" else ORACLE.instantiate(document, reference)
		if specimen != "source":
			reference.free()
		stage.add_child(house)
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var target := bounds.get_center()
		var reach := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.2
		for side in [-1, 1]:
			await _shoot(
				stage,
				target + Vector3(side, .5, side * 1.1) * reach,
				target,
				"%s_%s" % [specimen, "front" if side == 1 else "back"]
			)
		stage.queue_free()
		await process_frame
	quit()
