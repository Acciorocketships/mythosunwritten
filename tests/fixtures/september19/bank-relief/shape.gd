extends RefCounted
## The same detached deformation for solid vertices and barycentric attachments.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNERS=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
static func point(p:Vector3,rock:Dictionary)->Array:
 var recipe:Dictionary=rock.replay_recipe
 var pose:Transform3D=rock.transform
 var q:=p;var u:=p.x;var depth:=p.z
 var direction:=Vector3.BACK;var native:Array=[]
 if recipe.kind=="corner":
  if p.x<=-1.5:
   u=p.x;depth=p.z
  elif p.z<=-1.5:
   u=-p.z;depth=p.x;direction=Vector3.RIGHT
  else:
   var angle:=atan2(p.x+1.5,p.z+1.5)
   u=angle/(PI*.5)*3.0-1.5
   depth=Vector2(p.x+1.5,p.z+1.5).length()-1.5
   direction=Vector3(sin(angle),0,cos(angle))
  native=CORNERS._native(u,p.y,pose)
 elif recipe.kind=="inner_corner":
  u=p.x-p.z;depth=minf(p.x,p.z)
  native=CORNERS._inner_native(u,p.y,pose)
 if recipe.kind=="wall":native=[CRAGS._native_depth(pose.origin.dot(pose.basis.x)+u,p.y),CRAGS._native_normal(pose.origin.dot(pose.basis.x)+u,p.y)]
 # Borrow native relief only at thin attachments. Making the entire bank
 # relative to native depth reproduced its regular columns underwater.
 var backing:=lerpf(float(native[0]),.6,smoothstep(.75,1.4,depth))
 var exposure:=maxf(0,depth-backing)
 var scaled:=exposure*.3
 if scaled>2.0:scaled=2.0+.4*(1.0-exp(-(scaled-2.0)/.4))
 var front:=depth if exposure<=0 else backing+scaled
 # Compression must not bury a source face that already clears the native
 # wall. Keep a thin attached skin only at those contacts; the independent
 # outer mass takes over once it stands clear of the native relief.
 var source_clearance:=depth-float(native[0])
 if source_clearance>0.0:
  var contact:=float(native[0])+.18*(1.0-exp(-source_clearance/.18))
  var blend:=maxf(0.0,1.0-absf(front-contact)/.12)
  front=minf(depth,maxf(front,contact)+.03*blend*blend)
 if recipe.kind=="wall":q.z=front
 elif recipe.kind=="inner_corner":q=Vector3(maxf(u,0)+front,p.y,maxf(-u,0)+front)
 elif u<=-1.5:q=Vector3(u,p.y,front)
 elif u>=1.5:q=Vector3(front,p.y,-u)
 else:q=Vector3(-1.5,p.y,-1.5)+direction*(1.5+front)
 return [q,native[1],smoothstep(.015,.18,front-float(native[0]))]
