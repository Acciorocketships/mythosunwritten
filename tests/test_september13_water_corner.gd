extends GutTest
static var _fields:WorldFieldBlockCache
func fields()->WorldFieldBlockCache:
	if _fields==null:
		var water:=TerrainWorldTuning.make_water(2697992464)
		_fields=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	return _fields

func test_photographed_bank_keeps_connected_water_above_its_lower_reach()->void:
	var field:=fields().water_at(Vector2(1106,35.625))
	var lower:=field.level_at(Vector2(1103,35.625))
	var worst:=INF
	var previous:=lower
	var jump:=0.0
	for i in 601:
		var p:=Vector2(1103+i*.01,35.625)
		var level:=field.level_at(p)
		assert_true(is_finite(level),"the whole photographed bank is wet")
		worst=minf(worst,level)
		jump=maxf(jump,absf(level-previous))
		previous=level
	assert_gte(worst,lower-.001,"the connected upper water cannot form a pit below the lower reach beside a high dry bank")
	assert_lte(jump,.01,"coarse/fine ownership cannot insert a step into the same water body")

func test_photographed_swimming_surface_matches_the_visible_corner()->void:
	var field:=fields().water_at(Vector2(1106,35.625))
	var sampler:=WaterSampler.build(field.raw_context(),field._region,Vector2(1101,30),1,10,7)
	var worst:=0.0
	for z in 11:
		for x in 81:
			var p:=Vector2(1101+x*.1,30+z*.5)
			if not field.is_wet(p):continue
			worst=maxf(worst,absf(sampler.level_at(p)-field.level_at(p)))
	assert_lte(worst,.001,"the frozen swimming surface must agree with visible water at the reported bank")
