extends GutTest

func _box(x, y, z, sx, sy, sz) -> AABB:
	return AABB(Vector3(x, y, z), Vector3(sx, sy, sz))

func _rand_box(rng: RandomNumberGenerator) -> AABB:
	var x = rng.randf_range(-200, 200)
	var z = rng.randf_range(-200, 200)
	var y = rng.randf_range(-10, 10)
	var sizes = [4.0, 8.0, 12.0, 24.0]
	var sx = sizes[rng.randi() % sizes.size()]
	var sz = sizes[rng.randi() % sizes.size()]
	var sy = rng.randf_range(1, 8)
	return AABB(Vector3(x, y, z), Vector3(sx, sy, sz))

var _next_id := 0

var _objs_to_free: Array[Object] = []

func before_each() -> void:
	_objs_to_free.clear()

func after_each() -> void:
	for o in _objs_to_free:
		if is_instance_valid(o):
			o.free()
	_objs_to_free.clear()

func _make_module(size: AABB) -> TerrainModuleInstance:
	var dummy_scene := PackedScene.new()
	var m := TerrainModule.new(dummy_scene, size)
	m.debug_id = _next_id
	_next_id += 1
	var inst: TerrainModuleInstance = m.spawn()
	# Tests for TerrainIndex use synthetic AABBs; bypass mesh-based AABB computation.
	inst.size = size
	inst.set_world_aabb()
	return inst

# --------------------------------------------------------
# TEST CASE: deterministic small test
# --------------------------------------------------------
func test_deterministic():
	var idx := TerrainIndex.new()
	_objs_to_free.append(idx)

	var center_mod = _make_module(_box(-12, 0, -12, 24, 4, 24))
	var east_mod   = _make_module(_box(12, 0, -2, 4, 4, 4))
	var north_mod  = _make_module(_box(-2, 0, 12, 4, 4, 4))

	idx.insert(center_mod)
	idx.insert(east_mod)
	idx.insert(north_mod)

	var q1 = idx.query_box(_box(-12,-1,-12,24,10,24))
	assert_eq(q1.size(), 1, "q1 count")
	assert_true(center_mod in q1, "q1 has center")

	var q2 = idx.query_box(_box(-12,-1,-12,40,10,24))
	assert_true(center_mod in q2, "q2 has center")
	assert_true(east_mod in q2, "q2 has east")
	assert_false(north_mod in q2, "q2 excludes north")

	# Move
	east_mod.set_position(Vector3(-40,0,0))
	idx.update(east_mod)
	var q3 = idx.query_box(_box(-50,-1,-10,30,10,20))
	assert_true(east_mod in q3)
	assert_false(center_mod in q3)
	assert_false(north_mod in q3)

# --------------------------------------------------------
# TEST CASE: random fuzz test (without print spam)
# --------------------------------------------------------
func test_random_stress():
	var idx := TerrainIndex.new()
	_objs_to_free.append(idx)
	var naive: Array = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 123456

	_next_id = 0

	# fewer modules to reduce CPU load
	for i in range(200):
		var box = _rand_box(rng)
		var m = _make_module(box)
		idx.insert(m)
		naive.append({"m": m, "box": box})

	for qi in range(200):
		var q = _rand_box(rng)
		var fast = idx.query_box(q)

		var slow: Array = []
		for e in naive:
			if e["box"].intersects(q):
				slow.append(e["m"])

		assert_eq(
			fast.size(), 
			slow.size(), 
			"fast matches slow for query " + str(qi)
		)

		for m in fast:
			assert_true(slow.has(m), "fast-only module in query " + str(qi))

		for m in slow:
			assert_true(fast.has(m), "slow-only module in query " + str(qi))
