extends RefCounted
## Shared mossy slope (owner trial, September 23, third pass). One smooth
## surface for all formations instead of one fillet per formation: its reach
## at a height comes from the distance to the nearest cliff foot (wall runs,
## outer-corner arcs, inner-corner arms). Collinear runs therefore join
## without a crease, outer corners become cones reaching as far as the walls
## and inner corners valleys. Every formation's lower vertices are pushed out
## onto it; crag relief survives only in a band below the slope top.
## Parameters are world-space functions of the foot position, so neighbouring
## formations and chunks agree exactly. Worker-pure plain data.
## `sheet` style (owner, September 24, fourth pass): the sheet IS the wall.
## No crag dressing; one slope leaves the wall vertically just under the
## native lip and flattens to the ground. Rock bunches, one rule for every
## rock, sit on it; the sheet swells in a smooth union to meet each rock.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
## Where the slope leaves the wall, outward from the native foot line.
const ANCHOR:=.7
## Quarter superellipse: vertical at the top, tangent to the ground just below
## the base (FOOT).
const POWER:=1.4
const FOOT:=-.05
## Smooth-union radius with the rock at the junction; below ROCK_BAND under the
## top the surface is the slope alone.
const BLEND:=.9
const ROCK_BAND:=2.0
## Free cliff ends taper the slope to nothing over this run.
const FREE_TAPER:=3.5
const CELL:=6.0
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
## Under the `sheet` style the slope tops out this far below the crest, just
## under the native grass lip.
const LIP_GAP:=.3
## The whole-wall solid tops out this far under the plateau grass.
const TOP_GAP:=.02
## The whole-wall sheet leaves the wall further out, over the native lip's
## rocky teeth, which otherwise hang like icicles above the slope.
const SHEET_ANCHOR:=1.0

var _seed:int
var _region:HeightfieldRegion
var _primitives:Array[Dictionary]=[]
var _buckets:Dictionary={}
var _reach:Dictionary={}
var rock_list:Array[Dictionary]=[]

## `focus`: only rocks that can reach this rectangle are placed (a chunk
## computes its halo's lines too; placing their rocks there is wasted work).
var _focus:=Rect2(-1e9,-1e9,2e9,2e9)
func _init(formations:Array,seed_value:int,region:HeightfieldRegion=null,focus:=Rect2(-1e9,-1e9,2e9,2e9))->void:
 _seed=seed_value;_region=region;_focus=focus.grow(16.0)
 for form:Dictionary in formations:
  var recipe:Dictionary=form.get("replay_recipe",{})
  var pose:Transform3D=form.transform
  match recipe.get("kind",""):
   "wall":
    var abut:Vector2i=recipe.get("abut",Vector2i.ZERO);var half:float=float(recipe.width)*.5
    _segment(pose*Vector3(-half,0,0),pose*Vector3(half,0,0),pose.basis.z,pose.origin.y,recipe.height,
     recipe.left_end and abut.x==0,recipe.right_end and abut.y==0)
   "corner":
    _segment(pose*Vector3(-6,0,0),pose*Vector3(-1.5,0,0),pose.basis.z,pose.origin.y,recipe.height)
    _segment(pose*Vector3(0,0,-6),pose*Vector3(0,0,-1.5),pose.basis.x,pose.origin.y,recipe.height)
    var c:=pose*Vector3(-1.5,0,-1.5)
    _add({"arc":true,"c":Vector2(c.x,c.z),"r":1.5,"n1":_flat(pose.basis.z),"n2":_flat(pose.basis.x),
     "base":pose.origin.y,"height":float(recipe.height)},[Vector2(c.x,c.z)])
   "inner_corner":
    _segment(pose.origin,pose*Vector3(6,0,0),pose.basis.z,pose.origin.y,recipe.height)
    _segment(pose.origin,pose*Vector3(0,0,6),pose.basis.x,pose.origin.y,recipe.height)
 _find_open_ends()
 _build_groups()
 _find_rocks()
 _diagnose(formations)

## Temporary review aid: `res://.godot/slope_diag` holding "x,z,r" logs the
## formations and primitives near that point.
func _diagnose(formations:Array)->void:
 if not FileAccess.file_exists("res://.godot/slope_diag"):return
 var spec:=FileAccess.get_file_as_string("res://.godot/slope_diag").strip_edges().split(",")
 var at:=Vector2(float(spec[0]),float(spec[1]));var r:=float(spec[2])
 for form:Dictionary in formations:
  var o:Vector3=(form.transform as Transform3D).origin
  if Vector2(o.x,o.z).distance_to(at)>r:continue
  print("SLOPE_DIAG form ",form.get("replay_recipe",{}).get("kind","?")," o=",o," z=",(form.transform as Transform3D).basis.z," rec=",form.get("replay_recipe",{}))
 for s:Dictionary in _primitives:
  var p:Vector2=s.c if s.arc else s.a
  if p.distance_to(at)>r:continue
  print("SLOPE_DIAG prim arc=",s.arc," a=",s.get("a",s.get("c"))," len=",s.get("length",0)," n=",s.get("n",s.get("n1"))," base=",s.base," h=",s.height," free=",s.get("free_a"),s.get("free_b"))

static func _flat(v:Vector3)->Vector2:return Vector2(v.x,v.z).normalized()

## A slope tapers wherever its foot line stops without a continuation: no
## collinear run, corner arc or crossing foot line at that end. A full-size
## slope cut there shows as a vertical blade. Formation end flags are not
## enough: a step to another base or a joined formation leaves them unset.
func _find_open_ends()->void:
 for s:Dictionary in _primitives:
  if s.arc:continue
  for end:int in 2:
   var point:Vector2=(s.a as Vector2)+(s.t as Vector2)*(0.0 if end==0 else float(s.length))
   s["free_a" if end==0 else "free_b"]=not _continued(s,point,end)

func _continued(s:Dictionary,point:Vector2,end:int)->bool:
 var outward:Vector2=(s.t as Vector2)*(-1.0 if end==0 else 1.0)
 for o:Dictionary in _primitives:
  if o==s or absf(float(o.base)-float(s.base))>.5:continue
  if o.arc:
   # The arc starts where the arm ends.
   for n:Vector2 in [o.n1,o.n2]:
    if ((o.c as Vector2)+n*float(o.r)).distance_to(point)<.3:return true
   continue
  var along:=(point-(o.a as Vector2)).dot(o.t)
  var across:=absf((point-(o.a as Vector2)).dot(o.n))
  if across>.3:continue
  var parallel:=absf((o.t as Vector2).dot(s.t))>.99
  if parallel:
   # A collinear run continuing past this end.
   var beyond:=point+outward*.3
   var b:=(beyond-(o.a as Vector2)).dot(o.t)
   if b>=-.01 and b<=float(o.length)+.01:return true
  elif along>=-.3 and along<=float(o.length)+.3:return true
 return false

func _segment(a:Vector3,b:Vector3,normal:Vector3,base:float,height:float,free_a:=false,free_b:=false)->void:
 var n:=_flat(normal)
 # The tangent follows the normal, so collinear runs share one coordinate.
 var t:=Vector2(n.y,-n.x)
 var pa:=Vector2(a.x,a.z);var pb:=Vector2(b.x,b.z)
 if (pb-pa).dot(t)<0.0:
  var swap:=pa;pa=pb;pb=swap
  var f:=free_a;free_a=free_b;free_b=f
 _add({"arc":false,"a":pa,"t":t,"n":n,"length":(pb-pa).dot(t),"base":base,"height":height,
  "free_a":free_a,"free_b":free_b},[pa,pb])

func _add(primitive:Dictionary,points:Array)->void:
 _primitives.append(primitive)
 var lo:=Vector2(INF,INF);var hi:=-lo
 for p:Vector2 in points:lo=lo.min(p);hi=hi.max(p)
 # Every bucket the slope can reach from this foot.
 for bx in range(floori((lo.x-8.0)/CELL),floori((hi.x+8.0)/CELL)+1):
  for bz in range(floori((lo.y-8.0)/CELL),floori((hi.y+8.0)/CELL)+1):
   var key:=Vector2i(bx,bz)
   if not _buckets.has(key):_buckets[key]=[]
   _buckets[key].append(_primitives.size()-1)

