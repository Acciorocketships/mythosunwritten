extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const ROWS="res://tests/fixtures/september19/short-inner-join/native-walls.bin"
func source()->Array:
 ROCKS.prepare()
 var rows:Array=FileAccess.open(ROWS,FileAccess.READ).get_var()
 var forms:Array=ROCKS.formations(rows,2697992464)
 forms.append(CORNER.make_inner(Transform3D(Basis.IDENTITY,Vector3(-421.5,28,-349.5)),4,2697992464))
 return forms
func test_transition_solids_close_and_replay_the_actual_turf_and_rock()->void:
 var forms:=source();JOIN.apply(forms)
 var checked:=0;var bad_edges:=0;var degenerate:=0;var missing_turf:=0;var replay_mismatch:=0
 for f:Dictionary in forms:
  if not f.replay_recipe.has("edge_heights") and not f.replay_recipe.has("inner_connections"):continue
  checked+=1
  var edges:Dictionary={};var tris:Dictionary={}
  for i in range(0,f.faces.size(),3):
   var a:Vector3=f.faces[i];var b:Vector3=f.faces[i+1];var c:Vector3=f.faces[i+2]
   tris[[a,b,c]]=true
   if (c-a).cross(b-a).length_squared()<1e-14:degenerate+=1
   for j in 3:
    a=f.faces[i+j];b=f.faces[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  for n:int in edges.values():
   if n!=2:bad_edges+=1
  for i in range(0,f.green.size(),3):
   if not tris.has([f.green[i],f.green[i+1],f.green[i+2]]):missing_turf+=1
  var rebuilt:=REPLAY.rebuild(f.transform,f.faces,f.replay_recipe,CRAGS,CORNER)
  if rebuilt.faces!=f.faces or rebuilt.green!=f.green:replay_mismatch+=1
 assert_gt(checked,2)
 assert_eq(bad_edges,0);assert_eq(degenerate,0);assert_eq(missing_turf,0);assert_eq(replay_mismatch,0)
func test_short_join_is_order_independent_and_rejection_keeps_original_solids()->void:
 var a:=source();var b:=a.duplicate(true);b.reverse()
 JOIN.apply(a);JOIN.apply(b)
 var by_id:Array=[{},{}]
 for i in 2:
  for f:Dictionary in [a,b][i]:by_id[i][f.id]=[f.faces,f.green,f.anchor,f.transform]
 assert_eq(by_id[0],by_id[1])
 var rejected:=source();var before:=rejected.duplicate(true)
 var result:=JOIN.apply(rejected,null,null,func(_form:Dictionary)->bool:return true)
 assert_eq(result.connections,0);assert_eq(rejected,before)
func test_narrow_isolated_native_column_does_not_gain_a_detached_rock()->void:
 ROCKS.prepare()
 var rows:Array=[]
 for level in 3:rows.append(Transform3D(Basis.IDENTITY,Vector3(1.5,level*4,0)))
 assert_true(ROCKS.formations(rows,2697992464).is_empty())
