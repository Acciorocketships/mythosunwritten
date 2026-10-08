extends RefCounted
## The whole-wall cliff slope (`sheet` style, owner September 24-25): the
## rounded terrain envelope (CliffSlopeEnvelope) meshed as one solid
## (`solid`), with Meadow rock clusters along the cliff foot lines. The foot
## lines are the terrain's own walls: TerrainTileField.wall_segments, the
## exact dual-cell borders (x or z = 12 i + 6) where two lattice points'
## surfaces differ, each with its top (high side) and bottom (low side)
## heights. Parameters are world-space functions of the foot position, so
## neighbouring chunks agree exactly. Worker-pure plain data.
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
const ROCK_CAPS=preload("res://scripts/terrain/field/CliffSlopeRockCaps.gd")
const ROCK_FRONTS=preload("res://scripts/terrain/field/CliffSlopeRockFronts.gd")
const ENVELOPE=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
## Free cliff ends taper the rock slots' wall height to nothing over this run.
const FREE_TAPER:=3.5
## Spatial hash of foot lines and rocks.
const CELL:=6.0
## The slope tops out this far below the crest.
const LIP_GAP:=.3
## A wall segment is split where its top or bottom height changes by more than
## this along it: every foot-line primitive has one base and one height.
const WALL_SPLIT:=.25
## Spacing of the height samples along a wall segment.
const WALL_SAMPLE:=.5

var _seed:int
## How far beyond its owned rectangle the slope reads the ground: the focus
## and envelope margins plus the envelope's pad. The terrain it reads there
## must be the very terrain its neighbours build (road verges: the streamer's
## feature contexts reach this far, FieldTerrainStreamer).
const FOCUS_GROW:=16.0
const ENVELOPE_GROW:=12.0
const GROUND_REACH:=FOCUS_GROW+ENVELOPE_GROW+ENVELOPE.PAD
var _region:HeightfieldRegion
var _primitives:Array[Dictionary]=[]
var _buckets:Dictionary={}
var rock_list:Array[Dictionary]=[]

## `focus`: only rocks that can reach this rectangle are placed (a chunk
## computes its halo's lines too; placing their rocks there is wasted work).
var _focus:=Rect2(-1e9,-1e9,2e9,2e9)
var _features:FeatureContext
var _water:WaterFieldContext
var _water_blocks:WorldFieldBlockCache
## `walls`: wall segments as TerrainTileField.wall_segments returns them
## ({a, b: segment ends, normal: unit direction from the high toward the low
## side, top / bottom: Vector2 heights at a and b on the high / low side,
## high / low: the owning lattice points}). Synthetic walls may omit the
## owners; their heights are then linear between the ends.
## `water_blocks`: an optional block cache over the same fields to share
## across slopes (see _water_level); one is built otherwise.
func _init(walls:Array,seed_value:int,region:HeightfieldRegion=null,focus:=Rect2(-1e9,-1e9,2e9,2e9),
  features:FeatureContext=null,water:WaterFieldContext=null,water_blocks:WorldFieldBlockCache=null)->void:
 _seed=seed_value;_region=region;_focus=focus.grow(FOCUS_GROW);_features=features;_water=water
 _water_blocks=water_blocks
 for wall:Dictionary in walls:_add_wall(wall)
 _add_outer_corners(walls)
 _find_open_ends()
 _build_groups()
 _find_rocks()

## A straight synthetic wall for tests and studies: the high side is behind
## `a`-`b` (against `normal`), `top` over ground `bottom`.
static func straight_wall(a:Vector2,b:Vector2,normal:Vector2,top:float,bottom:=0.0)->Dictionary:
 return {"a":a,"b":b,"normal":normal.normalized(),"top":Vector2(top,top),"bottom":Vector2(bottom,bottom)}

## Splits a wall segment where its heights change by more than WALL_SPLIT
## and adds each piece as a foot-line primitive with the heights of its first
## sample: every sample of a piece but its last (where the next piece starts)
## lies within WALL_SPLIT of them.
func _add_wall(wall:Dictionary)->void:
 var a:Vector2=wall.a;var b:Vector2=wall.b
 var steps:=maxi(1,ceili(a.distance_to(b)/WALL_SAMPLE))
 var tops:=PackedFloat64Array();var bottoms:=PackedFloat64Array()
 var sampled:=_region!=null and wall.has("high") and wall.has("low")
 for k in steps+1:
  var f:=float(k)/steps
  if not sampled:
   tops.append(lerpf(float(wall.top.x),float(wall.top.y),f))
   bottoms.append(lerpf(float(wall.bottom.x),float(wall.bottom.y),f))
  else:
   var p:=a.lerp(b,f)
   tops.append(TerrainTileField.surface_y_on_side(_region,p.x,p.y,wall.high))
   bottoms.append(TerrainTileField.surface_y_on_side(_region,p.x,p.y,wall.low))
 var start:=0
 for k in range(1,steps+1):
  if k<steps and absf(tops[k]-tops[start])<=WALL_SPLIT and absf(bottoms[k]-bottoms[start])<=WALL_SPLIT:continue
  var top:=tops[start];var base:=bottoms[start]
  if top-base>.05:
   _segment(a.lerp(b,float(start)/steps),a.lerp(b,float(k)/steps),wall.normal,base,top-base)
  start=k

## An outer (convex) corner where two walls meet at a shared end with
## perpendicular normals, each running away from the side the other faces:
## a zero-radius arc lets the foot line turn the corner (a rock slot there).
func _add_outer_corners(walls:Array)->void:
 var ends:Dictionary={}
 for i in walls.size():
  for end:int in 2:
   var p:Vector2=walls[i].a if end==0 else walls[i].b
   if not ends.has(p):ends[p]=[]
   ends[p].append([i,end])
 for c:Vector2 in ends:
  var list:Array=ends[c]
  for x in list.size():
   for y in range(x+1,list.size()):
    var w1:Dictionary=walls[list[x][0]];var w2:Dictionary=walls[list[y][0]]
    var n1:Vector2=w1.normal;var n2:Vector2=w2.normal
    if absf(n1.dot(n2))>.01:continue
    var o1:Vector2=w1.b if list[x][1]==0 else w1.a
    var o2:Vector2=w2.b if list[y][1]==0 else w2.a
    if (o1-c).dot(n2)>=0.0 or (o2-c).dot(n1)>=0.0:continue
    var top1:float=w1.top.x if list[x][1]==0 else w1.top.y
    var top2:float=w2.top.x if list[y][1]==0 else w2.top.y
    var bottom1:float=w1.bottom.x if list[x][1]==0 else w1.bottom.y
    var bottom2:float=w2.bottom.x if list[y][1]==0 else w2.bottom.y
    if absf(bottom1-bottom2)>.5:continue
    var base:=(bottom1+bottom2)*.5;var height:=(top1+top2)*.5-base
    if height<=.05:continue
    _add({"arc":true,"c":c,"r":0.0,"n1":n1,"n2":n2,"base":base,"height":height},[c])

## A foot-line run tapers wherever it stops without a continuation: no
## collinear run, corner arc or crossing foot line at that end.
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

func _segment(pa:Vector2,pb:Vector2,n:Vector2,base:float,height:float)->void:
 n=n.normalized()
 # The tangent follows the normal, so collinear runs share one coordinate.
 var t:=Vector2(n.y,-n.x)
 if (pb-pa).dot(t)<0.0:
  var swap:=pa;pa=pb;pb=swap
 _add({"arc":false,"a":pa,"t":t,"n":n,"length":(pb-pa).dot(t),"base":base,"height":height,
  "free_a":false,"free_b":false},[pa,pb])

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

