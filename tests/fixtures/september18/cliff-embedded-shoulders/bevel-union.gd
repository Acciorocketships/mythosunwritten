extends SceneTree
const BASE=preload("res://tests/fixtures/september18/cliff-embedded-shoulders/before.gd")
const OUT="res://tests/fixtures/september18/cliff-embedded-shoulders/"
func _initialize()->void:call_deferred("_run")
func _array_mesh(faces:PackedVector3Array)->ArrayMesh:
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=faces
 var normals:=PackedVector3Array();var indices:=PackedInt32Array()
 for i in range(0,faces.size(),3):
  var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
  for j in 3:normals.append(normal);indices.append(i+j)
 arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func _run()->void:
 var started:=Time.get_ticks_msec()
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var a:Array=anchors[20]
 var form:Dictionary=BASE.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 print("UNION_SOURCE ",a," triangles=",form.faces.size()/3)
 var combination:=CSGCombiner3D.new()
 var source:=CSGMesh3D.new();source.mesh=BASE.mesh(form);combination.add_child(source)
 var assets:Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"bevel-rocks.json"))
 var rows:Array=[]
 for i in 3:
  var asset:Dictionary=assets[i]
  var x:float=[-6.5,-.5,5.5][i];var cy:float=[1.9,1.6,1.25][i]
  var width:float=[9.0,6.5,8.5][i];var height:float=[4.7,3.9,3.3][i];var depth:float=[6.0,5.4,5.5][i]
  var z:=-INF
  for t in range(0,form.faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(x,cy,30),Vector3.FORWARD,form.faces[t],form.faces[t+1],form.faces[t+2])
   if hit!=null:z=maxf(z,hit.z)
  assert(is_finite(z))
  var basis:=Basis(Vector3.UP,[.2,-.3,.4][i])*Basis(Vector3.FORWARD,[.1,-.15,.06][i])
  var transformed:=PackedVector3Array()
  for v:Array in asset.vertices:
   var p:Vector3=basis*(Vector3(v[0],v[1],v[2])-Vector3.ONE*.5)
   p*=Vector3(width,height,depth);p+=Vector3(x,cy,z-depth*.35)
   transformed.append(p)
  var faces:=PackedVector3Array();var turf:=PackedVector3Array();var volume:=0.0
  for tri:Array in asset.faces:
   var p:Vector3=transformed[tri[0]];var q:Vector3=transformed[tri[1]];var r:Vector3=transformed[tri[2]]
   volume+=p.dot(q.cross(r))/6.0
  for face_index in asset.faces.size():
   var tri:Array=asset.faces[face_index]
   var vertices:=PackedVector3Array([transformed[tri[0]],transformed[tri[2] if volume>0 else tri[1]],transformed[tri[1] if volume>0 else tri[2]]])
   if asset.green[face_index]:turf.append_array(vertices)
   else:faces.append_array(vertices)
  var part:=CSGMesh3D.new();part.mesh=_array_mesh(faces);part.mesh.surface_set_material(0,source.mesh.surface_get_material(0))
  if not turf.is_empty():
   var grass_mesh:=_array_mesh(turf)
   part.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,grass_mesh.surface_get_arrays(0))
   part.mesh.surface_set_material(1,source.mesh.surface_get_material(1))
  combination.add_child(part)
  rows.append({"asset":asset.asset,"center":str(Vector3(x,cy,z-depth*.35)),"size":str(Vector3(width,height,depth))})
 root.add_child(combination)
 for frame in 5:await process_frame
 var meshes:Array=combination.get_meshes()
 assert(meshes.size()==2)
 var mesh:Mesh=meshes[1]
 ResourceSaver.save(mesh,OUT+"bevel-union.res")
 var faces:=mesh.get_faces();var green:=PackedVector3Array()
 for surface in mesh.get_surface_count():
  var material:Material=mesh.surface_get_material(surface)
  print("UNION_SURFACE ",surface," material=",material," vertices=",mesh.surface_get_array_len(surface))
  if material==source.mesh.surface_get_material(1):
   var single:=ArrayMesh.new();single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(surface));green.append_array(single.get_faces())
 FileAccess.open(OUT+"bevel-union-faces.bin",FileAccess.WRITE).store_var(faces)
 FileAccess.open(OUT+"bevel-union-green.bin",FileAccess.WRITE).store_var(green)
 FileAccess.open(OUT+"bevel-union-manifest.json",FileAccess.WRITE).store_string(JSON.stringify({"triangles":faces.size()/3,"green_triangles":green.size()/3,"time_ms":Time.get_ticks_msec()-started,"placements":rows},"  "))
 print("UNION_DONE triangles=",faces.size()/3," green=",green.size()/3," ms=",Time.get_ticks_msec()-started)
 quit()