## Top (slope height above the base) and reach at a foot point. Mini ridges
## and valleys run along the wall at about a 5 m wavelength.
var _params:Dictionary={}
func params(foot:Vector2,height:float)->Vector3:
 var key:=[foot.snapped(Vector2.ONE*.125),height]
 if _params.has(key):return _params[key]
 var p:=Vector3(snappedf(foot.x,.125),0,snappedf(foot.y,.125))
 var ripple:=Helper._value_noise01(p,_seed+9121,5.0)*2.0-1.0
 var broad:=Helper._value_noise01(p,_seed+9127,16.0)*2.0-1.0
 var top:=minf(height*.5,3.8*(1.0+.08*broad))*(1.0+.1*ripple)
 var reach:=top*1.8*(1.0+.08*broad)*(1.0+.22*ripple)
 var power:=POWER
 if STYLE.sheet_only:
  # The whole wall: vertical under the lip, the run growing more slowly than
  # the height so tall walls stay steep rather than spreading 15 m out.
  top=height-LIP_GAP
  # Rolling ridges and valleys: two warped octaves, so they wander rather
  # than repeat.
  var warp:=(Helper._value_noise01(p,_seed+9131,23.0)-.5)*12.0
  var q:=p+Vector3(warp,0,-warp)
  var ridge:=.6*(Helper._value_noise01(q,_seed+9133,6.5)*2.0-1.0)+.4*(Helper._value_noise01(q,_seed+9137,13.0)*2.0-1.0)
  # Sharpened so crests and gullies read as ridges, not a gentle wobble.
  ridge=clampf(signf(ridge)*pow(absf(ridge)*1.6,.7),-1.0,1.0)
  reach=(.85*top+1.6)*(1.0+.06*broad)*(1.0+.45*ridge)
  # Crests bulge out full; gullies sag concave. Walking along the slope at
  # one distance from the wall therefore rises over ridges and dips into
  # valleys, rather than holding one height.
  power=lerpf(2.3,1.3,ridge*.5+.5)
 _params[key]=Vector3(clampf(top,0.0,maxf(0.0,height-LIP_GAP)),minf(reach,10.0 if STYLE.sheet_only else 7.0),power)
 return _params[key]

## Outward offset of the slope from its anchor at height y above the base.
static func offset(y:float,top:float,reach:float,power:=-1.0)->float:
 if y>=top or top<=0.0:return 0.0
 var b:=(y-FOOT)/(top-FOOT)
 if b<=0.0:return reach+(FOOT-y)*.25
 if power<0.0:power=sheet_power()
 return reach*(1.0-pow(1.0-pow(1.0-b,power),1.0/power))

## The whole-wall sheet holds a near-vertical band under the lip before it
## swings out; the lower-wall slope is a gentler, more even curve.
## Gentle bumps and divots on the sheet, a subtle echo of the rock
## dressing: two octaves in a skewed (foot, height) plane, faded out at the
## ground (keeping the tangent foot) and at the lip.
func _bump(foot:Vector2,y:float,top:float)->float:
 if not STYLE.sheet_only:return 0.0
 var p:=Vector3(foot.x+y*.53,0,foot.y-y*.41)
 var b:=(Helper._value_noise01(p,_seed+9301,2.4)-.5)*.44+(Helper._value_noise01(p*1.7,_seed+9307,1.1)-.5)*.16
 return b*smoothstep(.2,1.2,y)*smoothstep(top+.1,top-.8,y)

static func anchor()->float:return SHEET_ANCHOR if STYLE.sheet_only else ANCHOR

static func sheet_power()->float:return 1.7 if STYLE.sheet_only else POWER

## Foot candidates of `q` at the same base: distance and direction out from
## the foot line, the foot point, taper and slope parameters.
func _candidates(q:Vector2,base:float)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var key:=Vector2i(floori(q.x/CELL),floori(q.y/CELL))
 for index:int in _buckets.get(key,[]):
  var s:Dictionary=_primitives[index]
  if absf(float(s.base)-base)>.5:continue
  var d:float;var dir:Vector2;var foot:Vector2;var fade:=1.0
  if s.arc:
   var v:Vector2=q-(s.c as Vector2)
   if v.dot(s.n1)<0.0 or v.dot(s.n2)<0.0 or v.length()<.01:continue
   dir=v.normalized();d=v.length()-float(s.r);foot=(s.c as Vector2)+dir*float(s.r)
  else:
   var along:float=(q-(s.a as Vector2)).dot(s.t)
   if along<-.05 or along>float(s.length)+.05:continue
   dir=s.n;d=(q-(s.a as Vector2)).dot(dir);foot=(s.a as Vector2)+(s.t as Vector2)*along
   if s.free_a:fade*=smoothstep(0.0,FREE_TAPER,along)
   if s.free_b:fade*=smoothstep(0.0,FREE_TAPER,float(s.length)-along)
  if d<-.9 or fade<.02:continue
  var shape:=_shape(foot,dir,s.height,base)
  result.append({"d":d,"dir":dir,"foot":foot,"fade":fade,"top":shape.x,"reach":shape.y,"base":float(s.base),"arc":s.arc,"c":s.get("c",Vector2.ZERO),"r":float(s.get("r",0.0))})
 return result

func _supported(foot:Vector2,dir:Vector2,base:float,limit:float)->float:
 if _region==null:return INF
 var key:=[foot.snapped(Vector2.ONE*.5),dir.snapped(Vector2.ONE*.05),snappedf(base,.5)]
 if _reach.has(key):return _reach[key]
 var depth:=ANCHOR
 var result:=INF
 while depth<limit:
  var p:=foot+dir*(depth+.5)
  if TerrainSurfaceField.surface_y(_region,p.x,p.y)<base-CRAGS.SUPPORT_DROP:result=depth;break
  depth+=.5
 _reach[key]=result
 return result

## Outward distance of the slope surface for a candidate at height y above
## its base, including the swell meeting any rock.
func target(c:Dictionary,y:float)->float:
 # A faded slope sinks just behind the wall face rather than onto it.
 var d:=_with_rocks(c.foot,c.dir,float(c.base),y,anchor()+offset(y,c.top,c.reach))
 return d*float(c.fade)-.3*(1.0-float(c.fade))

## The slope swells to meet each rock: a smooth union with an ellipsoid a
## little smaller than the rock, so the rock stands just proud of a mound
## that curves into it instead of breaking the slope.
const ROCK_BLEND:=.8
var _rock_cells:Dictionary={}
func _with_rocks(foot:Vector2,dir:Vector2,base:float,y:float,d:float)->float:
 for rock:Dictionary in _rock_cells.get(Vector2i(floori(foot.x/CELL),floori(foot.y/CELL)),[]):
  if (rock.n as Vector2).dot(dir)<.7:continue
  var du:=(foot-(rock.foot as Vector2)).dot(rock.t)/float(rock.ru)
  # World heights: sheet columns hang to their own ground, so bases differ.
  var dy:=(base+y-float(rock.base)-float(rock.y))/float(rock.ry)
  if absf(du)>2.0 or absf(dy)>2.0:continue
  var q:=1.0-du*du-dy*dy
  # Signed, so the swell stays continuous across the ellipsoid's rim.
  var e:=float(rock.cd)+float(rock.ro)*signf(q)*sqrt(absf(q))
  d=CRAGS._smax(d,e,ROCK_BLEND)
 return d

## The candidate whose slope most encloses the point (a union of slopes).
## Only feet on the formation's own base count: a storey above or below has
## its own slope on its own ground.
func _enclosing(w:Vector3,base:float)->Dictionary:
 var best:Dictionary={};var slack:=-INF
 for c:Dictionary in _candidates(Vector2(w.x,w.z),base):
  var y:=w.y-float(c.base)
  if y>float(c.top)+.6:continue
  var s:=target(c,y)-float(c.d)
  if s>slack:slack=s;best=c
 return best

