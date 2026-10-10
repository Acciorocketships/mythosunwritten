extends GutTest

class OneSite extends SettlementPlan:
	func site_for(cell: Vector2i) -> Dictionary:
		return {"id":&"hamlet.production","cell":Vector2i.ZERO} if cell==Vector2i.ZERO else {}

class UncachedVillagePlan extends VillagePlan:
	var fixture: VillageRecord
	var builds := 0
	func _build(_frame: VillageFrame) -> VillageRecord:
		builds += 1
		return fixture

func test_spread_town_keeps_its_far_grade_owner_discoverable() -> void:
	var feature_program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	var program := feature_program.villages
	var heights: Dictionary = {}
	for z in range(-24,25):
		for x in range(-24,25): heights[Vector2i(x,z)] = 0
	var region := HeightfieldRegion.new(heights,heights)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds":[],"rivers":[],"buckets":{},"region":region}
	water._region = region
	water._coverage = Rect2(-576,-576,1152,1152)
	var frame := VillageFrame.from_mask({"id":&"hamlet.production","cell":Vector2i.ZERO},
		0,region,water)
	var plan := VillagePlan.new(1,program)
	var record := plan.record_for(frame)
	assert_true(record.urban_fabric.accepted)
	assert_true(record.urban_fabric.validate(program,record.tier))
	assert_true(record.validate(program),"complete native record must fit its declared discovery contract")
	var water_plan := WaterPlan.new(1,1,1)
	var fields := WorldFieldBlockCache.new(HeightfieldPlan.new(1,32,8),water_plan,
		feature_program.query_margin,feature_program.shore_distance_limit,feature_program.field_cache_cap)
	var world := WorldFeaturePlan.new(1,water_plan,fields,feature_program,OneSite.new(1,water_plan))
	world._frames[Vector2i.ZERO] = frame
	world._villages._records[frame.settlement_id] = record
	# Exercise the actual finite control-owner fringe, with the record already
	# cached so a missing result proves a discovery-cull error, not generation.
	var edge := Rect2(Vector2(record.bounds.get_center().x,record.bounds.end.y-2.0),Vector2.ONE)
	assert_eq(world._records_affecting(edge),[record],"far control fringe must discover the same terrain owner")
	assert_eq(world._records_affecting(Rect2(edge.position+Vector2.DOWN*100,Vector2.ONE)),[],
		"the completed record still terminates its influence")

	var uncached := UncachedVillagePlan.new(1,program)
	uncached.fixture = record
	world._villages = uncached
	assert_eq(world._records_affecting(edge),[record],"uncached discovery reaches the canonical builder too")
	assert_eq(uncached.builds,1)
	world._records_affecting(edge)
	assert_eq(uncached.builds,1,"a repeated query reuses the canonical record")
	assert_lte(record.discovery_bound.size.x * 0.5,program.warren_discovery_radius)

func test_source_envelope_and_discovery_bounds_cover_the_size_distribution() -> void:
	var discovery := preload("res://scripts/terrain/features/villages/WarrenTownDiscovery.gd")
	var field_type := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")
	var asset_reach := 20.0
	var maximum := discovery.maximum_radius(asset_reach)
	for seed_value in range(1,33):
		assert_lte(discovery.radius_for_seed(seed_value,asset_reach),maximum)
		for id: StringName in WarrenVillageScaleProfile.IDS:
			var profile := WarrenVillageScaleProfile.for_id(id)
			var field := field_type.sample(seed_value,profile)
			var extent := field_type.maximum_sample_extent(profile.radius_cells)
			var within := true
			for cell: Vector2i in field.air:
				within = within and absi(cell.x)<=extent and absi(cell.y)<=extent
			assert_true(within,"sampled domain fits the bound derived from the same lobe limits")
