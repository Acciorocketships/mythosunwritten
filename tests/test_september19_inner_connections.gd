extends GutTest
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const SNAP="res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin"
func source()->Array:
 ROCKS.prepare()
 return FileAccess.open(SNAP,FileAccess.READ).get_var()
func test_photographed_joins_use_existing_walls_and_preserve_owners()->void:
 var forms:=source();var before:Dictionary={}
 for form:Dictionary in forms:before[form.id]=form.duplicate()
 var result:=JOIN.apply(forms)
 assert_eq(result.connections,2);assert_eq(result.changed_walls,4)
 assert_eq(forms.size(),before.size()-2)
 var changed:=0
 for form:Dictionary in forms:
  assert_eq(form.anchor,before[form.id].anchor)
  if form.faces==before[form.id].faces:continue
  changed+=1
  assert_eq(form.replay_recipe.kind,"wall")
  assert_eq(form.replay_recipe.width,before[form.id].replay_recipe.width+3.0)
  assert_almost_eq(form.base,before[form.id].base,.0001)
 assert_eq(changed,4)
func test_complete_reserved_extension_rejects_both_walls_atomically()->void:
 var forms:=source();var old:=forms.duplicate(true)
 var result:=JOIN.apply(forms,null,null,func(form:Dictionary)->bool:return form.transform.origin.x< -440)
 assert_eq(result.connections,0)
 assert_eq(forms,old)
func test_iteration_order_does_not_change_corner_geometry()->void:
 var a:=source();var b:=source();b.reverse()
 JOIN.apply(a);JOIN.apply(b)
 var left:Dictionary={};var right:Dictionary={}
 for f:Dictionary in a:left[f.id]=[f.faces,f.anchor,f.transform]
 for f:Dictionary in b:right[f.id]=[f.faces,f.anchor,f.transform]
 assert_eq(left,right)
func test_extended_sources_remain_closed_and_keep_turf_on_the_solid()->void:
 var forms:=source();var old:Dictionary={}
 for f:Dictionary in forms:old[f.id]=f.faces
 JOIN.apply(forms)
 for form:Dictionary in forms:
  if form.faces==old[form.id]:continue
  var edges:Dictionary={};var triangles:Dictionary={};var degenerate:=0
  for i in range(0,form.faces.size(),3):
   var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
   triangles[[a,b,c]]=true
   if (b-a).cross(c-a).length_squared()<1e-14:degenerate+=1
   for j in 3:
    a=form.faces[i+j];b=form.faces[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  var bad:=0;var missing_turf:=0
  for count:int in edges.values():
   if count!=2:bad+=1
  for i in range(0,form.green.size(),3):
   if not triangles.has([form.green[i],form.green[i+1],form.green[i+2]]):missing_turf+=1
  assert_eq(bad,0);assert_eq(degenerate,0);assert_eq(missing_turf,0)
func test_production_whole_and_chunk_queries_keep_identical_rock_ownership()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return 16.0 if x>=0 or z>=0 else 0.0)
 var region:=plan.compute_region(0,0,8)
 var whole:=ROCKS.compute(region,-3,-3,6,2697992464)
 var expected:Dictionary={};var feet:=0;var floating:=0
 for form:Dictionary in whole.placements:
  if form.kind!="rock":continue
  expected[form.id]=[form.faces,form.transform,form.anchor]
  for p:Vector3 in form.faces:
   var world:Vector3=form.transform*p
   if absf(world.y-form.base)>.001:continue
   feet+=1
   if world.y>TerrainSurfaceField.surface_y(region,world.x,world.z)-.05:floating+=1
 var actual:Dictionary={};var duplicates:=0
 for lo:Vector2i in [Vector2i(-3,-3),Vector2i(0,-3),Vector2i(-3,0),Vector2i(0,0)]:
  for form:Dictionary in ROCKS.compute(region,lo.x,lo.y,3,2697992464).placements:
   if form.kind!="rock":continue
   if actual.has(form.id):duplicates+=1
   actual[form.id]=[form.faces,form.transform,form.anchor]
 assert_gt(feet,20);assert_eq(floating,0);assert_eq(duplicates,0);assert_eq(actual,expected)

func test_join_preparation_is_detached_and_public_reservations_are_atomic()->void:
 var forms:=source();var control:=source()
 var expected:=JOIN.apply(control)
 var thread:=Thread.new()
 assert_eq(thread.start(func():return JOIN.apply(forms)),OK)
 assert_eq(thread.wait_to_finish(),expected)
 assert_eq(forms,control)
 var reserved_forms:=source();var original:=reserved_forms.duplicate(true)
 var changed:Dictionary={}
 for f:Dictionary in control:
  if f.replay_recipe.has("inner_connections"):changed=f;break
 var box:AABB=changed.bounds
 var strip:=Rect2(Vector2(box.position.x,box.position.z),Vector2(.2,box.size.z))
 var ground:=FeatureGroundField.new([], [FeatureGroundShape.axis_rect(strip)],0)
 var context:=FeatureContext.new(Rect2(-1000,-1000,2000,2000),ground,EnvironmentInstancePayload.new())
 var blocked_corner:Vector3=changed.replay_recipe.inner_connections[0]
 var blocked_ids:Dictionary={}
 for f:Dictionary in control:
  if blocked_corner in f.replay_recipe.get("inner_connections",[]):blocked_ids[f.id]=true
 var originals:Dictionary={}
 for f:Dictionary in original:originals[f.id]=f
 assert_eq(JOIN.apply(reserved_forms,null,context).connections,1)
 var retained_corner:=false
 for f:Dictionary in reserved_forms:
  if blocked_ids.has(f.id):assert_eq(f,originals[f.id])
  if f.replay_recipe.kind=="inner_corner" and f.anchor==blocked_corner:retained_corner=true
 assert_true(retained_corner)
func test_unmatched_height_keeps_the_existing_inner_corner()->void:
 var forms:=source()
 for f:Dictionary in forms:
  if f.replay_recipe.kind=="wall":f.replay_recipe.height+=.5
 var old:=forms.duplicate(true)
 assert_eq(JOIN.apply(forms).connections,0)
 assert_eq(forms,old)