## Formations keep their own rock. Below the rock band nothing may stand out
## of the slope sheet: protruding rock is pulled just inside it, so the sheet
## alone forms the slope and no formation end can show through it. Turf close
## to the slope is dropped (a pale tread across the junction reads as a band).
const INSIDE:=.3
func apply(form:Dictionary)->void:
 var pose:Transform3D=form.transform;var inverse:=pose.affine_inverse()
 var faces:PackedVector3Array=form.faces
 var moved:Dictionary={};var clear:Dictionary={}
 for i in faces.size():
  var p:=faces[i]
  if moved.has(p):faces[i]=moved[p];continue
  var w:=pose*p
  var c:=_enclosing(w,pose.origin.y)
  var result:=p
  if not c.is_empty():
   var y:=w.y-float(c.base);var d:float=c.d
   clear[p]=y-float(c.top)
   var inside:=target(c,y)-INSIDE
   var z:=lerpf(d,minf(d,inside),1.0-smoothstep(float(c.top)-ROCK_BAND,float(c.top)-ROCK_BAND+1.0,y))
   if z<d-.0001:
    var q:Vector2
    if c.arc:q=(c.c as Vector2)+(c.dir as Vector2)*(float(c.r)+z)
    else:q=Vector2(w.x,w.z)+(c.dir as Vector2)*(z-d)
    result=(inverse*Vector3(q.x,w.y,q.y)).snapped(Vector3.ONE*.0001)
  moved[p]=result;faces[i]=result
 var kept:=PackedVector3Array()
 for i in range(0,faces.size(),3):
  if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()>1e-12:
   kept.append_array(PackedVector3Array([faces[i],faces[i+1],faces[i+2]]))
 form.faces=kept
 var green:PackedVector3Array=form.get("green",PackedVector3Array())
 var turf:=PackedVector3Array()
 for i in range(0,green.size(),3):
  var ok:=true
  for j in 3:
   var p:=green[i+j]
   if moved.get(p,p)!=p or float(clear.get(p,INF))<2.5:ok=false
  if ok:turf.append_array(PackedVector3Array([green[i],green[i+1],green[i+2]]))
 form.green=turf
 if form.has("native_roots"):
  var roots:Dictionary=form.native_roots
  for p:Vector3 in moved:
   var q:Vector3=moved[p]
   if q!=p and roots.has(p):roots[q]=[roots[p][0],1.0]
 var bounds:=AABB(kept[0],Vector3.ZERO)
 for p:Vector3 in kept:bounds=bounds.expand(p)
 form.bounds=pose*bounds;form.top=(pose*bounds).end.y;form.base=(pose*bounds).position.y

## The slope itself: one sheet per straight foot line (collinear walls and
## corner arms merged) and one per outer-corner arc, sampled on world-aligned
## columns so neighbouring chunks share their edge vertices. Rows follow the
## quarter superellipse evenly in angle, with a skirt buried below the ground
## and a lip curling back into the wall above the top, so no sheet edge shows.
const STEP:=.5
const ROWS:=18
func sheets(owned:Rect2)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var lines:Dictionary={}
 for s:Dictionary in _primitives:
  if s.arc:continue
  var n:Vector2=s.n
  var key:=[snappedf((s.a as Vector2).dot(n),.5),n.snapped(Vector2.ONE*.01),snappedf(float(s.base),.5)]
  if not lines.has(key):lines[key]=[]
  lines[key].append(s)
 for key:Array in lines:
  var group:Array=lines[key]
  var first:Dictionary=group[0];var t:Vector2=first.t;var n:Vector2=first.n
  var offset_line:float=key[0]
  # Union of the runs along the line, with their exact ends as samples.
  var intervals:Array=[]
  for s:Dictionary in group:
   var u0:float=(s.a as Vector2).dot(t);intervals.append([u0,u0+float(s.length)])
  intervals.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
  var merged:Array=[]
  for iv:Array in intervals:
   if merged.is_empty() or float(iv[0])>float(merged[-1][1])+.01:merged.append(iv.duplicate())
   else:merged[-1][1]=maxf(float(merged[-1][1]),float(iv[1]))
  for iv:Array in merged:
   var us:Array[float]=[float(iv[0])]
   var u:=ceilf(float(iv[0])/STEP+.001)*STEP
   while u<float(iv[1])-.001:us.append(u);u+=STEP
   us.append(float(iv[1]))
   var columns:Array=[];var owners:Array[bool]=[]
   for value:float in us:
    var foot:=t*value+n*offset_line
    columns.append(_column(foot,n,group,value,float(first.base)))
    owners.append(owned.has_point(foot))
   result.append_array(_stitch(columns,owners,key))
 for s:Dictionary in _primitives:
  if not s.arc or not owned.has_point(s.c):continue
  var columns:Array=[];var owners:Array[bool]=[]
  for j in 9:
   var angle:=j/8.0*PI*.5
   var dir:=((s.n1 as Vector2)*cos(angle)+(s.n2 as Vector2)*sin(angle)).normalized()
   columns.append(_column((s.c as Vector2)+dir*float(s.r),dir,[s],NAN,float(s.base)))
   owners.append(true)
  result.append_array(_stitch(columns,owners,[s.c]))
 return result

## Under the sheet style a column hangs from the lip and runs down to the
## lowest ground along its run, not to its formation's base: at a stepped
## corner the upper cone wraps down to the lower ground and meets the tall
## face's slope instead of standing as a cut edge. Returns [base, shape].
func _frame(foot:Vector2,dir:Vector2,height:float,base:float)->Array:
 if STYLE.sheet_only:
  var run:=anchor()+params(foot,height).y
  var low:=_lowest_line(foot,dir,base,run)
  if _region!=null:low=minf(low,_lowest(foot,dir,base,run))
  if low<base-.5:height+=base-low;base=low
 return [base,_shape(foot,dir,height,base)]

func _lowest(foot:Vector2,dir:Vector2,base:float,run:float)->float:
 var key:=[foot.snapped(Vector2.ONE*.5),dir.snapped(Vector2.ONE*.05),snappedf(base,.5),snappedf(run,.5)]
 if _low.has(key):return _low[key]
 var low:=base;var depth:=.5
 while depth<=run:
  var p:=foot+dir*depth
  low=minf(low,TerrainSurfaceField.surface_y(_region,p.x,p.y))
  depth+=.5
 # Only whole storeys count: small dips in the ground are not a step.
 low=base if low>base-1.5 else maxf(low,base-12.0)
 _low[key]=low
 return low
var _low:Dictionary={}

## The ground steps down exactly at a lower cliff's foot line: a run that
## crosses one (facing the same way) continues down to that cliff's base.
func _lowest_line(foot:Vector2,dir:Vector2,base:float,run:float)->float:
 var low:=base
 var seen:Dictionary={}
 for q:Vector2 in [foot,foot+dir*run]:
  for index:int in _buckets.get(Vector2i(floori(q.x/CELL),floori(q.y/CELL)),[]):
   if seen.has(index):continue
   seen[index]=true
   var o:Dictionary=_primitives[index]
   if o.arc or float(o.base)>base-1.0:continue
   var facing:=(o.n as Vector2).dot(dir)
   if facing<.3:continue
   var t:=((o.a as Vector2)-foot).dot(o.n)/facing
   if t<.3 or t>run:continue
   var along:=(foot+dir*t-(o.a as Vector2)).dot(o.t)
   if along<-1.0 or along>float(o.length)+1.0:continue
   low=minf(low,float(o.base))
 return low

## Slope top and reach at a foot, limited by its own terrace: before a lower
## cliff edge the slope steepens, and on a narrow tier it vanishes.
func _shape(foot:Vector2,dir:Vector2,height:float,base:float)->Vector3:
 var shape:=params(foot,height)
 var limit:=_supported(foot,dir,base,anchor()+shape.y+.5)-anchor()-.4
 if limit<shape.y:
  shape.y=maxf(0.0,limit)
  # The ordinary slope lowers its top; the whole-wall sheet keeps its top
  # under the lip and steepens instead.
  if not STYLE.sheet_only:shape.x=minf(shape.x,shape.y*1.2)
 return shape

