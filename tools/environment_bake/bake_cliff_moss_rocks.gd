extends "res://tools/environment_bake/environment_bake.gd"
## Feed freshly authored GLBs into the ordinary self-contained catalogue bake.
var _fresh_sources:Array[PackedScene]=[]
func _run()->void:
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/cliff_moss_rocks.json"))
 for entry:Dictionary in manifest.assets:
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  assert(document.append_from_file(entry.source,state)==OK)
  var root:=document.generate_scene(state);var packed:=PackedScene.new()
  if entry.id=="cliff.rock.bush":
   for node:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
    for i in node.mesh.get_surface_count():
     var original:=node.get_active_material(i) as StandardMaterial3D
     if original==null or original.albedo_texture==null:continue
     var leaves:=ShaderMaterial.new()
     leaves.shader=load("res://terrain/materials/cliff_leaves.gdshader")
     leaves.set_shader_parameter("leaf_tex",original.albedo_texture)
     node.mesh.surface_set_material(i,leaves)
  assert(packed.pack(root)==OK);root.free()
  packed.take_over_path(entry.source);_fresh_sources.append(packed)
 super._run()
