extends RefCounted
static func columns(form:Dictionary)->Dictionary:
 var rows:Dictionary={}
 for p:Vector3 in form.green:
  if not rows.has(p.x):rows[p.x]={}
  rows[p.x][Vector2(p.z,p.y)]=true
 var result:Dictionary={}
 for x:float in rows:
  var points:Array=rows[x].keys()
  points.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.y<b.y)
  var groups:Array=[]
  for p:Vector2 in points:
   if groups.is_empty() or p.y-groups[-1][-1].y>.55:groups.append([])
   groups[-1].append(p)
  result[x]=[]
  for group:Array in groups:
   group.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.x<b.x)
   if group[-1].x-group[0].x>.01:result[x].append(group)
 return result
static func nearest_row(rows:Dictionary,x:float,target:float=INF)->Array:
 var chosen:float=INF;var distance:=INF
 for key:float in rows:
  if not rows[key].is_empty() and absf(key-x)<distance:chosen=key;distance=absf(key-x)
 if not is_finite(chosen):return []
 if not is_finite(target):return rows[chosen]
 var best:Array=[];var gap:=INF
 for group:Array in rows[chosen]:
  var height:float=(group[0].y+group[-1].y)*.5
  if absf(height-target)<gap:gap=absf(height-target);best=group
 return best if gap<1.0 else []
static func apply(forms:Array)->void:
 var joins:Dictionary={}
 for i in forms.size():
  for corner:Vector3 in forms[i].replay_recipe.get("inner_connections",[]):
   if not joins.has(corner):joins[corner]=[]
   joins[corner].append(i)
 for corner:Vector3 in joins:
  var parents:Array=joins[corner]
  if parents.size()!=2:continue
  var profiles:Array=[columns(forms[parents[0]]),columns(forms[parents[1]])]
  var samples:Array=[]
  for n in 2:
   var local:Vector3=forms[parents[n]].transform.affine_inverse()*corner
   samples.append(nearest_row(profiles[n],local.x-signf(local.x)*3.0))
  var best:=0.0;var target:=0.0
  for a:Array in samples[0]:
   for b:Array in samples[1]:
    var ay:float=(a[0].y+a[-1].y)*.5;var by:float=(b[0].y+b[-1].y)*.5
    if absf(ay-by)>1.0:continue
    var score:float=minf(a[-1].x-a[0].x,b[-1].x-b[0].x)/(1.0+absf(ay-by))
    if score>best:best=score;target=(ay+by)*.5
  if best<=0.0:continue
  var reaches:Array=[]
  for n in 2:
   var f:Dictionary=forms[parents[n]];var local:Vector3=f.transform.affine_inverse()*corner
   var reach:=1.5
   for p:Vector3 in f.green:
    if absf(p.x-local.x)<6.0 and absf(p.y-target)<.6:reach=maxf(reach,p.z)
   reaches.append(reach)
  print("WARP_JOIN corner=",corner," target=",target," reach=",reaches)
  for n in 2:
   warp(forms[parents[n]],corner,target,reaches[1-n]+.3,reaches[1-n]+4.0,profiles[n])
static func interpolate(group:Array,z:float)->float:
 if z<=group[0].x:return group[0].y
 for i in range(1,group.size()):
  if z<=group[i].x:
   var span:float=group[i].x-group[i-1].x
   return lerpf(group[i-1].y,group[i].y,(z-group[i-1].x)/span) if span>.0001 else group[i].y
 return group[-1].y
static func warp(form:Dictionary,corner:Vector3,target:float,inner_radius:float,radius:float,rows:Dictionary)->void:
 var local:Vector3=form.transform.affine_inverse()*corner
 var selected:Dictionary={}
 for x:float in rows:
  var group:=nearest_row(rows,x,target)
  if not group.is_empty():selected[x]=group
 var keys:Array=selected.keys();keys.sort()
 var mapping:Dictionary={};var maximum:=0.0
 for p:Vector3 in form.faces:
  if mapping.has(p):continue
  var q:=p
  var w:float=1.0-smoothstep(inner_radius,radius,absf(p.x-local.x))
  w*=smoothstep(0.0,.5,p.z)*smoothstep(0.0,.6,p.y)*(1.0-smoothstep(float(form.replay_recipe.height)-1.0,float(form.replay_recipe.height)-.25,p.y))
  if w>0.0 and not keys.is_empty():
   var hi:int=keys.bsearch(p.x);var lo:int=maxi(0,hi-1);hi=mini(hi,keys.size()-1)
   var a:float=keys[lo];var b:float=keys[hi]
   var row_y:float=lerpf(interpolate(selected[a],p.z),interpolate(selected[b],p.z),(p.x-a)/(b-a)) if b>a else interpolate(selected[a],p.z)
   var dy:float=clampf(target-row_y,-.55,.55)
   w*=1.0-smoothstep(.25,1.45,absf(p.y-row_y))
   q.y+=dy*w
  mapping[p]=q.snapped(Vector3.ONE*.0001);maximum=maxf(maximum,absf(q.y-p.y))
 for field:String in ["faces","green"]:
  var values:PackedVector3Array=form[field]
  for i in values.size():values[i]=mapping[values[i]]
  form[field]=values
 var box:=AABB(form.faces[0],Vector3.ZERO)
 for p:Vector3 in form.faces:box=box.expand(p)
 form.bounds=form.transform*box
 print("WARP_FORM ",form.id," maximum=",maximum)
