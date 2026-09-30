extends GutTest
var ENV: GDScript = _old_envelope()
func _old_envelope()->GDScript:
 var script:=GDScript.new()
 script.source_code=FileAccess.get_file_as_string("res://docs/qa/2026-09-26-p03-crown-colour/baseline-envelope.gd.txt")
 assert(script.reload()==OK)
 return script
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func after_each()->void:STYLE.apply("sheet_bedrock")
func control_water_beside_a_tall_cliff_preserves_its_rounded_shoulder()->void:
 STYLE.apply("sheet")
 var env=ENV.build(Rect2(-8,-8,16,44),func(q:Vector2)->float:return 12.0 if q.y<=0 else 0.0,Callable(),2697992464,func(q:Vector2)->float:return .8 if q.y>0 else NAN)
 assert_gt(env.sample(Vector2(0,.5)),11.85,"Water beside the lip must not cut a vertical step into its shoulder")
 var grades:=[]
 for i in range(1,35):
  var p:=Vector2(0,i*.5);var y:float=env.sample(p)
  if y<1.0 or y>11.8:continue
  grades.append(rad_to_deg(atan(absf(env.sample(p+Vector2(0,.25))-env.sample(p-Vector2(0,.25)))/.5)))
 grades.sort()
 assert_lt(float(grades[grades.size()/2]),50.0,"Test the water-constrained slope, not the dry profile")
 assert_lt(env.sample(Vector2(0,20)),.8,"The bank still meets and sinks under water")

func control_opposing_banks_keep_a_submerged_channel_between_them()->void:
 STYLE.apply("sheet")
 var env=ENV.build(Rect2(-8,-16,16,32),func(q:Vector2)->float:return 12.0 if absf(q.y)>=8 else 0.0,Callable(),2697992464,func(q:Vector2)->float:return .8 if absf(q.y)<8 else NAN)
 assert_gt(env.sample(Vector2(0,7.5)),11.85,"A constrained bank still starts with a rounded shoulder")
 for z:float in [-.5,0.0,.5]:
  assert_lt(env.sample(Vector2(0,z)),.8,"Opposing bank extensions must not dam the middle of the channel")

func control_small_wet_patch_cannot_slice_a_tall_bank_into_a_slab()->void:
 STYLE.apply("sheet")
 var ground:=func(q:Vector2)->float:return 12.0 if q.y<=0 else 0.0
 var area:=Rect2(-8,-8,16,32)
 var plain=ENV.build(area,ground,Callable(),2697992464)
 var wet=ENV.build(area,ground,Callable(),2697992464,func(q:Vector2)->float:return 1.4 if q.y>0 and q.y<4 else NAN)
 for z:float in [.5,1,2,3]:
  assert_lt(float(plain.sample(Vector2(0,z))-wet.sample(Vector2(0,z))),.5,"A small wet patch inside the bank runout must not sever its shoulder")

