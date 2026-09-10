extends GutTest

var _fields: WorldFieldBlockCache

func before_all() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	_fields = WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),
		water,0.0,0.0,128)

func test_water_tag_cannot_turn_an_ordinary_slope_into_a_wall() -> void:
	var heights: Dictionary = {}
	for z in range(-3,4):
		for x in range(-3,4): heights[Vector2i(x,z)] = 1 if x <= 0 else 0
	var plain := HeightfieldRegion.new(heights,{})
	var bank := HeightfieldRegion.new(heights,{}, {Vector2i(1,0):true})
	assert_false(TerrainSurfaceField._is_cliff_top(bank,0,0))
	for x in range(0,25):
		assert_almost_eq(TerrainSurfaceField.surface_y(bank,x,0),
			TerrainSurfaceField.surface_y(plain,x,0),0.000001,
			"a river uses the same slope as ordinary terrain")

func test_photographed_bank_has_a_continuous_walk_to_shallow_water() -> void:
	var region := _fields.region(Vector2i(-3,-2))
	var water := _fields.water(Vector2i(-3,-2))
	var entered := 0
	for x in [-552.0,-528.0,-518.4]:
		var previous := TerrainSurfaceField.surface_y(region,x,-300.0)
		for i in range(1,161):
			var p := Vector2(x,-300.0+i*0.5)
			var ground := TerrainSurfaceField.surface_y(region,p.x,p.y)
			assert_lt(absf(ground-previous),0.4,"half-metre samples cannot hide a bank wall")
			previous = ground
			var level := water.level_at(p)
			if is_finite(level):
				assert_lte(level,1.701,"upstream pools cannot flood a high shelf over this downstream bank")
				if level-ground > 0.1:
					entered += 1
					break
	assert_eq(entered,3,"all three approaches reach shallow water without a drop")

func test_bank_and_water_agree_across_the_streamed_chunk_border() -> void:
	var a := _fields.region(Vector2i(-3,-2))
	var b := _fields.region(Vector2i(-3,-1))
	var wa := _fields.water(Vector2i(-3,-2))
	var wb := _fields.water(Vector2i(-3,-1))
	var wet_count := 0
	for x in range(-576,-383,3):
		var p := Vector2(x,-192)
		assert_almost_eq(TerrainSurfaceField.surface_y(a,p.x,p.y),
			TerrainSurfaceField.surface_y(b,p.x,p.y),0.000001)
		var la := wa.level_at(p)
		var lb := wb.level_at(p)
		assert_eq(is_finite(la),is_finite(lb),"wetness must agree at %s: %s / %s" % [p,la,lb])
		if is_finite(la) and is_finite(lb):
			wet_count += 1
			assert_almost_eq(la,lb,0.001)
	assert_gt(wet_count,5,"the seam crosses the actual river")
