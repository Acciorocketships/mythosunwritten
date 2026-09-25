extends SceneTree
const LOFT=preload("res://tests/fixtures/september19/corner-surface-loft/loft.gd")
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
func _initialize()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/101-short-corner-runs/before/before-forms.bin",FileAccess.READ).get_var()
 var anchor:=Vector3(-421.5,28,-349.5);var report:Array=[]
 for form:Dictionary in forms:
  var point:Vector3
  if form.transform.origin.distance_to(Vector3(-421.5,28,-334.5))<.01:point=anchor+Vector3(0,0,6.5)
  elif form.transform.origin.distance_to(Vector3(-414,28,-349.5))<.01:point=anchor+Vector3(9.5,0,0)
  else:continue
  var local:Vector3=form.transform.affine_inverse()*point
  var section:=LOFT.section(form,local,4)
  var rows:=LEDGES.columns(form)
  report.append({"pose":str(form.transform),"local":str(local),"section":str(section),"ledges":str(LEDGES.nearest_row(rows,local.x))})
 FileAccess.open("res://docs/qa/2026-09-19-manual/102-corner-surface-loft/profiles.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit()
