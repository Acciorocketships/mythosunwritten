extends RefCounted
func run(review:Node3D)->void:
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var env=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").build(Rect2(476,924,92,96),ground,func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0,2697992464,func(q:Vector2)->float:return d.wet[index.call(q)])
 var checked:=0;var misses:=[];var area:=0.0;var unique:={}
 var space:=review.get_world_3d().direct_space_state
 for chunk:Vector2i in [Vector2i(2,4),Vector2i(2,5)]:
  for node:MultiMeshInstance3D in review._streamer._built[chunk].find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   var faces:PackedVector3Array=node.get_meta("relief_faces")
   for i in range(0,faces.size(),3):
    var a:Vector3=node.global_transform*faces[i];var b:Vector3=node.global_transform*faces[i+1];var c:Vector3=node.global_transform*faces[i+2]
    var p:Vector3=(a+b+c)/3.0;var q:=Vector2(p.x,p.z)
    if not Rect2(480,928,76,80).has_point(q):continue
    if unique.has(p):continue
    var cross:Vector3=(c-a).cross(b-a)
    if cross.normalized().y<.94 or env.rock_at(q)<.6 or p.y<ground.call(q)+.5:continue
    unique[p]=true;checked+=1;area+=cross.length()*.5
    var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*.2,review._character.collision_mask,[review._character.get_rid()])
    var hit:=space.intersect_ray(ray)
    if hit.is_empty() or (hit.position as Vector3).distance_to(p)>.002:misses.append(str(p))
 var result:={"tread_triangles":checked,"tread_area_m2":area,"missing_or_mismatched_contacts":misses}
 FileAccess.open(review._output_dir+"/ledge-contacts.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[ledge_contacts] ",JSON.stringify(result))
 assert(checked>50,"Verify the rendered horizontal rock ledges, not just the smooth backing")
 assert(misses.is_empty(),"Every tested ledge must have collision on its rendered surface")
