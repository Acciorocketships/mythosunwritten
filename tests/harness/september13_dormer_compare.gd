extends SceneTree
func _init() -> void:
	var path := "res://docs/qa/2026-09-13-manual/41-dormers/"
	var before: Dictionary = FileAccess.open(path+"before-payload.bin",FileAccess.READ).get_var()
	var after: Dictionary = FileAccess.open(path+"after-payload.bin",FileAccess.READ).get_var()
	var a := _owners(before)
	var b := _owners(after)
	var removed := []
	var changed := []
	var added := []
	for id: String in a:
		if not b.has(id): removed.append({"id":id,"asset":str(a[id].asset)})
		elif a[id] != b[id]: changed.append(id)
	for id: String in b:
		if not a.has(id): added.append(id)
	var result := {"removed":removed,"changed":changed,"added":added,"surfaces_identical":before.surface_meshes==after.surface_meshes,"collision_boxes_identical":before.collision_boxes==after.collision_boxes,"walked_identical":before.walked==after.walked}
	FileAccess.open(path+"placements.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BARREL_COMPARISON ",result)
	quit()
func _owners(data: Dictionary) -> Dictionary:
	var out := {}
	for asset: StringName in data.batches:
		var batch: Dictionary = data.batches[asset]
		for index in batch.ids.size(): out[str(batch.ids[index])] = {"asset":asset,"transform":batch.transforms[index]}
	return out
