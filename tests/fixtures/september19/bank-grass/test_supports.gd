extends GutTest
const SUPPORTS=preload("res://tests/fixtures/september19/bank-grass/supports.gd")
var banks:Array=[]
func before_all()->void:
 banks=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/banks.bin",FileAccess.READ).get_var()
func test_real_bank_turf_has_grass_support()->void:
 var caps:=SUPPORTS.surfaces(banks,Rect2(-576,192,192,192))
 assert_gt(caps.size(),0,"Wet-bank admission must publish its actual dry ledge surfaces to grass")
 var index:=GrassSupportSurfaces.spatial_index(caps)
 var supported:=0
 for bank:Dictionary in banks:
  for i in range(0,bank.green.size(),3):
   var local:Vector3=(bank.green[i]+bank.green[i+1]+bank.green[i+2])/3
   var point:Vector3=bank.transform*local
   var sample:=GrassSupportSurfaces.at_index(index,Vector2(point.x,point.z))
   if sample.is_empty():continue
   if absf(sample.y-point.y)<.001:supported+=1
 assert_gt(supported,10,"The support must be exposed on the real bank, not occluded by the old wider source solid")
