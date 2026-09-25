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

func test_independent_cuts_fade_at_thin_native_attachment_but_keep_thick_crags()->void:
 CRAGS.prepare()
 var samples:=0;var deepest_cut:=0.0
 for u in range(-12,13):
  var y:=15.0;var core:=2.0;var crest:=16.0
  var plain:float=CRAGS._body_depth(u,y,core,crest,0,2697992464,[],[])
  var thickness:float=CRAGS._projection(plain)-CRAGS._native_depth(u,y)
  if thickness<0 or thickness>.45:continue
  var fractures:Array=[[[[y,1.0,.5]],float(u)+10.0,2697992464]]
  var cut:float=CRAGS._body_depth(u,y,core,crest,0,2697992464,fractures,[])
  deepest_cut=maxf(deepest_cut,plain-cut);samples+=1
 assert_gt(samples,5,"Exercise exposed thin roots, not buried backs")
 assert_lt(deepest_cut,.12,"Independent cuts must not punch through a thin native attachment")
 var plain:float=CRAGS._body_depth(0,8,5,16,0,2697992464,[],[])
 var cut:float=CRAGS._body_depth(0,8,5,16,0,2697992464,[[[[8.0,1.0,.5]],10.0,2697992464]],[])
 assert_gt(plain-cut,.4,"Full fracture depth remains on the thick independent rock")
 print("THIN_CRAG_CUT samples=",samples," depth=",deepest_cut," thick=",plain-cut)
