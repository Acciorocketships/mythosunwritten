extends GutTest
## September 22 manual review, photos 2/4: modular timber houses met at their
## outer corners as bare plaster (two mitred panels, mismatched rails), and a
## deep door's return left a stepped seam with a hairline gap on the facade.
## Each exterior timber corner and each door-return seam owns a timber post.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const SOURCE := "res://tests/fixtures/september22/town-e-source.txt"
const WORLD_ORIGIN := Vector3(310.5, 12.08, 1074.5)
static var _placements: Array[Dictionary] = []


func _realized() -> Array[Dictionary]:
	if _placements.is_empty():
		var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		_placements = FROZEN.spatial(FROZEN.read(SOURCE), program).compiled_fabric_cache().expanded_placements()
	return _placements


func _post_at(world_x: float, world_z: float, world_y: float, prefix: String) -> bool:
	# The frozen town frame is a uniform 2x scale about WORLD_ORIGIN.
	var local := (Vector3(world_x, world_y, world_z) - WORLD_ORIGIN) / 2.0
	for placement: Dictionary in _realized():
		if not String(placement.get("stable_id", "")).begins_with(prefix): continue
		var bounds := (placement.bounds as AABB).grow(0.01)
		if bounds.has_point(local): return true
	return false


func test_photographed_timber_corners_carry_a_corner_post() -> void:
	# Photo 2: maze_back.03's and house.015's north-west corners.
	assert_true(_post_at(321.0, 1109.0, 15.0, "facade-corner/"), "maze_back.03 corner post")
	assert_true(_post_at(309.0, 1115.0, 15.0, "facade-corner/"), "house.015 corner post")


func test_door_return_seam_carries_a_post() -> void:
	# Photo 4: house.006's facade beside its deep west door.
	var found := false
	for placement: Dictionary in _realized():
		var id := String(placement.get("stable_id", ""))
		found = found or (id.begins_with("facade-door-return/") and "house.006.part00.room00" in id)
	assert_true(found, "house.006 door-return seam post")


func test_corner_posts_stay_slender_and_proud() -> void:
	var count := 0
	for placement: Dictionary in _realized():
		if not String(placement.get("stable_id", "")).begins_with("facade-corner/"): continue
		count += 1
		var bounds := placement.bounds as AABB
		assert_almost_eq(bounds.size.x, SettlementFabricPlan.CONVEX_POST_WIDTH, 0.01, "post section")
		assert_almost_eq(bounds.size.z, SettlementFabricPlan.CONVEX_POST_WIDTH, 0.01, "post section")
	assert_gt(count, 10, "the town's timber houses own their outer corners")
