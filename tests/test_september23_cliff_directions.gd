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

func _surface(field,q:Vector2,ground:=0.0)->float:
 var contribs:Array=field._contributions(q)
 for j in range(ceili(40.0/FIELD.GRID),floori(-4.0/FIELD.GRID),-1):
  if field._inside(contribs,[],q,j)>0.0:return maxf(ground,j*FIELD.GRID)
 # Beyond the slope: the ground itself.
 return ground

func test_sheet_style_is_one_slope_for_the_whole_wall()->void:
 # Owner (September 24): not a skirt below the bumpy wall; one continuous
 # slope, vertical toward the top of the cliff and horizontal at the bottom.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,40,8)],SEED)
 field.rock_list.clear()
 for x:float in [6.0,12.0,18.0]:
  var previous:=INF
  for i in 24:
   var h:=_surface(field,Vector2(x,POSE.origin.z+.25+i*.5))
   assert_lt(h,previous+.01,"x=%s: the slope descends away from the wall"%x)
   previous=h
  assert_gt(_surface(field,Vector2(x,POSE.origin.z+.5)),8.0-1.0,"x=%s: reaches up under the lip"%x)
  assert_lt(_surface(field,Vector2(x,POSE.origin.z+12.0)),.3,"x=%s: meets the ground"%x)

func test_sheet_ridges_rise_and_fall_along_the_wall()->void:
 # Owner: walking along the slope parallel to the wall should go up and down
 # over gently rolling ridges and valleys, not hold one height.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(40,0,30)),80,8)],SEED)
 field.rock_list.clear()
 var heights:Array[float]=[]
 for i in 120:heights.append(_surface(field,Vector2(10.0+i*.5,30.0+3.5)))
 assert_gt(heights.max()-heights.min(),1.0,"At 3.5 m from the wall the slope rises and falls by over a metre")
 # Across the upper face too (owner sketch): at 2 m out, near the top half.
 var upper:Array[float]=[]
 for i in 120:upper.append(_surface(field,Vector2(10.0+i*.5,30.0+2.0)))
 assert_gt(upper.max()-upper.min(),1.5,"The whole face rolls, not just the foot")
 var peaks:=0
 for i in range(2,heights.size()-2):
  if heights[i]>heights[i-2] and heights[i]>=heights[i+2]:peaks+=1
 assert_gt(peaks,2,"Several ridges along 60 m")

func test_stacked_cliffs_merge_into_one_hillside()->void:
 # Owner: a cliff on top of a cliff must not leave a slope that just stops.
 STYLE.apply("sheet")
 var lower:=_wall(Transform3D(Basis(),Vector3(20,0,30)),40,4)
 var upper:=_wall(Transform3D(Basis(),Vector3(20,4,27)),40,4)
 var field=FIELD.new([lower,upper],SEED)
 field.rock_list.clear()
 for x:float in [12.0,20.0,28.0]:
  # From 1.5 m out: directly under the upper lip the slope is near vertical
  # by design.
  var previous:=_surface(field,Vector2(x,27.0+1.5))
  for i in range(4,40):
   var h:=_surface(field,Vector2(x,27.0+i*.5))
   # Gentle bumps and divots (owner) may rise a little; no step or gap.
   assert_lt(h,previous+.6,"x=%s: one descending surface over both cliffs"%x)
   assert_lt(previous-h,1.6,"x=%s: no cliff-like drop in the hillside at %s m"%[x,i*.5])
   previous=h

func test_outer_corners_wrap_at_full_size()->void:
 STYLE.apply("sheet")
 var corner:={"replay_recipe":{"kind":"corner","height":8.0},"transform":POSE}
 var field=FIELD.new([corner],SEED)
 field.rock_list.clear()
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
 field.rock_list.clear()
 # At the bisector the union of the two slopes plus the round sits at least
 # as high as either slope alone would there.
 var bisector:=POSE*(Vector3(1,0,1).normalized()*4.0)
 var arm:=POSE*Vector3(4.0/sqrt(2.0),0,6.0)
 assert_gt(_surface(field,Vector2(bisector.x,bisector.z)),_surface(field,Vector2(arm.x,arm.z))-.1,"No V: the corner is filled")

