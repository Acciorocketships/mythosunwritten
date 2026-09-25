extends GutTest
## Unresolved reproduction, deliberately outside the ordinary test catalogue.
## Current production fails this proposed connectivity invariant.
## The two passing prototypes were rejected by the native visual comparison.
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
