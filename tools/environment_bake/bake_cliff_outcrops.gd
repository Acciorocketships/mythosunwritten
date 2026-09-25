extends "res://tools/environment_bake/environment_bake.gd"
## Feed freshly authored GLBs into the ordinary self-contained catalogue bake.
var _fresh_sources:Array[PackedScene]=[]
func _run()->void:
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/cliff_outcrops.json"))
 for entry:Dictionary in manifest.assets:
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  assert(document.append_from_file(entry.source,state)==OK)
  var root:=document.generate_scene(state);var packed:=PackedScene.new()
  assert(packed.pack(root)==OK);root.free()
  packed.take_over_path(entry.source);_fresh_sources.append(packed)
 super._run()
