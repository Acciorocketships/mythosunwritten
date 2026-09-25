extends RefCounted
const CRAGS=preload("res://tests/fixtures/september19/inner-ledge-levels/candidate.gd")
const FLOOR=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
static func apply(forms:Array)->void:
 CRAGS.prepare()
 var joins:Dictionary={}
 for i in forms.size():
  for corner:Vector3 in forms[i].replay_recipe.get("inner_connections",[]):
   if not joins.has(corner):joins[corner]=[]
   joins[corner].append(i)
 var controls:Dictionary={}
 for corner:Vector3 in joins:
  var parents:Array=joins[corner]
  if parents.size()!=2:continue
  parents.sort_custom(func(a:int,b:int)->bool:
   if forms[a].replay_recipe.height!=forms[b].replay_recipe.height:return forms[a].replay_recipe.height>forms[b].replay_recipe.height
   return forms[a].anchor<forms[b].anchor)
  var driver:Dictionary=forms[parents[0]]
  var local:Vector3=driver.transform.affine_inverse()*corner
  var height:float=minf(forms[parents[0]].replay_recipe.height,forms[parents[1]].replay_recipe.height)
  var sample_x:float=local.x-signf(local.x)*3.0
  var cuts:Array=CRAGS.sample_cuts(driver.transform,driver.replay_recipe.height,sample_x,driver.replay_recipe.seed)
  cuts=cuts.filter(func(c:Array)->bool:return c[0]>.4 and c[0]<height-.9 and c[1]>.12)
  if cuts.is_empty():continue
  var reaches:Array=[]
  for parent:int in parents:
   var local_corner:Vector3=forms[parent].transform.affine_inverse()*corner
   var reach:=1.5
   for p:Vector3 in forms[parent].faces:
    if absf(p.x-local_corner.x)<=6.0 and p.y<=height-.4:reach=maxf(reach,p.z)
   reaches.append(reach)
  for n in 2:
   var parent:int=parents[n]
   if not controls.has(parent):controls[parent]=[]
   var root:Vector3=forms[parent].transform.affine_inverse()*corner
   var reach:float=reaches[1-n]
   controls[parent].append({"x":root.x,"corner":corner,"cuts":cuts,"height":height,"inner_radius":reach+.25,"radius":reach+4.0})
  print("SHARED_LEDGE corner=",corner," cuts=",cuts," reach=",reaches)
 for index:int in controls:
  var old:Dictionary=forms[index];var r:Dictionary=old.replay_recipe
  var fresh:Dictionary=CRAGS.make(old.transform,r.width,r.height,r.seed,null,r.left_end,r.right_end,controls[index])[0]
  fresh.id=old.id;fresh.anchor=old.anchor
  fresh.replay_recipe["inner_connections"]=r.inner_connections
  fresh.replay_recipe["ledge_joins"]=controls[index]
  FLOOR._restore_floor(fresh,FLOOR._bounds(old.faces).position.y)
  forms[index]=fresh
