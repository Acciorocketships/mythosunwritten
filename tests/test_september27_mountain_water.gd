extends GutTest
## September 27 owner report (seed 2697992464, player (468.6,35.9,872.1),
## crosshair (472.1,34.3,878.4)): water emerged from a mountainside and lay
## in separate sheets on stepped treads instead of flowing over the ledges.
## See docs/qa/2026-09-27-mountain-water/result.md.
const SEED := 2697992464
const FIELD := preload("res://scripts/terrain/field/CliffSlopeField.gd")

## A walk that never gets beyond its free first loop (SUMMIT_REACH) was boxed
## in round a narrow peak after ~11 steps; its terminal lake sat on the flank,
## spilled far below the summit and dug a stepped crater. Four of the 55
## sources in this 81-district window did so.
func test_every_river_leaves_its_summit() -> void:
	var water := TerrainWorldTuning.make_water(SEED)
	var stuck: Array = []
	for z in range(-4, 5):
		for x in range(-4, 5):
			var cell := Vector2i(x, z)
			if not water.has_source(cell): continue
			var trace := water.river_for(cell, 0)
			assert_not_null(trace, "a firing source always yields its river")
			if trace != null and trace.points[-1].distance_to(trace.points[0]) <= WaterPlan.SUMMIT_REACH:
				stuck.append([cell, trace.points.size()])
	assert_eq(stuck, [], "no river may end before it reaches a real terminus")


## The reported mountain: its summit spring (super-cell (0,1)) looped round a
## 20 m circle and ended in a lake 79 m below the flank, excavating the
## 12 m staircase the owner photographed. The mountain now keeps its ground.
func test_reported_mountain_is_not_excavated_by_a_flank_lake() -> void:
	var water := TerrainWorldTuning.make_water(SEED)
	assert_false(water.has_source(Vector2i(0, 1)), "the looping summit spring feeds no river")
	var plan := TerrainWorldTuning.make_heightfield(SEED, water)
	var carved := 0
	# x 408..528, z 816..936 (12 m terrain points 34..44 x 68..78); the next
	# 24 m column east lies in the bank feather of the real river (0,0) and is
	# legitimately graded by up to 3.8 m.
	for cz in range(68, 79):
		for cx in range(34, 45):
			if plan.raw_height(cx, cz) < plan.uncarved_height(cx, cz) - 0.01: carved += 1
	assert_eq(carved, 0, "no water body excavates the reported mountainside")


class CascadeWater extends WaterFieldContext:
	## A 20 m channel crossing an 8 m ledge at x = 0: a sill-riding film on
	## the upper tread (0.1 m, the production DESCENT_CLAMP) descends over
	## the lip into a 2 m-deep receiving pool. Banks beyond |z| = 10 are dry.
	func has_sources() -> bool: return true
	func coverage() -> Rect2: return Rect2(-200, -200, 400, 400)
	func covers(_q: Vector2) -> bool: return true
	func level_at(q: Vector2) -> float:
		if absf(q.y) >= 10.0: return NAN
		return 8.1 if q.x < 0.0 else maxf(8.1 - 0.6 * q.x, 2.0)


static func cascade_ground(q: Vector2) -> float:
	if absf(q.y) >= 10.0: return 12.0
	return 8.0 if q.x < 0.0 else 0.0


## The slope envelope treated the shallow sill film as dry bank and dilated a
## rounded shoulder from it over the falling water, burying the cascade.
func test_rounded_slope_does_not_bury_water_falling_over_a_ledge() -> void:
	var style = load("res://scripts/terrain/field/CliffRockStyle.gd")
	style.apply("sheet_bedrock")
	var field = FIELD.new([], SEED, null, Rect2(-30, -30, 60, 60), null, CascadeWater.new())
	field.ground_at = cascade_ground
	var env = field.envelope()
	var water := CascadeWater.new()
	var buried := []
	# The dry 12 m side banks legitimately run out ~8 m into this 20 m channel.
	for x in range(1, 24):
		for z in [-1, 0, 1]:
			var q := Vector2(x, z)
			if env.sample(q) > water.level_at(q) + 0.05:
				buried.append([q, snappedf(env.sample(q), .01), water.level_at(q)])
	assert_eq(buried, [], "falling water stays visible over the ledge and in its pool")
	assert_almost_eq(env.at(Vector2(-6, 0)), 8.0, 0.01, "a film cannot cut its own crest")
	style.apply("current")
