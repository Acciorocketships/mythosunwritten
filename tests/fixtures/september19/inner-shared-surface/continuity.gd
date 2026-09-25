extends SceneTree
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const OUT="res://docs/qa/2026-09-19-manual/92-inner-shared-surface/"
func depth(form:Dictionary,world:Vector3,direction:Vector3)->float:
 var inverse:Transform3D=form.transform.affine_inverse()
 var origin:Vector3=inverse*(world+direction*20)
 var ray:Vector3=inverse.basis*(-direction)
 var maximum:=-INF
 for i in range(0,form.faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(origin,ray,form.faces[i],form.faces[i+1],form.faces[i+2])
  if hit!=null:maximum=maxf(maximum,(form.transform*hit-world).dot(direction))
 return maximum
func _init()->void:
 ROCKS.prepare()
 var before:Array=FileAccess.open(OUT+"extended/before-forms.bin",FileAccess.READ).get_var()
 var after:=before.duplicate(true);JOIN.apply(after)
 var rows:Array=[];var old:Dictionary={}
 for f:Dictionary in before:old[f.id]=f
 var baseline:=false
 for arg:String in OS.get_cmdline_user_args():
  if arg=="--before":baseline=true
 var failures:=0
 for form:Dictionary in after:
  if not form.replay_recipe.has("inner_connections"):continue
  var original:Dictionary=old[form.id]
  var corner:Vector3=form.replay_recipe.inner_connections[0]
  var q:Vector3=(original.transform as Transform3D).affine_inverse()*corner
  var side:float=-1 if q.x<0 else 1
  for along:float in [.5,1.0,1.5]:
   for y:float in [1,2,3]:
    var world:Vector3=original.transform*Vector3(side*(original.replay_recipe.width*.5-along),y,0)
    var a:=depth(original,world,original.transform.basis.z)
    var b:=depth(form,world,original.transform.basis.z)
    rows.append({"id":String(form.id),"world":str(world),"before_depth":a,"after_depth":b})
    # At an interior turn, rock bearing continues through the last metre;
    # it must not fade to a bare native wall before reaching the junction.
    if (a if baseline else b)<.5:failures+=1
 var report:={"baseline":baseline,"samples":rows.size(),"failed_bearings":failures,"rows":rows}
 FileAccess.open(OUT+("before-continuity.json" if baseline else "after-continuity.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("JOIN_BEARING samples=",rows.size()," failed=",failures," baseline=",baseline)
 quit(1 if failures>0 else 0)
