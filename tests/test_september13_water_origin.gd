extends GutTest

func test_origin_water_has_one_answer_across_four_chunk_owners()->void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	var contexts:Array[WaterFieldContext]=[]
	for chunk:Vector2i in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,0)]:contexts.append(fields.water(chunk))
	for point:Vector2 in [Vector2(-.01,-.01),Vector2(.01,-.01),Vector2(.01,.01),Vector2(-.01,.01),Vector2(6.5,-7.4)]:
		var expected:=contexts[0].level_at(point)
		for i in range(1,contexts.size()):
			var actual:=contexts[i].level_at(point)
			assert_eq(is_finite(actual),is_finite(expected),"water existence at %s must not depend on the requesting chunk"%point)
			if is_finite(actual) and is_finite(expected):assert_almost_eq(actual,expected,.001,"one physical surface at the same world position")
	# The photographed field is beyond a dry sill and has no physical source.
	# Agreement alone is insufficient: flooding all four owners would hide
	# the seam while retaining the unsupported pool.
	for z in range(-24,25,6):
		for x in range(-24,25,6):
			for context: WaterFieldContext in contexts:
				assert_false(context.is_wet(Vector2(x,z)),"the source-free spawn field remains dry at "+str(Vector2(x,z)))
