extends SceneTree
func _init() -> void:
 var rows: Array=[]
 for id: StringName in [SettlementFabricProgram.WOOD_DOOR_CLOSED,SettlementFabricProgram.ROCK_DOOR_CLOSED]:
  var visual:=load(EnvironmentCatalog.load_default().descriptor(id).visual_path) as EnvironmentVisual
  var hits: Array=[]
  for piece in visual.pieces:
   var faces:=piece.mesh.get_faces()
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(Vector3(1.1,2.75,5),Vector3.FORWARD,piece.local_transform*faces[i],piece.local_transform*faces[i+1],piece.local_transform*faces[i+2])
    if hit!=null:hits.append(hit.z)
  rows.append({"asset":String(id),"hits":hits,"bounds":str(EnvironmentCatalog.load_default().descriptor(id).measured_aabb)})
 print(rows)
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 quit()
