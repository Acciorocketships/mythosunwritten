extends GutTest
func test_reported_high_river_ends_at_the_lower_channel_before_the_false_bank_source()->void:
 var water:=TerrainWorldTuning.make_water(2697992464)
 var incoming:=water.river_for(Vector2i(-2,-1))
 var receiver:=water.river_for(Vector2i(-3,-4))
 assert_gt(incoming.priority,receiver.priority,"The photographed lower receiver loses the old hash comparison")
 assert_true(incoming.joined,"The incoming river must join receiving water")
 assert_lt(incoming.points.size(),50,"Do not continue a high supply beyond the first lower-channel crossing")
