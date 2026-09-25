extends SceneTree
const ROOT="res://docs/qa/2026-09-19-manual/107-town-road-corner/"
func _init()->void:
 var output:=ROOT.path_join("after-source") if "--after" in OS.get_cmdline_user_args() else ROOT
 DirAccess.make_dir_recursive_absolute(output)
 var catalog:=EnvironmentCatalog.load_default()
 var program:=FeatureProgram.compile(catalog)
 var water:=TerrainWorldTuning.make_water(2697992464)
 var heightfield:=TerrainWorldTuning.make_heightfield(2697992464,water)
 var fields:=WorldFieldBlockCache.new(heightfield,water,program.query_margin,program.shore_distance_limit,program.field_cache_cap)
 var world:=WorldFeaturePlan.new(2697992464,water,fields,program,SettlementPlan.new(2697992464,water))
 var frame:=world.frame_for(Vector2i(-2,1))
 var record:=world.village_plan().record_for(frame)
 var urban:VillageUrbanFabricPlan=record.urban_fabric
 var ground := frame.path_ground
 var shapes: Array = []
 for shape: FeatureGroundShape in ground._surface_shapes + urban.surfaces:
  shapes.append({"kind":shape.kind,"surface_id":shape.surface_id,"priority":shape.priority,"stable_id":shape.stable_id,"_a":shape._a,"_b":shape._b,"_radius":shape._radius,"_half_extents":shape._half_extents,"_angle":shape._angle})
 FileAccess.open(output.path_join("field.bin"),FileAccess.WRITE).store_var({"shapes":shapes,"masks":ground._connection_masks,"nodes":ground._node_cells,"priorities":ground._surface_priorities,"roads":urban.world_road_connections})
 print("CORNER_FIELD_SAVED ", shapes.size(), " shapes, ",ground._connection_masks.size()," cells")
 quit()
