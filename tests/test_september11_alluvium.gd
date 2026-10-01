extends GutTest

class FlatWetPlan extends WaterPlan:
	func noise_h(_point: Vector2) -> float: return 12.0
	func _alluvial_wetness(_point: Vector2) -> float: return 1.0

static func straight_trace() -> RiverTrace:
	var trace := RiverTrace.new()
	trace.source_cell = Vector2i(1,1)
	for i in 61:
		trace.points.append(Vector2(1008+i*12,1008))
		trace.beds.append(2.5)
		trace.widths.append(22.0)
	return trace

func test_wet_gentle_reaches_retain_bars_between_connected_channels() -> void:
	var water := FlatWetPlan.new(17,128,32)
	var trace := straight_trace()
	water._shape_alluvial_reach(trace)
	assert_gt(trace.land_bars.size(),0,"Lowland rivers need retained ground between their branches")
	assert_gt(trace.widths[-1],60.0,"A terminal fan must open beyond the ordinary narrow channel")

func test_retained_islands_and_both_branches_use_actual_ground_and_water() -> void:
	var water := preload("res://tests/fixtures/september11/landforms/AlluvialFixture.gd").new()
	var plan := water.heightfield()
	var fields := WorldFieldBlockCache.new(plan,water,0,0)
	for bar: Dictionary in water.trace.land_bars:
		var center: Vector2=bar.center
		var region:=fields.region_at(center)
		assert_almost_eq(TerrainTileField.surface_y(region,center.x,center.y),8.0,.01)
		assert_false(fields.water_at(center).is_wet(center),"Retained ground is a physical island")
		for point: Vector2 in [Vector2(center.x,1008),Vector2(center.x,1008+(108 if center.y>1008 else -108))]:
			assert_true(fields.water_at(point).is_wet(point),"Both sides of the island carry connected water")
			assert_gt(fields.water_at(point).level_at(point)-TerrainTileField.surface_y(fields.region_at(point),point.x,point.y),.2)

func test_wide_reach_claims_cover_outer_branches_without_a_ground_context() -> void:
	var water := preload("res://tests/fixtures/september11/landforms/AlluvialFixture.gd").new()
	var point := Vector2(1296,1092)
	var context := WaterField.ctx(water,Vector2i((point/192).floor()))
	assert_gt(WaterField.level_at(context,point),-INF,"Outer branch must remain in the river index")
	assert_false(WaterField._claim(context,point).is_empty(),"Flow and water membership use the same complete width")

func test_alluvial_bars_have_low_broad_crests_instead_of_retained_high_bank_pillars() -> void:
	var water:=preload("res://tests/fixtures/september11/landforms/AlluvialFixture.gd").new()
	var plan:=water.heightfield()
	for bar:Dictionary in water.trace.land_bars:
		var center:Vector2=bar.center
		assert_gte(float(bar.half_width),36.0,"A bar spans several terrain samples across its width")
		# raw_height is keyed by 12 m terrain points (HeightfieldPlan.POINT).
		var point:=Vector2i((center/HeightfieldPlan.POINT).round())
		assert_lte(plan.raw_height(point.x,point.y),8.0,"Deposition must not retain a tall bank pillar")
