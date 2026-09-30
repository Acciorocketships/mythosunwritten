extends RefCounted
## Run through cliff_site_review's test-only `probe` command, on its settled
## streamed scene. Tests real collision against mesh centroids with a 2 mm hit-position tolerance.
func run(review:Node3D)->void:
 var mesh_checked:=0;var mesh_misses:=[];var covered:=[]
 var space:=review.get_world_3d().direct_space_state
 for chunk:Vector2i in review._streamer._built:
  var root:Node3D=review._streamer._built[chunk]
  for node:MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   var faces:PackedVector3Array=node.get_meta("relief_faces")
   var stride:=maxi(1,faces.size()/3/1000)*3
   for i in range(0,faces.size(),stride):
    var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
    var p:Vector3=node.global_transform*((a+b+c)/3.0)
    var near:=false
    for view:Dictionary in review._views:
     if p.distance_to(view.target)<35:near=true;break
    if not near:continue
    var normal:Vector3=(c-a).cross(b-a).normalized()
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+normal*.2,p-normal*.2,review._character.collision_mask,[review._character.get_rid()]))
    mesh_checked+=1
    if hit.is_empty():mesh_misses.append([p.x,p.y,p.z])
    elif (hit.position as Vector3).distance_to(p)>.002:
     # The sheet intentionally sinks under native ground. A nearer opaque
     # contact covers this face; a contact behind it would be a real miss.
     var offset:Vector3=hit.position-p
     if offset.dot(normal)>=-.002:covered.append({"point":str(p),"contact":str(hit.position),"offset":offset.length()})
     else:mesh_misses.append([p.x,p.y,p.z])
 var result:={"surface_contacts":mesh_checked,"exposed_exact_contacts":mesh_checked-mesh_misses.size()-covered.size(),"covered_faces":covered,"missing_surface_contacts":mesh_misses}
 FileAccess.open(review._output_dir+"/surface-audit-final.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[restored_cliff_audit] ",JSON.stringify(result))
 assert(mesh_checked>100,"The native audit must exercise the reported cliff neighborhood")
 assert(mesh_misses.is_empty(),"Every sampled exposed surface needs collision backing")
