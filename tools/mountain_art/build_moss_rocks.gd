extends SceneTree
## Offline conversion of the owner's chosen CC0 Ultimate Nature moss rocks.
## Normalize bounds for a measured face-fitting art study; retain every source face.
func _initialize()->void:
 DirAccess.make_dir_recursive_absolute("res://assets/CliffMossRocks")
 for variant:int in [1,2,4,7]:
  var vertices:Array[Vector3]=[]
  var triangles:=[]
  var green:=false
  for line:String in FileAccess.get_file_as_string("res://assets/UltimateNaturePack/OBJ/Rock_Moss_%d.obj"%variant).split("\n"):
   var parts:=line.split(" ",false)
   if parts.is_empty():continue
   if parts[0]=="v":vertices.append(Vector3(float(parts[1]),float(parts[2]),float(parts[3])))
   if parts[0]=="usemtl":green=parts[1]=="Green"
   if parts[0]=="f":
    for i in range(2,parts.size()-1):triangles.append([int(parts[1].split("/")[0])-1,int(parts[i+1].split("/")[0])-1,int(parts[i].split("/")[0])-1,green])
  var bounds:=AABB(vertices[0],Vector3.ZERO)
  for v:Vector3 in vertices:bounds=bounds.expand(v)
  var mesh:=ArrayMesh.new()
  for moss:bool in [false,true]:
   var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_smooth_group(-1)
   for face:Array in triangles:
    if face[3]!=moss:continue
    for i in 3:
     var v:Vector3=(vertices[face[i]]-bounds.position)/bounds.size
     surface.add_vertex(v-Vector3(.5,0,.5))
   surface.generate_normals();surface.commit(mesh)
   var mat:=StandardMaterial3D.new();mat.roughness=1;mat.metallic_specular=0
   mat.albedo_color=Color(.18,.31,.10) if moss else Color(.38,.39,.43)
   mesh.surface_set_material(mesh.get_surface_count()-1,mat)
  var root:=Node3D.new();var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node);node.owner=root
  var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_scene(root,state)==OK)
  assert(doc.write_to_filesystem(state,"res://assets/CliffMossRocks/moss_%d.glb"%variant)==OK)
  root.free()
 quit()
