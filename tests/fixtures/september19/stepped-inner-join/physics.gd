extends SceneTree
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const OUT="res://docs/qa/2026-09-19-manual/94-stepped-inner-join/"
func _init()->void:call_deferred("run")
func run()->void:
 ROCKS.prepare()
 var world:Node3D=load("res://docs/qa/2026-09-19-manual/93-fresh-corner-review/final-P12/world.scn").instantiate();root.add_child(world)
 for shape:CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
  if shape.name==&"CliffRocks":shape.disabled=true
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin",FileAccess.READ).get_var()
 var original:Dictionary={}
 for f:Dictionary in forms:original[f.id]=f.faces
 var result:=JOIN.apply(forms)
 var probes:Array=[];var feet:Array=[];var bodies:Array[RID]=[]
 for form:Dictionary in forms:
  if original[form.id]==form.faces:continue
  var pose:Transform3D=form.transform
  var body:=StaticBody3D.new();body.collision_layer=2;world.add_child(body);body.global_transform=pose;body.set_meta("form_id",form.id);bodies.append(body.get_rid())
  var shape:=CollisionShape3D.new();var solid:=ConcavePolygonShape3D.new();solid.set_faces(form.faces);shape.shape=solid;body.add_child(shape)
  var stride:=maxi(1,form.faces.size()/3/240)
  for i in range(0,form.faces.size(),3*stride):
   var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
   var cross:Vector3=(c-a).cross(b-a)
   if cross.length()<.001:continue
   var p:Vector3=(a+b+c)/3
   if p.y<.1 or p.y>float(form.replay_recipe.height)-.1:continue
   probes.append([body,pose*p,pose.basis*cross.normalized()])
  var unique:Dictionary={};var minimum:=INF
  for p:Vector3 in form.faces:minimum=minf(minimum,p.y)
  for p:Vector3 in form.faces:
   if absf(p.y-minimum)<.001:unique[p]=true
  for p:Vector3 in unique:feet.append(pose*p)
 await physics_frame
 await physics_frame
 var space:=world.get_world_3d().direct_space_state
 var misses:Array=[]
 var missing:=0;var error:=0.0;var exposed:=0;var missing_ground:=0
 for probe:Array in probes:
  var p:Vector3=probe[1];var n:Vector3=probe[2]
  var excluded:Array[RID]=bodies.duplicate();excluded.erase(probe[0].get_rid())
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+n*.008,p-n*.012,2,excluded))
  if hit.is_empty() or hit.collider!=probe[0]:
   missing+=1
   misses.append({"point":str(p),"normal":str(n),"expected":probe[0].get_meta("form_id"),"hit":str(hit.position) if not hit.is_empty() else "none","actual":hit.collider.get_meta("form_id", "other") if not hit.is_empty() else "none"})
  else:error=maxf(error,p.distance_to(hit.position))
 for p:Vector3 in feet:
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*64,p-Vector3.UP*128,1))
  if hit.is_empty():missing_ground+=1
  elif p.y>hit.position.y-.05:exposed+=1
 var report:={"misses":misses,"connections":result.connections,"changed_walls":result.changed_walls,"collision_samples":probes.size(),"collision_misses":missing,"max_error":error,"native_ground_samples":feet.size(),"missing_ground":missing_ground,"exposed_roots":exposed}
 FileAccess.open(OUT+"physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("JOIN_PHYSICS ",JSON.stringify(report))
 quit(0 if missing==0 and error<.003 and missing_ground==0 and exposed==0 else 1)
