extends "res://tests/harness/pure_village_lineup.gd"
## Native components for embedded frontage design, shown without deformation.
func _run() -> void:
	get_root().size = Vector2i(1400,1000)
	for name: String in ["BowWindow_1", "BowWindow_2", "BowWindow_3", "BowWindow_4", "BowWindow_5", "BowWindow_6", "BowWindow_7", "BowWIndow_8", "BowWindow_9", "TileAwning_1", "TileAwning_4", "Wall_Slice_Start_20x15", "Wall_Start_10x30_0"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var part: Node3D = (load(R + "Architecture/" + name + ".glb") as PackedScene).instantiate()
		stage.add_child(part)
		var box := _aabb(part)
		print("FRONTAGE_PART ", name, " ", box)
		var centre := box.get_center()
		var reach := maxf(3.0, box.size.length() * 1.1)
		await _shoot(stage, centre + Vector3(0.6,0.25,1.0) * reach, centre, name + "-front")
		await _shoot(stage, centre + Vector3(-0.6,0.25,-1.0) * reach, centre, name + "-back")
		stage.queue_free()
		await process_frame
	quit()
