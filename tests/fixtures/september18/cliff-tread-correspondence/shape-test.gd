extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-layered-bodies/before.gd")
const AFTER=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func test_riser_correction_retains_sampled_shape_and_complete_turf()->void:
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var moved:=0;var missing:=0;var turf_changed:=0;var triangle_changes:=0
 for a:Array in anchors:
  var old:Dictionary=BEFORE.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var current:Dictionary=AFTER.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var previous:Dictionary={};var revised:Dictionary={}
  for p:Vector3 in old.faces:previous[p]=true
  for p:Vector3 in current.faces:
   revised[p]=true
   if not previous.has(p):moved+=1
  for p:Vector3 in previous:
   if not revised.has(p):missing+=1
  var turf:Dictionary={}
  for i in range(0,old.green.size(),3):turf[[old.green[i],old.green[i+1],old.green[i+2]]]=true
  for i in range(0,current.green.size(),3):
   if not turf.erase([current.green[i],current.green[i+1],current.green[i+2]]):turf_changed+=1
  turf_changed+=turf.size()
  triangle_changes+=absi(current.faces.size()-old.faces.size())
 print("RISER_PRESERVATION formations=",anchors.size()," new_vertices=",moved," missing_vertices=",missing," changed_turf_triangles=",turf_changed," triangle_count_difference=",triangle_changes)
 assert_eq(moved+missing,0,"Retain the actual crown, rock and rooted outline samples")
 assert_eq(turf_changed,0,"Retain the complete ledge triangles, not only a few cap rays")
 assert_eq(triangle_changes,0,"The correction does not increase geometry density")
