extends GutTest
## Whole-wall slope sheet (owner reviews September 23-27), on synthetic foot
## lines. The procedural crag, terrace and native-piece tests of this review
## were retired with those styles (dual-grid terrain tiles, September 30); the
## sheet's foot lines are wall segments (TerrainTileField.wall_segments form).
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const SEED:=2697992464
const POSE:=Transform3D(Basis.IDENTITY,Vector3(12,0,30))

func after_each()->void:STYLE.apply("sheet_bedrock")

## A straight wall along x centred on the pose origin, `width` long, its
## plateau behind it (z below the origin), `height` above the origin's ground.
func _wall(pose:Transform3D,width:float,height:float)->Dictionary:
 var o:=pose.origin
 return FIELD.straight_wall(Vector2(o.x-width*.5,o.z),Vector2(o.x+width*.5,o.z),Vector2(0,1),o.y+height,o.y)

## An outer (convex) corner at the pose origin: the plateau lies at lower x and
## z; walls facing +z and +x meet at the corner.
func _corner(pose:Transform3D,height:float)->Array:
 var o:=pose.origin
 return [FIELD.straight_wall(Vector2(o.x-12,o.z),Vector2(o.x,o.z),Vector2(0,1),o.y+height,o.y),
  FIELD.straight_wall(Vector2(o.x,o.z-12),Vector2(o.x,o.z),Vector2(1,0),o.y+height,o.y)]

## An inner (concave) corner at the pose origin: the low ground lies at higher
## x and z, walled on both arms.
func _inner_corner(pose:Transform3D,height:float)->Array:
 var o:=pose.origin
 return [FIELD.straight_wall(Vector2(o.x,o.z),Vector2(o.x+6,o.z),Vector2(0,1),o.y+height,o.y),
  FIELD.straight_wall(Vector2(o.x,o.z),Vector2(o.x,o.z+6),Vector2(1,0),o.y+height,o.y)]

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
 var field=FIELD.new(_corner(POSE,8.0),SEED)
 var centre:=Vector2(POSE.origin.x,POSE.origin.z)
 var heights:Array[float]=[]
 for i in 13:
  var angle:=i/12.0*PI*.5
  heights.append(_surface(field,centre+Vector2(sin(angle),cos(angle))*3.0))
 for i in range(1,heights.size()):
  assert_lt(absf(heights[i]-heights[i-1]),.8,"The slope wraps the corner without a step")
 assert_gt(heights.min(),1.0,"It stays a full slope all the way round")

func test_inner_corners_fill_round()->void:
 STYLE.apply("sheet")
 var field=FIELD.new(_inner_corner(POSE,8.0),SEED)
 # At the bisector the slope sits at least as high as out along an arm.
 var bisector:=POSE*(Vector3(1,0,1).normalized()*4.0)
 var arm:=POSE*Vector3(4.0/sqrt(2.0),0,6.0)
 assert_gt(_surface(field,Vector2(bisector.x,bisector.z)),_surface(field,Vector2(arm.x,arm.z))-.1,"No V: the corner is filled")

func test_solid_chunks_share_their_seam()->void:
 # Each chunk builds the envelope over its own window; values must agree.
 STYLE.apply("sheet")
 var forms:=[_wall(Transform3D(Basis(),Vector3(12,0,30)),24,8)]+_corner(Transform3D(Basis(),Vector3(24,0,30)),8.0)
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
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(0,0,30)),80,8)]+_corner(Transform3D(Basis(),Vector3(40,0,30)),8.0),SEED)
 var bunches:Dictionary={}
 for rock:Dictionary in field.rock_list:bunches[rock.bunch]=bunches.get(rock.bunch,[])+[rock]
 # Owner (September 27) superseded the no-bare-stretch rule: clusters are
 # colonial (CliffSlopeField.colony01), with genuinely empty foot between.
 # September 27 judging: fewer, fuller clusters of up to four nestled rocks.
 assert_gt(bunches.size(),1,"An 80 m wall holds clusters")
 for bunch:Vector2 in bunches:
  assert_between((bunches[bunch] as Array).size(),2,4,"Clusters of two to four")
  for rock:Dictionary in bunches[bunch]:
   assert_lt((rock.foot as Vector2).distance_to(bunch),8.0,"Kept together")
 for rock:Dictionary in field.rock_list:
  var bounds:Vector3=preload("res://scripts/terrain/field/CliffSlopeRocks.gd").PIECES[rock.piece][1]
  var extents:=bounds*(rock.transform as Transform3D).basis.get_scale()
  var size:=maxf(extents.x,maxf(extents.y,extents.z))
  assert_lt(size,8.6 if rock.kind=="face" else 6.5,"Bounded larger face (%.1f m)"%size)

func test_upper_outer_corner_flows_into_lower_inner_corner()->void:
 # Owner (X in review photo): an outer corner one storey up, directly above
 # an inner corner below, must be one continuous slope down both storeys.
 STYLE.apply("sheet")
 var field=FIELD.new(_corner(Transform3D(Basis(),Vector3(-3,4,-3)),4.0)+_inner_corner(Transform3D.IDENTITY,4.0),SEED)
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

func test_solid_has_no_visible_holes()->void:
 # A short column beside a tall one left the tall one's side faces open:
 # the native wall showed through in vertical bars.
 STYLE.apply("sheet")
 var wall:=_wall(Transform3D(Basis(),Vector3(-15,4,-3)),18,4)
 var field=FIELD.new(_corner(Transform3D(Basis(),Vector3(-3,4,-3)),4.0)+_inner_corner(Transform3D.IDENTITY,4.0)+[wall],SEED)
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

func test_basal_rocks_are_embedded_with_their_tops_showing()->void:
 # Owner (September 25): rock undersides showed, with air beneath them.
 STYLE.apply("sheet")
 var field=FIELD.new([_wall(POSE,80,8)]+_corner(Transform3D(Basis(),Vector3(52,0,30)),8.0),SEED)
 var env=field.envelope()
 # September 27: colonies leave bare stretches; fewer rocks per wall.
 assert_gt(field.rock_list.size(),3,"The wall still carries rocks")
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
 assert_gt(count,1,"Visible cliff clusters remain")

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
  var field=FIELD.new([_wall(POSE,80,height)]+_corner(Transform3D(Basis(),Vector3(52,0,30)),height),SEED)
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
