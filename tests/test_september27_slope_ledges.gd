extends GutTest
## Owner review, September 27 (seed 2697992464): rock ledges lifted into a
## lip as they ran out from the slope, rock bands were jagged, a one-storey
## bank carried cliff ridges, and a country road ended in a box trench (its
## town-grade root fix: test_september27_road_grade.gd).
## See docs/qa/2026-09-27-slope-ledges/result.md.
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED:=2697992464
func after_each()->void:STYLE.apply("sheet_bedrock")

func _p03(style:String):
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 STYLE.apply(style)
 return ENV.build(Rect2(476,924,92,96),func(q:Vector2)->float:return d.ground[index.call(q)],
  func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0,SEED,func(q:Vector2)->float:return d.wet[index.call(q)])

## A straight cliff `height` tall whose face runs at `angle` to the grid.
func _wall(style:String,angle:float,height:float)->Array:
 var n:=Vector2(cos(angle),sin(angle))
 STYLE.apply(style)
 return [ENV.build(Rect2(-40,-40,80,80),func(q:Vector2)->float:return height if q.dot(n)<0.0 else 0.0,Callable(),SEED),n]

## Rock samples with their backing's fall direction, where the rock differs
## from the uncarved hillside.
func _rock_samples(smooth,rock,lo:Vector2i,hi:Vector2i)->Array:
 var out:=[]
 for x in range(lo.x,hi.x):
  for z in range(lo.y,hi.y):
   var q:=Vector2(x,z)*.5
   var g:=Vector2(smooth.at(q+Vector2(.5,0))-smooth.at(q-Vector2(.5,0)),smooth.at(q+Vector2(0,.5))-smooth.at(q-Vector2(0,.5)))
   if g.length()>.2 and absf(rock.at(q)-smooth.at(q))>.05:out.append([q,-g.normalized()])
 return out

func test_rock_treads_never_rise_as_they_run_out_from_the_hill()->void:
 # Owner A: the ledge's outer edge rose into a raised rock lip. Walking
 # out along the backing's fall line, the rock may stay level or fall.
 var smooth=_p03("sheet");var rock=_p03("sheet_bedrock")
 var worst:=0.0;var at:=Vector2.ZERO;var tested:=0
 for s:Array in _rock_samples(smooth,rock,Vector2i(960,1856),Vector2i(1113,2017)):
  var q:Vector2=s[0];var rise:float=rock.sample(q+s[1])-rock.sample(q)
  tested+=1
  if rise>worst:worst=rise;at=q
 assert_gt(tested,1000,"Exercise the native rock patches")
 assert_lt(worst,.1,"No tread rises outward over a metre (worst %.2f m at %s)"%[worst,at])
 for angle:float in [0.0,.52]:
  var wall:Array=_wall("sheet",angle,20.0);var carved:Array=_wall("sheet_bedrock",angle,20.0)
  worst=0.0
  for s:Array in _rock_samples(wall[0],carved[0],Vector2i(-60,-60),Vector2i(61,61)):
   worst=maxf(worst,float(carved[0].sample(s[0]+s[1]))-float(carved[0].sample(s[0])))
  assert_lt(worst,.3,"A straight 20 m wall at %.2f rad has no outward-rising tread"%angle)

func test_rock_bands_run_cleanly_along_the_contour()->void:
 # Owner B: jagged ledges, sawtooth facets. Along the contour a bench is
 # level; half-metre zigzags there are grid aliasing and phase fins.
 var smooth=_p03("sheet");var rock=_p03("sheet_bedrock")
 var rough:=0
 for s:Array in _rock_samples(smooth,rock,Vector2i(960,1856),Vector2i(1113,2017)):
  var t:=Vector2(-s[1].y,s[1].x);var q:Vector2=s[0]
  if absf(rock.sample(q+t*.5)-2.0*rock.sample(q)+rock.sample(q-t*.5))>.5:rough+=1
 assert_lt(rough,120,"Native rock bands have few half-metre sawtooth kinks (%d)"%rough)
 for angle:float in [.52,.785]:
  var wall:Array=_wall("sheet",angle,20.0);var carved:Array=_wall("sheet_bedrock",angle,20.0)
  var t:=Vector2(-wall[1].y,wall[1].x);rough=0
  for s:Array in _rock_samples(wall[0],carved[0],Vector2i(-60,-60),Vector2i(61,61)):
   var q:Vector2=s[0]
   if absf(float(carved[0].sample(q+t*.5))-2.0*float(carved[0].sample(q))+float(carved[0].sample(q-t*.5)))>.5:rough+=1
  assert_lt(rough,120,"A diagonal wall's benches do not alias into facets (%d at %.2f rad)"%[rough,angle])

