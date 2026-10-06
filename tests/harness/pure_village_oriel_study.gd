extends "res://tests/harness/pure_village_lineup.gd"
## Inspect the pack's half-tower grammar as one supported window projection.
func _run() -> void:
	get_root().size = Vector2i(1400,900)
	var stage := Node3D.new()
	get_root().add_child(stage)
	_light(stage)
	var assembly := Node3D.new()
	stage.add_child(assembly)
	var parts := [{"file":"StoneTowerHalf_Window_15x30","y":1.5},
		{"file":"StoneTowerHalf_Support_15x30","y":1.5},
		{"file":"Roof_Tower_2","y":4.5}]
	for record: Dictionary in parts:
		var node := (load(R+"Architecture/"+record.file+".glb") as PackedScene).instantiate()
		assembly.add_child(node)
		node.position.y = record.y
		print("ORIEL_PART ",record.file," ",_aabb(node))
	var box := _aabb(assembly)
	var target := box.get_center()
	var reach := maxf(box.size.x,box.size.y)*1.4
	await _shoot(stage,target+Vector3(reach*0.5,reach*0.1,reach),target,"oriel-front")
	await _shoot(stage,target+Vector3(-reach,reach*0.1,-reach*0.6),target,"oriel-back")
	stage.queue_free()
	await process_frame
	quit()
