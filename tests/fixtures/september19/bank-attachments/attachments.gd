extends RefCounted
## Keep canonical dry proposals/ranks; only accepted wet owners move their roots.
## Compete against both possible poses without reading halo water. Unpublished
## alternatives remain conservative reservations, so ownership cannot change
## the winner when adjacent chunks prepare different hydraulic windows.
const SHAPE=preload("res://tests/fixtures/september19/bank-attachments/shape.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
static func map_attachment(plant:Dictionary,source:Dictionary)->Dictionary:
 if source.get("replay_recipe",{}).get("kind","") not in ["wall","corner","inner_corner"]:return {}
 var pose:Transform3D=source.transform
 var local:Vector3=pose.affine_inverse()*plant.support_point
 var faces:PackedVector3Array=source.faces
 var best:=INF;var picked:Dictionary={}
 for i in range(0,faces.size(),3):
  var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
  var u:=b-a;var v:=c-a;var w:=local-a
  var uu:=u.dot(u);var uv:=u.dot(v);var vv:=v.dot(v)
  var denominator:=uu*vv-uv*uv
  if absf(denominator)<1e-12:continue
  var wb:=(vv*w.dot(u)-uv*w.dot(v))/denominator
  var wc:=(uu*w.dot(v)-uv*w.dot(u))/denominator
  var wa:=1.0-wb-wc
  # Crevice candidates round shared source edges to one millimetre.
  if minf(wa,minf(wb,wc))<-.02:continue
  var weights:=Vector3(maxf(wa,0),maxf(wb,0),maxf(wc,0))
  weights/=weights.x+weights.y+weights.z
  var point:=a*weights.x+b*weights.y+c*weights.z
  var distance:=point.distance_to(local)
  if distance>.003:continue
  var normal:Vector3=(c-a).cross(b-a).normalized()
  var world_normal:Vector3=(pose.basis.inverse().transposed()*normal).normalized()
  var score:=distance+maxf(0,1-world_normal.dot(plant.support_normal))*.0000001
  if score>=best:continue
  best=score;picked={"a":a,"b":b,"c":c,"weights":weights,"normal":world_normal}
 if picked.is_empty():return {}
 var a:Vector3=pose*SHAPE.point(picked.a,source)[0]
 var b:Vector3=pose*SHAPE.point(picked.b,source)[0]
 var c:Vector3=pose*SHAPE.point(picked.c,source)[0]
 var normal:Vector3=(c-a).cross(b-a).normalized()
 if normal.is_zero_approx():return {}
 var rotation:=Basis(Quaternion(picked.normal,normal))
 var weights:Vector3=picked.weights
 var point:=a*weights.x+b*weights.y+c*weights.z
 var result:=plant.duplicate(true)
 result.support_point=point
 result.support_normal=(rotation*plant.support_normal).normalized()
 result.transform=Transform3D(rotation*plant.transform.basis,point+rotation*(plant.transform.origin-plant.support_point))
 result.bounds=result.transform*ROCKS._definitions[plant.asset].bounds
 return result

static func publish(proposals:Array,sources:Array,banks:Array,region:HeightfieldRegion=null,
 features:FeatureContext=null,water:WaterFieldContext=null)->Array[Dictionary]:
 var originals:Dictionary={};var owned:Dictionary={};var alternatives:Dictionary={}
 for source:Dictionary in sources:originals[source.id]=source
 for bank:Dictionary in banks:owned[bank.id]=bank
 for plant:Dictionary in proposals:
  var moved:=map_attachment(plant,originals[plant.support_id])
  if not moved.is_empty():alternatives[plant.id]=moved
 var result:Array[Dictionary]=[]
 for original:Dictionary in proposals:
  if not owned.has(original.support_id) or not alternatives.has(original.id):continue
  var plant:Dictionary=alternatives[original.id]
  var bank:Dictionary=owned[plant.support_id]
  var point:Vector3=plant.support_point;var normal:Vector3=plant.support_normal
  if point.y<float(bank.replay_recipe.shore_level)+.3 or normal.y<-.5:continue
  if water!=null and water.has_sources():
   var xz:=Vector2(point.x,point.z)
   assert(water.covers(xz),"Only the admitted owner's water window may be queried")
   var level:=water.level_at(xz)
   if is_finite(level) and level>point.y-.3:continue
  var exposed:=point if plant.attachment=="ledge" else point+Vector3(normal.x,0,normal.z).normalized()*1.6
  if region!=null and TerrainSurfaceField.surface_y(region,exposed.x,exposed.z)>point.y-.3:continue
  if features!=null and features.overlaps_clearance(FeatureGroundShape.axis_rect(ROCKS._footprint(plant.bounds)),.3):continue
  var clear:=true
  for other:Dictionary in sources:
   if other.id==plant.support_id or not (other.bounds as AABB).grow(.01).has_point(point):continue
   if ROCKS._covered(other,point+normal*.1):clear=false;break
  if not clear:continue
  for other:Dictionary in proposals:
   if other.id==plant.id:continue
   # The same owner is known to use its bank pose. Other owners may publish
   # either pose, depending on their own complete hydraulic admission.
   if other.support_id!=plant.support_id and ROCKS._canopies_crowd(plant.bounds,other.bounds):clear=false;break
   if alternatives.has(other.id) and ROCKS._canopies_crowd(plant.bounds,alternatives[other.id].bounds):clear=false;break
  if clear:result.append(plant)
 return result
