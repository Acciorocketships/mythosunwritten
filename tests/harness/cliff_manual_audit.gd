extends RefCounted
## Run through cliff_site_review's test-only `probe` command, on its settled
## streamed scene. Tests real collision and rendered grass instance roots.
func run(review:Node3D)->void:
 var rows:=[]
 for view:Dictionary in review._views:
  if not view.has("player"):continue
  await review._grass_at(view.player)
  for tick in 3:await review.get_tree().physics_frame
  var space:=review.get_world_3d().direct_space_state
  var misses:=[];var checked:=0
  var grass:GrassStreamer=review._streamer._grass_streamer
  for tile:Vector2i in grass._built:
   var root:Node3D=grass._built[tile].node
   if root==null:continue
   for node:MultiMeshInstance3D in root.get_children():
    var mm:=node.multimesh
    var base_y:float=node.material_override.get_shader_parameter("local_base_y")
    for i in range(0,mm.instance_count,11):
     var tf:=node.global_transform*mm.get_instance_transform(i)
     var p:=tf*Vector3(0,base_y,0)
     if Vector2(p.x-view.player.x,p.z-view.player.z).length()>20:continue
     var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.12,p-Vector3.UP*.12,review._character.collision_mask,[review._character.get_rid()]))
     checked+=1
     if hit.is_empty():misses.append([p.x,p.y,p.z])
  rows.append({"view":view.id,"grass_roots":checked,"unsupported_roots":misses.size(),"misses":misses})
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
 var result:={"grass":rows,"surface_contacts":mesh_checked,"missing_surface_contacts":mesh_misses}
 FileAccess.open(review._output_dir+"/native-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[manual_cliff_audit] ",JSON.stringify(result))
