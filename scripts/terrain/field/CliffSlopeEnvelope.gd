extends RefCounted
## Whole-wall slope surface for the `sheet` style (owner, September 25): a
## rounded envelope of the terrain itself. Every cliff lip gets a rounded
## shoulder and every foot a concave fillet. Because it is one field over the
## whole ground, not one slope per foot line, it continues round corners,
## past the ends of walls and across stacked storeys: there is nowhere for a
## slope to stop and drop straight down.
##
##   F = max(g, erode_FOOT(max(g, dilate_{SHOULDER+FOOT}(crests(g)))))
##
## (crests: the top of every cliff-edge discontinuity; see JUMP.)
## Dilation by a paraboloid of radius R rounds every convex edge (radius R);
## eroding by a smaller one gives the shoulder back its radius SHOULDER and
## fills each concave foot with a fillet of radius FOOT. Both are exact and
## separable (Felzenszwalb lower envelopes) on a world-aligned grid, so every
## chunk that computes a point gets the same value as long as its pad covers
## the transforms' reach.
##
## Ridges and valleys blend a narrow and a wide shoulder, by noise carried
## down the fall lines (each point takes the noise of the lip point it falls
## from). Roads, plazas, villages and water cap the surface by a steep cut
## rising from their edge. Worker-pure plain data.
const H:=.5
## Shoulder radius range (narrow valleys .. full ridges) and foot fillet
## radius. Wider sides retain flat terrace interiors. Tall relief takes
## the profile below, with its own ridge/valley width blend.
const SHOULDER:=Vector2(3.0,6.4)
const FOOT:=4.5
## Tall drops keep a rounded shoulder and a broad foot. The former narrow
## profile made ordinary tall faces too steep (owner, September 26).
## RELIEF: the local relief over which the blend runs.
const TIGHT:=Vector2(4.5,4.0)
const RELIEF:=Vector2(4.0,10.0)
const RELIEF_SPREAD:=25.0
## Only cliff edges take the slope (owner, September 27 judging pass). The
## terrain is classified per edge: a cliff edge (two or more storeys) is the
## only vertical discontinuity in the ground, and every other side is the
## ordinary smootherstep slope. The closing therefore dilates only the CRESTS
## of those discontinuities (the higher node wherever neighbouring ground
## steps by JUMP), never continuous ground: a dilation wider than its
## erosion raises any sloped plane by s^2 SHOULDER/2 (0.6 m on a one-storey
## slope) and fills an ordinary slope's concave foot, which laid strips of
## slope (another colour, other grass, a cut at every road) over ordinary
## hillsides. A wall keeps exactly its former rounding; continuous ground,
## however steep, keeps its own surface.
##
## Walls lie on dual-cell borders (the 12 m tile midlines x = 12 i + 6), so
## they run along a grid axis. Each wall is closed
## ACROSS itself only (1-D, along the other axis): where its top descends
## along the wall (a crest stepping down, a cliff ending in a hillside) an
## isotropic dilation spilled along the wall, over the sloping top beside it
## and above the crest in front, a raised darker curled nose. Across-only
## closing gives c(x) - y^2/(2 SHOULDER) in front of a crest c(x) and the
## ground itself behind. A wall found by the terrain itself (its two owners
## differ at a dual-cell border) counts down to any height, so an ending cliff's
## rounding reaches its very end; below LOW (metres) its shoulder widens as
## LOW/H (at most WIDEN times), so the face keeps its plan width almost to
## the end and closes there in a round blob instead of a spike (a cliff ends
## with its drop falling cubically, and the width of a fixed shoulder falls
## with the square root of the drop). Convex plan corners (crests
## of both directions) keep the isotropic closing, so slopes still round
## corners, and one equal-radius closing (FOOT) of the rounded walls then
## fillets the concave creases where faces meet (inner corners, feet): it
## preserves planes and convex shapes, so it neither lifts slopes nor
## spills. Off cell boundaries (synthetic grounds, graded edits) a JUMP
## between 0.5 m nodes counts as a wall.
const CELL:=TerrainTileField.SPACING
const LOW:=3.0
const WIDEN:=20.0
const JUMP:=2.0
## Drop over which a slope counts as a cliff for bedrock (above any water).
const CLIFF_DROP:=3.2
## Ridges, valleys, bumps and bedrock belong to tall cliffs: the variation
## fades in with local relief from about one to two storeys (owner,
## September 27); a lower wall takes one uniform rounded slope.
const VARIED:=Vector2(4.5,8.0)
## The one uniform shoulder a plain slope takes (0 narrow .. 1 wide).
const PLAIN:=0.0
## Grid pad beyond the rectangle that needs exact values: the reach of the
## dilation and erosion over the steepest local relief.
const PAD:=32.0
## Rise of the cut from an excluded area's edge (a road cut, not a wall).
const CUT_SLOPE:=1.4
const CUT_MARGIN:=.5
const EXCLUDE_STEP:=4

var origin:=Vector2.ZERO
var w:=0
var h:=0
var ground:=PackedFloat64Array()
var surface:=PackedFloat64Array()
## Rock exposure per node (0 moss slope .. 1 bare rock); empty unless a
## study variant exposes rock in the surface itself.
var rock:=PackedFloat64Array()
## The uncarved hillside grade keeps grass on rock benches in the same moss
## family as its surroundings, instead of painting each tread a pale stripe.
var moss_grade:=PackedFloat64Array()
## Keep-out nodes (roads, plazas, graded ground): painted ground the solid
## must never cover.
var excluded:=PackedByteArray()
## Solid columns of the bedrock surface net (CliffSlopeField.solid): a
## mesher skirt point is buried only under a full neighbourhood of them.
var replacement_columns:Dictionary={}

const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
## Native (C#) versions of _envelope_axis, _window and _blur under .NET Godot,
## parity-checked against these GDScript kernels at startup (perf session).
const NativeGridKernels := preload("res://scripts/native/NativeGridKernels.gd")