func _step(height:float):
 STYLE.apply("sheet_bedrock")
 return ENV.build(Rect2(-40,-16,80,32),func(q:Vector2)->float:return height if q.y<0.0 else 0.0,Callable(),SEED)

func test_a_single_storey_drop_is_one_uniform_slope()->void:
 # Owner C: a one-storey (4 m) step is an ordinary hillside. No ridges,
 # valleys, bumps or bedrock: every cross-section along it is identical.
 var env=_step(4.0)
 var spread:=0.0;var rock:=0.0
 for z in range(-24,25):
  var lo:=INF;var hi:=-INF
  for x in range(-60,61):
   var q:=Vector2(x,z)*.5
   lo=minf(lo,env.at(q));hi=maxf(hi,env.at(q));rock=maxf(rock,env.rock_at(q))
  spread=maxf(spread,hi-lo)
 assert_lt(spread,.01,"The one-storey slope has no ridge or valley along it")
 assert_eq(rock,0.0,"A one-storey slope exposes no bedrock")
 assert_gt(env.at(Vector2(0,2)),.5,"It is still a rounded slope, not the bare step")

func test_tall_cliffs_keep_their_ridges_and_rock()->void:
 var env=_step(12.0)
 var spread:=0.0;var rock:=0.0
 for z in range(0,17):
  var lo:=INF;var hi:=-INF
  for x in range(-60,61):
   var q:=Vector2(x,z)*.5
   lo=minf(lo,env.at(q));hi=maxf(hi,env.at(q));rock=maxf(rock,env.rock_at(q))
  spread=maxf(spread,hi-lo)
 assert_gt(spread,.5,"A three-storey cliff still rolls in ridges and valleys")
 assert_gt(rock,.5,"and exposes bedrock")

func test_variation_fades_in_with_relief_without_a_seam()->void:
 # A wall growing from one to three storeys along its length: the blend
 # from the plain slope to the varied cliff opens no step. (Bedrock blocks
 # beside each other are deliberately offset; this measures the slope.)
 STYLE.apply("sheet")
 var ground:=func(q:Vector2)->float:return 0.0 if q.y>=0.0 else 3.0+10.0*clampf((q.x+40.0)/80.0,0.0,1.0)
 var env=ENV.build(Rect2(-40,-16,80,32),ground,Callable(),SEED)
 var seam:=0.0
 for z in range(1,17):
  for x in range(-70,70):
   seam=maxf(seam,absf(env.at(Vector2(x,z)*.5)-env.at(Vector2(x+1,z)*.5)))
 assert_lt(seam,.5,"No half-metre seam along the slope where the variation fades in")

func _crossing(kind:int,excluded:Callable=Callable(),style:="sheet_bedrock"):
 STYLE.apply(style)
 if not excluded.is_valid():excluded=func(q:Vector2)->int:return kind if absf(q.x)<2.0 else 0
 return ENV.build(Rect2(-24,-24,48,48),func(q:Vector2)->float:return 32.0 if q.y<0.0 else 24.0,excluded,SEED)

## The owner's dead-end road (D) is fixed where it arose: the town grade no
## longer opens a cliff across an accepted road (test_september27_road_grade).
## Kept-clear ground, roads included, keeps its own grade next to a slope.
func test_village_ground_and_roads_beside_a_cliff_are_still_cut_clear()->void:
 var graded=_crossing(1)
 assert_eq(graded.sample(Vector2(0,1)),24.0,"Graded/village ground crossing a step keeps its own grade")
 var beside=_crossing(1,func(q:Vector2)->int:return 1 if q.y>6.0 and q.y<10.0 else 0)
 assert_eq(beside.sample(Vector2(0,8)),24.0,"A road along the foot is not buried by the slope")

func test_a_one_storey_river_bank_is_a_plain_slope_not_a_cliff()->void:
 # Owner C (1497.8,7.3,590): a storey-2 bank above a river carved into the
 # storey below. The drop to the water surface is under a storey, so the
 # carved bed must not make it read as a varied cliff.
 STYLE.apply("sheet_bedrock")
 var env=ENV.build(Rect2(-40,-16,80,48),func(q:Vector2)->float:return 8.0 if q.y<0.0 else 0.0,Callable(),SEED,
  func(q:Vector2)->float:return 5.7 if q.y>=0.0 and q.y<24.0 else NAN)
 var spread:=0.0
 for z in range(-8,3):
  var lo:=INF;var hi:=-INF
  for x in range(-60,61):
   var y:float=env.at(Vector2(x,z)*.5);lo=minf(lo,y);hi=maxf(hi,y)
  spread=maxf(spread,hi-lo)
 assert_lt(spread,.01,"The bank's rounded crest is the same all along the river")
