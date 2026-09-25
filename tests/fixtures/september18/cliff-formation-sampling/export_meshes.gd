extends SceneTree
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var path:="res://tests/fixtures/september18/cliff-formation-sampling/embedded-before.gd"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--generator="):path=arg.trim_prefix("--generator=")
 var candidate:GDScript=load(path)
 var baseline:GDScript=load("res://tests/fixtures/september18/cliff-formation-sampling/before.gd")
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 for entry:Array in [["before",baseline],["candidate",candidate]]:
  var form:Dictionary=entry[1].make(pose,48,32,2697992464)[0]
  for surface:String in ["faces","green"]:
   var stream:=FileAccess.open("res://tests/fixtures/september18/cliff-formation-sampling/"+entry[0]+"-"+surface+".bin",FileAccess.WRITE)
   stream.store_buffer(form[surface].to_byte_array());stream.close()
 print("EXPORTED matching source and candidate meshes")
 quit()
