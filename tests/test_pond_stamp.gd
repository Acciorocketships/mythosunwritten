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
