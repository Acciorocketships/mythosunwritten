extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_terrain_grade.gd")

func test_reported_bank_has_one_shared_surface_across_its_old_cliff() -> void:
	var region := Frozen.region("res://docs/qa/2026-09-13-manual/17-village-grade/P24-field.txt")
	var largest := 0.0
	for x in range(-284,-276):
		var north:=TerrainSurfaceField.surface_y_in_cell(region,x,444,-12,18)
		var south:=TerrainSurfaceField.surface_y_in_cell(region,x,444,-12,19)
		largest=maxf(largest,absf(north-south))
	assert_lt(largest,.0001,"the two graded owners must join; residual natural steps form the photographed stone fins")

func test_natural_cliffs_outside_the_construction_remain_vertical() -> void:
	var region := Frozen.region("res://docs/qa/2026-09-13-manual/17-village-grade/P24-field.txt")
	var natural:=region.without_terrain_grades()
	var samples:=0
	for z in range(14,23):
		for x in range(-15,-8):
			var p:=Vector2(x*24+12,z*24)
			if region.has_grade_effect_in(Rect2(p-Vector2.ONE,Vector2.ONE*2)): continue
			for owner:Vector2i in [Vector2i(x,z),Vector2i(x+1,z)]:
				assert_eq(TerrainSurfaceField.surface_y_in_cell(region,p.x,p.y,owner.x,owner.y),
					TerrainSurfaceField.surface_y_in_cell(natural,p.x,p.y,owner.x,owner.y))
				samples+=1
	assert_gt(samples,30)
