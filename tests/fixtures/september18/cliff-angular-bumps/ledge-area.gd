extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var results:Array=[]
 for name:String in ["before","candidate","bearing","carved","open-carved"]:
  var source:GDScript=load("res://tests/fixtures/september18/cliff-angular-bumps/"+name+".gd")
  for height:float in [8,32]:
   var form:Dictionary=source.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
   var area:=0.0
   for i in range(0,form.green.size(),3):area+=(form.green[i+1]-form.green[i]).cross(form.green[i+2]-form.green[i]).length()*.5
   var row:Dictionary={"source":name,"height":height,"turf_area":area,"turf_triangles":form.green.size()/3,"physical_triangles":form.faces.size()/3}
   results.append(row);print("LEDGE_AREA ",JSON.stringify(row))
 FileAccess.open("res://docs/qa/2026-09-18-manual/78-cliff-angular-bumps/ledge-area.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 quit()
