extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func test_stepped_native_wall_has_identical_owned_solids_in_whole_and_partitioned_queries()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return (12.0 if z<2 else 8.0) if x>=0 else 0.0)
 var region:=plan.compute_region(0,0,8)
 var whole:=ROCKS.compute(region,-3,-3,6,2697992464)
 var expected:Dictionary={};var transitions:=0
 for f:Dictionary in whole.placements:
  if f.kind!="rock":continue
  expected[f.id]=[f.faces,f.green,f.transform,f.anchor]
  if f.get("replay_recipe",{}).has("edge_heights"):transitions+=1
 var actual:Dictionary={};var duplicates:=0
 for lo:Vector2i in [Vector2i(-3,-3),Vector2i(0,-3),Vector2i(-3,0),Vector2i(0,0)]:
  for f:Dictionary in ROCKS.compute(region,lo.x,lo.y,3,2697992464).placements:
   if f.kind!="rock":continue
   if actual.has(f.id):duplicates+=1
   actual[f.id]=[f.faces,f.green,f.transform,f.anchor]
 assert_gt(transitions,0,"The ownership comparison must exercise actual height-aware ends")
 assert_eq(duplicates,0)
 assert_eq(actual,expected)
