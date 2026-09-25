extends GutTest
func test_upper_body_opens_gradually_toward_its_root()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var worst:=0.0;var sampled:=0
 for height:float in [8.0,16.0,32.0,64.0]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var form:Dictionary=source.make(pose,48,height,2697992464)[0]
  var feet:Dictionary={}
  for p:Vector3 in form.faces:
   if p.y<=0.01 and p.z>0:feet[p.x]=maxf(feet.get(p.x,0.0),p.z)
  for p:Vector3 in form.faces:
   var drop:=height-p.y
   if drop<=1.0 or drop>height*.45 or p.z<0 or not feet.has(p.x):continue
   var extra:float=p.z-source._native_depth(pose.origin.x+p.x,p.y)
   # By the upper quarter, only a quarter of the total rooted projection
   # should have emerged. A short fixed-height collar creates a false shelf.
   var limit:float=.12+(feet[p.x]+.5)*clampf((drop-1.0)/(height-1.0),0.0,1.0)
   worst=maxf(worst,extra-limit);sampled+=1
 print("CROWN_GRADIENT samples=",sampled," envelope_excess=",worst)
 assert_gt(sampled,1000)
 assert_lt(worst,.08,"Spread the projection down the wall instead of restoring it at one short collar")
