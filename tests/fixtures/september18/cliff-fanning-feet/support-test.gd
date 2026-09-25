extends GutTest
func test_shelf_support_spreads_into_adjacent_lower_rock_without_an_upper_bulge()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var supports:Callable=Callable(source,"_shoulders")
 var arity:=3
 for method:Dictionary in source.get_script_method_list():
  if method.name=="_shoulders":arity=method.args.size()
 # A 16 m high, 2 m deep shelf four metres sideways from this probe.
 # Its lower bearing should widen into the probe; its upper rim should not.
 var donors:Array=[[4.0,[[16.0,2.0,3.0,0.0]]]]
 var root:float=supports.call(0.0,[],0,donors) if arity==4 else supports.call(0.0,[],0)
 var crown:float=supports.call(15.0,[],0,donors) if arity==4 else supports.call(15.0,[],0)
 print("FANNING_BEARING root=",root," upper=",crown)
 assert_gt(root,1.5,"The root must spread beyond the narrow upper shelf footprint")
 assert_lt(crown,.01,"The neighbouring upper shelf must retain its actual outline")
 var previous:=crown
 var recession:=0.0;var jump:=0.0
 for i in range(1,151):
  var y:=15.0-float(i)*.1
  var current:float=supports.call(y,[],0,donors) if arity==4 else supports.call(y,[],0)
  recession=maxf(recession,previous-current);jump=maxf(jump,absf(current-previous));previous=current
 assert_lt(recession,.001,"The widening lower support cannot cave inward beneath its bearing")
 assert_lt(jump,.06,"The spread must enter smoothly instead of forming another hard shelf")

func test_neighbor_support_enters_a_tread_without_a_depth_discontinuity()->void:
 var source:GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var local:Array=[[16.0,2.0,3.0,0.0]]
 var donors:Array=[[4.0,[[32.0,4.0,3.0,0.0]]]]
 var above:float=source._shoulders(16.001,local,1,donors)
 var below:float=source._shoulders(15.999,local,1,donors)
 print("SUPPORT_TREAD_JUMP ",absf(above-below))
 assert_lt(absf(above-below),.01,"The underlying support must remain continuous across the separately authored tread")
