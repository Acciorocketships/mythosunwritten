extends SceneTree
func _init() -> void:
	var directory := "res://docs/qa/2026-09-13-manual/39-door-panels/"
	var a: Dictionary = FileAccess.open(directory+"before-payload.bin",FileAccess.READ).get_var()
	var b: Dictionary = FileAccess.open(directory+"after-payload.bin",FileAccess.READ).get_var()
	var diffs := []
	for i in a.surface_meshes.size():
		var old: Dictionary = a.surface_meshes[i]
		var new: Dictionary = b.surface_meshes[i]
		for key: Variant in old:
			if old[key] == new.get(key): continue
			var item := {"surface":i,"key":str(key),"type":type_string(typeof(old[key])),"stable_id":str(old.get("stable_id",""))}
			if old[key] is PackedVector3Array and new[key] is PackedVector3Array:
				item["before_count"] = old[key].size()
				item["after_count"] = new[key].size()
				var max_distance := 0.0
				if old[key].size() == new[key].size():
					for k in old[key].size(): max_distance = maxf(max_distance,old[key][k].distance_to(new[key][k]))
				item["max_distance"] = max_distance
			diffs.append(item)
	print(JSON.stringify(diffs))
	FileAccess.open(directory+"surface-differences.json",FileAccess.WRITE).store_string(JSON.stringify(diffs,"  "))
	quit()
