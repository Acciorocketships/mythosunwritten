extends SceneTree
func _initialize()->void:
 var g=preload("res://tests/fixtures/september18/cliff-widening-shoulders/fan.gd")
 g.prepare()
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[9]
 var pose:Transform3D=a[0]
 var coordinate:=pose.origin.dot(pose.basis.x)
 var salt:=2697992464+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
 print("SOURCE_ANCHOR ",a," coordinate=",coordinate," salt=",salt)
 for x:float in [5.5,5.75,5.9,5.95,6.0,6.25]:
  var u:=coordinate+x
  var cuts:Array=g._structural_terraces(u,a[2],salt)
  print("CUTS x=",x," value=",cuts)
 quit()
