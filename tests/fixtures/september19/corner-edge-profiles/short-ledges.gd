extends SceneTree
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
func _initialize()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/section-caps-short/after-forms.bin",FileAccess.READ).get_var()
 var corner:=Vector3(-421.5,28,-349.5);var pair:Array=[];var rows:Array=[]
 for form:Dictionary in forms:
  if corner not in form.replay_recipe.get("inner_connections",[]):continue
  pair.append(form)
  var local:Vector3=form.transform.affine_inverse()*corner
  var sample_x:float=local.x-signf(local.x)*3.0
  var groups:Array=LEDGES.nearest_row(LEDGES.columns(form),sample_x)
  var levels:Array=[]
  for group:Array in groups:levels.append({"average_y":(group[0].y+group[-1].y)*.5,"width":group[-1].x-group[0].x,"profile":str(group)})
  rows.append({"pose":str(form.transform),"recipe":str(form.replay_recipe),"sample_x":sample_x,"groups":levels})
 assert(pair.size()==2)
 var report:={"parents":rows,"selected_controls":LEDGES.controls(pair,corner)}
 FileAccess.open("res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/short-ledge-levels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit()
