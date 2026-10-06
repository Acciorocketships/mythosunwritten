extends SceneTree
func _init():
 var output := "extends RefCounted\n## Conservative triangle bounds in two-metre height bands, measured from baked LPFV meshes.\nconst BANDS := {\n"
 for name in ["lpfv_tree_01","lpfv_tree_02"]:
  var visual = load("res://terrain/environment/visuals/low_poly_fantasy_village/%s.tres" % name)
  var boxes := {}
  for piece in visual.pieces:
   for surface in piece.mesh.get_surface_count():
    var arrays = piece.mesh.surface_get_arrays(surface)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for index in range(0,indices.size(),3):
     var a: Vector3 = piece.local_transform*vertices[indices[index]]
     var b: Vector3 = piece.local_transform*vertices[indices[index+1]]
     var c: Vector3 = piece.local_transform*vertices[indices[index+2]]
     var box := AABB(a,Vector3.ZERO).expand(b).expand(c)
     for band in range(floori(box.position.y/2),floori(box.end.y/2)+1):
      boxes[band] = (boxes[band] as AABB).merge(box) if boxes.has(band) else box
  output += '\t&"lpfv.tree.%s": [' % name.get_slice("_",2)
  var keys = boxes.keys()
  keys.sort()
  for band in keys:
   var box: AABB = boxes[band]
   var low := maxf(box.position.y,float(band)*2.0)
   var high := minf(box.end.y,float(band+1)*2.0)
   box.position.y = low
   box.size.y = high-low
   output += "AABB(%s,%s)," % [var_to_str(box.position),var_to_str(box.size)]
  output += "],\n"
 output += "}\n"
 var file := FileAccess.open("res://scripts/terrain/features/villages/TownTreeProfiles.gd",FileAccess.WRITE)
 file.store_string(output)
 quit()
