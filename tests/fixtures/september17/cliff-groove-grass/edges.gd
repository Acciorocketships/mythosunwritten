extends SceneTree
func _init()->void:
 for label:String in ["before","after"]:
  var supports:Array=FileAccess.open("/tmp/cliff42-%s-supports.bin"%label,FileAccess.READ).get_var()
  for p:Vector2 in [Vector2(86.68353,63.52369),Vector2(86.92834,64.40626),Vector2(87.31775,147.5025)]:
   var hit:=GrassSupportSurfaces.at_point(supports,p)
   for s:Dictionary in supports:
    if s.id!=hit.support_id:continue
    var near:=INF;var edge:Array=[]
    for j in range(0,s.border.size(),2):
     var a:Vector2=s.border[j];var b:Vector2=s.border[j+1]
     var t:=clampf((p-a).dot(b-a)/maxf((b-a).length_squared(),.000001),0,1)
     var dist:=p.distance_to(a.lerp(b,t))
     if dist<near:near=dist;edge=[a,b]
    print(label," ",p," border_distance=",near," edge=",edge," total=",hit.edge_distance," face=",s.face)
 quit()
