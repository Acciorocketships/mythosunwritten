extends GutTest
const Boundary = preload("res://scripts/terrain/diagnostics/StreamingMovementBoundary.gd")
func _ready_ground(p: Vector3) -> bool:
	return p.x < 191.0 and p.z < 191.0
func test_stops_at_frontier_but_retreat_and_slide_stay_available() -> void:
	var start := Vector3(190.5, 8, 90)
	var stopped := Boundary.clip(start, start+Vector3(10,0,0), _ready_ground)
	assert_lt(stopped.x, 191.0)
	var retreat := Boundary.clip(stopped, stopped-Vector3(2,0,0), _ready_ground)
	assert_almost_eq(retreat.x, stopped.x-2, 0.001)
	var slide := Boundary.clip(stopped, stopped+Vector3(2,0,4), _ready_ground)
	assert_lt(slide.x, 191.0)
	assert_almost_eq(slide.z, stopped.z+4, 0.001)
func test_corner_and_fast_motion_never_cross_missing_ground() -> void:
	var end := Boundary.clip(Vector3(190,10,190), Vector3(450,20,450), _ready_ground)
	assert_lt(end.x, 191.0)
	assert_lt(end.z, 191.0)
	assert_eq(end.y,20.0)
func test_finished_features_are_published_before_terrain_tail_wait() -> void:
	var streamer := FieldTerrainStreamer.new()
	var payload := EnvironmentInstancePayload.new()
	var result := {"kind": &"chunk", "chunk": Vector2i(2,3), "build_features":true,
		"build_terrain":true, "feature_generation":7, "terrain_generation":9, "features":payload}
	streamer._publish_feature_stage(result)
	assert_eq(streamer._done.size(),1)
	assert_true(streamer._done[0].build_features)
	assert_false(streamer._done[0].build_terrain)
	assert_same(streamer._done[0].features,payload)
	assert_eq(streamer._done[0].feature_generation,7)
	assert_true(result.build_terrain)
	assert_false(result.build_features)
	assert_false(result.has("features"))
	streamer.free()

class TestStreamer:
	extends FieldTerrainStreamer
	func _walkable_stream_position(position: Vector3, margin := PLAYER_COLLISION_MARGIN) -> bool:
		return position.x >= margin and position.x < 192.0-margin

func test_teleport_inside_guard_band_can_retreat_without_loading_neighbour() -> void:
	var streamer := TestStreamer.new()
	var start := Vector3(191.8,30,90)
	var stopped := streamer._guard_player_motion(start,start+Vector3(3,0,0))
	assert_almost_eq(stopped.x,start.x,.001)
	var retreat := streamer._guard_player_motion(stopped,stopped-Vector3(5,0,0))
	assert_almost_eq(retreat.x,start.x-5,.001)
	assert_gt(streamer.movement_boundary_blocks,0)
	streamer.free()
