extends SceneTree
func _initialize()->void:
 var old=load("res://tests/fixtures/september17/cliff-oblique-relief/patches.gd")
 var current=load("res://tests/fixtures/september17/cliff-oblique-relief/cached.gd")
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for height:float in [32,64]:anchors.append([Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48.0,height,true,true])
 var identical:=0
 for a:Array in anchors:
  var before:Dictionary=old.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var after:Dictionary=current.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  assert(var_to_bytes(before.faces)==var_to_bytes(after.faces))
  assert(var_to_bytes(before.green)==var_to_bytes(after.green))
  identical+=1
 print("CACHE_EXACT_GEOMETRY formations=",identical)
 quit()