## One column of sheet points at a foot (world xz) facing `dir`: heights and
## outward distances bottom to top, from the covering runs' parameters.
func _column(foot:Vector2,dir:Vector2,group:Array,u:float,base:float)->Array:
 var height:=0.0;var fade:=0.0
 for s:Dictionary in group:
  var f:=1.0
  if not s.arc:
   var along:float=u-(s.a as Vector2).dot(s.t)
   if along<-.01 or along>float(s.length)+.01:continue
   if s.free_a:f*=smoothstep(0.0,FREE_TAPER,along)
   if s.free_b:f*=smoothstep(0.0,FREE_TAPER,float(s.length)-along)
  height=maxf(height,float(s.height));fade=maxf(fade,f)
 var frame:=_frame(foot,dir,height,base)
 base=frame[0];var shape:Vector3=frame[1]
 var c:={"foot":foot,"dir":dir,"base":base,"top":shape.x,"reach":shape.y,"fade":fade}
 var rows:Array=[]
 # Skirt, buried below the ground.
 for y:float in [-2.3,-1.0]:rows.append([y,target(c,y)])
 for k in ROWS+1:
  var phi:=PI*.5*(1.0-float(k)/ROWS)
  var a:=1.0-pow(cos(phi),2.0/sheet_power());var b:=1.0-pow(sin(phi),2.0/sheet_power())
  var y:=FOOT+b*(shape.x-FOOT)
  rows.append([y,_with_rocks(foot,dir,base,y,anchor()+shape.y*a+_bump(foot,y,shape.x))*fade-.3*(1.0-fade)])
 # Lip curling back into the wall, hidden behind the rock (or, as the whole
 # wall, the native grass lip) above the top.
 var curl:=Vector2(.1,.25) if STYLE.sheet_only else Vector2(.5,1.0)
 rows.append([shape.x+curl.x,(anchor()-.35)*fade-.3*(1.0-fade)])
 rows.append([shape.x+curl.y,-.3])
 if STYLE.sheet_only:_round_inner_corners(rows,foot,dir,group,base,shape.x)
 var points:=PackedVector3Array()
 for row:Array in rows:
  var q:=foot+dir*float(row[1])
  points.append(Vector3(q.x,base+float(row[0]),q.y).snapped(Vector3.ONE*.0001))
 return [points,dir]

## Two walls meeting at an inner corner: their slopes simply intersect in a
## hard V. Near the corner each column bends into a round fillet of radius
## FILLET (narrowing toward the lip) with the crossing wall's slope, as in a
## smooth union; both walls' sheets follow the same round.
const FILLET:=2.5
func _round_inner_corners(rows:Array,foot:Vector2,dir:Vector2,group:Array,base:float,top:float)->void:
 var own:float=group[0].base if not group.is_empty() else base
 for o:Dictionary in _primitives:
  if o.arc or absf(float(o.base)-own)>.5 or absf((o.n as Vector2).dot(dir))>.2:continue
  # The crossing wall runs out in front of this one, from near its foot line.
  var a0:=((o.a as Vector2)-foot).dot(dir);var a1:=((o.a as Vector2)+(o.t as Vector2)*float(o.length)-foot).dot(dir)
  if minf(a0,a1)>.6 or maxf(a0,a1)<1.0:continue
  var across:=(foot-(o.a as Vector2)).dot(o.n)
  if across<-.5 or across>FILLET+9.5:continue
  var other_foot:=foot-(o.n as Vector2)*across
  var frame:=_frame(other_foot,o.n,o.height,o.base)
  var other_base:float=frame[0];var other:Vector2=frame[1]
  for row:Array in rows:
   var y:float=row[0]
   if y<-.5 or y>top:continue
   var k:=FILLET*(1.0-smoothstep(top*.6,top,y))+.3
   var reach_other:=anchor()+offset(base+y-other_base,other.x,other.y)
   var gap:=across-reach_other
   if gap>=k:continue
   var d:float=row[1]
   # Faded in from the crossing wall's own line: where this wall continues
   # past it (a step, not a corner) the push must not start as a blade.
   row[1]=d+(k-(sqrt(maxf(0.0,k*k-(k-gap)*(k-gap))) if gap>0.0 else 0.0))*smoothstep(-.5,1.0,across)

## Quads between neighbouring columns, owned by the column they start from;
## winding faces out of the cliff.
func _stitch(columns:Array,owners:Array[bool],key:Variant)->Array[Dictionary]:
 var faces:=PackedVector3Array();var roots:Dictionary={}
 for i in columns.size()-1:
  if not owners[i]:continue
  var a:PackedVector3Array=columns[i][0];var b:PackedVector3Array=columns[i+1][0]
  var out:=Vector3((columns[i][1] as Vector2).x,0,(columns[i][1] as Vector2).y)
  for k in a.size()-1:
   for tri:Array in [[a[k],b[k],a[k+1]],[b[k],b[k+1],a[k+1]]]:
    if (tri[1]-tri[0]).cross(tri[2]-tri[0]).length_squared()<1e-12:continue
    if (tri[2]-tri[0]).cross(tri[1]-tri[0]).dot(out)>0:faces.append_array(PackedVector3Array([tri[0],tri[1],tri[2]]))
    else:faces.append_array(PackedVector3Array([tri[0],tri[2],tri[1]]))
 if faces.is_empty():return []
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:
  bounds=bounds.expand(p)
  roots[p]=[Vector3.UP,1.0]
 return [{"faces":faces,"green":PackedVector3Array(),"native_roots":roots,"transform":Transform3D.IDENTITY,
  "bounds":bounds,"anchor":bounds.get_center(),"top":bounds.end.y,"base":bounds.position.y,
  "id":"slope/%s/%s"%[key,faces[0]],"asset":&"cliff.native_crag","kind":"rock","native_crag":true,"slope_sheet":true}]

## Rocks (eighth pass): a very rocky face. Two layers, one placement rule
## (`_add_rock`): every rock sits on the combined surface, its middle sunk
## into the slope, and the solid unions a smaller ellipsoid so the slope
## swells into it.
## - Outcrops: on 14 m slots along each merged foot line (~70%), 8-12 rocks
##   packed around a 6-9 m core, from the foot up the slope.
## - Face rocks: on 4 m slots (~85%), one or two 3.5-7 m rocks standing out
##   of the steep face between 30% and 85% of the wall height.
## Tall stratified masses where the slope is steep; flat layered rocks where
## it is gentle.
const GROUND_ROCKS:=["angry_01","angry_02","angry_03","angry_04","angry_05","polyart_flat"]
const CLIFF_ROCKS:=["cliff_large_01","cliff_large_02","cliff_large_03","angry_01","angry_03"]
const BUNCH_SPACING:=14.0
const FACE_SPACING:=4.0
func _find_rocks()->void:
 for gi in _groups.size():
  var g:Dictionary=_groups[gi]
  if g.has("arc") or float(g.u1)-float(g.u0)<4.0:continue
  var line:=roundi(float(g.offset)*2.0)
  # Outcrops.
  for slot in range(floori(float(g.u0)/BUNCH_SPACING),floori(float(g.u1)/BUNCH_SPACING)+1):
   var key:=Vector3(slot,line,roundi(float(g.base)))
   if Helper.position_hash01(key,_seed+9201)>.7:continue
   var u:=(slot+.5)*BUNCH_SPACING+(Helper.position_hash01(key,_seed+9203)-.5)*5.0
   if u<float(g.u0)+2.5 or u>float(g.u1)-2.5:continue
   if not _focus.has_point(t_of(g)*u+(g.n as Vector2)*float(g.offset)):continue
   var core:=_sample(gi,snappedf(u,.0001))
   if core.is_empty() or float(core.height)<2.5:continue
   var main:=lerpf(6.0,9.0,Helper.position_hash01(key,_seed+9213))*clampf(float(core.height)/7.0,.6,1.2)
   var count:=8+floori(Helper.position_hash01(key,_seed+9219)*4.99)
   for k in count:
    var rk:=key+Vector3(0,k,0)
    var size:=main if k==0 else main*lerpf(.35,.8,Helper.position_hash01(rk,_seed+9231))
    var along:=u+(0.0 if k==0 else (Helper.position_hash01(rk,_seed+9233)-.5)*1.3*main)
    var out:=lerpf(.3,.6,Helper.position_hash01(rk,_seed+9207)) if k==0 else lerpf(.08,.8,Helper.position_hash01(rk,_seed+9207))
    _add_rock(gi,along,out,-1.0,size,rk,t_of(g)*u+(g.n as Vector2)*float(g.offset),"outcrop")
  # Face rocks.
  for slot in range(floori(float(g.u0)/FACE_SPACING),floori(float(g.u1)/FACE_SPACING)+1):
   var key:=Vector3(slot,line,roundi(float(g.base))*2+1)
   # Short walls carry fewer: a row of rocks under a 4 m lip reads as a line.
   var line_height:float=_sample(gi,snappedf(clampf((slot+.5)*FACE_SPACING,float(g.u0),float(g.u1)),.0001)).get("height",0.0)
   if Helper.position_hash01(key,_seed+9301)>.85*clampf((line_height-2.0)/6.0,.25,1.0):continue
   var count:=1+int(Helper.position_hash01(key,_seed+9303)>.55)
   for k in count:
    var rk:=key+Vector3(0,k,0)
    var along:=(slot+.5)*FACE_SPACING+(Helper.position_hash01(rk,_seed+9305)-.5)*3.0
    if along<float(g.u0)+1.5 or along>float(g.u1)-1.5:continue
    if not _focus.has_point(t_of(g)*along+(g.n as Vector2)*float(g.offset)):continue
    var sample:=_sample(gi,snappedf(along,.0001))
    if sample.is_empty() or float(sample.height)<3.0:continue
    var size:=lerpf(3.5,7.0,Helper.position_hash01(rk,_seed+9307))*clampf(float(sample.height)/8.0,.6,1.3)
    var rise:=lerpf(.15,.8,Helper.position_hash01(rk,_seed+9309))
    _add_rock(gi,along,-1.0,rise,size,rk,t_of(g)*along+(g.n as Vector2)*float(g.offset),"face")
 for rock:Dictionary in rock_list:
  var foot:Vector2=rock.foot;var reach:=2.0*float(rock.ru)
  for bx in range(floori((foot.x-reach)/CELL),floori((foot.x+reach)/CELL)+1):
   for bz in range(floori((foot.y-reach)/CELL),floori((foot.y+reach)/CELL)+1):
    var cell:=Vector2i(bx,bz)
    if not _rock_cells.has(cell):_rock_cells[cell]=[]
    _rock_cells[cell].append(rock)

