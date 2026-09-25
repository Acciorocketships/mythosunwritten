extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/125-bank-domains"
const FIT=preload("res://tests/fixtures/september19/bank-attachments/fit.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:run.call_deferred()
func run()->void:
 ROCKS.prepare()
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var candidates:Array=[]
 var common:=Rect2(-602,166,244,52)
 for source:Dictionary in sources:
  var footprint:=ROCKS._footprint(source.bounds)
  if common.encloses(footprint.grow(3)):candidates.append(source)
 print("BANK_DOMAIN candidates=",candidates.size())
 var results:Array=[];var times:Array=[]
 for key:Vector2i in [Vector2i(-3,0),Vector2i(-3,1)]:
  # Separate plans and caches exercise independently built canonical water
  # domains, not two coverage wrappers over one already-computed field.
  var hydraulic:=TerrainWorldTuning.make_water(2697992464)
  var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
  var start:=Time.get_ticks_msec()
  fields.profile_callback=func(event,phase,owner,elapsed):print("BANK_DOMAIN_FIELD ",event," ",phase," ",owner," ",elapsed)
  var region:=fields.region(key);var water:=fields.water(key)
  var output:Dictionary={}
  for source:Dictionary in candidates:
   assert(water.coverage().encloses(ROCKS._footprint(source.bounds).grow(3)))
   output[source.id]=FIT.fit(source,region,water) if ROCKS._wet_formation(source,water) else source
  results.append(output);times.append(Time.get_ticks_msec()-start)
  FileAccess.open(OUT.path_join("domain-%d.bin"%key.y),FileAccess.WRITE).store_var(output)
  print("BANK_DOMAIN_DONE ",key," milliseconds=",times[-1])
 var rows:Array=[];var failures:=0;var banks:=0
 for id:String in results[0]:
  var a:Dictionary=results[0][id];var b:Dictionary=results[1][id]
  var equal:=var_to_bytes(a)==var_to_bytes(b)
  if not equal:failures+=1
  if not a.is_empty() and a.get("replay_recipe",{}).has("shore_level"):banks+=1
  rows.append({"id":id,"same":equal,"accepted_a":not a.is_empty(),"accepted_b":not b.is_empty(),"bank_a":a.get("replay_recipe",{}).has("shore_level")})
 var report:={"candidates":candidates.size(),"bank_forms":banks,"failures":failures,"elapsed_ms":times,"rows":rows}
 FileAccess.open(OUT.path_join("comparison.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BANK_DOMAIN_RESULT ",report)
 quit(0 if failures==0 and banks>0 else 1)
