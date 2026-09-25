extends SceneTree

func _init() -> void:
	var directory := "res://docs/qa/2026-09-11-manual/11-cliffs/"
	var rows: Array[Dictionary] = []
	for shape: String in ["face","outer","inner"]:
		var before: Dictionary = FileAccess.open(directory+"before/"+shape+"-data.bin",FileAccess.READ).get_var()
		var after: Dictionary = FileAccess.open(directory+"candidate/"+shape+"-data.bin",FileAccess.READ).get_var()
		var unchanged: Dictionary = {}
		for key: String in ["surface_arrays","collision_faces","apron_arrays","wall_arrays","wall_collision_arrays","cliffs"]:
			unchanged[key] = var_to_bytes(before[key]) == var_to_bytes(after[key])
		var counts: Dictionary = {}
		var kinds: Dictionary = {}
		for placement: Dictionary in after.cliff_terraces.placements:
			counts[placement.asset] = int(counts.get(placement.asset,0))+1
			kinds[placement.kind] = int(kinds.get(placement.kind,0))+1
		rows.append({"shape":shape,"unchanged":unchanged,"assets":counts,"kinds":kinds,
			"native_collision_triangles":after.cliff_terraces.collision_faces.size()/3})
	print(JSON.stringify(rows,"  "))
	FileAccess.open(directory+"native-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
