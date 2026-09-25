extends SceneTree
const GENERATOR=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var stage:=Node3D.new();root.add_child(stage)
 var probes:Array=[];var bodies:Array=[]
 for height:float in [8,32]:
  var form:Dictionary=GENERATOR.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
  var body:=StaticBody3D.new();stage.add_child(body);body.position=Vector3(height*10,0,0)
  var shape:=CollisionShape3D.new();var solid:=ConcavePolygonShape3D.new();solid.set_faces(form.faces);shape.shape=solid;body.add_child(shape)
  bodies.append(body)
  var green:PackedVector3Array=form.green
  var stride:=maxi(1,green.size()/3/160)
  for i in range(0,green.size(),3*stride):
   var cross:Vector3=(green[i+2]-green[i]).cross(green[i+1]-green[i])
   if cross.length()<.001:continue
   probes.append([body,body.position+(green[i]+green[i+1]+green[i+2])/3.0])
 await physics_frame
 await physics_frame
 var space:=stage.get_world_3d().direct_space_state
 var missing:=0;var worst:=0.0;var errors:Array=[]
 for probe:Array in probes:
  var p:Vector3=probe[1]
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.015,p-Vector3.UP*.025,1))
  if hit.is_empty():missing+=1;errors.append(str(p));continue
  worst=maxf(worst,hit.position.distance_to(p))
  if hit.collider!=probe[0]:missing+=1
 var report:Dictionary={"samples":probes.size(),"missing_or_wrong_body":missing,"max_contact_error":worst,"missing":errors}
 FileAccess.open("res://docs/qa/2026-09-18-manual/76-cliff-connected-relief/physical-treads.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PHYSICAL_TREADS ",JSON.stringify(report))
 quit(1 if probes.size()<200 or missing>0 or worst>.002 else 0)
