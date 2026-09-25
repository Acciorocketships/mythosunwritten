extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/123-bank-grass"
const ROOT="res://docs/qa/2026-09-19-manual/122-bank-attachments"
const SUPPORTS=preload("res://tests/fixtures/september19/bank-grass/supports.gd")
const OLD=preload("res://tests/fixtures/september19/bank-grass/grass_before.gd")
const CORE=Rect2(-528,312,48,48)
class BankWaterWindow extends WaterFieldContext:
 var source:WaterFieldContext
 var outside:=0
 var queries:=0
 func has_sources()->bool:return source.has_sources()
 func is_wet(p:Vector2)->bool:
  queries+=1
  if not covers(p):outside+=1
  return source.is_wet(p)
 func level_at(p:Vector2)->float:
  queries+=1
  if not covers(p):outside+=1
  return source.level_at(p)
 func shore_distance_at(p:Vector2)->float:return source.shore_distance_at(p)
func window(source:WaterFieldContext,core:Rect2)->BankWaterWindow:
 var result:=BankWaterWindow.new();result.source=source;result._coverage=core.grow(26)
 return result
func _init()->void:run.call_deferred()
func run()->void:
 SUPPORTS.ROCKS.prepare()
 var catalog:=EnvironmentCatalog.load_default();var cache:=EnvironmentRenderCache.new(catalog)
 var program:=GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,cache)
 var max_radius:=0.0
 for asset:Dictionary in program.assets.values():max_radius=maxf(max_radius,asset.footprint_radius*program.scale_range.y+GrassField.CLIFF_FOOTPRINT_MARGIN)
 assert(max_radius<SUPPORTS.NEIGHBOR_REACH)
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,program.shore_distance_limit,8)
 var region:=fields.region(Vector2i(-3,1));var water:=fields.water(Vector2i(-3,1))
 var sources:Array=FileAccess.open(ROOT.path_join("sources.bin"),FileAccess.READ).get_var()
 var complete:=window(water,CORE)
 var admitted:=SUPPORTS.admit(sources,CORE,region,complete)
 var caps:=SUPPORTS.surfaces(admitted,CORE)
 FileAccess.open(OUT.path_join("admitted.bin"),FileAccess.WRITE).store_var(admitted)
 var proposals:Array=FileAccess.open(ROOT.path_join("source-plants.bin"),FileAccess.READ).get_var()
 var banks:Array=admitted.filter(func(p:Dictionary)->bool:return p.get("replay_recipe",{}).has("shore_level"))
 var foliage:=preload("res://tests/fixtures/september19/bank-grass/attachments.gd").publish(proposals,sources,banks,region,null,water)
 FileAccess.open(OUT.path_join("plants.bin"),FileAccess.WRITE).store_var(foliage)
 FileAccess.open(OUT.path_join("supports.bin"),FileAccess.WRITE).store_var(caps)
 print("BANK_GRASS supports=",caps.size()," rocks=",admitted.size()," footprint_radius=",max_radius)
 var outputs:Dictionary={};var rows:Array=[];var mismatch:=0;var new_roots:=0
 for tile:Vector2i in [Vector2i(-22,13),Vector2i(-21,13),Vector2i(-22,14),Vector2i(-21,14)]:
  var tile_core:=Rect2(Vector2(tile)*24,Vector2.ONE*24)
  var bounded:=window(water,tile_core)
  var local:=SUPPORTS.admit(sources,tile_core,region,bounded)
  var local_caps:=SUPPORTS.surfaces(local,tile_core)
  var full_payload:=GrassField.compute(program,2697992464,tile,region,complete,null,caps)
  var partial:=GrassField.compute(program,2697992464,tile,region,bounded,null,local_caps)
  var baseline:=OLD.compute(program,2697992464,tile,region,complete,null,caps)
  var equal:=var_to_bytes(full_payload.batches)==var_to_bytes(partial.batches)
  if not equal:mismatch+=1
  var count:=partial.instance_count-baseline.instance_count;new_roots+=count
  outputs[tile]={"before":baseline.batches,"after":partial.batches}
  var row:={"tile":tile,"before":baseline.instance_count,"after":partial.instance_count,"identical_whole_split":equal,"outside_queries":bounded.outside,"queries":bounded.queries,"local_rocks":local.size(),"local_caps":local_caps.size()}
  rows.append(row);print("BANK_GRASS_TILE ",row)
 FileAccess.open(OUT.path_join("payloads.bin"),FileAccess.WRITE).store_var(outputs)
 var report:={"tiles":rows,"new_instances":new_roots,"mismatches":mismatch,"whole_outside_queries":complete.outside,"max_patch_radius":max_radius}
 FileAccess.open(OUT.path_join("sampling.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BANK_GRASS_DONE ",report)
 quit(0 if mismatch==0 and complete.outside==0 and new_roots>0 else 1)
