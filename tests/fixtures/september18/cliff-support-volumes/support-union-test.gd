extends GutTest
func test_overlapping_terraces_share_lower_bearing_instead_of_accumulating_columns()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 # Three ledges with the same outer reach should share the underlying rock.
 # Treating every ledge as an additional solid extrudes the base three times.
 var shelves:Array=[[6.0,2.0,2.0,0.0],[10.0,2.0,2.0,0.0],[16.0,2.0,2.0,0.0]]
 var single:float=source._shoulders(0.0,[shelves[0]],0)
 var joined:float=source._shoulders(0.0,shelves,0)
 print("SHARED_BEARING single=",single," stacked=",joined)
 assert_gte(joined,single,"The lower stone cannot retreat inside its supported ledge")
 assert_lt(joined,single+.5,"Overlapping shoulders must share their bearing rather than multiply base extrusion")
 var previous:float=source._shoulders(5.9,shelves,0)
 var recession:=0.0
 for i in 59:
  var current:float=source._shoulders(5.8-i*.1,shelves,0)
  recession=maxf(recession,previous-current);previous=current
 assert_lt(recession,.0001,"The joined lower support must remain rooted")