static func t_of(g:Dictionary)->Vector2:return g.t

## One rock on line group gi at `along`: either at a fraction `out` of the
## slope's run, or (out < 0) where the surface reaches the fraction `rise` of
## the wall height. Sits on the combined surface, sunk into it.
func _add_rock(gi:int,along:float,out:float,rise:float,size:float,rk:Vector3,bunch:Vector2,kind:String)->void:
 var g:Dictionary=_groups[gi];var t:Vector2=g.t;var n:Vector2=g.n
 along=clampf(along,float(g.u0),float(g.u1))
 var sample:=_sample(gi,snappedf(along,.0001))
 if sample.is_empty():return
 var foot:=t*along+n*float(g.offset)
 var reach:float=sample.reach;var crest:float=sample.crest
 var surface:float;var height:float;var q:Vector2
 if out>=0.0:
  surface=anchor()+reach*out
 else:
  # Walk out until the combined surface falls to the target height.
  var target:=crest-float(sample.height)*(1.0-rise)
  # Bisection: the surface falls monotonically out from the lip.
  var lo:=anchor();var hi:=anchor()+reach
  for i in 7:
   var mid:=(lo+hi)*.5
   if surface_height(_contributions(foot+n*mid),foot+n*mid)>target:lo=mid
   else:hi=mid
  surface=(lo+hi)*.5
 q=foot+n*surface;height=surface_height(_contributions(q),q)
 var ground_y:=ground(q)
 # In a gully the slope meets the ground sooner: move up onto it.
 while height<ground_y+.4 and surface>anchor()+.6:
  surface-=.5;q=foot+n*surface;height=surface_height(_contributions(q),q);ground_y=ground(q)
 if height<ground_y+.2 or height>crest-1.0:return
 var d0:=surface_height(_contributions(foot+n*(surface-.3)),foot+n*(surface-.3))
 var d1:=surface_height(_contributions(foot+n*(surface+.3)),foot+n*(surface+.3))
 var slope:=.6/maxf(.01,d0-d1)
 var normal:=Vector3(n.x,slope,n.y).normalized()
 var steep:=slope<1.0
 var pool:Array=CLIFF_ROCKS if steep else GROUND_ROCKS
 var name:String=pool[floori(Helper.position_hash01(rk,_seed+9211)*pool.size())]
 var bounds:Vector3=ROCKS.PIECES[name][1]
 var scale:=size/maxf(bounds.x,maxf(bounds.y,bounds.z))
 # Never above the crest: shrink a rock that would stand over the lip.
 var top:=height+.5*scale*bounds.y
 if top>crest-.4:scale*=maxf(.4,(crest-.4-height)/(.5*scale*bounds.y))
 var radius:=.25*scale*(bounds.x+bounds.z)
 var cd:=surface-radius*(.5 if steep else .3)
 var yaw:=Helper.position_hash01(rk,_seed+9217)*TAU
 var axis:=Vector3.UP.cross(normal).normalized()
 var lean:=Basis(axis,Vector3.UP.angle_to(normal)*.5) if axis.length()>.5 and not steep else Basis()
 var point:=foot+n*surface;var middle:=foot+n*cd
 rock_list.append({"piece":name,"transform":Transform3D(lean*Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale),Vector3(middle.x,height,middle.y)),
  "point":Vector3(point.x,height,point.y),"normal":normal,"ground":ground_y,"bunch":bunch,"kind":kind,
  "foot":foot,"t":t,"n":n,"base":float(g.base),"y":height-float(g.base),"cd":cd,
  "centre":Vector3(middle.x,height,middle.y),"axis_t":Vector3(t.x,0,t.y),"axis_n":Vector3(n.x,0,n.y),
  # The swell stays inside the rock, which stands out of the mound.
  "ru":radius*.75,"ry":.5*scale*bounds.y*.75,"ro":radius*(.45 if steep else .5)})

## The rocks of every bunch whose centre lies in the owned rectangle.
func rocks(owned:Rect2)->Array[Dictionary]:
 return rock_list.filter(func(rock:Dictionary)->bool:return owned.has_point(rock.bunch))

## Whole-wall slope as one implicit solid (`sheet` style, seventh pass).
## Each merged foot line and outer-corner arc defines a slope height as a
## function of the horizontal distance d from its lip: near vertical under
## the grass lip, then falling ever more gently, a*x^SLOPE_P, and it keeps
## falling past any lower terrace edge until it meets real ground. A smooth
## union of every slope and the ground (sunk 0.3 m) gives one surface, so
## storeys, outer corners above inner corners and narrow terraces all flow
## into one hillside with no per-column frame to disagree between columns.
## Rocks are unioned ellipsoids. Surface nets meshes the result per chunk
## on a world-aligned grid.
const GRID:=.5
const UNION:=3.0
## Fillet radius where the slope meets the ground.
const GROUND_FILLET:=1.4
const BEHIND:=1.2
const SLOPE_P:=.6
## Slope of the straight tail below the bend.
const TAIL_SLOPE:=.35
const GROUND_SINK:=.3
var _groups:Array[Dictionary]=[]
var _group_cells:Dictionary={}
var _samples:Dictionary={}
var _grounds:Dictionary={}

