extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-upper-relief/before.gd")
func test_tall_upper_face_receives_physical_form_without_changing_crown()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 for height:float in [32,64]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var old:Dictionary=BEFORE.make(pose,48,height,2697992464)[0]
  var now:Dictionary=source.make(pose,48,height,2697992464)[0]
  var changed:Dictionary={};var columns:Dictionary={};var crown:=0.0
  for i in old.faces.size():
   var p:Vector3=old.faces[i];var q:Vector3=now.faces[i]
   var delta:=p.distance_to(q)
   if p.y>height-1.3:crown=maxf(crown,delta)
   if p.y<height*.75 or p.y>height-2.0 or p.z<0:continue
   if delta>.08:changed[p]=true;columns[p.x]=true
  print("UPPER_RELIEF height=",height," changed=",changed.size()," columns=",columns.size()," crown=",crown)
  assert_gt(changed.size(),100,"Upper tall rock faces need physical forms as well as the base")
  assert_gt(columns.size(),20,"Variation must reach a broad part of the upper wall")
  assert_lt(crown,.001,"Preserve the native crown attachment")
