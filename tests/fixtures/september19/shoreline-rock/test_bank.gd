extends GutTest
const FIT=preload("res://tests/fixtures/september19/shoreline-rock/fit.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
var fields:WorldFieldBlockCache
var region:HeightfieldRegion
var water:WaterFieldContext
var source:Dictionary
func before_all()->void:
 ROCKS.prepare()
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 fields=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 region=fields.region(Vector2i(-3,1));water=fields.water(Vector2i(-3,1))
 var frozen:Dictionary=FileAccess.open("res://docs/qa/2026-09-19-manual/120-corner-shore/field.bin",FileAccess.READ).get_var()
 for form:Dictionary in frozen.N04:
  if (form.anchor as Vector3).distance_to(Vector3(-490.5,8,312))<.01:source=form
 assert(not source.is_empty())
func test_reported_bank_keeps_exposed_rock_without_filling_water()->void:
 assert_true(ROCKS._wet_formation(source,water),"The original whole-footprint rule removes the reported bank")
 var rock:=FIT.fit(source,region,water)
 assert_false(rock.is_empty(),"Keep the exposed bank rock instead of omitting the full formation")
 if rock.is_empty():return
 var wet_air:=0;var projected:=0;var edges:Dictionary={}
 for i in range(0,rock.faces.size(),3):
  var a:Vector3=rock.transform*rock.faces[i];var b:Vector3=rock.transform*rock.faces[i+1];var c:Vector3=rock.transform*rock.faces[i+2]
  for p:Vector3 in [a,b,c,(a+b+c)/3,(a+b)*.5,(b+c)*.5,(c+a)*.5]:
   var point:=Vector2(p.x,p.z)
   var level:=water.level_at(point)
   if is_finite(level) and p.y<level+.1 and p.y>TerrainSurfaceField.surface_y(region,p.x,p.z)+.01:wet_air+=1
   if p.y>13.8 and p.y<15.5 and p.x<-491.8:projected+=1
  for j in 3:
   var p:Vector3=rock.faces[i+j];var q:Vector3=rock.faces[i+(j+1)%3]
   var key:Array=[p,q] if p<q else [q,p]
   edges[key]=edges.get(key,0)+1
 var open:=0
 for count:int in edges.values():
  if count!=2:open+=1
 assert_eq(wet_air,0,"Every wetted rock sample must remain inside the original terrain")
 assert_gt(projected,20,"The visible dry face needs actual projection, not just recolouring")
 assert_eq(open,0,"The bank must retain a closed collision shell")
 assert_lte(rock.top,source.top+.001)
