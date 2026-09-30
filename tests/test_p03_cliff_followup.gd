extends GutTest
const SUPPORT=preload("res://scripts/terrain/grass/GrassSupportSurfaces.gd")
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")

func _grid(faces:PackedVector3Array)->Dictionary:
 var flags:=PackedByteArray();flags.resize(81);flags.fill(1)
 var heights:=PackedFloat32Array();heights.resize(81)
 return {"grid":true,"origin":Vector2(-2,-2),"w":9,"h":9,"step":.5,"heights":heights,"flags":flags,
  "mesh_faces":faces,"mesh_cells":SUPPORT.index_mesh(faces,Vector2(-2,-2),.5),"id":"test"}

func test_roots_use_rendered_triangle_height_instead_of_the_envelope()->void:
 var faces:=PackedVector3Array([Vector3(-2,0,-2),Vector3(2,0,-2),Vector3(2,2,2),Vector3(-2,0,-2),Vector3(2,2,2),Vector3(-2,0,2)])
 var grid:=_grid(faces)
 for q:Vector2 in [Vector2(.5,-.5),Vector2(-.5,.5),Vector2(.7,.7)]:
  var expected:Variant=null
  for t in [0,3]:
   var hit:Variant=Geometry3D.ray_intersects_triangle(Vector3(q.x,10,q.y),Vector3.DOWN,faces[t],faces[t+1],faces[t+2])
   if hit!=null:expected=hit
  var actual:=SUPPORT.at_grid(grid,q)
  assert_not_null(expected)
  assert_almost_eq(float(actual.y),(expected as Vector3).y,.00001,"Root contacts the actual rendered triangle")

func test_wide_clump_cannot_overhang_a_supported_centre()->void:
 var faces:=PackedVector3Array([Vector3(-2,0,-2),Vector3(0,0,-2),Vector3(0,0,2),Vector3(-2,0,-2),Vector3(0,0,2),Vector3(-2,0,2)])
 var grid:=_grid(faces);var index:=SUPPORT.spatial_index([grid])
 var q:=Vector2(-.2,0);var support:=SUPPORT.at_index(index,q)
 assert_almost_eq(float(support.y),0.0,.00001)
 assert_eq(SUPPORT.footprint_scale(index,q,support,1.0),0.0,"A metre-wide clump at a 20 cm ledge is rejected")
 q=Vector2(-1,0);support=SUPPORT.at_index(index,q)
 assert_eq(SUPPORT.footprint_scale(index,q,support,.5),1.0,"A fully supported interior clump retains its size")

func test_rock_blocked_support_claims_the_point_without_terrain_fallback()->void:
 var faces:=PackedVector3Array([Vector3(-2,1,-2),Vector3(2,1,-2),Vector3(2,1,2),Vector3(-2,1,-2),Vector3(2,1,2),Vector3(-2,1,2)])
 var grid:=_grid(faces);grid.flags.fill(2)
 var hit:=SUPPORT.at_grid(grid,Vector2.ZERO)
 assert_almost_eq(float(hit.y),1.0,.00001)
 assert_eq(float(hit.edge_distance),0.0)

func test_tall_cliffs_are_gentler_without_a_new_sharp_crest_or_cut_off_foot()->void:
 STYLE.apply("sheet")
 for height:float in [12.0,24.0]:
  var env=ENV.build(Rect2(-20,-8,60,16),func(q:Vector2)->float:return height if q.x<=0 else 0.0,Callable(),2697992464)
  var grades:=[]
  for i in range(1,65):
   var q:=Vector2(i*.5,0);var y:float=env.sample(q)
   var gradient:float=absf(env.sample(q+Vector2(.25,0))-env.sample(q-Vector2(.25,0)))/.5
   if y>.1 and y<height-.1:grades.append(rad_to_deg(atan(gradient)))
   assert_lt(gradient,3.0,"No abrupt drop at the former 14 m relief boundary")
  grades.sort()
  assert_lt(float(grades[grades.size()/2]),44.0 if height==12.0 else 53.0,"Tall slopes have gentler median grades")
  assert_almost_eq(float(env.sample(Vector2.ZERO)),height,.001,"The slope meets its plateau")
  assert_lt(height-float(env.sample(Vector2(.5,0))),.05,"The first half metre rounds down gradually")
 STYLE.apply("sheet_bedrock")

func test_a_fully_cut_back_cliff_still_has_a_wall()->void:
 STYLE.apply("sheet_bedrock")
 var env=ENV.new();env.origin=Vector2(-12,-12);env.w=49;env.h=49
 env.ground.resize(49*49);env.surface.resize(49*49)
 for z in 49:
  for x in 49:
   var y:=12.0 if x<=24 else 0.0
   env.ground[z*49+x]=y;env.surface[z*49+x]=y
 var field=FIELD.new([],2697992464,null,Rect2(-6,-6,12,12));field._env=env
 var mesh:Array=field.solid(Rect2(-6,-6,12,12))
 assert_false(mesh.is_empty(),"Even a cut with no raised slope needs a solid cliff face")
 if mesh.is_empty():return
 var faces:PackedVector3Array=mesh[0].faces
 for height:float in [1.0,4.0,8.0,11.0]:
  var found:=false
  for i in range(0,faces.size(),3):
   if Geometry3D.ray_intersects_triangle(Vector3(3,height,.13),Vector3.LEFT,faces[i],faces[i+1],faces[i+2])!=null:found=true;break
  assert_true(found,"Cut wall is backed at height %s"%height)

