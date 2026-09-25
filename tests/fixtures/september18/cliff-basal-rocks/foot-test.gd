extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-basal-rocks/before.gd")
func test_reported_short_walls_gain_local_grounded_rock_without_moving_upper_faces()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var widened:=0;var unchanged:=0;var sampled:=0;var upper_change:=0.0;var max_delta:=0.0
 for index:int in [11,20]:
  var a:Array=anchors[index]
  var before:Dictionary=BEFORE.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var after:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var old:=_outline(before.faces);var current:=_outline(after.faces)
  for key:Vector2 in old:
   if not current.has(key):continue
   var delta:float=current[key]-old[key]
   if key.y>a[2]*.65:upper_change=maxf(upper_change,absf(delta))
   if key.y>0 or old[key]<.01:continue
   sampled+=1;max_delta=maxf(max_delta,delta)
   if delta>.5:widened+=1
   if absf(delta)<.05:unchanged+=1
 print("BASAL_FOOT sampled=",sampled," widened=",widened," retained=",unchanged," upper_change=",upper_change," max_delta=",max_delta)
 assert_gt(sampled,50,"Survey the photographed formations' actual closed roots")
 assert_gt(widened,10,"Some lower rock must project visibly beyond the current near-wall footprint")
 assert_gt(unchanged,10,"Leave recessed root intervals rather than adding one continuous plinth")
 assert_lt(upper_change,.001,"The new basal rock must not push the upper wall forward")
 assert_lt(max_delta,3.5,"Keep the local added reach moderate")
func _outline(faces:PackedVector3Array)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in faces:
  if p.z<0:continue
  var key:=Vector2(p.x,p.y).snapped(Vector2.ONE*.0001)
  result[key]=maxf(result.get(key,-INF),p.z)
 return result
