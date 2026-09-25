extends SceneTree
## Offline fit of native vine strands to the existing repeating cliff relief.
## The runtime receives ordinary baked assets, never source paths or deformation.
func _initialize() -> void:
 var stock:EnvironmentVisual=load("res://terrain/environment/visuals/kaykit/kaykit_cliff_wall.tres")
 var wall:PackedVector3Array=stock.pieces[0].mesh.get_faces()
 for i in wall.size():wall[i]=stock.pieces[0].local_transform*wall[i]
 DirAccess.make_dir_recursive_absolute("res://assets/NativeCliffVines")
 var entries:=[]
 for variant:int in [1,2,4]:
  var source_path:="res://assets/Medieval Village MegaKit/glTF/Prop_Vine%d.gltf"%variant
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  assert(document.append_from_file(source_path,state)==OK)
  var source:=document.generate_scene(state)
  for count:int in [1,2,3]:
   var root:=Node3D.new()
   root.name="NativeCliffVine"
   var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   var material:Material
   for node:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
    var pose:=node.transform;var parent:=node.get_parent()
    while parent!=source and parent is Node3D:pose=parent.transform*pose;parent=parent.get_parent()
    for segment in count:
     var scale_value:=1.0-float(segment)*.10
     for section in node.mesh.get_surface_count():
      var arrays:=node.mesh.surface_get_arrays(section)
      var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
      for i in vertices.size():
       var point:=pose*vertices[i]*scale_value
       point.y-=.95+float(segment)*1.8
       point.z=_front(wall,point.x,point.y)+maxf(.025,point.z+.055)
       vertices[i]=point
      arrays[Mesh.ARRAY_VERTEX]=vertices
      var part:=ArrayMesh.new();part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
      surface.append_from(part,0,Transform3D.IDENTITY)
      material=node.get_active_material(section).duplicate()
      if material is StandardMaterial3D:
       material.roughness=.95;material.metallic_specular=.1
   surface.generate_normals()
   var mesh:=surface.commit();mesh.surface_set_material(0,material)
   var instance:=MeshInstance3D.new();instance.mesh=mesh;root.add_child(instance);instance.owner=root
   var name:="trailing_%d_%d"%[variant,count]
   var path:="res://assets/NativeCliffVines/"+name+".glb"
   var output:=GLTFDocument.new();var output_state:=GLTFState.new()
   assert(output.append_from_scene(root,output_state)==OK)
   assert(output.write_to_filesystem(output_state,path)==OK)
   root.free()
   entries.append({"id":"native.cliff."+name,"source":path,"merge_pieces":true,"tags":["foliage","cliff"],"supports_instance_color":false})
  source.free()
 entries.append({"id":"quaternius.cliff.fern","source":"res://assets/StylizedNatureQuaternius/glTF/Fern_1.gltf","merge_pieces":true,"tags":["foliage","fern"],"supports_instance_color":false})
 FileAccess.open("res://tools/environment_bake/manifests/native_cliff_foliage.json",FileAccess.WRITE).store_string(JSON.stringify({"pack":"native_cliff_foliage","license":"Quaternius CC0; original leaf meshes fitted to KayKit CC0 cliff stock","assets":entries},"  "))
 quit()

func _front(faces:PackedVector3Array,x:float,y:float)->float:
 var p:=Vector2(x,fposmod(y+.3,4.0)-.3)
 var result:=-INF
 for i in range(0,faces.size(),3):
  var a:=Vector2(faces[i].x,faces[i].y);var b:=Vector2(faces[i+1].x,faces[i+1].y);var c:=Vector2(faces[i+2].x,faces[i+2].y)
  var area:=(b-a).cross(c-a)
  if absf(area)<.000001:continue
  var u:=(b-p).cross(c-p)/area;var v:=(c-p).cross(a-p)/area
  if u>=-.00001 and v>=-.00001 and u+v<=1.00001:result=maxf(result,u*faces[i].z+v*faces[i+1].z+(1-u-v)*faces[i+2].z)
 assert(is_finite(result),"Vine escaped the native wall socket")
 return result
