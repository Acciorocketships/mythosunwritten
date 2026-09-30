extends RefCounted
func run(review:Node3D)->void:
 var include:=load("res://terrain/materials/slope_green.gdshaderinc") as ShaderInclude
 include.code=FileAccess.get_file_as_string("res://terrain/materials/slope_green.gdshaderinc")
 review._reload_scripts()
 for view:Dictionary in [
  {"id":"missing-wall","position":Vector3(511,40,932),"target":Vector3(524,30,948),"fov":65.0},
  {"id":"crest","position":Vector3(504,44,940),"target":Vector3(510,36,954),"fov":65.0},
  {"id":"strip","position":Vector3(485,58,944),"target":Vector3(497,39,954),"fov":60.0},
  {"id":"grass-ledge","position":Vector3(496,47,960),"target":Vector3(499,40,967),"fov":55.0},
  {"id":"rock-face","position":Vector3(541,38,960),"target":Vector3(542,36,973),"fov":60.0},
  {"id":"wall-overview","position":Vector3(511,44,928),"target":Vector3(524,30,948),"fov":65.0}]:
  if not review._views.any(func(v:Dictionary)->bool:return v.id==view.id):review._views.append(view)
 var views:Array=review._views.duplicate()
 var keys:Array=review._streamer._built.keys()
 for key:Vector2i in keys:
  review._views.append({"id":"rebuild-only","target":Vector3(key.x*192+84,30,key.y*192+84)})
 await review._rebuild_full()
 review._views.assign(views)
 # The wider rock now occupies the old close camera; lift the detail view
 # above the surface. Keep the matched P03/crest/wall-overview cameras.
 for view:Dictionary in review._views:
  if view.id=="strip":view.position=Vector3(485,58,944)
  if view.id=="missing-wall":view.position=Vector3(511,40,932)
 await review._capture_all(23)
 await review._grass_at(review._views[0].player)
 review._camera.look_at_from_position(review._views[0].position,review._views[0].target,Vector3.UP)
 review._camera.fov=review._views[0].fov
 for path:String in ["res://tests/harness/cliff_p03_audit.gd","res://tests/harness/cliff_p03_surface_audit.gd","res://tests/harness/cliff_p03_verify.gd","res://tests/harness/cliff_p03_normals.gd"]:
  var script:=GDScript.new()
  script.source_code=FileAccess.get_file_as_string(path)
  assert(script.reload()==OK)
  await script.new().run(review)
 print("[p03_full_review] rebuilt ",keys.size()," chunks")
