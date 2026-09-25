extends SceneTree
func _initialize()->void:_run.call_deferred()
func _run()->void:
 var reports:=[]
 for phase:String in ["before","terrace"]:
  var stage:Node3D=load("res://docs/qa/2026-09-18-manual/53-hillside-native/"+phase+"/P21/geometry.scn").instantiate()
  root.add_child(stage)
  await physics_frame
  await physics_frame
  var rows:=[]
  for dz:float in [-12.0,0.0,12.0]:
   for dx:float in [-12.0,0.0,12.0]:
    var p:=Vector2(-1189.9+dx,-609.4+dz)
    var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,160,p.y),Vector3(p.x,-32,p.y))
    var hit:=stage.get_world_3d().direct_space_state.intersect_ray(query)
    var row:Dictionary={"x":p.x,"z":p.y,"ground":hit.position.y if not hit.is_empty() else null}
    rows.append(row)
    print("HILLSIDE_GROUND ",phase," ",JSON.stringify(row))
  reports.append({"phase":phase,"samples":rows})
  stage.free()
  await physics_frame
 FileAccess.open("res://docs/qa/2026-09-18-manual/53-hillside-native/ground.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
 quit()