func test_solid_chunks_share_their_seam()->void:
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(12,0,30)),24,8)],SEED)
 var left:Array=field.solid(Rect2(-12,0,24,60));var right:Array=field.solid(Rect2(12,0,24,60))
 var a:={};var b:={}
 for p:Vector3 in left[0].faces:if absf(p.x-12.0)<.3:a[p]=true
 for p:Vector3 in right[0].faces:if absf(p.x-12.0)<.3:b[p]=true
 var shared:=a.keys().filter(func(p:Vector3)->bool:return b.has(p))
 assert_gt(shared.size(),10,"Both chunks emit the same seam vertices")

func test_rocks_bunch_into_outcrops()->void:
 # Owner: rocks too small and spread out; bunches creating rocky outcrops.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,80,8)],SEED)
 var bunches:Dictionary={};var face:=0
 for rock:Dictionary in field.rock_list:
  if rock.kind=="outcrop":bunches[rock.bunch]=bunches.get(rock.bunch,[])+[rock]
  else:
   face+=1
   assert_gt(float(rock.y),8.0*.1,"Face rocks stand out of the side, above the foot")
 # Owner: the side should be very rocky.
 assert_gt(face,12,"An 80 m wall carries many face rocks")
 assert_gt(bunches.size(),2,"An 80 m wall holds several outcrops")
 for bunch:Vector2 in bunches:
  var rocks:Array=bunches[bunch]
  assert_gte(rocks.size(),5,"Each outcrop packs several rocks")
  for rock:Dictionary in rocks:
   assert_lt((rock.foot as Vector2).distance_to(bunch),6.0,"Packed together, not spread out")

func test_upper_outer_corner_flows_into_lower_inner_corner()->void:
 # Owner (X in review photo): an outer corner one storey up, directly above
 # an inner corner below, must be one continuous slope down both storeys.
 STYLE.apply("sheet")
 var upper:={"replay_recipe":{"kind":"corner","height":4.0},"transform":Transform3D(Basis(),Vector3(-3,4,-3))}
 var lower:={"replay_recipe":{"kind":"inner_corner","height":4.0},"transform":Transform3D(Basis(),Vector3(0,0,0))}
 var field=FIELD.new([upper,lower],SEED)
 field.rock_list.clear()
 field.ground_at=func(q:Vector2)->float:
  if q.x<-3.0 and q.y<-3.0:return 8.0
  return 0.0 if q.x>0.0 and q.y>0.0 else 4.0
 # Down the diagonal from the upper lip, across the narrow terrace and the
 # lower inner corner: always descending, never a cliff-like drop.
 var dir:=Vector2(1,1).normalized()
 var start:=Vector2(-4.5,-4.5)+dir*2.0
 var previous:=_surface(field,start,field.ground(start))
 for i in range(1,36):
  var q:=start+dir*(i*.5)
  var h:=_surface(field,q,field.ground(q))
  # A gentle fillet may round over the lower lip; never a drop or a gap.
  assert_lt(h,previous+.6,"No bump at %s"%q)
  assert_lt(previous-h,1.6,"No abrupt drop at %s"%q)
  previous=h
 assert_lt(previous,1.0,"It reaches the bottom ground")

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
  if owned.grow(-1.0).has_point(Vector2(m.x,m.z)) and m.y>field.ground(Vector2(m.x,m.z))+.1:open+=1
 assert_eq(open,0,"No open edges above ground inside the chunk")

func test_plateau_cell_past_the_wall_does_not_flatten_the_top()->void:
 # The native terrain cell under a plateau reaches ~1.5 m past its wall
 # line. Unioned as ground it held the slope top flat, then dropped it
 # vertically at the cell edge (owner: "straight down, then a sharp turn").
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(20,0,30)),40,8)],SEED)
 field.rock_list.clear()
 field.ground_at=func(q:Vector2)->float:return 8.0 if q.y<31.5 else 0.0
 var previous:=_surface(field,Vector2(20,30.75),0.0)
 for i in range(1,12):
  var h:=_surface(field,Vector2(20,30.75+i*.5),0.0)
  assert_lt(previous-h,1.6,"No vertical drop at %s m out"%(.75+i*.5))
  previous=h
