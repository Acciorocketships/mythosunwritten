extends RefCounted
func run(review:Node3D)->void:
 var north:={};var south:={}
 for key:Vector2i in [Vector2i(2,4),Vector2i(2,5)]:
  var points:Dictionary=north if key.y==4 else south
  var root:Node3D=review._streamer._built[key]
  for node:MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   var mesh:=node.multimesh.mesh
   var tf:=node.global_transform*node.multimesh.get_instance_transform(0)
   for s in mesh.get_surface_count():
    var arrays:=mesh.surface_get_arrays(s)
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    for i in vertices.size():
     var p:Vector3=tf*vertices[i]
     if p.x<480 or p.x>560 or absf(p.z-948)>.6:continue
     points[p]=(tf.basis*normals[i]).normalized()
 var count:=0;var maximum:=0.0;var examples:=[]
 for p:Vector3 in north:
  if not south.has(p):continue
  count+=1
  var error:float=(north[p] as Vector3).distance_to(south[p])
  maximum=maxf(maximum,error)
  if error>.001 and examples.size()<8:examples.append({"point":str(p),"error":error})
 var result:={"shared_vertices":count,"maximum_normal_disagreement":maximum,"examples":examples}
 FileAccess.open(review._output_dir+"/normal-seam-native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[p03_normals] ",JSON.stringify(result))
 assert(count>100)
 assert(maximum<.001,"Adjacent native chunks must shade their shared vertices identically")
