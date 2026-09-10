extends GutTest

func _reference(point:Vector3,seed_value:int,scale:float)->float:
	var x:=point.x/scale
	var z:=point.z/scale
	var cx:=floori(x)
	var cz:=floori(z)
	var fx:=smoothstep(0,1,x-float(cx))
	var fz:=smoothstep(0,1,z-float(cz))
	return lerpf(lerpf(Helper._cell_hash01(seed_value,cx,cz),Helper._cell_hash01(seed_value,cx+1,cz),fx),
		lerpf(Helper._cell_hash01(seed_value,cx,cz+1),Helper._cell_hash01(seed_value,cx+1,cz+1),fx),fz)

func test_value_noise_retains_full_seed_precision_and_cell_boundary_values()->void:
	for seed_value:int in [2697992464,2697992464+(1<<40),-9223372036854770000]:
		for scale:float in [46,120,320,420,768]:
			for offset:float in [-0.001,0,0.001]:
				for point:Vector3 in [Vector3(-320+offset,0,120),Vector3(offset,0,-768),Vector3(1080,0,offset)]:
					assert_eq(Helper._value_noise01(point,seed_value,scale),_reference(point,seed_value,scale))

func test_cold_values_survive_cache_pressure_and_reversed_query_order()->void:
	var first:=Vector3(-37,0,13)
	var expected:=_reference(first,2697992464,46)
	assert_eq(Helper._value_noise01(first,2697992464,46),expected)
	for i in 20000:
		var point:=Vector3(i*48,0,-i*48)
		if i%199==0: assert_eq(Helper._value_noise01(point,2697992464,46),_reference(point,2697992464,46))
		else: Helper._value_noise01(point,2697992464,46)
	assert_eq(Helper._value_noise01(first,2697992464,46),expected)
	for i in range(99,-1,-1):
		var point:=Vector3(i*48,0,-i*48)
		assert_eq(Helper._value_noise01(point,2697992464,46),_reference(point,2697992464,46))
	assert_lte(Helper._noise_corner_cache.size(),Helper._NOISE_CORNER_CACHE_LIMIT)

func _parallel_probe(seed_value:int)->int:
	var mismatches:=0
	for i in 12000:
		var point:=Vector3(i*48,0,-i*24)
		if Helper._value_noise01(point,seed_value,46)!=_reference(point,seed_value,46): mismatches+=1
	return mismatches

func test_concurrent_eviction_retains_exact_corner_values()->void:
	var first:=Thread.new()
	var second:=Thread.new()
	assert_eq(first.start(_parallel_probe.bind(2697992464)),OK)
	assert_eq(second.start(_parallel_probe.bind(2697992464+(1<<40))),OK)
	assert_eq(first.wait_to_finish(),0)
	assert_eq(second.wait_to_finish(),0)
	assert_lte(Helper._noise_corner_cache.size(),Helper._NOISE_CORNER_CACHE_LIMIT)
