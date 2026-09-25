extends SceneTree
const ROOT="res://docs/qa/2026-09-19-manual/106-town-path-context/"
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
 var report:Dictionary={"transform":str(urban.world_transform),"roads":urban.world_road_connections,"shapes":[],"urban":{},"record":{},"frame":{}}
 for item:Array in [[urban,report.urban],[record,report.record],[frame,report.frame]]:
  for property:Dictionary in item[0].get_property_list():
   if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:continue
   if property.name in ["surfaces","entries","surface_meshes","fabric_plan","volumetric_spatial"]:continue
   var value=item[0].get(property.name)
   if value is Object:continue
   item[1][property.name]=str(value)
 var area:=Rect2(Vector2(-1070,1045),Vector2(50,45))
 for shape:FeatureGroundShape in urban.surfaces:
  if not shape.bounds().intersects(area):continue
  report.shapes.append({"id":str(shape.stable_id),"kind":shape.kind,"surface":shape.surface_id,"priority":shape.priority,"a":str(shape._a),"b":str(shape._b),"radius":shape._radius,"half":str(shape._half_extents),"angle":shape._angle})
 FileAccess.open(output.path_join("world-source.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 FileAccess.open(output.path_join("surface-shapes.bin"),FileAccess.WRITE).store_var(report)
 var skin:=SettlementFabricAssembler.maze_ground_skin_transaction(urban.fabric_plan)
 FileAccess.open(output.path_join("plan-evidence.bin"),FileAccess.WRITE).store_var({"transform":urban.world_transform,"roads":urban.world_road_connections,"retained":skin.retained,"entries":urban.entries,"bounds":VillageWarrenFabricSolver._local_bounds(urban.fabric_plan),"contacts":VillageWarrenFabricSolver.terrain_contact_specs(urban.volumetric_spatial,urban.fabric_plan)})
 print("TOWN_PATH_WORLD_SOURCE ",report.shapes.size()," local surface owners, ",report.roads.size()," road connections")
 quit()
