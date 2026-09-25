extends GutTest
const RAW=preload("res://tests/fixtures/september18/cliff-relief-transitions/unshaped.gd")
func test_added_relief_does_not_form_abrupt_fins_on_connected_faces()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var raw:PackedVector3Array=RAW.make(pose,48,32,2697992464)[0].faces
 var faces:PackedVector3Array=source.make(pose,48,32,2697992464)[0].faces
 var sampled:=0;var excessive:=0;var maximum:=0.0
 for i in range(0,faces.size(),3):
  for j in 3:
   var k:int=(j+1)%3
   var a:Vector3=raw[i+j];var b:Vector3=raw[i+k]
   if a.z<=0.0 or b.z<=0.0:continue
   var span:=Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y))
   if span<.1 or span>.35:continue
   var depth_change:=absf((faces[i+j].z-a.z)-(faces[i+k].z-b.z))
   var excess:=depth_change-span*1.1
   maximum=maxf(maximum,excess);sampled+=1
   if excess>.001:excessive+=1
 print("ADDED_RELIEF_FINS sampled=",sampled," excessive=",excessive," max_excess=",maximum)
 assert_gt(sampled,10000,"Inspect real densely sampled wall faces")
 assert_eq(excessive,0,"New relief must not introduce steep fins across short connected face edges")
