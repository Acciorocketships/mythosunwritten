extends GutTest
func test_added_tall_skin_covers_the_native_relief_between_joins()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load(path)
 var height:=64.0
 var form:Dictionary=source.make(Transform3D.IDENTITY,48,height,2697992464)[0]
 var checked:=0;var covered:=0;var points:Dictionary={}
 var native_peak:=0.0
 for value:float in source._wall_depth:native_peak=maxf(native_peak,value)
 for p:Vector3 in form.faces:
  if p.y<2 or p.y>height-3 or p.z<0 or absf(p.x)>20:continue
  points[p]=true
 for p:Vector3 in points:
  checked+=1
  if p.z>native_peak+.02:covered+=1
 var fraction:=float(covered)/maxi(1,checked)
 print("INDEPENDENT_SKIN samples=",checked," coverage=",fraction," native_peak=",native_peak)
 assert_gt(checked,1000)
 assert_gt(fraction,.98,"Away from real attachment edges, tile crests must not break through the added continuous stone")