func _build_groups()->void:
 var by:Dictionary={}
 for s:Dictionary in _primitives:
  if s.arc:continue
  var n:Vector2=s.n
  var key:=[snappedf((s.a as Vector2).dot(n),.5),n.snapped(Vector2.ONE*.01),snappedf(float(s.base),.5)]
  if not by.has(key):
   by[key]={"n":n,"t":s.t,"offset":(s.a as Vector2).dot(n),"base":float(s.base),"segs":[],"u0":INF,"u1":-INF}
   _groups.append(by[key])
  var g:Dictionary=by[key]
  s["group"]=_groups.find(g)
  var u0:float=(s.a as Vector2).dot(s.t)
  g.segs.append(s);g.u0=minf(g.u0,u0);g.u1=maxf(g.u1,u0+float(s.length))
 for s:Dictionary in _primitives:
  if s.arc:s["group"]=_groups.size();_groups.append({"arc":s,"base":float(s.base)})
 # Line ends that continue into a corner arc.
 for g:Dictionary in _groups:
  if g.has("arc"):continue
  var a:Vector2=(g.t as Vector2)*float(g.u0)+(g.n as Vector2)*float(g.offset)
  var b:Vector2=(g.t as Vector2)*float(g.u1)+(g.n as Vector2)*float(g.offset)
  for o:Dictionary in _groups:
   if not o.has("arc") or absf(float(o.base)-float(g.base))>.5:continue
   for n:Vector2 in [o.arc.n1,o.arc.n2]:
    var p:Vector2=(o.arc.c as Vector2)+n*float(o.arc.r)
    if p.distance_to(a)<.3:g["arc_a"]=true
    if p.distance_to(b)<.3:g["arc_b"]=true
 for i in _groups.size():
  var g:Dictionary=_groups[i]
  var lo:Vector2;var hi:Vector2
  if g.has("arc"):
   var c:Vector2=g.arc.c;lo=c-Vector2.ONE*20.0;hi=c+Vector2.ONE*20.0
  else:
   var a:Vector2=(g.t as Vector2)*float(g.u0)+(g.n as Vector2)*float(g.offset)
   var b:Vector2=(g.t as Vector2)*float(g.u1)+(g.n as Vector2)*float(g.offset)
   lo=a.min(b)-Vector2.ONE*20.0;hi=a.max(b)+Vector2.ONE*20.0
  for bx in range(floori(lo.x/CELL),floori(hi.x/CELL)+1):
   for bz in range(floori(lo.y/CELL),floori(hi.y/CELL)+1):
    var cell:=Vector2i(bx,bz)
    if not _group_cells.has(cell):_group_cells[cell]=[]
    _group_cells[cell].append(i)

## A foot sample of one group: crest, wall height, the slope's reach and
## shape factor, taper, and its ridge value.
func _sample(gi:int,key:float)->Dictionary:
 var id:=Vector2(gi,key)
 if _samples.has(id):return _samples[id]
 var g:Dictionary=_groups[gi]
 var foot:Vector2;var dir:Vector2;var height:=0.0;var fade:=0.0
 if g.has("arc"):
  var arc:Dictionary=g.arc
  dir=((arc.n1 as Vector2)*cos(key)+(arc.n2 as Vector2)*sin(key)).normalized()
  foot=(arc.c as Vector2)+dir*float(arc.r);height=arc.height;fade=1.0
 else:
  dir=g.n;foot=(g.t as Vector2)*key+dir*float(g.offset)
  for s:Dictionary in g.segs:
   var along:float=key-(s.a as Vector2).dot(s.t)
   if along<-.01 or along>float(s.length)+.01:continue
   var f:=1.0
   if s.free_a:f*=smoothstep(0.0,FREE_TAPER,along)
   if s.free_b:f*=smoothstep(0.0,FREE_TAPER,float(s.length)-along)
   height=maxf(height,float(s.height));fade=maxf(fade,f)
 var result:={}
 if height>0.0 and fade>0.0:
  var reach:float=params(foot,height).y
  result={"crest":float(g.base)+height,"height":height,"reach":reach,
   "a":height/pow(reach,SLOPE_P),"fade":fade,"ridge":_ridge(foot),"foot":foot}
 _samples[id]=result
 return result

## Warped two-octave ridge value along the wall, -1 gully .. 1 crest.
func _ridge(foot:Vector2)->float:
 var p:=Vector3(snappedf(foot.x,.125),0,snappedf(foot.y,.125))
 var warp:=(Helper._value_noise01(p,_seed+9141,21.0)-.5)*10.0
 var q:=p+Vector3(warp,0,-warp)
 var r:=.65*(Helper._value_noise01(q,_seed+9143,8.0)*2.0-1.0)+.35*(Helper._value_noise01(q,_seed+9147,15.0)*2.0-1.0)
 return clampf(r*1.5,-1.0,1.0)

## Height of one slope at horizontal distance d from its foot line. Behind
## the lip it sits just under the native grass cap and tucks back into the
## wall; in front it falls a*x^SLOPE_P. Ridges lift the whole face (the
## contour at every height rolls), strongest mid-slope.
func slope_height(sample:Dictionary,d:float)->float:
 var crest:float=sample.crest
 var x:=d-anchor()
 if x<=0.0:
  # Flush with the plateau grass up to the lip (a gap left a dark strip of
  # native rock showing between the grass and the moss), tucked back into
  # the wall behind it.
  return crest-TOP_GAP-.25*smoothstep(-.1,-.6,d)
 var reach:float=sample.reach
 # A quarter circle (vertical under the lip, bending evenly over the whole
 # run) plus a gentle straight tail: the bend is spread out rather than
 # concentrated just under the lip, and the tail keeps falling past lower
 # terrace edges so storeys merge.
 var height:float=sample.height
 var bend:=maxf(height*.3,height-TAIL_SLOPE*reach)
 var t:=clampf(x/reach,0.0,1.0)
 var fall:=(bend*sqrt(1.0-(1.0-t)*(1.0-t))+TAIL_SLOPE*x)/maxf(float(sample.fade),.05)
 var lift:=minf(2.2,float(sample.height)*.3)*float(sample.ridge)*pow(sin(PI*clampf(x/reach,0.0,1.0)),.6)
 var h:=crest-TOP_GAP-fall+lift
 # Sampled by height as well as distance: on the near-vertical upper face
 # the distance barely changes, and distance-only noise drew vertical flutes.
 var z:=h+x
 var p:=Vector3((sample.foot as Vector2).x+z*.53,0,(sample.foot as Vector2).y-z*.41)
 var bump:=((Helper._value_noise01(p,_seed+9301,2.4)-.5)*.44+(Helper._value_noise01(p*1.7,_seed+9307,1.1)-.5)*.16)*smoothstep(0.0,1.0,x)
 return h+bump

## Real ground at a column; without a region, the ground the cliffs imply
## (the crest of any cliff the point stands behind).
var ground_at:Callable
func ground(q:Vector2)->float:
 var key:=q.snapped(Vector2.ONE*.25)
 if _grounds.has(key):return _grounds[key]
 var result:float
 if _region!=null:result=TerrainSurfaceField.surface_y(_region,q.x,q.y)
 elif ground_at.is_valid():result=ground_at.call(q)
 else:
  result=INF
  for gi:int in _group_cells.get(Vector2i(floori(q.x/CELL),floori(q.y/CELL)),[]):
   result=minf(result,float(_groups[gi].base))
  if result==INF:result=0.0
  for gi:int in _group_cells.get(Vector2i(floori(q.x/CELL),floori(q.y/CELL)),[]):
   var g:Dictionary=_groups[gi]
   if g.has("arc"):continue
   var d:=q.dot(g.n)-float(g.offset);var u:=q.dot(g.t)
   if d<0.0 and d>-30.0 and u>=float(g.u0) and u<=float(g.u1):
    for seg:Dictionary in g.segs:
     var along:float=u-(seg.a as Vector2).dot(seg.t)
     if along>=0.0 and along<=float(seg.length):result=maxf(result,float(g.base)+float(seg.height))
 _grounds[key]=result
 return result

