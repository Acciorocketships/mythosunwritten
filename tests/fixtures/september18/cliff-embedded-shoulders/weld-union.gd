extends SceneTree
func _initialize()->void:
 var prefix:="moss-" if "--moss" in OS.get_cmdline_user_args() else ""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
 var path:="res://tests/fixtures/september18/cliff-embedded-shoulders/"+prefix+"union-"
 var faces:PackedVector3Array=FileAccess.open(path+"faces.bin",FileAccess.READ).get_var()
 var green:PackedVector3Array=FileAccess.open(path+"green.bin",FileAccess.READ).get_var()
 var cleaned:=PackedVector3Array();var turf:=PackedVector3Array();var removed:=0
 var originals:Dictionary={}
 for i in range(0,green.size(),3):originals[[green[i],green[i+1],green[i+2]]]=true
 for i in range(0,faces.size(),3):
  var tri:Array[Vector3]=[faces[i].snapped(Vector3.ONE*.00001),faces[i+1].snapped(Vector3.ONE*.00001),faces[i+2].snapped(Vector3.ONE*.00001)]
  if tri[0]==tri[1] or tri[1]==tri[2] or tri[2]==tri[0]:removed+=1;continue
  cleaned.append_array(PackedVector3Array(tri))
  if originals.has([faces[i],faces[i+1],faces[i+2]]):turf.append_array(PackedVector3Array(tri))
 FileAccess.open(path+"welded-faces.bin",FileAccess.WRITE).store_var(cleaned)
 FileAccess.open(path+"welded-green.bin",FileAccess.WRITE).store_var(turf)
 print("UNION_WELD ",prefix," triangles=",cleaned.size()/3," removed=",removed," turf=",turf.size()/3)
 quit()
