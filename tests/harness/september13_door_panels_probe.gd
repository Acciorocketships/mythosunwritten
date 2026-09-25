extends SceneTree
func _init() -> void:
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/39-door-panels/before-payload.bin",FileAccess.READ).get_var()
	var catalog := EnvironmentCatalog.load_default()
	var area := AABB(Vector3(990,25,-420),Vector3(9,9,7))
	var report := []
	for asset: StringName in data.batches:
		var batch: Dictionary = data.batches[asset]
		for index in batch.transforms.size():
			var frame: Transform3D = data.transform*batch.transforms[index]
			var bounds: AABB = frame*catalog.descriptor(asset).measured_aabb
			if not area.intersects(bounds): continue
			report.append({"id":str(batch.ids[index]),"asset":str(asset),"frame":str(frame),"bounds":str(bounds)})
	FileAccess.open("res://docs/qa/2026-09-13-manual/39-door-panels/owners.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
