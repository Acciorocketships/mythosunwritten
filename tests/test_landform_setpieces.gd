extends GutTest

const SEED := 2697992464
const ST := 4.0

func _max_params(kind: StringName) -> Dictionary:
	var out := {}
	var spec: Dictionary = TerrainRegimeCatalog.SETPIECE_PARAMS[kind]
	for name: String in spec:
		out[name] = float(spec[name][1])
	return out

func test_footprints_fit_the_neighbourhood_and_shapes_vanish_at_the_edge() -> void:
	for kind: StringName in TerrainRegimeCatalog.SETPIECE_PARAMS:
		var q := _max_params(kind)
		var r := LandformSetpieces.footprint_radius(kind, q)
		assert_lte(r, LandformSetpieces.MAX_RADIUS, String(kind))
		for i in 16:
			var edge := Vector2.from_angle(i * TAU / 16.0) * r
			var v := LandformSetpieces.shape(kind, q, edge, 0.3)
			assert_almost_eq(v.x, 0.0, 1e-4, "%s delta at edge" % kind)
			assert_almost_eq(v.y, 0.0, 1e-4, "%s mask at edge" % kind)

func test_shapes_have_their_silhouettes() -> void:
	var e := {"length_m": 600.0, "rise_st": 3.0, "face_m": 20.0, "back_m": 160.0}
	assert_gt(LandformSetpieces.shape(&"escarpment", e, Vector2(0, 40), 0.0).x
		- LandformSetpieces.shape(&"escarpment", e, Vector2(0, -40), 0.0).x, 3.0 * ST * 0.8, "escarpment step")
	var m := {"radius_m": 120.0, "height_st": 4.0, "face_m": 16.0}
	assert_almost_eq(LandformSetpieces.shape(&"mesa", m, Vector2.ZERO, 0.0).x,
		LandformSetpieces.shape(&"mesa", m, Vector2(60, 0), 0.0).x, 1e-4, "flat mesa crown")
	var g := {"length_m": 700.0, "height_st": 4.0, "half_width_m": 60.0, "pass_frac": 0.6}
	assert_gt(LandformSetpieces.shape(&"big_ridge", g, Vector2(200, 0), 0.0).x,
		LandformSetpieces.shape(&"big_ridge", g, Vector2.ZERO, 0.0).x + 4.0, "pass in the ridge")
	var c := {"length_m": 400.0, "slot_m": 30.0, "shoulder_st": 3.0, "shoulder_m": 80.0}
	assert_gt(LandformSetpieces.shape(&"cleft", c, Vector2(0, 50), 0.0).x
		- LandformSetpieces.shape(&"cleft", c, Vector2(0, 0), 0.0).x, 3.0 * ST * 0.8, "cleft walls")
	var h := {"length_m": 600.0, "trunk_half_m": 60.0, "trunk_st": 4.0, "trib_half_m": 20.0, "lip_st": 2.0}
	assert_gt(LandformSetpieces.shape(&"hanging_valley", h, Vector2(0, 150), 0.0).x
		- LandformSetpieces.shape(&"hanging_valley", h, Vector2(0, 0), 0.0).x, 2.0 * ST * 0.8, "lip above trunk floor")
	var a := {"radius_m": 160.0, "wall_st": 3.0}
	assert_gt(LandformSetpieces.shape(&"amphitheatre", a, Vector2(-160, 0), 0.0).x,
		LandformSetpieces.shape(&"amphitheatre", a, Vector2.ZERO, 0.0).x + 8.0, "back wall")
	assert_gt(LandformSetpieces.shape(&"amphitheatre", a, Vector2(-160, 0), 0.0).x,
		LandformSetpieces.shape(&"amphitheatre", a, Vector2(160, 0), 0.0).x + 6.0, "open mouth")

func test_admitted_footprints_never_overlap_and_are_order_independent() -> void:
	var cells: Array[Vector2i] = []
	for z in range(-8, 9):
		for x in range(-8, 9):
			cells.append(Vector2i(x, z))
	var forward := []
	for c in cells:
		forward.append(LandformSetpieces.admitted(SEED, c))
	LandformSetpieces.clear_caches()
	var backward := []
	for i in range(cells.size() - 1, -1, -1):
		backward.push_front(LandformSetpieces.admitted(SEED, cells[i]))
	assert_eq(forward, backward)
	var live := forward.filter(func(a): return not a.is_empty())
	assert_gt(live.size(), 3, "some set pieces exist")
	for i in live.size():
		for j in range(i + 1, live.size()):
			assert_gt(live[i].pos.distance_to(live[j].pos), live[i].radius + live[j].radius - 1e-3)

func test_sample_matches_rect_query() -> void:
	var rect := Rect2(-2000, -2000, 4000, 4000)
	var pieces := LandformSetpieces.setpieces_in_rect(SEED, rect)
	for i in 2000:
		var p := Vector2(fposmod(i * 97.3, 4000.0) - 2000.0, fposmod(i * 61.7, 4000.0) - 2000.0)
		var v := LandformSetpieces.sample(SEED, p)
		if v.y > 0.0:
			var hit := pieces.any(func(a): return p.distance_to(a.pos) < a.radius)
			assert_true(hit, "masked point %s lies in a listed footprint" % p)
