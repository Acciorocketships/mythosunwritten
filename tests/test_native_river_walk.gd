extends GutTest
const N := preload("res://scripts/native/NativeRiverWalk.gd")

func test_native_walks_match_gdscript_exactly_or_stay_off() -> void:
	var seed := 2697992464
	N.setup(seed)
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(N.ready_for(seed)); return
	assert_true(N.ready_for(seed), "parity gate passed")
	var gd := TerrainWorldTuning.make_water(seed)
	var native := TerrainWorldTuning.make_water(seed)
	TerrainWorldTuning.make_heightfield(seed, gd)
	TerrainWorldTuning.make_heightfield(seed, native)
	for sc in [Vector2i(-3, -11), Vector2i(1, -5), Vector2i(2, 2), Vector2i(-6, 4), Vector2i(9, -9)]:
		N.force_off = true
		var a := gd.has_source(sc)
		var ta: RiverTrace = gd._walk(sc) if a else null
		N.force_off = false
		var b := native.has_source(sc)
		assert_eq(a, b, "has_source %s" % sc)
		if a:
			var tb: RiverTrace = native._walk(sc)
			assert_eq(ta.points, tb.points); assert_eq(ta.beds, tb.beds); assert_eq(ta.widths, tb.widths)
			assert_eq(ta.pond.center, tb.pond.center); assert_eq(ta.pond.level, tb.pond.level)
			assert_eq(ta.source_pool.level, tb.source_pool.level)
