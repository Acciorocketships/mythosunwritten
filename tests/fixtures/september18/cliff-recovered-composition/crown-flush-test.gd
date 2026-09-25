extends GutTest
func test_photographed_upper_metre_stays_close_to_native_wall()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var worst:=0.0;var sampled:=0;var location:Array=[]
 for a:Array in FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var():
  var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var phase:float=a[0].origin.dot(a[0].basis.x)
  for p:Vector3 in form.faces:
   if p.y<a[2]-1.0 or p.y>a[2] or p.z<0:continue
   var excess:float=p.z-source._native_depth(phase+p.x,p.y)
   if excess>worst:worst=excess;location=[a[0],a[2],p,phase]
   sampled+=1
 print("UPPER_JOIN samples=",sampled," maximum_added_projection=",worst," location=",location)
 assert_gt(sampled,100)
 assert_lt(worst,.35,"The whole upper metre must stay nearly flush, not merely its last row beneath the lip")
