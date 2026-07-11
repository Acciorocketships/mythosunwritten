extends GutTest

# ------------------------------------------------------------
# r3 Task 7: swim volumes are now TRIGGER BOXES straight from WaterSkin's own
# `triggers` list (one per 24m wet TILE, footprint = union of every built
# vertex in that tile — see WaterSkin._triggers), each carrying
# set_meta("sampler", <the chunk's one frozen WaterSampler>) instead of a
# per-cell sampled plane (the old marching-squares mesher's per-cell swim
# data and the plane meta pair it produced are both deleted outright this
# task — see that task's report). A probe anywhere inside a box reads its
# real water height straight from the sampler (WaterSampler.level_at), not
# from a linear extrapolation off one centre sample.
#
# This suite checks the SHAPE of that wiring: tile coverage, the top/bottom
# clearance arithmetic, sampler meta presence (a single shared instance per
# chunk), and level_at sanity against WaterField's own ground truth at real
# probe points. The STEEP-tile no-trigger gate itself moved to
# test_water_skin.gd (test_no_trigger_where_unswimmably_steep) per the task
# brief. The full depth-CLASSIFICATION parity oracle (does a character's
# actual swim/wade/dry read ever disagree with the field?) is r3 Task 9's
# contract (river-train mirror + parity test) — deliberately not duplicated
# here.
# Pinned review seed/chunk; the site chunk carries the R3 cascade.
# ------------------------------------------------------------

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


func _region(seed_v: int, chunk: Vector2i):
	var key := [seed_v, chunk]
	if not _regions.has(key):
		_water(seed_v)
		_regions[key] = _plans[seed_v].compute_region(
			chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


func _volumes(root: Node3D) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Area3D:
			out.append(child)
	return out


## Tile index a trigger Area3D belongs to, recovered from its own position
## (rect.position.x/y + rect.size*0.5 by construction — see
## WaterSurfaceBuilder.build_chunk).
func _cell_of(area: Area3D) -> Vector2i:
	return Vector2i(int(floor(area.position.x / WaterSkin.TILE)),
		int(floor(area.position.z / WaterSkin.TILE)))


## Every trigger Area3D exactly reproduces its own WaterSkin.build().triggers
## entry: same footprint (rect position/size -> box centre/width/depth), same
## top/bottom clearance arithmetic (top = the tile's own max level +
## TRIGGER_TOP_CLEAR, bottom = the tile's own min ground - TRIGGER_BOTTOM_
## CLEAR — WaterSkin's own constants, read live rather than as literals so
## this test breaks loudly if either clearance ever changes), and every
## WaterSkin-reported tile is covered by exactly one box (no lost/duplicated
## tiles in either direction).
func test_triggers_match_skin_tile_coverage_and_clearance() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk has water")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	assert_not_null(root, "site builds")
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "trigger boxes emitted")

	var by_cell: Dictionary = {}
	for v in vols:
		var cell: Vector2i = _cell_of(v)
		assert_false(by_cell.has(cell), "exactly one box per tile (%s already seen)" % cell)
		by_cell[cell] = v

	var skin_cells: Dictionary = {}
	for trig: Dictionary in skin.triggers:
		var rect: Rect2 = trig.rect
		var cell := Vector2i(int(round(rect.position.x / WaterSkin.TILE)),
			int(round(rect.position.y / WaterSkin.TILE)))
		skin_cells[cell] = trig
		assert_true(by_cell.has(cell), "skin tile %s has a matching trigger box" % cell)
		if not by_cell.has(cell):
			continue
		var area: Area3D = by_cell[cell]
		var shape: BoxShape3D = area.get_child(0).shape
		var top: float = area.position.y + shape.size.y * 0.5
		var bottom: float = area.position.y - shape.size.y * 0.5
		assert_almost_eq(top, float(trig.top), 0.001, "top matches skin trigger at %s" % cell)
		assert_almost_eq(bottom, float(trig.bottom), 0.001, "bottom matches skin trigger at %s" % cell)
		assert_almost_eq(shape.size.x, rect.size.x, 0.001, "box width matches tile width at %s" % cell)
		assert_almost_eq(shape.size.z, rect.size.y, 0.001, "box depth matches tile depth at %s" % cell)
		assert_almost_eq(area.position.x, rect.position.x + rect.size.x * 0.5, 0.001,
			"box centred on tile x at %s" % cell)
		assert_almost_eq(area.position.z, rect.position.y + rect.size.y * 0.5, 0.001,
			"box centred on tile z at %s" % cell)
		assert_eq(area.collision_layer, 1 << 7, "water trigger layer at %s" % cell)
		assert_eq(area.collision_mask, 0, "trigger has no collision mask at %s" % cell)
	for cell in by_cell:
		assert_true(skin_cells.has(cell), "built box %s has a matching skin tile (no phantom boxes)" % cell)
	print("MEAS test_triggers_match_skin_tile_coverage_and_clearance: %d tiles, all matched" % by_cell.size())
	root.free()


