extends GutTest

class CountingPlan extends HeightfieldPlan:
	var builds := 0
	func compute_rect_region(area: Rect2i) -> HeightfieldRegion:
		builds += 1
		return super.compute_rect_region(area)

func _plan() -> CountingPlan:
	var plan := CountingPlan.new(31,128,32,"mean",3)
	plan.set_raw_height_override(func(x: int,z: int) -> float:
		return 48.0 + sin(float(x)*.7)*14.0 + cos(float(z)*.8)*5.0)
	return plan

func _trace() -> RiverTrace:
	var trace := RiverTrace.new()
	trace.points = PackedVector2Array([Vector2(-48,0),Vector2(-24,0),Vector2.ZERO,Vector2(24,0),Vector2(48,0)])
	trace.beds = PackedFloat32Array([52,48,36,28,24])
	trace.widths = PackedFloat32Array([20,20,20,20,20])
	return trace

func test_complete_natural_region_is_reused_without_a_second_terrain_build() -> void:
	var plan := _plan()
	var region := plan.compute_region(0,0,12)
	var trace := _trace()
	plan.builds = 0
	var actual := WaterField.profile(trace,region)
	assert_eq(plan.builds,0,"Complete existing terrain already owns every profile sample")
	var oracle_plan := _plan()
	var oracle := WaterField.profile(_trace(),oracle_plan.compute_region(100,100,1))
	assert_eq(actual.levels,oracle.levels)
	assert_eq(var_to_bytes(actual.descents),var_to_bytes(oracle.descents))

func test_partial_or_graded_region_does_not_supply_profile_heights() -> void:
	var plan := _plan()
	var region := plan.compute_region(0,0,1)
	plan.builds = 0
	WaterField.profile(_trace(),region)
	assert_eq(plan.builds,1,"Partial coverage still resolves the complete canonical terrain")
	region = plan.compute_region(0,0,12)
	region.terrain_grades.append(TerrainGradePatch.new(&"test",{Vector2i.ZERO: 0.0},Vector2.ZERO,3.0))
	plan.builds = 0
	WaterField.profile(_trace(),region)
	assert_eq(plan.builds,1,"Town grading cannot enter a natural hydraulic profile")

func test_certified_sample_stencil_does_not_require_the_unused_trace_square() -> void:
	var plan := _plan()
	# Radius in 12 m terrain points: the centreline spans x -48..48 (points
	# -4..4) and WaterField._point_domain adds each tile's far corner plus a
	# two-point ring (-6..7), so 7 is the smallest square that certifies it.
	var region := plan.compute_region(0,0,7)
	plan.builds = 0
	var actual := WaterField.profile(_trace(),region)
	assert_eq(plan.builds,0,"The centreline and its two-point classifier stencil are already certified")
	var oracle_plan := _plan()
	var oracle := WaterField.profile(_trace(),oracle_plan.compute_region(100,100,1))
	assert_eq(actual.levels,oracle.levels)
	assert_eq(var_to_bytes(actual.descents),var_to_bytes(oracle.descents))
