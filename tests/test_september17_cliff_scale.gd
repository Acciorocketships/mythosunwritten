extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const BEFORE=preload("res://tests/fixtures/september17/cliff-scale/before.gd")

## Ledges are off by default for now (owner, September 24); these tests
## cover the ledge generator itself.
const _LEDGE_STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_LEDGE_STYLE.ledges=true
func after_all()->void:_LEDGE_STYLE.apply("chosen")

func test_tall_scale_change_preserves_short_geometry_in_frozen_pair()->void:
 for height:float in [4,8,12,16]:
  for x:float in [-24,0,24]:
   var pose:=Transform3D(Basis.IDENTITY,Vector3(x,0,10.5))
   var old:Dictionary=BEFORE.make(pose,24,height,2697992464)[0]
   var current:Dictionary=preload("res://tests/fixtures/september17/cliff-scale/selected.gd").make(pose,24,height,2697992464)[0]
   assert_eq(current.faces,old.faces,"Tall composition must not simplify short physical crags")
   assert_eq(current.green,old.green,"Short ledge geometry remains unchanged")

func test_tall_cliff_retains_coherent_stone_between_fracture_clusters()->void:
 var path:=OS.get_environment("STORY_SCALE_GENERATOR")
 var control:=OS.get_environment("STORY_SCALE_CONTROL")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 var reference:GDScript=load("res://tests/fixtures/september17/cliff-scale/selected-unfractured.gd" if control.is_empty() else control)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var actual:=_columns(generator.make(pose,48,64,2697992464)[0])
 var uncut:=_columns(reference.make(pose,48,64,2697992464)[0])
 var broad:=0;var longest:=0.0
 for x:int in actual:
  var run:=0;var maximum:=0
  for y in range(100,271):
   var z:float=actual[x].get(y,-INF)
   var delta:float=uncut[x].get(y,INF)-z
   run=run+1 if z>2.0 and delta<.30 else 0
   maximum=maxi(maximum,run)
  if maximum>=40:broad+=1
  longest=maxf(longest,maximum*.2)
 print("COHERENT_STONE broad_columns=",broad," longest_m=",longest)
 assert_gte(broad,8,"Some tall faces must survive eight metres between fracture clusters, rather than every face receiving a course every four metres")

func _columns(form:Dictionary)->Dictionary:
 var result:Dictionary={}
 for p:Vector3 in form.faces:
  if p.y<20 or p.y>54 or absf(p.y/.2-roundf(p.y/.2))>.001:continue
  var x:=roundi(p.x*4);var y:=roundi(p.y*5)
  if x%4!=0:continue
  if not result.has(x):result[x]={}
  result[x][y]=maxf(result[x].get(y,-INF),p.z)
 return result

func test_tall_cliff_has_large_upper_formations_between_small_crags()->void:
 var path:=OS.get_environment("STORY_SCALE_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 # Native construction at the fixed corner-study camera/seed. Inspect the
 # actual closed front geometry, above the enlarged lower shoulders.
 var form:Dictionary=generator.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,64,2697992464)[0]
 var columns:Dictionary={}
 for p:Vector3 in form.faces:
  if p.y<20 or p.y>54 or absf(p.y/.2-roundf(p.y/.2))>.001:continue
  var x:=roundi(p.x*4);var y:=roundi(p.y*5)
  if x%4!=0:continue
  if not columns.has(x):columns[x]={}
  columns[x][y]=maxf(columns[x].get(y,-INF),p.z)
 var tall:=0;var longest:=0.0;var short:=0
 for column:Dictionary in columns.values():
  var run:=0;var maximum:=0
  for y in range(100,271):
   run=run+1 if column.get(y,-INF)>3.8 else 0
   maximum=maxi(maximum,run)
  if maximum>=30:tall+=1
  if maximum<15:short+=1
  longest=maxf(longest,maximum*.2)
 print("CLIFF_SCALE tall_columns=",tall," short_columns=",short," longest_m=",longest," total=",columns.size())
 assert_gte(tall,10,"A tall wall needs several coherent six-metre upper rock formations, beyond small repeated lumps")
 assert_gte(short,8,"Retain intervals of smaller crags rather than turning the entire wall into large slabs")

func test_current_short_mass_scale_and_historical_fracture_scale()->void:
 # Sparse fracture art supersedes this old density, but the tall-scale repair's
 # original short-wall invariance remains independently reproducible.
 var historical:GDScript=preload("res://tests/fixtures/september17/cliff-scale/selected.gd")
 for height:float in [4,8,12,16]:
  for x:float in [-24,0,24]:
   var masses:Array=CRAGS._mass_profile(x,height,2697992464)
   # Extra signed lateral coordinates now bend the physical faces. Their
   # original centres, radii and depth budgets retain the short-wall scale.
   var dimensions:Array=[]
   for mass:Array in masses:dimensions.append(mass.slice(0,4))
   # Complete foot discovery also admits masses whose upper radius misses this
   # column. Their existing dimensions must not change merely to widen discovery.
   for original:Array in BEFORE._mass_profile(x,height,2697992464):
    assert_has(dimensions,original,"Retain every original short mass's centre, radii and depth budget")
   assert_eq(historical._fracture_profile(x,height,2697992464),BEFORE._fracture_profile(x,height,2697992464),"Retain the short-wall fracture positions, spans and slopes")
