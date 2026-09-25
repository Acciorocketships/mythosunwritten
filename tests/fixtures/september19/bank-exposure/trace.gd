extends RefCounted
static func first_contact(plant:Dictionary,forms:Array)->Dictionary:
 var point:Vector3=plant.support_point;var normal:Vector3=plant.support_normal
 var start:=point+normal*.2;var direction:=-normal
 var nearest:=.400001;var result:Dictionary={}
 for form:Dictionary in forms:
  if not (form.bounds as AABB).grow(.401).has_point(point):continue
  var inverse:Transform3D=form.transform.affine_inverse()
  var local:Vector3=inverse*start;var ray:Vector3=inverse.basis*direction
  var faces:PackedVector3Array=form.faces
  for i in range(0,faces.size(),3):
   var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
   if (c-a).cross(b-a).dot(ray)>=0:continue
   var hit=Geometry3D.ray_intersects_triangle(local,ray,a,b,c)
   if hit==null:continue
   var world:Vector3=form.transform*hit
   var distance:=start.distance_to(world)
   if distance>=nearest:continue
   nearest=distance;result={"id":form.id,"point":world,"distance":distance,"root_gap":world.distance_to(point)}
 return result
