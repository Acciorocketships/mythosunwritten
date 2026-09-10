extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var rows: Array = []
	for label in ["east","offset","thin-turf"]:
		var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-%s-source.txt"%label),program)
		var fabric := spatial.compiled_fabric_cache()
		var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
		var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
		payload.append_from(SettlementFabricAssembler.payload(fabric))
		var lamps: Array = []
		for id: StringName in payload.batches:
			if not (String(id).contains("prop.") or String(id).contains("flower")):continue
			var batch: Dictionary = payload.batches[id]
			for i in batch.transforms.size():lamps.append({"id":String(batch.ids[i]),"asset":String(id),"transform":str(batch.transforms[i])})
		rows.append({"source":label,"lamps":lamps,"garden_cells":transaction.garden.size(),"public_cells":transaction.walked.size(),"garden":str(transaction.garden.keys())})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print(rows)
	quit()
