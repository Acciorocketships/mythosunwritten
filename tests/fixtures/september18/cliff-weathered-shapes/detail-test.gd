extends GutTest
func test_face_relief_varies_at_rock_scale_without_narrow_grooves()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var cache:Dictionary={};var energy:=0.0;var samples:=0;var steepest:=0.0;var bent:=0.0
 for ix in 160:
  for iy in 36:
   var x:float=-40.0+ix*.5;var y:float=iy*.7
   var b:float=source._stone_relief(x,y,2697992464,cache)
   var a:float=source._stone_relief(x-1.5,y,2697992464,cache)
   var c:float=source._stone_relief(x+1.5,y,2697992464,cache)
   energy+=absf(b-(a+c)*.5);samples+=1
   a=source._stone_relief(x-.1,y,2697992464,cache)
   c=source._stone_relief(x+.1,y,2697992464,cache)
   steepest=maxf(steepest,absf(c-a)/.2);bent=maxf(bent,absf(a-2*b+c))
 print("ROCK_SCALE_DETAIL mean=",energy/samples," slope=",steepest," second_difference=",bent)
 assert_gt(energy/samples,.025,"Broad faces need visible metre-scale shape, not only barely bent flat slabs")
 assert_lt(steepest,.45,"Rock-scale relief must not reintroduce steep narrow crack sides")
 assert_lt(bent,.025,"Detail must not create sharp groove bottoms")
