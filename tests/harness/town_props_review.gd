extends "res://tests/harness/pure_village_lineup.gd"

func _run() -> void:
 get_root().size = Vector2i(1600,900)
 var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/town_props.json"))
 for entry: Dictionary in manifest.assets:
  var stage := Node3D.new()
  get_root().add_child(stage)
  _light(stage)
  var visual := load("res://terrain/environment/visuals/town_props/%s.tres" % String(entry.id).replace(".","_")) as EnvironmentVisual
  if visual == null:
   push_error("Missing baked visual %s" % entry.id)
   quit(1)
   return
  var root := Node3D.new()
  stage.add_child(root)
  for piece: EnvironmentVisualPiece in visual.pieces:
   var node := MeshInstance3D.new()
   node.mesh = piece.mesh
   node.transform = piece.local_transform
   root.add_child(node)
  var box := _aabb(root)
  root.position.y = -box.position.y
  var target := box.get_center()-Vector3(0,box.position.y,0)
  var distance := maxf(2.0,box.size.length())
  print("PROP %s min=%s size=%s" % [entry.id,box.position,box.size])
  _label(stage,String(entry.id),Vector3(target.x,0.05,target.z+box.size.z*0.5+0.5))
  await _shoot(stage,target+Vector3(1,0.6,1)*distance,target,String(entry.id).replace(".","_"))
  stage.queue_free()
  await process_frame
 print("PROPS_REVIEW_DONE")
 quit()
