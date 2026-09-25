extends GutTest
const JOIN=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
func test_joined_source_drops_only_collapsed_triangles()->void:
 var forms:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/banks.bin",FileAccess.READ).get_var()
 var form:Dictionary={}
 for f:Dictionary in forms:
  if (f.anchor as Vector3).distance_to(Vector3(-517.5,8,337.5))<.01:form=f.duplicate(true)
 assert_false(form.is_empty())
 form.faces=form.shore_source_faces;form.green=PackedVector3Array()
 var before:=triangles(form.faces)
 assert_eq(before.collapsed,2,"Pin the actual joined source defect, before bank fitting")
 JOIN.apply(form,[])
 var after:=triangles(form.faces)
 assert_eq(after.collapsed,0,"A joined rock must not retain collapsed surface triangles")
 assert_eq(after.solid,before.solid,"Keep every triangle with area exactly unchanged")
 var edges:Dictionary={}
 for tri:Array in after.solid:
  for j in 3:
   var pair:Array=[tri[j],tri[(j+1)%3]];pair.sort();edges[pair]=edges.get(pair,0)+1
 var bad:=0
 for count:int in edges.values():
  if count!=2:bad+=1
 assert_eq(bad,0,"The surviving source has a closed two-sided edge incidence")
func triangles(faces:PackedVector3Array)->Dictionary:
 var collapsed:=0;var solid:Dictionary={}
 for i in range(0,faces.size(),3):
  var a:Vector3=faces[i];var b:Vector3=faces[i+1];var c:Vector3=faces[i+2]
  if a==b or a==c or b==c:collapsed+=1
  else:solid[[a,b,c]]=true
 return {"collapsed":collapsed,"solid":solid}
