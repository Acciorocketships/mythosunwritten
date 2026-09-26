extends GutTest
## September 23 owner review: subtle rock (fuller straight/inner feet than
## convex corners), ground-up moss, and storey-quantised inner terraces.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const CORNERS=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const KIT=preload("res://scripts/terrain/field/CliffKitDressing.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED:=2697992464
const POSE:=Transform3D(Basis.IDENTITY,Vector3(12,0,30))

func before_all()->void:CRAGS.prepare();CORNERS.prepare()
func after_each()->void:STYLE.apply("chosen")

func _foot(faces:PackedVector3Array)->float:
 var columns:Dictionary={}
 for p:Vector3 in faces:
  if p.y>=0.0 and p.y<1.0:columns[p.x]=maxf(columns.get(p.x,0.0),p.z)
 var depths:=columns.values();depths.sort()
 return depths[depths.size()/2]

func test_subtle_foot_stays_close_to_the_wall()->void:
 # The unconstrained foot measured 6-9 m on a 4 m wall (a talus apron).
 for height:float in [4.0,8.0,16.0]:
  STYLE.apply("current")
  var old:=_foot(CRAGS.make(POSE,24,height,SEED)[0].faces)
  STYLE.apply("chosen")
  var now:=_foot(CRAGS.make(POSE,24,height,SEED)[0].faces)
  assert_lt(now,3.0,"A %d m wall's foot stays within 3 m"%height)
  assert_gt(now,1.5,"The foot still carries a real rock base")
  assert_lt(now,old*.45,"Subtle removes most of the pooled foot")

func test_convex_corners_keep_a_tighter_foot_than_straight_faces()->void:
 # Ledge lips were part of the fuller straight foot; with ledges off (owner,
 # September 24) the two feet measure alike, so compare with them on.
 STYLE.ledges=true
 assert_lt(CRAGS.SUBTLE_CORNER_FOOT,CRAGS.SUBTLE_FOOT)
 var wall:=_foot(CRAGS.make(POSE,24,8,SEED,null,false,false,[],CRAGS.SUBTLE_FOOT)[0].faces)
 var corner:=_foot(CRAGS.make(POSE,24,8,SEED,null,false,false,[],CRAGS.SUBTLE_CORNER_FOOT)[0].faces)
 assert_lt(corner,wall-.3,"The corner source foot is tighter")

func test_subtle_keeps_the_crown_and_most_wall_turf()->void:
 STYLE.apply("current")
 var old:Dictionary=CRAGS.make(POSE,24,8,SEED)[0]
 STYLE.apply("chosen")
 # Ledges are off for now (owner, September 24); compare like with like.
 STYLE.ledges=true
 var now:Dictionary=CRAGS.make(POSE,24,8,SEED)[0]
 var crown:Dictionary={}
 for p:Vector3 in old.faces:
  if p.y>=6.4:crown[p]=true
 var kept:=0;var total:=0
 for p:Vector3 in now.faces:
  if p.y>=6.4:
   total+=1
   if crown.has(p):kept+=1
 assert_gt(total,0)
 assert_eq(kept,total,"The upper fifth keeps the native crown exactly")
 assert_gt(now.green.size(),old.green.size()*.5,"Straight faces keep most ledge turf")

func test_moss_reads_height_and_lawn_tint()->void:
 var rock:Dictionary=CRAGS.make(POSE,24,8,SEED)[0]
 var arrays:Array=CRAGS.mesh_arrays(rock,null,SEED)[0]
 var rise:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 assert_eq(rise.size(),vertices.size())
 assert_almost_eq(rise[0].x,vertices[0].y,.0001,"Without terrain, rise is the local base height")
 assert_ne(Color(colors[0].r,colors[0].g,colors[0].b),Color(1,1,1),"Moss carries the lawn's biome tint")

func test_terrace_turf_sits_on_a_storey_band()->void:
 # 8 m corner: one storey below the crest, one above the pocket.
 assert_almost_eq(KIT.terrace_cap(24.0,16.0,16.2,.9),20.0,.0001)
 # 12 m corner: either whole-storey band, never half-height.
 for roll:float in [0.0,.49,.51,.99]:
  var cap:=KIT.terrace_cap(28.0,16.0,16.3,roll)
  assert_true(is_equal_approx(cap,24.0) or is_equal_approx(cap,20.0),"cap %f"%cap)
 # The lowest lip-to-ground height (one storey) has no terrace.
 assert_true(is_nan(KIT.terrace_cap(20.0,16.0,16.1,.5)))
 # An uneven pocket cannot carry a flat terrace.
 assert_true(is_nan(KIT.terrace_cap(28.0,16.0,18.0,.5)))

