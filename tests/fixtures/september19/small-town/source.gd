extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/119-small-town"
func _init()->void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=FeatureProgram.compile(catalog)
	var water:=TerrainWorldTuning.make_water(2697992464)
	var heightfield:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(heightfield,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
	var world:=WorldFeaturePlan.new(2697992464,water,fields,program,SettlementPlan.new(2697992464,water))
	var frame:=world.frame_for(Vector2i(-1,0))
	assert(frame!=null)
	var record:=world.village_plan().record_for(frame)
	assert(record!=null and not record.is_empty())
	var urban:=record.urban_fabric
	var report:={"tier":record.tier,"centre":record.centre,"frame_cell":frame.cell,"transform":urban.world_transform,"generation_kind":urban.generation_kind,"audit":urban.fabric_audit,"surfaces":[],"entries":[]}
	for surface:Dictionary in record.payload.surface_meshes:
		var brief:=surface.duplicate()
		for key in ["vertices","normals","indices","uvs","collision_faces","colors"]:
			if brief.has(key):brief[key]=str(brief[key].size())+" values"
		report.surfaces.append(brief)
	for entry:Dictionary in urban.entries:report.entries.append(entry)
	FileAccess.open(OUT.path_join("payload.bin"),FileAccess.WRITE).store_var({"batches":record.payload.batches,"collision_boxes":record.payload.collision_boxes,"surface_meshes":record.payload.surface_meshes,"transform":urban.world_transform})
	if urban.volumetric_spatial!=null:
		var source:WarrenMazeSourcePlan=urban.volumetric_spatial.source_volume.mass_context.get(&"maze_source_plan")
		var values:Dictionary={};var excavation:Dictionary={}
		for key in ["passage_kinds","market_zone","market_square_cells","feature_stamps","summit_cell","block_thickness","plots","audit"]:values[key]=source.get(key)
		for key in ["route","lanes","loop_edges","bridge_spans","bridge_span_audit","frontage_reservations","carved","covered","transitions","portals"]:excavation[key]=source.excavation.get(key)
		var frozen:={"world_seed":source.world_seed,"profile":source.scale_profile.scale_id,"massif_columns":source.massif.columns,"massif_core":source.massif.core_top_bands,"excavation":excavation,"source":values}
		FileAccess.open(OUT.path_join("source.txt"),FileAccess.WRITE).store_string(var_to_str(frozen))
	FileAccess.open(OUT.path_join("source.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SMALL_TOWN_SOURCE tier=",record.tier," centre=",record.centre," kind=",urban.generation_kind)
	quit()
