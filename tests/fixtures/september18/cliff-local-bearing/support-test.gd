extends GutTest
func test_short_shelf_bearing_spreads_below_its_lip()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var donors:Array=[[1.0,[[3.0,2.0,2.0,0.0]],.5]]
 # The old three-argument implementation has no neighbouring support. A finite
 # ledge one metre away should acquire a rooted shoulder below its 3 m cap.
 var has_donors:=false
 for method:Dictionary in source.get_script_method_list():
  if method.name=="_shoulders":has_donors=method.args.size()==4
 var at_foot:float=source._shoulders(0.0,[],0,donors) if has_donors else source._shoulders(0.0,[],0)
 var at_rim:float=source._shoulders(2.8,[],0,donors) if has_donors else source._shoulders(2.8,[],0)
 print("SHORT_BEARING foot=",at_foot," rim=",at_rim)
 assert_gt(at_foot,1.0,"A short cliff's ledge should blend sideways into its lower bearing")
 assert_eq(at_rim,0.0,"Keep the nearby upper wall recessed")
 var previous:=0.0
 for i in 31:
  var y:=3.0-i*.1
  var value:float=source._shoulders(y,[],0,donors) if has_donors else source._shoulders(y,[],0)
  assert_gte(value,previous-.0001,"The bearing must not curl inward toward the foot")
  previous=value
