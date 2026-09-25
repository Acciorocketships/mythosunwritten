extends SceneTree
const FOLDER="res://docs/qa/2026-09-19-manual/91-masonry-joints/payloads/"
func rows(data:Dictionary)->Dictionary:
 var out:Dictionary={}
 for asset:StringName in data.batches:
  var batch:Dictionary=data.batches[asset]
  for i in batch.ids.size():out[batch.ids[i]]=[asset,batch.transforms[i]]
 return out
func _init()->void:call_deferred("run")
func run()->void:
 var stage:=Node3D.new();root.add_child(stage)
 var cache:=EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
 var a:=rows(FileAccess.open(FOLDER+"before-payload.bin",FileAccess.READ).get_var())
 var b:=rows(FileAccess.open(FOLDER+"after-payload.bin",FileAccess.READ).get_var())
 var probes:Array=[];var index:=0
 for id:StringName in a:
  if a[id][0]==b[id][0]:continue
  for version in 2:
   var row:Array=a[id] if version==0 else b[id]
   var pose:Transform3D=row[1]
   var body:=StaticBody3D.new();stage.add_child(body)
   var key:=String(id).split("/")
   var center:=Vector3(float(key[1])*.75,float(key[2])*1.5,float(key[3])*.75)
   var shift:=Vector3(index*4,0,0)-center;index+=1
   body.transform=Transform3D(Basis.IDENTITY,shift)*pose
   for piece:EnvironmentCollisionPiece in cache.visual(row[0]).collisions:
    var shape:=CollisionShape3D.new();shape.shape=piece.shape;shape.transform=piece.local_transform;body.add_child(shape)
   for height:float in [.1,.4,.75,1.1,1.4]:
    for offset:float in [-.15,0,.15]:
     for direction:Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
      var lateral:=Vector3(-direction.z,0,direction.x)
      var point:=center+shift+Vector3.UP*height+lateral*offset
      probes.append([body,point+direction*.8,point-direction*.8,version,String(id),height,offset])
 await physics_frame
 await physics_frame
 var space:=stage.get_world_3d().direct_space_state
 var missing:Array=[];var counts:=[0,0]
 for probe:Array in probes:
  counts[probe[3]]+=1
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(probe[1],probe[2],1))
  if hit.is_empty() or hit.collider!=probe[0]:missing.append([probe[3],probe[4],probe[5],probe[6]])
 var report:={"joints":index/2,"probes_by_version":counts,"misses":missing}
 FileAccess.open(FOLDER+"physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("JOINT_PHYSICS ",JSON.stringify(report))
 quit(0 if missing.is_empty() else 1)