## Slope top (height above the base) and reach at a foot point: vertical under
## the lip, the run growing more slowly than the height so tall walls stay
## steep; ridges and valleys wander in two warped octaves.
var _params:Dictionary={}
func params(foot:Vector2,height:float)->Vector3:
 var key:=[foot.snapped(Vector2.ONE*.125),height]
 if _params.has(key):return _params[key]
 var p:=Vector3(snappedf(foot.x,.125),0,snappedf(foot.y,.125))
 var broad:=Helper._value_noise01(p,_seed+9127,16.0)*2.0-1.0
 var top:=height-LIP_GAP
 var warp:=(Helper._value_noise01(p,_seed+9131,23.0)-.5)*12.0
 var q:=p+Vector3(warp,0,-warp)
 var ridge:=.6*(Helper._value_noise01(q,_seed+9133,6.5)*2.0-1.0)+.4*(Helper._value_noise01(q,_seed+9137,13.0)*2.0-1.0)
 # Sharpened so crests and gullies read as ridges, not a gentle wobble.
 ridge=clampf(signf(ridge)*pow(absf(ridge)*1.6,.7),-1.0,1.0)
 var reach:=(.85*top+1.6)*(1.0+.06*broad)*(1.0+.45*ridge)
 _params[key]=Vector3(clampf(top,0.0,maxf(0.0,height-LIP_GAP)),minf(reach,10.0),lerpf(2.3,1.3,ridge*.5+.5))
 return _params[key]

## Broad, shallow boulder flanks follow the mid-slope tangent; lower
## layered rocks collect near the foot. Both
## retain deterministic cluster ownership and share the envelope surface.
const GROUND_ROCKS:=["angry_01","angry_02","angry_03","angry_04","angry_05"]
const CLIFF_ROCKS:=["face_meadow_01","face_meadow_02","face_meadow_03","face_meadow_04","face_meadow_05"]
## Rocks come in small clusters of two or three, on slots spaced along the
## cliff lines and at outer corners (owner, September 25). Which slots carry a
## cluster is one coherent colony field (owner, September 27: evenly
## sprinkled clusters along every step read as scattered and too many), so
## runs of clusters alternate with genuinely bare stretches of foot. Outer
## corners, where rock naturally collects, are more likely.
const CLUSTER_SPACING:=10.0
const COLONY_SCALE:=56.0
## Nominal habitat coverage, a little under a third of the foot slots
## (corners more). September 27 judging: fewer, fuller clusters (three or
## four nestled rocks) than the first September 27 pass (two or three spaced
## rocks at cover .55), for about the same count.
const COLONY_COVER:=.5
const CLUSTER_MIN:=3
## Companion centre distance, from the deepest nestle the shared rule allows
## (0) to bases just touching (1).
const NESTLE_SPREAD:=Vector2(.15,.55)
## Turns (radians) tried round the main rock when a companion's first station
## is too steep to leave it exposed.
const NESTLE_TURNS:=[0.0,.35,.7,1.05,1.4]
const COLONY_SOFTNESS:=.06
const COLONY_CHANNEL:=0x2C7B94E1
static func colony01(p:Vector2,seed_value:int,cover:=COLONY_COVER)->float:
 return DressingEcology.suitability(DressingEcology.habitat01(p,seed_value,COLONY_CHANNEL,COLONY_SCALE),
  cover,DressingHabitatLayer.Preference.INTERIOR,COLONY_SOFTNESS)
func _find_rocks()->void:
 for gi in _groups.size():
  var g:Dictionary=_groups[gi]
  # [position key (along the line, or angle round the corner), slot id]
  var slots:Array=[]
  if g.has("arc"):
   var c:Vector2=g.arc.c
   slots.append([PI*.25,Vector3(roundi(c.x*2.0),roundi(c.y*2.0),roundi(float(g.base))*2+1)])
  else:
   var line:=roundi(float(g.offset)*2.0)
   for slot in range(floori(float(g.u0)/CLUSTER_SPACING),floori(float(g.u1)/CLUSTER_SPACING)+1):
    var key:=Vector3(slot,line,roundi(float(g.base))*2)
    var u:=(slot+.5+(Helper.position_hash01(key,_seed+9203)-.5)*.6)*CLUSTER_SPACING
    if u<float(g.u0)-.5 or u>float(g.u1)+.5:continue
    slots.append([clampf(u,float(g.u0),float(g.u1)),key])
  for slot:Array in slots:
   var key:Vector3=slot[1]
   var at_slot:Vector2=(g.arc.c as Vector2) if g.has("arc") else (g.t as Vector2)*float(slot[0])+(g.n as Vector2)*float(g.offset)
   if Helper.position_hash01(key,_seed+9201)>=colony01(at_slot,_seed,COLONY_COVER*(1.5 if g.has("arc") else 1.0)):continue
   var core:=_sample(gi,snappedf(float(slot[0]),.0001))
   if core.is_empty() or float(core.height)<2.5:continue
   var bunch:Vector2=core.foot
   if not _focus.has_point(bunch):continue
   var main:=lerpf(2.5,4.5,Helper.position_hash01(key,_seed+9213))*clampf(float(core.height)/6.0,.7,1.3)
   var count:=CLUSTER_MIN+int(Helper.position_hash01(key,_seed+9219)>.5)
   # Bedrock: the rock is the slope itself; loose rocks only at the foot.
   var bedrock:=STYLE.sheet_study=="bedrock"
   var basal:=bedrock or Helper.position_hash01(key,_seed+9241)<.28
   var rise:=lerpf(.08,.16,Helper.position_hash01(key,_seed+9209)) if basal else lerpf(.44,.64,Helper.position_hash01(key,_seed+9209))
   if bedrock:rise=lerpf(.02,.06,Helper.position_hash01(key,_seed+9209))
   if basal:main=minf(6.4,main*1.25)
   if not basal:main=lerpf(6.0,8.5,Helper.position_hash01(key,_seed+9213))
   if not basal and g.has("arc"):main=4.5
   # Study variants expose rock in the surface itself: only foot boulders.
   var pool:Array=GROUND_ROCKS if basal else CLIFF_ROCKS
   var first:=floori(Helper.position_hash01(key,_seed+9211)*pool.size())
   var stride:=1 if Helper.position_hash01(key,_seed+9251)<.5 else pool.size()-1
   var start:=rock_list.size()
   var used:Array[String]=[]
   for k in count:
    var rk:=key+Vector3(0,k,0)
    var size:=main if k==0 else maxf(MIN_ROCK,main*lerpf(.55,.85,Helper.position_hash01(rk,_seed+9231)))
    if g.has("arc") and not basal:size=maxf(size,4.5)
    # Companions nestle into the main rock (owner, September 27 judging:
    # slightly overlapping clusters): their centres sit between the nestle
    # distance and touching (NESTLE_SPREAD) from the main rock's placed
    # centre, so bases overlap but never stack: to either side along the foot
    # and, in a larger cluster, one uphill behind it (a group, not a row).
    # No main rock, no cluster.
    if k>0 and rock_list.size()==start:break
    var side:=(1.0 if Helper.position_hash01(key,_seed+9233)<.5 else -1.0)*(1.0 if k==1 else -1.0)
    var nestle:={}
    if k>0 and basal:
     var main_rock:Dictionary=rock_list[start]
     nestle={"rock":main_rock,"factor":lerpf(NESTLE_SPREAD.x,NESTLE_SPREAD.y,Helper.position_hash01(rk,_seed+9233)),
      "dir":-(main_rock.n as Vector2) if k==3 else (main_rock.t as Vector2)*side}
    var spread:=0.0 if k==0 else side*.5*(main+size)
    # Round a corner, the spread is an angle (its arc is short).
    var at:=float(slot[0])+(spread/maxf(2.0,float(core.height)) if g.has("arc") else spread)
    if g.has("arc") and k>0:at=clampf(at+(.32 if k==1 else -.32),.12,PI*.5-.12)
    if not nestle.is_empty():at=float(nestle.rock.along)
    var r:=clampf(rise+(Helper.position_hash01(rk,_seed+9207)-.5)*.12,.06,.72)
    for attempt in pool.size()*(3 if g.has("arc") and not basal else 1):
     var chosen:String=pool[(first+(k+attempt)*stride)%pool.size()]
     if chosen in used:continue
     var before:=rock_list.size()
     var fit_rise:=clampf(r+floori(float(attempt)/pool.size())*.1,.3,.72) if not basal else r
     _add_rock(gi,at,-1.0,fit_rise,size,rk,bunch,"basal" if basal else "face",chosen,nestle)
     if rock_list.size()>before:
      used.append(chosen)
      break
   for i in range(start,rock_list.size()):rock_list[i]["key"]=Helper.position_hash01(key,_seed+9261)
 _thin_rocks()

