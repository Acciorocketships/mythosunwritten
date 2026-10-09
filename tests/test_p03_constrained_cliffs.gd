extends GutTest

# Historical step-ground fixtures exercise the E3 envelope/fillet. The shared
# production profile supplies continuous ground and is covered separately.
var _fixture_saved_mode: int
func before_each() -> void:
 _fixture_saved_mode = TerrainTileField.cliff_end
 TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E3
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func after_each()->void:
 STYLE.apply("sheet_bedrock")
 TerrainTileField.cliff_end = _fixture_saved_mode
func test_water_beside_a_tall_cliff_preserves_its_rounded_shoulder()->void:
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

func test_opposing_banks_keep_a_submerged_channel_between_them()->void:
 STYLE.apply("sheet")
 var env=ENV.build(Rect2(-8,-16,16,32),func(q:Vector2)->float:return 12.0 if absf(q.y)>=8 else 0.0,Callable(),2697992464,func(q:Vector2)->float:return .8 if absf(q.y)<8 else NAN)
 assert_gt(env.sample(Vector2(0,7.5)),11.85,"A constrained bank still starts with a rounded shoulder")
 for z:float in [-.5,0.0,.5]:
  assert_lt(env.sample(Vector2(0,z)),.8,"Opposing bank extensions must not dam the middle of the channel")

func test_small_wet_patch_cannot_slice_a_tall_bank_into_a_slab()->void:
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

func test_marked_native_crowns_keep_their_rounded_profile_after_rock_carving()->void:
 var smooth=_native_surface("sheet")
 var carved=_native_surface("sheet_bedrock")
 for x:float in [510,516,542,548]:
  var crest:=948.0 if x<520 else 972.0
  for i in range(1,6):
   var q:=Vector2(x,crest-i*.5)
   assert_lt(absf(carved.sample(q)-smooth.sample(q)),.5,"The actual marked crown stays rounded at %s"%q)

func test_rock_faces_stay_below_the_local_mountain_crest()->void:
 STYLE.apply("sheet_bedrock")
 var env=ENV.build(Rect2(-20,-12,40,36),func(q:Vector2)->float:return 12.0 if q.y<=0 else 0.0,Callable(),2697992464)
 var highest:=0.0
 for y:float in env.surface:highest=maxf(highest,y)
 assert_lte(highest,12.001,"Restoring rock projections cannot raise peaks above the plateau")

func test_native_rock_joins_do_not_make_one_cell_fins_or_slots()->void:
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

func test_marked_rock_faces_stay_close_to_their_continuous_hillside()->void:
 var smooth=_native_surface("sheet")
 var carved=_native_surface("sheet_bedrock")
 var deepest:=0.0
 for x in range(980,1011):
  for z in range(1880,1949):
   var q:=Vector2(x,z)*.5
   deepest=maxf(deepest,smooth.at(q)-carved.at(q))
 assert_lt(deepest,.26,"The solid backing remains intact beneath projecting rock ledges")
 for x:float in [510,516,542,548]:
  var crest:=948.0 if x<520 else 972.0
  for i in range(1,6):
   var q:=Vector2(x,crest-i*.5)
   var drop:float=absf(carved.sample(q)-carved.sample(q+Vector2(0,.5)))
   assert_lt(drop,.72,"The actual first 2.5 m of the upper shoulder stays below 55 degrees: %s"%q)

func test_buried_foot_rocks_do_not_warp_the_shared_bedrock_sheet()->void:
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

func test_reported_mountain_shoulders_are_not_cut_into_narrow_wet_pockets()->void:
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

