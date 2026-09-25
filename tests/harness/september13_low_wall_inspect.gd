extends SceneTree
func _init() -> void:
 var name := "after" if "--after" in OS.get_cmdline_user_args() else "before"
 var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/10-low-wall/%s-payload.bin" % name,FileAccess.READ).get_var()
 var catalog := EnvironmentCatalog.load_default()
 var target := Vector3(-195.4,12.1,-953.9)
 var result := []
 for asset: StringName in data.batches:
  var batch: Dictionary = data.batches[asset]
  for index in batch.transforms.size():
   var transform: Transform3D = data.transform * batch.transforms[index]
   var box: AABB = transform * catalog.descriptor(asset).measured_aabb
   if not box.grow(1.5).has_point(target): continue
   result.append({"asset":asset,"id":batch.ids[index],"box":str(box),"transform":str(transform)})
 FileAccess.open("res://docs/qa/2026-09-13-manual/10-low-wall/nearby-%s.json" % name,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit()
