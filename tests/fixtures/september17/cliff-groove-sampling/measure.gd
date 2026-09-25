extends SceneTree
## Bounded mesh-cost comparison; wall-clock values are local, not game timings.
func _initialize()->void:
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for variant:String in ["res://scripts/terrain/field/CliffRockCrags.gd","res://tests/fixtures/september17/cliff-detail-options/grooves-refined.gd","res://tests/fixtures/september17/cliff-groove-sampling/efficient.gd"]:
  var generator:GDScript=load(variant)
  generator.prepare()
  var triangles:=0
  var started:=Time.get_ticks_usec()
  for index:int in [0,11,20]:
   var a:Array=anchors[index]
   var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
   triangles+=form.faces.size()/3
  print("GROOVE_MESH path=",variant," triangles=",triangles," generation_ms=",(Time.get_ticks_usec()-started)/1000.0)
 quit()
