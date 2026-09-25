extends GutTest
const FIT=preload("res://tests/fixtures/september19/shoreline-rock/fit_bank.gd")
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
func test_bank_dressing_continues_through_visible_waterline()->void:
 var rock:=FIT.fit(source,region,water)
 assert_false(rock.is_empty())
 if rock.is_empty():return
 var exposed:=0;var maximum:=0.0
 var native=ROCKS.CRAGS
 for p:Vector3 in rock.faces:
  var world:Vector3=rock.transform*p
  if world.y<10 or world.y>13.5:continue
  var depth:float=native._native_depth(rock.transform.origin.dot(rock.transform.basis.x)+p.x,p.y)
  if p.z>depth+.1:exposed+=1
  maximum=maxf(maximum,p.z-depth)
 assert_gt(exposed,100,"Dress the visible submerged bank too, not just the thin dry crown")
 assert_lte(maximum,3.001,"Keep the channel bank narrow and attached to the native cliff")

class FloodedWater extends WaterFieldContext:
 func has_sources()->bool:return true
 func level_at(_point:Vector2)->float:return 20.0
func test_fully_wet_cliff_does_not_admit_a_bank_under_a_fall()->void:
 assert_true(FIT.fit(source,region,FloodedWater.new()).is_empty())

class NarrowWater extends WaterFieldContext:
 func has_sources()->bool:return true
 func covers(_point:Vector2)->bool:return true
 func level_at(point:Vector2)->float:return 13.7 if point.x < -491.0 and point.x > -494.0 else NAN
func test_narrow_channel_cannot_receive_the_bank_projection()->void:
 assert_true(FIT.fit(source,region,NarrowWater.new()).is_empty(),"Protect a narrow channel instead of blindly admitting every wet bank")

class DryWater extends WaterFieldContext:
 func has_sources()->bool:return false
func test_dry_formation_keeps_exact_original_geometry()->void:
 assert_eq(FIT.fit(source,region,DryWater.new()),source)
