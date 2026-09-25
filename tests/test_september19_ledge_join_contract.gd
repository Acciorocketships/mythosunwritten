extends GutTest
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const OLD_JOIN=preload("res://tests/fixtures/september19/inner-ledge-levels/production-before-CliffInnerConnections.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/92-inner-shared-surface/extended/before-forms.bin"
## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func source()->Array:
 ROCKS.prepare()
 return FileAccess.open(SOURCE,FileAccess.READ).get_var()
func test_join_preserves_existing_footprints_topology_roots_and_crowns()->void:
 var before:=source();var after:=source();OLD_JOIN.apply(before);JOIN.apply(after)
 var old:Dictionary={}
 for f:Dictionary in before:old[f.id]=f
 var changed:=0;var count_changed:=0;var horizontal_changes:=0;var anchor_changes:=0;var root_or_crown_changes:=0;var maximum:=0.0
 for f:Dictionary in after:
  var previous:Dictionary=old[f.id]
  if not f.replay_recipe.has("ledge_joins"):
   assert_eq(f.faces,previous.faces)
   continue
  changed+=1
  for field:String in ["faces","green"]:
   if f[field].size()!=previous[field].size():count_changed+=1;continue
   for i in f[field].size():
    var a:Vector3=previous[field][i];var b:Vector3=f[field][i]
    if a.x!=b.x or a.z!=b.z:horizontal_changes+=1
    if (a.y<=.01 or a.y>=float(f.replay_recipe.height)-.25) and a!=b:root_or_crown_changes+=1
    maximum=maxf(maximum,absf(a.y-b.y))
  if f.anchor!=previous.anchor or f.transform!=previous.transform:anchor_changes+=1
 print("LEDGE_JOIN_CONTRACT changed=",changed," max_vertical=",maximum)
 assert_eq(changed,4);assert_eq(count_changed,0);assert_eq(horizontal_changes,0)
 assert_eq(root_or_crown_changes,0);assert_eq(anchor_changes,0);assert_lte(maximum,.5501)
func test_saved_controls_reconstruct_the_exact_final_rock_and_turf()->void:
 var forms:=source();JOIN.apply(forms)
 var checked:=0
 for f:Dictionary in forms:
  if not f.replay_recipe.has("ledge_joins"):continue
  var rebuilt:=REPLAY.rebuild(f.transform,f.faces,f.replay_recipe,CRAGS,CORNER)
  assert_eq(rebuilt.faces,f.faces);assert_eq(rebuilt.green,f.green)
  assert_eq(rebuilt.replay_recipe.ledge_joins,f.replay_recipe.ledge_joins)
  checked+=1
 assert_eq(checked,4)
func test_pair_controls_are_symmetric_and_do_not_depend_on_parent_iteration_order()->void:
 var forms:=source();OLD_JOIN.apply(forms)
 var pair:Array=[];var corner:=Vector3(-445.5,32,-301.5)
 for f:Dictionary in forms:
  if corner in f.replay_recipe.get("inner_connections",[]):pair.append(f)
 var controls:=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
 var first:=controls.controls(pair,corner);pair.reverse();var second:=controls.controls(pair,corner);second.reverse()
 assert_eq(first,second)
 assert_eq(first[0].target,first[1].target)
