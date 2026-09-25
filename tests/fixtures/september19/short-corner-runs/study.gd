extends RefCounted
const CRAGS=preload("res://tests/fixtures/september19/short-corner-runs/crags.gd")
const LEDGES=preload("res://scripts/terrain/field/CliffLedgeJoin.gd")
## Isolated art experiment at the pinned native short turn. No production admission.
static func apply(forms:Array)->bool:
 CRAGS.prepare()
 var records:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/101-short-corner-runs/panels.bin",FileAccess.READ).get_var()
 var corner:Dictionary={};var narrow:Dictionary={};var right:Dictionary={}
 for form:Dictionary in forms:
  if form.replay_recipe.kind=="inner_corner" and form.anchor.distance_to(Vector3(-421.5,28,-349.5))<.01:corner=form
  if form.replay_recipe.kind=="wall" and form.transform.origin.distance_to(Vector3(-414,28,-349.5))<.01:right=form
 for record:Dictionary in records:
  if record.pose.origin.distance_to(Vector3(-421.5,28,-346.5))<.01:narrow=record
 if corner.is_empty() or narrow.is_empty() or right.is_empty():
  push_error("Study requires the complete corner and both native wall runs");return false
 var tall_pose:Transform3D=narrow.pose;tall_pose.origin+=tall_pose.basis.x*1.5
 # Below the adjoining four-metre wall the section continues through the turn.
 # Only its exposed upper portion returns to the existing backing wall.
 var tall:Dictionary=CRAGS.make(tall_pose,6,8,2697992464,null,true,true,[],Vector2(0,4))[0]
 var low_pose:Transform3D=right.transform;low_pose.origin-=low_pose.basis.x*1.5
 # The omitted three-metre panel belongs to this same-height run. Generate it
 # with the complete existing neighbour so its ledge does not become a dash.
 var low:Dictionary=CRAGS.make(low_pose,15,4,2697992464,null,true,true)[0]
 var pair:Array=[tall,low]
 var controls:=LEDGES.controls(pair,corner.anchor)
 print("RUN_STUDY controls=",controls)
 for i in pair.size():
  pair[i].replay_recipe["inner_connections"]=[corner.anchor]
  if not controls.is_empty():
   LEDGES.apply(pair[i],[controls[i]])
   pair[i].replay_recipe["ledge_joins"]=[controls[i]]
 forms.erase(corner);forms.erase(right);forms.append_array(pair)

 return true
