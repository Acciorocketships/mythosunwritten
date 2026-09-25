extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const CAPS=preload("res://scripts/terrain/field/CliffRockEndCaps.gd")
const SOURCE="res://docs/qa/2026-09-19-manual/99-height-transition/join/before-forms.bin"
func test_deformed_production_end_caps_stay_inside_their_actual_outline()->void:
 CRAGS.prepare()
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var old_outside:=0;var new_outside:=0;var new_degenerate:=0;var checked:=0
 for form:Dictionary in forms:
  if form.replay_recipe.kind!="wall":continue
  var before:=check_caps(form)
  if before.outside==0:continue
  old_outside+=before.outside;checked+=1
  var current:=REPLAY.rebuild(form.transform,form.faces,form.replay_recipe,CRAGS,CORNER)
  var after:=check_caps(current)
  new_outside+=after.outside;new_degenerate+=after.degenerate
 assert_eq(checked,3)
 assert_eq(old_outside,8,"Pin the actual prior production failure")
 assert_eq(new_outside,0,"Shaped end caps cannot cross their own outline")
 assert_eq(new_degenerate,0)
func check_caps(form:Dictionary)->Dictionary:
 var recipe:Dictionary=form.replay_recipe
 var checked:=0;var outside:=0;var degenerate:=0
 var half:float=recipe.width*.5
 for end:float in [-half,half]:
  var side:Array=[];var edges:Dictionary={}
  for i in range(0,form.faces.size(),3):
   var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
   if a.x!=end or b.x!=end or c.x!=end:continue
   var tri:Array=[Vector2(a.z,a.y),Vector2(b.z,b.y),Vector2(c.z,c.y)];side.append(tri)
   for j in 3:
    var edge:Array=[tri[j],tri[(j+1)%3]];edge.sort();edges[edge]=edges.get(edge,0)+1
  if side.is_empty():continue
  var adjacent:Dictionary={}
  for edge:Array in edges:
   if edges[edge]!=1:continue
   for j in 2:
    if not adjacent.has(edge[j]):adjacent[edge[j]]=[]
    adjacent[edge[j]].append(edge[1-j])
  var outline:=PackedVector2Array();var point:Vector2=adjacent.keys()[0];var previous:=Vector2(INF,INF)
  for step in adjacent.size():
   assert(adjacent[point].size()==2)
   outline.append(point)
   var next:Vector2=adjacent[point][0]
   if next==previous:next=adjacent[point][1]
   previous=point;point=next
  assert(point==outline[0])
  for tri:Array in side:
   var a:Vector2=tri[0];var b:Vector2=tri[1];var c:Vector2=tri[2]
   if absf((b-a).cross(c-a))<.0000001:degenerate+=1;continue
   checked+=1
   var escaped:=false
   for weights:Vector3 in [Vector3(.333333,.333333,.333334),Vector3(.8,.1,.1),Vector3(.1,.8,.1),Vector3(.1,.1,.8)]:
    var sample:Vector2=a*weights.x+b*weights.y+c*weights.z
    if not Geometry2D.is_point_in_polygon(sample,outline):escaped=true
   if escaped:outside+=1
 return {"outside":outside,"degenerate":degenerate,"checked":checked}

func test_cap_repair_preserves_surface_roots_and_closed_edges_and_is_idempotent()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 var changed:=0;var changed_surface:=0;var bad_edges:=0;var lost_vertices:=0;var nonrepeatable:=0
 for form:Dictionary in forms:
  if form.replay_recipe.kind!="wall":continue
  var before:Dictionary=form.duplicate(true)
  CAPS.rebuild(form)
  if before.faces==form.faces:continue
  changed+=1
  var half:float=form.replay_recipe.width*.5
  var surfaces:Array=[PackedVector3Array(),PackedVector3Array()];var vertices:Array=[{},{}]
  for n in 2:
   var f:Dictionary=before if n==0 else form
   for p:Vector3 in f.faces:vertices[n][p]=true
   for i in range(0,f.faces.size(),3):
    var a:Vector3=f.faces[i];var b:Vector3=f.faces[i+1];var c:Vector3=f.faces[i+2]
    if absf(a.x)==half and b.x==a.x and c.x==a.x:continue
    surfaces[n].append_array(PackedVector3Array([a,b,c]))
  if surfaces[0]!=surfaces[1] or before.green!=form.green:changed_surface+=1
  if vertices[0]!=vertices[1]:lost_vertices+=1
  var edges:Dictionary={}
  for i in range(0,form.faces.size(),3):
   for j in 3:
    var edge:Array=[form.faces[i+j],form.faces[i+(j+1)%3]];edge.sort();edges[edge]=edges.get(edge,0)+1
  for count:int in edges.values():
   if count!=2:bad_edges+=1
  var once:PackedVector3Array=form.faces.duplicate()
  CAPS.rebuild(form)
  if once!=form.faces:nonrepeatable+=1
 assert_gt(changed,0)
 assert_eq(changed_surface,0)
 assert_eq(lost_vertices,0)
 assert_eq(bad_edges,0)
 assert_eq(nonrepeatable,0)
