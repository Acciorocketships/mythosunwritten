extends RefCounted
const CAPS=preload("res://scripts/terrain/field/CliffRockEndCaps.gd")
static func apply(forms:Array)->Dictionary:
 var changed:=0;var moved:=0
 for form:Dictionary in forms:
  var recipe:Dictionary=form.get("replay_recipe",{})
  if recipe.get("kind","")!="wall":continue
  var controls:Array=[]
  for corner:Vector3 in recipe.get("inner_connections",[]):
   for other:Dictionary in forms:
    var target:Dictionary=other.get("replay_recipe",{})
    if target.get("kind","")!="wall" or target.height>=recipe.height or not corner in target.get("inner_connections",[]):continue
    var local:Transform3D=form.transform.affine_inverse()*other.transform
    if absf(local.origin.y)>.001:continue
    var x:float=(form.transform.affine_inverse()*corner).x
    controls.append([x,float(target.height)])
  if controls.is_empty():continue
  var mapping:Dictionary={}
  for p:Vector3 in form.faces:
   if mapping.has(p):continue
   var q:=p
   for control:Array in controls:
    var distance:float=signf(control[0])*(control[0]-p.x)
    var w:float=(1.0-smoothstep(-.5,6.0,distance))*smoothstep(control[1]-.8,control[1]+1.2,p.y)
    if p.z>-.5:q.z=lerpf(q.z,-.5,w)
   if q!=p:moved+=1
   mapping[p]=q.snapped(Vector3.ONE*.0001)
  for channel:String in ["faces","green"]:
   var values:PackedVector3Array=form[channel]
   for i in values.size():values[i]=mapping[values[i]]
   form[channel]=values
  CAPS.rebuild(form)
  var box:=AABB(form.faces[0],Vector3.ZERO)
  for p:Vector3 in form.faces:box=box.expand(p)
  form.bounds=form.transform*box;form.base=form.bounds.position.y;form.top=form.bounds.end.y
  changed+=1
 return {"changed":changed,"moved":moved}
