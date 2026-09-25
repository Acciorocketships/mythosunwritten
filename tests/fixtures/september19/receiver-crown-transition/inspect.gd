extends SceneTree
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
const SURFACE=preload("res://scripts/terrain/field/CliffInnerSurface.gd")
func _init()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/103-receiver-crown-transition/study/before-forms.bin",FileAccess.READ).get_var()
 for form:Dictionary in forms:
  if minf(form.transform.origin.distance_to(Vector3(-445.5,28,-267)),form.transform.origin.distance_to(Vector3(-445.5,32,-289.5)))>.01:continue
  print("WALL ",form.transform.origin," ",form.replay_recipe)
  for z:float in [-273,-275,-277.5,-279,-282,-284]:
   var x:float=(form.transform.affine_inverse()*Vector3(-445.5,form.transform.origin.y,z)).x
   if absf(x)>float(form.replay_recipe.width)*.5:continue
   print("at ",z," x ",x," treads ",LEDGES.nearest_row(LEDGES.columns(form),x))
 quit()
