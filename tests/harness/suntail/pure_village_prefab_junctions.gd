extends "res://tests/harness/pure_village_lineup.gd"
func _run() -> void:
	get_root().size=Vector2i(1400,1000)
	for name: String in ["House_16c","House_11c"]:
		var stage:=Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var house: Node3D=(load(R+"Houses/"+name+".glb") as PackedScene).instantiate()
		stage.add_child(house)
		var box:=_aabb(house)
		var centre:=box.get_center()
		await _shoot(stage,centre+Vector3(24,10,30),centre,name+"-front")
		await _shoot(stage,centre+Vector3(-24,10,-30),centre,name+"-back")
		if name=="House_16c":
			await _shoot(stage,Vector3(15,12,16),Vector3(4.625,9,3),name+"-junction")
		stage.queue_free()
		await process_frame
	quit()
