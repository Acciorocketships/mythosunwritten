extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(fabric)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
	var old: Dictionary = FileAccess.open("res://docs/qa/2026-09-16-manual/05-town-rails/before-payload.bin",FileAccess.READ).get_var()
	var result := {"batches_identical":old.batches == payload.batches,"collision_boxes_identical":old.collision_boxes == payload.collision_boxes,"changed_meshes":[],"unchanged_meshes":0}
	for i in payload.surface_meshes.size():
		if old.surface_meshes[i] == payload.surface_meshes[i]: result.unchanged_meshes += 1
		else: result.changed_meshes.append({"index":i,"before_vertices":old.surface_meshes[i].vertices.size(),"after_vertices":payload.surface_meshes[i].vertices.size()})
	var previous := _instances(old.batches)
	var current := _instances(payload.batches)
	result["removed"] = []
	result["added"] = []
	result["changed"] = []
	for id in previous:
		if not current.has(id): result.removed.append(id)
		elif previous[id] != current[id]: result.changed.append(id)
	for id in current:
		if not previous.has(id): result.added.append(id)
	result.removed.sort()
	assert(result.removed == ["public-guard/-3:4:8:0:-1","public-guard/-4:4:8:0:-1"])
	assert(result.added.is_empty() and result.changed.is_empty())
	var path := "res://docs/qa/2026-09-16-manual/05-town-rails/"
	FileAccess.open(path+"payload-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	FileAccess.open(path+"after-payload.bin",FileAccess.WRITE).store_var({"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,"transform":old.transform,"walked":SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)})
	print("RAIL_PAYLOAD ",result)
	quit()

func _instances(batches: Dictionary) -> Dictionary:
	var result := {}
	for asset in batches:
		var batch: Dictionary = batches[asset]
		for i in batch.ids.size():
			result[String(batch.ids[i])] = [asset,batch.transforms[i],batch.colors[i],batch.collision_enabled[i]]
	return result
