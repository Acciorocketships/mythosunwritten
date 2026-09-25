extends SceneTree
func _rows(data:Dictionary)->Dictionary:
 var out:Dictionary={}
 for asset:StringName in data.batches:
  var batch:Dictionary=data.batches[asset]
  for i in batch.ids.size():out[batch.ids[i]]=[asset,batch.transforms[i],batch.colors[i],batch.collision_enabled[i]]
 return out
func _init()->void:
 var folder:="res://docs/qa/2026-09-19-manual/91-masonry-joints/payloads/"
 var before:Dictionary=FileAccess.open(folder+"before-payload.bin",FileAccess.READ).get_var()
 var after:Dictionary=FileAccess.open(folder+"after-payload.bin",FileAccess.READ).get_var()
 var a:=_rows(before);var b:=_rows(after)
 var removed:Array=[];var changed:Array=[];var added:Array=[]
 for id:StringName in a:
  if not b.has(id):removed.append(id)
  elif a[id]!=b[id]:changed.append(id)
 for id:StringName in b:
  if not a.has(id):added.append(id)
 var report:={"before_instances":a.size(),"after_instances":b.size(),"removed":removed,"changed":changed,"added":added,"same_walked":before.walked==after.walked,"same_surfaces":before.surface_meshes==after.surface_meshes,"same_collision_boxes":before.collision_boxes==after.collision_boxes}
 print(JSON.stringify(report))
 FileAccess.open(folder+"difference.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 assert(removed.is_empty() and added.is_empty())
 assert(changed.size()==9)
 for id:StringName in changed:
  assert(String(id).begins_with("masonry-joint/"))
  assert(a[id][0]==&"sfv.deck.pillar.001" and b[id][0]==&"sfv.fabric.wall.rock.retaining.001")
  assert(a[id][3]==b[id][3])
 assert(report.same_walked and report.same_surfaces and report.same_collision_boxes)
 quit()
