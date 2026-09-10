extends GutTest

func test_grade_sample_cache_preserves_cold_values_and_natural_input() -> void:
	var source := TerrainGradePatch.new(&"cache",{Vector2i.ZERO:11.0},Vector2.ZERO,3.0)
	var points: Array[Vector2] = [Vector2(1.234,0.567),Vector2(7.123,2.345),Vector2(12.456,4.567)]
	for point: Vector2 in points:
		for natural in [7.123456789,8.234567891]:
			source._surface_cache.clear()
			var cold := source.surface_y(point,natural)
			assert_eq(source.surface_y(point,natural),cold,"memoization cannot quantize a field sample")
			var other := source.surface_y(point,natural+1)
			source._surface_cache.clear()
			assert_eq(source.surface_y(point,natural+1),other,"the cache never captures the first caller's natural ground")

func test_street_extension_preserves_one_normal_terrain_slope() -> void:
	for turn in 4:
		var axis := Vector2.RIGHT.rotated(turn*PI*0.5)
		var source := TerrainGradePatch.new(&"street-slope",{Vector2i.ZERO:11.0},Vector2.ZERO,3.0)
		var streets: Array[Dictionary] = [{"points":[Vector2.ZERO,axis*27.0] as Array[Vector2]}]
		var grade := VillageOutskirtsConstruction._extend_street_grade(source,streets,8.0)
		for step in range(1,109):
			var point := axis*step*0.25
			var expected := lerpf(11.0,8.0,TerrainSurfaceField.transition_weight(maxf(0,point.length()-1.5)))
			assert_almost_eq(grade.surface_y(point,8.0),expected,0.00002,"a reserved street must not re-sample the 12 m terrain curve into 3 m plateaus")
		assert_eq(source._claims.size(),1,"extending the street does not mutate its source")

func test_foundation_extension_and_second_street_keep_the_inherited_curve_and_bounds() -> void:
	var source := TerrainGradePatch.new(&"composed-slope",{Vector2i.ZERO:11.0},Vector2.ZERO,3.0)
	var streets: Array[Dictionary] = [{"points":[Vector2.ZERO,Vector2(27,0)] as Array[Vector2]}]
	var first := VillageOutskirtsConstruction._extend_street_grade(source,streets,8.0)
	var pads := first._claims.duplicate()
	for z in range(4,8):
		for x in range(6,10): pads[Vector2i(x,z)] = 8.0
	var grade := VillageOutskirtsConstruction._extend_street_grade(first.with_fixed_extension(pads),streets,8.0)
	for step in range(1,109):
		var p := Vector2(step*0.25,0)
		assert_almost_eq(grade.surface_y(p,8.0),source.surface_y(p,8.0),0.00002,"later pads and access paths preserve the continuous street")
	for z in range(-5,9):
		for x in range(-3,12):
			var area := Rect2(Vector2(x,z)*3+Vector2(0.17,0.29),Vector2(2.1,2.6))
			var bounds := grade.height_bounds(area,Vector2(7,9))
			for iz in 4:
				for ix in 4:
					var p := area.position+area.size*Vector2(ix,iz)/3
					for natural in [7.0,9.0]:
						var h := grade.surface_y(p,natural)
						assert_between(h,bounds.x-0.00001,bounds.y+0.00001,"composed grading extrema enclose the emitted ground")
