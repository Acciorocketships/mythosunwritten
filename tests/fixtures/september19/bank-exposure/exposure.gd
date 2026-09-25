extends RefCounted
const SHAPE=preload("res://tests/fixtures/september19/bank-preserved-relief/shape.gd")
const TRACE=preload("res://tests/fixtures/september19/bank-exposure/trace.gd")
## Unknown neighboring water ownership cannot change exposure: reserve both
## canonical dry and potentially fitted surfaces. No halo water reads are needed.
static func filter(plants:Array,sources:Array,banks:Array)->Array:
 var owners:Dictionary={};var fitted:Dictionary={};var result:Array=[]
 for bank:Dictionary in banks:owners[bank.id]=bank
 for plant:Dictionary in plants:
  if not owners.has(plant.support_id):continue
  var candidates:Array=[owners[plant.support_id]]
  for source:Dictionary in sources:
   if source.id==plant.support_id or not (source.bounds as AABB).grow(.401).has_point(plant.support_point):continue
   candidates.append(source)
   if source.replay_recipe.kind not in ["wall","corner","inner_corner"]:continue
   if not fitted.has(source.id):fitted[source.id]=_mapped(source)
   candidates.append(fitted[source.id])
  var contact:=TRACE.first_contact(plant,candidates)
  if not contact.is_empty() and contact.id==plant.support_id and contact.root_gap<=.005:result.append(plant)
 return result

static func _mapped(source:Dictionary)->Dictionary:
 var unique:Dictionary={};var faces:=PackedVector3Array()
 for p:Vector3 in source.faces:
  if not unique.has(p):unique[p]=SHAPE.point(p,source)[0]
  faces.append(unique[p])
 var box:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:box=box.expand(p)
 return {"id":source.id,"faces":faces,"transform":source.transform,"bounds":source.transform*box}