## Contributions of every group at one column: [a, b, w, d].
func _contributions(q:Vector2)->Array:
 var out:Array=[]
 for gi:int in _group_cells.get(Vector2i(floori(q.x/CELL),floori(q.y/CELL)),[]):
  var g:Dictionary=_groups[gi];var d:float;var key:float;var step:float;var edge:float;var recede:=0.0
  if g.has("arc"):
   var arc:Dictionary=g.arc;var v:=q-(arc.c as Vector2)
   if v.dot(arc.n1)<-.01 or v.dot(arc.n2)<-.01 or v.length()<.01:continue
   d=v.length()-float(arc.r);key=atan2(v.dot(arc.n2),v.dot(arc.n1));step=PI/60.0
   edge=smoothstep(0.0,.35,minf(key,PI*.5-key))
  else:
   d=q.dot(g.n)-float(g.offset);key=q.dot(g.t);step=.25
   # An end that continues into a corner arc stops exactly there; any other
   # end runs on past the wall, receding into it, rather than cutting the
   # slope off in a vertical seam.
   var lo_end:=.01 if g.get("arc_a",false) else END_RUN
   var hi_end:=.01 if g.get("arc_b",false) else END_RUN
   if key<float(g.u0)-lo_end or key>float(g.u1)+hi_end:continue
   var beyond:=maxf(float(g.u0)-key,key-float(g.u1))
   if beyond>0.0:
    recede=smoothstep(0.0,END_RUN,beyond)
    key=clampf(key,float(g.u0),float(g.u1))
   edge=1.0
   if g.get("arc_a",false):edge=minf(edge,smoothstep(0.0,2.0,key-float(g.u0)))
   if g.get("arc_b",false):edge=minf(edge,smoothstep(0.0,2.0,float(g.u1)-key))
   if beyond>0.0:edge=0.0
  if d<-BEHIND or d>20.0:continue
  var k0:=floorf(key/step)*step;var w:=(key-k0)/step
  var a:=_sample(gi,snappedf(k0,.0001));var b:=_sample(gi,snappedf(k0+step,.0001))
  if a.is_empty() and b.is_empty():continue
  if a.is_empty():a=b
  if b.is_empty():b=a
  # Receding: evaluated farther out, so the slope shrinks back into the wall.
  if recede>0.0:d+=recede*(anchor()+float(a.reach)+2.0)
  out.append([a,b,w,d,edge,float(g.base)])
 return out

## The surface height at a column: smooth union of every slope and the
## (sunk) ground.
## The union never rises above a lip (overlapping lip caps at an inner
## corner would otherwise swell through the grass). The ground fillet fades
## out where the ground is the plateau just behind a lip, for the same reason.
## Blending fades out toward each piece's own ends (edge factor), so pieces
## that adjoin (a corner arc and its arms, a wall and its continuation) join
## exactly; slopes that cross round with a fillet, wider between storeys.
const SAME_UNION:=1.4
const END_RUN:=2.5
func surface_height(contribs:Array,q:Vector2)->float:
 var h:=-INF;var cap:=-INF;var dom_edge:=0.0;var dom_base:=0.0
 for c:Array in contribs:
  var v:=lerpf(slope_height(c[0],c[3]),slope_height(c[1],c[3]),c[2])
  var cv:=lerpf(float(c[0].crest),float(c[1].crest),c[2])-TOP_GAP
  if h==-INF:
   h=v;dom_edge=c[4];dom_base=c[5]
  else:
   var k:=(UNION if absf(float(c[5])-dom_base)>.5 else SAME_UNION)*minf(dom_edge,float(c[4]))
   var merged:=CRAGS._smax(h,v,k) if k>.01 else maxf(h,v)
   if v>h:dom_edge=c[4];dom_base=c[5]
   h=minf(merged,maxf(cap,cv))
  cap=maxf(cap,cv)
 var g:=ground(q)-GROUND_SINK
 if h==-INF:return g
 # The native terrain cell under a plateau reaches past its wall line; in
 # the band just in front of a lip, ground at that lip's level is not a
 # floor for the slope (it held the top flat, then dropped it vertically
 # at the cell edge). The slope alone shapes the top there.
 for c:Array in contribs:
  if float(c[3])<anchor()+2.0 and absf(g+GROUND_SINK-float(c[0].crest))<1.0:return h
 var k:=GROUND_FILLET*clampf((cap-g-1.0)/2.0,0.0,1.0)
 return CRAGS._smax(h,g,k) if k>.01 else maxf(h,g)

## Signed inside value of the solid at a column and grid level.
func _inside(contribs:Array,rocks:Array,q:Vector2,j:int,surface:=NAN)->float:
 var y:=j*GRID
 if is_nan(surface):surface=surface_height(contribs,q)
 var f:=surface-y
 for r:Dictionary in rocks:
  var local:=Vector3(q.x,y,q.y)-(r.centre as Vector3)
  var u:=Vector3(local.dot(r.axis_t),local.y,local.dot(r.axis_n))
  var e:=Vector3(u.x/float(r.ru),u.y/float(r.ry),u.z/float(r.ro))
  var g:=minf(float(r.ru),minf(float(r.ry),float(r.ro)))*(1.0-e.length())
  f=CRAGS._smax(f,g,1.0)
 return f