## Every trigger Area3D carries set_meta("sampler", <a WaterSampler>) — the
## old per-cell sampled-plane meta pair is gone (checked below by name, the
## regression-guard pattern this codebase already uses elsewhere to pin a
## retired field's absence). All boxes on the same chunk share the IDENTICAL
## sampler instance (WaterSkin.build's own single `sampler` return value, per
## WaterSurfaceBuilder.build_chunk — one frozen snapshot per chunk, not one
## per tile).
func test_triggers_carry_a_shared_sampler() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "trigger boxes emitted")
	var first_sampler: WaterSampler = null
	for v in vols:
		assert_true(v.has_meta("sampler"), "sampler meta present")
		assert_false(v.has_meta("surface_c"), "no legacy sampled-plane meta on a new trigger")
		assert_false(v.has_meta("surface_g"), "no legacy sampled-plane gradient meta on a new trigger")
		var s: Variant = v.get_meta("sampler")
		assert_true(s is WaterSampler, "sampler meta is a WaterSampler instance")
		if first_sampler == null:
			first_sampler = s
		else:
			assert_true(s == first_sampler, "every trigger on one chunk shares the SAME sampler instance")
	root.free()


## level_at sanity: a 5x5 grid of probe points spanning each trigger box's own
## FULL tile footprint (not just its geometric centre, which — since a
## trigger's rect is the whole 24m tile square regardless of how much of it
## is actually wet — can legitimately land in a dry corner of a shore-heavy
## tile and starve the probe of real hits). Wherever the sampler returns a
## non-NAN answer it must agree with WaterField.level_at (the field's own
## ground truth) within a small tolerance — see WaterSampler.gd's own
## precision note (the sampler bilinear-interpolates over a 3.0m grid finer
## than the field's own 6.0m fill lattice). This is a sanity check on the
## WIRING (does the frozen snapshot actually track the live field it was
## baked from), not the full swim/wade/dry classification parity oracle (r3
## Task 9's contract).
func test_sampler_level_at_tracks_the_field() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "trigger boxes emitted")
	var checked := 0
	var nan_n := 0
	var offenders: Array = []
	for v in vols:
		var sampler: WaterSampler = v.get_meta("sampler")
		var shape: BoxShape3D = v.get_child(0).shape
		var rect := Rect2(Vector2(v.position.x - shape.size.x * 0.5, v.position.z - shape.size.z * 0.5),
			Vector2(shape.size.x, shape.size.z))
		for gj in 5:
			for gi in 5:
				var p: Vector2 = rect.position + rect.size * (Vector2(gi, gj) / 4.0)
				var sampled: float = sampler.level_at(p)
				if is_nan(sampled):
					nan_n += 1
					continue
				var truth: float = WaterField.level_at(ctx, p)
				if truth == -INF:
					continue
				checked += 1
				var err: float = absf(sampled - truth)
				if err > 0.5 and offenders.size() < 10:
					offenders.append("p=%s sampled=%.3f truth=%.3f err=%.3f" % [p, sampled, truth, err])
	print("MEAS test_sampler_level_at_tracks_the_field: %d probes agree with the field, %d returned NAN (shore band/gap), %d offenders" % [
		checked, nan_n, offenders.size()])
	assert_true(checked > 50, "a meaningful share of the tile-grid probes got a real (non-NAN) sampler reading to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every non-NAN sampler reading tracks the field within its own bilinear tolerance: %s" % str(offenders))
	root.free()
