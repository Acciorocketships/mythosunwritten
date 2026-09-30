extends GutTest

const REFERENCE := preload("res://tests/fixtures/september9_dictionary_region.gd")

func test_complete_region_arrays_match_original_including_margins() -> void:
	for config in [[1,"mean",8], [3,"min",8], [2,"max",12]]:
		var plan := HeightfieldPlan.new(2697992464,48,config[2],config[1],config[0])
		plan.set_raw_height_override(func(x: int,z: int)->float:
			return float(posmod(x*17+z*31,57)) if posmod(x+z,5)!=0 else 0.0)
		for centre: Vector2i in [Vector2i(12,-56),Vector2i(-32,32)]:
			var reference := REFERENCE.compute_region(plan,centre.x,centre.y,12)
			var actual := plan.compute_region(centre.x,centre.y,12)
			assert_eq(actual._storeys,reference._storeys,"all storeys, including finite outer margin")
			assert_eq(actual._levels,reference._levels,"all terraces, including masked clamp boundaries")
			assert_eq(actual._carved,reference._carved)

class Carve:
	extends RefCounted
	func carve_at(x:float,z:float)->float:
		var i:=roundi(x/HeightfieldPlan.POINT)
		var j:=roundi(z/HeightfieldPlan.POINT)
		return 8.25 if posmod(i*3-j,11)<2 else 0.0

func test_carve_provenance_and_real_seed_keep_complete_original_arrays() -> void:
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	plan.set_water_plan(Carve.new())
	var reference := REFERENCE.compute_region(plan,12,-56,8)
	var actual := plan.compute_region(12,-56,8)
	assert_eq(actual._storeys,reference._storeys)
	assert_eq(actual._levels,reference._levels)
	assert_eq(actual._carved,reference._carved)
	assert_gt(actual._carved.size(),0)
