extends SceneTree
const EXPOSE=preload("res://tests/fixtures/september19/bank-exposure/exposure.gd")
const OUT="res://docs/qa/2026-09-19-manual/128-bank-exposure"
func _init()->void:
 preload("res://scripts/terrain/field/CliffRockDressing.gd").prepare()
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/127-bank-preserved-relief/validated-banks.bin",FileAccess.READ).get_var()
 var plants:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/127-bank-preserved-relief/plants.bin",FileAccess.READ).get_var()
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var result:=EXPOSE.filter(plants,sources,banks)
 FileAccess.open(OUT.path_join("plants.bin"),FileAccess.WRITE).store_var(result)
 var ids:Dictionary={}
 for plant:Dictionary in result:ids[plant.id]=true
 var rejected:Array=[]
 for plant:Dictionary in plants:
  if not ids.has(plant.id):rejected.append({"id":plant.id,"root":plant.support_point})
 FileAccess.open(OUT.path_join("selection.json"),FileAccess.WRITE).store_string(JSON.stringify({"before":plants.size(),"after":result.size(),"rejected":rejected},"  "))
 print("BANK_EXPOSE_BUILD ",result.size()," / ",plants.size())
 quit()
