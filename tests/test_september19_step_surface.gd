extends GutTest
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/104-three-way-surface/raster/before-forms.bin"
const STEP=preload("res://scripts/terrain/field/CliffStepSurface.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
func test_raised_neighbor_meets_the_actual_tall_wall_end_without_an_upper_blade()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 JOIN.apply(forms)
 var tall:Dictionary={};var raised:Dictionary={}
 for form:Dictionary in forms:
  if form.transform.origin.distance_to(Vector3(-445.5,28,-267))<.01:tall=form
  if form.transform.origin.distance_to(Vector3(-445.5,32,-289.5))<.01:raised=form
 assert_false(tall.is_empty());assert_false(raised.is_empty())
 var misses:=0;var gaps:=0
 for y:float in [33.5,34,35,36,37,38,39]:
  var a:=depth(tall,Vector3(-445.5,y,-278.9999))
  var b:=depth(raised,Vector3(-445.5,y,-279.0001))
  if not is_finite(a) or not is_finite(b):misses+=1
  elif absf(a-b)>.002:gaps+=1
 assert_eq(misses,0,"Both sides must retain their real rock surface at the handoff")
 assert_eq(gaps,0,"An independent raised-base formation cannot project beyond the adjoining tall profile at the seam")
func test_only_the_raised_run_changes_and_its_saved_recipe_replays_exactly()->void:
 var before:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var forms:Array=before.duplicate(true)
 assert_eq(STEP.apply(forms),1)
 var changed:=0
 for i in forms.size():
  if forms[i].faces==before[i].faces:continue
  changed+=1
  var f:Dictionary=forms[i]
  assert_eq(f.id,before[i].id);assert_eq(f.anchor,before[i].anchor)
  assert_eq(f.transform,before[i].transform)
  var rebuilt:=REPLAY.rebuild(f.transform,f.faces,f.replay_recipe,CRAGS,CORNER)
  assert_true(rebuilt.faces==f.faces,"Saved geometry must not silently reconstruct the old overlapping end")
  assert_true(rebuilt.green==f.green)
 assert_eq(changed,1)
 assert_eq(STEP.apply(forms),0)
func test_native_rotation_and_reversed_input_keep_the_same_local_surface()->void:
 var original:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var reference:Array=original.duplicate(true);STEP.apply(reference)
 var expected:Dictionary={}
 for f:Dictionary in reference:
  if f.replay_recipe.has("step_surface"):expected=f
 for quarter in 4:
  var basis:=Basis(Vector3.UP,quarter*PI*.5)
  var turn:=Transform3D(Basis(basis.x.round(),basis.y.round(),basis.z.round()),Vector3(96,0,-144))
  var forms:Array=original.duplicate(true);forms.reverse()
  for f:Dictionary in forms:
   f.transform=turn*f.transform;f.anchor=turn*f.anchor;f.bounds=turn*f.bounds
  assert_eq(STEP.apply(forms),1)
  for f:Dictionary in forms:
   if not f.replay_recipe.has("step_surface"):continue
   assert_true(f.faces==expected.faces)
   assert_true(f.green==expected.green)
func test_rejected_candidate_does_not_cut_the_original_run()->void:
 var original:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var forms:Array=original.duplicate(true);var rejected:Array=[]
 assert_eq(STEP.apply(forms,null,null,func(f:Dictionary)->bool:rejected.append(f.id);return true),0)
 assert_eq(rejected.size(),1)
 assert_true(forms==original)
func test_turf_is_backed_and_crowns_and_feet_keep_their_original_limits()->void:
 var original:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var forms:Array=original.duplicate(true);STEP.apply(forms)
 var violations:=0;var green_missing:=0
 for index in forms.size():
  var f:Dictionary=forms[index]
  if not f.replay_recipe.has("step_surface"):continue
  var low:=INF;var high:=-INF;var triangles:Dictionary={}
  for p:Vector3 in original[index].faces:low=minf(low,p.y);high=maxf(high,p.y)
  for i in range(0,f.faces.size(),3):
   var tri:Array=[f.faces[i],f.faces[i+1],f.faces[i+2]];tri.sort();triangles[tri]=true
   for p:Vector3 in tri:
    if p.y<low-.0001 or p.y>high+.0001:violations+=1
  for i in range(0,f.green.size(),3):
   var tri:Array=[f.green[i],f.green[i+1],f.green[i+2]];tri.sort()
   if not triangles.has(tri):green_missing+=1
 assert_eq(violations,0);assert_eq(green_missing,0)
func test_flat_ledge_samples_do_not_leave_unpaired_closing_edges()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var();STEP.apply(forms)
 var open_edges:=0
 for f:Dictionary in forms:
  if not f.replay_recipe.has("step_surface"):continue
  var edges:Dictionary={}
  for i in range(0,f.faces.size(),3):
   for j in 3:
    var a:Vector3=f.faces[i+j].snapped(Vector3.ONE*.0001);var b:Vector3=f.faces[i+(j+1)%3].snapped(Vector3.ONE*.0001)
    if a==b:continue
    var edge:Array=[a,b];edge.sort();edges[edge]=edges.get(edge,0)+1
  for count:int in edges.values():
   if count!=2:open_edges+=1
 assert_eq(open_edges,0,"Every physical boundary edge must belong to exactly two faces")
func test_existing_turf_outside_the_join_is_preserved()->void:
 var original:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var();var forms:Array=original.duplicate(true)
 STEP.apply(forms)
 var missing:=0;var checked:=0
 for index in forms.size():
  var f:Dictionary=forms[index]
  if not f.replay_recipe.has("step_surface"):continue
  var r:Dictionary=f.replay_recipe.step_surface;var current:Dictionary={}
  for i in range(0,f.green.size(),3):
   var tri:Array=[]
   for j in 3:tri.append(f.green[i+j].snapped(Vector3.ONE*.0001))
   tri.sort();current[tri]=true
  var old:PackedVector3Array=original[index].green
  for i in range(0,old.size(),3):
   if minf((old[i].x-r.finish)*r.side,minf((old[i+1].x-r.finish)*r.side,(old[i+2].x-r.finish)*r.side))<.001:continue
   var tri:Array=[]
   for j in 3:tri.append(old[i+j].snapped(Vector3.ONE*.0001))
   tri.sort();checked+=1
   if not current.has(tri):missing+=1
 assert_gt(checked,50);assert_eq(missing,0)
func test_left_handed_step_has_the_same_supported_front_profile()->void:
 var original:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var();var pair:Array=[]
 for f:Dictionary in original:
  if minf(f.transform.origin.distance_to(Vector3(-445.5,28,-267)),f.transform.origin.distance_to(Vector3(-445.5,32,-289.5)))<.01:pair.append(f)
 pair.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.transform.origin.y<b.transform.origin.y)
 pair[0].transform=Transform3D.IDENTITY
 pair[1].transform=Transform3D(Basis.IDENTITY,Vector3(22.5,4,0))
 var mirrored:Array=pair.duplicate(true)
 for f:Dictionary in mirrored:
  f.transform.origin.x=-f.transform.origin.x
  for channel:String in ["faces","green"]:
   var values:PackedVector3Array=f[channel]
   for i in range(0,values.size(),3):
    for j in 3:values[i+j].x=-values[i+j].x
    var swap:=values[i+1];values[i+1]=values[i+2];values[i+2]=swap
   f[channel]=values
 assert_eq(STEP.apply(pair),1);assert_eq(STEP.apply(mirrored),1)
 var mismatch:=0
 for x:float in [12.01,12.5,13,14,14.99]:
  for y:float in [4.2,5,6,8,10,11.5]:
   var a:=depth(pair[1],Vector3(x,y,0));var b:=depth(mirrored[1],Vector3(-x,y,0))
   if not is_finite(a) or not is_finite(b) or absf(a-b)>.001:mismatch+=1
 assert_eq(mismatch,0)
func depth(form:Dictionary,world:Vector3)->float:
 var inverse:Transform3D=form.transform.affine_inverse()
 var origin:Vector3=inverse*(world+form.transform.basis.z*20)
 var result:=-INF
 for i in range(0,form.faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.FORWARD,form.faces[i],form.faces[i+1],form.faces[i+2])
  if hit!=null:result=maxf(result,hit.z)
 return result
