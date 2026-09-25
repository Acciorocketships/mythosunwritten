extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
class AuditedWater extends WaterFieldContext:
 var requested:Rect2
 var outside:=0
 var calls:=0
 var wet_rect:=Rect2()
 func has_sources()->bool:return true
 # Let the observer see escaped samples instead of aborting at the production
 # assertion. The actual contract is the 26 m PathProgram query margin below.
 func coverage()->Rect2:return Rect2(-1000,-1000,2000,2000)
 func is_wet(point:Vector2)->bool:
  calls+=1
  if not requested.has_point(point):outside+=1
  return wet_rect.has_point(point)
 func level_at(_point:Vector2)->float:return 100.0
func test_halo_connections_do_not_query_water_outside_the_owner_domain()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return 16.0 if x>=0 or z>=0 else 0.0)
 var region:=plan.compute_region(0,0,12)
 var outside:=0;var calls:=0
 for lo:Vector2i in [Vector2i(-8,-8),Vector2i(0,-8),Vector2i(-8,0),Vector2i(0,0)]:
  var water:=AuditedWater.new()
  water.requested=Rect2(Vector2(lo)*24,Vector2.ONE*192).grow(26.0)
  ROCKS.compute(region,lo.x,lo.y,8,2697992464,null,water)
  outside+=water.outside;calls+=water.calls
 assert_gt(calls,0)
 assert_eq(outside,0,"Only owned rock and core grass supports may query the prepared hydraulic domain")
func rock_map(result:Dictionary)->Dictionary:
 var records:Dictionary={}
 for form:Dictionary in result.placements:
  if form.kind=="rock":records[form.id]=[form.faces,form.transform,form.anchor]
 return records
func test_wet_join_admission_is_complete_and_chunk_independent()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return 16.0 if x>=0 or z>=0 else 0.0)
 var region:=plan.compute_region(0,0,8)
 var water:=AuditedWater.new()
 water.requested=Rect2(-98,-98,196,196)
 water.wet_rect=Rect2(-18,-72,6,144)
 var dry:=rock_map(ROCKS.compute(region,-3,-3,6,2697992464))
 var whole:=ROCKS.compute(region,-3,-3,6,2697992464,null,water)
 var expected:=rock_map(whole);var actual:Dictionary={};var duplicates:=0
 for lo:Vector2i in [Vector2i(-3,-3),Vector2i(0,-3),Vector2i(-3,0),Vector2i(0,0)]:
  water.requested=Rect2(Vector2(lo)*24,Vector2.ONE*72).grow(26)
  var part:=rock_map(ROCKS.compute(region,lo.x,lo.y,3,2697992464,null,water))
  for id:String in part:
   if actual.has(id):duplicates+=1
   actual[id]=part[id]
 assert_gt(expected.size(),0)
 assert_lt(expected.size(),dry.size(),"Intersecting complete solids must still be withdrawn")
 assert_eq(actual,expected);assert_eq(duplicates,0);assert_eq(water.outside,0)
 water.requested=Rect2(-98,-98,196,196)
 water.wet_rect=Rect2(-1000,-1000,2000,2000)
 var flooded:=ROCKS.compute(region,-3,-3,6,2697992464,null,water)
 assert_eq(rock_map(flooded).size(),0)
 assert_eq(flooded.collision_faces.size(),0)
 assert_eq(flooded.grass_supports.size(),0)
