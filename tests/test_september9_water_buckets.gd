extends GutTest

class StraightRiverWater extends WaterPlan:
	var trace := RiverTrace.new()
	func _init() -> void:
		super(19, 32, 8)
		for i in 201:
			trace.points.append(Vector2(-2400+i*24, 24))
			trace.beds.append(4)
			trace.widths.append(26)
	func river_for(sc: Vector2i, _depth: int = JOIN_DEPTH,
			_progress_start := -1.0, _progress_end := -1.0) -> RiverTrace:
		return trace if sc == Vector2i.ZERO else null

func test_regional_carve_index_only_stores_its_owned_cells() -> void:
	var water := StraightRiverWater.new()
	for region_key in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]:
		var region := water._region_for(region_key)
		var outside := 0
		for cell: Vector2i in region.buckets:
			var owner := Vector2i(floori(float(cell.x)/32), floori(float(cell.y)/32))
			if owner != region_key: outside += 1
		assert_eq(outside, 0, "a region cannot service another region's carve coordinates")
		assert_eq(region.rivers, [water.trace], "complete river discovery is retained")
		# Independently enumerate the old full-trace index at every owned
		# cell. Negative and exact-zero boundaries must retain every sample.
		for z in range(region_key.y*32, (region_key.y+1)*32):
			for x in range(region_key.x*32, (region_key.x+1)*32):
				var expected: Array[int] = []
				for i in water.trace.points.size():
					var point: Vector2 = water.trace.points[i]
					var influence := water.trace.widths[i] + WaterPlan.BANK_FEATHER
					if x >= floori((point.x-influence)/24+0.5) and x <= floori((point.x+influence)/24+0.5) \
							and z >= floori((point.y-influence)/24+0.5) and z <= floori((point.y+influence)/24+0.5):
						expected.append(i)
				var actual: Array[int] = []
				for entry: Array in region.buckets.get(Vector2i(x,z), []):
					assert_same(entry[0], water.trace)
					actual.append(entry[1])
				assert_eq(actual, expected)
