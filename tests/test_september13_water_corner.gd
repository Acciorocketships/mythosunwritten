extends GutTest
static var _fields:WorldFieldBlockCache
func fields()->WorldFieldBlockCache:
	if _fields==null:
		var water:=TerrainWorldTuning.make_water(2697992464)
		_fields=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(2697992464,water),water,26,0,64)
	return _fields

## Re-pinned (dual-grid terrain, 2026-09-30): the 12 m tiles moved the
## photographed bank at x 1103..1109, z 35.625 (that line is no longer wet).
## tests/harness/september13_water_corner_scan.gd scans chunks (4..6,-1..1) of
## the production seed for the same shape: a 6 m +x line wet at every 0.25 m
## sample, its far end >= 0.3 m above its near (lower-reach) end, beside a high
## dry bank (a dry sample 3 m to the side of the far half standing above the
## far-end water). The nearest strong hit is x 1185..1191, z 18.625: rise
## 0.78 m, dry bank ground 15.77 m at (1190,21.625) over 15.0 m water.
func test_photographed_bank_keeps_connected_water_above_its_lower_reach()->void:
	_assert_connected_rising_line(Vector2(1185,18.625))

## Regression (dual-grid water, 2026-10-01): the same scan over chunks
## (4..6,-1..1) also hits x 1191.75..1197.75, z 183.625. Its 3 m rescue cells
## have their far edge on the wall line z = 186 (12 i + 6), where a cliff dies
## into a slope at x = 1194 (E2: wall from the tile centre on, a steep ramp
## before it). The shore-support probe on that edge read the ramp's midline
## (12.0) for x < 1194 and the wall top (14.0) from x = 1194: the correction
## jumped and so did the water (0.083 m at x = 1194).
func test_rescued_bank_beside_a_dying_wall_has_no_step()->void:
	_assert_connected_rising_line(Vector2(1191.75,183.625))

func _assert_connected_rising_line(start:Vector2)->void:
	var field:=fields().water_at(start+Vector2(3,0))
	var lower:=field.level_at(start)
	var worst:=INF
	var previous:=lower
	var jump:=0.0
	for i in 601:
		var p:=start+Vector2(i*.01,0)
		var level:=field.level_at(p)
		assert_true(is_finite(level),"the whole photographed bank is wet")
		worst=minf(worst,level)
		jump=maxf(jump,absf(level-previous))
		previous=level
	assert_gte(worst,lower-.001,"the connected upper water cannot form a pit below the lower reach beside a high dry bank")
	assert_lte(jump,.01,"coarse/fine ownership cannot insert a step into the same water body")

## Same re-pinned corner as above: the window spans the rising reach and its
## dry bank (x 1183..1191, z 16..21).
func test_photographed_swimming_surface_matches_the_visible_corner()->void:
	var field:=fields().water_at(Vector2(1188,18.625))
	var sampler:=WaterSampler.build(field.raw_context(),field._region,Vector2(1183,16),1,10,7)
	var worst:=0.0
	for z in 11:
		for x in 81:
			var p:=Vector2(1183+x*.1,16+z*.5)
			if not field.is_wet(p):continue
			worst=maxf(worst,absf(sampler.level_at(p)-field.level_at(p)))
	assert_lte(worst,.001,"the frozen swimming surface must agree with visible water at the reported bank")
