extends SceneTree
func _initialize():
 for file in ["before.gd","sculpted.gd"]:
  var source=load("res://tests/fixtures/september18/cliff-weathered-shapes/"+file)
  var a=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
  var f=source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var points:Dictionary={}
  for p:Vector3 in f.faces:
   if p.z<0 or p.y<4 or p.y>10:continue
   var key:=Vector2i(roundi(p.x*4),roundi(p.y*5))
   if absf(p.y-key.y*.2)>.0001:continue
   points[key]=maxf(points.get(key,-INF),p.z)
  var count:=0;var sum:=0.0
  for key:Vector2i in points:
   if key.x< -20 or key.x>12:continue
   if not points.has(key+Vector2i(0,5)) or not points.has(key-Vector2i(0,5)):continue
   sum+=absf(points[key]-(points[key+Vector2i(0,5)]+points[key-Vector2i(0,5)])*.5);count+=1
  print("ACTUAL_FACE ",file," samples=",count," detail=",sum/maxi(1,count))
 quit()