## Water (owner, September 28: spikes, sharp corners and cut-outs where the
## slope met water). The water never cuts the slope: planar cuts from a 2 m
## block mask left prisms, fins and pits wherever a rounded wall reached a
## pool. A bank rounds down to the carved bed and the water covers what lies
## below its surface; the shore is where the bank rises out of it.
## A broad wet corridor (at least 2 CHANNEL_CORE across) stays open between
## opposing banks: a wall facing it rounds with at most the radius that
## brings its bank under the water a quarter core short of mid-channel.
## Narrower wet pockets are absorbed by the bank (owner, September 26).
const CHANNEL_CORE:=8.0
## Water no deeper than this over the ground is a film: neither floor nor
## shore (a river's sill film where it runs over a ledge).
const WATER_SINK:=.4
## Rock relief may stand proud, but must not excavate metre-deep benches
## into an otherwise continuous mountain shoulder.
const BEDROCK_RECESS:=.25
## Tests only: run every transform even where the result is known to be the
## ground (build's no-wall shortcut), to prove the shortcut exact.
static var always_transform:=false
## `ground_grid`, when given, returns ground_at over the whole grid at once
## (origin, w, h -> the w*h node values, row by row): the same values, without
## a call per node.
static func build(rect:Rect2,ground_at:Callable,excluded_at:Callable,seed_value:int,water_at:Callable=Callable(),ground_grid:=Callable())->RefCounted:
 var env:=new()
 var grid:=rect.grow(PAD)
 env.origin=(grid.position/H).floor()*H
 env.w=ceili((grid.end.x-env.origin.x)/H)+1
 env.h=ceili((grid.end.y-env.origin.y)/H)+1
 var n:int=env.w*env.h
 var clock:=Time.get_ticks_usec();var profile:=OS.has_environment("SLOPE_ENV_PROFILE")
 var mark:=func(label:String)->void:
  if profile:print("[slope_envelope] %s %.0f ms (%dx%d)"%[label,(Time.get_ticks_usec()-clock)/1000.0,env.w,env.h])
 var excluded:=PackedByteArray();excluded.resize(n)
 var any_excluded:=false
 if ground_grid.is_valid():
  env.ground=ground_grid.call(env.origin,env.w,env.h)
  assert(env.ground.size()==n)
 else:
  env.ground.resize(n)
  for k in env.h:
   for i in env.w:
    env.ground[k*env.w+i]=ground_at.call(env.origin+Vector2(i,k)*H)
 mark.call("ground")
 # Keep-out areas on a coarser lattice: water and feature queries are far
 # dearer than the ground, and the cut's margin absorbs the block size.
 if excluded_at.is_valid():
  for k in range(0,env.h,EXCLUDE_STEP):
   for i in range(0,env.w,EXCLUDE_STEP):
    if not excluded_at.call(env.origin+(Vector2(i,k)+Vector2.ONE*(EXCLUDE_STEP-1)*.5)*H):continue
    any_excluded=true
    for kk in range(k,mini(k+EXCLUDE_STEP,env.h)):
     for ii in range(i,mini(i+EXCLUDE_STEP,env.w)):excluded[kk*env.w+ii]=1
  # Blocks on the mask's edge are resolved per node: the cut follows the
  # road's own outline, not a 2 m staircase (owner, September 26).
  if any_excluded:
   var S:=EXCLUDE_STEP;var coarse:=excluded.duplicate()
   for k in range(0,env.h,S):
    for i in range(0,env.w,S):
     var here:=coarse[k*env.w+i];var edge:=false
     for o:Vector2i in [Vector2i(-S,0),Vector2i(S,0),Vector2i(0,-S),Vector2i(0,S)]:
      var ii:=i+o.x;var kk:=k+o.y
      if ii>=0 and kk>=0 and ii<env.w and kk<env.h and coarse[kk*env.w+ii]!=here:edge=true
     if not edge:continue
     for kk in range(k,mini(k+S,env.h)):
      for ii in range(i,mini(i+S,env.w)):
       excluded[kk*env.w+ii]=1 if excluded_at.call(env.origin+Vector2(ii,kk)*H) else 0
 if any_excluded:env.excluded=excluded
 var wet_level:=_levels(env,water_at)
 var any_wet:=not wet_level.is_empty()
 mark.call("exclusion")
 var g:=env.ground
 var sh:=SHOULDER
 var foot:=FOOT
 var tight_sh:=TIGHT.x
 var tight_foot:=TIGHT.y
 var walls:=_walls(env,g,ground_at,wet_level)
 mark.call("walls")
 # Ground with no wall crest anywhere in the grid: every closing below
 # returns the ground itself (an erosion never rises over its input, and each
 # blend of equal surfaces is that surface), the fillet's gate is closed, no
 # rock is exposed and no cap lowers it. Only the moss grade remains to compute.
 if not always_transform and walls[0][0].count(-INF)==n and walls[1][0].count(-INF)==n:
  env.surface=g.duplicate()
  if STYLE.sheet_study=="bedrock":
   env.moss_grade=_moss_grade(env,env.surface)
   env.rock.resize(n)
  mark.call("done (no walls)")
  return env
 # Nodes a channel-fitted bank reaches (see CHANNEL_CORE).
 var channel:=PackedByteArray();channel.resize(n)
 # Each rounding also says how far along its walls it reaches (see the
 # fillet below), blended exactly as the roundings are.
 var along_narrow:=PackedFloat64Array();along_narrow.resize(n)
 var along_wide:=PackedFloat64Array();along_wide.resize(n)
 var along_tight:=PackedFloat64Array();along_tight.resize(n)
 var along_tight_wide:=PackedFloat64Array();along_tight_wide.resize(n)
 var ground_rows:={}
 var narrow:=_close_walls(g,walls,env.w,env.h,sh.x,foot,channel,along_narrow,ground_rows)
 mark.call("close narrow")
 var wide_dilated:=_dilate(g,env.w,env.h,sh.y+foot)
 var wide:=_close_walls(g,walls,env.w,env.h,sh.y,foot,channel,along_wide,ground_rows)
 var tight:=_close_walls(g,walls,env.w,env.h,tight_sh,tight_foot,channel,along_tight,ground_rows)
 var tight_wide:=_close_walls(g,walls,env.w,env.h,6.4,tight_foot,channel,along_tight_wide,ground_rows)
 mark.call("close all four")
 # Local relief: highest reach minus lowest reach nearby; continuous even
 # across the terrain's own cliffs, so the blend never opens a step.
 var floor_level:=_erode(g,env.w,env.h,SHOULDER.y+FOOT)
 var relief:=PackedFloat64Array();relief.resize(n)
 for idx in n:relief[idx]=wide_dilated[idx]-floor_level[idx]
 # Carried out over the fan a drop feeds, so the whole corner slope takes
 # the corner's drop, not the relief left at each point along it.
 relief=_dilate(relief,env.w,env.h,RELIEF_SPREAD)
 # Whether a drop reads as a cliff is measured to the water surface, not a
 # carved river bed: a one-storey bank above a river is an ordinary slope.
 var drop:=relief
 if any_wet:
  var floor_dry:=g.duplicate()
  for idx in n:
   if is_finite(wet_level[idx]) and wet_level[idx]>floor_dry[idx]:floor_dry[idx]=wet_level[idx]
  floor_dry=_erode(floor_dry,env.w,env.h,SHOULDER.y+FOOT)
  drop=PackedFloat64Array();drop.resize(n)
  for idx in n:drop[idx]=wide_dilated[idx]-floor_dry[idx]
  drop=_dilate(drop,env.w,env.h,RELIEF_SPREAD)
 mark.call("transforms")
 var t:=_ridges(env,narrow,wide,wide_dilated,seed_value)
 mark.call("ridges")
 env.surface.resize(n)
 var along:=PackedFloat64Array();along.resize(n)
 for idx in n:
  var tall:=smoothstep(RELIEF.x,RELIEF.y,relief[idx])
  var ridge:=lerpf(PLAIN,t[idx],smoothstep(VARIED.x,VARIED.y,drop[idx]))
  env.surface[idx]=lerpf(lerpf(narrow[idx],wide[idx],ridge),lerpf(tight[idx],tight_wide[idx],ridge),tall)
  along[idx]=lerpf(lerpf(along_narrow[idx],along_wide[idx],ridge),lerpf(along_tight[idx],along_tight_wide[idx],ridge),tall)
 # Fillet the concave creases where wall faces meet (see JUMP).
 # Only where walls are being rounded: the ground's own concave bends
 # (a slope's foot, a valley between two banks) keep their surface. Where a
 # wall ends (dual-grid tiles: under E2 the wall runs to the tile centre and
 # shortens to nothing beyond it) the fillet between its rounded
 # end and the ground beyond continues ALONG the wall, over ground the
 # rounding does not raise: gated by the lift at each node it stopped in a
 # steep cut across the fall line. So the gate also counts the rounding's
 # lift carried along its own wall over a FOOT fillet's reach (never across
 # the wall: up over its top or over to an opposing bank).
 # In a fitted channel never above the water: filleting the valley between
 # opposing banks dammed the channel they were fitted to leave open.
 # The fillet never stands over the lip across a wall line (see _lips).
 mark.call("blend")
 var filleted:=_erode(_dilate(env.surface,env.w,env.h,FOOT),env.w,env.h,FOOT)
 var lips:=_lips(walls,g,env.w,n)
 mark.call("fillet transform")
 for idx in n:
  var fill:=filleted[idx]
  if lips[idx]>-INF:fill=minf(fill,maxf(lips[idx],env.surface[idx]))
  if channel[idx] and _deep(wet_level,env.ground,idx):fill=minf(fill,wet_level[idx]-.3)
  env.surface[idx]=lerpf(env.surface[idx],maxf(env.surface[idx],fill),smoothstep(0.0,.5,maxf(env.surface[idx]-g[idx],along[idx])))
 var uncut:=env.surface.duplicate()
 # Only a road's cut face is bare rock: the underwater bank keeps its moss.
 var shaped:=env.surface.duplicate()
 # Keep-out caps: a steep cut rising from roads and graded ground.
 var caps:=PackedFloat64Array();caps.resize(n);caps.fill(INF)
 if any_excluded:
  var dist:=_distance(excluded,env.w,env.h)
  for idx in n:caps[idx]=env.ground[idx]+CUT_SLOPE*maxf(0.0,dist[idx]-CUT_MARGIN)
 # Roads remain hard constraints. The rounded bank is a backing surface,
 # not a ceiling that flattens every rock ledge.
 var rock_caps:=caps.duplicate()
 # Rock stands proud of the slope, never over the lip it hangs from: bounded
 # only by the highest crest around, a bench stood 0.6 m over the lip at a
 # dying wall's end, the trough of owner photo 1 again. A slope standing over
 # every lip here falls from another rounding (a corner): it keeps its room,
 # restored over a metre so the cap never steps.
 # The level lip: a diagonal wall is a staircase of axis walls, and the
 # shouldered bound's per-axis falloff faceted its benches.
 var rock_lips:=_lips(walls,g,env.w,n,false)
 for idx in n:
  if rock_lips[idx]>-INF:rock_caps[idx]=minf(rock_caps[idx],maxf(rock_lips[idx],uncut[idx])+7.5*smoothstep(0.0,1.0,uncut[idx]-rock_lips[idx]))
 for idx in n:env.surface[idx]=minf(env.surface[idx],maxf(env.ground[idx],caps[idx]))
 mark.call("fillet and caps")
 if STYLE.sheet_study=="bedrock":
  # A dry rock face can stand proud; a submerged point must stay submerged.
  # Fade its available relief in above the actual bank/water contact.
  if any_wet:
   for idx in n:
    if not _deep(wet_level,env.ground,idx):continue
    # Under water the rock never builds above the shaped bank.
    var room:=7.5*smoothstep(.75,3.0,env.surface[idx]-wet_level[idx])
    rock_caps[idx]=minf(rock_caps[idx],env.surface[idx]+room)
  var cut:=PackedFloat64Array();cut.resize(n)
  for idx in n:cut[idx]=shaped[idx]-env.surface[idx]
  # Bedrock needs a tall cliff below the bed's rim and more than a storey
  # of it standing above any water.
  var cliff:=PackedFloat64Array();cliff.resize(n)
  # Only on the rounded face of a cliff edge, never on continuous ground.
  for idx in n:cliff[idx]=smoothstep(VARIED.x,VARIED.y,relief[idx])*smoothstep(CLIFF_DROP,VARIED.x,drop[idx])*smoothstep(.15,1.0,uncut[idx]-g[idx])
  # No benches under water: the bank below the surface stays one slope.
  if any_wet:
   for idx in n:
    if _deep(wet_level,env.ground,idx):cliff[idx]*=1.0-smoothstep(-.5,0.0,wet_level[idx]-env.surface[idx])
  # Only a keep-out cap cuts the slope back.
  _bedrock(env,floor_level,wide_dilated,cliff,seed_value,cut,any_excluded)
  for idx in n:env.surface[idx]=minf(env.surface[idx],maxf(env.ground[idx],rock_caps[idx]))
 mark.call("done")
 return env

