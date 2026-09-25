extends SceneTree
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var stage:=Node3D.new();root.add_child(stage)
 var probes:Array=[];var index:=0
 for inner:bool in [false,true]:
  for height:float in [4,8,32,64]:
   for rotation in 4:
    var pose:=Transform3D(Basis(Vector3.UP,rotation*PI*.5),Vector3(index*40,0,0));index+=1
    var seed_value:=17 if rotation%2==0 else 2697992464
    var form:Dictionary=CORNER.make_inner(pose,height,seed_value) if inner else CORNER.make(pose,height,seed_value)
    var body:=StaticBody3D.new();stage.add_child(body);body.transform=pose
    var shape:=CollisionShape3D.new();var solid:=ConcavePolygonShape3D.new();solid.set_faces(form.faces);shape.shape=solid;body.add_child(shape)
    var faces:PackedVector3Array=form.faces
    var stride:=maxi(1,faces.size()/3/140)
    for i in range(0,faces.size(),3*stride):
     var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
     var cross:Vector3=(c-a).cross(b-a)
     if cross.length()<.001:continue
     var point:Vector3=(a+b+c)/3
     if point.y<.1 or point.y>height-.1:continue
     var n:=cross.normalized()
     probes.append([body,pose*point,pose.basis*n,inner,height,rotation])
 await physics_frame
 await physics_frame
 var space:=stage.get_world_3d().direct_space_state
 var missing:=0;var worst:=0.0;var errors:Array=[]
 for probe:Array in probes:
  var point:Vector3=probe[1];var normal:Vector3=probe[2]
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.008,point-normal*.012,1))
  if hit.is_empty() or hit.collider!=probe[0]:
   missing+=1;errors.append({"point":str(point),"inner":probe[3],"height":probe[4],"rotation":probe[5]});continue
  worst=maxf(worst,hit.position.distance_to(point))
 var report:Dictionary={"samples":probes.size(),"forms":index,"missing":missing,"max_error":worst,"errors":errors}
 FileAccess.open("res://docs/qa/2026-09-18-manual/88-cliff-corner-continuity/physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CORNER_PHYSICS ",JSON.stringify(report))
 quit(1 if missing>0 or worst>.003 else 0)
