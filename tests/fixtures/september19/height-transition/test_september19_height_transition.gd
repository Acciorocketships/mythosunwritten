extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const JOIN=preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const ROWS="res://tests/fixtures/september19/short-inner-join/native-walls.bin"
func test_native_height_transition_is_present_and_connects_the_reported_inner_turn()->void:
 ROCKS.prepare()
 var walls:Array=FileAccess.open(ROWS,FileAccess.READ).get_var()
 var forms:Array=ROCKS.formations(walls,2697992464)
 var transition:Dictionary={}
 for f:Dictionary in forms:
  if f.anchor.distance_to(Vector3(-421.5,28,-346.5))<.01:transition=f
 assert_false(transition.is_empty(),"The actual 3 m wide, 8 m high transition cannot be omitted")
 var corner:=Vector3(-421.5,28,-349.5)
 forms.append(CORNER.make_inner(Transform3D(Basis.IDENTITY,corner),4,2697992464))
 var result:=JOIN.apply(forms)
 assert_eq(result.connections,1,"The short turn should continue its real adjacent parents")
 var independent:=0
 for f:Dictionary in forms:
  if f.replay_recipe.kind=="inner_corner":independent+=1
 assert_eq(independent,0)

func test_height_change_keeps_shared_lower_rock_and_buries_the_exposed_upper_end()->void:
 ROCKS.prepare()
 var rows:Array=[]
 for x:int in range(5):
  for level:int in (3 if x<4 else 2):rows.append(Transform3D(Basis.IDENTITY,Vector3(1.5+x*3,level*4,0)))
 var forms:Array=ROCKS.formations(rows,2697992464)
 var lower_depth:=-INF;var upper_depth:=-INF
 for f:Dictionary in forms:
  if f.replay_recipe.height!=12:continue
  for p:Vector3 in f.faces:
   var world:Vector3=f.transform*p
   if absf(world.x-12)>.001:continue
   if world.y>1 and world.y<6:lower_depth=maxf(lower_depth,p.z)
   if world.y>8.01:upper_depth=maxf(upper_depth,p.z)
 assert_gt(lower_depth,.2,"Shared lower end must retain its rock body")
 assert_lt(upper_depth,-.4,"Unbacked upper end must stay buried")