## Water level per node (NAN where dry). Queried on the coarse lattice (water
## queries are far dearer than the ground); blocks on the wet outline or at a
## change of level are resolved per node, so neither the shore nor a level
## change steps in 2 m blocks.
static func _levels(env,water_at:Callable)->PackedFloat64Array:
 if not water_at.is_valid():return PackedFloat64Array()
 var S:=EXCLUDE_STEP;var w:int=env.w;var h:int=env.h
 var cw:=ceili(float(w)/S);var ch:=ceili(float(h)/S)
 var coarse:=PackedFloat64Array();coarse.resize(cw*ch)
 var any:=false
 for ck in ch:
  for ci in cw:
   var level:float=water_at.call(env.origin+(Vector2(ci*S,ck*S)+Vector2.ONE*(S-1)*.5)*H)
   coarse[ck*cw+ci]=level;any=any or is_finite(level)
 if not any:return PackedFloat64Array()
 var out:=PackedFloat64Array();out.resize(w*h);out.fill(NAN)
 for ck in ch:
  for ci in cw:
   # Per node wherever the neighbourhood is not one uniform water body
   # (the shore, or a change of level): its outline and steps stay exact.
   var here:=coarse[ck*cw+ci];var edge:=false
   for dk in range(-1,2):
    for di in range(-1,2):
     var k:=ck+dk;var i:=ci+di
     if k<0 or i<0 or k>=ch or i>=cw:continue
     var other:=coarse[k*cw+i]
     if is_finite(other)!=is_finite(here) or (is_finite(here) and absf(other-here)>.02):edge=true
   for kk in range(ck*S,mini(ck*S+S,h)):
    for ii in range(ci*S,mini(ci*S+S,w)):
     if edge:out[kk*w+ii]=water_at.call(env.origin+Vector2(ii,kk)*H)
     elif is_finite(here):out[kk*w+ii]=here
 return out

## Water actually standing over the ground (the sampler reports a level
## wherever its domain reaches, also under dry banks).
static func _wet(wet:PackedFloat64Array,ground:PackedFloat64Array,idx:int)->bool:
 return is_finite(wet[idx]) and wet[idx]>ground[idx]

static func _deep(wet:PackedFloat64Array,ground:PackedFloat64Array,idx:int)->bool:
 return is_finite(wet[idx]) and wet[idx]>ground[idx]+WATER_SINK

## Wall crests per direction: [0] walls along x (a drop between z-
## neighbours), [1] walls along z, each [crest height, drop, step toward the
## low side, water run, lead, water depth, crest node indices], at the higher
## node; [2] convex corners (crests of both).
static func _walls(env,g:PackedFloat64Array,ground_at:Callable,wet:=PackedFloat64Array())->Array:
 var w:int=env.w;var h:int=env.h;var n:=g.size()
 var out:=[]
 for axis in 2:
  var step:=w if axis==0 else 1
  var crest:=PackedFloat64Array();crest.resize(n);crest.fill(-INF)
  var drop:=PackedFloat64Array();drop.resize(n)
  var toward:=PackedInt32Array();toward.resize(n)
  var run:=PackedFloat64Array();run.resize(n);run.fill(INF)
  # Distance from a crest node to its wall line: the terrain's top stays
  # level up to the cell boundary, so the shoulder starts there, not half a
  # grid step early (a slope kink along every crest, September 28).
  var lead:=PackedFloat64Array();lead.resize(n)
  # Water standing over each crest's foot (0 where dry).
  var depth:=PackedFloat64Array();depth.resize(n)
  var mark:=func(top:int,low:int,d:float)->void:
   # Water pouring over a crest is not a rock shoulder: a rounded bank grown
   # from it buried the falling water (September 27/28).
   if not wet.is_empty() and _wet(wet,env.ground,top):return
   # A wall standing in deep water drops only to the water's floor.
   if g[low]>env.ground[low]+1e-6:d=minf(d,g[top]-g[low])
   if d<.02:return
   if d>drop[top]:crest[top]=g[top];drop[top]=d;toward[top]=low-top
  # The terrain's own walls: its two owners differ at a cell boundary.
  var o:float=env.origin.y if axis==0 else env.origin.x
  var count:=h if axis==0 else w
  var first:=ceili((o-CELL*.5)/CELL)
  var b:=first
  while true:
   var at:=CELL*.5+CELL*b
   var kb:=roundi((at-o)/H)
   b+=1
   if kb>=count:break
   if kb<1:continue
   for t in (w if axis==0 else h):
    var along:float=(env.origin.x if axis==0 else env.origin.y)+t*H
    var before:float=ground_at.call(Vector2(along,at-.001) if axis==0 else Vector2(at-.001,along))
    var after:float=ground_at.call(Vector2(along,at+.001) if axis==0 else Vector2(at+.001,along))
    if absf(before-after)<.02:continue
    var i0:=((kb-1)*w+t) if axis==0 else (t*w+kb-1)
    var i1:=i0+step
    if before>after:
     mark.call(i0,i1,before-after)
     if toward[i0]==i1-i0:lead[i0]=maxf(lead[i0],at-o-(kb-1)*H)
    else:mark.call(i1,i0,after-before)
  # Any other discontinuity between nodes.
  for k in h:
   for i in w:
    var idx:=k*w+i
    if (axis==0 and k==h-1) or (axis==1 and i==w-1):continue
    var d:=g[idx]-g[idx+step]
    if absf(d)<JUMP:continue
    if d>0.0:mark.call(idx,idx+step,d)
    else:mark.call(idx+step,idx,-d)
  # Width of the water each crest faces: the wet run straight across from
  # its foot to the opposite bank (INF where none: open water or dry).
  if not wet.is_empty():
   for idx in n:
    if crest[idx]==-INF:continue
    # The water may begin a node past the wall line (its boundary node).
    var q:=idx+toward[idx];var length:=0.0;var found:=false
    for j in 160:
     if q<0 or q>=n or (axis==1 and absi(q%w-idx%w)>j+2):break
     if not _wet(wet,env.ground,q):
      if length==0.0 and j<2:
       q+=toward[idx];continue
      found=length>0.0;break
     length+=H;q+=toward[idx]
    if found:run[idx]=length
    for ahead: int in [1,2]:
     var foot:=idx+toward[idx]*ahead
     if foot>=0 and foot<n and _wet(wet,env.ground,foot):
      depth[idx]=wet[foot]-env.ground[foot];break
  # The crest nodes in index order (the closings visit only these).
  var crests:=PackedInt32Array()
  if crest.count(-INF)<n:
   for idx in n:
    if crest[idx]!=-INF:crests.append(idx)
  out.append([crest,drop,toward,run,lead,depth,crests])
 var corners:=PackedFloat64Array();corners.resize(n)
 for idx in n:corners[idx]=minf(out[0][0][idx],out[1][0][idx])
 out.append(corners)
 return out

