extends SceneTree
func _initialize()->void:
 var form:Dictionary
 for f:Dictionary in FileAccess.open("res://docs/qa/2026-09-19-manual/94-stepped-inner-join/candidate/after-forms.bin",FileAccess.READ).get_var():
  if f.id=="worn_crag/(-445.5, 28.0, -265.5)/(1.0, 0.0, -0.0)":form=f
 var gen=load("res://tests/fixtures/september19/inner-shelf-tips/diagnostic.gd")
 gen.prepare();gen.make(form.transform,form.replay_recipe.width,form.replay_recipe.height,2697992464,null,true,false)
 quit()