func test_collinear_panels_of_different_heights_abut_instead_of_fading()->void:
 # The ground steps a storey along one face: a 16 m and a 12 m run meet.
 # Both were treated as free ends and faded, leaving a bare native column.
 const RELIEF=preload("res://scripts/terrain/field/CliffRockRelief.gd")
 var walls:=[]
 for x:float in [-10.5,-7.5,-4.5]:
  for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x,12+y*4,10.5)))
 for x:float in [-1.5,1.5]:
  for y in 3:walls.append(Transform3D(Basis.IDENTITY,Vector3(x,16+y*4,10.5)))
 var panels:=RELIEF.panels(walls)
 assert_eq(panels.size(),2)
 for panel:Dictionary in panels:
  var towards_step:bool=(panel.pose as Transform3D).origin.x<-3.0
  assert_true(panel.right_abut if towards_step else panel.left_abut,"The storey step is a joint")
  assert_false(panel.left_abut if towards_step else panel.right_abut,"The far end stays free")
 assert_lt(CRAGS._end_fade(9.0,1),CRAGS._end_fade(9.0,0),"A joint fades less than a free end")
 for panel:Dictionary in panels:
  assert_true(bool(panel.right_extend or panel.left_extend),"Equal crests continue into each other")
 # A lower crest continues into its taller neighbour, never the reverse.
 var stepped:=[]
 for x:float in [-10.5,-7.5,-4.5]:
  for y in 4:stepped.append(Transform3D(Basis.IDENTITY,Vector3(x,12+y*4,10.5)))
 for x:float in [-1.5,1.5]:
  for y in 2:stepped.append(Transform3D(Basis.IDENTITY,Vector3(x,12+y*4,10.5)))
 for panel:Dictionary in RELIEF.panels(stepped):
  var lower:bool=float(panel.height)<16.0
  assert_eq(bool(panel.right_extend or panel.left_extend),lower,"Only the lower crest continues")

## Front depth of the finished formation at column x, height y.
func _depth(faces:PackedVector3Array,x:float,y:float)->float:
 var z:=-INF
 for p:Vector3 in faces:
  if absf(p.x-x)<.13 and absf(p.y-y)<.3:z=maxf(z,p.z)
 return z

const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")

func _sloped(form:Dictionary,others:Array=[])->Dictionary:
 var field=FIELD.new([form]+others,SEED)
 field.apply(form)
 return form

func test_ledges_are_off_for_now()->void:
 # Owner (September 24): ledge treads and their turf added slivers and bands.
 STYLE.apply("chosen")
 assert_true(CRAGS.make(POSE,24,8,SEED)[0].green.is_empty(),"No ledge turf")

## One sheet column's (height, outward distance) samples through x = `x`.
func _profile(sheet:Dictionary,x:float)->Array:
 var column:Dictionary={}
 for p:Vector3 in sheet.faces:
  if absf(p.x-x)<.01:column[p.y]=maxf(column.get(p.y,-INF),p.z-POSE.origin.z)
 var ys:=column.keys();ys.sort()
 return ys.map(func(y:float)->Vector2:return Vector2(y,column[y]))

func test_mossy_slope_is_one_smooth_sheet_meeting_ground_and_wall()->void:
 # Owner (slopes passes 2-4): a smooth, gently rolling slope that blends into
 # the ground and the cliff face.
 STYLE.apply("slopes")
 var form:Dictionary=CRAGS.make(POSE,24,8,SEED)[0]
 var field=FIELD.new([form],SEED)
 # The plain slope: rocks and their swells have their own test.
 field.rock_list.clear();field._rock_cells.clear()
 var sheets:Array=field.sheets(Rect2(-100,-100,300,300))
 assert_eq(sheets.size(),1,"One sheet for the wall")
 for x:float in [9.0,12.0,15.0]:
  var profile:=_profile(sheets[0],x)
  var ground:Vector2=profile.filter(func(p:Vector2)->bool:return p.x>=0.0)[0]
  var next:Vector2=profile[profile.find(ground)+1]
  assert_lt((next.x-ground.x)/(ground.y-next.y),tan(deg_to_rad(20.0)),"x=%s: nearly tangent to the ground"%x)
  for i in range(1,profile.size()):
   assert_lt(profile[i].y,profile[i-1].y+.001,"x=%s: recedes monotonically up the slope"%x)
  assert_lt(profile[-1].y,0.0,"x=%s: the lip curls back into the wall"%x)

