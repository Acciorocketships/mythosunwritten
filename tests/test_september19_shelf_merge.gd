extends GutTest
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func reported(strength:float)->Array:
 return [[5.0311307826246,2.80659267679372,2.0,0.0],[5.32176735449271,strength,4.14002782534808,.23283841863105],[6.201732881186,1.27716865060528,3.17820718144067,0.0]]
func substantial(cuts:Array)->Array:
 var result:=cuts.filter(func(c:Array)->bool:return c[1]>.1)
 result.sort_custom(func(a:Array,b:Array)->bool:return a[0]<b[0])
 return result
func test_emerging_shelf_cannot_displace_existing_bearings_abruptly()->void:
 var a:=reported(0.0);var b:=reported(.00000628074677)
 CRAGS._merge_close_ledges(a);CRAGS._merge_close_ledges(b)
 a=substantial(a);b=substantial(b)
 assert_eq(a.size(),b.size())
 var jump:=0.0
 for i in mini(a.size(),b.size()):jump=maxf(jump,absf(a[i][0]-b[i][0]))
 print("EMERGING_SHELF height_jump=",jump)
 assert_lt(jump,.001,"An almost absent intermediate shelf cannot move the actual larger ledges")
func test_transfer_conserves_support_and_keeps_distant_ledges_independent()->void:
 for strength:float in [0.0,.00000628074677,.05,.2,1.0]:
  var cuts:=reported(strength);cuts.append([10.0,.8,2.0,.1])
  var total:=0.0
  for c:Array in cuts:total+=c[1]
  CRAGS._merge_close_ledges(cuts)
  var actual:=0.0
  for c:Array in cuts:actual+=c[1]
  assert_almost_eq(actual,total,.00001)
  assert_eq(cuts[-1],[10.0,.8,2.0,.1])

func test_tiny_new_tread_does_not_steal_the_adjacent_full_tread_match()->void:
 var left:=PackedVector3Array([Vector3(0,8,0),Vector3(0,5,1),Vector3(0,5,2.5),Vector3(0,0,3)])
 var right:=PackedVector3Array([Vector3(.25,8,0),Vector3(.25,5.4,1),Vector3(.25,5.4,1.01),Vector3(.25,4.98,1),Vector3(.25,4.98,2.5),Vector3(.25,0,3)])
 var joins:=CRAGS._matched_bands(left,right,[[0,1,false],[1,2,true],[2,3,false]],[[0,1,false],[1,2,true],[2,3,false],[3,4,true],[4,5,false]])
 var matched:Array=[]
 for join:Array in joins:
  if join[0][2]:matched.append([join[0][0],join[1][0]])
 assert_eq(matched,[[1,3]],"The broad continuing tread must not be stitched to a new hairline above it")
