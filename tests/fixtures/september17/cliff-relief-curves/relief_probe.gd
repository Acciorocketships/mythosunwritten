extends GutTest
func test_exposed_attachment_relief_does_not_repeat_every_native_storey()->void:
 var path:=OS.get_environment("STORY_RELIEF_GENERATOR")
 var generator:GDScript=load("res://tests/fixtures/september17/cliff-relief-curves/candidate.gd" if path.is_empty() else path)
 generator.prepare()
 var error:=0.0;var samples:=0;var root_error:=0.0
 var before:GDScript=load("res://tests/fixtures/september17/cliff-relief-curves/before.gd")
 before.prepare()
 # The photographed Amber cliff's along-wall phase, over two native storeys.
 for ix in 80:
  for iy in 16:
   var u:float=-445.5+ix*.2;var y:float=.4+iy*.2
   var a:float=generator._attach(1.8,u,y,1.0)
   var b:float=generator._attach(1.8,u,y+4.0,1.0)
   error+=(a-b)*(a-b);samples+=1
   root_error=maxf(root_error,absf(generator._attach(.6,u,y,1.0)-before._attach(.6,u,y,1.0)))
 var rms:=sqrt(error/samples)
 print("RELIEF_CURVATURE repeated_course_rms=",rms," thin_root_change=",root_error)
 assert_gt(rms,.02,"Outer attachment relief must break the exact four-metre native repeat")
 assert_lt(root_error,.00001,"Thin physical wall contact remains native")
