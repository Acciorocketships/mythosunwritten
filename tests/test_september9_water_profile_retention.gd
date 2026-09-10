extends GutTest

class ObservedPlan extends HeightfieldPlan:
	var built_regions:Array[WeakRef]=[]
	func compute_region(x:int,z:int,r:int)->HeightfieldRegion:
		var region:=super.compute_region(x,z,r)
		built_regions.append(weakref(region))
		return region

func test_completed_profile_keeps_its_values_without_retaining_construction_terrain()->void:
	var plan:=ObservedPlan.new(2697992464)
	plan.set_raw_height_override(func(_x:int,_z:int)->float:return 0)
	var caller:=plan.compute_region(0,0,1)
	var trace:=RiverTrace.new()
	trace.source_cell=Vector2i(491,493)
	trace.points=PackedVector2Array([Vector2.ZERO,Vector2(24,0),Vector2(48,0)])
	trace.beds=PackedFloat32Array([12,10,4])
	trace.widths=PackedFloat32Array([20,20,20])
	var first:=WaterField.profile(trace,caller)
	assert_eq(plan.built_regions.size(),2,"a real descent constructs its canonical terrain")
	assert_null(plan.built_regions[1].get_ref(),"finished hydraulic arrays must release their large construction region")
	assert_eq(WaterField.profile(trace,caller),first,"the compact finished profile remains warm")
	assert_eq(plan.built_regions.size(),2,"reusing a profile must not rebuild released terrain")

func test_long_travel_bounds_profiles_and_recomputes_evicted_values_exactly()->void:
	WaterField._profiles.clear()
	var first:RiverTrace
	var expected:Dictionary
	for i in 1100:
		var trace:=RiverTrace.new()
		trace.source_cell=Vector2i(i,1847)
		trace.points=PackedVector2Array([Vector2(i*24,0),Vector2(i*24+12,0)])
		trace.beds=PackedFloat32Array([12,4])
		trace.widths=PackedFloat32Array([8,9])
		var result:=WaterField.profile(trace)
		if i==0:
			first=trace
			expected=result.duplicate(true)
	assert_lte(WaterField._profiles.size(),1024,"an endless sequence of river owners must not grow profiles without bound")
	var key:=[first.get_instance_id(),0,false]
	assert_false(WaterField._profiles.has(key),"old unused profiles are evicted individually")
	assert_eq(WaterField.profile(first),expected,"eviction changes cost, not hydraulic output")