## No rock rests on another (owner, September 27: stacked pairs). Clusters,
## not single rocks, compete for ground: a companion closer to its own
## cluster than the nestle distance is dropped, a cluster reduced to one rock
## goes (a rock never stands alone), and of two clusters whose rocks come
## within the nestle distance only the lower key stays (Matern II over
## clusters: independent of order, so every chunk that computes both agrees).
func _thin_rocks()->void:
 var clusters:Dictionary={}
 for rock:Dictionary in rock_list:
  var members:Array=clusters.get(rock.bunch,[])
  var clear:=true
  for other:Dictionary in members:clear=clear and not _overlap(rock,other)
  if clear:members.append(rock)
  clusters[rock.bunch]=members
 var whole:Array=clusters.values().filter(func(members:Array)->bool:return members.size()>1)
 rock_list=[]
 for a:Array in whole:
  var survives:=true
  for b:Array in whole:
   if float(b[0].key)>=float(a[0].key):continue
   for x:Dictionary in a:
    for y:Dictionary in b:survives=survives and not _overlap(x,y)
   if not survives:break
  if survives:rock_list.append_array(a)

static func _overlap(a:Dictionary,b:Dictionary)->bool:
 return _base_centre(a).distance_to(_base_centre(b))<DressingCompiler.nestle_distance(_base_radius(a),_base_radius(b))

static func _base_centre(rock:Dictionary)->Vector2:
 var o:Vector3=(rock.transform as Transform3D).origin
 return Vector2(o.x,o.z)

## Horizontal half-extent of a placed rock.
static func _base_radius(rock:Dictionary)->float:
 var basis:Basis=(rock.transform as Transform3D).basis
 var bounds:Vector3=ROCKS.PIECES[rock.piece][1]
 return .5*maxf(Vector2(basis.x.x,basis.x.z).length()*bounds.x,Vector2(basis.z.x,basis.z.z).length()*bounds.z)

static func t_of(g:Dictionary)->Vector2:return g.t

## One rock on line group gi at `along`: either at a fraction `out` of the
## slope's run, or (out < 0) where the surface reaches the fraction `rise` of
## the wall height. Sits on the combined surface, sunk into it.
## Rocks smaller than this are not placed; each rock's swell (the mound the
## slope raises to meet it) is this fraction of its size.
const MIN_ROCK:=1.5
const SWELL:=.6
## A placed rock's base lies this far under the surface everywhere; at least
## this fraction of its height must still show.
const EMBED:=.25
const MIN_EXPOSED:=.15
## `nestle` ({rock, dir, factor}) places a basal companion along `dir` from
## that rock's centre, `factor` of the way from the nestle distance to touching.
func _add_rock(gi:int,along:float,out:float,rise:float,size:float,rk:Vector3,bunch:Vector2,kind:String,piece_name:String="",nestle:={})->void:
 var g:Dictionary=_groups[gi];var t:Vector2;var n:Vector2;var foot:Vector2
 if g.has("arc"):
  # `along` is the angle round the corner.
  var arc:Dictionary=g.arc
  along=clampf(along,0.0,PI*.5)
  n=((arc.n1 as Vector2)*cos(along)+(arc.n2 as Vector2)*sin(along)).normalized()
  t=Vector2(n.y,-n.x);foot=(arc.c as Vector2)+n*float(arc.r)
 else:
  t=g.t;n=g.n
  along=clampf(along,float(g.u0),float(g.u1))
  foot=t*along+n*float(g.offset)
 var sample:=_sample(gi,snappedf(along,.0001))
 if sample.is_empty():return
 var crest:float=sample.crest;var run:=_extent(float(sample.height))
 var env:=envelope()
 var surface:float;var height:float;var q:Vector2
 if out>=0.0:
  surface=1.0+run*out
 else:
  # Walk out until the surface falls to the target height.
  var target:=crest-float(sample.height)*(1.0-rise)
  # Bisection: the surface falls monotonically out from the lip.
  var lo:=.5;var hi:=1.5+run
  for i in 8:
   var mid:=(lo+hi)*.5
   if env.sample(foot+n*mid)>target:lo=mid
   else:hi=mid
  surface=(lo+hi)*.5
 q=foot+n*surface;height=env.sample(q)
 var ground_y:=ground(q)
 # In a gully the slope meets the ground sooner: move up onto it.
 while height<ground_y+.4 and surface>1.1:
  surface-=.5;q=foot+n*surface;height=env.sample(q);ground_y=ground(q)
 if height<ground_y+.2 or height>crest-1.0:return
 var grad:=Vector2(env.sample(q+Vector2(.3,0))-env.sample(q-Vector2(.3,0)),env.sample(q+Vector2(0,.3))-env.sample(q-Vector2(0,.3)))/.6
 var normal:=Vector3(-grad.x,1,-grad.y).normalized()
 var steep:=kind!="basal"
 var pool:Array=CLIFF_ROCKS if steep else GROUND_ROCKS
 var name:String=piece_name if not piece_name.is_empty() else pool[floori(Helper.position_hash01(rk,_seed+9211)*pool.size())]
 var bounds:Vector3=ROCKS.PIECES[name][1]
 var scale:=size/maxf(bounds.x,maxf(bounds.y,bounds.z))
 # Never above the crest: shrink a rock that would stand over the lip.
 var top:=height+.5*scale*bounds.y
 if not steep and top>crest-.4:scale*=maxf(.4,(crest-.4-height)/(.5*scale*bounds.y))
 # A rock under about a metre and a half shows only as a chip through its
 # own swell.
 if scale*maxf(bounds.x,maxf(bounds.y,bounds.z))<MIN_ROCK:return
 var yaw:=Helper.position_hash01(rk,_seed+9217)*TAU
 # Shear the stone uphill while keeping every authored horizontal ledge level.
 # Compression controls projection without tilting the grass toward the viewer.
 var basis:=Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale)
 if steep:
  var up:=(Vector3.UP-normal*normal.y).normalized()
  var across:=up.cross(normal).normalized()
  var outward:=Vector3(normal.x,0,normal.z).normalized()
  basis=Basis(across,up,outward)
  var face_height:=minf(size*bounds.y/bounds.x,float(sample.height)*.8)
  basis=basis*Basis.from_scale(Vector3(size/bounds.x,face_height/bounds.y,2.0/bounds.z))
 # Face inclusions keep both recessed ends buried at their mid-slope anchor.
 # Basal rocks bury their full footprint and may settle farther downhill.
 var height_m:=scale*bounds.y
 var exposure:=lerpf(.3,.6,Helper.position_hash01(rk,_seed+9219))*height_m
 var placed:=false;var centre:=Vector3.ZERO;var along_out:=surface
 var point:=foot+n*surface
 var radius:=.5*maxf(Vector2(basis.x.x,basis.x.z).length()*bounds.x,Vector2(basis.z.x,basis.z.z).length()*bounds.z)
 if steep:
  centre=Vector3(q.x,height,q.y)+normal*.25
  # Bound the actual front samples against the rolling terrain.
  var sink:=0.0
  for local:Vector3 in ROCK_FRONTS.POINTS[name]:
   var front:=centre+basis*local
   sink=maxf(sink,front.y-env.sample(Vector2(front.x,front.z))-.8/maxf(.1,normal.y))
  # Bury the true outer end bands. Interior authored ledges remain rock
  # surfaces with Meadow grass tops; they are not the asset end caps.
  for cap:Array in ROCK_CAPS.FACES[name]:
   if maxf(absf((cap[1] as Vector3).y),maxf(absf((cap[2] as Vector3).y),absf((cap[3] as Vector3).y)))<bounds.y*.38:continue
   for i in 4:
    for j in range(4-i):
     var local:Vector3=cap[1]+((cap[2] as Vector3)-cap[1])*(i/3.0)+((cap[3] as Vector3)-cap[1])*(j/3.0)
     var p:=centre+basis*local
     sink=maxf(sink,p.y-env.sample(Vector2(p.x,p.z))+.12)
  centre.y-=sink
  var visible_min:=INF;var visible_max:=-INF;var visible_count:=0
  for local:Vector3 in ROCK_FRONTS.POINTS[name]:
   var p:=centre+basis*local
   if (p.y-env.sample(Vector2(p.x,p.z)))*normal.y<=.06:continue
   visible_min=minf(visible_min,local.x);visible_max=maxf(visible_max,local.x);visible_count+=1
  placed=visible_count>=6 and (visible_max-visible_min)*basis.x.length()>=maxf(1.2,size*.3)

 else:
  # Stations tried in order: outward down the fall line from the surface
  # point or, for a nestled companion, round the main rock at its nestle
  # distance, turning from `dir` toward the downhill side (the flatter foot).
  var stations:Array[Vector2]=[]
  if nestle.is_empty():
   for shift:float in [0.0,.75,1.5,2.25,3.0]:stations.append(foot+n*(surface+shift))
  else:
   var main_rock:Dictionary=nestle.rock
   var r0:=_base_radius(main_rock)
   var d:=lerpf(DressingCompiler.nestle_distance(r0,radius),r0+radius,float(nestle.factor))
   var dir:Vector2=nestle.dir;var down:Vector2=main_rock.n
   # Behind (uphill) turns toward one side; beside turns toward downhill.
   var toward:=Vector2(-dir.y,dir.x)*(1.0 if Helper.position_hash01(rk,_seed+9271)<.5 else -1.0) if dir.dot(down)<-.9 else down
   for turn:float in NESTLE_TURNS:
    var station:Vector2=_base_centre(main_rock)+(dir*cos(turn)+toward*sin(turn)).normalized()*d
    if env.sample(station)<=crest-1.0:stations.append(station)
  for point2:Vector2 in stations:
   along_out=(point2-foot).dot(n);point=point2
   var ground_here:=env.sample(point2)
   centre=Vector3(point2.x,ground_here,point2.y)
   var sink:=0.0
   for i in 12:
    var a:=i*TAU/12.0
    for r:float in [1.0,.6]:
     var corner:=centre+basis*Vector3(cos(a)*bounds.x*.5*r,-bounds.y*.5,sin(a)*bounds.z*.5*r)
     sink=maxf(sink,corner.y-(env.sample(Vector2(corner.x,corner.z))-EMBED))
   centre.y-=sink
   var shown:=(centre+basis*Vector3(0,bounds.y*.5,0)).y-ground_here
   if shown>exposure:centre.y-=shown-exposure;shown=exposure
   if shown>=MIN_EXPOSED*height_m:placed=true;break
 if not placed:return
 var surface_y:=env.sample(point)
 # A basal rock's support plane is the surface where it finally stands (the
 # fall-line shift or nestle station), not the steeper slope point it was
 # sought from: its material measures its contact band from this plane.
 if not steep:
  grad=Vector2(env.sample(point+Vector2(.3,0))-env.sample(point-Vector2(.3,0)),env.sample(point+Vector2(0,.3))-env.sample(point-Vector2(0,.3)))/.6
  normal=Vector3(-grad.x,1,-grad.y).normalized()
 var substrate:=_substrate(Vector2(centre.x,centre.z),radius)
 # Where the rock meets the visible ground: its skirt's mound top (skirts()).
 var at_centre:=Vector2(centre.x,centre.z)
 var level:=maxf(env.sample(at_centre),ground(at_centre))
 var contact_rise:=RockSkirt.rise_for(centre.y+.5*bounds.y*basis.y.length()-level) if kind=="basal" and STYLE.sheet_study=="bedrock" else 0.0
 rock_list.append({"piece":name,"transform":Transform3D(basis,centre),
  "point":Vector3(point.x,surface_y,point.y),"normal":normal,"ground":ground(point),"bunch":bunch,"kind":kind,
  "exposure":substrate.x,"grade":substrate.y,"contact_rise":contact_rise,
  "foot":foot,"t":t,"n":n,"base":float(g.base),"y":surface_y-float(g.base),"cd":along_out,"along":along,
  "inverse":Transform3D(basis,centre).affine_inverse(),"zscale":basis.z.length(),
  "reach":.55*maxf(bounds.x*basis.x.length(),bounds.y*basis.y.length())+1.0,
  "centre":centre,"axis_t":basis.x.normalized(),"axis_y":basis.y.normalized(),"axis_n":basis.z.normalized(),
  # The swell stays inside the rock, which stands out of the mound.
  "ru":.5*bounds.x*basis.x.length()*SWELL,"ry":.5*bounds.y*basis.y.length()*SWELL,"ro":.5*bounds.z*basis.z.length()*SWELL})

