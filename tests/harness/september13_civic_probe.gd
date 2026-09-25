extends SceneTree
func _init() -> void:
	var program:=FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water:=TerrainWorldTuning.make_water(2697992464)
	var heightfield:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(heightfield,water,program.query_margin,
		program.shore_distance_limit,program.field_cache_cap)
	var world:=WorldFeaturePlan.new(2697992464,water,fields,program,SettlementPlan.new(2697992464,water))
	var record:=world.village_plan().record_for(world.frame_for(Vector2i(0,0)))
	var urban:=record.urban_fabric
	var report:Dictionary={"transform":urban.world_transform,"audit":urban.fabric_audit,"entries":urban.entries,"surfaces":[],"claims":urban.terrain_grade._claims}
	for shape:FeatureGroundShape in urban.surfaces:
		var data:Dictionary={}
		for prop:Dictionary in shape.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: data[prop.name]=shape.get(prop.name)
		report.surfaces.append(data)
	var output:="res://docs/qa/2026-09-13-manual/20-civic/source.txt"
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(var_to_str(report))
	print("STREET_SOURCE ",report.transform," shapes=",report.surfaces.size())
	quit()
