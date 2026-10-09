extends GutTest

class FlatSampler:
	extends WaterSampler
	func _current_surface_level_at(_p: Vector2) -> float:
		return 2.0

func test_full_frame_cache_evicts_one_entry_without_dropping_warm_frames() -> void:
	var sampler := FlatSampler.new()
	for i in WaterSampler.FRAME_CACHE_CAP:
		sampler._surface_frame(Vector2(i,0)*WaterSampler.FRAME_CELL)
	var expected := sampler._surface_frame(Vector2(20,0)*WaterSampler.FRAME_CELL)
	sampler._surface_frame(Vector2(-1,0)*WaterSampler.FRAME_CELL)
	assert_eq(sampler._frames.size(),WaterSampler.FRAME_CACHE_CAP)
	assert_true(sampler._frames.has(Vector2i(20,0)),"one miss must not flush all warm wave samples")
	assert_eq(sampler._surface_frame(Vector2(20,0)*WaterSampler.FRAME_CELL),expected)
