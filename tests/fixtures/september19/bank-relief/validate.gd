extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/126-bank-relief"
const FIT=preload("res://tests/fixtures/september19/bank-relief/fit.gd")
const ATTACH=preload("res://tests/fixtures/september19/bank-relief/attachments.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:run.call_deferred()
func run()->void:
 ROCKS.prepare()
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 fields.profile_callback=func(event,phase,owner,elapsed):print("BANK_FIELD ",event," ",phase," ",owner," ",elapsed)
 var region:=fields.region(Vector2i(-3,1));var water:=fields.water(Vector2i(-3,1))
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var proposals:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/source-plants.bin",FileAccess.READ).get_var()
 var studied:Array=FileAccess.open(OUT.path_join("banks.bin"),FileAccess.READ).get_var()
 var study:Dictionary={}
 for bank:Dictionary in studied:study[bank.id]=bank
 var banks:Array=[];var rows:Array=[];var mismatches:=0;var dry:=0
 for source:Dictionary in sources:
  var cell:=Vector2i(floori((source.anchor.x+12)/24),floori((source.anchor.z+12)/24))
  if cell.x < -24 or cell.x >= -16 or cell.y < 8 or cell.y >= 16:continue
  if not ROCKS._wet_formation(source,water):dry+=1;continue
  var fitted:=FIT.fit(source,region,water)
  var row:={"id":source.id,"accepted":not fitted.is_empty(),"studied":study.has(source.id)}
  if not fitted.is_empty():
   var equal:=study.has(source.id) and var_to_bytes(fitted.faces)==var_to_bytes(study[source.id].faces) and var_to_bytes(fitted.green)==var_to_bytes(study[source.id].green)
   row["same_studied_geometry"]=equal
   if not equal:mismatches+=1
   fitted.render_arrays=ROCKS.CRAGS.mesh_arrays(fitted)
   banks.append(fitted)
  elif study.has(source.id):mismatches+=1
  rows.append(row)
 var plants:=ATTACH.publish(proposals,sources,banks,region,null,water)
 FileAccess.open(OUT.path_join("validated-banks.bin"),FileAccess.WRITE).store_var(banks)
 FileAccess.open(OUT.path_join("plants.bin"),FileAccess.WRITE).store_var(plants)
 var report:={"dry_forms":dry,"wet_candidates":rows.size(),"admitted":banks.size(),"studied":study.size(),"geometry_mismatches":mismatches,"plants":plants.size(),"rows":rows}
 FileAccess.open(OUT.path_join("admission.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BANK_VALIDATED ",banks.size()," plants=",plants.size()," mismatches=",mismatches)
 quit(0 if mismatches==0 and banks.size()==study.size() else 1)
