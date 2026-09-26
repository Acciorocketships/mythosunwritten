extends GutTest
## Bedrock sheet style (owner, September 26): rock and ledges in the slope
## surface, slopes only on real cliffs, slopes into water, lip options.
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const ENVELOPE=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED:=2697992464

func after_each()->void:
 STYLE.apply("sheet")

func _wall(pose:Transform3D,width:float,height:float)->Dictionary:
 return {"replay_recipe":{"kind":"wall","width":width,"height":height,"left_end":true,"right_end":true,"abut":Vector2i.ZERO},"transform":pose}

## Plateau `top` high for z < 0, `low` beyond.
func _step(top:float,low:=0.0)->Callable:
 return func(q:Vector2)->float:return top if q.y<0.0 else low

func test_bedrock_solid_has_no_open_edges()->void:
 STYLE.apply("sheet_bedrock")
 var field=FIELD.new([_wall(Transform3D(Basis(),Vector3(0,0,0)),80,12)],SEED)
 field.ground_at=_step(12.0)
 field._env=null
 var owned:=Rect2(-30,-10,60,40)
 var env=field.envelope()
 var exposed:=0
 for x in range(-30,30):
  for z in range(0,15):
   if env.rock_at(Vector2(x,z))>.5:exposed+=1
 assert_gt(exposed,20,"Some of a 12 m face is bare rock")
 var faces:PackedVector3Array=field.solid(owned)[0].faces
 var count:Dictionary={}
 for i in range(0,faces.size(),3):
  for k in 3:
   var a:=faces[i+k];var b:=faces[i+(k+1)%3]
   var key:=[a,b] if a<b else [b,a]
   count[key]=count.get(key,0)+1
 var open:=0
 for e:Array in count:
  if count[e]!=1 or (e[0] as Vector3).distance_to(e[1])<.02:continue
  var m:Vector3=(e[0]+e[1])*.5
  if owned.grow(-1.0).has_point(Vector2(m.x,m.z)) and m.y>field.ground(Vector2(m.x,m.z))+.1:open+=1
 assert_eq(open,0,"Carved rock leaves no hole in the slope")

func test_level_steps_take_no_slope()->void:
 # The terrain's 1 m level steps are ramps already: no slope strip over them
 # (it showed as a light/dark seam beside paths).
 STYLE.apply("sheet_bedrock")
 var env=ENVELOPE.build(Rect2(-20,-20,40,40),_step(1.0),Callable(),SEED)
 var worst:=0.0
 for x in range(-20,20):
  for z in range(-20,20):
   var q:=Vector2(x,z)*.5+Vector2(.25,.25)
   worst=maxf(worst,env.at(q)-env.ground_node(q))
 assert_lt(worst,.15,"No slope over a 1 m level step")

func test_cliffs_keep_their_slope()->void:
 STYLE.apply("sheet_bedrock")
 var env=ENVELOPE.build(Rect2(-20,-20,40,40),_step(4.0),Callable(),SEED)
 assert_gt(env.at(Vector2(0,1.0))-env.ground_node(Vector2(0,1.0)),1.0,"A storey cliff still takes its slope")

func test_slope_runs_into_water_then_sinks()->void:
 # Cliffs at water get the slope too (no flat cut plane at the waterline);
 # far out it stays under the water surface and cannot fill a channel.
 STYLE.apply("sheet_bedrock")
 var level:=.8
 var water:=func(q:Vector2)->float:return level if q.y>3.0 else NAN
 var ground:=func(q:Vector2)->float:return 8.0 if q.y<0.0 else 0.0
 var env=ENVELOPE.build(Rect2(-20,-20,40,50),ground,Callable(),SEED,water)
 assert_gt(env.at(Vector2(0,4.0)),level+.3,"Just past the shore the slope stands above the water")
 for z in range(12,24):
  assert_lt(env.at(Vector2(0,z)),level,"Far out it is under water (z=%d)"%z)

func test_steep_slope_claims_its_grass_points()->void:
 # A steep node grows no grass but must not fall back to the terrain below:
 # blades rooted under the slope poked their tips through it.
 var grid:={"grid":true,"origin":Vector2.ZERO,"step":.5,"w":3,"h":3,
  "heights":PackedFloat32Array([0,2,4,0,2,4,0,2,4]),"flags":PackedByteArray([1,1,1,1,1,1,1,1,1]),
  "bounds":Rect2(0,0,1,1),"id":"t","obstacles":[]}
 var sample:=GrassSupportSurfaces.at_grid(grid,Vector2(.4,.4))
 assert_false(sample.is_empty(),"The steep slope still claims the point")
 assert_eq(float(sample.edge_distance),0.0,"and grows no grass there")

func test_underlip_keeps_the_lip_and_starts_below_it()->void:
 STYLE.apply("sheet_bedrock+underlip")
 var env=ENVELOPE.build(Rect2(-20,-20,40,40),_step(8.0),Callable(),SEED)
 # The cell overhangs the visible wall line by OVERHANG.
 var wall_line:=-ENVELOPE.OVERHANG
 assert_lt(env.at(Vector2(0,wall_line+.5)),8.0-ENVELOPE.LIP_DROP+.5,"The slope leaves the wall under the lip")
 assert_almost_eq(env.at(Vector2(0,wall_line-1.0)),8.0,.01,"The plateau behind the lip keeps its own ground")
 var pieces:={"grass_lip":[Transform3D(Basis(),Vector3(0,8,wall_line))]}
 assert_eq((env.uncovered(pieces).grass_lip as Array).size(),1,"Native lips stay")
