extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")

func test_fractures_do_not_reenter_native_wall_in_photographed_shoulder()->void:
 var path:=OS.get_environment("STORY_CUT_DEPTH_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 var entry:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[20]
 var form:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
 var front:Dictionary={}
 for p:Vector3 in form.faces:
  var key:=Vector2i(roundi(p.x*100),roundi(p.y*100))
  front[key]=maxf(front.get(key,-INF),p.z)
 var coordinate:float=entry[0].origin.dot(entry[0].basis.x)
 # These five exposed samples originally cut through the native wall by up to
 # 36 cm, creating an island of unrelated native relief inside the added face.
 # Use actual generated vertices, not the private depth-budget formula.
 for key:Vector2i in [Vector2i(325,660),Vector2i(325,640),Vector2i(350,660),Vector2i(350,640),Vector2i(375,660)]:
  assert_true(front.has(key),"Keep the physical photo-site probe on the generated surface")
  var native:float=generator._native_depth(coordinate+key.x*.01,key.y*.01)
  var clearance:float=front.get(key,-INF)-native
  print("CUT_DEPTH anchor=",entry[0].origin," local=",key," clearance=",clearance)
  assert_gt(clearance,0.0,"A finite fracture inside this exposed shoulder must retain its native-wall backing")
