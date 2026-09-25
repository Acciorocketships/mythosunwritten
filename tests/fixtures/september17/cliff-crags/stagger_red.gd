extends GutTest
const CRAGS=preload("res://tests/fixtures/september17/cliff-crags/before_stagger.gd")
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

func test_fractures_do_not_leave_entire_smooth_columns_between_clusters()->void:
 var widest_gap:=0.0
 for u in range(-24,25):
  var levels:Array[float]=[0.0,64.0]
  for entry:Array in CRAGS._fracture_profile(u,64,2697992464):
   for joint:Array in entry[0]:
    if joint[1]>.25:levels.append(clampf(joint[0],0,64))
  levels.sort()
  for i in range(1,levels.size()):widest_gap=maxf(widest_gap,levels[i]-levels[i-1])
 print("FRACTURE_LATERAL_GAP ",widest_gap)
 assert_lt(widest_gap,12.0,"Irregular fractures must also cross gaps between vertical clusters")
