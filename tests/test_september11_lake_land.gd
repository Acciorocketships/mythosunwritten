extends GutTest

func test_a_river_and_its_receiving_lake_share_the_reserved_island() -> void:
	var water:=preload("res://tests/fixtures/september11/landforms/AlluvialFixture.gd").new()
	water.trace.pond.radius=140
	water.trace.pond.island_radius=24
	water.trace.pond.island_offset=Vector2(0,72)
	var center:=water.trace.pond.center+water.trace.pond.island_offset
	var plan:=water.heightfield()
	# raw_height is keyed by 12 m terrain points (HeightfieldPlan.POINT).
	var cell:=Vector2i((center/HeightfieldPlan.POINT).round())
	assert_gte(plan.raw_height(cell.x,cell.y),4.0,"A broad river cannot excavate its own lake's reserved dry land")
	var fields:=WorldFieldBlockCache.new(plan,water,26,0)
	assert_false(fields.water_at(center).is_wet(center),"The reserved lake island must remain physically dry")
	var inlet:=water.trace.points[-1]
	assert_true(fields.water_at(inlet).is_wet(inlet),"Island ownership must retain the river's wet inlet")


func test_fitted_lake_land_keeps_its_inlet_and_water_rim_open() -> void:
	var water:=preload("res://tests/fixtures/september11/landforms/AlluvialFixture.gd").new()
	var pond:=water.trace.pond
	pond.radius=140
	pond.island_radius=24
	pond.island_offset=Vector2(0,72)
	water._fit_terminal_land(water.trace)
	assert_gt(pond.island_radius,0.0)
	var center:=pond.center+pond.island_offset
	for i in 24:
		var p:=center+Vector2.from_angle(TAU*float(i)/24)*(pond.island_radius*1.25+12)
		assert_lte(pond.footprint_t(p),.95)
	assert_gt(center.distance_to(water.trace.points[-1]),pond.island_radius*1.25+WaterPlan.W_MIN+6)
