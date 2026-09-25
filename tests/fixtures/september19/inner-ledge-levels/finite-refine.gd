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
  var height:float=minf(forms[parents[0]].replay_recipe.height,forms[parents[1]].replay_recipe.height)
  var samples:Array=[]
  for parent:int in parents:
   var f:Dictionary=forms[parent]
   var local:Vector3=f.transform.affine_inverse()*corner
   var sample_x:float=local.x-signf(local.x)*3.0
   var cuts:Array=CRAGS.sample_cuts(f.transform,f.replay_recipe.height,sample_x,f.replay_recipe.seed)
   samples.append(cuts.filter(func(c:Array)->bool:return c[0]>.6 and c[0]<height-.9 and c[1]>.12))
  var chosen:Array=[];var best:=0.0
  for a:Array in samples[0]:
   for b:Array in samples[1]:
    if absf(a[0]-b[0])>1.0:continue
    var score:float=minf(a[1],b[1])/(1.0+absf(a[0]-b[0]))
    if score>best:
     best=score
     chosen=[(a[0]+b[0])*.5,(a[1]+b[1])*.5,(a[2]+b[2])*.5,0.0]
  if chosen.is_empty():continue
  var reaches:Array=[]
  for parent:int in parents:
   var local:Vector3=forms[parent].transform.affine_inverse()*corner
   var reach:=1.5
   for p:Vector3 in forms[parent].faces:
    if absf(p.x-local.x)<=6.0 and absf(p.y-chosen[0])<=1.0:reach=maxf(reach,p.z)
   reaches.append(reach)
  for n in 2:
   var parent:int=parents[n]
   if not controls.has(parent):controls[parent]=[]
   var root:Vector3=forms[parent].transform.affine_inverse()*corner
   var reach:float=reaches[1-n]
   controls[parent].append({"x":root.x,"cuts":[chosen],"height":height,"inner_radius":reach+.25,"radius":reach+3.0})
  print("SHARED_LEDGE corner=",corner," cut=",chosen," reach=",reaches)
 for index:int in controls:
  var old:Dictionary=forms[index];var r:Dictionary=old.replay_recipe
  var fresh:Dictionary=CRAGS.make(old.transform,r.width,r.height,r.seed,null,r.left_end,r.right_end,controls[index])[0]
  fresh.id=old.id;fresh.anchor=old.anchor
  fresh.replay_recipe["inner_connections"]=r.inner_connections
  fresh.replay_recipe["ledge_joins"]=controls[index]
  FLOOR._restore_floor(fresh,FLOOR._bounds(old.faces).position.y)
  forms[index]=fresh
