extends GutTest
const A=preload('res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd')
func test_retained_stone_corner_selects_rock_instead_of_timber()->void:
 var retained:Dictionary={Vector3i.ZERO:true,Vector3i(1,0,1):true}
 var payload:=A.masonry_corner_joints(retained,{})
 assert_eq(payload.instance_count,1)
 assert_true(payload.batches.has(A.MAZE_STONE_MODULE),'Pure retaining masonry must use stone at its joint')
 assert_false(payload.batches.has(A.TIMBER_SUPPORT),'The exposed vertical timber is the reported stray-board defect')
func test_inhabited_room_contact_preserves_its_timber_member()->void:
 var payload:=A.masonry_corner_joints({Vector3i.ZERO:true},{Vector3i(1,0,1):true})
 assert_eq(payload.instance_count,1)
 assert_true(payload.batches.has(A.TIMBER_SUPPORT))

func test_stone_joint_uses_native_bounds_and_its_retaining_district()->void:
 var retained:Dictionary={Vector3i(0,2,0):true,Vector3i(1,2,1):true}
 var stock:=EnvironmentCatalog.load_default().descriptor(A.MAZE_STONE_MODULE).measured_aabb
 for seed_value:int in [0,17,6667864705524842848]:
  var payload:=A.masonry_corner_joints(retained,{},seed_value,{A.MAZE_STONE_MODULE:{"visual_bounds":stock}})
  var batch:Dictionary=payload.batches[A.MAZE_STONE_MODULE]
  var box:AABB=batch.transforms[0]*stock
  assert_almost_eq(box.position.y,3.0,.0001)
  assert_almost_eq(box.end.y,4.5,.0001)
  assert_almost_eq(box.get_center().x,.75,.0001)
  assert_almost_eq(box.get_center().z,.75,.0001)
  assert_almost_eq(box.size.x,A.STONE_CAP_HALF_DEPTH*2,.0001)
  assert_almost_eq(box.size.z,A.STONE_CAP_HALF_DEPTH*2,.0001)
  assert_eq(batch.colors[0],A.maze_masonry_tint(Vector4i(0,2,0,0),seed_value))
func test_joint_choice_is_independent_of_retained_iteration_order()->void:
 var first:Dictionary={Vector3i.ZERO:true,Vector3i(1,0,1):true,Vector3i(1,0,0):true}
 var second:Dictionary={Vector3i(1,0,0):true,Vector3i(1,0,1):true,Vector3i.ZERO:true}
 assert_eq(A.masonry_corner_joints(first,{},17).batches,A.masonry_corner_joints(second,{},17).batches)
