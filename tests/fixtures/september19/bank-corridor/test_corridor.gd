extends GutTest
const FIT=preload("res://tests/fixtures/september19/bank-corridor/fit.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
var fields:WorldFieldBlockCache;var region:HeightfieldRegion;var water:WaterFieldContext
var flowing:Dictionary={};var blocked:Dictionary={}
func before_all()->void:
 ROCKS.prepare()
 var hydraulic:=TerrainWorldTuning.make_water(2697992464)
 fields=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,hydraulic),hydraulic,26,0,8)
 region=fields.region(Vector2i(-3,1));water=fields.water(Vector2i(-3,1))
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 for source:Dictionary in sources:
  if source.replay_recipe.kind!="corner" or source.anchor.y!=20 or source.anchor.z!=205.5:continue
  if source.anchor.x==-541.5:flowing=source
  if source.anchor.x==-586.5:blocked=source
 assert(not flowing.is_empty() and not blocked.is_empty())
func test_clear_sloping_water_can_keep_its_cliff_dressing()->void:
 assert_false(FIT.fit(flowing,region,water).is_empty(),"A changing water level alone is not a blocked channel")
func test_neighboring_dry_bank_still_limits_rock_projection()->void:
 assert_true(FIT.fit(blocked,region,water).is_empty(),"A dry 24 m receiving bank must remain protected")

class FloodedWater extends WaterFieldContext:
 func has_sources()->bool:return true
 func level_at(_point:Vector2)->float:return 100.0
func test_flooded_crown_remains_ineligible()->void:
 assert_true(FIT.fit(flowing,region,FloodedWater.new()).is_empty())

class DryWater extends WaterFieldContext:
 func has_sources()->bool:return false
func test_dry_rock_is_not_deformed()->void:
 assert_eq(FIT.fit(flowing,region,DryWater.new()),flowing)

class BrokenWater extends WaterFieldContext:
 var wrapped:WaterFieldContext
 func has_sources()->bool:return true
 func covers(point:Vector2)->bool:return wrapped.covers(point)
 func level_at(point:Vector2)->float:
  if point.x> -539.6 and point.x< -539.3:return NAN
  return wrapped.level_at(point)
func test_a_dry_break_inside_the_sloping_passage_remains_ineligible()->void:
 var broken:=BrokenWater.new();broken.wrapped=water
 assert_true(FIT.fit(flowing,region,broken).is_empty(),"A wet slope may not bridge a dry obstruction")
