extends GutTest
const CRAGS=preload("res://tests/fixtures/september17/cliff-crags/before.gd")
func test_tall_cliffs_retain_short_fractures_throughout_their_height()->void:
 var generator:GDScript=CRAGS
 var widest_gap:=0.0
 for height:float in [16,32,64]:
  for u:float in [-19,-3,8,23]:
   # Test inside a fracture cluster; lateral gaps between clusters are intentional.
   var center:float=generator._fracture_profile(u,height,2697992464)[1][1]
   var levels:Array[float]=[0.0,height]
   for entry:Array in generator._fracture_profile(center,height,2697992464):
    if absf(entry[1]-center)>.001:continue
    for joint:Array in entry[0]:levels.append(clampf(joint[0],0,height))
   levels.sort()
   for i in range(1,levels.size()):widest_gap=maxf(widest_gap,levels[i]-levels[i-1])
 print("FRACTURE_EMPTY_VERTICAL_SPAN ",widest_gap)
 assert_lt(widest_gap,6.0,"Tall faces should not contain stretched, detail-free intervals")
