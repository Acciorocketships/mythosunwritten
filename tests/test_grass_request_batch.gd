extends GutTest

func test_batch_preserves_priority_updates_and_rejections() -> void:
	var single := GrassWorkQueue.new(null,99,0)
	var batch := GrassWorkQueue.new(null,99,0)
	var sampling := GrassSamplingContext.new()
	var requests: Array[Dictionary] = []
	for tile: Vector2i in GrassStreamer.desired_tiles(Vector2.ZERO):
		requests.push_front({"tile":tile,"generation":1,"sampling":sampling})
	requests.append({"tile":Vector2i(1000,1000),"generation":1,"sampling":sampling})
	var accepted: Array[Vector2i] = []
	for item in requests:
		if single.request(item.tile,item.generation,item.sampling): accepted.append(item.tile)
	assert_eq(batch.request_batch(requests),accepted)
	assert_eq(batch._jobs,single._jobs,"batching preserves deterministic nearest-first order")
	var replacement := GrassSamplingContext.new()
	batch._active[Vector2i(1,1)] = true
	var updates: Array[Dictionary] = [
		{"tile":Vector2i.ZERO,"generation":2,"sampling":replacement},
		{"tile":Vector2i(1,1),"generation":2,"sampling":replacement}]
	assert_eq(batch.request_batch(updates),[Vector2i.ZERO])
	assert_eq(batch._queued[Vector2i.ZERO].generation,2)
	assert_same(batch._queued[Vector2i.ZERO].sampling,replacement)
	single.stop()
	batch.stop()
	assert_true(batch.request_batch(updates).is_empty(),"shutdown rejects new batches")

func test_scan_cost_is_measured_without_worker_scheduling_noise() -> void:
	var requests: Array[Dictionary] = []
	for tile: Vector2i in GrassStreamer.desired_tiles(Vector2.ZERO):
		requests.append({"tile":tile,"generation":1,"sampling":GrassSamplingContext.new()})
	var single := GrassWorkQueue.new(null,99,0)
	var batch := GrassWorkQueue.new(null,99,0)
	var start := Time.get_ticks_usec()
	for item in requests: single.request(item.tile,item.generation,item.sampling)
	var single_us := Time.get_ticks_usec()-start
	start = Time.get_ticks_usec()
	batch.request_batch(requests)
	print("GRASS_BATCH_COST tiles=%d single_us=%d batch_us=%d" % [requests.size(),single_us,Time.get_ticks_usec()-start])
	assert_eq(batch._jobs,single._jobs)
	single.stop()
	batch.stop()
