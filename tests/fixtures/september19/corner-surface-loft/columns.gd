extends SceneTree
const LOFT=preload("res://tests/fixtures/september19/corner-surface-loft/loft.gd")
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
func _initialize()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/101-short-corner-runs/before/before-forms.bin",FileAccess.READ).get_var()
 for form:Dictionary in forms:
  if form.transform.origin.distance_to(Vector3(-421.5,28,-334.5))>.01:continue
  var rows:=LEDGES.columns(form)
  for i in range(26,43):
   var x:=i*.25;var section:=LOFT.section(form,Vector3(x,0,0),4.0)
   print("X=",x," actual=",rows.get(x,[])," nearest=",LEDGES.nearest_row(rows,x)," section=",section)
 quit()
