extends SceneTree
func _initialize()->void:
 var path:="res://docs/qa/2026-09-19-manual/100-corner-edge-profiles/shared-edges/"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):path=arg.trim_prefix("--output=")+"/"
 var before:Array=FileAccess.open(path+"before-forms.bin",FileAccess.READ).get_var()
 var after:Array=FileAccess.open(path+"after-forms.bin",FileAccess.READ).get_var()
 var changed:=0;var degenerate:=0;var bad_edges:=0;var outward:=0;var turf_missing:=0
 for n in before.size():
  var a:Dictionary=before[n];var b:Dictionary=after[n]
  if a.faces==b.faces:continue
  changed+=1
  var bounds:=AABB(a.faces[0],Vector3.ZERO)
  for p:Vector3 in a.faces:bounds=bounds.expand(p)
  bounds=bounds.grow(.0001)
  var edges:Dictionary={};var tris:Dictionary={}
  for i in range(0,b.faces.size(),3):
   var p:Vector3=b.faces[i];var q:Vector3=b.faces[i+1];var r:Vector3=b.faces[i+2]
   if (r-p).cross(q-p).length_squared()<1e-14:degenerate+=1
   tris[[p,q,r]]=true
   for j in 3:
    p=b.faces[i+j];q=b.faces[i+(j+1)%3]
    var edge:Array=[p,q] if p<q else [q,p]
    edges[edge]=edges.get(edge,0)+1
    if not bounds.has_point(b.faces[i+j]):outward+=1
  for count:int in edges.values():
   if count!=2:bad_edges+=1
  for i in range(0,b.green.size(),3):
   if not tris.has([b.green[i],b.green[i+1],b.green[i+2]]):turf_missing+=1
 var report:={"changed":changed,"degenerate":degenerate,"nonmanifold_edges":bad_edges,"vertices_outside_original_bounds":outward,"missing_turf_triangles":turf_missing}
 FileAccess.open(path+"structure.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if degenerate==0 and bad_edges==0 and turf_missing==0 and outward==0 else 1)
