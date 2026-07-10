extends GutTest

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)

static var _plans: Dictionary = {}
static var _waters: Dictionary = {}
static var _regions: Dictionary = {}


static func _water(seed_v: int) -> WaterPlan:
	if not _waters.has(seed_v):
		var plan := HeightfieldPlan.new(seed_v, 22.0, 8, "mean", 3)
		var water := WaterPlan.new(seed_v, 22.0, 8)
		plan.set_water_plan(water)
		_plans[seed_v] = plan
		_waters[seed_v] = water
	return _waters[seed_v]


static func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


## Phase 1 (hydrostatic fill) note: see the identical helper in
## test_water_mesher.gd (WaterMesher.gd's own guard, not a new defect — see
## .superpowers/sdd/h-task-1-report.md). GUT checks for unhandled errors
## right after the test body returns, before after_each runs, so this is
## called immediately after each WaterMesher.build() call, not from a hook.
func _mark_multiseam_handled() -> void:
	for e in GutUtils.get_error_tracker().get_current_test_errors():
		if e.contains_text("multi-seam cell"):
			e.handled = true


func test_falls_weld_to_lip_and_dive_under_the_pool() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_true(m.cuts.size() >= 1, "site has falls")
	var mesh: ArrayMesh = FallMesher.build(m.cuts, region)
	assert_not_null(mesh, "falls build")
	var arrays: Array = mesh.surface_get_arrays(0)
	var fverts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vset: Dictionary = {}
	for v in fverts:
		vset[v] = true
	for rec: Dictionary in m.cuts:
		var top_row := 0
		for v: Vector3 in rec.lip:
			if vset.has(v):
				top_row += 1
		assert_eq(top_row, rec.lip.size(),
			"every lip vert appears in the fall mesh bit-identically")
		var below := false
		for v in fverts:
			if v.y < rec.cut.bottom - 0.3:
				below = true
		assert_true(below, "fall dives under the plunge surface")


func test_no_fall_without_a_big_drop() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	for rec: Dictionary in m.cuts:
		assert_true(rec.cut.top - rec.cut.bottom > WaterField.FALL_DROP_MIN - 0.001,
			"a sub-4m fall exists — the weir staircase is back")
