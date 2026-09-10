extends GutTest

class CountedPlan extends HeightfieldPlan:
	var region_calls := 0
	func compute_region(x:int,z:int,r:int)->HeightfieldRegion:
		region_calls+=1
		return super.compute_region(x,z,r)

class CountedGround extends RefCounted:
	var reads := 0
	func storey_at(_x:int,_z:int)->int:
		reads+=1
		return 0
	func level_at(_x:int,_z:int)->int: return 0
	func surface_height(_x:int,_z:int)->float: return 0

func test_equal_river_targets_do_not_sample_ground() -> void:
	var ground := CountedGround.new()
	assert_eq(WaterField._descend_segment(ground,Vector2.ZERO,Vector2(2400,0),5.5,5.5),5.5)
	assert_eq(ground.reads,0,"the min-held envelope cannot change a constant target")

func test_flat_trace_does_not_build_a_kilometre_terrain_region() -> void:
	var plan := CountedPlan.new(1)
	plan.set_raw_height_override(func(_x:int,_z:int)->float:return 0)
	var region := plan.compute_region(0,0,1)
	plan.region_calls=0
	var trace := RiverTrace.new()
	trace.source_cell=Vector2i(700,701)
	trace.points=PackedVector2Array([Vector2.ZERO,Vector2(1200,0),Vector2(2400,0)])
	trace.beds=PackedFloat32Array([4,4,4])
	trace.widths=PackedFloat32Array([20,20,20])
	var result := WaterField.profile(trace,region)
	var level := 4+WaterField.SURFACE_RIDE
	assert_eq(result.levels,PackedFloat32Array([level,level,level]))
	assert_eq(plan.region_calls,0,"a constant river profile needs no terrain shaping")

func test_steep_terminal_pond_still_requests_canonical_ground() -> void:
	var plan := CountedPlan.new(1)
	plan.set_raw_height_override(func(_x:int,_z:int)->float:return 0)
	var region := plan.compute_region(0,0,1)
	plan.region_calls=0
	var trace := RiverTrace.new()
	trace.source_cell=Vector2i(702,703)
	trace.points=PackedVector2Array([Vector2.ZERO,Vector2(24,0)])
	trace.beds=PackedFloat32Array([12,12])
	trace.widths=PackedFloat32Array([20,20])
	trace.pond=PondStamp.new(Vector2(24,0),26,2,1,3)
	var result := WaterField.profile(trace,region)
	assert_eq(plan.region_calls,1,"a real terminal drop still shapes against canonical terrain")
	assert_lt(result.levels[1],result.levels[0])
