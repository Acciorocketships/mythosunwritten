extends GutTest
func test_authored_rock_feet_widen_beyond_the_middle_cross_section()->void:
 var path:=OS.get_environment("STORY_DETAIL_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path);generator.prepare()
 var records:Dictionary={}
 # Photo P20's world-oriented source profile domain, expanded beyond both ends.
 var salt:=2697992464+roundi(-253.5)*13+32*71
 for x in range(-2200,-1760):
  var u:=x*.25
  for mass:Array in generator._nature_mass_profile(u,8.0,salt):
   var key:=Vector2(mass[1],mass[3])
   if not records.has(key):records[key]=Vector2.ZERO
   var width:Vector2=records[key]
   if mass[4][2]>.12:width.x+=.25
   if mass[4][16]>.12:width.y+=.25
   records[key]=width
 var ratios:Array=[];var wider:=0
 for width:Vector2 in records.values():
  if width.y<2:continue
  ratios.append(width.x/width.y)
  if width.x>width.y*1.15:wider+=1
 print("SOURCE_FEET widths=",records.values()," ratios=",ratios," wider=",wider," count=",ratios.size())
 assert_gte(ratios.size(),3,"Exercise several actual authored profiles around photo P20")
 assert_gt(float(wider)/maxi(1,ratios.size()),.5,"Most source rocks need visibly broader lower footprints, rather than constant vertical extrusions")
