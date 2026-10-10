extends "res://tests/harness/pure_village_lineup.gd"
## Measure authored complete tower/projection assemblies before adapting them.

func _run() -> void:
	get_root().size = Vector2i(1600,900)
	var measurements: Array = []
	for file: String in ["House_11c", "House_16c", "House_7b"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var house := (load(R+"Houses/"+file+".glb") as PackedScene).instantiate()
		stage.add_child(house)
		var box := AABB()
		var first := true
		var parts: Array = []
		for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			var bounds := mesh.global_transform*mesh.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
			parts.append({"name":mesh.name,"transform":str(mesh.global_transform),
				"bounds":str(bounds)})
		measurements.append({"house":file,"bounds":str(box),"parts":parts})
		var target := box.get_center()
		var reach := maxf(box.size.x,box.size.z)*1.6
		await _shoot(stage,target+Vector3(reach,box.size.y*0.25,reach),target,file+"_front")
		await _shoot(stage,target+Vector3(-reach,box.size.y*0.25,-reach),target,file+"_back")
		stage.queue_free()
		await process_frame
	FileAccess.open(_out.path_join("assemblies.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"  "))
	quit()