func test_rock_never_stands_out_of_the_lower_slope()->void:
 # Formation ends inside the slope used to show as vertical blades.
 STYLE.apply("slopes")
 var form:Dictionary=CRAGS.make(POSE,24,8,SEED,null,false,false)[0]
 var field=FIELD.new([form],SEED)
 field.apply(form)
 for p:Vector3 in form.faces:
  var w:=POSE*p
  var c:Dictionary=field._enclosing(w,POSE.origin.y)
  if c.is_empty() or w.y-float(c.base)>float(c.top)-FIELD.ROCK_BAND:continue
  assert_lt(float(c.d),field.target(c,w.y-float(c.base))-.2,"Rock stays inside the slope at %s"%w)

func test_slope_tapers_only_at_free_ends()->void:
 STYLE.apply("slopes")
 var form:Dictionary=CRAGS.make(POSE,24,8,SEED,null,true,true)[0]
 var sheets:Array=FIELD.new([form],SEED).sheets(Rect2(-100,-100,300,300))
 assert_gt(_profile(sheets[0],12.0)[2].y,2.0,"The slope stands out mid-wall")
 for x:float in [0.0,24.0]:
  for sample:Vector2 in _profile(sheets[0],x):
   assert_lt(sample.y,0.0,"No slope at the free end x=%s"%x)

func test_collinear_formations_share_one_sheet()->void:
 # Each formation used to build its own slope; neighbours crossed as blades.
 STYLE.apply("slopes")
 var a:Dictionary=CRAGS.make(POSE,24,8,SEED,null,true,false)[0]
 var b:Dictionary=CRAGS.make(POSE.translated(Vector3(21,0,0)),24,4,SEED,null,false,true)[0]
 var sheets:Array=FIELD.new([a,b],SEED).sheets(Rect2(-100,-100,300,300))
 assert_eq(sheets.size(),1,"Overlapping collinear walls share one continuous sheet")

func test_neighbouring_chunks_share_sheet_edges()->void:
 STYLE.apply("slopes")
 var form:Dictionary=CRAGS.make(POSE,24,8,SEED)[0]
 var field=FIELD.new([form],SEED)
 var left:Array=field.sheets(Rect2(-100,-100,112,300))
 var right:Array=field.sheets(Rect2(12,-100,200,300))
 var a:={};var b:={}
 for p:Vector3 in left[0].faces:a[p]=true
 for p:Vector3 in right[0].faces:b[p]=true
 var shared:=a.keys().filter(func(p:Vector3)->bool:return b.has(p))
 assert_eq(shared.size(),ROWS_PER_COLUMN,"One full shared column at the chunk boundary")

const ROWS_PER_COLUMN:=FIELD.ROWS+5

func test_slope_reaches_as_far_around_an_outer_corner()->void:
 # The corner body is compressed; its slope used to be too, so the slope fell
 # short around corners. The shared slope is a cone at the full reach.
 STYLE.apply("slopes")
 var corner:={"replay_recipe":{"kind":"corner","height":8.0},"transform":POSE}
 var field=FIELD.new([corner],SEED)
 var centre:=POSE*Vector3(-1.5,0,-1.5)
 for angle:float in [.2,.785,1.3]:
  var dir:=POSE.basis*Vector3(sin(angle),0,cos(angle))
  var q:=centre+dir*3.0
  var c:Dictionary=field._enclosing(Vector3(q.x,POSE.origin.y+.5,q.z),POSE.origin.y)
  assert_false(c.is_empty(),"The corner wedge has a slope at %s rad"%angle)
  assert_true(c.arc,"It is the corner's cone")
  assert_almost_eq(float(c.reach),field.params(c.foot,8.0).y,.001,"At full reach, as along the walls")

func test_slope_tapers_where_its_foot_line_stops()->void:
 # A wall end not flagged as an end (a step to another base, a joined
 # formation) still has nothing continuing its slope; cut at full size there
 # the sheet stood out as a vertical blade.
 STYLE.apply("slopes")
 var wall:Dictionary=CRAGS.make(POSE,24,8,SEED,null,false,false)[0]
 var higher:Dictionary=CRAGS.make(POSE.translated(Vector3(24,4,0)),24,4,SEED,null,false,false)[0]
 var sheets:Array=FIELD.new([wall,higher],SEED).sheets(Rect2(-100,-100,300,300))
 var low:Array=sheets.filter(func(s:Dictionary)->bool:return s.base<POSE.origin.y)
 assert_eq(low.size(),1)
 for sample:Vector2 in _profile(low[0],24.0):
  assert_lt(sample.y,0.0,"The lower slope has tapered where its foot line stops")

