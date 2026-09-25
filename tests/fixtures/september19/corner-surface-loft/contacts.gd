extends SceneTree
func _initialize()->void:
 var root:="res://docs/qa/2026-09-19-manual/102-corner-surface-loft/shoulder"
 var before:Array=FileAccess.open(root.path_join("before-forms.bin"),FileAccess.READ).get_var()
 var after:Array=FileAccess.open(root.path_join("after-forms.bin"),FileAccess.READ).get_var()
 for form:Dictionary in after:
  if form.replay_recipe.kind!="study_loft":continue
  var triangles:int=form.green.size()/3
  for fraction:float in [.15,.3,.5,.7,.85]:
   var i:=int(triangles*fraction)*3
   var point:Vector3=form.transform*((form.green[i]+form.green[i+1]+form.green[i+2])/3)
   var old:=height(before,point+Vector3.UP*.1)
   var new:=height(after,point+Vector3.UP*.1)
   print("PROBE ",point," before=",old," after=",new," delta=",point.y-old)
 quit()
static func height(forms:Array,origin:Vector3)->float:
 var best:=-INF
 for form:Dictionary in forms:
  var pose:Transform3D=form.transform
  var local:Vector3=pose.affine_inverse()*origin
  var faces:PackedVector3Array=form.faces
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(local,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
   if hit!=null:best=maxf(best,(pose*hit).y)
 return best