func test_water_runout_never_excavates_the_existing_terrain()->void:
 STYLE.apply("sheet_bedrock")
 var env=ENV.build(Rect2(-8,-8,16,48),func(q:Vector2)->float:return 10.0 if q.y<0 else 2.0,Callable(),2697992464,
  func(q:Vector2)->float:return 2.8 if q.y>3.0 else NAN)
 for z in range(0,36):
  assert_gte(float(env.at(Vector2(0,z))),float(env.ground_node(Vector2(0,z)))-.00001,"Water can bury the added slope, never remove the terrain backing")

func test_rock_bench_colour_carries_the_surrounding_slope_grade()->void:
 STYLE.apply("sheet_bedrock")
 # Test the material contract on a flat rock ledge explicitly. The owner
 # rejected the deep generated benches this test formerly relied on existing.
 var points:=PackedVector3Array([Vector3(-1,8,0),Vector3(1,8,0),Vector3(0,8,1)])
 var roots:={}
 for p:Vector3 in points:roots[p]=[Vector3.UP,1.0,.2]
 var mesh:={"faces":points,"green":PackedVector3Array(),"native_roots":roots,
  "slope_sheet":true,"transform":Transform3D.IDENTITY,"top":12.0,"base":0.0}
 var arrays:Array=load("res://scripts/terrain/field/CliffRockCrags.gd").mesh_arrays(mesh)
 var rises:PackedVector2Array=arrays[0][Mesh.ARRAY_TEX_UV2]
 assert_eq(rises.size(),3)
 for rise:Vector2 in rises:
  assert_almost_eq(rise.x,5.6,.001,"A flat rock ledge carries its hillside moss grade instead of becoming pale lawn")

class FilmWater extends WaterFieldContext:
 var level:=.2
 func has_sources()->bool:return true
 func coverage()->Rect2:return Rect2(-200,-200,400,400)
 func covers(_q:Vector2)->bool:return true
 func level_at(_q:Vector2)->float:return level

func test_shallow_plateau_water_does_not_cut_away_the_rounded_shoulder()->void:
 # September 27: the sampler reports films; the envelope itself declines to
 # cut for water shallower than WATER_SINK (and grows no bank from it).
 var ledge:=func(q:Vector2)->float:return 4.0 if q.x<0.0 else 0.0
 var dry=FIELD.new([],2697992464,null,Rect2(-8,-8,16,16),null,null)
 dry.ground_at=ledge
 var water:=FilmWater.new()
 var field=FIELD.new([],2697992464,null,Rect2(-8,-8,16,16),null,water)
 field.ground_at=ledge
 var worst:=0.0
 for x in range(-8,9):
  for z in range(-8,9):
   var q:=Vector2(x,z)
   worst=maxf(worst,absf(field.envelope().at(q)-dry.envelope().at(q)))
 assert_almost_eq(worst,0.0,1e-6,"A film shallower than the required sink cannot cut the crest")
 water.level=2.0
 assert_eq(float(field._water_level().call(Vector2.ZERO)),2.0,"Deep channel water still constrains the slope")

func test_bedrock_cannot_recreate_a_lip_on_the_first_metre_of_a_rounded_crown()->void:
 var env=ENV.new();env.origin=Vector2(-8,-8);env.w=65;env.h=33
 var count:int=env.w*env.h
 env.ground.resize(count);env.surface.resize(count)
 var floor_level:=PackedFloat64Array();floor_level.resize(count)
 var top:=PackedFloat64Array();top.resize(count);top.fill(16.0)
 var relief:=top.duplicate()
 var cut:=PackedFloat64Array();cut.resize(count);cut.fill(2.0)
 for z in env.h:
  for x in env.w:
   var xx:float=env.origin.x+x*.5
   env.ground[z*env.w+x]=16.0 if xx<=0.0 else 0.0
   env.surface[z*env.w+x]=16.0 if xx<=0.0 else maxf(0.0,16.0-.5*xx*xx)
 var original:PackedFloat64Array=env.surface.duplicate()
 ENV._bedrock(env,floor_level,top,relief,2697992464,cut)
 for q:Vector2 in [Vector2(.5,0),Vector2(1,0)]:
  var index:int=roundi((q.y-env.origin.y)/.5)*env.w+roundi((q.x-env.origin.x)/.5)
  assert_almost_eq(float(env.at(q)),original[index],.001,"The continuous crown fillet survives rock bench carving")

func test_neighbouring_surface_nets_share_the_same_boundary_normals()->void:
 STYLE.apply("sheet_bedrock")
 var env=ENV.new();env.origin=Vector2(-8,-8);env.w=33;env.h=33
 env.ground.resize(33*33);env.surface.resize(33*33)
 for z in 33:
  for x in 33:env.surface[z*33+x]=4.0+(x-16)*.05+(z-16)*.05
 var a=FIELD.new([],2697992464,null,Rect2(-4,-4,8,4));a._env=env
 var b=FIELD.new([],2697992464,null,Rect2(-4,0,8,4));b._env=env
 var left:Dictionary=a.solid(Rect2(-4,-4,8,4))[0].native_roots
 var right:Dictionary=b.solid(Rect2(-4,0,8,4))[0].native_roots
 var common:=0;var worst:=0.0
 for p:Vector3 in left:
  if not right.has(p) or absf(p.x)>3.0:continue
  common+=1;worst=maxf(worst,(left[p][0] as Vector3).distance_to(right[p][0]))
 assert_gt(common,10,"Both owners render the same boundary vertices")
 assert_lt(worst,.00001,"A continuous surface must not acquire a dark normal seam at ownership boundaries")