## Sheet style: the slope is one implicit solid. Its surface height at a
## world point is the highest grid level still inside.
func _wall(pose:Transform3D,width:float,height:float,ends:=Vector2i(1,1))->Dictionary:
 return {"replay_recipe":{"kind":"wall","width":width,"height":height,"left_end":ends.x==1,"right_end":ends.y==1,"abut":Vector2i.ZERO},"transform":pose}

## Steepest rise between neighbouring points 0.5 m apart on a cliff side
## (about 75 degrees, the tallest drops); a sheer drop is a storey in one step.
const STEEPEST:=1.9

func _surface(field,q:Vector2)->float:
 return field.envelope().sample(q)

## Largest height change between neighbouring grid nodes over `area`
## (0.5 m apart): a ledge or an abrupt stop shows as a jump.
func _worst_step(field,area:Rect2)->Dictionary:
 var env=field.envelope()
 var worst:={"step":0.0,"at":Vector2.ZERO}
 var z:=area.position.y
 while z<area.end.y:
  var x:=area.position.x
  while x<area.end.x:
   var q:=Vector2(x,z)
   for o:Vector2 in [Vector2(.5,0),Vector2(0,.5)]:
    var step:=absf(float(env.at(q+o))-float(env.at(q)))
    if step>float(worst.step):worst={"step":step,"at":q}
   x+=.5
  z+=.5
 return worst

func test_sheet_style_is_one_slope_for_the_whole_wall()->void:
 # Owner (September 25): slopes continuous, meshing with the landscape, no
 # ledges; and they dress the cliff side only, leaving flat ground flat.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,40,8)],SEED)
 for x:float in [6.0,12.0,18.0]:
  assert_almost_eq(_surface(field,Vector2(x,POSE.origin.z-.5)),8.0,.01,"x=%s: flush with the plateau behind the lip"%x)
  assert_gt(_surface(field,Vector2(x,POSE.origin.z+.5)),8.0-.8,"x=%s: the slope leaves the lip level, with no drop"%x)
  var previous:=INF
  for i in 48:
   var h:=_surface(field,Vector2(x,POSE.origin.z+.5+i*.5))
   assert_lt(h,previous+.25,"x=%s: the slope descends away from the wall"%x)
   if previous<INF:assert_lt(previous-h,STEEPEST,"x=%s: a steep side, never a sheer drop, at %s m"%[x,.5+i*.5])
   previous=h
  assert_almost_eq(_surface(field,Vector2(x,POSE.origin.z+13.0)),0.0,.01,"x=%s: flat ground beyond the cliff side stays flat"%x)

func test_terraces_stay_flat()->void:
 # Owner (September 25): the slopes swallowed every terrace. A 24 m terrace
 # between two one-storey cliffs keeps its middle flat.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(20,0,30)),40,4),_wall(Transform3D(Basis(),Vector3(20,4,6)),40,4)],SEED)
 field.ground_at=func(q:Vector2)->float:return 8.0 if q.y<6.0 else (4.0 if q.y<30.0 else 0.0)
 field._env=null
 for x:float in [10.0,20.0,30.0]:
  for z:float in [14.0,16.0,18.0,20.0,22.0]:
   assert_almost_eq(_surface(field,Vector2(x,z)),4.0,.01,"The terrace middle stays flat at %s"%Vector2(x,z))

func test_sheet_ridges_rise_and_fall_along_the_wall()->void:
 # Owner: walking along the slope parallel to the wall goes up and down
 # over gently rolling ridges and valleys.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(40,0,30)),80,8)],SEED)
 var heights:Array[float]=[]
 for i in 120:heights.append(_surface(field,Vector2(10.0+i*.5,30.0+4.0)))
 assert_gt(heights.max()-heights.min(),1.2,"At 4 m from the wall the slope rises and falls")
 var peaks:=0
 for i in range(3,heights.size()-3):
  if heights[i]>heights[i-3] and heights[i]>=heights[i+3]:peaks+=1
 assert_gt(peaks,2,"Several ridges along 60 m")

func test_stacked_cliffs_merge_into_one_hillside()->void:
 # Owner: a cliff on top of a cliff must not leave a slope that just stops.
 STYLE.apply("sheet")
 var lower:=_wall(Transform3D(Basis(),Vector3(20,0,30)),40,4)
 var upper:=_wall(Transform3D(Basis(),Vector3(20,4,27)),40,4)
 var field=FIELD.new([lower,upper],SEED)
 for x:float in [12.0,20.0,28.0]:
  var previous:=_surface(field,Vector2(x,27.0))
  for i in range(1,50):
   var h:=_surface(field,Vector2(x,27.0+i*.5))
   assert_lt(h,previous+.25,"x=%s: one descending surface over both cliffs"%x)
   assert_lt(previous-h,STEEPEST,"x=%s: no ledge in the hillside at %s m"%[x,i*.5])
   previous=h