## The closing of the walls alone: each crest's parabola stamped across its
## wall toward the low side (its shoulder widening below LOW) and eroded by
## the foot across the wall; convex corners isotropically. Exactly the
## former closing across a tall wall under a level top, and the ground
## itself wherever no crest reaches. A shoulder widened below LOW never
## stands higher over the ground than its crest's drop: over a low side that
## keeps falling (the wall shortening across an E1 cliff-end tile) the
## widened shoulder of a wall centimetres high stood two metres over the
## slope. Over level ground below the wall, and for walls of LOW or more,
## this is the former stamp.
## `along`, when given (sized like g), receives each wall's lift carried
## along the wall (dilated by the foot radius in the wall's own direction).
## `ground_rows`: a cache, shared by calls over the same ground, of its rows'
## erosions per foot radius.
static func _close_walls(g:PackedFloat64Array,walls:Array,w:int,h:int,shoulder:float,foot:float,channel:=PackedByteArray(),along:=PackedFloat64Array(),ground_rows=null)->PackedFloat64Array:
 var out:=g.duplicate()
 var n:=g.size()
 for axis in 2:
  var crest:PackedFloat64Array=walls[axis][0];var drop:PackedFloat64Array=walls[axis][1]
  var toward:PackedInt32Array=walls[axis][2]
  var spread:=g.duplicate()
  # Crests facing a broad water corridor round to fit it: their closed
  # profile (shoulder, then foot fillet) is compressed across the wall by a
  # scale that varies smoothly along the wall, so neighbouring columns never
  # jump between a fitted and a free bank.
  var scale:=PackedFloat64Array()
  if walls[axis].size()>3:scale=_channel_scale(walls[axis],w,n,axis,shoulder,foot)
  var fitted:=g.duplicate();var any_fitted:=false
  # The lines (columns for axis 0, rows for axis 1) a crest stamps; the
  # stamps run along them. An unstamped line closes to its own ground, which
  # an erosion never rises over: it is skipped (always_transform: not).
  var lines:=PackedByteArray();lines.resize(w if axis==0 else h)
  if always_transform:lines.fill(1)
  for idx:int in (walls[axis][6] if walls[axis].size()>6 else range(n)):
   if crest[idx]==-INF:continue
   lines[idx%w if axis==0 else idx/w]=1
   var shoulder_radius:=shoulder*clampf(LOW/drop[idx],1.0,WIDEN)
   var radius:=shoulder_radius+foot
   var lead:float=walls[axis][4][idx] if walls[axis].size()>4 else 0.0
   var squeeze:=scale[idx] if not scale.is_empty() else 1.0
   var q:=idx
   if squeeze<.999:
    # The analytic closing of one step: shoulder radius Rs to the tangent
    # point x1, foot fillet radius F to the full extent X.
    any_fitted=true
    var rs:=shoulder_radius*squeeze;var rf:=foot*squeeze
    var extent:=sqrt(2.0*(rs+rf)*drop[idx]);var x1:=extent*rs/(rs+rf)
    var base:float=crest[idx]-drop[idx]
    for j in ceili((extent+lead)/H)+1:
     if q<0 or q>=n:break
     var x:=maxf(0.0,j*H-lead)
     var y:=crest[idx]-x*x/(2.0*rs) if x<=x1 else base+(extent-x)*(extent-x)/(2.0*rf)
     fitted[q]=maxf(fitted[q],y)
     if not channel.is_empty():channel[q]=1
     if axis==1 and (q%w==0 and toward[idx]<0 or q%w==w-1 and toward[idx]>0):break
     q+=toward[idx]
    continue
   var plain:=shoulder+foot
   var reach:=ceili((maxf(sqrt(2.0*plain*(drop[idx]+1.0)),sqrt(2.0*radius*drop[idx]))+lead)/H)+1
   for j in reach+1:
    if q<0 or q>=n:break
    var d:=maxf(0.0,j*H-lead)
    # The widened shoulder keeps the face's plan width, never its height:
    # it stands at most the crest's drop over the ground (see above).
    var widened:=minf(crest[idx],g[q]+drop[idx])-d*d/(2.0*radius)
    spread[q]=maxf(spread[q],maxf(crest[idx]-d*d/(2.0*plain),widened))
    # Stay in this row/column.
    if axis==1 and (q%w==0 and toward[idx]<0 or q%w==w-1 and toward[idx]>0):break
    q+=toward[idx]
  var closed:=_envelope_axis(spread,w,h,H*H/(2.0*foot),axis==0,lines)
  # Where along each stamped line the closing lifts the ground: the lines
  # across them (rows for axis 0) that carry any lift.
  var lifted:=PackedByteArray();lifted.resize(h if axis==0 else w)
  if always_transform:lifted.fill(1)
  var lift:=PackedFloat64Array()
  if not along.is_empty():
   lift.resize(n);lift.fill(-0.0)
  var count:=w if axis==0 else h
  var length:=h if axis==0 else w
  var stride:=w if axis==0 else 1
  for line in count:
   if not lines[line]:continue
   var idx:=line if axis==0 else line*w
   for t in length:
    out[idx]=maxf(out[idx],maxf(closed[idx],fitted[idx]) if any_fitted else closed[idx])
    if not along.is_empty():
     lift[idx]=-maxf(closed[idx]-g[idx],0.0)
     if lift[idx]<0.0:lifted[t]=1
    idx+=stride
  if not along.is_empty():
   # Walls of axis 0 run along x (rows), of axis 1 along z (columns).
   lift=_envelope_axis(lift,w,h,H*H/(2.0*foot),axis==1,lifted)
   # A line with no lift erodes to zero everywhere: along keeps its value.
   for line in lifted.size():
    if not lifted[line]:continue
    var idx:=line*w if axis==0 else line
    for t in (w if axis==0 else h):
     along[idx]=maxf(along[idx],-lift[idx])
     idx+=1 if axis==0 else w
 # Convex corners round isotropically. Without one the rounding is the
 # ground's own erosion, which never rises over it.
 var corners:PackedFloat64Array=walls[2]
 if always_transform:
  var full:=_dilate(corners,w,h,shoulder+foot)
  for idx in full.size():full[idx]=maxf(full[idx],g[idx])
  full=_erode(full,w,h,foot)
  for idx in out.size():out[idx]=maxf(out[idx],full[idx])
  return out
 if corners.count(-INF)==n:return out
 # The same closing, computed only where it can lift: a row without a corner
 # dilates to nothing (it stays -INF until the column pass); the rounding
 # stands over the ground only at nodes D, and elsewhere the erosion stays
 # under the ground. Rows where the rounding is the ground erode exactly as
 # the ground does (shared per foot in `ground_rows`).
 var corner_rows:=PackedByteArray();corner_rows.resize(h)
 for k in h:
  for i in w:
   if corners[k*w+i]!=-INF:corner_rows[k]=1;break
 var neg:=PackedFloat64Array();neg.resize(n)
 for idx in n:neg[idx]=-corners[idx]
 var reach:=H*H/(2.0*(shoulder+foot))
 neg=_envelope_axis(_envelope_axis(neg,w,h,reach,false,corner_rows),w,h,reach,true)
 var round:=g.duplicate()
 var lift_rows:=PackedByteArray();lift_rows.resize(h)
 var lift_cols:=PackedByteArray();lift_cols.resize(w)
 for idx in n:
  var dilated:=-neg[idx]
  if dilated>g[idx]:round[idx]=dilated;lift_rows[idx/w]=1;lift_cols[idx%w]=1
 var a:=H*H/(2.0*foot)
 if ground_rows==null:ground_rows={}
 if not ground_rows.has(foot):ground_rows[foot]=_envelope_axis(g,w,h,a,false)
 var lifted_rows:=_envelope_axis(round,w,h,a,false,lift_rows)
 var row_pass:PackedFloat64Array=(ground_rows[foot] as PackedFloat64Array).duplicate()
 for k in h:
  if not lift_rows[k]:continue
  for i in w:row_pass[k*w+i]=lifted_rows[k*w+i]
 round=_envelope_axis(row_pass,w,h,a,true,lift_cols)
 for i in w:
  if not lift_cols[i]:continue
  for k in h:out[k*w+i]=maxf(out[k*w+i],round[k*w+i])
 return out

