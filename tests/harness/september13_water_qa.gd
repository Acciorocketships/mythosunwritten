extends "res://tests/harness/september13_path_qa.gd"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var replacement_index := args.find("--water-geometry")
	if replacement_index >= 0:
		assert(_frozen, "Geometry comparisons use the same frozen production surroundings")
		var world := _character.get_parent().get_parent()
		var material: Material
		for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
			if not node.is_in_group("tactical_preserve_surface"): continue
			if material == null: material = node.get_active_material(0)
			node.free()
		assert(material != null)
		var geometry: Node3D = (load(args[replacement_index + 1]) as PackedScene).instantiate()
		for node: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
			if not node.is_in_group("tactical_preserve_surface"): continue
			geometry.remove_child(node)
			world.add_child(node)
			node.material_override = material
		geometry.free()
	await super._run()

func _spots() -> Array:
	var poses:Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/photo-poses.json"))
	var out:=[]
	for spot:Dictionary in poses:
		if String(spot.id) in ["P01","P02","P12","P13","P19","P25","P34","P39","P48"]:
			out.append([spot.id,"September water review",Vector3(spot.player[0],spot.player[1],spot.player[2]),
				Vector3(spot.crosshair[0],spot.crosshair[1],spot.crosshair[2])])
	return out
