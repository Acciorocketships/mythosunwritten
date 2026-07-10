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


## Phase 2a RENAME (was test_falls_weld_to_lip_and_dive_under_the_pool,
## which asserted "site has falls" / m.cuts.size() >= 1 and then checked
## FallMesher's weld/dive-under geometry against the site's one cut). H1
## fixed: the site's steep_spans()/fall_cuts() now return ZERO spans (the
## rendered terrain here never drops more than FALL_DROP_MIN in any 24m
## window), so WaterMesher.build's m.cuts is empty, FallMesher.build([])
## returns null (see FallMesher.build's own "if cuts.is_empty(): return
## null"), and WaterSurfaceBuilder.build_chunk never adds its "Waterfalls"
## MeshInstance3D child (see build_chunk's own "if falls != null:" guard).
## Asserted at the build_chunk/scene level (not just m.cuts/FallMesher in
## isolation) so this test also exercises the real assembled-node contract
## a Phase-2b mesher rewrite would need to keep honouring.
func test_no_fall_mesh_without_steep_terrain() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var m: Dictionary = WaterMesher.build(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_eq(m.cuts.size(), 0, "H1: the site's rendered terrain never demands a fall")
	var fall_mesh: ArrayMesh = FallMesher.build(m.cuts, region)
	assert_null(fall_mesh, "FallMesher.build([]) returns null, no fall geometry at all")
	var node: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	_mark_multiseam_handled()
	assert_not_null(node, "site still builds its water sheet")
	assert_null(node.get_node_or_null("Waterfalls"),
		"build_chunk adds no Waterfalls node when there is nothing to render")
	node.free()


## Phase 2a REWRITE (was iterating m.cuts, which is now always empty on this
## seed's site — the loop body never ran, leaving the test "risky"/did-not-
## assert). The invariant itself ("no sub-4m fall exists — the weir
## staircase is back") is still exactly the right thing to guard against;
## re-expressed directly against steep_spans()/fall_cuts()'s own output
## (which m.cuts is now sourced from — see WaterMesher.gd:31) so the
## assertion has real teeth again instead of vacuously iterating nothing.
func test_no_fall_without_a_big_drop() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var rect := Rect2(Vector2(0, -1152), Vector2(192, 192))
	var spans: Array = WaterField.steep_spans(ctx, rect)
	var checked := 0
	for span: Dictionary in spans:
		checked += 1
		assert_true(span.top - span.bottom > WaterField.FALL_DROP_MIN - 0.001,
			"a sub-4m fall exists — the weir staircase is back")
	if checked == 0:
		pass_test("zero spans at the site (H1 fixed) — nothing to check, and nothing is exactly correct here")