## The lip over each node: the ground on the high side of every wall line
## whose rounding reaches the node across the line, falling away from the line
## as the widest shoulder does unless `shouldered` is false (-INF where none). The line
## runs on past the wall's ends by the fillet's reach, its lip there the
## ground at the line, which the crest meets as the wall shrinks to nothing.
## The foot fillet is an isotropic closing: where the top climbs along a wall
## (a cliff dying into a slope) it carried the higher crest a metre or two
## along the wall, and the low side stood up to 0.9 m over the plateau's own
## edge beside it, which keeps its ground: a trough along the wall line (owner
## photo 1, October 4). Under this lip the fillet still fills feet, inner
## corners and the crease past a wall's end, all of which lie below it.
static func _lips(walls:Array,g:PackedFloat64Array,w:int,n:int,shouldered:=true)->PackedFloat64Array:
 var lips:=PackedFloat64Array();lips.resize(n);lips.fill(-INF)
 var shoulder:=SHOULDER.y
 var past:=ceili(2.0*FOOT/H)
 for axis in 2:
  var drop:PackedFloat64Array=walls[axis][1]
  var toward:PackedInt32Array=walls[axis][2];var lead:PackedFloat64Array=walls[axis][4]
  # Walls of axis 0 run along x (rows), of axis 1 along z (columns).
  var step:=1 if axis==0 else w
  # Each high-side node on a line: how far its stamp runs, per direction.
  var runs:={}
  for idx:int in walls[axis][6]:
   var radius:=shoulder*clampf(LOW/drop[idx],1.0,WIDEN)+FOOT
   var reach:=ceili((maxf(sqrt(2.0*(shoulder+FOOT)*(drop[idx]+1.0)),sqrt(2.0*radius*drop[idx]))+lead[idx])/H)+1
   for k in range(-past,past+1):
    var at:=idx+k*step
    if at<0 or at>=n or (axis==0 and at/w!=idx/w):continue
    var key:=Vector2i(at,toward[idx])
    var run:Vector2=runs.get(key,Vector2.ZERO)
    runs[key]=Vector2(maxf(run.x,reach),maxf(run.y,lead[idx]))
  for key:Vector2i in runs:
   var q:=key.x;var lip:=g[key.x];var run:Vector2=runs[key]
   for j in int(run.x)+1:
    if q<0 or q>=n:break
    # Falling away from the lip as the widest shoulder does: held level,
    # the bound left a terrace edge where the crest climbs along the wall.
    var d:=maxf(0.0,j*H-run.y) if shouldered else 0.0
    lips[q]=maxf(lips[q],lip-d*d/(2.0*(shoulder+FOOT)))
    if axis==1 and (q%w==0 and key.y<0 or q%w==w-1 and key.y>0):break
    q+=key.y
 return lips

## Horizontal squeeze (area scale) of each crest's closed profile so its bank
## goes under the water a quarter core short of the middle of the corridor
## it faces (1 where no broad corridor). Limited along the wall so the bank
## narrows gradually where the channel begins.
static func _channel_scale(wall:Array,w:int,n:int,axis:int,shoulder:float,foot:float)->PackedFloat64Array:
 var crest:PackedFloat64Array=wall[0];var drop:PackedFloat64Array=wall[1]
 var toward:PackedInt32Array=wall[2];var run:PackedFloat64Array=wall[3]
 var root:=PackedFloat64Array();root.resize(n);root.fill(1.0)
 var any:=false
 for idx in n:
  if crest[idx]==-INF or not is_finite(run[idx]):continue
  var weight:=smoothstep(1.25*CHANNEL_CORE,1.75*CHANNEL_CORE,run[idx])
  if weight<=0.0:continue
  var rs:=shoulder*clampf(LOW/drop[idx],1.0,WIDEN);var d:=drop[idx]
  var extent:=sqrt(2.0*(rs+foot)*d)
  # Where the free profile meets the water surface over its foot.
  var above:=clampf(float(wall[5][idx]),0.0,d)
  var at_water:=extent-sqrt(2.0*foot*above) if above<=d*foot/(rs+foot) else sqrt(2.0*rs*(d-above))
  var shore:=maxf(run[idx]*.5-CHANNEL_CORE*.25,run[idx]*.25)
  if at_water<=shore:continue
  root[idx]=lerpf(1.0,maxf(.1,shore/at_water),weight);any=true
 if not any:return PackedFloat64Array()
 var along:=1 if axis==0 else w
 for sweep in 2:
  var order:=range(n) if sweep==0 else range(n-1,-1,-1)
  var step:=-along if sweep==0 else along
  for idx:int in order:
   var prev:=idx+step
   if crest[idx]==-INF or prev<0 or prev>=n or crest[prev]==-INF or toward[prev]!=toward[idx]:continue
   root[idx]=minf(root[idx],root[prev]+.08)
 for idx in n:root[idx]*=root[idx]
 return root

## min over nodes of the same column (or row) of f(p) + a*|q-p|^2.
## `only`, when given (one flag per column or row): lines without a flag are
## left as they are.
static func _envelope_axis(f:PackedFloat64Array,w:int,h:int,a:float,columns:bool,only:=PackedByteArray())->PackedFloat64Array:
 if NativeGridKernels.enabled:return NativeGridKernels.envelope_axis(f,w,h,a,columns,only)
 var n:=maxi(w,h)
 var result:=PackedFloat64Array();result.resize(n)
 var v:=PackedInt32Array();v.resize(n)
 var z:=PackedFloat64Array();z.resize(n+1)
 if columns:
  var out:=f.duplicate()
  var line:=PackedFloat64Array();line.resize(h)
  for i in w:
   if not only.is_empty() and not only[i]:continue
   for k in h:line[k]=f[k*w+i]
   _envelope1(line,h,a,result,v,z)
   for k in h:out[k*w+i]=result[k]
  return out
 # Rows are contiguous: copied in and out whole.
 var rows:=PackedFloat64Array()
 for k in h:
  var line:=f.slice(k*w,k*w+w)
  if only.is_empty() or only[k]:
   _envelope1(line,w,a,result,v,z)
   line=result.slice(0,w)
  rows.append_array(line)
 return rows

## Separable square-window max (or min) over `reach` metres, in linear time
## (van Herk / Gil-Werman: block prefix and suffix extrema).
static func _window(g:PackedFloat64Array,w:int,h:int,reach:float,highest:bool)->PackedFloat64Array:
 if NativeGridKernels.enabled:return NativeGridKernels.window(g,w,h,reach,highest)
 var r:=ceili(reach/H)
 var rows:=g.duplicate()
 var line:=PackedFloat64Array()
 for k in h:
  line.resize(w)
  for i in w:line[i]=g[k*w+i]
  line=_slide(line,r,highest)
  for i in w:rows[k*w+i]=line[i]
 var out:=rows.duplicate()
 for i in w:
  line.resize(h)
  for k in h:line[k]=rows[k*w+i]
  line=_slide(line,r,highest)
  for k in h:out[k*w+i]=line[k]
 return out

static func _slide(f:PackedFloat64Array,r:int,highest:bool)->PackedFloat64Array:
 var n:=f.size();var size:=2*r+1
 var pre:=PackedFloat64Array();pre.resize(n)
 var suf:=PackedFloat64Array();suf.resize(n)
 for i in n:
  pre[i]=f[i] if i%size==0 else (maxf(pre[i-1],f[i]) if highest else minf(pre[i-1],f[i]))
 for i in range(n-1,-1,-1):
  suf[i]=f[i] if (i%size==size-1 or i==n-1) else (maxf(suf[i+1],f[i]) if highest else minf(suf[i+1],f[i]))
 var out:=PackedFloat64Array();out.resize(n)
 for i in n:
  var a:=suf[maxi(0,i-r)];var b:=pre[mini(n-1,i+r)]
  out[i]=maxf(a,b) if highest else minf(a,b)
 return out

