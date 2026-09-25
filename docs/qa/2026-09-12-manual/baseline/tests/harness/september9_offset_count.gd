extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-offset-source.txt"),program)
	var payload := SettlementFabricAssembler.terrace_retaining_payload(spatial.compiled_fabric_cache())
	var report := {}
	for prefix in ["maze-outcrop/-1/3/11/3","maze-outcrop/-3/3/11/3"]:
		var row := {"pieces":[],"braces":0}
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			for i in batch.ids.size():
				var id := String(batch.ids[i])
				if not id.begins_with(prefix): continue
				row.pieces.append({"id":id,"asset":str(asset),"pose":str(batch.transforms[i])})
				row.braces += int(id.contains("/brace/"))
		report[prefix] = row
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
