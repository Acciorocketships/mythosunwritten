extends GutTest
const BASE=preload("res://tests/fixtures/september18/cliff-formation-sampling/before.gd")
func test_added_formations_have_broad_contacts_in_actual_mesh()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://tests/fixtures/september18/cliff-formation-sampling/embedded-before.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var before:PackedVector3Array=BASE.make(pose,48,32,2697992464)[0].faces
 var after:PackedVector3Array=source.make(pose,48,32,2697992464)[0].faces
 assert_eq(after.size(),before.size(),"This contact repair preserves the closed source topology")
 if before.size()!=after.size():return
 var checked:=0;var fins:=0;var added:=0;var maximum:=0.0
 for i in range(0,before.size(),3):
  for j in 3:
   var a:=i+j;var b:=i+(j+1)%3
   var pa:Vector3=before[a];var pb:Vector3=before[b]
   if minf(pa.z,pb.z)<.5:continue
   var distance:=Vector2(pa.x,pa.y).distance_to(Vector2(pb.x,pb.y))
   if distance<.02:continue
   var delta:float=absf((after[a].z-pa.z)-(after[b].z-pb.z))
   checked+=1
   if delta>.25 and delta/distance>2.0:fins+=1
   if after[a].z-pa.z>.25:added+=1
   maximum=maxf(maximum,after[a].z-pa.z)
 print("ROCK_CONTACTS checked=",checked," fins=",fins," moved=",added," max_gain=",maximum)
 assert_gt(checked,10000)
 assert_eq(fins,0,"A small contact strip must not create a steep quarter-metre fin")
 assert_gt(added,500,"Removing fins must retain actual formations rather than flatten the wall")
 assert_gt(maximum,.45,"Retain substantial physical depth")
