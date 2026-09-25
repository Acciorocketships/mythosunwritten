extends SceneTree
func _initialize()->void:
 var old=load("res://tests/fixtures/september17/cliff-oblique-relief/before.gd")
 var current=load("res://tests/fixtures/september17/cliff-oblique-relief/planes.gd")
 old.prepare();current.prepare()
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for index in [0,1,1,0]:
  var g=old if index==0 else current
  var start:=Time.get_ticks_usec();var triangles:=0
  for i in [0,11,20]:
   var a:Array=anchors[i]
   var form:Dictionary=g.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
   triangles+=form.faces.size()/3
  print("GEOMETRY_COST variant=",index," ms=",(Time.get_ticks_usec()-start)/1000.0," triangles=",triangles)
 quit()
