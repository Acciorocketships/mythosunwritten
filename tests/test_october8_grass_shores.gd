extends GutTest

func test_detached_shore_index_matches_closed_open_and_degenerate_curves() -> void:
	var region := HeightfieldRegion.new({}, {})
	var source := WaterFieldContext.new()
	source._region = region
	source._ctx = {"region":region,"ponds":[],"rivers":[],"buckets":{}}
	source._coverage = Rect2(-100,-100,200,200)
	source._shore_curves_ready = true
	source._shore_curves = [
		{"pts":PackedVector2Array([Vector2(-24,-24),Vector2(24,-12),Vector2(0,24)]),"closed":true},
		{"pts":PackedVector2Array([Vector2(-48,12),Vector2(48,12)]),"closed":false},
		{"pts":PackedVector2Array([Vector2(-12,-12),Vector2(-12,-12)]),"closed":false},
	]
	for limit: float in [0.0, 0.3, 4.0, 16.0]:
		source._shore_limit = limit
		var detached := GrassSamplingContext.detached(region,source)
		var matches := true
		for z in range(-60,61):
			for x in range(-60,61):
				var point := Vector2(x,z) + Vector2(0.0,0.17)
				matches = matches and detached.water.shore_distance_at(point) == source.shore_distance_at(point)
		assert_true(matches,"exact saturated distance, including negative cell boundaries and closed final edges; limit=%s" % limit)

func test_a_far_shore_does_not_enlarge_the_local_query() -> void:
	var region := HeightfieldRegion.new({}, {})
	var source := WaterFieldContext.new()
	source._region = region
	source._ctx = {"region":region,"ponds":[],"rivers":[],"buckets":{}}
	source._coverage = Rect2(-100,-100,200,200)
	source._shore_limit = 0.3
	source._shore_curves_ready = true
	for i in 1000:
		source._shore_curves.append({"pts":PackedVector2Array([Vector2(50,i*.01),Vector2(60,i*.01)]),"closed":false})
	var detached := GrassSamplingContext.detached(region,source)
	assert_eq(detached.water.shore_distance_at(Vector2.ZERO),source.shore_distance_at(Vector2.ZERO))
	assert_false((detached.water as GrassSamplingContext.WaterSamples).shore_cells.has(Vector2i.ZERO),
		"a grass query whose answer saturates cannot scan a distant river's thousand segments")

func test_support_buckets_match_the_full_scan_at_overlaps_and_boundaries() -> void:
	var supports: Array = []
	for i in 100:
		var heights := PackedFloat32Array([1,1,1,1])
		heights.fill(float(i % 3))
		supports.append({"grid":true,"origin":Vector2(i-50,-1.5),"step":3.0,
			"w":2,"h":2,"heights":heights,"flags":PackedByteArray([1,1,1,1]),"id":str(i)})
	var index := GrassSupportSurfaces.spatial_index(supports)
	var same := true
	for x in range(-220,220):
		for z in range(-8,8):
			var point := Vector2(x,z)*0.25
			var expected := {}
			for support: Dictionary in supports:
				var sample := GrassSupportSurfaces.at_grid(support,point)
				if not sample.is_empty() and (expected.is_empty() or float(sample.y)>float(expected.y)):
					expected=sample
			same = same and GrassSupportSurfaces.at_index(index,point)==expected
	assert_true(same,"overlap winners, tied heights and grid boundaries retain the full scan's exact output")
