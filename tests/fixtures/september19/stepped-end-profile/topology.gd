extends SceneTree
func _init()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/104-three-way-surface/raster/before-forms.bin",FileAccess.READ).get_var()
 preload("res://scripts/terrain/field/CliffStepSurface.gd").apply(forms)
 for f:Dictionary in forms:
  if not f.replay_recipe.has("step_surface"):continue
  var edges:Dictionary={};var bad:Array=[]
  for i in range(0,f.faces.size(),3):
   for j in 3:
    var a:Vector3=f.faces[i+j].snapped(Vector3.ONE*.0001);var b:Vector3=f.faces[i+(j+1)%3].snapped(Vector3.ONE*.0001)
    if a==b:continue
    var edge:Array=[a,b];edge.sort();edges[edge]=edges.get(edge,0)+1
  var counts:Dictionary={}
  for edge:Array in edges:
   var count:int=edges[edge];counts[count]=counts.get(count,0)+1
   if count==1 and bad.size()<12:bad.append(edge)
  print("TOPOLOGY ",counts," examples=",bad)
 quit()
