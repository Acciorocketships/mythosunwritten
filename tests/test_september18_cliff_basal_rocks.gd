extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-basal-rocks/before.gd")
func test_reported_short_walls_gain_local_grounded_rock_without_pushing_upper_faces_out()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var widened:=0;var unchanged:=0;var sampled:=0;var upper_change:=0.0;var max_delta:=0.0
 var upper_basal:=0.0;var upper_samples:=0
 for index:int in [11,20]:
  var a:Array=anchors[index]
  var before:Dictionary=BEFORE.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var after:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var old:=_outline(before.faces);var current:=_outline(after.faces)
  var pose:Transform3D=a[0]
  var salt:=2697992464+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
  var profiles:Dictionary={}
  for key:Vector2 in current:
   if key.y<=a[2]*.65:continue
   if not profiles.has(key.x):profiles[key.x]=source._basal_profile(pose.origin.dot(pose.basis.x)+key.x,a[2],salt)
   upper_basal=maxf(upper_basal,source._basal_depth(key.y,a[2],profiles[key.x]));upper_samples+=1
  for key:Vector2 in old:
   if not current.has(key):continue
   var delta:float=current[key]-old[key]
   # Retain the historical surface delta as a diagnostic. Removing rejected
   # cracks legitimately fills their valleys; it is not added basal growth.
   if key.y>a[2]*.65:upper_change=maxf(upper_change,delta)
   if key.y>0 or old[key]<.01:continue
   sampled+=1;max_delta=maxf(max_delta,delta)
   if delta>.5:widened+=1
   if absf(delta)<.05:unchanged+=1
 print("BASAL_FOOT sampled=",sampled," widened=",widened," retained=",unchanged," upper_change=",upper_change," max_delta=",max_delta," upper_basal=",upper_basal," upper_samples=",upper_samples)
 assert_gt(sampled,50,"Survey the photographed formations' actual closed roots")
 assert_gt(widened,10,"Some lower rock must project visibly beyond the current near-wall footprint")
 assert_gt(unchanged,10,"Leave recessed root intervals rather than adding one continuous plinth")
 # Isolate basal support from later upper-surface art changes. The independent
 # attachment/lip tests constrain the complete current upper silhouette.
 assert_gt(upper_samples,100)
 assert_lt(upper_basal,.001,"Basal support must not add any projection to the upper wall")
 assert_lt(max_delta,3.5,"Keep the local added reach moderate")
func _outline(faces:PackedVector3Array)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in faces:
  if p.z<0:continue
  var key:=Vector2(p.x,p.y).snapped(Vector2.ONE*.0001)
  result[key]=maxf(result.get(key,-INF),p.z)
 return result
