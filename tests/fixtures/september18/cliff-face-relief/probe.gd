extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for index in [11,20]:
  var a:Array=anchors[index];var form:Dictionary=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var points:Dictionary={}
  for p:Vector3 in form.faces:
   if p.z>0 and p.y>1 and p.y<a[2]-2:points[p]=true
  print("ANCHOR ",index," width=",a[1]," height=",a[2]," pose=",a[0])
  var rows:Array=[]
  for x in range(ceili(-a[1]*.5)+2,floori(a[1]*.5)-2,2):
   for y in range(2,floori(a[2])-3,2):
    var pts:Array[Vector3]=[]
    for p:Vector3 in points:
     if absf(p.x-x)<=1.5 and absf(p.y-y)<=1.5:pts.append(p)
    if pts.size()<50:continue
    var xx:=Vector3.ZERO;var xy:=Vector3.ZERO;var xz:=Vector3.ZERO;var rhs:=Vector3.ZERO
    for p:Vector3 in pts:
     var v:=Vector3(p.x-x,p.y-y,1)
     xx+=v*v.x;xy+=v*v.y;xz+=v;rhs+=v*p.z
    var mat:=Basis(xx,xy,xz)
    if absf(mat.determinant())<.0001:continue
    var fit:=mat.inverse()*rhs;var sum:=0.0;var maximum:=0.0
    for p:Vector3 in pts:
     var err:=absf(p.z-fit.dot(Vector3(p.x-x,p.y-y,1)));sum+=err*err;maximum=maxf(maximum,err)
    rows.append([x,y,sqrt(sum/pts.size()),maximum,pts.size()])
  rows.sort_custom(func(a,b):return a[2]<b[2])
  print("FACE_PLANES ",rows.slice(0,12))
  if index==20:
   var found:=false
   for row:Array in rows:
    if row[0]==-8 and row[1]==4:
     found=true
     print("PINNED_FACE ",row)
     if row[2]<.075:
      print("RED: photographed broad face remains within 7.5 cm RMS of a single plane")
      quit(1);return
   if not found:
    print("MISSING PINNED FACE");quit(2);return
 quit()