func test_native_exposures_have_real_wide_treads_not_only_a_stone_texture()->void:
 var smooth=_native_surface("sheet")
 var rock=_native_surface("sheet_bedrock")
 # September 28: rounded banks no longer fill deep water (the fixture's 11 m
 # deep tarn). The 19 benches the old envelope stood inside that water are
 # gone by design; ledges on dry ground are counted (35 before, 32 after).
 var f:=FileAccess.open("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz",FileAccess.READ)
 var d:Dictionary=bytes_to_var(f.get_buffer(f.get_length()).decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var treads:=0;var patches:={}
 for x in range(960,1113):
  for z in range(1856,2017):
   var q:=Vector2(x,z)*.5
   if rock.rock_at(q)<.6:continue

   var dx:=Vector2(.5,0);var dz:=Vector2(0,.5)
   var base_gradient:=Vector2(smooth.at(q+dx)-smooth.at(q-dx),smooth.at(q+dz)-smooth.at(q-dz))
   var gradient:=Vector2(rock.at(q+dx)-rock.at(q-dx),rock.at(q+dz)-rock.at(q-dz))
   if base_gradient.length()<=.6 or gradient.length()>=.35 or rock.at(q)-smooth.at(q)<=.35:continue
   var fall:=base_gradient.normalized()
   if absf(rock.sample(q+fall*.5)-rock.sample(q-fall*.5))>=.3:continue
   patches[Vector2i(q/8.0)]=true
   var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
   var level:float=d.wet[p.y*d.w+p.x]
   if not (is_finite(level) and level>d.ground[p.y*d.w+p.x]+.4):treads+=1
 assert_gt(treads,28,"At least 7 square metres of one-metre-deep ledges remain on dry ground while faces lean with the hill")
 # October 4: the fillet stays under the lip across each wall line; one bench
 # in the 8 m cell (65, 118) now tilts with the slope beside it, so 9 -> 8
 # patches while the dry tread area is unchanged (33 samples).
 assert_gt(patches.size(),7,"Ledges return across distinct cliff patches, not just one small detail")

func test_projecting_rocks_leave_the_native_submerged_channel_open()->void:
 var smooth=_native_surface("sheet")
 var rock=_native_surface("sheet_bedrock")
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var tested:=0;var violations:=0
 for x in range(960,1113):
  for z in range(1856,2017):
   var q:=Vector2(x,z)*.5
   var p:=Vector2i(((q-d.origin)/.5).round());var water:float=d.wet[p.y*d.w+p.x]
   if is_nan(water) or smooth.at(q)>water-.05:continue
   tested+=1
   if rock.at(q)>water:violations+=1
 assert_gt(tested,100,"Exercise real native submerged channel samples")
 assert_eq(violations,0,"Restoring rock relief cannot fill the open water channel")

func test_rock_face_normals_follow_the_hillside_instead_of_standing_upright()->void:
 var smooth=_native_surface("sheet")
 var rock=_native_surface("sheet_bedrock")
 var deviations:=[]
 for x in range(960,1113):
  for z in range(1856,2017):
   var q:=Vector2(x,z)*.5
   if rock.rock_at(q)<.6:continue
   var dx:=Vector2(.5,0);var dz:=Vector2(0,.5)
   var backing:=Vector2(smooth.at(q+dx)-smooth.at(q-dx),smooth.at(q+dz)-smooth.at(q-dz))
   var face:=Vector2(rock.at(q+dx)-rock.at(q-dx),rock.at(q+dz)-rock.at(q-dz))
   # Measure the actual risers on ordinary slopes, excluding level ledges
   # and channel cut faces that are already steep in the backing terrain.
   if backing.length()<=.6 or backing.length()>=1.6 or face.length()<=backing.length()*1.1:continue
   var a:=Vector3(-backing.x,1,-backing.y).normalized()
   var b:=Vector3(-face.x,1,-face.y).normalized()
   deviations.append(rad_to_deg(acos(clampf(a.dot(b),-1,1))))
 deviations.sort()
 assert_gt(deviations.size(),200,"Exercise rock faces across the native fixture")
 assert_lt(float(deviations[deviations.size()/2]),14.0,"Typical rock-face normals follow the supporting slope")
 assert_lt(float(deviations[int(deviations.size()*.9)]),24.0,"The broad faces cannot be dominated by upright walls")