## Value at a world point on the grid (nearest node; exact at grid points).
func at(q:Vector2)->float:
 var i:=clampi(roundi((q.x-origin.x)/H),0,w-1);var k:=clampi(roundi((q.y-origin.y)/H),0,h-1)
 return surface[k*w+i]

## Rock exposure, bilinear (0 where no study variant exposes rock).
func rock_at(q:Vector2)->float:
 if rock.is_empty():return 0.0
 var p:=(q-origin)/H
 var i:=clampi(floori(p.x),0,w-2);var k:=clampi(floori(p.y),0,h-2)
 var fx:=clampf(p.x-i,0.0,1.0);var fz:=clampf(p.y-k,0.0,1.0)
 return lerpf(lerpf(rock[k*w+i],rock[k*w+i+1],fx),lerpf(rock[(k+1)*w+i],rock[(k+1)*w+i+1],fx),fz)

func moss_grade_at(q:Vector2)->float:
 if moss_grade.is_empty():return 0.0
 var p:=(q-origin)/H
 var i:=clampi(floori(p.x),0,w-2);var k:=clampi(floori(p.y),0,h-2)
 var fx:=clampf(p.x-i,0.0,1.0);var fz:=clampf(p.y-k,0.0,1.0)
 return lerpf(lerpf(moss_grade[k*w+i],moss_grade[k*w+i+1],fx),lerpf(moss_grade[(k+1)*w+i],moss_grade[(k+1)*w+i+1],fx),fz)

func excluded_node(q:Vector2)->bool:
 if excluded.is_empty():return false
 var i:=clampi(roundi((q.x-origin.x)/H),0,w-1);var k:=clampi(roundi((q.y-origin.y)/H),0,h-1)
 return excluded[k*w+i]!=0

func ground_node(q:Vector2)->float:
 var i:=clampi(roundi((q.x-origin.x)/H),0,w-1);var k:=clampi(roundi((q.y-origin.y)/H),0,h-1)
 return ground[k*w+i]

## Bilinear between nodes, for rock placement off the grid.
func sample(q:Vector2)->float:
 var p:=(q-origin)/H
 var i:=clampi(floori(p.x),0,w-2);var k:=clampi(floori(p.y),0,h-2)
 var fx:=clampf(p.x-i,0.0,1.0);var fz:=clampf(p.y-k,0.0,1.0)
 var a:=lerpf(surface[k*w+i],surface[k*w+i+1],fx)
 var b:=lerpf(surface[(k+1)*w+i],surface[(k+1)*w+i+1],fx)
 return lerpf(a,b,fz)

func contains(q:Vector2)->bool:
 return q.x>=origin.x and q.y>=origin.y and q.x<=origin.x+(w-1)*H and q.y<=origin.y+(h-1)*H

## Whether the slope covers a wall point at `origin` whose top is `top`: on
## every low side (ground more than `drop` below the top, `far` out) the slope
## just past the crest (`near` out) stands at least at that top.
func covers_piece(origin:Vector3,top:float,near:=1.6,far:=2.6,drop:=1.0)->bool:
 var low:=false
 var p:=Vector2(origin.x,origin.z)
 for a in 8:
  var dir:=Vector2.from_angle(a*PI*.25)
  if not contains(p+dir*far):return false
  if ground_node(p+dir*far)>top-drop:continue
  low=true
  if at(p+dir*near)<top-.3:return false
 return low

## A buried skirt can leave its top 2 cm above the sunken sheet. Require a full grid neighbourhood above every
## tested point, so exposed cut walls keep their backing.
func _buried_skirt_point(p:Vector3)->bool:
 if replacement_columns.is_empty():return false
 var q:=Vector2i((Vector2(p.x,p.z)/H).floor())
 for dz in range(-1,3):
  for dx in range(-1,3):
   var key:=q+Vector2i(dx,dz)
   var point:=Vector2(key)*H
   if not replacement_columns.has(key) or not contains(point) or at(point)<p.y-.03:return false
 return true

## Skirt triangles (the mesher's vertical rock faces) the slope does not
## cover, checked at every corner and the centre. Every skirt stands on its
## wall line (a dual-cell border, x or z = 12 i + 6); coverage is measured from
## that line.
const SEAM_NEAR:=.1
const SEAM_FAR:=.6
static func _on_seam(p:Vector3,a:Vector3,b:Vector3,c:Vector3)->Vector3:
 var tile:=TerrainTileField.SPACING
 if absf(a.x-b.x)+absf(a.x-c.x)<.001:return Vector3((roundf(p.x/tile-.5)+.5)*tile,p.y,p.z)
 if absf(a.z-b.z)+absf(a.z-c.z)<.001:return Vector3(p.x,p.y,(roundf(p.z/tile-.5)+.5)*tile)
 return p
func uncovered_faces(arrays:Array)->Array:
 if arrays.is_empty():return arrays
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:=PackedInt32Array(arrays[Mesh.ARRAY_INDEX]) if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
 if indices.is_empty():
  indices.resize(vertices.size())
  for i in vertices.size():indices[i]=i
 var kept:=PackedInt32Array()
 for t in range(0,indices.size(),3):
  var a:=vertices[indices[t]];var b:=vertices[indices[t+1]];var c:=vertices[indices[t+2]]
  # Each point is tested against the skirt's own top and bottom in its
  # column: along a descending crest the triangle's highest vertex stands
  # over lower ground than its other points, and a low wall's drop is less
  # than a metre.
  var tri:=[a,b,c]
  var span:=func(p:Vector3)->Vector2:
   var r:=Vector2(INF,-INF)
   for v:Vector3 in tri:
    if absf(v.x-p.x)+absf(v.z-p.z)<.01:r=Vector2(minf(r.x,v.y),maxf(r.y,v.y))
   return r
  var spans:Array=[span.call(a),span.call(b),span.call(c)]
  var centre:Vector2=(spans[0]+spans[1]+spans[2])/3.0
  var covered:=true
  for k in 4:
   var p:Vector3=tri[k] if k<3 else (a+b+c)/3.0
   var col:Vector2=spans[k] if k<3 else centre
   var drop:=clampf(.5*(col.y-col.x),.05,1.0)
   if not _buried_skirt_point(p) and not covers_piece(_on_seam(p,a,b,c),col.y,SEAM_NEAR,SEAM_FAR,drop):covered=false;break
  if not covered:kept.append_array(PackedInt32Array([indices[t],indices[t+1],indices[t+2]]))
 if kept.size()==indices.size():return arrays
 var out:=arrays.duplicate()
 out[Mesh.ARRAY_INDEX]=kept
 return out if not kept.is_empty() else []

## Ridge blend: 0 = narrow shoulder (valley), 1 = wide (ridge crest). Noise
## is taken at the lip point each point falls from (the dilation's source:
## q + R grad D), so ridges run down the fall lines; a light blur removes the
## jump where two walls' fall lines meet at an inner corner. Fine bumps and
## divots ride on top, within the same narrow..wide band, so they can never
## rise over the lip or through the ground.
static func _ridges(env:RefCounted,narrow:PackedFloat64Array,wide:PackedFloat64Array,dilated:PackedFloat64Array,seed_value:int)->PackedFloat64Array:
 var w:int=env.w;var h:int=env.h
 var t:=PackedFloat64Array();t.resize(w*h);t.fill(.5)
 var reach:=SHOULDER.y+FOOT
 for k in range(1,h-1):
  for i in range(1,w-1):
   var idx:=k*w+i
   if wide[idx]-narrow[idx]<.005:continue
   var q:Vector2=env.origin+Vector2(i,k)*H
   var grad:=Vector2(dilated[idx+1]-dilated[idx-1],dilated[idx+w]-dilated[idx-w])/(2.0*H)
   var src:=(q+grad*reach).snapped(Vector2.ONE*.25)
   var p:=Vector3(src.x,0,src.y)
   var warp:=(Helper._value_noise01(p,seed_value+9131,23.0)-.5)*12.0
   var r:=.6*(Helper._value_noise01(p+Vector3(warp,0,-warp),seed_value+9133,7.0)*2.0-1.0) \
    +.4*(Helper._value_noise01(p+Vector3(warp,0,-warp),seed_value+9137,14.0)*2.0-1.0)
   t[idx]=.5+.5*clampf(signf(r)*pow(absf(r)*1.6,.7),-1.0,1.0)
 t=_blur(_blur(t,w,h,2),w,h,2)
 for idx in t.size():t[idx]=smoothstep(.22,.78,t[idx])
 for k in h:
  for i in w:
   var idx:=k*w+i
   if wide[idx]-narrow[idx]<.005:continue
   var p:=Vector3(env.origin.x+i*H,0,env.origin.y+k*H)
   var bump:=(Helper._value_noise01(p,seed_value+9301,4.5)-.5)*.15+(Helper._value_noise01(p,seed_value+9307,2.6)-.5)*.04
   t[idx]=clampf(t[idx]+bump,0.0,1.0)
 return t

