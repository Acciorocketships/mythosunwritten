extends SceneTree
## Offline fit of native vine strands to the existing repeating cliff relief.
## The runtime receives ordinary baked assets, never source paths or deformation.
func _initialize() -> void:
 var stock:EnvironmentVisual=load("res://terrain/environment/visuals/kaykit/kaykit_cliff_wall.tres")
 var wall:PackedVector3Array=stock.pieces[0].mesh.get_faces()
 for i in wall.size():wall[i]=stock.pieces[0].local_transform*wall[i]
 DirAccess.make_dir_recursive_absolute("res://assets/NativeCliffVines")
 var entries:=[]
 var sources:Dictionary={}
 for variant:int in [1,2,4,5,6,9]:
  var doc:=GLTFDocument.new();var st:=GLTFState.new()
  assert(doc.append_from_file("res://assets/MedievalVillageQuaternius/glTF/Prop_Vine%d.gltf"%variant,st)==OK)
  sources[variant]=doc.generate_scene(st)
 for variant:int in [1,2,4,5,6,9]:
  for count:int in [1,2,3,4,5]:
   var root:=Node3D.new()
   root.name="NativeCliffVine"
   var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   var material:Material
   # Every native source's crown stays below the parent cliff crown;
   # the wider cross-branch sources have higher original origins.
   var offset:=1.85
   for segment in count:
    var kinds:=[1,2,4,5,6,9]
    var kind:int=kinds[(kinds.find(variant)+segment*5+segment*segment)%kinds.size()]
    var source:Node=sources[kind]
    var spread:float=1.05 if kind in [1,2,4] else (.82 if kind==5 else .52)
    var scale_value:float=1.0-float(segment)*.075
    var sideways:float=.18*sin(variant*2.3+segment*1.7)
    for node:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
     var pose:=node.transform;var parent:=node.get_parent()
     while parent!=source and parent is Node3D:pose=parent.transform*pose;parent=parent.get_parent()
     for section in node.mesh.get_surface_count():
      var arrays:=node.mesh.surface_get_arrays(section)
      var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
      for i in vertices.size():
       var point:=pose*vertices[i]*scale_value
       point.x=point.x*spread+sideways+.12*sin(point.y*1.2+variant+segment)
       if (variant+segment)%2==0:point.x=-point.x
       point.y-=offset
       # Actual relief fit is recomputed after all variation; the leaf cluster
       # keeps its silhouette while the wall owns its attachment depth.
       point.z=_front(wall,point.x,point.y)+.05+absf(point.z)*.12
       vertices[i]=point
      arrays[Mesh.ARRAY_VERTEX]=vertices
      var part:=ArrayMesh.new();part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
      surface.append_from(part,0,Transform3D.IDENTITY)
      material=node.get_active_material(section).duplicate()
      if material is StandardMaterial3D:
       material.roughness=.95;material.metallic_specular=.1
    offset+=1.3+.38*(1.0+sin(variant*1.3+segment*2.1))
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
 for source:Node in sources.values():source.free()
 entries.append({"id":"quaternius.cliff.fern","source":"res://assets/StylizedNatureQuaternius/glTF/Fern_1.gltf","merge_pieces":true,"tags":["foliage","fern"],"supports_instance_color":false})
 for i:int in [1,3]:
  entries.append({"id":"native.cliff.groundplant_%d"%i,"source":"res://assets/LowPolyFantasyVillage/Models/Nature/Plant_0%d.glb"%i,"merge_pieces":true,"tags":["foliage","plant"],"supports_instance_color":false})
 FileAccess.open("res://tools/environment_bake/manifests/native_cliff_foliage.json",FileAccess.WRITE).store_string(JSON.stringify({"pack":"native_cliff_foliage","license":"Quaternius CC0 vines and fern fitted to KayKit CC0 cliff stock; ground plants retain the LowPolyFantasyVillage source-pack license","assets":entries},"  "))
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
