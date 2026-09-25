extends GutTest
func test_photographed_upper_metre_stays_close_to_native_wall()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
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

func test_convex_upper_join_follows_its_actual_native_corner()->void:
 var path:=OS.get_environment("STORY_BUTTRESS_CORNER")
 var source:GDScript=load("res://scripts/terrain/field/CliffCornerCrags.gd" if path.is_empty() else path)
 var rows:Array=FileAccess.open("res://tests/fixtures/september17/cliff-corners/photographed-rows.bin",FileAccess.READ).get_var()
 var worst:=0.0;var sampled:=0
 for form:Dictionary in source.formations(rows,2697992464):
  var height:float=form.top-form.anchor.y
  for p:Vector3 in form.faces:
   if p.y<height-1.0 or p.y>height or p.x< -1.499 or p.z< -1.499:continue
   var offset:=Vector2(p.x+1.5,p.z+1.5)
   var angle:=atan2(offset.x,offset.y)
   var u:=angle/(PI*.5)*3.0-1.5
   var native:Array=source._native(u,p.y,form.transform)
   worst=maxf(worst,offset.length()-1.5-float(native[0]));sampled+=1
 print("CORNER_UPPER_JOIN samples=",sampled," excess=",worst)
 assert_gt(sampled,100)
 assert_lt(worst,.35,"The full upper metre must stay flush around convex corners too")

func test_crown_repair_preserves_geometry_below_the_join()->void:
 # This pins the isolated collar repair. Later full-height profile changes
 # intentionally alter the lower body and have separate support/profile gates.
 var current:GDScript=load("res://tests/fixtures/september18/cliff-crown-collar/candidate.gd")
 var before:GDScript=load("res://tests/fixtures/september18/cliff-crown-collar/before.gd")
 var checked:=0
 for height:float in [4.0,8.0,16.0,32.0]:
  var pose:=Transform3D(Basis(Vector3.UP,PI*.5),Vector3(-433.5,32,-301.5))
  var a:Dictionary=before.make(pose,9.0,height,2697992464)[0]
  var b:Dictionary=current.make(pose,9.0,height,2697992464)[0]
  var boundary:=height-minf(4.0,maxf(2.5,height*.32))-.001
  var old_points:Dictionary={};var new_points:Dictionary={}
  for p:Vector3 in a.faces:
   if p.y<=boundary:old_points[p]=true
  for p:Vector3 in b.faces:
   if p.y<=boundary:new_points[p]=true
  assert_eq(new_points.size(),old_points.size(),"Do not add or remove lower rock vertices")
  for p:Vector3 in old_points:
   if not new_points.has(p):fail_test("Lower support moved at height %s point %s"%[height,p]);return
  checked+=old_points.size()
 print("UNCHANGED_LOWER_VERTICES ",checked)
 assert_gt(checked,100)