## The surface a rock is set into, for its material (meadow_rock.gdshader):
## (rock exposure, moss grade) averaged round its base outline, exactly as
## the visible surface draws them there: the sheet's own exposure and grade
## (solid()) where the sheet shows, the terrain's plain lawn (0, 0) elsewhere.
func _substrate(centre:Vector2,radius:float)->Vector2:
 var env:=envelope()
 var sum:=Vector2.ZERO
 for k in 8:
  var q:=centre+Vector2.from_angle(TAU*k/8.0)*radius
  if env.sample(q)-SINK<=ground(q):continue
  var exposure:=env.rock_at(q)
  # The grade the sheet draws there (CliffRockCrags.mesh_arrays), not the
  # raw steepness: the rock's contact band must match its lawn or moss.
  var grade:=SlopeProfile.moss_grade(sheet_normal(q).y)
  if not env.moss_grade.is_empty():grade=maxf(grade,env.moss_grade_at(q)*smoothstep(.1,.5,exposure))
  sum+=Vector2(exposure,grade)
 return sum/8.0

## The ground skirt meeting a basal rock (RockSkirt). The surface it covers
## is the visible one: the slope sheet where it stands above the rendered
## terrain, the terrain elsewhere. The rock's contact outline is its
## horizontal section where that surface cuts it.
func skirt(rock:Dictionary)->Dictionary:
 var t:Transform3D=rock.transform
 var bounds:Vector3=ROCKS.PIECES[rock.piece][1]
 var env:=envelope()
 var terrain:=RockSkirt.terrain_surface(_region,_seed) if _region!=null \
  else {"height":Callable(self,"ground"),"normal":func(_p:Vector2)->Vector3:return Vector3.UP,"tint":func(_p:Vector2)->Color:return Color.WHITE}
 # The visible surface is the higher one: the sheet (meshed SINK under the
 # envelope) or the rendered terrain.
 var on_sheet:=func(p:Vector2)->bool:return env.sample(p)-SINK>float(terrain.height.call(p))
 var surface:={
  "height":func(p:Vector2)->float:return maxf(env.sample(p),float(terrain.height.call(p))),
  "normal":func(p:Vector2)->Vector3:return sheet_normal(p) if on_sheet.call(p) else terrain.normal.call(p),
  "tint":terrain.tint,"sheet":on_sheet}
 # The terrain part samples in one batch (RockSkirt.prefetch_corners).
 if terrain.has("prefetch"):surface["prefetch"]=terrain.prefetch
 var centre:=_base_centre(rock)
 var level:float=surface.height.call(centre)
 var half_height:=.5*bounds.y*t.basis.y.length()
 var section:=sqrt(maxf(.35,1.0-pow((level-t.origin.y)/half_height,2.0)))
 var axis_u:=Vector2(t.basis.x.x,t.basis.x.z)
 var semi:=Vector2(axis_u.length()*bounds.x,Vector2(t.basis.z.x,t.basis.z.z).length()*bounds.z)*.5*.9*section
 return RockSkirt.build("slope_rock/%s"%rock.key,centre,RockSkirt.ellipse_radii(semi,axis_u.normalized()),
  t.origin.y+half_height-level,surface)

