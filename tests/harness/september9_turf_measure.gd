extends SceneTree

func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-thin-turf-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.terrace_retaining_payload(fabric)
	var collision_batches: Dictionary = {}
	for asset: StringName in payload.batches:
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		if not visual.collisions.is_empty(): collision_batches[asset] = payload.batches[asset]
	var collision: Array = [collision_batches,payload.collision_boxes]
	var ground: Array = []
	var report := {"soil_meshes":0,"soil_vertices":0,"border_meshes":0,"border_vertices":0,"suspended_cells":SettlementFabricAssembler.maze_ground_skin_transaction(fabric).suspended_plaza.size()}
	for mesh: Dictionary in payload.surface_meshes:
		if not (mesh.collision_faces as PackedVector3Array).is_empty():
			collision.append([mesh.stable_id,mesh.collision_faces])
		if mesh.get("terrain_ground",false): ground.append(mesh)
		if mesh.get("soil_bed",false):
			report.soil_meshes += 1
			report.soil_vertices += (mesh.vertices as PackedVector3Array).size()
		if mesh.get("lawn_border",false):
			report.border_meshes += 1
			report.border_vertices += (mesh.vertices as PackedVector3Array).size()
	report.collision_sha256 = var_to_str(collision).sha256_text()
	report.ground_sha256 = var_to_str(ground).sha256_text()
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TURF_MEASURE ",report)
	quit()
