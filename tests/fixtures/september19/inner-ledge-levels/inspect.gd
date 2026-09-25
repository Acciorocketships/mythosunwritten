extends SceneTree
func _init()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/96-inner-shelf-tips/candidate3/after-forms.bin",FileAccess.READ).get_var()
 for form:Dictionary in forms:
  var joins:Array=form.replay_recipe.get("inner_connections",[])
  if joins.is_empty():continue
  for corner:Vector3 in joins:
   var local:Vector3=form.transform.affine_inverse()*corner
   print("FORM ",form.id," corner=",corner," local=",local)
   for distance:float in [1,2,3,4,5]:
    var x:float=local.x-signf(local.x)*distance
    var rows:Dictionary={}
    for p:Vector3 in form.green:
     if absf(p.x-x)<.01:
      var key:=snappedf(p.y,.01)
      if not rows.has(key):rows[key]=[p.z,p.z]
      rows[key][0]=minf(rows[key][0],p.z);rows[key][1]=maxf(rows[key][1],p.z)
    print("  distance=",distance," x=",x," rows=",rows)
 quit()
