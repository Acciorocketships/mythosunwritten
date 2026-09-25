extends GutTest

func test_rooted_nature_boulders_do_not_stretch_with_the_whole_cliff()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 source.prepare()
 var largest_ratio:=0.0;var checked:=0
 for u:float in [-42,-19,0,13,37]:
  var medium:Array=source._nature_mass_profile(u,32,2697992464)
  var tall:Array=source._nature_mass_profile(u,64,2697992464)
  assert_eq(medium.size(),tall.size())
  for i in medium.size():
   largest_ratio=maxf(largest_ratio,tall[i][1]/medium[i][1]);checked+=1
 print("ROOT_BOULDER_HEIGHT checked=",checked," growth_ratio=",largest_ratio)
 assert_gt(checked,5)
 assert_lt(largest_ratio,1.2,"A taller backing cliff must not stretch each rooted boulder into a full-height column")
