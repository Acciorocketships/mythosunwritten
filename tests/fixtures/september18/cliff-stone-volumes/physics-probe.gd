extends SceneTree
const GENERATOR=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const BEFORE=preload("res://tests/fixtures/september18/cliff-stone-volumes/before.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var stage:=Node3D.new();root.add_child(stage)
 var probes:Array=[];var bodies:Array=[]
 for height:float in [8,32]:
  var form:Dictionary=GENERATOR.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
  var old:Dictionary=BEFORE.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
  var body:=StaticBody3D.new();stage.add_child(body);body.position=Vector3(height*10,0,0)
  var shape:=CollisionShape3D.new();var solid:=ConcavePolygonShape3D.new();solid.set_faces(form.faces);shape.shape=solid;body.add_child(shape)
  bodies.append(body)
  var green:PackedVector3Array=form.green
  var stride:=maxi(1,green.size()/3/160)
  for i in range(0,green.size(),3*stride):
   var cross:Vector3=(green[i+2]-green[i]).cross(green[i+1]-green[i])
   if cross.length()<.001:continue
   probes.append([body,body.position+(green[i]+green[i+1]+green[i+2])/3.0,Vector3.UP,false])
  var stone:PackedVector3Array=form.faces
  var stone_stride:=maxi(1,stone.size()/3/600)
  for i in range(0,stone.size(),3*stone_stride):
   var n:Vector3=(stone[i+2]-stone[i]).cross(stone[i+1]-stone[i]).normalized()
   if n.z<.2 or minf(stone[i].z,minf(stone[i+1].z,stone[i+2].z))<0:continue
   var previous:PackedVector3Array=old.faces
   var moved:bool=stone[i].distance_to(previous[i])>.0001 or stone[i+1].distance_to(previous[i+1])>.0001 or stone[i+2].distance_to(previous[i+2])>.0001
   probes.append([body,body.position+(stone[i]+stone[i+1]+stone[i+2])/3.0,n,moved])
 await physics_frame
 await physics_frame
 var space:=stage.get_world_3d().direct_space_state
 var missing:=0;var worst:=0.0;var errors:Array=[]
 var changed:=0;var changed_missing:=0
 for probe:Array in probes:
  var p:Vector3=probe[1]
  if probe[3]:changed+=1
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+probe[2]*.015,p-probe[2]*.025,1))
  if hit.is_empty():
   missing+=1;errors.append(str(p))
   if probe[3]:changed_missing+=1
   continue
  worst=maxf(worst,hit.position.distance_to(p))
  if hit.collider!=probe[0]:missing+=1
 var report:Dictionary={"samples":probes.size(),"changed_samples":changed,"changed_missing":changed_missing,"missing_or_wrong_body":missing,"max_contact_error":worst,"missing":errors}
 FileAccess.open("res://docs/qa/2026-09-18-manual/82-cliff-stone-volumes/physical-changes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PHYSICAL_TREADS ",JSON.stringify(report))
 quit(1 if changed<1 or changed_missing>0 or worst>.002 else 0)
