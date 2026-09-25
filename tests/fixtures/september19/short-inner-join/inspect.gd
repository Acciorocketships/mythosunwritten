extends SceneTree
func _init()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin",FileAccess.READ).get_var()
 var corner:=Vector3(-421.5,28,-349.5)
 for f:Dictionary in forms:
  if Vector2(f.anchor.x-corner.x,f.anchor.z-corner.z).length()<35:
   print(f.id," pose=",f.transform," recipe=",f.replay_recipe)
 quit()
