extends SceneTree
func _initialize()->void:
 var reports:Array=[]
 for variant:String in ["section","section-caps"]:
  var path:="res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/"+variant+"/after-forms.bin"
  var forms:Array=FileAccess.open(path,FileAccess.READ).get_var()
  var checked:=0;var outside:=0;var degenerate:=0
  for form:Dictionary in forms:
   var recipe:Dictionary=form.replay_recipe
   if recipe.kind!="wall" or not recipe.has("edge_heights"):continue
   var half:float=recipe.width*.5
   for end:float in [-half,half]:
    var side:Array=[];var edges:Dictionary={}
    for i in range(0,form.faces.size(),3):
     var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
     if a.x!=end or b.x!=end or c.x!=end:continue
     var tri:Array=[Vector2(a.z,a.y),Vector2(b.z,b.y),Vector2(c.z,c.y)];side.append(tri)
     for j in 3:
      var edge:Array=[tri[j],tri[(j+1)%3]];edge.sort();edges[edge]=edges.get(edge,0)+1
    if side.is_empty():continue
    var adjacent:Dictionary={}
    for edge:Array in edges:
     if edges[edge]!=1:continue
     for j in 2:
      if not adjacent.has(edge[j]):adjacent[edge[j]]=[]
      adjacent[edge[j]].append(edge[1-j])
    var outline:=PackedVector2Array();var point:Vector2=adjacent.keys()[0];var previous:=Vector2(INF,INF)
    for step in adjacent.size():
     assert(adjacent[point].size()==2)
     outline.append(point)
     var next:Vector2=adjacent[point][0]
     if next==previous:next=adjacent[point][1]
     previous=point;point=next
    assert(point==outline[0])
    for tri:Array in side:
     var a:Vector2=tri[0];var b:Vector2=tri[1];var c:Vector2=tri[2]
     if absf((b-a).cross(c-a))<.0000001:degenerate+=1;continue
     checked+=1
     var escaped:=false
     for weights:Vector3 in [Vector3(.333333,.333333,.333334),Vector3(.8,.1,.1),Vector3(.1,.8,.1),Vector3(.1,.1,.8)]:
      var sample:Vector2=a*weights.x+b*weights.y+c*weights.z
      if not Geometry2D.is_point_in_polygon(sample,outline):escaped=true
     if escaped:outside+=1
  reports.append({"variant":variant,"checked_cap_triangles":checked,"escaped_cap_triangles":outside,"degenerate_caps":degenerate})
 var report:={"cases":reports,"reproduced":reports[0].escaped_cap_triangles>0,"repaired":reports[1].escaped_cap_triangles==0 and reports[1].degenerate_caps==0}
 FileAccess.open("res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/cap-containment.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if report.reproduced and report.repaired else 1)
