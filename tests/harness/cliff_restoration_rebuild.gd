extends RefCounted
func run(review:Node3D)->void:
 if review._output_dir.ends_with("south"):
  review._views=review._views.filter(func(v:Dictionary)->bool:return v.id!="p03")
 await review._rebuild_full()
 await review._capture_all(91)
 await load("res://tests/harness/cliff_restoration_audit.gd").new().run(review)
