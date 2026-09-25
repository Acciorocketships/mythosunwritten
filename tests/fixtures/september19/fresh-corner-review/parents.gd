extends SceneTree
func _initialize()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin",FileAccess.READ).get_var()
 for corner:Dictionary in forms:
  if corner.replay_recipe.kind!="inner_corner":continue
  print("CORNER ",corner.anchor," height=",corner.replay_recipe.height)
  for form:Dictionary in forms:
   if form.replay_recipe.kind!="wall":continue
   var local:Transform3D=corner.transform.affine_inverse()*form.transform
   var normal:Vector3=local.basis.z
   if not ((normal.dot(Vector3.BACK)>.99 and absf(local.origin.z)<.01) or (normal.dot(Vector3.RIGHT)>.99 and absf(local.origin.x)<.01)):continue
   var relative:Vector3=form.transform.affine_inverse()*corner.transform.origin
   if absf(absf(relative.x)-form.replay_recipe.width*.5)>2.0:continue
   print("PARENT ",form.id," pose=",local," recipe=",form.replay_recipe)
 quit()
