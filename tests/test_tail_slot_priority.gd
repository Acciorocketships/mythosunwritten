extends GutTest

func _stream() -> FieldTerrainStreamer:
	var stream := FieldTerrainStreamer.new()
	stream._tail_free.assign([0,1,2])
	stream._startup_completion_emitted = true
	stream._profile_player_chunk = Vector2i(-3,-7)
	stream._queue_lod_origin = Vector2(-530.6,-1260)
	stream._queue_travel_offset = Vector2(0,-300)
	stream._active_job = stream._new_job(Vector2i(-5,-9),true,false,2,3)
	return stream

static func _wait(stream: FieldTerrainStreamer, entered: Semaphore, result: Dictionary) -> void:
	entered.post()
	result.acquired = stream._wait_for_tail_slot()

func test_new_urgent_ground_interrupts_wait_without_a_free_tail_slot() -> void:
	var stream := _stream()
	var entered := Semaphore.new()
	var result := {}
	var thread := Thread.new()
	assert_eq(thread.start(_wait.bind(stream,entered,result)),OK)
	entered.wait()
	OS.delay_msec(15)
	assert_true(thread.is_alive(),"background work waits while all slots are occupied")
	stream._mutex.lock()
	stream._request_job_locked(Vector2i(-3,-8),true,true,1,1)
	stream._mutex.unlock()
	var deadline := Time.get_ticks_msec()+1000
	while thread.is_alive() and Time.get_ticks_msec()<deadline: OS.delay_msec(5)
	var yielded := not thread.is_alive()
	if not yielded:
		stream._mutex.lock()
		stream._exit = true
		stream._mutex.unlock()
		stream._tail_slots.post()
	thread.wait_to_finish()
	assert_true(yielded,"urgent planning proceeds without waiting for an unrelated tail to finish")
	assert_false(result.acquired)
	assert_false(stream._tail_slots.try_wait(),"cancellation did not invent a slot")
	stream.free()

func test_cancelled_wait_returns_an_available_slot() -> void:
	var stream := _stream()
	stream._request_job_locked(Vector2i(-3,-8),true,true,1,1)
	stream._tail_slots.post()
	assert_false(stream._wait_for_tail_slot())
	assert_true(stream._tail_slots.try_wait())
	assert_false(stream._tail_slots.try_wait())
	stream.free()

func test_needed_job_acquires_exactly_one_slot() -> void:
	var stream := _stream()
	stream._tail_slots.post()
	assert_true(stream._wait_for_tail_slot())
	assert_false(stream._tail_slots.try_wait())
	stream.free()

func test_shutdown_interrupts_a_saturated_wait() -> void:
	var stream := _stream()
	stream._exit = true
	assert_false(stream._wait_for_tail_slot())
	stream.free()


func test_last_slot_is_reserved_for_nearby_ground() -> void:
	var stream := _stream()
	stream._tail_free.assign([0])
	stream._tail_slots.post()
	var entered := Semaphore.new()
	var result := {}
	var thread := Thread.new()
	assert_eq(thread.start(_wait.bind(stream,entered,result)),OK)
	entered.wait()
	OS.delay_msec(20)
	assert_true(thread.is_alive(),"distant scenery cannot consume the reserve")
	stream._mutex.lock()
	stream._request_job_locked(Vector2i(-3,-8),true,true,1,1)
	stream._mutex.unlock()
	var deadline := Time.get_ticks_msec()+1000
	while thread.is_alive() and Time.get_ticks_msec()<deadline: OS.delay_msec(5)
	if thread.is_alive():
		stream._mutex.lock()
		stream._exit = true
		stream._mutex.unlock()
	thread.wait_to_finish()
	assert_false(result.acquired)
	stream._active_job_yield_requested = false
	stream._active_job = stream._jobs.pop_front()
	assert_true(stream._wait_for_tail_slot(),"upcoming terrain uses the reserved slot immediately")
	assert_false(stream._tail_slots.try_wait())
	stream.free()

func test_startup_can_use_all_tail_slots() -> void:
	var stream := _stream()
	stream._startup_completion_emitted = false
	stream._tail_free.assign([0])
	stream._tail_slots.post()
	assert_true(stream._wait_for_tail_slot())
	assert_false(stream._tail_slots.try_wait())
	stream.free()
