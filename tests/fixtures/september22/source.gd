extends SceneTree
## Freezes one production town of seed 2697992464 for the September 22 review.
## Usage: -s source.gd -- --super=X,Z --out=res://docs/qa/2026-09-22-manual/town-e
func _init()->void:
	var super_cell:=Vector2i.ZERO
	var out:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--super="):
			var parts:=arg.trim_prefix("--super=").split(",")
			super_cell=Vector2i(int(parts[0]),int(parts[1]))
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var started:=Time.get_ticks_msec()
	var catalog:=EnvironmentCatalog.load_default()
	var program:=FeatureProgram.compile(catalog)
	var water:=TerrainWorldTuning.make_water(2697992464)
	var heightfield:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(heightfield,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var world:=WorldFeaturePlan.new(2697992464,water,fields,program,SettlementPlan.new(2697992464,water))
	var frame:=world.frame_for(super_cell)
	assert(frame!=null)
	var record:=world.village_plan().record_for(frame)
	assert(record!=null and not record.is_empty())
	var urban:=record.urban_fabric
	var report:={"tier":record.tier,"centre":record.centre,"frame_cell":frame.cell,"transform":urban.world_transform,"generation_kind":urban.generation_kind,"audit":urban.fabric_audit,"elapsed_ms":Time.get_ticks_msec()-started}
	FileAccess.open(out.path_join("payload.bin"),FileAccess.WRITE).store_var({"batches":record.payload.batches,"collision_boxes":record.payload.collision_boxes,"surface_meshes":record.payload.surface_meshes,"transform":urban.world_transform})
	if urban.volumetric_spatial!=null:
		var source:WarrenMazeSourcePlan=urban.volumetric_spatial.source_volume.mass_context.get(&"maze_source_plan")
		var values:Dictionary={};var excavation:Dictionary={}
		for key in ["passage_kinds","market_zone","market_square_cells","feature_stamps","summit_cell","block_thickness","plots","audit"]:values[key]=source.get(key)
		for key in ["route","lanes","loop_edges","bridge_spans","bridge_span_audit","frontage_reservations","carved","covered","transitions","portals"]:excavation[key]=source.excavation.get(key)
		var frozen:={"world_seed":source.world_seed,"profile":source.scale_profile.scale_id,"massif_columns":source.massif.columns,"massif_core":source.massif.core_top_bands,"massif_form":source.massif.form_id,"massif_open_court":source.massif.open_court,"excavation":excavation,"source":values}
		FileAccess.open(out.path_join("source.txt"),FileAccess.WRITE).store_string(var_to_str(frozen))
	FileAccess.open(out.path_join("source.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TOWN_SOURCE tier=",record.tier," centre=",record.centre," kind=",urban.generation_kind," transform=",urban.world_transform," ms=",Time.get_ticks_msec()-started)
	quit()
