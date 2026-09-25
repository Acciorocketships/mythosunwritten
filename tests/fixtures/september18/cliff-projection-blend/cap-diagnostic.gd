extends GutTest
func test_merged_cap_has_no_stone_channel_across_its_interior()->void:
 # Follow the actual tread between the same three reported wall columns.
 # A new rock silhouette may relocate it in depth; fixed old-depth rays then
 # test empty air. Interior coverage still reproduces the historical defect.
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
 var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var samples:=0;var covered:=0
 for x:float in [5.05,5.125,5.2]:
  var near:=INF;var far:=-INF
  var faces:PackedVector3Array=form.faces
  for i in range(0,faces.size(),3):
   var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
   if normal.y<.8:continue
   for j in 3:
    var p:=faces[i+j];var q:=faces[i+(j+1)%3]
    if absf(p.x-q.x)<.00001 or x<minf(p.x,q.x) or x>maxf(p.x,q.x):continue
    var hit:=p.lerp(q,(x-p.x)/(q.x-p.x))
    if hit.y<=2.0 or hit.y>3.5 or hit.z<.4:continue
    near=minf(near,hit.z);far=maxf(far,hit.z)
  print("CAP_INTERVAL x=",x," near=",near," far=",far)
  if far-near<.55:continue
  for step in 19:
   var z:=lerpf(near,far,float(step+1)/20)
   var origin:=Vector3(x,3.5,z);var shell:=-INF;var turf:=-INF;var hit_normal:=Vector3.ZERO;var hit_tri:=[]
   for type:String in ["faces","green"]:
    var triangles:PackedVector3Array=form[type]
    for i in range(0,triangles.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,triangles[i],triangles[i+1],triangles[i+2])
     if hit==null:continue
     if type=="faces" and hit.y>shell:
      shell=hit.y;hit_normal=(triangles[i+2]-triangles[i]).cross(triangles[i+1]-triangles[i]).normalized();hit_tri=[triangles[i],triangles[i+1],triangles[i+2]]
     else:turf=maxf(turf,hit.y)
   if shell>2.0 and absf(turf-shell)>.0001:print("MISSING_TURF origin=",origin," shell=",shell," normal=",hit_normal," triangle=",hit_tri)
   if shell>2.0:samples+=1
   if shell>2.0 and absf(turf-shell)<.0001:covered+=1
 print("CAP_INTERVAL_RESULT samples=",samples," covered=",covered)
 assert_eq(samples,57,"The complete reported shelf remains physically present")
 assert_eq(covered,samples,"The full tread must remain turf without interior stone channels")
