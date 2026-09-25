extends "res://tests/harness/september15_reported_qa.gd"
## Real-world art study. Original wall, grass lip and terrain remain intact.
## Source loading is deliberately restricted to this offline review harness.
func _capture_views(world:Node3D)->void:
 if "--rocks" in OS.get_cmdline_user_args():
  var stock:Dictionary={}
  for variant:int in [1,2,4,7,10,11,12,13,14,15,16,17]:
   var doc:=GLTFDocument.new();var state:=GLTFState.new()
   assert(doc.append_from_file("res://assets/CliffMossRocks/moss_%d.glb"%variant,state)==OK)
   var source:=doc.generate_scene(state)
   stock[variant]=(source.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D).mesh
   source.free()
  var terraces=preload("res://scripts/terrain/field/CliffTerraces.gd");terraces.prepare()
  var wall:Mesh=CliffDressing._pieces.wall[0]
  var plants:=preload("res://tests/harness/september15_mountain_study.gd").new()
  plants._stage=world;plants._rng.seed=2697992464
  var batches:Dictionary={};var count:=0
  for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
   var mesh:Mesh=node.multimesh.mesh
   for asset:StringName in terraces._pieces:
    var native:Mesh=terraces._pieces[asset][0]
    if mesh.get_aabb().is_equal_approx(native.get_aabb()) and mesh.get_faces().size()==native.get_faces().size():node.visible=false
   if not mesh.get_aabb().is_equal_approx(wall.get_aabb()) or mesh.get_faces().size()!=wall.get_faces().size():continue
   var poses:=[]
   for i in node.multimesh.instance_count:poses.append(node.multimesh.get_instance_transform(i))
   var panels:=preload("res://scripts/terrain/field/CliffSiding.gd").panels(poses)
   for key:String in panels:
    var dimensions:=key.trim_prefix("wall_").split("x")
    var width:=float(dimensions[0]);var height:=float(dimensions[1])
    for panel:Transform3D in panels[key]:
     var n:=maxi(1,roundi(width/5.5));var bay:=width/n
     for i in n:
      var anchor:=panel*Vector3(-width*.5+bay*(i+.5),0,0)
      var roll:=Helper.position_hash01(anchor,9271)
      var variant:int=10+mini(7,int(roll*8))
      var rib_height:=(height-.4)*lerpf(.92,1.0,Helper.position_hash01(anchor,9283))
      var size:=Vector3(bay*lerpf(1.5,1.85,roll),rib_height,lerpf(3.0,3.8,roll))
      var local:=Transform3D(Basis.from_scale(size)*Basis(Vector3.UP,lerpf(-.2,.2,roll)),Vector3(-width*.5+bay*(i+.5),-.26,.45))
      var pose:Transform3D=node.global_transform*panel*local
      if not batches.has(variant):batches[variant]=[]
      batches[variant].append(pose);count+=1
      _plants(stock[variant],pose,plants,roll)
      # Broken front ribs obscure the straight rear shoulders and vary the
      # silhouette, while the complete ledged solid retains ground bearing.
      var face_variant:int=[1,2,4,7][mini(3,int(Helper.position_hash01(anchor,9293)*4))]
      var face_pose:=local
      face_pose.basis=Basis.from_scale(Vector3(bay*1.30,height*lerpf(.68,.93,roll),3.8))*Basis(Vector3.UP,roll*TAU)
      face_pose.origin.z=1.85
      var face_world:Transform3D=node.global_transform*panel*face_pose
      if not batches.has(face_variant):batches[face_variant]=[]
      batches[face_variant].append(face_world);count+=1
      _plants(stock[face_variant],face_world,plants,roll+.31)
      if height>=8:
       var shoulder:=local
       shoulder.basis=Basis.from_scale(Vector3(bay*1.1,height*lerpf(.22,.65,roll),4.5))*Basis(Vector3.UP,roll*TAU+1.2)
       shoulder.origin.x+=bay*(.20 if roll<.5 else -.20);shoulder.origin.z=.75
       var v:int=4 if roll<.5 else 7
       var p:Transform3D=node.global_transform*panel*shoulder
       if not batches.has(v):batches[v]=[]
       batches[v].append(p);count+=1
       _plants(stock[v],p,plants,roll+.2)
  for variant:int in batches:
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=stock[variant]
   mm.instance_count=batches[variant].size()
   for i in mm.instance_count:mm.set_instance_transform(i,batches[variant][i])
   var instance:=MultiMeshInstance3D.new();instance.multimesh=mm;world.add_child(instance)
  plants._flush();plants.free()
  print("MOSS_ROCK_STUDY ",count)
 await super._capture_views(world)

func _plants(mesh:Mesh,pose:Transform3D,plants:Node3D,roll:float)->void:
 if roll>.82:return
 var faces:=mesh.surface_get_arrays(1)
 var vertices:PackedVector3Array=faces[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=faces[Mesh.ARRAY_INDEX]
 var anchors:Array[Vector3]=[]
 for i in range(0,indices.size(),3):
  var a:=pose*vertices[indices[i]];var b:=pose*vertices[indices[i+1]];var c:=pose*vertices[indices[i+2]]
  var normal:=(c-a).cross(b-a).normalized()
  if normal.y<.7:continue
  var point:Vector3=(a+b+c)/3
  var native:=pose.affine_inverse()*point
  if native.z<.05:continue
  var clear:=true
  for old:Vector3 in anchors:
   if old.distance_to(point)<1.4:clear=false
  if not clear:continue
  var space:PhysicsDirectSpaceState3D=plants._stage.get_world_3d().direct_space_state
  var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*150,point-Vector3.UP*.1))
  if not hit.is_empty() and hit.position.y>point.y+.2:continue
  anchors.append(point)
  var scale_value:=lerpf(1.2,2.1,fposmod(roll,1))
  plants._asset(plants.SOURCE+"Bush_Common.gltf",Transform3D(Basis(Vector3.UP,roll*TAU).scaled(Vector3.ONE*scale_value),point-Vector3.UP*.12),"leaf")
  if anchors.size()>=2:break
