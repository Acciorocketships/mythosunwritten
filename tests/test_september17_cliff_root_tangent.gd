extends GutTest
const CURRENT=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func test_added_stone_leaves_the_native_surface_tangentially()->void:
 var path:=OS.get_environment("STORY_ROOT_GENERATOR")
 var generator:GDScript=CURRENT if path.is_empty() else load(path)
 generator.prepare()
 # At the emergence plane, vary the independent mass envelope while holding
 # the actual native face fixed. A linear crossing leaves a visible crease even
 # when vertex shading borrows a wall normal. Geometry must flatten at contact.
 var maximum:=0.0
 for u:float in [-10.7,-4.4,0.2,5.7,10.2]:
  for y:float in [1.3,4.7,9.1,14.2]:
   var below:float=generator._attach((.62-.015)/.8,u,y,1.0)
   var above:float=generator._attach((.62+.015)/.8,u,y,1.0)
   maximum=maxf(maximum,absf(above-below)/.030)
   assert_lt(below,generator._native_depth(u,y),"Approach the genuine native wall from inside")
   assert_gt(above,generator._native_depth(u,y),"The exposed skin must emerge outside the genuine native wall")
 print("ROOT_TANGENT maximum_envelope_slope=",maximum)
 assert_lt(maximum,.25,"Thin rock geometry must ease out of the native face, rather than cut across it at full slope")
