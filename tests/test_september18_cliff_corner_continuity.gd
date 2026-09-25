extends GutTest

# Pins the full-projection ("current") rock shape this test was written for.
# The owner-selected September 23 default compresses projection (subtle),
# which narrows ledges by design; test_september23_cliff_directions.gd
# covers that style, including its retained wall turf.
const _STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_STYLE.apply("current")
func after_all()->void:_STYLE.apply("chosen")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
func test_outer_turn_uses_physical_composition_scale()->void:
 var form:=CORNER.make(Transform3D.IDENTITY,8,2697992464)
 var angles:Dictionary={}
 for point:Vector3 in form.faces:
  if absf(point.y-8.0)>.001 or point.x<=-1.5 or point.z<=-1.5:continue
  angles[snappedf(atan2(point.x+1.5,point.z+1.5),.001)]=true
 assert_lte(angles.size(),16,"Native turn must not squeeze dozens of independent rock columns into its short arc")
func test_inner_corner_is_an_explicit_closed_construction()->void:
 var generator:GDScript=CORNER
 assert_true(generator.has_method("make_inner"),"Concave native joins need their own added rock")
 if not generator.has_method("make_inner"):return
 var form:Dictionary=generator.make_inner(Transform3D.IDENTITY,16,2697992464)
 var edges:Dictionary={}
 for i in range(0,form.faces.size(),3):
  for j in 3:
   var a:Vector3=form.faces[i+j];var b:Vector3=form.faces[i+(j+1)%3]
   var key:Array=[a,b] if a<b else [b,a]
   edges[key]=edges.get(key,0)+1
 var open:=0
 for count:int in edges.values():
  if count!=2:open+=1
 assert_eq(open,0,"Inner collision must remain a closed rock solid")
 assert_gt(form.green.size(),0,"The inner join carries real turf ledges")
 var coverage:=0
 for y:float in [2,5,8,11,14]:
  for i in range(0,form.faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(15,y,15),Vector3(-1,0,-1).normalized(),form.faces[i],form.faces[i+1],form.faces[i+2])
   if hit!=null and hit.x>.7:coverage+=1;break
 assert_gte(coverage,4,"The recess must carry connected rock over most of its height")

func test_short_inner_corners_are_not_silently_omitted()->void:
 var forms:=CORNER.formations([Transform3D.IDENTITY],2697992464,null,null,true)
 assert_eq(forms.size(),1)
 assert_eq(forms[0].replay_recipe.kind,"inner_corner")

func test_inner_joins_keep_production_ownership_grounding_and_collision()->void:
 var rocks:=preload("res://scripts/terrain/field/CliffRockDressing.gd")
 rocks.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return 16.0 if x>=0 or z>=0 else 0.0)
 var region:=plan.compute_region(0,0,8)
 var whole:=rocks.compute(region,-3,-3,6,2697992464)
 var expected:Dictionary={};var feet:=0;var floating:=0;var total:=0
 for form:Dictionary in whole.placements:
  if form.kind!="rock":continue
  total+=form.faces.size()
  if form.get("replay_recipe",{}).get("kind","")!="inner_corner" and not form.get("replay_recipe",{}).has("inner_connections"):continue
  expected[form.id]=form.faces
  for point:Vector3 in form.faces:
   var world:Vector3=form.transform*point
   if absf(world.y-form.base)>.001:continue
   feet+=1
   if world.y>TerrainSurfaceField.surface_y(region,world.x,world.z)-.05:floating+=1
 assert_gt(expected.size(),0)
 assert_gt(feet,20)
 assert_eq(floating,0)
 assert_eq(whole.collision_faces.size(),total)
 var actual:Dictionary={};var duplicates:=0
 for lo:Vector2i in [Vector2i(-3,-3),Vector2i(0,-3),Vector2i(-3,0),Vector2i(0,0)]:
  var part:=rocks.compute(region,lo.x,lo.y,3,2697992464)
  for form:Dictionary in part.placements:
   if form.get("replay_recipe",{}).get("kind","")!="inner_corner" and not form.get("replay_recipe",{}).has("inner_connections"):continue
   if actual.has(form.id):duplicates+=1
   actual[form.id]=form.faces
 assert_eq(duplicates,0)
 assert_eq(actual,expected)

func test_inner_solids_remain_closed_on_short_and_tall_walls()->void:
 for height:float in [4,8,32,64]:
  var form:=CORNER.make_inner(Transform3D.IDENTITY,height,17)
  var edges:Dictionary={};var degenerate:=0
  for i in range(0,form.faces.size(),3):
   var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
   if (b-a).cross(c-a).length_squared()<1e-14:degenerate+=1
   for j in 3:
    a=form.faces[i+j];b=form.faces[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  var bad:=0
  for count:int in edges.values():
   if count!=2:bad+=1
  assert_eq(bad,0)
  assert_eq(degenerate,0)
  assert_lte(form.bounds.end.y,height+.001)

func test_inner_native_resources_are_prepared_before_worker_placement()->void:
 CORNER.prepare()
 var thread:=Thread.new()
 var pose:=Transform3D(Basis(Vector3.UP,PI*.5),Vector3(10.5,0,10.5))
 var expected:=CORNER.make_inner(pose,8,2697992464)
 assert_eq(thread.start(func():return CORNER.make_inner(pose,8,2697992464)),OK)
 var actual:Dictionary=thread.wait_to_finish()
 assert_eq(actual.faces,expected.faces)
 assert_eq(actual.native_roots,expected.native_roots)

func test_inner_join_respects_complete_public_footprint()->void:
 var dry:=CORNER.formations([Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(0,4,0))],17,null,null,true)
 var box:AABB=dry[0].bounds
 var strip:=Rect2(Vector2(box.end.x-.1,box.position.z),Vector2(.2,box.size.z))
 var ground:=FeatureGroundField.new([], [FeatureGroundShape.axis_rect(strip)],0)
 var context:=FeatureContext.new(Rect2(-1000,-1000,2000,2000),ground,EnvironmentInstancePayload.new())
 var occupied:=CORNER.formations([Transform3D.IDENTITY,Transform3D(Basis.IDENTITY,Vector3(0,4,0))],17,null,context,true)
 assert_eq(occupied.size(),0)
