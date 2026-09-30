extends RefCounted
func run(review:Node3D,label:="")->void:
 var space:=review.get_world_3d().direct_space_state
 var rows:=[];var misses:=[];var contacts:=0
 var grass:GrassStreamer=review._streamer._grass_streamer
 for tile:Vector2i in grass._built:
  var root:Node3D=grass._built[tile].node
  if root==null:continue
  for node:MultiMeshInstance3D in root.get_children():
   var mm:=node.multimesh
   var base_y:float=node.material_override.get_shader_parameter("local_base_y")
   var vertices:PackedVector3Array=mm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   var roots:=PackedVector3Array();var used:={}
   for p:Vector3 in vertices:
    if p.y>base_y+.025:continue
    var key:=Vector2(p.x,p.z).snapped(Vector2.ONE*.05)
    if used.has(key):continue
    used[key]=true;roots.append(p)
   for i in range(0,mm.instance_count,17):
    var tf:=node.global_transform*mm.get_instance_transform(i)
    var centre:=tf*Vector3(0,base_y,0)
    if centre.distance_to(review._views[0].player)>80 or review._camera.is_position_behind(centre):continue
    var pixel:Vector2=review._camera.unproject_position(centre)
    if not Rect2(0,0,1600,900).has_point(pixel):continue
    var checked:=0;var failed:=0
    for j in range(0,roots.size(),maxi(1,roots.size()/12)):
     var p:=tf*roots[j]
     var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.15,p-Vector3.UP*.15,review._character.collision_mask,[review._character.get_rid()])
     ray.hit_back_faces=true
     var hit:=space.intersect_ray(ray)
     checked+=1;contacts+=1
     if hit.is_empty():
      failed+=1;misses.append({"world":str(p),"pixel":str(review._camera.unproject_position(p))})
    rows.append({"centre":str(centre),"pixel":str(pixel),"blade_roots":checked,"misses":failed})
 var result:={"blade_roots_checked":contacts,"missing_contacts":misses.size(),"clumps":rows,"misses":misses}
 var suffix:=label if not label.is_empty() else ("before" if not FileAccess.file_exists(review._output_dir+"/grass-before.json") else "after")
 FileAccess.open(review._output_dir+"/grass-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[p03_grass_audit] ",suffix," roots=",contacts," misses=",misses.size())
 if suffix=="after":
  assert(contacts>100,"Exercise actual blade roots across the reported view")
  assert(misses.is_empty(),"Grass blades need visible ground support")
