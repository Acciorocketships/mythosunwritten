extends SceneTree
const CliffTerraces=preload("res://scripts/terrain/field/CliffTerraces.gd")
func _init() -> void:
 var mesher:=TerrainChunkMesher.new()
 mesher.prepare_resources()
 for key in ["wall","outer_wall","inner_wall"]:
  var p:Array=CliffDressing._pieces[key]
  var f:PackedVector3Array=p[0].get_faces()
  var box:=AABB(p[1]*f[0],Vector3.ZERO)
  for v in f:box=box.expand(p[1]*v)
  print(key," ",box)
 for id in CliffTerraces._definitions:
  var d:Dictionary=CliffTerraces._definitions[id]
  if id==CliffTerraces.ROCK:continue
  var cap:=preload("res://scripts/terrain/field/NativeTerrainCap.gd").measure({"id":id,"top":d.bounds.end.y,"transform":Transform3D.IDENTITY,"bounds":d.bounds},d.faces)
  var b:=Rect2(cap.border[0],Vector2.ZERO)
  for v in cap.border:b=b.expand(v)
  print(id," visual ",d.bounds," cap ",b)
 quit()
