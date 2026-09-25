extends SceneTree
func _initialize()->void:
 for name:String in ["before","candidate"]:
  var generator=load("res://tests/fixtures/september17/cliff-tall-curves/"+name+".gd")
  var form:Dictionary=generator.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,64,2697992464)[0]
  var rows:Dictionary={}
  for p:Vector3 in form.faces:
   if p.y<8 or p.y>56 or absf(p.y/4.0-roundf(p.y/4.0))>.0001:continue
   var y:=roundi(p.y);var x:=roundi(p.x*4)
   if not rows.has(y):rows[y]={}
   rows[y][x]=maxf(rows[y].get(x,-INF),p.z)
  var diffs:Array=[]
  for y in range(8,49,4):
   var a:Array=[];var b:Array=[]
   for x in range(-80,81,4):
    if rows[y].has(x) and rows[y+8].has(x):a.append(rows[y][x]);b.append(rows[y+8][x])
   var ma:=0.0;var mb:=0.0
   for i in a.size():ma+=a[i]/a.size();mb+=b[i]/b.size()
   var difference:=0.0
   for i in a.size():difference+=pow((a[i]-ma)-(b[i]-mb),2)/a.size()
   diffs.append(sqrt(difference))
  print(name," shape_changes=",diffs)
 quit()
