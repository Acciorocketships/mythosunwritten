extends GutTest

func test_rectangular_region_matches_independent_certified_square_controls() -> void:
	var plan := HeightfieldPlan.new(39,128,32,"mean",3)
	plan.set_raw_height_override(func(x:int,z:int)->float: return 52+sin(x*.4)*28+cos(z*.6)*15)
	assert_true(plan.has_method("compute_rect_region"),"Narrow river corridors must not request a maximum-span square")
	if not plan.has_method("compute_rect_region"): return
	for area: Rect2i in [Rect2i(-8,-2,17,5),Rect2i(-2,-8,5,17),Rect2i(-6,-3,3,12),Rect2i(5,-7,1,1)]:
		var actual: HeightfieldRegion = plan.call("compute_rect_region",area)
		var errors:=0
		for z in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				var oracle:=plan.compute_region(x,z,0)
				if actual.surface_height(x,z)!=oracle.surface_height(x,z): errors+=1
		assert_eq(errors,0,"Every certified cell equals a separately padded square query")
		assert_eq(actual.certified_points,area)
