extends "res://tests/harness/pure_village_lineup.gd"
## Measured native shallow-roof grammar, distinct from a full gable slope.
func _run() -> void:
	get_root().size = Vector2i(1200,900)
	for name: String in ["Roof_Bottom_30x5_1", "Roof_Bottom_Left_20x5_1", "Roof_Bottom_Right_20x5_1", "Roof_BottomCurved_30x5_1", "Roof_BottomCurved_Start_20x5_1", "Roof_BottomCurved_End_20x5_1", "Wall_Start_10x30_0"]:
		var path := R + "Architecture/" + name + ".glb"
		if not ResourceLoader.exists(path):
			print("MISSING ",name)
			continue
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var part: Node3D = (load(path) as PackedScene).instantiate()
		stage.add_child(part)
		var box := _aabb(part)
		print("SHED_PART ",name," ",box)
		part.position.y -= box.position.y
		box = _aabb(part)
		var centre := box.get_center()
		var reach := maxf(3.0,box.size.length()*1.1)
		await _shoot(stage,centre+Vector3(.65,.4,1)*reach,centre,name+"-front")
		await _shoot(stage,centre+Vector3(-.65,.25,-1)*reach,centre,name+"-back")
		stage.queue_free()
		await process_frame
	quit()
