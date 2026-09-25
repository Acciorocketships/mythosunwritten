extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/122-bank-attachments"
const ATTACH=preload("res://tests/fixtures/september19/bank-attachments/attachments.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:run.call_deferred()
func run()->void:
 ROCKS.prepare()
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 var region:=fields.region(Vector2i(-3,1));var water:=fields.water(Vector2i(-3,1))
 var sources:Array=FileAccess.open(OUT.path_join("sources.bin"),FileAccess.READ).get_var()
 var proposals:Array=FileAccess.open(OUT.path_join("source-plants.bin"),FileAccess.READ).get_var()
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/banks.bin",FileAccess.READ).get_var()
 var plants:=ATTACH.publish(proposals,sources,banks,region,null,water)
 FileAccess.open(OUT.path_join("plants.bin"),FileAccess.WRITE).store_var(plants)
 var rows:Array=[]
 for plant:Dictionary in plants:rows.append({"id":plant.id,"root":plant.support_point,"normal":plant.support_normal,"bounds":plant.bounds,"asset":plant.asset})
 FileAccess.open(OUT.path_join("plants.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("BANK_NATIVE_PLANTS ",plants.size()," banks=",banks.size())
 quit()
