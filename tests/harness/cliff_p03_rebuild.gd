extends RefCounted
func run(review:Node3D)->void:
 if not review._views.any(func(v:Dictionary)->bool:return v.id=="wall-overview"):
  review._views.append({"id":"wall-overview","position":Vector3(511,44,928),"target":Vector3(524,30,948),"fov":65.0})
  await review._capture_all(11)
 var include:=load("res://terrain/materials/slope_green.gdshaderinc") as ShaderInclude
 include.code=FileAccess.get_file_as_string("res://terrain/materials/slope_green.gdshaderinc")
 review._reload_scripts()
 await review._rebuild_full()
 await review._capture_all(21)
 await review._grass_at(review._views[0].player)
 review._camera.look_at_from_position(review._views[0].position,review._views[0].target,Vector3.UP)
 review._camera.fov=review._views[0].fov
 await load("res://tests/harness/cliff_p03_audit.gd").new().run(review)
 await load("res://tests/harness/cliff_restoration_audit.gd").new().run(review)
 print("[p03_rebuild] candidate complete")
