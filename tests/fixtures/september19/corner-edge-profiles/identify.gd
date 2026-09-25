extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/"
func _initialize()->void:call_deferred("run")
func run()->void:
 var world:Node3D=load("res://docs/qa/2026-09-19-manual/99-height-transition/fresh-grass-P12/world.scn").instantiate();root.add_child(world)
 var eye:=Vector3(-435,43,-267);var camera:=Transform3D(Basis.IDENTITY,eye).looking_at(Vector3(-444,29,-276))
 await physics_frame
 await physics_frame
 var space:=world.get_world_3d().direct_space_state
 var reports:Array=[]
 for pixel:Vector2 in [Vector2(1080,490),Vector2(1020,560),Vector2(890,340),Vector2(980,420),Vector2(760,580)]:
  var direction:=camera.basis*Vector3((pixel.x/800.0-1)*tan(deg_to_rad(32.5))*1.6,(1-pixel.y/500.0)*tan(deg_to_rad(32.5)),-1).normalized()
  var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,eye+direction*80,1))
  if hit.is_empty():continue
  var p:Vector3=hit.position;var found:Array=[]
  for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
   var local:Vector3=pose.affine_inverse()*p
   var faces:PackedVector3Array=node.get_meta("relief_faces")
   for i in range(0,faces.size(),3):
    var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
    var n:Vector3=(b-a).cross(c-a);var size:=n.length()
    if size<.00001 or absf((local-a).dot(n)/size)>.002:continue
    var sum:float=(b-local).cross(c-local).length()+(a-local).cross(c-local).length()+(a-local).cross(b-local).length()
    if absf(sum-size)>.003:continue
    found.append({"pose":str(pose),"recipe":str(node.get_meta("relief_recipe")),"triangle":[str(a),str(b),str(c)],"side_cap":absf(a.x-b.x)<.001 and absf(a.x-c.x)<.001})
  reports.append({"pixel":str(pixel),"point":str(p),"normal":str(hit.normal),"forms":found})
 print(JSON.stringify(reports))
 FileAccess.open(OUT+"cap-identification.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
 quit()