func test_outer_corners_wrap_at_full_size()->void:
 STYLE.apply("sheet")
 var corner:={"replay_recipe":{"kind":"corner","height":8.0},"transform":POSE}
 var field=FIELD.new([corner],SEED)
 var centre:=POSE*Vector3(-1.5,0,-1.5)
 var heights:Array[float]=[]
 for i in 13:
  var angle:=i/12.0*PI*.5
  var dir:=POSE.basis*Vector3(sin(angle),0,cos(angle))
  heights.append(_surface(field,Vector2(centre.x,centre.z)+Vector2(dir.x,dir.z)*(1.5+3.0)))
 for i in range(1,heights.size()):
  assert_lt(absf(heights[i]-heights[i-1]),.8,"The slope wraps the corner without a step")
 assert_gt(heights.min(),1.0,"It stays a full slope all the way round")

func test_inner_corners_fill_round()->void:
 STYLE.apply("sheet")
 var corner:={"replay_recipe":{"kind":"inner_corner","height":8.0},"transform":POSE}
 var field=FIELD.new([corner],SEED)
 # At the bisector the slope sits at least as high as out along an arm.
 var bisector:=POSE*(Vector3(1,0,1).normalized()*4.0)
 var arm:=POSE*Vector3(4.0/sqrt(2.0),0,6.0)
 assert_gt(_surface(field,Vector2(bisector.x,bisector.z)),_surface(field,Vector2(arm.x,arm.z))-.1,"No V: the corner is filled")

func test_solid_chunks_share_their_seam()->void:
 # Each chunk builds the envelope over its own window; values must agree.
 STYLE.apply("sheet")
 var forms:=[_wall(Transform3D(Basis(),Vector3(12,0,30)),24,8),{"replay_recipe":{"kind":"corner","height":8.0},"transform":Transform3D(Basis(),Vector3(27,0,30))}]
 var a=FIELD.new(forms,SEED,null,Rect2(-12,0,24,60))
 var b=FIELD.new(forms,SEED,null,Rect2(12,0,24,60))
 for z in range(0,120):
  var q:=Vector2(12.0,z*.5)
  assert_eq(a.envelope().at(q),b.envelope().at(q),"Same surface at the seam %s"%q)
 var left:Array=a.solid(Rect2(-12,0,24,60));var right:Array=b.solid(Rect2(12,0,24,60))
 var ka:={};var kb:={}
 for p:Vector3 in left[0].faces:if absf(p.x-12.0)<.3:ka[p]=true
 for p:Vector3 in right[0].faces:if absf(p.x-12.0)<.3:kb[p]=true
 var shared:=ka.keys().filter(func(p:Vector3)->bool:return kb.has(p))
 assert_gt(shared.size(),10,"Both chunks emit the same seam vertices")

func test_rocks_come_in_small_spaced_clusters()->void:
 # Owner (September 25): giant clusters with long bare stretches and bare
 # corners; wanted clusters of two or three, spaced out a bit.
 STYLE.apply("sheet")
 var corner:={"replay_recipe":{"kind":"corner","height":8.0},"transform":Transform3D(Basis(),Vector3(-38.5,0,31.5))}
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(0,0,30)),80,8),corner],SEED)
 var bunches:Dictionary={}
 for rock:Dictionary in field.rock_list:bunches[rock.bunch]=bunches.get(rock.bunch,[])+[rock]
 assert_gt(bunches.size(),6,"An 80 m wall holds many clusters")
 var along:Array[float]=[]
 for bunch:Vector2 in bunches:
  assert_between((bunches[bunch] as Array).size(),2,3,"Clusters of two or three")
  for rock:Dictionary in bunches[bunch]:
   assert_lt((rock.foot as Vector2).distance_to(bunch),8.0,"Kept together")
  along.append(bunch.x)
 along.sort()
 for i in range(1,along.size()):
  assert_lt(along[i]-along[i-1],21.0,"No long bare stretch between %.0f and %.0f"%[along[i-1],along[i]])
 var near_corner:Array=field.rock_list.filter(func(r:Dictionary)->bool:return (r.foot as Vector2).distance_to(Vector2(-40,30))<8.0)
 assert_gt(near_corner.size(),0,"The corner carries rocks too")
 for rock:Dictionary in field.rock_list:
  var bounds:Vector3=preload("res://scripts/terrain/field/CliffSlopeRocks.gd").PIECES[rock.piece][1]
  var extents:=bounds*(rock.transform as Transform3D).basis.get_scale()
  var size:=maxf(extents.x,maxf(extents.y,extents.z))
  assert_lt(size,8.6 if rock.kind=="face" else 6.5,"Bounded larger face (%.1f m)"%size)