## The bedrock sheet's lighting normal, exactly as solid() derives it: the
## negated central-difference height gradient at each grid node, interpolated.
func sheet_normal(q:Vector2)->Vector3:
 var env:=envelope()
 var g:=q/GRID;var i:=floori(g.x);var k:=floori(g.y);var f:=g-Vector2(i,k)
 var n:=Vector3.ZERO
 for c in 4:
  var o:=Vector2i(c&1,c>>1)
  var node:=Vector2(i+o.x,k+o.y)*GRID
  var w:=(f.x if o.x==1 else 1.0-f.x)*(f.y if o.y==1 else 1.0-f.y)
  n+=Vector3(env.sample(node-Vector2(GRID,0))-env.sample(node+Vector2(GRID,0)),2.0*GRID,
   env.sample(node-Vector2(0,GRID))-env.sample(node+Vector2(0,GRID)))*w
 return n.normalized()

## Skirts of every basal rock, computed once per rock. Only the bedrock sheet
## needs them: the other sheet styles union a swell per rock into the solid.
var _skirts:Dictionary={}
func skirts()->Dictionary:
 if _skirts.is_empty() and STYLE.sheet_study=="bedrock":
  for rock:Dictionary in rock_list:
   if rock.kind=="basal":_skirts[rock]=skirt(rock)
 return _skirts

## The owned skirts' sheet-covering triangles join the slope solid placement
## itself (`solid(owned)[0]`): one mesh, material, moss-grade scale (its top),
## tint lattice and collision. Each vertex takes its covered surface's own
## normal, rock exposure and moss grade.
## Their terrain-covering triangles commit as terrain (`skirt_terrain`).
func add_skirts(sheet:Dictionary,owned:Rect2)->void:
 var env:=envelope()
 var faces:PackedVector3Array=sheet.faces;var roots:Dictionary=sheet.native_roots
 var bounds:AABB=sheet.bounds
 for rock:Dictionary in skirts():
  if not owned.has_point(rock.bunch):continue
  var sk:Dictionary=_skirts[rock]
  var vertices:PackedVector3Array=sk.vertices
  for i:int in sk.sheet_indices:
   faces.append(vertices[i]);bounds=bounds.expand(vertices[i])
   if roots.has(vertices[i]):continue
   # A triangle straddling the sheet's edge keeps each corner's own covered
   # surface: over terrain, the lawn of its gentle normal and no exposure.
   # The root's grade is bedrock's own, as solid() stores it; mesh_arrays adds
   # the steepness band (October 2: a raw 1 - normal.y here painted every
   # gentle mound full moss, a dark disc round each rock).
   var q:=Vector2(vertices[i].x,vertices[i].z)
   var sheet_vertex:bool=sk.on_sheet[i]==1
   var exposure:=env.rock_at(q) if sheet_vertex else 0.0
   var grade:=0.0
   if sheet_vertex and not env.moss_grade.is_empty():grade=env.moss_grade_at(q)*smoothstep(.1,.5,exposure)
   roots[vertices[i]]=[sk.normals[i],exposure,grade]
 # The moss scale (UV2.y) reads the placement's top: keep the sheet's own.
 sheet.faces=faces;sheet.bounds=bounds;sheet.anchor=bounds.get_center();sheet.base=bounds.position.y

## The owned skirts' terrain-covering parts (RockSkirt.commit).
func skirt_terrain(owned:Rect2)->Array[Dictionary]:
 var out:Array[Dictionary]=[]
 for rock:Dictionary in skirts():
  if owned.has_point(rock.bunch):out.append(_skirts[rock])
 return out

## The rocks of every bunch whose centre lies in the owned rectangle.
func rocks(owned:Rect2)->Array[Dictionary]:
 return rock_list.filter(func(rock:Dictionary)->bool:return owned.has_point(rock.bunch))

## Whole-wall slope (`sheet` style): the rounded terrain envelope
## (CliffSlopeEnvelope), with the rocks' ellipsoid swells unioned in, meshed
## per chunk by surface nets on the envelope's world-aligned grid.
const GRID:=ENVELOPE.H
const NativeCliffSolid:=preload("res://scripts/native/NativeCliffSolid.gd")
## The solid tops out this far under the plateau grass and sinks under the
## ground where the slope meets it, so no seam edge shows.
const SINK:=.02
## A slope counts where it stands this far above the ground; the solid also
## covers MARGIN nodes around it (the lip band the native grass does not
## draw, and the foot as it sinks under the terrain). Lower rises are the
## envelope rounding the terrain's own level steps by a few centimetres: they
## stay the terrain's, or the solid shows through it in speckled lines.
const RAISED:=.15
## 4 m: where the slope hides a lip, the terrain surface stops 2.5 m behind
## the cell edge; a 2.5 m margin left a slit showing the void (September 26).
const MARGIN:=8
## Where the envelope does not raise the ground the solid lies ON the terrain
## sheet's own 2 m chords, a hair above them, so it covers the terrain in its
## columns and meets the uncovered terrain coplanar, with the same exact
## gradient normals and lawn colour: no visible join. Its lift over the
## ground is added on top, and as the lift grows (RAISED to EMERGE) the
## chord offset hands over to the exact envelope. The solid formerly stayed
## under the terrain until it stood RAISED above it, so it emerged along a
## crease wherever a rounded slope met the ground (owner, September 28:
## seams between flat ground and slopes).
const EMERGE:=.5
const COVER:=.01
func _solid_top(env:ENVELOPE,q:Vector2)->float:
 return _solid_top_over(env,q,env.at(q),env.ground_node(q))

## _solid_top given the envelope `e` and ground `g` at node q.
func _solid_top_over(env:ENVELOPE,q:Vector2,e:float,g:float)->float:
 var raised:=smoothstep(RAISED,EMERGE,e-g)
 if raised>=1.0 or _region==null:return e-SINK
 # Painted ground (roads, plazas, towns) keeps its own surface: there the
 # solid only backs the terrain, under its chords.
 var mesh:=_mesh_height(q)
 if env.excluded_node(q):return minf(e,mesh)-SINK-.12
 # Where a chord sags under the ground it does not follow it: ground that
 # drops metres within one 2 m quad slants the quad on the high side, a
 # notch in the lip (dual-grid tile gallery, September 30). There the solid
 # takes the ground's own shape, handing back to the chords as their sag
 # fades.
 raised=maxf(raised,smoothstep(RAISED,EMERGE,g-mesh))
 return e+(mesh-g)*(1.0-raised)+COVER*(1.0-raised)-SINK*raised

var _mesh_cells:Dictionary={}
## The four corner heights of each 2 m quad sampled so far (one quad serves
## the sixteen solid nodes inside it).
var _mesh_quads:Dictionary={}
## Height of the rendered terrain sheet (TerrainChunkMesher's 2 m quads, each
## pinned to the lattice point owning its centre, split along their
## (x0,z0)-(x1,z1) diagonal).
func _mesh_height(q:Vector2)->float:
 var step:=TerrainChunkMesher.STEP
 var x0:=floorf(q.x/step)*step;var z0:=floorf(q.y/step)*step
 var quad:=Vector2(x0,z0)
 var c:PackedFloat64Array=_mesh_quads.get(quad,PackedFloat64Array())
 if c.is_empty():
  var point:=Vector2i(TerrainTileField.point_of(x0+step*.5,_region),TerrainTileField.point_of(z0+step*.5,_region))
  var baked:PackedFloat32Array=_mesh_cells.get(point,PackedFloat32Array())
  if baked.is_empty():baked=TerrainTileField.bake_point(_region,point);_mesh_cells[point]=baked
  c=PackedFloat64Array([TerrainTileField.sample_baked(baked,point,x0,z0,_region),
   TerrainTileField.sample_baked(baked,point,x0+step,z0,_region),
   TerrainTileField.sample_baked(baked,point,x0,z0+step,_region),
   TerrainTileField.sample_baked(baked,point,x0+step,z0+step,_region)])
  _mesh_quads[quad]=c
 var fx:=(q.x-x0)/step;var fz:=(q.y-z0)/step
 var y00:=c[0];var y11:=c[3]
 if fx>=fz:
  var y10:=c[1]
  return y00+fx*(y10-y00)+fz*(y11-y10)
 var y01:=c[2]
 return y00+fz*(y01-y00)+fx*(y11-y01)

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
   "fade":fade,"foot":foot}
 _samples[id]=result
 return result

