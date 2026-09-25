extends SceneTree
func _initialize()->void:
 var root:="res://docs/qa/2026-09-19-manual/102-corner-surface-loft"
 var results:Dictionary={}
 for variant:String in ["loft","semantic","tread","tangent","collar"]:
  var path:=root.path_join(variant).path_join("after-forms.bin")
  if not FileAccess.file_exists(path):continue
  var forms:Array=FileAccess.open(path,FileAccess.READ).get_var()
  for form:Dictionary in forms:
   if form.replay_recipe.kind!="study_loft":continue
   var edges:Dictionary={};var degenerate:=0;var min_area:=INF
   for i in range(0,form.faces.size(),3):
    var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
    var area:float=(b-a).cross(c-a).length()*.5
    min_area=minf(min_area,area)
    if area<.00000001:degenerate+=1
    for j in 3:
     var edge:Array=[form.faces[i+j],form.faces[i+(j+1)%3]];edge.sort();edges[edge]=edges.get(edge,0)+1
   var counts:Dictionary={}
   for count:int in edges.values():counts[count]=counts.get(count,0)+1
   results[variant]={"triangles":form.faces.size()/3,"edge_incidence":counts,"degenerate":degenerate,"minimum_area":min_area,"green_triangles":form.green.size()/3}
 FileAccess.open(root.path_join("geometry-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 print(JSON.stringify(results));quit()
