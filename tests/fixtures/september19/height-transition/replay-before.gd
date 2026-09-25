extends RefCounted
## Rebuild a saved cliff visual with its construction identity and rooted floor.
## Legacy snapshots predate recipes; only the two known backing shapes migrate.
static func rebuild(pose:Transform3D,faces:PackedVector3Array,recipe:Dictionary,wall:GDScript,corner:GDScript)->Dictionary:
 var box:=_bounds(faces)
 if recipe.is_empty():recipe=_legacy_recipe(faces,box)
 var seed_value:int=recipe.get("seed",2697992464)
 var result:Dictionary
 if recipe.kind=="inner_corner":
  result=corner.make_inner(pose,recipe.height,seed_value)
 elif recipe.kind=="corner":
  result=corner.make(pose,recipe.height,seed_value)
 else:
  assert(recipe.kind=="wall","Unknown cliff snapshot construction")
  if recipe.has("ledge_joins"):
   result=wall.make(pose,recipe.width,recipe.height,seed_value,null,recipe.left_end,recipe.right_end,recipe.ledge_joins)[0]
  else:
   result=wall.make(pose,recipe.width,recipe.height,seed_value,null,recipe.left_end,recipe.right_end)[0]
 if recipe.has("inner_connections"):result.replay_recipe["inner_connections"]=recipe.inner_connections.duplicate()
 _restore_floor(result,box.position.y)
 return result

static func _bounds(faces:PackedVector3Array)->AABB:
 assert(not faces.is_empty())
 var box:=AABB(faces[0],Vector3.ZERO)
 for point:Vector3 in faces:box=box.expand(point)
 return box

static func _legacy_recipe(faces:PackedVector3Array,box:AABB)->Dictionary:
 # Native panels consist of complete 4 m storeys. Float32 AABB expansion can
 # turn a 4 m crown into 3.99999976 and change sampling rows on reconstruction.
 var height:=snappedf(box.end.y,4.0)
 assert(absf(height-box.end.y)<.001,"Legacy cliff height is not a native storey multiple")
 # Convex corner arms finish at local x/z=-6. A straight face instead closes
 # against z=-1.2 and has a symmetric x range. Never interpret a corner's
 # asymmetric projected width as a new straight-wall width.
 if absf(box.position.x+6.0)<.001 and absf(box.position.z+6.0)<.001:
  return {"kind":"corner","height":height}
 assert(absf(box.position.z+1.2)<.001 and absf(box.position.x+box.end.x)<.001,"Unrecognized legacy cliff backing; capture a new snapshot with relief_recipe")
 var left:=-INF;var right:=-INF
 for point:Vector3 in faces:
  if absf(point.x-box.position.x)<.001:left=maxf(left,point.z)
  if absf(point.x-box.end.x)<.001:right=maxf(right,point.z)
 return {"kind":"wall","width":box.size.x,"height":height,"left_end":left<-.49,"right_end":right<-.49}

static func _restore_floor(form:Dictionary,floor_y:float)->void:
 # The replay has no live heightfield. Preserve the saved foot burial rather
 # than lifting a previously seated corner back to its nominal datum.
 var old_floor:=_bounds(form.faces).position.y
 if absf(old_floor-floor_y)<.0001:return
 for channel:String in ["faces","green"]:
  var values:PackedVector3Array=form[channel]
  for i in values.size():
   var old:Vector3=values[i]
   if absf(old.y-old_floor)>.001:continue
   var point:=Vector3(old.x,floor_y,old.z)
   if form.has("native_roots") and form.native_roots.has(old):
    form.native_roots[point]=form.native_roots[old];form.native_roots.erase(old)
   values[i]=point
  form[channel]=values
 form.bounds=form.transform*_bounds(form.faces)
 form.base=form.bounds.position.y
