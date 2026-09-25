extends GutTest
const BEFORE=preload("res://tests/fixtures/september18/cliff-embedded-shoulders/before.gd")

func _front(faces:PackedVector3Array)->Dictionary:
 var points:Dictionary={}
 for p:Vector3 in faces:
  if p.z<0:continue
  var key:=Vector2(p.x,p.y).snapped(Vector2.ONE*.0001)
  points[key]=maxf(points.get(key,-INF),p.z)
 return points

func test_upper_faces_gain_physical_formations_without_moving_the_crown()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5))
 var before:=_front(BEFORE.make(pose,96,64,2697992464)[0].faces)
 var current:=_front(source.make(pose,96,64,2697992464)[0].faces)
 var sampled:=0;var projected:=0;var quiet:=0;var maximum:=0.0;var upper:=0.0
 var columns:Dictionary={}
 for key:Vector2 in before:
  if not current.has(key):continue
  var delta:float=current[key]-before[key]
  if key.y>63:upper=maxf(upper,absf(delta))
  if key.y<32 or key.y>58:continue
  sampled+=1;maximum=maxf(maximum,delta)
  if delta>.15:projected+=1;columns[key.x]=true
  if absf(delta)<.02:quiet+=1
 print("UPPER_OUTCROPS samples=",sampled," projected=",projected," quiet=",quiet," columns=",columns.size()," depth=",maximum," upper_change=",upper)
 assert_gt(projected,200,"Physical upper faces need added rock volumes; shading alone cannot pass")
 assert_gt(columns.size(),20,"New formations need physical width, not isolated spikes")
 assert_gt(float(quiet),float(sampled)*.25,"Keep quiet intervals instead of displacing the entire wall uniformly")
 assert_gt(maximum,.25,"At least some rock shoulders should visibly alter the cliff silhouette")
 assert_lt(maximum,1.5,"Local outcrops must retain a restrained projection")
 assert_lt(upper,.001,"Upper formations must remain flush at the crown")
