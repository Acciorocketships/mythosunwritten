extends SceneTree
func _initialize()->void:
 var generator=load("res://tests/fixtures/september17/cliff-ledge-channels/ordered-diagnostic.gd")
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/P05/poses.json"))[0]
 var numbers:=RegEx.new();numbers.compile("-?[0-9]+(?:\\.[0-9]+)?")
 var values:Array[float]=[]
 for m in numbers.search_all(record.camera):values.append(float(m.get_string()))
 var camera:=Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
 var forms:Array=[]
 for a:Array in anchors:forms.append(generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0])
 for pixel:Vector2 in [Vector2(1139,781),Vector2(1160,796),Vector2(1190,786)]:
  var q:=Vector2(pixel.x/800-1,1-pixel.y/500)*tan(deg_to_rad(record.fov)*.5)
  var direction:=camera.basis*Vector3(q.x*1.6,q.y,-1).normalized()
  var hit_triangle:Array=[]
  var nearest:=INF;var selected:=-1;var local:=Vector3.ZERO
  for index in forms.size():
   var form:Dictionary=forms[index];var inverse:Transform3D=form.transform.affine_inverse()
   var origin:Vector3=inverse*camera.origin;var ray:Vector3=inverse.basis*direction
   var faces:PackedVector3Array=form.faces
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
    if hit!=null and hit.distance_to(origin)<nearest:
     nearest=hit.distance_to(origin);selected=index;local=hit;hit_triangle=[faces[i],faces[i+1],faces[i+2]]
  print("LEDGE_PIXEL pixel=",pixel," anchor=",selected," local=",local)
  if selected<0:continue
  var column:=roundi((local.x+anchors[selected][1]*.5)/.25)
  print("TRIANGLE=",hit_triangle)
  print("POSE=",anchors[selected]," column=",column," cuts=",forms[selected].diagnostic_cuts[column])
 quit()