func test_upper_outer_corner_flows_into_lower_inner_corner()->void:
 # Owner (X in review photo): an outer corner one storey up, directly above
 # an inner corner below, must be one continuous slope down both storeys.
 STYLE.apply("sheet")
 var upper:={"replay_recipe":{"kind":"corner","height":4.0},"transform":Transform3D(Basis(),Vector3(-3,4,-3))}
 var lower:={"replay_recipe":{"kind":"inner_corner","height":4.0},"transform":Transform3D(Basis(),Vector3(0,0,0))}
 var field=FIELD.new([upper,lower],SEED)
 field.ground_at=func(q:Vector2)->float:
  if q.x<-3.0 and q.y<-3.0:return 8.0
  return 0.0 if q.x>0.0 and q.y>0.0 else 4.0
 var dir:=Vector2(1,1).normalized()
 var start:=Vector2(-4.5,-4.5)
 var previous:=_surface(field,start)
 for i in range(1,48):
  var q:=start+dir*(i*.5)
  var h:=_surface(field,q)
  assert_lt(h,previous+.25,"No bump at %s"%q)
  assert_lt(previous-h,STEEPEST,"No abrupt drop at %s"%q)
  previous=h
 assert_lt(previous,.5,"It reaches the bottom ground")

func test_no_ledges_anywhere()->void:
 # Owner (September 25): slopes ended abruptly and dropped straight down,
 # both outward and along the wall. The surface is the terrain's own
 # envelope, so every cliff is covered wherever it runs: stacked storeys
 # with a narrow terrace, an L-shaped plateau (inner corner), a wall that
 # steps from 8 m to 4 m and a 12 m cliff. Every neighbouring pair of points
 # differs by less than a steep slope's rise.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,40,8)],SEED)
 field.ground_at=func(q:Vector2)->float:
  var h:=0.0
  if q.y<20.0 and q.x<24.0:h=8.0
  if q.y<20.0 and q.x>=24.0 and q.x<48.0:h=4.0
  if q.y<14.0 and q.x<24.0:h=12.0
  if q.y<40.0 and q.x<-12.0:h=maxf(h,8.0)
  if q.y<0.0 and q.x>=48.0:h=12.0
  return h
 field._env=null
 var worst:Dictionary=_worst_step(field,Rect2(-40,-20,120,90))
 assert_lt(float(worst.step),STEEPEST+.1,"No ledge: largest step %.2f m at %s"%[worst.step,worst.at])

func test_slope_cuts_back_cleanly_at_a_road()->void:
 # A road at the cliff foot stays flat; the slope rises from its edge in a
 # steep cut, not a wall.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,40,8)],SEED)
 field.excluded_at=func(q:Vector2)->bool:return q.y>POSE.origin.z+4.0 and q.y<POSE.origin.z+8.0
 field._env=null
 for x:float in [6.0,12.0,18.0]:
  assert_almost_eq(_surface(field,Vector2(x,POSE.origin.z+6.0)),0.0,.01,"The road stays at its own ground")
  var previous:=_surface(field,Vector2(x,POSE.origin.z))
  for i in range(1,40):
   var h:=_surface(field,Vector2(x,POSE.origin.z+i*.5))
   assert_lt(absf(previous-h),STEEPEST+.1,"x=%s: a cut, not a wall, at %s m"%[x,i*.5])
   previous=h

func test_covered_native_pieces_are_hidden()->void:
 # Owner: little grey triangles — the native wall poking through the slope.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,40,8)],SEED)
 var wall:=Transform3D(Basis(),Vector3(12,4,POSE.origin.z-1.5))
 var lip:=Transform3D(Basis(),Vector3(12,8,POSE.origin.z-1.5))
 var kept:Dictionary=field.envelope().uncovered({"wall":[wall],"lip":[lip]})
 assert_eq((kept.wall as Array).size(),0,"A wall row under the slope is hidden")
 assert_eq((kept.lip as Array).size(),0,"The lip under the slope is hidden")
 var cut=FIELD.new([_wall(POSE,40,8)],SEED)
 cut.excluded_at=func(q:Vector2)->bool:return q.y>POSE.origin.z+.5
 cut._env=null
 kept=cut.envelope().uncovered({"wall":[wall],"lip":[lip]})
 assert_eq((kept.wall as Array).size(),1,"Where a road cuts the slope back, the native wall stays")