## Real ground at a column; without a region, the ground the cliffs imply
## (the crest of any cliff the point stands behind).
var ground_at:Callable
func ground(q:Vector2)->float:
 var key:=q.snapped(Vector2.ONE*.25)
 if _grounds.has(key):return _grounds[key]
 var result:float
 if _region!=null:result=TerrainTileField.surface_y(_region,q.x,q.y)
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

## Horizontal run of the slope below a wall `height` tall: shoulder and
## foot fillet at their widest.
static func _extent(height:float)->float:
 return sqrt(2.0*height*(ENVELOPE.SHOULDER.y+ENVELOPE.FOOT))

## The terrain envelope over the focus (built once, on first use).
var _env:ENVELOPE
func envelope()->ENVELOPE:
 if _env==null:
  var rect:=_focus.grow(ENVELOPE_GROW) if _focus.size.x<1e8 else _line_bounds().grow(30.0)
  _env=ENVELOPE.build(rect,_ground_sampler(),_exclusion(rect.grow(ENVELOPE.PAD+1.0)),_seed,_water_level(),_ground_grid(),_ground_points()) as ENVELOPE
 return _env

func _line_bounds()->Rect2:
 var r:=Rect2()
 for s:Dictionary in _primitives:
  var a:Vector2=s.c if s.arc else s.a
  var b:Vector2=a if s.arc else a+(s.t as Vector2)*float(s.length)
  r=Rect2(a,Vector2.ZERO) if r.size==Vector2.ZERO and r.position==Vector2.ZERO else r.expand(a)
  r=r.expand(b)
 return r

## The terrain's own surface, per lattice point baked once (same values as
## ground()). A query on a wall line resolves to the point that owns it.
func _ground_sampler()->Callable:
 if _region==null:return ground_at if ground_at.is_valid() else ground
 var baked:=_ground_baked;var region:=_region
 return func(q:Vector2)->float:
  var key:=Vector2i(TerrainTileField.point_of(q.x,region),TerrainTileField.point_of(q.y,region))
  if not baked.has(key):baked[key]=TerrainTileField.bake_point(region,key)
  return TerrainTileField.sample_baked(baked[key],key,q.x,q.y,region)

## The same samples over a whole envelope grid (node (i, k) at
## origin + (i, k) H), as one batched window sample (TerrainTileField.sample_grid).
var _ground_baked:Dictionary={}
func _ground_grid()->Callable:
 if _region==null:return Callable()
 var region:=_region
 return func(origin:Vector2,w:int,h:int)->PackedFloat64Array:
  # A node's x depends on i alone, its z on k alone (the same single-precision
  # sums as origin + Vector2(i, k) H).
  var xs:=PackedFloat64Array();xs.resize(w)
  for i in w:xs[i]=(origin+Vector2(i,0)*ENVELOPE.H).x
  var zs:=PackedFloat64Array();zs.resize(h)
  for k in h:zs[k]=(origin+Vector2(0,k)*ENVELOPE.H).y
  return TerrainTileField.sample_grid(region,xs,zs)

## The same samples over any grid xs x zs (row-major, z outer): the
## envelope's wall-line samples (TerrainTileField.sample_grid).
func _ground_points()->Callable:
 if _region==null:return Callable()
 var region:=_region
 return func(xs:PackedFloat64Array,zs:PackedFloat64Array)->PackedFloat64Array:
  return TerrainTileField.sample_grid(region,xs,zs)

## Water level at a point (NAN where dry), queried only in or beside a carved
## channel or basin: the slope runs into water and sinks under it.
func _water_level()->Callable:
 var water:=_water
 if water==null:return Callable()
 var region:=_region;var cells:Dictionary={}
 var tile:=TerrainTileField.spacing(region)
 # A context's halo may disagree with its neighbour's independently filled
 # halo. Always select the water domain by the queried world point, so both
 # cliff chunks use identical constraints throughout their shared mesh halo.
 var canonical:WorldFieldBlockCache=null
 if region!=null and region.plan!=null:
  # Block levels are pure functions of the fields: a shared cache over the
  # same fields (the streamer's, across chunks) returns the very same levels.
  if _water_blocks!=null and _water_blocks.serves(region.plan,water.raw_context().water):canonical=_water_blocks
  else:canonical=WorldFieldBlockCache.new(region.plan,water.raw_context().water,0.0,0.0,16)
 var home:=WorldFieldBlockCache.key_of(water.coverage().get_center())
 return func(q:Vector2)->float:
  var cell:=Vector2i(roundi(q.x/tile),roundi(q.y/tile))
  if not cells.has(cell):
   var wet:=region==null
   if region!=null:
    for dz in range(-1,2):
     for dx in range(-1,2):
      if region.is_carved(cell.x+dx,cell.y+dz):wet=true
   cells[cell]=wet
  if not cells[cell]:return NAN
  var owner:=WorldFieldBlockCache.key_of(q)
  var receiver:WaterFieldContext=canonical.water(owner) if canonical!=null and owner!=home else water
  if not receiver.has_sources() or not receiver.covers(q):return NAN
  # Every supplied level, films included: the envelope neither cuts for a
  # film shallower than WATER_SINK nor grows a bank from it (September 27).
  return receiver.level_at(q)

## Ground the slope keeps off: roads, plazas and other painted surfaces and
## graded (village) ground (1). Water is handled by _water_level.
var excluded_at:Callable
func _exclusion(_area:Rect2)->Callable:
 if excluded_at.is_valid():return excluded_at
 var features:=_features if _features!=null and _features.has_modified_surface() else null
 var water=null
 var region:=_region
 var graded:=region!=null and not region.terrain_grades.is_empty()
 if features==null and not graded:return Callable()
 # Per terrain cell: the feature shapes that reach it, and whether water can
 # (only in or beside a carved channel or basin). Point queries over a whole
 # village's shapes, or water queries on dry hills, were most of the cost.
 var cells:Dictionary={};var grades:Dictionary={}
 var tile:=TerrainTileField.spacing(region)
 return func(q:Vector2)->int:
  if graded:
   var key:=Vector2i(floori(q.x/4.0),floori(q.y/4.0))
   if not grades.has(key):grades[key]=region.has_grade_effect_in(Rect2(Vector2(key)*4.0,Vector2.ONE*4.0))
   if grades[key]:return 1
  var cell:=Vector2i(roundi(q.x/tile),roundi(q.y/tile))
  if not cells.has(cell):
   var sampler:=features.ground_field().surface_sampler_in(Rect2(Vector2(cell)*tile-Vector2.ONE*tile*.5,Vector2.ONE*tile)) if features!=null else Callable()
   var wet:=false
   if water!=null:
    if region==null:wet=true
    else:
     for dz in range(-1,2):
      for dx in range(-1,2):
       if region.is_carved(cell.x+dx,cell.y+dz):wet=true
   cells[cell]=[sampler,wet]
  var info:Array=cells[cell]
  if (info[0] as Callable).is_valid():
   var kind:=int((info[0] as Callable).call(q))
   if kind!=FeatureGroundField.NATURAL:return 1
  return 1 if info[1] and water.covers(q) and water.is_wet(q) else 0

## Ground the slope stands over (more than BURY above the terrain), as row
## runs of 2 m tiles: ambient rocks and plants rooted on the terrain there
## would be buried with their tips poking through the slope.
const BURY:=.25
func reservations(owned:Rect2)->Array[Rect2]:
 var env:=envelope()
 var out:Array[Rect2]=[]
 var z:=floorf(owned.position.y/2.0)*2.0
 while z<owned.end.y:
  var run_start:=NAN
  var x:=floorf(owned.position.x/2.0)*2.0
  while x<=owned.end.x:
   var raised:=false
   if x<owned.end.x:
    for o:Vector2 in [Vector2(1,1),Vector2(0,0),Vector2(2,0),Vector2(0,2),Vector2(2,2)]:
     var q:=Vector2(x,z)+o
     if env.at(q)-env.ground_node(q)>BURY:raised=true;break
   if raised and is_nan(run_start):run_start=x
   elif not raised and not is_nan(run_start):
    out.append(Rect2(run_start,z,x-run_start,2.0));run_start=NAN
   x+=2.0
  z+=2.0
 return out

