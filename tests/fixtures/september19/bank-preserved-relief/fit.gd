extends RefCounted
## Study: exposed bank formations anchored inside the unchanged native wall.
const SHAPE=preload("res://tests/fixtures/september19/bank-preserved-relief/shape.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNERS=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
static var last_rejections:Array=[]
static func fit(rock:Dictionary,region:HeightfieldRegion,water:WaterFieldContext)->Dictionary:
 last_rejections=[]
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
  var mapped:=SHAPE.point(p,rock)
  mapping[p]=mapped[0]
  roots[mapped[0]]=[mapped[1],mapped[2]]
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
    var ground:=TerrainSurfaceField.surface_y(region,clear.x,clear.y)
    if not is_finite(receiver) or absf(receiver-level)>.25 or receiver-ground<.75:
     intrusions+=1
     if last_rejections.size()<16:last_rejections.append({"point":p,"clear":clear,"level":level,"receiver":receiver,"ground":ground})
 if intrusions>0:
  print("SHORE_REJECT ",rock.anchor," ",recipe.kind," clearance=",intrusions)
  return {}
 return result