## max over p of g(p) - |q-p|^2/(2R).
static func _dilate(g:PackedFloat64Array,w:int,h:int,radius:float)->PackedFloat64Array:
 var neg:=PackedFloat64Array();neg.resize(g.size())
 for idx in g.size():neg[idx]=-g[idx]
 var out:=_envelope2(neg,w,h,H*H/(2.0*radius))
 for idx in out.size():out[idx]=-out[idx]
 return out

## min over p of g(p) + |q-p|^2/(2R).
static func _erode(g:PackedFloat64Array,w:int,h:int,radius:float)->PackedFloat64Array:
 return _envelope2(g,w,h,H*H/(2.0*radius))

## Euclidean distance (world units) to the nearest set node.
static func _distance(mask:PackedByteArray,w:int,h:int)->PackedFloat64Array:
 var f:=PackedFloat64Array();f.resize(mask.size())
 for idx in mask.size():f[idx]=0.0 if mask[idx] else INF
 var out:=_envelope2(f,w,h,1.0)
 for idx in out.size():out[idx]=sqrt(out[idx])*H
 return out

## min over nodes of f(p) + a*|q-p|^2 (grid units): rows then columns.
static func _envelope2(f:PackedFloat64Array,w:int,h:int,a:float)->PackedFloat64Array:
 return _envelope_axis(_envelope_axis(f,w,h,a,false),w,h,a,true)

## Lower envelope of the parabolas f[k] + a*(q-k)^2 (Felzenszwalb and
## Huttenlocher). Infinite entries take no part.
static func _envelope1(f:PackedFloat64Array,n:int,a:float,out:PackedFloat64Array,v:PackedInt32Array,z:PackedFloat64Array)->void:
 var k:=-1
 for q in n:
  var fq:=f[q]
  if fq==INF:continue
  if k<0:
   k=0;v[0]=q;z[0]=-INF;z[1]=INF;continue
  var s:=((fq+a*q*q)-(f[v[k]]+a*v[k]*v[k]))/(2.0*a*(q-v[k]))
  while s<=z[k]:
   k-=1
   if k<0:break
   s=((fq+a*q*q)-(f[v[k]]+a*v[k]*v[k]))/(2.0*a*(q-v[k]))
  k+=1
  v[k]=q;z[k]=-INF if k==0 else s;z[k+1]=INF
 if k<0:
  for q in n:out[q]=INF
  return
 var j:=0
 for q in n:
  while z[j+1]<q:j+=1
  var d:=q-v[j]
  out[q]=f[v[j]]+a*d*d

## Box blur of radius r nodes, rows then columns.
static func _blur(f:PackedFloat64Array,w:int,h:int,r:int)->PackedFloat64Array:
 if NativeGridKernels.enabled:return NativeGridKernels.blur(f,w,h,r)
 var tmp:=f.duplicate()
 for k in h:
  var sum:=0.0;var count:=0
  for i in range(0,mini(r,w)):sum+=f[k*w+i];count+=1
  for i in w:
   if i+r<w:sum+=f[k*w+i+r];count+=1
   if i-r-1>=0:sum-=f[k*w+i-r-1];count-=1
   tmp[k*w+i]=sum/count
 var out:=tmp.duplicate()
 for i in w:
  var sum:=0.0;var count:=0
  for k in range(0,mini(r,h)):sum+=tmp[k*w+i];count+=1
  for k in h:
   if k+r<h:sum+=tmp[(k+r)*w+i];count+=1
   if k-r-1>=0:sum-=tmp[(k-r-1)*w+i];count-=1
   out[k*w+i]=sum/count
 return out

## STUDY (owner, September 25 rethink): bedrock exposed in the slope surface
## itself. A patch mask picks parts of steep faces; inside, the moss slope is
## carved into blocky benches: Voronoi blocks (world lattice) each terrace the
## slope with their own phase, bench height and riser, so benches break into
## upright blocks and never line up into courses. Benches are flat, grassed
## ledges; risers are bare rock. The carve fades to nothing at the patch edge,
## so moss runs into rock without a lip; blocks jut only in the interior.
const BLOCK:=5.5
const PATCH:=14.0
const STRETCH:=2.2
## The bedrock moss grade of surface F (as _bedrock computes it): the slope's
## steepness, blurred; zero on the grid border.
static func _moss_grade(env,F:PackedFloat64Array)->PackedFloat64Array:
 var n:int=env.w*env.h;var w:int=env.w;var hh:int=env.h
 var grade:=PackedFloat64Array();grade.resize(n)
 for k in range(1,hh-1):
  for i in range(1,w-1):
   var idx:=k*w+i
   var gx:=(F[idx+1]-F[idx-1])/(2.0*H);var gz:=(F[idx+w]-F[idx-w])/(2.0*H)
   grade[idx]=1.0-1.0/sqrt(1.0+gx*gx+gz*gz)
 return _blur(grade,w,hh,2)