## Signed inside value of the solid at a column and grid level: the slope
## surface smoothly unioned with each rock's ellipsoid swell.
func _inside(rocks:Array,q:Vector2,j:int,surface:float)->float:
 var y:=j*GRID
 var f:=surface-y
 for r:Dictionary in rocks:
  if r.kind=="face":
   # Study stamp/blend: the rock's own front relief joins the slope solid by
   # a smooth union, so the moss meets the stone tangentially. `blend` keeps
   # the mesh in front (the solid's rock part 12 cm behind it).
   if not STYLE.sheet_study in ["stamp","blend"]:continue # Embedded flanks do not grow a mound over themselves.
   var local:=(r.inverse as Transform3D)*Vector3(q.x,y,q.y)
   var d:=ROCKS.depth_at(ROCKS.depth_map(r.piece),Vector2(local.x,local.y))
   if is_inf(d):continue
   # Stamp: double the (compressed) front relief and stand it out a little.
   var g:=(d*2.0-local.z)*float(r.zscale)+.3 if STYLE.sheet_study=="stamp" else (d-local.z)*float(r.zscale)-.1
   f=CRAGS._smax(f,g,.9 if STYLE.sheet_study=="stamp" else .8)
   continue
  var local:=Vector3(q.x,y,q.y)-(r.centre as Vector3)
  var u:=Vector3(local.dot(r.axis_t),local.dot(r.axis_y),local.dot(r.axis_n))
  var e:=Vector3(u.x/float(r.ru),u.y/float(r.ry),u.z/float(r.ro))
  var g:=minf(float(r.ru),minf(float(r.ry),float(r.ro)))*(1.0-e.length())
  # The blend scales with the rock: a fixed metre swallowed small rocks.
  f=CRAGS._smax(f,g,clampf(.4*float(r.ry),.15,1.0))
 return f

## Columns the solid covers in the owned rectangle: where the slope stands
## above the ground, and around it where a slope nearby continues at this
## column's height (the plateau band behind a lip, which the native grass
## does not draw). Ground discontinuities also seed backing at cuts where
## the entire raised slope has been removed.
var _column_cache:Dictionary={}
var _support_faces:=PackedVector3Array()
var _support_owned:=Rect2()
func _columns(owned:Rect2)->Dictionary:
 if _column_cache.has(owned):return _column_cache[owned]
 var env:=envelope()
 # Boundary cells need the same central-difference neighbours in both chunks.
 # A one-column halo meshes the join but makes its gradient sample absent air.
 var lo:=Vector2i(floori(owned.position.x/GRID)-3,floori(owned.position.y/GRID)-3)
 var hi:=Vector2i(ceili(owned.end.x/GRID)+3,ceili(owned.end.y/GRID)+3)
 var w:=hi.x-lo.x+1+2*MARGIN;var h:=hi.y-lo.y+1+2*MARGIN
 var top:=PackedFloat64Array();top.resize(w*h);top.fill(-INF)
 var grounds:=PackedFloat64Array();grounds.resize(w*h)
 var row_any:=PackedByteArray();row_any.resize(h)
 for k in h:
  for i in w:
   var q:=Vector2(lo.x-MARGIN+i,lo.y-MARGIN+k)*GRID
   var s:float=env.at(q);var g:float=env.ground_node(q)
   grounds[k*w+i]=g
   if s-g>RAISED:top[k*w+i]=s;row_any[k]=1
 # Road/graded cuts can consume the whole raised slope. They still have
 # a cliff: seed its ground discontinuity so the solid supplies backing even
 # when no raised surface survives nearby.
 if STYLE.sheet_study=="bedrock":
  var offsets:=PackedInt32Array([-1,1,-w,w])
  for k in range(1,h-1):
   for i in range(1,w-1):
    var idx:=k*w+i;var g:=grounds[idx]
    for offset:int in offsets:
     if absf(g-grounds[idx+offset])>=2.0:
      top[idx]=maxf(top[idx],g);row_any[k]=1;break
 # Highest raised surface within MARGIN nodes (separable max filter, each
 # line in linear time; a line with nothing raised stays -INF).
 var rows:=PackedFloat64Array();rows.resize(w*h);rows.fill(-INF)
 var any_row:=false
 for k in h:
  if not row_any[k]:continue
  any_row=true
  var m:=_window_max(top.slice(k*w,k*w+w),MARGIN)
  for i in w:rows[k*w+i]=m[i]
 var cols:Dictionary={}
 if not any_row:
  _column_cache[owned]=cols
  return cols
 var column:=PackedFloat64Array();column.resize(h)
 var col_max:=PackedFloat64Array();col_max.resize(w*h);col_max.fill(-INF)
 for i in range(MARGIN,w-MARGIN):
  var any:=false
  for k in h:
   column[k]=rows[k*w+i];any=any or column[k]!=-INF
  if not any:continue
  var m:=_window_max(column,MARGIN)
  for k in range(MARGIN,h-MARGIN):col_max[k*w+i]=m[k]
 for k in range(MARGIN,h-MARGIN):
  for i in range(MARGIN,w-MARGIN):
   var m:=col_max[k*w+i]
   # A bedrock notch can fall below its plateau. Its upper columns still
   # need meshing: the height comparison omitted them and exposed the void.
   if (is_finite(m) if STYLE.sheet_study=="bedrock" else m>grounds[k*w+i]-.5):cols[Vector2i(lo.x-MARGIN+i,lo.y-MARGIN+k)]=true
 _column_cache[owned]=cols
 return cols

## _columns as NativeCliffSolid's mask (bedrock sheet, native on), cached.
var _mask_cache:Dictionary={}
func _column_mask(owned:Rect2)->RefCounted:
 if not _mask_cache.has(owned):_mask_cache[owned]=NativeCliffSolid.columns(envelope(),owned)
 return _mask_cache[owned]

## Maximum of f over [i-r, i+r] clipped to the line, for every i, in linear
## time (van Herk / Gil-Werman: prefix and suffix maxima of 2r+1 blocks).
## Exactly the clipped window maximum (max is order-independent).
static func _window_max(f:PackedFloat64Array,r:int)->PackedFloat64Array:
 var n:=f.size();var size:=2*r+1
 var pre:=PackedFloat64Array();pre.resize(n)
 var suf:=PackedFloat64Array();suf.resize(n)
 for i in n:pre[i]=f[i] if i%size==0 else maxf(pre[i-1],f[i])
 for i in range(n-1,-1,-1):suf[i]=f[i] if (i%size==size-1 or i==n-1) else maxf(suf[i+1],f[i])
 var out:=PackedFloat64Array();out.resize(n)
 for i in n:
  var a:=maxi(0,i-r);var b:=mini(n-1,i+r)
  if a/size!=b/size:out[i]=maxf(suf[a],pre[b])
  elif a%size==0:out[i]=pre[b]
  elif b%size==size-1 or b==n-1:out[i]=suf[a]
  else:
   var m:=-INF
   for d in range(a,b+1):m=maxf(m,f[d])
   out[i]=m
 return out

