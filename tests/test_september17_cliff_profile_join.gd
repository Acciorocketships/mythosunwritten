extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")

func test_empty_authored_profiles_cannot_raise_the_existing_wall()->void:
 CRAGS.prepare()
 var empty:=PackedFloat32Array();empty.resize(33)
 var plain:float=CRAGS._body_depth(1.0,4.0,2.0,15.92,0.0,2697992464,[],[])
 for count:int in [1,2,4]:
  var profiles:Array=[]
  for index in count:profiles.append([0.0,12.0,0.0,4.0,empty])
  var joined:float=CRAGS._body_depth(1.0,4.0,2.0,15.92,0.0,2697992464,[],profiles)
  assert_almost_eq(joined,plain,.00001,"A zero-width/zero-depth source at its admission edge must not lift the wall")

func test_authored_profile_fades_continuously_to_zero_at_its_edge()->void:
 CRAGS.prepare()
 var previous:float=CRAGS._body_depth(1.0,4.0,2.0,15.92,0.0,2697992464,[],[])
 var largest:=0.0
 for step in range(1,101):
  var profile:=PackedFloat32Array();profile.resize(33);profile.fill(float(step)*.00001)
  var depth:float=CRAGS._body_depth(1.0,4.0,2.0,15.92,0.0,2697992464,[],[[0.0,12.0,0.0,4.0,profile]])
  largest=maxf(largest,absf(depth-previous));previous=depth
 print("AUTHORED_EDGE_STEP ",largest)
 assert_lt(largest,.0001,"An infinitesimal incoming source cannot create a raised seam")
