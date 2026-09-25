extends GutTest
func test_generated_shoulders_do_not_have_wide_constant_depth_centres()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load(path)
 var curves:Dictionary={}
 for step in 385:
  var u:float=-24.0+step*.125
  for cut:Array in source._structural_terraces(u,16.0,2697992464):
   # The stable fall/grade pair identifies the same finite shoulder while
   # its top changes height with u. Test the proposed physical front profile.
   var key:=Vector2(cut[2],cut[3])
   if not curves.has(key):curves[key]=[]
   curves[key].append(Vector2(u,cut[1]))
 var widest:=0.0;var tested:=0
 for curve:Array in curves.values():
  if curve.size()<24:continue
  var peak:=0.0
  for sample:Vector2 in curve:peak=maxf(peak,sample.y)
  if peak<.5:continue
  tested+=1
  var start:=INF;var last:=-INF
  for sample:Vector2 in curve:
   if peak-sample.y>.005 or sample.x-last>.13:
    start=INF
   if peak-sample.y<=.005:
    if is_inf(start):start=sample.x
    widest=maxf(widest,sample.x-start)
   last=sample.x
 print("SHOULDER_CENTRES curves=",tested," widest_constant_depth=",widest)
 assert_gt(tested,4)
 assert_lt(widest,1.5,"Generated curved shoulders must not contain metres of identical front depth")
