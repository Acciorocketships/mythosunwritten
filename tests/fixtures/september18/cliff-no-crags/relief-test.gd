extends GutTest
func test_replacement_relief_has_no_narrow_crack_gradients()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var cache:Dictionary={};var steepest:=0.0;var bent:=0.0;var lowest:=INF;var highest:=-INF
 for ix in 320:
  for iy in 36:
   var x:float=-40.0+ix*.25;var y:float=iy*.7
   var a:float=source._stone_relief(x-.1,y,2697992464,cache)
   var b:float=source._stone_relief(x,y,2697992464,cache)
   var c:float=source._stone_relief(x+.1,y,2697992464,cache)
   steepest=maxf(steepest,absf(c-a)/.2);bent=maxf(bent,absf(a-2*b+c))
   lowest=minf(lowest,b);highest=maxf(highest,b)
 print("NO_CRAGS slope=",steepest," second_difference=",bent," variation=",highest-lowest)
 assert_lt(steepest,.07,"Replacement shape should not contain narrow crack sides")
 assert_lt(bent,.003,"Broad rock variation should not introduce sharp groove bottoms")
 assert_gt(highest-lowest,.04,"Removing cracks must retain broad shape variation")
