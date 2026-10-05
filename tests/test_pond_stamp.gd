extends GutTest

# ------------------------------------------------------------
# PondStamp — wobbly bowl with a storey-aligned water level
# ------------------------------------------------------------

func _stamp() -> PondStamp:
	return PondStamp.new(Vector2(100.0, -50.0), 60.0, 12345, 3, 3.5)

func test_surface_and_bed_derive_from_level() -> void:
	var p: PondStamp = _stamp()
	assert_almost_eq(p.surface_y(), 3.0 * 4.0 - PondStamp.SURFACE_DROP, 0.0001,
		"surface = level*storey - drop")
	assert_almost_eq(p.bed_y(), 3.0 * 4.0 - 3.5, 0.0001, "bed = level*storey - depth")

func test_footprint_wobbles_but_stays_bounded() -> void:
	var p: PondStamp = _stamp()
	for k in 16:
		var r: float = p.radius_at(TAU * float(k) / 16.0)
		assert_true(r >= 60.0 * (1.0 - PondStamp.WOBBLE) - 0.001, "wobble lower bound")
		assert_true(r <= p.bound_radius() + 0.001, "wobble upper bound")

func test_carve_full_in_core_zero_outside() -> void:
	var p: PondStamp = _stamp()
	var ground: float = 14.0
	var core: float = p.carve_at(p.center, ground)
	assert_almost_eq(core, ground - p.bed_y(), 0.0001, "center carves to the bed")
	var outside: Vector2 = p.center + Vector2(p.bound_radius() + 1.0, 0.0)
	assert_eq(p.carve_at(outside, ground), 0.0, "no carve outside the footprint")

func test_carve_never_raises_ground() -> void:
	var p: PondStamp = _stamp()
	assert_eq(p.carve_at(p.center, p.bed_y() - 2.0), 0.0,
		"ground already below bed => carve 0 (only ever lowers)")

func test_footprint_deterministic_per_shape_seed() -> void:
	var a: PondStamp = _stamp()
	var b: PondStamp = _stamp()
	assert_eq(a.radius_at(1.0), b.radius_at(1.0), "same seed => same wobble")

## October 4 (amplified relief): a terminal lake's bowl lowered everything in
## its footprint to its bed, so a lake beside a mountain quarried a 59 m notch
## into the flank (seed 2697992464, x -1356..-1320, z -780). A lake fills its
## hollow: ground more than three storeys above its banks keeps its height,
## and the carve fades out continuously between one and three storeys above.
func test_carve_stops_where_the_ground_rises_far_above_the_banks() -> void:
	var p: PondStamp = _stamp()
	var bank := 3.0 * 4.0
	assert_eq(p.carve_at(p.center, bank + 40.0), 0.0, "a mountainside in the footprint keeps its ground")
	assert_almost_eq(p.carve_at(p.center, bank + 4.0), bank + 4.0 - p.bed_y(), 0.0001,
		"a storey above the banks still carves to the bed")
	var previous := -INF
	for k in 401:
		var ground := bank + k * 0.05
		var carved := ground - p.carve_at(p.center, ground)
		assert_gt(carved, previous - 0.0001, "the carved surface rises with the ground (%.2f m)" % ground)
		previous = carved
