extends SceneTree
func _initialize():
 var s=load("res://tests/fixtures/september18/cliff-ledge-grading/probe-source.gd")
 var a=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
 var f=s.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 print("ANCHOR ",a)
 for ix in f.columns.size():
  var c=f.columns[ix]
  if c[0].x < 0 or c[0].x > 6:continue
  for b in f.bands[ix]:
   if not b[2] or c[b[0]].y<1 or c[b[0]].y>3.5:continue
   print("TREAD ",c[b[0]]," / ",c[b[1]]," width ",c[b[1]].z-c[b[0]].z," grade ",(c[b[0]].y-c[b[1]].y)/maxf(.0001,c[b[1]].z-c[b[0]].z))
 quit()
