extends GutTest
func test_upper_cover_does_not_expand_at_a_fixed_short_collar()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var maximum:=0.0
 var count:=0
 var at:=Vector3.ZERO;var native_at:=0.0;var height_at:=0.0
 for height:float in [16.0,32.0,64.0]:
  var form:Dictionary=source.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
  var feet:Dictionary={}
  for p:Vector3 in form.faces:
   if p.y<=.01 and p.z>0:feet[p.x]=maxf(feet.get(p.x,0.0),p.z)
  for p:Vector3 in form.faces:
   var drop:=height-p.y
   if drop<1.05 or drop>height*.25 or p.z<0 or not feet.has(p.x):continue
   var t:=clampf((drop-1.05)/(height-1.05),0.0,1.0)
   # Native outer silhouette is 1 m. Allow 0.12 m of shallow relief;
   # additional projection should grow with the whole wall's descent.
   var limit:float=1.12+maxf(0.0,feet[p.x]-1.0)*t
   if p.z-limit>maximum:
    at=p;native_at=source._native_depth(-13.5+p.x,p.y);height_at=height
   maximum=maxf(maximum,p.z-limit);count+=1
 print("UPPER_COLLAR samples=",count," excess=",maximum," local=",at," native=",native_at," height=",height_at)
 assert_gt(count,1000)
 assert_lt(maximum,.08,"The upper covering layer must not form a short fixed-height shelf")
