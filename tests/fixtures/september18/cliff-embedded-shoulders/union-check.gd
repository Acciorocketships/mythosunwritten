extends SceneTree
func _initialize()->void:
 var prefix:="moss-" if "--moss" in OS.get_cmdline_user_args() else ""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--prefix="):prefix=arg.trim_prefix("--prefix=")
 var welded:="welded-" if "--welded" in OS.get_cmdline_user_args() else ""
 var faces:PackedVector3Array=FileAccess.open("res://tests/fixtures/september18/cliff-embedded-shoulders/"+prefix+"union-"+welded+"faces.bin",FileAccess.READ).get_var()
 var edges:Dictionary={};var degenerate:=0;var volume:=0.0
 for i in range(0,faces.size(),3):
  var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
  if (c-a).cross(b-a).length()<.0000001:
   degenerate+=1;print("SLIVER ",a," ",b," ",c," area2=",(c-a).cross(b-a).length()," edges=",[a.distance_to(b),b.distance_to(c),c.distance_to(a)])
  volume+=a.dot(b.cross(c))/6
  for j in 3:
   var p:=faces[i+j].snapped(Vector3.ONE*.00001);var q:=faces[i+(j+1)%3].snapped(Vector3.ONE*.00001)
   var key:Array=[p,q] if p<q else [q,p]
   edges[key]=edges.get(key,0)+1
 var bad:=0
 for value:int in edges.values():
  if value!=2:bad+=1
 var data:Dictionary={"triangles":faces.size()/3,"bad_edges_at_1e5":bad,"degenerate":degenerate,"signed_volume":volume}
 print("EXACT_UNION_CHECK ",JSON.stringify(data))
 FileAccess.open("res://docs/qa/2026-09-18-manual/75-cliff-embedded-shoulders/"+prefix+"union-"+welded+"check.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
 quit(1 if bad>0 or degenerate>0 or volume>=0 else 0)
