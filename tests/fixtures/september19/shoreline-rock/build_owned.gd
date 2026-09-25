extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned"
const FIT=preload("res://tests/fixtures/september19/shoreline-rock/fit_bank.gd")
const ROCKS=preload("res://tests/fixtures/september19/shoreline-rock/owned_adapter.gd")
func _init()->void:run.call_deferred()
func run()->void:
 ROCKS.prepare()
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 var region:=fields.region(Vector2i(-3,1));var water:=fields.water(Vector2i(-3,1))
 var frozen:Dictionary=FileAccess.open("res://docs/qa/2026-09-19-manual/120-corner-shore/field.bin",FileAccess.READ).get_var()
 var compiled:=ROCKS.compute(region,-24,8,8,2697992464,null,water)
 var banks:Array=compiled.placements.filter(func(p:Dictionary)->bool:return p.get("replay_recipe",{}).has("shore_level"))
 print("SHORE_OWNED banks=",banks.size()," placements=",compiled.placements.size())
 FileAccess.open(OUT.path_join("all-banks.bin"),FileAccess.WRITE).store_var(banks)
 var added:Array[Dictionary]=[];var records:Array=[]
 for source:Dictionary in banks:
  if Vector2(source.anchor.x+519.5,source.anchor.z-326.4).length()>42:continue
  var candidate:=source
  var row:Dictionary={"anchor":source.anchor,"kind":source.replay_recipe.kind,"source_bounds":source.bounds,"accepted":not candidate.is_empty()}
  if not candidate.is_empty():
   var edges:Dictionary={};var small:=0
   for i in range(0,candidate.faces.size(),3):
    if (candidate.faces[i+1]-candidate.faces[i]).cross(candidate.faces[i+2]-candidate.faces[i]).length()<.0000001:small+=1
    for j in 3:
     var a:Vector3=candidate.faces[i+j];var b:Vector3=candidate.faces[i+(j+1)%3]
     var key:Array=[a,b] if a<b else [b,a]
     edges[key]=edges.get(key,0)+1
   var open:=0
   for count:int in edges.values():
    if count!=2:open+=1
   var original_edges:Dictionary={}
   var original:PackedVector3Array=candidate.shore_source_faces
   for i in range(0,original.size(),3):
    for j in 3:
     var a:Vector3=original[i+j];var b:Vector3=original[i+(j+1)%3]
     var key:Array=[a,b] if a<b else [b,a]
     original_edges[key]=original_edges.get(key,0)+1
   var original_open:=0
   for count:int in original_edges.values():
    if count!=2:original_open+=1
   row["original_open_edges"]=original_open
   if open>0:print("SHORE_OPEN ",source.anchor," before=",original_open," after=",open)
   row["open_edges"]=open;row["tiny_triangles"]=small
   row["bounds"]=candidate.bounds;row["recipe"]=candidate.replay_recipe
   row["triangles"]=candidate.faces.size()/3;row["turf_triangles"]=candidate.green.size()/3
   candidate["render_arrays"]=ROCKS.CRAGS.mesh_arrays(candidate)
   added.append(candidate)
  records.append(row)
  print("SHORE_FORM ",row.anchor," ",row.kind," accepted=",row.accepted)
 FileAccess.open(OUT.path_join("banks.bin"),FileAccess.WRITE).store_var(added)
 FileAccess.open(OUT.path_join("banks.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
 print("SHORE_BUILD accepted=",added.size()," rejected=",records.size()-added.size())
 quit()