func test_solid_has_no_visible_holes()->void:
 # A short column beside a tall one left the tall one's side faces open:
 # the native wall showed through in vertical bars.
 STYLE.apply("sheet")
 var upper:={"replay_recipe":{"kind":"corner","height":4.0},"transform":Transform3D(Basis(),Vector3(-3,4,-3))}
 var lower:={"replay_recipe":{"kind":"inner_corner","height":4.0},"transform":Transform3D(Basis(),Vector3(0,0,0))}
 var wall:=_wall(Transform3D(Basis(),Vector3(-15,4,-3)),18,4)
 var field=FIELD.new([upper,lower,wall],SEED)
 field.ground_at=func(q:Vector2)->float:
  if q.x<-3.0 and q.y<-3.0:return 8.0
  return 0.0 if q.x>0.0 and q.y>0.0 else 4.0
 var owned:=Rect2(-24,-24,48,48)
 var faces:PackedVector3Array=field.solid(owned)[0].faces
 var count:Dictionary={}
 for i in range(0,faces.size(),3):
  for k in 3:
   var a:=faces[i+k];var b:=faces[i+(k+1)%3]
   var key:=[a,b] if a<b else [b,a]
   count[key]=count.get(key,0)+1
 var open:=0
 for e:Array in count:
  if count[e]!=1:continue
  var m:Vector3=(e[0]+e[1])*.5
  # A rock swell's pinched tip can leave a millimetre sliver; bars are metres.
  if (e[0] as Vector3).distance_to(e[1])<.02:continue
  if owned.grow(-1.0).has_point(Vector2(m.x,m.z)) and m.y>field.ground(Vector2(m.x,m.z))+.1:open+=1
 assert_eq(open,0,"No open edges above ground inside the chunk")

func test_sheet_builds_outlines_with_the_same_slope()->void:
 # The sheet slope reads only a formation's recipe and pose; building the
 # crag meshes it discards was most of a chunk's cost (in-game teleports froze).
 STYLE.apply("sheet")
 var poses:=[Transform3D(Basis(),Vector3(0,0,0)),Transform3D(Basis(Vector3.UP,PI*.5),Vector3(20,4,0))]
 var slopes:Array=[]
 for full:bool in [true,false]:
  STYLE.sheet_only=not full
  var forms:Array=[]
  for pose:Transform3D in poses:forms.append_array(CRAGS.make(pose,12,8,SEED,null,true,true))
  forms.append(CORNERS.make(Transform3D(Basis(),Vector3(-9,0,-9)),8,SEED))
  forms.append(CORNERS.make_inner(Transform3D(Basis(),Vector3(9,0,-9)),8,SEED))
  if not full:
   for f:Dictionary in forms:assert_true(f.get("outline",false),"sheet formations are outlines")
  STYLE.sheet_only=true
  slopes.append(FIELD.new(forms,SEED))
 assert_eq(str(slopes[1]._primitives),str(slopes[0]._primitives),"same foot lines")
 var owned:=Rect2(-24,-24,60,48)
 assert_eq(hash(slopes[1].solid(owned)[0].faces),hash(slopes[0].solid(owned)[0].faces),"same slope solid")

func test_basal_rocks_are_embedded_with_their_tops_showing()->void:
 # Owner (September 25): rock undersides showed, with air beneath them.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,80,8),{"replay_recipe":{"kind":"corner","height":8.0},"transform":Transform3D(Basis(),Vector3(-28.5,0,31.5))}],SEED)
 var env=field.envelope()
 assert_gt(field.rock_list.size(),10,"The wall still carries rocks")
 for rock:Dictionary in field.rock_list:
  if rock.kind!="basal":continue
  var t:Transform3D=rock.transform
  var bounds:Vector3=preload("res://scripts/terrain/field/CliffSlopeRocks.gd").PIECES[rock.piece][1]
  for i in 12:
   var a:=i*TAU/12.0
   var corner:=t*Vector3(cos(a)*bounds.x*.5,-bounds.y*.5,sin(a)*bounds.z*.5)
   assert_lt(corner.y,float(env.sample(Vector2(corner.x,corner.z)))-.2,"%s: base under the surface"%rock.piece)
  var top:=(t*Vector3(0,bounds.y*.5,0)).y
  assert_gt(top,float(env.sample(Vector2(t.origin.x,t.origin.z))),"%s: its top shows"%rock.piece)

func test_one_storey_cliff_sides_are_walkable()->void:
 # Owner (September 25): the character got stuck on moderate slopes. It
 # walks up to 55 degrees; a one-storey cliff side stays under that
 # everywhere, ridges and bumps included.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(40,0,30)),80,4)],SEED)
 var limit:=tan(deg_to_rad(54.5))*.5
 var worst:Dictionary=_worst_step(field,Rect2(8,20,64,24))
 assert_lt(float(worst.step),limit,"Steepest 0.5 m rise %.2f m at %s"%[worst.step,worst.at])
 var character=preload("res://characters/character.gd").new()
 assert_almost_eq(float(character.MAX_WALK_SLOPE_DEGREES),55.0,.001,"The character walks up 55 degree ground")
 character.free()

