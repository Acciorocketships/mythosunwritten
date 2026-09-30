extends RefCounted
## Run through cliff_site_review's test-only `probe` command, on its settled
## streamed scene. Tests real collision and rendered grass instance roots.
func run(review:Node3D)->void:
 var mesh_checked:=0;var mesh_misses:=[]
 var space:=review.get_world_3d().direct_space_state
 for chunk:Vector2i in review._streamer._built:
  var root:Node3D=review._streamer._built[chunk]
  for node:MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   var faces:PackedVector3Array=node.get_meta("relief_faces")
   var stride:=maxi(1,faces.size()/3/500)*3
   for i in range(0,faces.size(),stride):
    var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
    var p:Vector3=node.global_transform*((a+b+c)/3.0)
    var near:=false
    for view:Dictionary in review._views:
     if p.distance_to(view.target)<35:near=true;break
    if not near:continue
    var normal:Vector3=(c-a).cross(b-a).normalized()
    var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+normal*.08,p-normal*.08,review._character.collision_mask,[review._character.get_rid()]))
    mesh_checked+=1
    if hit.is_empty():mesh_misses.append([p.x,p.y,p.z])
 var result:={"surface_contacts":mesh_checked,"missing_surface_contacts":mesh_misses}
 FileAccess.open(review._output_dir+"/surface-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[restored_cliff_audit] ",JSON.stringify(result))
