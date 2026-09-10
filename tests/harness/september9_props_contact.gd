extends SceneTree
func _init() -> void:
 var catalog:=EnvironmentCatalog.load_default()
 var surfaces: Array=[]
 for id: StringName in [SettlementFabricProgram.TERRACE_CRATE,SettlementFabricProgram.TERRACE_BAG]:
  var visual:=load(catalog.descriptor(id).visual_path) as EnvironmentVisual
  var faces:=PackedVector3Array()
  for piece in visual.pieces:
   for p in piece.mesh.get_faces():faces.append(piece.local_transform*p)
  surfaces.append(faces)
 var rise:=-INF
 var witness:=Vector2.ZERO
 var rows:Array=[]
 for ix in range(-10,11):
  for iz in range(-8,9):
   var x:=ix*0.025
   var z:=iz*0.025
   var levels:Array=[]
   for faces:PackedVector3Array in surfaces:
    var lo:=INF
    var hi:=-INF
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(Vector3(x,3,z),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
     if hit!=null:
      lo=minf(lo,hit.y)
      hi=maxf(hi,hit.y)
    levels.append(Vector2(lo,hi))
   if not is_finite(levels[0].y) or not is_finite(levels[1].x):continue
   var delta:float=levels[0].y-levels[1].x
   if delta>rise:
    rise=delta
    witness=Vector2(x,z)
   rows.append({"xz":str(Vector2(x,z)),"crate_top":levels[0].y,"bag_bottom":levels[1].x})
 var result:={"bag_rise":rise,"contact_xz":str(witness),"samples":rows}
 print("BAG_RISE ",rise," contact ",witness)
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit()
