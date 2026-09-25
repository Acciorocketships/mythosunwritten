extends GutTest
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin"
func forms()->Array:
 ROCKS.prepare()
 return FileAccess.open(SOURCE,FileAccess.READ).get_var()
func test_reported_tall_parent_keeps_bearing_through_the_lower_inner_join()->void:
 var source:=forms();var original:Dictionary={}
 for form:Dictionary in source:
  if (form.anchor as Vector3).distance_to(Vector3(-445.5,28,-265.5))<.001:original=form.duplicate();break
 assert_false(original.is_empty())
 if original.is_empty():return
 JOIN.apply(source)
 var selected:Dictionary={}
 for form:Dictionary in source:
  if form.id==original.id:selected=form
 var failures:=0
 for along:float in [.5,1.0,1.5]:
  for y:float in [1,2,3]:
   var point:Vector3=original.transform*Vector3(original.replay_recipe.width*.5-along,y,0)
   var origin:Vector3=selected.transform.affine_inverse()*(point+original.transform.basis.z*20)
   var direction:Vector3=selected.transform.basis.inverse()*(-original.transform.basis.z)
   var depth:=-INF
   for i in range(0,selected.faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(origin,direction,selected.faces[i],selected.faces[i+1],selected.faces[i+2])
    if hit!=null:depth=maxf(depth,(selected.transform*hit-point).dot(original.transform.basis.z))
   if depth<.5:failures+=1
 assert_eq(failures,0,"The last 1.5 m of the tall parent's bottom three metres must continue into the concave junction")
func test_stepped_extension_requires_the_complete_upper_backing()->void:
 for removal:bool in [false,true]:
  var source:=forms()
  for i in range(source.size()-1,-1,-1):
   var form:Dictionary=source[i]
   if (form.anchor as Vector3).distance_to(Vector3(-445.5,32,-288))>.001:continue
   if removal:source.remove_at(i)
   else:form.replay_recipe.height-=4
  JOIN.apply(source)
  var retained:=false
  for form:Dictionary in source:
   if form.replay_recipe.kind=="inner_corner" and (form.anchor as Vector3).distance_to(Vector3(-445.5,28,-277.5))<.001:retained=true
  assert_true(retained,"Missing or short upper backing cannot authorize a taller extension")
func test_stepped_join_selection_survives_all_four_rotations()->void:
 for quarter in 4:
  var source:=forms()
  var turn:=Transform3D(Basis(Vector3.UP,quarter*PI*.5),Vector3.ZERO)
  for form:Dictionary in source:
   form.transform=turn*form.transform
   form.anchor=turn*form.anchor
  var result:=JOIN.apply(source)
  assert_eq(result.connections,2)
  assert_eq(result.changed_walls,4)
func test_generated_step_keeps_whole_and_split_chunk_geometry_and_grounding()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,z:int)->float:return 32.0 if x>=0 else (16.0 if z>=0 else 0.0))
 var region:=plan.compute_region(0,0,8)
 var whole:=ROCKS.compute(region,-2,-2,4,2697992464)
 var expected:Dictionary={};var actual:Dictionary={};var connected:=0;var exposed:=0;var probes:=0
 for form:Dictionary in whole.placements:
  if form.kind!="rock":continue
  expected[form.id]=[form.faces,form.transform,form.anchor]
  if not form.replay_recipe.has("inner_connections"):continue
  connected+=1
  var minimum:=INF
  for p:Vector3 in form.faces:minimum=minf(minimum,p.y)
  var feet:Dictionary={}
  for p:Vector3 in form.faces:
   if absf(p.y-minimum)<.001:feet[p]=true
  for p:Vector3 in feet:
   var world:Vector3=form.transform*p
   probes+=1
   if world.y>TerrainSurfaceField.surface_y(region,world.x,world.z)-.05:exposed+=1
 var duplicates:=0
 for lo:Vector2i in [Vector2i(-2,-2),Vector2i(0,-2),Vector2i(-2,0),Vector2i(0,0)]:
  for form:Dictionary in ROCKS.compute(region,lo.x,lo.y,2,2697992464).placements:
   if form.kind!="rock":continue
   if actual.has(form.id):duplicates+=1
   actual[form.id]=[form.faces,form.transform,form.anchor]
 assert_gt(connected,0);assert_gt(probes,20);assert_eq(exposed,0)
 assert_eq(duplicates,0);assert_eq(actual,expected)
