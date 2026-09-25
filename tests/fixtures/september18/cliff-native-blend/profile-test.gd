extends GutTest

func test_upper_silhouette_does_not_spend_the_root_projection_near_the_crown()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var worst:=0.0;var sampled:=0
 for height:float in [8.0,16.0,32.0,64.0]:
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
  var form:Dictionary=source.make(pose,48,height,2697992464)[0]
  var feet:Dictionary={}
  for p:Vector3 in form.faces:
   if p.y<=.01 and p.z>0:feet[p.x]=maxf(feet.get(p.x,0.0),p.z)
  for p:Vector3 in form.faces:
   var drop:=height-p.y
   if drop<=1.0 or drop>height*.45 or p.z<0 or not feet.has(p.x):continue
   # Measure the outer silhouette against the measured 1 m native crest,
   # not its inset mortar valleys. Allow 0.4 m for the larger shallow stone
   # sections, then require the remaining projection to grow with descent.
   # This rejects the old abrupt collar without stamping native tile valleys
   # back into every section of the independent stone surface.
   var limit:float=1.4+maxf(0.0,feet[p.x]-1.0)*(drop-1.0)/(height-1.0)
   worst=maxf(worst,p.z-limit);sampled+=1
 print("UPPER_SILHOUETTE samples=",sampled," envelope_excess=",worst)
 assert_gt(sampled,1000)
 assert_lt(worst,.08,"The large projection must develop toward the foot, not just below the turf lip")
