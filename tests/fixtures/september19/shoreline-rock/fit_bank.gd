extends RefCounted
## Study: exposed bank formations anchored inside the unchanged native wall.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNERS=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
static func fit(rock:Dictionary,region:HeightfieldRegion,water:WaterFieldContext)->Dictionary:
 if water==null or not water.has_sources():return rock
 var recipe:Dictionary=rock.get("replay_recipe",{})
 if recipe.get("kind","") not in ["wall","corner","inner_corner"]:return {}
 var pose:Transform3D=rock.transform
 var levels:Dictionary={};var highest:=-INF;var dry_crown:=false
 for p:Vector3 in rock.faces:
  var world:Vector3=pose*p;var point:=Vector2(world.x,world.z)
  if not levels.has(point):levels[point]=water.level_at(point)
  var level:float=levels[point]
  if is_finite(level):highest=maxf(highest,level)
  elif world.y>float(rock.top)-.15:dry_crown=true
 if not is_finite(highest):return rock
 if not dry_crown or highest>float(rock.top)-.65:return {}
 # Retain the whole rooted formation. Broad channels can admit a shallow
 # attached bank; an above-water-only retreat leaves the visible submerged
 # native facade bare. Bound the independent bank face to three metres from its native plane.
 var bottom:=pose.origin.y
 var result:Dictionary=rock.duplicate(true)
 var rise:=.3
 var mapping:Dictionary={};var roots:Dictionary={}
 for p:Vector3 in result.faces:
  if mapping.has(p):continue
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
  if recipe.kind=="wall":q.z=front
  elif recipe.kind=="inner_corner":q=Vector3(maxf(u,0)+front,p.y,maxf(-u,0)+front)
  elif u<=-1.5:q=Vector3(u,p.y,front)
  elif u>=1.5:q=Vector3(front,p.y,-u)
  else:q=Vector3(-1.5,p.y,-1.5)+direction*(1.5+front)
  mapping[p]=q
  if not native.is_empty():roots[q]=[native[1],smoothstep(.015,.18,front-float(native[0]))]
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for p:Vector3 in result.faces:faces.append(mapping[p])
 for i in range(0,result.green.size(),3):
  var a:Vector3=mapping[result.green[i]];var b:Vector3=mapping[result.green[i+1]];var c:Vector3=mapping[result.green[i+2]]
  if minf(a.y,minf(b.y,c.y))+bottom<highest+rise:continue
  green.append_array(PackedVector3Array([a,b,c]))
 result["shore_source_faces"]=rock.faces
 result.faces=faces;result.green=green
 if not roots.is_empty():result.native_roots=roots
 var box:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:box=box.expand(p)
 result.bounds=pose*box;result.top=result.bounds.end.y;result.base=result.bounds.position.y
 result.id=rock.id;result.anchor=rock.anchor
 result.replay_recipe["shore_level"]=highest
 result.replay_recipe["shore_rise"]=rise
 # Confirm a deep wet passage remains outside each projecting bank sample.
 # Steep falls, unsupported isolated masses and narrow channels are ineligible.
 # Each read stays inside the already prepared water domain.
 var intrusions:=0;var checked:Dictionary={}
 for i in range(0,faces.size(),3):
  var a:Vector3=pose*faces[i];var b:Vector3=pose*faces[i+1];var c:Vector3=pose*faces[i+2]
  for p:Vector3 in [a,b,c,(a+b+c)/3,(a+b)*.5,(b+c)*.5,(c+a)*.5]:
   if checked.has(p):continue
   checked[p]=true
   var point:=Vector2(p.x,p.z)
   if not water.covers(point):return {}
   var level:=water.level_at(point)
   if not is_finite(level) or p.y>level+.1 or p.y<=TerrainSurfaceField.surface_y(region,p.x,p.z)+.01:continue
   var local:Vector3=pose.affine_inverse()*p
   var direction:=Vector3.BACK
   if recipe.kind=="corner":
    if local.x>=-1.5 and local.z>=-1.5:direction=Vector3(local.x+1.5,0,local.z+1.5).normalized()
    elif local.z<=-1.5:direction=Vector3.RIGHT
   elif recipe.kind=="inner_corner":direction=Vector3.RIGHT if local.z>local.x else Vector3.BACK
   direction=pose.basis*direction
   for d:float in [1.5,3.0]:
    var clear:=point+Vector2(direction.x,direction.z)*d
    if not water.covers(clear):return {}
    var receiver:=water.level_at(clear)
    if not is_finite(receiver) or absf(receiver-level)>.25 or receiver-TerrainSurfaceField.surface_y(region,clear.x,clear.y)<.75:intrusions+=1
 if intrusions>0:
  print("SHORE_REJECT ",rock.anchor," ",recipe.kind," clearance=",intrusions)
  return {}
 return result