func _reach(field,from:Vector2,dir:Vector2)->float:
 var env=field.envelope()
 var d:=.5
 while d<40.0:
  var q:=from+dir*d
  if float(env.at(q))-float(env.ground_node(q))<.15:return d
  d+=.25
 return 40.0

func test_outer_corners_reach_about_as_far_as_their_edges()->void:
 # Owner (September 25): the slope at outer corners went out much further
 # than along the edges. Diagonal cells may drop two storeys more than an
 # edge's: here the edges fall 4 m to a terrace, the diagonal 16 m.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,40,4)],SEED)
 field.ground_at=func(q:Vector2)->float:
  if q.x<0.0 and q.y<0.0:return 16.0
  if q.x<0.0 or q.y<0.0:return 12.0
  return 0.0
 field._env=null
 var edge:=_reach(field,Vector2(0,-30),Vector2(1,0))
 var terrace:=_reach(field,Vector2(-30,0),Vector2(0,1))
 var corner:=_reach(field,Vector2(0,0),Vector2(1,1).normalized())
 gut.p("reach: corner %.1f m, upper edge %.1f m, terrace edge %.1f m"%[corner,edge,terrace])
 # Where two walls meet in the lower ground below, the slope fills the
 # inner corner to about 1.4 times a wall's reach along the diagonal.
 # Broader rolling shoulders may move the sampled foot by one 0.5 m cell.
 assert_lt(corner,maxf(edge,terrace)*1.6+FIELD.GRID,"Corner reach %.1f m against edges %.1f / %.1f m"%[corner,edge,terrace])

func test_midface_rocks_follow_slope_and_bury_both_ends()->void:
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,80,8)],SEED)
 var env=field.envelope()
 var count:=0
 for rock:Dictionary in field.rock_list:
  if rock.kind!="face":continue
  count+=1
  var t:Transform3D=rock.transform
  var bounds:Vector3=preload("res://scripts/terrain/field/CliffSlopeRocks.gd").PIECES[rock.piece][1]
  assert_lt(absf(t.basis.y.normalized().dot(rock.normal)),.08,"Long axis follows slope")
  assert_between(float(rock.point.y),2.8,5.8,"Midway up the eight metre wall")
  for end:float in [-1.0,1.0]:
   var p:=t*Vector3(0,end*bounds.y*.5,-bounds.z)
   assert_lt(p.y,float(env.sample(Vector2(p.x,p.z)))-.15,"Both ends buried")
 assert_gt(count,8,"Visible cliff clusters remain")

func test_rejected_kaykit_rocks_are_catalog_only()->void:
 var catalog:=EnvironmentCatalog.load_default()
 for id:StringName in catalog.ids():
  if String(id).begins_with("kaykit.rock."):
   assert_has(catalog.descriptor(id).tags,&"catalog_only","No ambient KayKit rocks")

 var program:=DressingCompiler.compile(load("res://terrain/dressing/index.tres"),catalog)
 assert_not_null(program)
 if program!=null:
  for set_data:Dictionary in program.sets:
   for choice:Dictionary in set_data.choices:
    assert_false(String(choice.asset_id).begins_with("kaykit.rock."),"Retired from every biome and habitat")


func test_native_outcrop_caps_are_inside_the_slope()->void:
 STYLE.apply("sheet")
 var rocks=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
 rocks.prepare()
 var checked:=0;var exposed:=0
 for height:float in [4.0,8.0,16.0]:
  var field=FIELD.new([_wall(POSE,80,height),{"replay_recipe":{"kind":"corner","height":height},"transform":Transform3D(Basis(),Vector3(-28.5,0,31.5))}],SEED)
  for rock:Dictionary in field.rock_list:
   if rock.kind!="face":continue
   var piece:Array=rocks._pieces[rock.piece]
   var bounds:Vector3=rocks.PIECES[rock.piece][1]
   for vertex:Vector3 in piece[0].get_faces():
    var local:Vector3=piece[1]*vertex
    if absf(local.y)<bounds.y*.42:continue
    checked+=1
    var p:Vector3=rock.transform*local
    if p.y>field.envelope().sample(Vector2(p.x,p.z)):exposed+=1
 assert_gt(checked,1000,"Check actual source-mesh end faces")
 assert_eq(exposed,0,"No exposed upper or lower rock caps")
