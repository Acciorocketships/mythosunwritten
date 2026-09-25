extends SceneTree
const TRACE=preload("res://tests/fixtures/september19/bank-exposure/trace.gd")
const OUT="res://docs/qa/2026-09-19-manual/128-bank-exposure"
func _init()->void:
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/127-bank-preserved-relief/validated-banks.bin",FileAccess.READ).get_var()
 var plants:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/127-bank-preserved-relief/plants.bin",FileAccess.READ).get_var()
 var rows:Array=[]
 for plant:Dictionary in plants:
  var contact:=TRACE.first_contact(plant,banks)
  rows.append({"id":plant.id,"owner":plant.support_id,"root":plant.support_point,"contact":contact,"valid":not contact.is_empty() and contact.id==plant.support_id and contact.root_gap<.005})
 FileAccess.open(OUT.path_join("contacts-before.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("BANK_EXPOSURE ",rows.filter(func(r):return not r.valid))
 quit()
