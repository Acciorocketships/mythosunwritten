extends GutTest

func test_queue_diagnostics_do_not_publish_temporary_sort_metrics()->void:
	var stream:=FieldTerrainStreamer.new()
	stream._queue_travel_offset=Vector2.ZERO
	stream._request_job_locked(Vector2i(2,2),true,false,2,3)
	var snapshot:=stream.streaming_profile_snapshot()
	assert_false(snapshot.queue_head[0].has("_sort_travel"),"temporary infinite sort distances must not leak into JSON reports")
	assert_false(snapshot.queue_head[0].has("_sort_ground"))
	stream.free()

func test_forward_ground_precedes_closer_side_ground_while_running()->void:
	var stream:=FieldTerrainStreamer.new()
	stream._startup_completion_emitted=true
	var origin:=Vector2(287.4,-1238)
	var centre:=Vector2i(1,-7)
	stream._queue_lod_origin=origin
	stream._queue_travel_offset=Vector2(0,-300)
	for chunk:Vector2i in [Vector2i(1,-6),Vector2i(1,-8),Vector2i(1,-9)]:
		stream._request_job_locked(chunk,true,false,1,stream._terrain_priority_tier(chunk,centre,origin))
	stream._refresh_job_priorities_locked(centre,origin)
	assert_eq(stream._jobs[0].chunk,Vector2i(1,-8),"the first upcoming crossing precedes ground behind the runner")
	assert_eq(stream._jobs[1].chunk,Vector2i(1,-9),"the following crossing precedes background terrain")
	stream._queue_travel_offset=Vector2.ZERO
	stream._refresh_job_priorities_locked(centre,origin)
	assert_eq(stream._jobs[0].chunk,Vector2i(1,-6),"stopping restores physical-proximity priority")
	stream.free()

func test_long_lookahead_cannot_skip_the_intervening_chunk()->void:
	var stream:=FieldTerrainStreamer.new()
	stream._startup_completion_emitted=true
	var origin:=Vector2(287.4,-1238)
	var centre:=Vector2i(1,-7)
	stream._queue_lod_origin=origin
	stream._queue_travel_offset=Vector2(0,-500)
	assert_eq(stream._terrain_priority_tier(Vector2i(1,-8),centre,origin),1,"the segment, not only its far endpoint, owns prefetch")
	assert_eq(stream._terrain_priority_tier(Vector2i(1,-9),centre,origin),1)
	stream.free()