## `any_cut`: false when `cut` is zero everywhere.
static func _bedrock(env,floor_level:PackedFloat64Array,top:PackedFloat64Array,cliff:PackedFloat64Array,seed_value:int,cut:PackedFloat64Array,any_cut:=true)->void:
 var n:int=env.w*env.h;var w:int=env.w;var hh:int=env.h
 var F:PackedFloat64Array=env.surface.duplicate()
 env.moss_grade.resize(n)
 var crown:=PackedByteArray();crown.resize(n)
 for k in range(1,hh-1):
  for i in range(1,w-1):
   var idx:=k*w+i
   var gx:=(F[idx+1]-F[idx-1])/(2.0*H);var gz:=(F[idx+w]-F[idx-w])/(2.0*H)
   env.moss_grade[idx]=1.0-1.0/sqrt(1.0+gx*gx+gz*gz)
   if absf(F[idx]-env.ground[idx])<.05 and F[idx]-floor_level[idx]>1.0 and gx*gx+gz*gz<.04:crown[idx]=1
 var crown_distance:=_distance(crown,w,hh)
 env.moss_grade=_blur(env.moss_grade,w,hh,2)
 var raw:=PackedFloat64Array();raw.resize(n)
 var lattice:={}
 var noise:=func(q:Vector2,scale:float,salt:int)->float:
  var p:=q/scale;var i:=floori(p.x);var k:=floori(p.y);var f:=p-Vector2(i,k)
  f=f*f*(Vector2(3,3)-2.0*f)
  var c:=func(a:int,b:int)->float:
   var key:=Vector3i(a,b,salt)
   if not lattice.has(key):lattice[key]=Helper.position_hash01(Vector3(a,b,salt)*.5,seed_value+4431)
   return lattice[key]
  return lerpf(lerpf(c.call(i,k),c.call(i+1,k),f.x),lerpf(c.call(i,k+1),c.call(i+1,k+1),f.x),f.y)
 var patch:=PackedFloat64Array();patch.resize(n)
 for k in range(1,hh-1):
  for i in range(1,w-1):
   var idx:=k*w+i
   # Where a road or water cut the slope back, the cut face is bare rock.
   # It stays the planar cut: benches on its creased backing made spikes.
   raw[idx]=smoothstep(.3,1.0,cut[idx])
   if cliff[idx]<=0.0:continue
   var gx:=(F[idx+1]-F[idx-1])/(2.0*H);var gz:=(F[idx+w]-F[idx-w])/(2.0*H)
   var steep:=sqrt(gx*gx+gz*gz)
   if steep<.45:continue
   var span:=maxf(top[idx]-floor_level[idx],1.0)
   var frac:=(F[idx]-floor_level[idx])/span
   var q:Vector2=env.origin+Vector2(i,k)*H
   var mask:float=.65*noise.call(q,PATCH,1)+.35*noise.call(q,PATCH*.45,2)
   var e:=smoothstep(.54,.7,mask+.3*(smoothstep(.6,1.6,steep)-.5))
   e*=smoothstep(.45,.9,steep)*smoothstep(.08,.28,frac)*cliff[idx]
   raw[idx]=maxf(raw[idx],e);patch[idx]=e
 raw=_blur(_blur(raw,w,hh,2),w,hh,2)
 # Benches stay clear of cut faces too: a tread running out over a cut's
 # crease stood proud as a lone column.
 # (Without a cut the zone is zero and leaves the patch as it is.)
 if any_cut or always_transform:
  var cut_zone:=PackedFloat64Array();cut_zone.resize(n)
  for idx in n:cut_zone[idx]=smoothstep(.05,.3,cut[idx])
  cut_zone=_blur(_blur(cut_zone,w,hh,2),w,hh,2)
  for idx in n:patch[idx]*=1.0-smoothstep(0.0,.2,cut_zone[idx])
 patch=_blur(_blur(patch,w,hh,2),w,hh,2)
 var cells:={}
 var cell_at:=func(c:Vector2i)->Array:
  if not cells.has(c):
   var hsh:=func(salt:int)->float:return Helper.position_hash01(Vector3(c.x,c.y,salt)*.5,seed_value+7727)
   var pt:=(Vector2(c)+Vector2(.15+.7*hsh.call(1),.15+.7*hsh.call(2)))*BLOCK
   # [feature point, phase, bench step, riser share]. One block in three is
   # 15% taller, interrupting the smaller shelves. The riser takes most of
   # the fall-line run, so faces lean with the hill (owner, September 26).
   var step:=lerpf(3.5,6.5,hsh.call(4))*(1.0 if hsh.call(7)>=.33 else 1.15)
   cells[c]=[pt,hsh.call(3)*step,step,lerpf(.60,.75,hsh.call(5))]
  return cells[c]
 var carved_nodes:=PackedByteArray();carved_nodes.resize(n)
 for k in range(1,hh-1):
  for i in range(1,w-1):
   var idx:=k*w+i
   # Never carve into flat ground the blur spread onto (plateau tops, feet).
   var gx:=(F[idx+1]-F[idx-1])/(2.0*H);var gz:=(F[idx+w]-F[idx-w])/(2.0*H)
   var grade:=sqrt(gx*gx+gz*gz)
   # Keep the whole rounded shoulder intact before the first rock bench.
   # A one-metre guard still allowed multi-metre cuts just beside the crown,
   # especially where two cliff edges meet above a water-constrained bank.
   var fade:=smoothstep(.3,.65,grade)*smoothstep(3.0,7.0,crown_distance[idx])
   raw[idx]*=fade
   var e:=patch[idx]*fade
   if e<.01:continue
   var q:Vector2=env.origin+Vector2(i,k)*H
   var base:=Vector2i(floori(q.x/BLOCK),floori(q.y/BLOCK))
   # Blocks stretch along the contour: long benches, fewer vertical splits.
   var fall:=Vector2(gx,gz)/grade
   var near:Array=[];var d1:=INF
   for dz in range(-2,3):
    for dx in range(-2,3):
     var cell:Array=cell_at.call(base+Vector2i(dx,dz))
     var delta:Vector2=q-cell[0];var across:=delta.dot(fall)
     var d:=sqrt(delta.length_squared()+(STRETCH*STRETCH-1.0)*across*across)
     near.append([d,cell]);d1=minf(d1,d)
   # Chipped bench edges: broad noise on where each riser starts.
   var height:float=F[idx]-.35*noise.call(q,4.6,3)
   # Neighbouring blocks join over a few metres, weighted by how close each
   # is to winning: side by side, their treads slope gently from one level
   # to the other. Blending only the two nearest jumped wherever the second
   # and third changed places, and a narrow join made one-cell fins, slots
   # and grooves the half-metre grid cannot draw (sawtooth facets).
   var carved:=0.0;var weight:=0.0
   for c:Array in near:
    var wt:=1.0-smoothstep(0.0,BLOCK_BLEND,float(c[0])-d1)
    if wt>0.0:carved+=wt*_bench(height,c[1],grade);weight+=wt
   carved/=weight
   # No rock above its local crest. An absolute height limit keeps the
   # tread level; a displacement limit made it follow the sloping backing.
   carved=minf(carved,maxf(F[idx],top[idx]-.5))
   # A narrow (about 2 m) transition: most of a patch is fully rock.
   # Keep the backing intact: a solid slope column, never a hole where the
   # native pieces are hidden, and no more than a shallow inward chip.
   var shaped:=maxf(lerpf(F[idx],carved,smoothstep(.15,.55,e)),F[idx]-BEDROCK_RECESS)
   env.surface[idx]=maxf(env.ground[idx]+minf(F[idx]-env.ground[idx],.4),shaped)
   carved_nodes[idx]=1
 _level_outward(env,F,carved_nodes)
 env.rock=raw

## Bench height over the backing height: level treads at n*step-phase, each
## joined to the next by a riser over the share r of the backing's drop. A
## tread meets the backing at its inner edge and stands proud at its outer
## edge, so rock only builds outward. Tread levels do not depend on r: the
## riser may take a different share of the run anywhere on a face without
## tilting a tread. Corners are rounded over a quarter of the riser each
## side, and every tread keeps TREAD metres of run: narrower treads and
## creases alias on the half-metre grid into sawtooth facets. For the same
## reason every riser keeps RISER metres of run. Where the backing is too
## steep to fit both, the bench fades into the backing slope.
const TREAD:=1.75
const RISER:=1.0
const CORNER:=.25
const BLOCK_BLEND:=3.0
## The half-metre node carries its cell's average height (a tent filter one
## grid step either side along the fall line): a crease between nodes would
## otherwise alias into sawtooth facets wherever it runs across the grid.
static func _bench(height:float,cell:Array,grade:float)->float:
 var reach:=grade*H*FILTER
 var a:=_bench_profile(height-.75*reach,cell,grade)+_bench_profile(height+.75*reach,cell,grade)
 return (a+3.0*(_bench_profile(height-.25*reach,cell,grade)+_bench_profile(height+.25*reach,cell,grade)))/8.0
const FILTER:=1.5
static func _bench_profile(height:float,cell:Array,grade:float)->float:
 var step:float=cell[2]
 var lo:=RISER*grade/step;var hi:=1.0-TREAD*grade/step
 var r:=clampf(float(cell[3]),lo,maxf(lo,hi))
 var n:=floorf((height+float(cell[1]))/step)
 var base:=n*step-float(cell[1])
 var x:=clampf((height-base)/(r*step),0.0,1.0)
 # Linear ramp with rounded ends (slope 0 at both, 1/(1-CORNER) between).
 var m:=1.0/(1.0-CORNER)
 var y:=m*x*x/(2.0*CORNER) if x<CORNER else (1.0-m*(1.0-x)*(1.0-x)/(2.0*CORNER) if x>1.0-CORNER else m*(x-CORNER*.5))
 return lerpf(height,base+step*y,smoothstep(0.0,.15,hi-lo))

## A ledge never rises as it runs out from the hill (owner, September 27):
## down the backing's fall line the rock stays level or falls. Carved nodes
## are visited from the highest backing down, each capped by the surface one
## grid line uphill on its own fall line, and never above the nearer uphill
## node (a shallow recess there left the tread standing proud as a lip,
## September 28). A fading patch edge, a neighbouring
## block's phase or a chipped riser can still tilt a tread from side to
## side, but none can lift its outer edge into a lip.
static func _level_outward(env,F:PackedFloat64Array,carved:PackedByteArray)->void:
 var w:int=env.w
 assert(carved.size()<1000000,"The sort key packs the node index in six digits")
 var order:=PackedInt64Array()
 for idx in carved.size():
  if carved[idx]:order.append(int(roundf((1e4-F[idx])*1000.0))*1000000+idx)
 order.sort()
 for key:int in order:
  var idx:=key%1000000
  var gx:=F[idx+1]-F[idx-1];var gz:=F[idx+w]-F[idx-w]
  if maxf(absf(gx),absf(gz))<1e-6:continue
  # The uphill point where the fall line meets the next grid line.
  var a:int;var b:int;var t:float
  if absf(gx)>=absf(gz):
   a=idx+(1 if gx>0.0 else -1);t=absf(gz/gx);b=a+(w if gz>0.0 else -w)
  else:
   a=idx+(w if gz>0.0 else -w);t=absf(gx/gz);b=a+(1 if gx>0.0 else -1)
  env.surface[idx]=minf(env.surface[idx],minf(env.surface[a],lerpf(env.surface[a],env.surface[b],t)))
