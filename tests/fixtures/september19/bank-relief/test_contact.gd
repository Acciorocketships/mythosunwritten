extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const OLD=preload("res://tests/fixtures/september19/bank-attachments/shape.gd")
const CURRENT=preload("res://tests/fixtures/september19/bank-relief/shape.gd")
func test_compression_preserves_original_native_wall_contacts()->void:
 ROCKS.prepare()
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/all-banks.bin",FileAccess.READ).get_var()
 var baseline_losses:=0;var losses:=0;var overshoots:=0;var changes_buried:=0;var examined:=0
 var mapper=OLD if OS.get_environment("BANK_CONTACT_BASELINE")=="1" else CURRENT
 for bank:Dictionary in banks:
  if bank.replay_recipe.kind!="wall":continue
  var seen:Dictionary={}
  for p:Vector3 in bank.shore_source_faces:
   if seen.has(p):continue
   seen[p]=true
   var native:float=ROCKS.CRAGS._native_depth(bank.transform.origin.dot(bank.transform.basis.x)+p.x,p.y)
   var old:Vector3=OLD.point(p,bank)[0];var q:Vector3=mapper.point(p,bank)[0]
   if p.z>native+.05:
    examined+=1
    if old.z<native+.01:baseline_losses+=1
    if q.z<native+.01:losses+=1
    if q.z>p.z+.00001:overshoots+=1
   elif p.z<=native and q.distance_to(old)>.000001:changes_buried+=1
 print("BANK_CONTACT examined=",examined," baseline_losses=",baseline_losses," losses=",losses," overshoots=",overshoots," changed_buried=",changes_buried)
 assert_gt(examined,1000)
 assert_gt(baseline_losses,100,"Demonstrate lost original surface contacts before testing the repair")
 assert_eq(losses,0,"An exposed source surface must not disappear behind its native backing")
 assert_eq(overshoots,0,"Contact preservation cannot protrude farther than the original source")
 assert_eq(changes_buried,0,"Keep the existing buried seams and crown roots")
