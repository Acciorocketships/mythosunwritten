extends SceneTree
func _initialize()->void:
 call_deferred("run")
func run()->void:
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var raw=load("res://tests/fixtures/september18/cliff-relief-transitions/unshaped.gd").make(pose,48,32,2697992464)[0].faces
 for name:String in ["before","candidate"]:
  var faces=load("res://tests/fixtures/september18/cliff-relief-transitions/"+name+".gd").make(pose,48,32,2697992464)[0].faces
  var sharp:=0;var maximum:=0.0;var edges:Dictionary={};var worst:Array=[]
  for i in range(0,faces.size(),3):
   for j in 3:
    var a:Vector3=raw[i+j];var b:Vector3=raw[i+(j+1)%3]
    if a.z<=0 or b.z<=0 or absf(a.x-b.x)<.1 or absf(a.x-b.x)>.26 or absf(a.y-b.y)>.21:continue
    var key:Array=[a,b] if a.x<b.x else [b,a]
    if edges.has(key):continue
    edges[key]=true
    var change:float=absf((faces[i+j].z-a.z)-(faces[i+(j+1)%3].z-b.z))
    maximum=maxf(maximum,change)
    if change>.15:sharp+=1
    if change>.3:worst.append([a,b,change])
  print("RELIEF_TRANSITION ",name," edges=",edges.size()," sharp=",sharp," maximum=",maximum," worst=",worst.slice(0,8))
 quit()
