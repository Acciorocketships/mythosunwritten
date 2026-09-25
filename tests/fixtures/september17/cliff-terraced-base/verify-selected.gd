extends SceneTree
func _initialize()->void:
 var current=preload("res://scripts/terrain/field/CliffRockCrags.gd")
 var candidate=preload("res://tests/fixtures/september17/cliff-terraced-base/restrained.gd")
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for a:Array in anchors:
  var p:Dictionary=current.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  var q:Dictionary=candidate.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
  assert(p.faces==q.faces and p.green==q.green)
 print("SELECTED_GEOMETRY 31 photographed formations identical to rendered candidate")
 quit()
