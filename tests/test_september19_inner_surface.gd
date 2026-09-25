extends GutTest
const CONNECTIONS=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const CONTACTS=preload("res://tests/fixtures/september19/corner-surface-loft/contacts.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/101-short-corner-runs/before/before-forms.bin"
const PROBES=[Vector3(-416.1061,30.38997,-343.5995),Vector3(-415.9913,30.08433,-344.4205),Vector3(-415.384,29.68497,-345.2663),Vector3(-413.9415,29.20347,-345.1856),Vector3(-412.8981,28.92977,-345.572)]
func test_short_stepped_inner_turn_continues_the_actual_supported_ledge()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 CONNECTIONS.apply(forms)
 var gaps:=0
 for point:Vector3 in PROBES:
  var found:=CONTACTS.height(forms,point+Vector3.UP*.15)
  if not is_finite(found) or absf(found-point.y)>.15:gaps+=1
 assert_eq(gaps,0,"The photographed short turn must carry rock beneath the connecting ledge")

const SURFACE=preload("res://scripts/terrain/field/CliffInnerSurface.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
func test_join_is_closed_replayable_and_keeps_the_original_parents()->void:
 var before:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var forms:Array=before.duplicate(true)
 assert_eq(SURFACE.apply(forms),1)
 var changed:=0;var open_edges:=0;var degenerate:=0;var turf_outside:=0
 for i in forms.size():
  if forms[i].faces==before[i].faces:continue
  changed+=1
  assert_eq(before[i].replay_recipe.kind,"inner_corner")
  assert_eq(forms[i].id,before[i].id)
  assert_eq(forms[i].anchor,before[i].anchor)
  var form:Dictionary=forms[i];var edges:Dictionary={};var triangles:Dictionary={}
  for j in range(0,form.faces.size(),3):
   var a:Vector3=form.faces[j];var b:Vector3=form.faces[j+1];var c:Vector3=form.faces[j+2]
   if (b-a).cross(c-a).length_squared()<1e-16:degenerate+=1
   var tri:Array=[a,b,c];tri.sort();triangles[tri]=true
   for k in 3:
    var edge:Array=[form.faces[j+k],form.faces[j+(k+1)%3]];edge.sort();edges[edge]=edges.get(edge,0)+1
  for count:int in edges.values():
   if count!=2:open_edges+=1
  for j in range(0,form.green.size(),3):
   var tri:Array=[form.green[j],form.green[j+1],form.green[j+2]];tri.sort()
   if not triangles.has(tri):turf_outside+=1
  var replay:=REPLAY.rebuild(form.transform,form.faces,form.replay_recipe,CRAGS,CORNER)
  assert_true(replay.faces==form.faces)
  assert_true(replay.green==form.green)
 assert_eq(changed,1)
 assert_eq(open_edges,0)
 assert_eq(degenerate,0)
 assert_eq(turf_outside,0)
 assert_eq(SURFACE.apply(forms),0,"An existing surface is not extended again")
func test_rejecting_a_complete_join_preserves_all_original_geometry()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var before:Array=forms.duplicate(true)
 var rejected:Array=[]
 var count:=SURFACE.apply(forms,null,null,func(form:Dictionary)->bool:rejected.append(form.bounds);return true)
 assert_eq(count,0)
 assert_eq(rejected.size(),1)
 assert_true(forms==before)
func test_parent_discovery_is_order_independent_and_rotates_with_native_walls()->void:
 var before:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var reference:Array=before.duplicate(true)
 SURFACE.apply(reference)
 var target:Dictionary={}
 for form:Dictionary in reference:
  if form.replay_recipe.kind=="inner_surface":target=form
 assert_false(target.is_empty())
 for turns in 4:
  var forms:Array=before.duplicate(true);forms.reverse()
  # Exact cardinal bases avoid injecting floating-point rotation noise into
  # an otherwise exact world-grid ownership check.
  var basis:=Basis(Vector3.UP,turns*PI*.5)
  basis=Basis(basis.x.round(),basis.y.round(),basis.z.round())
  var shift:=Transform3D(basis,Vector3(96,0,-144))
  for form:Dictionary in forms:
   form.transform=shift*form.transform;form.anchor=shift*form.anchor;form.bounds=shift*form.bounds
  assert_eq(SURFACE.apply(forms),1)
  var result:Dictionary={}
  for form:Dictionary in forms:
   if form.replay_recipe.kind=="inner_surface":result=form
  assert_true(result.faces==target.faces,"The local join must be identical in every cardinal orientation")
  assert_true(result.green==target.green)
  assert_eq(result.anchor,shift*target.anchor)
func test_different_buried_parent_feet_keep_a_fully_buried_closing_floor()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 SURFACE.apply(forms)
 var recipe:Dictionary={}
 for form:Dictionary in forms:
  if form.replay_recipe.kind=="inner_surface":recipe=form.replay_recipe.duplicate(true)
 var b:PackedVector2Array=recipe.b
 b[-1].y-=1.0;recipe.b=b
 var result:=SURFACE.rebuild(Transform3D.IDENTITY,recipe)
 var feet:Dictionary={}
 for p:Vector3 in result.faces:
  if absf(p.x+1.2)>.001 and absf(p.z+1.2)>.001:continue
  var key:=Vector2(p.x,p.z);feet[key]=minf(feet.get(key,INF),p.y)
 var suspended:=0
 for y:float in feet.values():
  if y>b[-1].y+.001:suspended+=1
 assert_eq(suspended,0,"The joining foot cannot slope upward from its lowest native bearing")
func test_fresh_world_replay_retains_the_exact_native_burial_height()->void:
 var saved:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/102-corner-surface-loft/replay-mismatch.bin",FileAccess.READ).get_var()
 var result:=REPLAY.rebuild(saved[0],saved[1],saved[3],CRAGS,CORNER)
 assert_true(result.faces==saved[1],"Preserve the actual native floor even when its difference is below one micrometre")
 assert_true(result.green==saved[2])
