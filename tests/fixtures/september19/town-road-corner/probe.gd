extends SceneTree
const ROOT = "res://docs/qa/2026-09-19-manual/107-town-road-corner"
func _init() -> void:
 var data: Dictionary = FileAccess.open(ROOT.path_join("field.bin"),FileAccess.READ).get_var()
 var shapes: Array[FeatureGroundShape] = []
 for values: Dictionary in data.shapes:
  var shape := FeatureGroundShape.new(values.kind, values._a, values._b, values._radius, values._half_extents, values._angle, values.surface_id, values.priority, values.stable_id)
  shapes.append(shape)
 var field := FeatureGroundField.new(shapes,[],4.5,data.masks,data.nodes,data.priorities)
 var curved := PathProgram.filleted_path_shapes(data.roads[0].points,2,1,120,&"desired")
 var excess: Array = []
 for z in range(10460,10521):
  for x in range(-10581,-10539):
   var p:=Vector2(x,z)*.1
   var owns:=false
   for s:FeatureGroundShape in curved:
    if s.contains(p):owns=true
   if field.surface_at(p)==1 and not owns:excess.append(p)
 for p:Vector2 in [Vector2(-1057.8,1051.8),Vector2(-1057,1051),Vector2(-1056,1051)]:
  var ids:Array=[]
  for s:FeatureGroundShape in shapes:
   if s.contains(p):ids.append(str(s.stable_id))
  print("CORNER_POINT ",p," surface=",field.surface_at(p)," shapes=",ids)
 print("CORNER_EXCESS ",excess.size()," of 2562 grid points; first=",excess.slice(0,10))
 FileAccess.open(ROOT.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"excess":excess,"masks":data.masks,"roads":data.roads},"  "))
 quit()
