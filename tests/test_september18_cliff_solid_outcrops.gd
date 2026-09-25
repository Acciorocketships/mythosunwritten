extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-weathered-shapes/before.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")

# This pins the full-projection formation logic against its historical
# baseline. The owner-selected subtle compression (September 23) displaces
# every lower face uniformly by design; test_september23_cliff_directions.gd
# covers it.
func before_all()->void:STYLE.apply("current")
func after_all()->void:STYLE.apply("chosen")

func _front(faces:PackedVector3Array)->Dictionary:
 var points:Dictionary={}
 for p:Vector3 in faces:
  if p.z<0:continue
  var key:=Vector2(p.x,p.y).snapped(Vector2.ONE*.0001)
  points[key]=maxf(points.get(key,-INF),p.z)
 return points

func test_added_formations_change_physical_shape_in_local_patches()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var before:=_front(BEFORE.make(pose,96,32,2697992464)[0].faces)
 var current:=_front(source.make(pose,96,32,2697992464)[0].faces)
 var sampled:=0;var projected:=0;var quiet:=0;var maximum:=0.0;var upper:=0.0
 var columns:Dictionary={}
 for key:Vector2 in before:
  if not current.has(key):continue
  var delta:float=current[key]-before[key]
  # Preserve the actual crown collar. The upper face below it now intentionally
  # receives restrained physical relief, verified on both 32 m and 64 m walls.
  if key.y>32-1.3:upper=maxf(upper,absf(delta))
  if key.y<1 or key.y>20:continue
  sampled+=1;maximum=maxf(maximum,delta)
  if delta>.25:projected+=1;columns[key.x]=true
  if absf(delta)<.02:quiet+=1
 print("SOLID_OUTCROPS samples=",sampled," projected=",projected," quiet=",quiet," columns=",columns.size()," depth=",maximum," upper_change=",upper)
 assert_gt(projected,200,"Real rock vertices must project beyond the previous wall; shading alone cannot pass")
 assert_gt(columns.size(),20,"New formations need physical width, not isolated spikes")
 assert_gt(float(quiet),float(sampled)*.25,"Keep quiet intervals instead of displacing the entire wall uniformly")
 assert_gt(maximum,.65,"At least some rock shoulders should visibly alter the cliff silhouette")
 assert_lt(maximum,3.3,"Local outcrops must retain a restrained projection")
 # September 22: order-independent shelf merging moves a near-crest shelf by
 # about a millimetre; the collar itself is still unchanged within 2 mm.
 assert_lt(upper,.002,"Additional formations must leave the crown attachment intact")
