extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/120-corner-shore"
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:run.call_deferred()
func run()->void:
 ROCKS.prepare()
 var water:=TerrainWorldTuning.make_water(2697992464)
 var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
 var fields:=WorldFieldBlockCache.new(plan,water,26,0,8)
 var native:Dictionary=FileAccess.open(OUT.path_join("native.bin"),FileAccess.READ).get_var()
 var report:Dictionary={};var payload:Dictionary={}
 for site:String in ["N03","N04"]:
  var key:=Vector2i(-3,2 if site=="N03" else 1)
  print("FIELD_BEGIN ",site)
  var region:=fields.region(key);var wet:=fields.water(key)
  var actual:=CliffDressing.compute(region,key.x*8-1,key.y*8-1,10)
  var matched:=0;var missing:Array=[]
  for kind:String in ["wall","outer_wall","inner_wall"]:
   for pose:Transform3D in native[site][kind]:
    if actual[kind].has(pose):matched+=1
    else:missing.append({"kind":kind,"pose":pose})
  var forms:=ROCKS.formations(native[site].wall,2697992464,region)
  forms.append_array(ROCKS.CORNERS.formations(native[site].outer_wall,2697992464,region))
  forms.append_array(ROCKS.CORNERS.formations(native[site].inner_wall,2697992464,region,null,true))
  var production:Dictionary={}
  if site=="N03":
   var built:=ROCKS.compute(region,-19,20,2,2697992464,null,wet)
   for rock:Dictionary in built.placements:
    if rock.get("anchor",Vector3.ZERO)==Vector3(-445.5,20,490.5) and rock.kind=="rock":production=rock
   assert(not production.is_empty(),"Reported corner must reach production-owned publication")
   FileAccess.open(OUT.path_join("production-corner.bin"),FileAccess.WRITE).store_var(production)
  var records:Array=[]
  for form:Dictionary in forms:
   var unique:Dictionary={};var wet_vertices:=0;var above:=0;var below:=0;var min_level:=INF;var max_level:=-INF
   for vertex:Vector3 in form.faces:
    var point:Vector3=form.transform*vertex
    if unique.has(point):continue
    unique[point]=true
    var level:=wet.level_at(Vector2(point.x,point.z))
    if not is_finite(level):continue
    wet_vertices+=1;min_level=minf(min_level,level);max_level=maxf(max_level,level)
    if point.y>level+.1:above+=1
    else:below+=1
   records.append({"wet_vertices":wet_vertices,"above_water_vertices":above,"submerged_vertices":below,"minimum_water":min_level if is_finite(min_level) else null,"maximum_water":max_level if is_finite(max_level) else null,"anchor":form.anchor,"bounds":form.bounds,"recipe":form.replay_recipe,"wet_rejected":ROCKS._wet_formation(form,wet)})
  report[site]={"native_matches":matched,"native_mismatches":missing,"formations":records}
  payload[site]=forms
  print("FIELD_END ",site," native matches=",matched," mismatches=",missing.size()," forms=",forms.size())
  FileAccess.open(OUT.path_join("field.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
  FileAccess.open(OUT.path_join("field.bin"),FileAccess.WRITE).store_var(payload)
 quit()
