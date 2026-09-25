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
 # Use complete native courses so phase, attachment normals and crown agree
 # with the real wall. Only the visible bank owns new independent relief.
 var bottom:=maxf(pose.origin.y,floorf(highest/4.0)*4.0)
 var height:float=pose.origin.y+float(recipe.height)-bottom
 if height<=0:return {}
 pose.origin.y=bottom
 var result:Dictionary
 match recipe.kind:
  "wall":result=CRAGS.make(pose,recipe.width,height,recipe.seed,null,recipe.left_end,recipe.right_end)[0]
  "corner":result=CORNERS.make(pose,height,recipe.seed)
  "inner_corner":result=CORNERS.make_inner(pose,height,recipe.seed)
 # Retreat into the backing before reaching water. Keep finite thickness in
 # the buried part; collapsing both sides would open the physical shell.
 var rise:=minf(2.0,maxf(.8,(float(rock.top)-highest)*.6))
 var mapping:Dictionary={};var roots:Dictionary={}
 for p:Vector3 in result.faces:
  if mapping.has(p):continue
  var weight:=lerpf(.04,1.0,smoothstep(highest+.3,highest+rise,p.y+bottom))
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
  var front:=lerpf(-1.2,depth,weight)
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
 result.faces=faces;result.green=green
 if not roots.is_empty():result.native_roots=roots
 var box:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:box=box.expand(p)
 result.bounds=pose*box;result.top=result.bounds.end.y;result.base=result.bounds.position.y
 result.id=rock.id;result.anchor=rock.anchor
 result.replay_recipe["shore_level"]=highest
 result.replay_recipe["shore_rise"]=rise
 # Validate against existing terrain, not a new hydraulic mask. A wet point
 # may be rock only where the unchanged cliff already occupies that volume.
 var intrusions:=0
 for i in range(0,faces.size(),3):
  var a:Vector3=pose*faces[i];var b:Vector3=pose*faces[i+1];var c:Vector3=pose*faces[i+2]
  for p:Vector3 in [a,b,c,(a+b+c)/3,(a+b)*.5,(b+c)*.5,(c+a)*.5]:
   var level:=water.level_at(Vector2(p.x,p.z))
   if is_finite(level) and p.y<level+.1 and p.y>TerrainSurfaceField.surface_y(region,p.x,p.z)+.01:intrusions+=1
 if intrusions>0:
  print("SHORE_REJECT ",rock.anchor," ",recipe.kind," wet_air=",intrusions)
  return {}
 return result
