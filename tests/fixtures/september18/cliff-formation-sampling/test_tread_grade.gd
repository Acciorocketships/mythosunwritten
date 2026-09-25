extends GutTest
func test_actual_tread_grade_survives_body_projection()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://tests/fixtures/september18/cliff-formation-sampling/tread-before.gd" if path.is_empty() else path)
 var checked:=0;var steepened:=0;var worst:=0.0
 for height:float in [8,32]:
  var form:Dictionary=source.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
  for section:Array in form.tread_sections:
   var a:Vector3=section[0];var b:Vector3=section[1]
   if b.z-a.z<.15 or float(section[2])<.01:continue
   checked+=1
   var grade:float=(a.y-b.y)/(b.z-a.z)
   var excess:float=grade-float(section[2]);worst=maxf(worst,excess)
   if excess>.02:steepened+=1
 print("TREAD_GRADES checked=",checked," steepened=",steepened," max_excess=",worst)
 assert_gt(checked,50)
 assert_eq(steepened,0,"A body deformation must not turn an intended shallow tread into a steep channel")
