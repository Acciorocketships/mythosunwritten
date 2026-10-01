extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_terrain_grade.gd")

func _gradient(sample: Callable, point: Vector2) -> float:
	const E := 0.01
	return Vector2((sample.call(point+Vector2.RIGHT*E)-sample.call(point-Vector2.RIGHT*E))/(2*E),
		(sample.call(point+Vector2.DOWN*E)-sample.call(point-Vector2.DOWN*E))/(2*E)).length()

func test_reported_eastern_approach_stays_below_player_climb_limit() -> void:
	var region := Frozen.region("res://docs/qa/2026-09-13-manual/17-village-grade/P11-field.txt")
	var sample := func(p: Vector2) -> float: return TerrainTileField.surface_y(region,p.x,p.y)
	var steepest := 0.0
	for z in range(21):
		for x in range(17):
			steepest = maxf(steepest,_gradient(sample,Vector2(978.5+x*.25,-378+z*.25)))
	assert_lt(steepest,0.95,"the photographed gentle approach must remain below the player's 45 degree floor limit, with margin")

func test_overlapping_pad_collars_do_not_multiply_a_single_storey_slope() -> void:
	var claims: Dictionary = {}
	for z in range(-4,5):
		for x in range(-4,5):
			if absi(x)<=1 or absi(z)<=1: claims[Vector2i(x,z)]=4.0
	var patch := TerrainGradePatch.new(&"cross",claims,Vector2.ZERO,3.0)
	var sample := func(p: Vector2) -> float: return patch.surface_y(p,0)
	var steepest := 0.0
	for z in range(1,70):
		for x in range(1,70): steepest=maxf(steepest,_gradient(sample,Vector2(x,z)*.4))
	assert_lte(steepest,4.0*1.875/TerrainGradePatch.TRANSITION_WIDTH+.001,
		"overlapping reservations must blend distance before applying the common slope profile once")
	for cell: Vector2i in claims: assert_eq(sample.call(Vector2(cell)*3),4.0)

func test_finite_collar_extent_and_bounds_cover_blended_corners() -> void:
	var claims: Dictionary = {}
	for x in range(-3,4):
		claims[Vector2i(x,0)]=4.0
		claims[Vector2i(0,x)]=4.0
	for quarter in 4:
		var rotated: Dictionary = {}
		for cell: Vector2i in claims:
			var point:=Vector2(cell).rotated(quarter*PI/2)
			rotated[Vector2i(roundi(point.x),roundi(point.y))]=claims[cell]
		var patch:=TerrainGradePatch.new(&"extent",rotated,Vector2.ZERO,3.0)
		var largest_error:=0.0
		var outside_error:=0.0
		for z in range(-30,31,2):
			for x in range(-30,31,2):
				var area:=Rect2(Vector2(x,z),Vector2(1.5,1.5))
				var interval:=patch.height_bounds(area,Vector2.ZERO)
				for offset: Vector2 in [Vector2.ZERO,Vector2(.3,.8),Vector2(1.5,1.5)]:
					var point:=area.position+offset
					var height:=patch.surface_y(point,0)
					largest_error=maxf(largest_error,maxf(interval.x-height,height-interval.y))
					if not patch.bounds.has_point(point): outside_error=maxf(outside_error,absf(height))
		assert_lt(largest_error,.00001,"complete interpolation and its extended corners stay inside declared bounds")
		assert_eq(outside_error,0.0,"the broader smooth union still has a finite natural boundary")
