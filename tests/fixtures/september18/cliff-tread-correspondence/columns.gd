extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var source=load("res://tests/fixtures/september18/cliff-tread-correspondence/debug.gd")
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[9]
 source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])
 print("ANCHOR ",a)
 for ix in source.debug_columns.size():
  var c:PackedVector3Array=source.debug_columns[ix]
  if c[0].x<2 or c[0].x>3:continue
  print("COLUMN ",c[0].x)
  for i in c.size():
   if c[i].y<4.4 or c[i].y>6:continue
   var tags:Array=[]
   for b:Array in source.debug_bands[ix]:
    if b[2] and i>=b[0] and i<=b[1]:tags.append(b)
   print(i," ",c[i]," raw=",source.debug_raw[ix][i]," ",tags)
 quit()
