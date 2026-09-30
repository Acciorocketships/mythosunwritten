extends RefCounted
func run(review:Node3D)->void:
 review._reload_scripts()
 var views:Array=review._views.duplicate()
 if review.get_meta("all_chunks",false):
  for key:Vector2i in review._streamer._built:
   review._views.append({"id":"rebuild-only","target":Vector3(key.x*192+84,30,key.y*192+84)})
 await review._rebuild_full()
 review._views.assign(views)
 await review._capture_all(int(review.get_meta("iteration",3)))
 await review._grass_at(review._views[0].player)
 review._camera.look_at_from_position(review._views[0].position,review._views[0].target,Vector3.UP)
 review._camera.fov=review._views[0].fov
 for path:String in ["res://tests/harness/cliff_p03_audit.gd","res://tests/harness/cliff_p03_surface_audit.gd","res://tests/harness/cliff_p03_verify.gd","res://tests/harness/cliff_p03_normals.gd"]:
  var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path);assert(script.reload()==OK)
  if path.ends_with("cliff_p03_audit.gd"):await script.new().run(review,"after")
  else:await script.new().run(review)
 print("[continuity_rebuild] finished")