## Grass reuses the rendered solid triangles, spatially indexed in the
## support grid. Bilinear envelope heights are not the rendered surface on
## folded rock benches. Rocks claim their points without growing blades.
func grass_support(area:Rect2)->Dictionary:
 var env:=envelope()
 var cols=_column_mask(area) if NativeCliffSolid.on() else _columns(area)
 var lo:=Vector2i(floori(area.position.x/GRID),floori(area.position.y/GRID))
 var hi:=Vector2i(ceili(area.end.x/GRID),ceili(area.end.y/GRID))
 var w:=hi.x-lo.x+1;var h:=hi.y-lo.y+1
 var heights:=PackedFloat32Array();heights.resize(w*h)
 var flags:=PackedByteArray();flags.resize(w*h)
 # Lift over the terrain ground: where the solid merely covers the terrain,
 # the terrain's own grass grows there (September 28: a strip of missing
 # grass along every slope foot).
 var lifts:=PackedFloat32Array();lifts.resize(w*h)
 for k in h:
  for i in w:
   var key:=lo+Vector2i(i,k)
   var q:=Vector2(key)*GRID
   var e:=env.at(q);var g:=env.ground_node(q)
   lifts[k*w+i]=e-g
   heights[k*w+i]=_solid_top_over(env,q,e,g)
   # Where the slope has sunk under the terrain (its foot), the terrain's own
   # grass grows; grass planted on the buried slope would be invisible.
   if heights[k*w+i]>=g-.05 and cols.has(key):flags[k*w+i]=1
 for r:Dictionary in rock_list:
  var c:Vector3=r.centre;var reach:=maxf(float(r.ry),maxf(float(r.ru),float(r.ro)))/.75
  for k in range(maxi(0,floori((c.z-reach)/GRID)-lo.y),mini(h,ceili((c.z+reach)/GRID)-lo.y+1)):
   for i in range(maxi(0,floori((c.x-reach)/GRID)-lo.x),mini(w,ceili((c.x+reach)/GRID)-lo.x+1)):
    if Vector2(lo.x+i,lo.y+k).distance_to(Vector2(c.x,c.z)/GRID)*GRID<reach:flags[k*w+i]=2
 return {"grid":true,"origin":Vector2(lo)*GRID,"step":GRID,"w":w,"h":h,"heights":heights,"flags":flags,"lifts":lifts,
  "mesh_faces":_support_faces,"mesh_bounds":_support_owned,"mesh_cells":GrassSupportSurfaces.index_mesh(_support_faces,Vector2(lo)*GRID,GRID),
  "bounds":Rect2(Vector2(lo)*GRID,Vector2(w-1,h-1)*GRID),"id":"slope/%s"%area.position,"obstacles":[]}

## Surface-nets mesh of the solid for the owned rectangle. `mode`: 0 auto
## (the native bedrock net once NativeCliffSolid's gate passed), 1 GDScript,
## 2 native (gate and tests).
func solid(owned:Rect2,mode:=0)->Array[Dictionary]:
 var env:=envelope()
 if STYLE.sheet_study=="bedrock" and (mode==2 or (mode==0 and NativeCliffSolid.on())):
  var cols:=_column_mask(owned)
  env.replacement_columns=_column_mask(owned.grow(4.0))
  return NativeCliffSolid.solid(self,env,owned,cols,_region)
 var rock_cells:Dictionary={}
 for r:Dictionary in rock_list:
  # Bedrock foot assets are already fitted and buried against the sheet.
  # Extra ellipsoid mounds can escape their silhouettes and make adjacent
  # chunks disagree where their rock-placement halos differ.
  if STYLE.sheet_study=="bedrock":continue
  var c:Vector3=r.centre;var reach:=maxf(float(r.ry),maxf(float(r.ru),float(r.ro)))
  if r.kind=="face" and STYLE.sheet_study in ["stamp","blend"]:reach=float(r.reach)
  for bx in range(floori((c.x-reach)/GRID)-1,floori((c.x+reach)/GRID)+2):
   for bz in range(floori((c.z-reach)/GRID)-1,floori((c.z+reach)/GRID)+2):
    var key:=Vector2i(bx,bz)
    if not rock_cells.has(key):rock_cells[key]=[]
    rock_cells[key].append(r)
 var cols:=_columns(owned)
 if STYLE.sheet_study=="bedrock":env.replacement_columns=_columns(owned.grow(4.0))
 for key:Vector2i in rock_cells:
  var q:=Vector2(key)*GRID
  if owned.grow(GRID*2.0).has_point(q):cols[key]=true
 # Evaluate every column over its level range.
 var field:Dictionary={}
 for key:Vector2i in cols:
  var q:=Vector2(key.x*GRID,key.y*GRID)
  var rocks:Array=rock_cells.get(key,[])
  var g:float=env.ground_node(q)
  var surface:float=_solid_top(env,q)
  var jlo:=floori((minf(surface,g)-2.4)/GRID);var jhi:=ceili(surface/GRID)+1
  for r:Dictionary in rocks:
   jhi=maxi(jhi,ceili(((r.centre as Vector3).y+maxf(float(r.get("reach",0.0)),maxf(float(r.ry),maxf(float(r.ru),float(r.ro)))))/GRID)+1)
  var values:=PackedFloat32Array()
  if rocks.is_empty():
   for j in range(jlo,jhi+1):values.append(surface-j*GRID)
  else:
   for j in range(jlo,jhi+1):values.append(_inside(rocks,q,j,surface))
  # Levels j where the sign changes between j and j+1 (above the range the
  # solid ends), so meshing only visits the band around the surface.
  var cmin:=1000000;var cmax:=-1000000
  for idx in values.size():
   var next:=values[idx+1] if idx+1<values.size() else -1.0
   if (values[idx]>0.0)!=(next>0.0):cmin=mini(cmin,jlo+idx);cmax=maxi(cmax,jlo+idx)
  field[key]=[jlo,values,cmin,cmax]
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
  var j0:=r.x-1;var j1:=r.y+1
  # With all three columns present, every sign change lies between their
  # lowest and highest crossing (below it all are solid, above it all air).
  var band:=Vector2i(1000000,-1000000)
  for dk:Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]:
   var col=field.get(key+dk)
   if col==null:band=Vector2i(j0,j1-1);break
   band=Vector2i(mini(band.x,int(col[2])),maxi(band.y,int(col[3])))
  j0=maxi(j0,band.x);j1=mini(j1,band.y+1)
  for j in range(j0,j1):
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
     # Winding belongs to the sign-changing grid edge, not the deformed
     # triangle normal. A folded surface-net quad can point across its edge;
     # flipping that triangle alone tears the oriented surface (tiny holes).
     var forward:=((f0>0.0)==(axis==1)) if STYLE.sheet_study=="bedrock" else (c-a).cross(b-a).dot(out)>0.0
     if forward:faces.append_array(PackedVector3Array([a,b,c]))
     else:faces.append_array(PackedVector3Array([a,c,b]))
 faces=_drop_fragments(faces)
 _support_faces=faces
 _support_owned=owned
 if faces.is_empty():return []
 # Normals from the field's gradient (central differences on the grid,
 # trilinear at each vertex): facet normals of surface nets band into
 # vertical streaks on steep faces.
 var height_gradients:={}
 var grad:=func(i:int,j:int,k:int)->Vector3:
  # Bedrock is a height field: its derivative is independent of elevation.
  # The sparse meshing band's +/-1 sentinels only classify inside/outside;
  # differentiating those clipped values paints flat, recessed-looking panels
  # into a rounded shoulder as neighbours leave the stored vertical range.
  if STYLE.sheet_study=="bedrock":
   var key:=Vector2i(i,k)
   if not height_gradients.has(key):
    var q:=Vector2(key)*GRID
    height_gradients[key]=Vector3(env.sample(q+Vector2(GRID,0))-env.sample(q-Vector2(GRID,0)),-2.0*GRID,env.sample(q+Vector2(0,GRID))-env.sample(q-Vector2(0,GRID)))
   return height_gradients[key]
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
  # Second slot: rock exposure (study variants), read by the shader as COLOR.a.
  var exposure:=env.rock_at(Vector2(p.x,p.z))
  # Study stamp: stone wherever the solid stands proud of the plain slope.
  if STYLE.sheet_study=="stamp":exposure=maxf(exposure,smoothstep(.12,.5,p.y-env.sample(Vector2(p.x,p.z))))
  roots[p]=[n.normalized() if n.length()>1e-6 else Vector3.UP,exposure]
  roots[p].append(env.moss_grade_at(Vector2(p.x,p.z))*smoothstep(.1,.5,exposure) if not env.moss_grade.is_empty() else 0.0)
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