## Surface-nets mesh of the solid for the owned rectangle.
func solid(owned:Rect2)->Array[Dictionary]:
 var rock_cells:Dictionary={}
 for r:Dictionary in rock_list:
  var c:Vector3=r.centre;var reach:=maxf(float(r.ru),float(r.ro))
  for bx in range(floori((c.x-reach)/GRID)-1,floori((c.x+reach)/GRID)+2):
   for bz in range(floori((c.z-reach)/GRID)-1,floori((c.z+reach)/GRID)+2):
    var key:=Vector2i(bx,bz)
    if not rock_cells.has(key):rock_cells[key]=[]
    rock_cells[key].append(r)
 # Columns within the band of any group (plus one cell of halo).
 var lo:=Vector2i(floori(owned.position.x/GRID)-1,floori(owned.position.y/GRID)-1)
 var hi:=Vector2i(ceili(owned.end.x/GRID)+1,ceili(owned.end.y/GRID)+1)
 var cols:Dictionary={}
 for gi in _groups.size():
  var g:Dictionary=_groups[gi]
  var pts:Array[Vector2]=[]
  if g.has("arc"):
   var arc:Dictionary=g.arc
   for ai in 61:
    var ang:=ai/60.0*PI*.5
    var dir:=((arc.n1 as Vector2)*cos(ang)+(arc.n2 as Vector2)*sin(ang)).normalized()
    var r:=-BEHIND
    while r<18.0:pts.append((arc.c as Vector2)+dir*(float(arc.r)+r));r+=GRID*.5
  else:
   var u:float=g.u0-.5
   while u<=float(g.u1)+.5:
    var r:=-BEHIND
    while r<18.0:pts.append((g.t as Vector2)*u+(g.n as Vector2)*(float(g.offset)+r));r+=GRID*.5
    u+=GRID*.5
  for p:Vector2 in pts:
   var key:=Vector2i(roundi(p.x/GRID),roundi(p.y/GRID))
   if key.x<lo.x or key.x>hi.x or key.y<lo.y or key.y>hi.y or cols.has(key):continue
   cols[key]=null
 # Evaluate every column over its level range.
 var field:Dictionary={}
 for key:Vector2i in cols:
  var q:=Vector2(key.x*GRID,key.y*GRID)
  var contribs:=_contributions(q)
  var rocks:Array=rock_cells.get(key,[])
  if contribs.is_empty() and rocks.is_empty():continue
  var surface:=surface_height(contribs,q)
  var jlo:=floori((minf(surface,ground(q))-2.4)/GRID);var jhi:=ceili(surface/GRID)+1
  for r:Dictionary in rocks:
   jhi=maxi(jhi,ceili(((r.centre as Vector3).y+float(r.ry))/GRID)+1)
  var values:=PackedFloat32Array()
  for j in range(jlo,jhi+1):values.append(_inside(contribs,rocks,q,j,surface))
  field[key]=[jlo,values]
 # Below a column's range the solid continues (underground); above, it ends.
 var at:=func(i:int,j:int,k:int)->float:
  var col=field.get(Vector2i(i,k))
  if col==null:return -1.0
  var idx:int=j-int(col[0])
  if idx<0:return 1.0
  var values:PackedFloat32Array=col[1]
  return values[idx] if idx<values.size() else -1.0
 var vertices:Dictionary={}
 var vertex:=func(i:int,j:int,k:int)->Variant:
  var key:=Vector3i(i,j,k)
  if vertices.has(key):return vertices[key]
  var sum:=Vector3.ZERO;var n:=0
  var corner:=func(c:int)->Vector3i:return Vector3i(i+(c&1),j+((c>>1)&1),k+((c>>2)&1))
  for e:Array in [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]]:
   var a:Vector3i=corner.call(e[0]);var b:Vector3i=corner.call(e[1])
   var fa:float=at.call(a.x,a.y,a.z);var fb:float=at.call(b.x,b.y,b.z)
   if (fa>0.0)==(fb>0.0):continue
   var t:=fa/(fa-fb)
   sum+=Vector3(a)*(1.0-t)+Vector3(b)*t;n+=1
  var result:Variant=null
  if n>0:result=(sum/n*GRID).snapped(Vector3.ONE*.0001)
  vertices[key]=result
  return result
 var faces:=PackedVector3Array()
 var owned_lo:=Vector2i(ceili(owned.position.x/GRID),ceili(owned.position.y/GRID))
 var owned_hi:=Vector2i(ceili(owned.end.x/GRID)-1,ceili(owned.end.y/GRID)-1)
 # Every grid point whose +x, +y or +z edge can cross the surface: each
 # evaluated column and its -x/-z neighbours, over the union of the level
 # ranges of the column and its +x/+z neighbours (a short column beside a
 # tall one still owns the tall one's side faces above its own top).
 var points:Dictionary={}
 for key:Vector2i in field:
  for dk:Vector2i in [Vector2i(0,0),Vector2i(-1,0),Vector2i(0,-1)]:points[key+dk]=true
 var span:=func(key:Vector2i)->Vector2i:
  var col=field.get(key)
  if col==null:return Vector2i(1000000,-1000000)
  return Vector2i(int(col[0]),int(col[0])+(col[1] as PackedFloat32Array).size())
 for key:Vector2i in points:
  if key.x<owned_lo.x or key.x>owned_hi.x or key.y<owned_lo.y or key.y>owned_hi.y:continue
  var r:Vector2i=span.call(key)
  for dk:Vector2i in [Vector2i(1,0),Vector2i(0,1)]:
   var o:Vector2i=span.call(key+dk);r=Vector2i(mini(r.x,o.x),maxi(r.y,o.y))
  if r.x>r.y:continue
  for j in range(r.x-1,r.y+1):
   var f0:float=at.call(key.x,j,key.y)
   # Edges along x, y and z from this grid point, each shared by 4 cells.
   for axis in 3:
    var o:=Vector3i(1,0,0) if axis==0 else (Vector3i(0,1,0) if axis==1 else Vector3i(0,0,1))
    var f1:float=at.call(key.x+o.x,j+o.y,key.y+o.z)
    if (f0>0.0)==(f1>0.0):continue
    var cells:Array
    if axis==0:cells=[Vector3i(key.x,j,key.y),Vector3i(key.x,j-1,key.y),Vector3i(key.x,j-1,key.y-1),Vector3i(key.x,j,key.y-1)]
    elif axis==1:cells=[Vector3i(key.x,j,key.y),Vector3i(key.x-1,j,key.y),Vector3i(key.x-1,j,key.y-1),Vector3i(key.x,j,key.y-1)]
    else:cells=[Vector3i(key.x,j,key.y),Vector3i(key.x-1,j,key.y),Vector3i(key.x-1,j-1,key.y),Vector3i(key.x,j-1,key.y)]
    var quad:Array[Vector3]=[]
    for c:Vector3i in cells:
     var v:Variant=vertex.call(c.x,c.y,c.z)
     if v==null:break
     quad.append(v)
    if quad.size()<4:continue
    # Outward is toward the outside end of the edge.
    var out:=Vector3(o)*(1.0 if f0>0.0 else -1.0)
    for tri:Array in [[quad[0],quad[1],quad[2]],[quad[0],quad[2],quad[3]]]:
     var a:Vector3=tri[0];var b:Vector3=tri[1];var c:Vector3=tri[2]
     if (b-a).cross(c-a).length_squared()<1e-10:continue
     if (c-a).cross(b-a).dot(out)>0.0:faces.append_array(PackedVector3Array([a,b,c]))
     else:faces.append_array(PackedVector3Array([a,c,b]))
 faces=_drop_fragments(faces)
 if FileAccess.file_exists("res://.godot/solid_diag"):_diag_holes(faces,owned,field)
 if faces.is_empty():return []
 # Normals from the field's gradient (central differences on the grid,
 # trilinear at each vertex): facet normals of surface nets band into
 # vertical streaks on steep faces.
 var grad:=func(i:int,j:int,k:int)->Vector3:
  return Vector3(float(at.call(i+1,j,k))-float(at.call(i-1,j,k)),float(at.call(i,j+1,k))-float(at.call(i,j-1,k)),float(at.call(i,j,k+1))-float(at.call(i,j,k-1)))
 var roots:Dictionary={};var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:
  bounds=bounds.expand(p)
  if roots.has(p):continue
  var g:=p/GRID;var i:=floori(g.x);var j:=floori(g.y);var k:=floori(g.z)
  var t:=g-Vector3(i,j,k);var n:=Vector3.ZERO
  for c in 8:
   var o:=Vector3i(c&1,(c>>1)&1,(c>>2)&1)
   var w:=(t.x if o.x==1 else 1.0-t.x)*(t.y if o.y==1 else 1.0-t.y)*(t.z if o.z==1 else 1.0-t.z)
   n+=grad.call(i+o.x,j+o.y,k+o.z)*w
  # The field grows inward; the outward normal is its negative gradient.
  n=-n
  roots[p]=[n.normalized() if n.length()>1e-6 else Vector3.UP,0.0]
 return [{"faces":faces,"green":PackedVector3Array(),"native_roots":roots,"transform":Transform3D.IDENTITY,
  "bounds":bounds,"anchor":bounds.get_center(),"top":bounds.end.y,"base":bounds.position.y,
  "id":"slope_solid/%s"%owned.position,"asset":&"cliff.native_crag","kind":"rock","native_crag":true,"slope_sheet":true}]

## Smooth unions can pinch off small blobs of solid in the air where two
## surfaces pass close; they render as dark floating chips. Keep only
## connected pieces of meaningful size.
const MIN_PIECE:=60
static func _drop_fragments(faces:PackedVector3Array)->PackedVector3Array:
 var parent:=PackedInt32Array();parent.resize(faces.size()/3)
 for i in parent.size():parent[i]=i
 var find:=func(i:int)->int:
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 var owner:Dictionary={}
 for t in parent.size():
  for k in 3:
   var v:=faces[t*3+k]
   if owner.has(v):
    var a:int=find.call(t);var b:int=find.call(owner[v])
    if a!=b:parent[a]=b
   else:owner[v]=t
 var size:Dictionary={}
 for t in parent.size():
  var r:int=find.call(t);size[r]=size.get(r,0)+1
 var kept:=PackedVector3Array()
 for t in parent.size():
  if int(size[find.call(t)])>=MIN_PIECE:kept.append_array(faces.slice(t*3,t*3+3))
 return kept

func _diag_holes(faces:PackedVector3Array,owned:Rect2,field:Dictionary)->void:
 var count:Dictionary={}
 for i in range(0,faces.size(),3):
  for k in 3:
   var a:=faces[i+k];var b:=faces[i+(k+1)%3]
   var key:=[a,b] if a<b else [b,a]
   count[key]=count.get(key,0)+1
 var inner:=owned.grow(-1.0);var holes:=[]
 for e:Array in count:
  if count[e]!=1:continue
  var m:Vector3=(e[0]+e[1])*.5
  if inner.has_point(Vector2(m.x,m.z)):holes.append(m)
 print("SOLID_DIAG owned=",owned," tris=",faces.size()/3," inner_boundary_edges=",holes.size()," sample=",holes.slice(0,6))
 for m:Vector3 in holes.slice(0,3):
  var key:=Vector2i(roundi(m.x/GRID),roundi(m.z/GRID))
  for dk:Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
   var col=field.get(key+dk)
   var q:=Vector2((key+dk).x*GRID,(key+dk).y*GRID)
   print("  col ",key+dk," ground=",ground(q)," range=",(col[0] if col!=null else "none")," n=",(col[1].size() if col!=null else 0)," surf=",surface_height(_contributions(q),q))
