extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/126-bank-relief"
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:
 ROCKS.prepare()
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/all-banks.bin",FileAccess.READ).get_var()
 var records:Array=[]
 for bank:Dictionary in banks:
  if bank.anchor.distance_to(Vector3(-466.5,8,240))>.1:continue
  var bins:Dictionary={};var unique:Dictionary={}
  for i in bank.faces.size():
   var source:Vector3=bank.shore_source_faces[i];var fitted:Vector3=bank.faces[i]
   if unique.has(source):continue
   unique[source]=true
   var y:=floori(source.y+bank.transform.origin.y)
   var depth:float=ROCKS.CRAGS._native_depth(bank.transform.origin.dot(bank.transform.basis.x)+source.x,source.y)
   if not bins.has(y):bins[y]={"y":y,"count":0,"source_exposed":0,"fitted_exposed":0,"source_max":-INF,"fitted_max":-INF,"source_min":INF,"fitted_min":INF}
   var row:Dictionary=bins[y];row.count+=1
   if source.z>depth+.05:row.source_exposed+=1
   if fitted.z>depth+.05:row.fitted_exposed+=1
   row.source_max=maxf(row.source_max,source.z-depth);row.fitted_max=maxf(row.fitted_max,fitted.z-depth)
   row.source_min=minf(row.source_min,source.z-depth);row.fitted_min=minf(row.fitted_min,fitted.z-depth)
  records.append({"anchor":bank.anchor,"top":bank.top,"level":bank.replay_recipe.shore_level,"bins":bins})
 FileAccess.open(OUT.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
 print(records);quit()
