extends SceneTree
func _initialize()->void:
 preload("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
 var saved:Dictionary=FileAccess.open("res://tests/fixtures/september26-cliffs/photo11-envelope.var",FileAccess.READ).get_var()
 var env=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd").new()
 for key:String in saved:env.set(key,saved[key])
 var area:=Rect2(296,768,8,8)
 var originals:={}
 for variant:String in ["original","repair"]:
  var result:Dictionary
  if variant=="original":
   result=FileAccess.open("res://tests/fixtures/september26-cliffs/photo11-original-mesh.var",FileAccess.READ).get_var()
  else:
   var field=preload("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,null,area)
   field._env=env
   var mesh:Dictionary=field.solid(area)[0]
   result={"faces":mesh.faces,"roots":mesh.native_roots}
  var faces:PackedVector3Array=result.faces
  var edges:={};var points:={}
  for i in range(0,faces.size(),3):
   for j in 3:
    var a:=faces[i+j];var b:=faces[i+(j+1)%3]
    var key:=[a,b] if a<b else [b,a]
    if not edges.has(key):edges[key]=[]
    edges[key].append(1 if a<b else -1)
    points[a]=true
  var bad:=0;var open:=0
  for key:Array in edges:
   var v:Array=edges[key]
   if v.size()==2 and v[0]==v[1]:bad+=1
   if v.size()==1:open+=1
  if variant=="original":originals=points
  var common:=0
  for point:Vector3 in points:
   if originals.has(point):common+=1
  var missing:=[]
  for x in range(297,304):
   for z in range(769,776):
    var hit:=false
    for i in range(0,faces.size(),3):
     if Geometry3D.ray_intersects_triangle(Vector3(x+.2,100,z+.2),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])!=null:hit=true;break
    if not hit:missing.append(Vector2(x+.2,z+.2))
  print(variant," retained=",common," missing=",missing)
  print(variant," triangles=",faces.size()/3," inconsistent=",bad," open=",open," points=",points.size())
  FileAccess.open("res://docs/qa/2026-09-26-cliff-style-restoration/probe-%s.var"%variant,FileAccess.WRITE).store_var({"area":area,"faces":faces,"roots":result.roots})
 quit()
