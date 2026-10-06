extends "res://tests/harness/pure_village_lineup.gd"
## Native reference assembly: separate the upper and curved lower courses.
## This study does not replace the production kit or stretch source pieces.
func _run() -> void:
	get_root().size = Vector2i(1600,900)
	for layer: String in ["upper", "curved", "complete", "closed"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var house := (load(R + "Houses/House_1.glb") as PackedScene).instantiate()
		stage.add_child(house)
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			var roof := String(mesh.name).begins_with("Roof_")
			var curved := String(mesh.name).begins_with("Roof_Curved")
			mesh.visible = roof and (layer in ["complete", "closed"] or curved == (layer == "curved"))
			if layer == "closed" and String(mesh.name).begins_with("Wall_Cut"):
				mesh.visible = true
			if not mesh.visible: continue
			var bounds := mesh.global_transform * mesh.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
		print("ROOF_REFERENCE ", layer," ",box)
		house.position.y = -box.position.y
		var target := box.get_center() - Vector3.UP * box.position.y
		await _shoot(stage,target+Vector3(12,5,15),target,layer+"_oblique")
		await _shoot(stage,target+Vector3(15,1,0),target,layer+"_end")
		stage.queue_free()
		await process_frame
	quit()
