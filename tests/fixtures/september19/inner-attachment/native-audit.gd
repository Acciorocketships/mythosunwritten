extends SceneTree
const C=preload('res://scripts/terrain/field/CliffCornerCrags.gd')
func _initialize():call_deferred('_run')
func _run():
 C.prepare();C.CRAGS.prepare()
 var world:Node3D=load('res://docs/qa/2026-09-18-manual/88-cliff-corner-continuity/fresh-P12/world.scn').instantiate();root.add_child(world)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,32,-301.5))
 var faces:=PackedVector3Array();var tiles:=0;var names:Dictionary={}
 for node:MultiMeshInstance3D in world.find_children('*','MultiMeshInstance3D',true,false):
  if not 'Walls' in str(node.name):continue
  for i in node.multimesh.instance_count:
   var t:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
   if absf(t.origin.y-pose.origin.y)>.01 or Vector2(t.origin.x-pose.origin.x,t.origin.z-pose.origin.z).length()>10:continue
   tiles+=1;names[str(node.name)]=true
   var local:Transform3D=pose.affine_inverse()*t
   for p:Vector3 in node.multimesh.mesh.get_faces():faces.append(local*p)
 var count:=0;var missing:=0;var worst:=0.0
 for y:float in [.1,1,2,3]:
  for u:float in [-5.8,-4.1,-2.3,-1.2,-1.05,-.95,.95,1.05,1.2,2.3,4.1,5.8]:
   var base:=Vector3(maxf(u,0),y,maxf(-u,0));var actual:=-INF
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(base+Vector3(20,0,20),Vector3(-1,0,-1).normalized(),faces[i],faces[i+1],faces[i+2])
    if hit!=null:actual=maxf(actual,hit.x-base.x)
   count+=1
   if not is_finite(actual):missing+=1;continue
   worst=maxf(worst,absf(C._inner_native(u,y,pose)[0]-actual))
 var report:Dictionary={'tiles':tiles,'groups':names.keys(),'samples':count,'missing':missing,'max_error':worst}
 print('NATIVE_INNER ',JSON.stringify(report))
 FileAccess.open('res://docs/qa/2026-09-19-manual/89-inner-attachment/native-audit.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
 quit(1 if missing>0 or worst>.025 or tiles<3 else 0)