func _native_surface(style:String):
 var f:=FileAccess.open("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz",FileAccess.READ)
 var d:Dictionary=bytes_to_var(f.get_buffer(f.get_length()).decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
  return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var water:=func(q:Vector2)->float:return d.wet[index.call(q)]
 var excluded:=func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0
 var area:=Rect2(476,924,92,96)
 STYLE.apply(style)
 return ENV.build(area,ground,excluded,2697992464,water)

func control_marked_native_crowns_keep_their_rounded_profile_after_rock_carving()->void:
 var smooth=_native_surface("sheet")
 var carved=_native_surface("sheet_bedrock")
 for x:float in [510,516,542,548]:
  var crest:=948.0 if x<520 else 972.0
  for i in range(1,6):
   var q:=Vector2(x,crest-i*.5)
   assert_lt(absf(carved.sample(q)-smooth.sample(q)),.5,"The actual marked crown stays rounded at %s"%q)

func control_unbenched_rock_follows_the_slope_instead_of_making_a_giant_shelf()->void:
 var cell:=[Vector2.ZERO,.7,5.0,.2,.5,false]
 for y:float in [7,8,9,10,11,12]:
  assert_almost_eq(ENV._bedrock_level(y,cell,-.1),y-.1,.00001,"An unbenched block retains its sloping face")

func control_native_rock_joins_do_not_make_one_cell_fins_or_slots()->void:
 var smooth=_native_surface("sheet")
 var carved=_native_surface("sheet_bedrock")
 var worst:=0.0;var point:=Vector2.ZERO
 for x in range(980,1011):
  for z in range(1880,1949):
   var q:=Vector2(x,z)*.5
   for dir:Vector2 in [Vector2(.5,0),Vector2(0,.5)]:
    var a:float=carved.at(q-dir);var b:float=carved.at(q);var c:float=carved.at(q+dir)
    var spike:=maxf(b-maxf(a,c),minf(a,c)-b)
    var original_curve:float=absf(smooth.at(q)-(smooth.at(q-dir)+smooth.at(q+dir))*.5)
    if original_curve<.2 and spike>worst:worst=spike;point=q
 assert_lt(worst,1.0,"No multi-metre rock fin or slot across a single half-metre cell (worst %s)"%point)

func control_marked_rock_faces_stay_close_to_their_continuous_hillside()->void:
 var smooth=_native_surface("sheet")
 var carved=_native_surface("sheet_bedrock")
 var worst:=0.0
 for x in range(980,1011):
  for z in range(1880,1949):
   var q:=Vector2(x,z)*.5
   worst=maxf(worst,absf(carved.at(q)-smooth.at(q)))
 assert_lt(worst,1.5,"The marked rock patch must remain embedded in the hillside, without metre-scale detached-looking slabs")
 for x:float in [510,516,542,548]:
  var crest:=948.0 if x<520 else 972.0
  for i in range(1,6):
   var q:=Vector2(x,crest-i*.5)
   var drop:float=absf(carved.sample(q)-carved.sample(q+Vector2(0,.5)))
   assert_lt(drop,.72,"The actual first 2.5 m of the upper shoulder stays below 55 degrees: %s"%q)

func control_buried_foot_rocks_do_not_warp_the_shared_bedrock_sheet()->void:
 STYLE.apply("sheet_bedrock")
 var env=ENV.new();env.origin=Vector2(-8,-8);env.w=33;env.h=33
 env.ground.resize(33*33);env.surface.resize(33*33);env.surface.fill(4.0)
 var field_script=load("res://scripts/terrain/field/CliffSlopeField.gd")
 var area:=Rect2(-4,-4,8,8)
 var plain=field_script.new([],2697992464,null,area);plain._env=env
 var dressed=field_script.new([],2697992464,null,area);dressed._env=env
 dressed.rock_list.append({"kind":"basal","centre":Vector3(0,3.8,0),"ru":1.5,"ry":1.5,"ro":1.5,"axis_t":Vector3.RIGHT,"axis_y":Vector3.UP,"axis_n":Vector3.BACK})
 var a:Dictionary=plain.solid(area)[0];var b:Dictionary=dressed.solid(area)[0]
 assert_eq(a.faces,b.faces,"Already buried foot rocks cannot add owner-dependent mounds to the continuous bedrock")
 assert_eq(a.native_roots,b.native_roots,"Their presence in a chunk halo cannot change shared surface normals")

func control_reported_mountain_shoulders_are_not_cut_into_narrow_wet_pockets()->void:
 var env=_native_surface("sheet_bedrock")
 for q:Vector2 in [Vector2(493.3,958.2),Vector2(492.3,946.45),Vector2(516.8,970.5)]:
  var previous:float=env.sample(q-Vector2(.7,-.7))
  for step in 4:
   var point:=q+Vector2(.7,-.7)*step
   var y:float=env.sample(point)
   assert_lt(previous-y,1.42,"The owner's circled shoulder continues as a slope instead of a water-cut recess at %s"%point)
   previous=y

func test_upper_circled_rock_bench_cannot_excavate_a_deep_notch()->void:
 var smooth=_native_surface("sheet")
 var rock=_native_surface("sheet_bedrock")
 for q:Vector2 in [Vector2(472.6,954.2),Vector2(473.3,953.5),Vector2(474,952.8),Vector2(474.7,952.1)]:
  assert_lt(smooth.sample(q)-rock.sample(q),.35,"Rock detail must remain shallow in the owner's upper-right circled hillside at %s"%q)
