extends GutTest

func test_optional_narrow_peaks_do_not_roll_five_storey_shafts():
	for seed_value in [8,9]:
		var plan := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"grand"),&"",false)
		assert_not_null(plan)
		if plan == null:continue
		var peaks := 0
		for p:Dictionary in WarrenPlotPlanner.outcomes(plan).buildings:
			if not p.get("skyline_peak",false):continue
			peaks += 1
			assert_lte(int(p.top)-int(p.floor),10,"A narrow optional peak uses at most four room storeys plus roof reservation")
		assert_gt(peaks,0,"Keep skyline variation instead of dropping every peak")

func test_required_upper_floor_overrides_optional_peak_body_budget():
	var columns := {}
	for x in range(-6,7):
		for z in range(-6,7):columns[Vector2i(x,z)]={"base":0,"top":14}
	var plan := WarrenMazeSourcePlan.new(8,WarrenVillageScaleProfile.for_id(&"grand"),WarrenMassif.with_columns(8,columns,14),WarrenExcavation.new(8))
	var cells:Array[Vector2i]=[Vector2i.ZERO]
	var building := {"floor":0,"seed":Vector2i.ZERO,"door":Vector3i.ZERO,"cells":cells}
	var street := WarrenPlotPlanner._building_top(plan,{Vector2i.ZERO:[12]}, {},building,true)
	assert_eq(street.top,12)
	assert_true(street.tiered)
	var upper := WarrenPlotPlanner._building_top(plan,{}, {Vector2i.ZERO:[12]},building,true)
	assert_eq(upper.top,12)
