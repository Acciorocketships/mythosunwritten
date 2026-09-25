extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var fixture := "september10-prefab-base-source.txt" if "--base" in OS.get_cmdline_user_args() else "september10-ceiling-source.txt"
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/"+fixture),program)
	var fabric := spatial.compiled_fabric_cache()
	var tx := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	var report := []
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in batch.ids.size():
			var id := String(batch.ids[index])
			if not id.begins_with("maze-stone/"): continue
			var parts := id.split("/")
			var key := Vector4i(int(parts[1]),int(parts[2]),int(parts[3]),int(parts[4]))
			if key.w >= 4: continue
			var cell := Vector3i(key.x,key.y,key.z)
			var pose: Transform3D = batch.transforms[index]
			var box := pose * catalog.descriptor(asset).measured_aabb
			var run := 1
			while tx.shell.exposed.has(Vector4i(key.x,key.y-run,key.z,key.w)): run+=1
			report.append({"id":id,"asset":str(asset),"cell":[cell.x,cell.y,cell.z],"direction":key.w,"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z],"run_bands":run,"lower_retained":tx.retained.has(cell+Vector3i.DOWN),"lower_solid":tx.solids.has(cell+Vector3i.DOWN),"treatment":int(tx.shell.treatments[key]),"turf":tx.capped_ground.has(cell)})
	FileAccess.open("/tmp/september10-skin-"+("base" if "--base" in OS.get_cmdline_user_args() else "ceiling")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
