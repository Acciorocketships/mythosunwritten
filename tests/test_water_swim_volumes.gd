extends GutTest

# ------------------------------------------------------------
# TRIGGERS (r3 Task 7, sub-tile-reconciled r3 Task 9 — this file's own
# rename-of-intent, per that task's brief: it was never really about
# "volumes" any more, it is entirely about the TRIGGER wiring): swim volumes
# are TRIGGER BOXES straight from WaterSkin's own `triggers` list — one per
# 24m wet TILE (footprint = union of every built vertex in that tile — see
# WaterSkin._triggers) on the common/fast path, or SEVERAL finer 6m boxes for
# a tile whose whole-tile level spread fails but reconciles cleanly at
# sub-tile resolution (WaterSkin._sub_tile_triggers, r3 Task 9's own
# controller-addition-2 fix for Task 7's disclosed "suppressed tile loses
# EVERYTHING" trade-off) — each entry carrying set_meta("sampler", <the
# chunk's one frozen WaterSampler>) instead of a per-cell sampled plane (the
# old marching-squares mesher's per-cell swim data and the plane meta pair it
# produced are both deleted outright, r3 Task 7). A probe anywhere inside a
# box reads its real water height straight from the sampler
# (WaterSampler.level_at), not from a linear extrapolation off one centre
# sample.
#
# This suite checks the SHAPE of that wiring: tile/sub-tile coverage, the
# top/bottom clearance arithmetic, sampler meta presence (a single shared
# instance per chunk), and level_at sanity against WaterField's own ground
# truth at real probe points. The STEEP-tile no-trigger gate and the r3 Task
# 9 sub-tile reconciliation's own site pins (I1 chute film / 5.7 plunge pool
# centre) live in test_water_skin.gd (test_no_trigger_where_unswimmably_steep,
# test_sub_tile_reconciliation_keeps_a_legal_sloped_reach) per the task
# briefs. The full depth-CLASSIFICATION parity oracle (does a character's
# actual swim/wade/dry read ever disagree with the field?) is r3 Task 9's own
# tests/test_water_classification.gd — deliberately not duplicated here.
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
## WaterSkin-reported entry is covered by exactly one box (no lost/duplicated
## entries in either direction).
## r3 Task 9: matched by RECT POSITION (a stable, collision-free key —
## Rect2.position is unique per entry by construction, whether the entry is
## a 24m tile or one of _sub_tile_triggers' own finer 6m boxes), not by
## coarse 24m "cell" — a cell-level key went vacuous the moment a single
## cascade cell could legitimately carry SEVERAL small boxes at once (r3 Task
## 9's own sub-tile reconciliation; see WaterSkin._sub_tile_triggers). List
## order is also preserved 1:1 (WaterSurfaceBuilder.build_chunk iterates
## skin.triggers directly, appending one Area3D per entry with no reorder),
## so a plain index zip is an equally valid, simpler alternative match this
## test cross-checks against as a sanity guard.
func test_triggers_match_skin_tile_coverage_and_clearance() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk has water")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	assert_not_null(root, "site builds")
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "trigger boxes emitted")
	assert_eq(vols.size(), skin.triggers.size(),
		"one Area3D per skin.triggers entry, no more, no fewer")

	var by_pos: Dictionary = {}   # Vector2 rect.position -> Area3D
	for v in vols:
		var shape: BoxShape3D = v.get_child(0).shape
		var pos := Vector2(v.position.x - shape.size.x * 0.5, v.position.z - shape.size.z * 0.5)
		var key: Vector2i = Vector2i(roundi(pos.x * 100.0), roundi(pos.y * 100.0))   # cm-quantized, avoids float-eq flakiness
		assert_false(by_pos.has(key), "exactly one box per rect position (%s already seen)" % pos)
		by_pos[key] = v

	var checked := 0
	var sub_tile_entries := 0
	for i in skin.triggers.size():
		var trig: Dictionary = skin.triggers[i]
		var rect: Rect2 = trig.rect
		if absf(rect.size.x - WaterSkin.TRIGGER_SUB_TILE) < 0.01:
			sub_tile_entries += 1
		var key: Vector2i = Vector2i(roundi(rect.position.x * 100.0), roundi(rect.position.y * 100.0))
		assert_true(by_pos.has(key), "skin trigger at %s has a matching trigger box" % rect.position)
		if not by_pos.has(key):
			continue
		var area: Area3D = by_pos[key]
		# Index-order cross-check (see docstring): build_chunk's own append
		# order must match skin.triggers' order exactly.
		assert_true(vols[i] == area, "build order matches skin.triggers order at index %d" % i)
		checked += 1
		var shape: BoxShape3D = area.get_child(0).shape
		var top: float = area.position.y + shape.size.y * 0.5
		var bottom: float = area.position.y - shape.size.y * 0.5
		assert_almost_eq(top, float(trig.top), 0.001, "top matches skin trigger at %s" % rect.position)
		assert_almost_eq(bottom, float(trig.bottom), 0.001, "bottom matches skin trigger at %s" % rect.position)
		assert_almost_eq(shape.size.x, rect.size.x, 0.001, "box width matches tile width at %s" % rect.position)
		assert_almost_eq(shape.size.z, rect.size.y, 0.001, "box depth matches tile depth at %s" % rect.position)
		assert_almost_eq(area.position.x, rect.position.x + rect.size.x * 0.5, 0.001,
			"box centred on tile x at %s" % rect.position)
		assert_almost_eq(area.position.z, rect.position.y + rect.size.y * 0.5, 0.001,
			"box centred on tile z at %s" % rect.position)
		assert_eq(area.collision_layer, 1 << 7, "water trigger layer at %s" % rect.position)
		assert_eq(area.collision_mask, 0, "trigger has no collision mask at %s" % rect.position)
	print("MEAS test_triggers_match_skin_tile_coverage_and_clearance: %d entries matched (%d fine sub-tile boxes among them)" % [
		checked, sub_tile_entries])
	assert_eq(checked, skin.triggers.size(), "every skin trigger entry matched exactly one box")
	assert_gt(sub_tile_entries, 0,
		"the site chunk's own cascade tiles exercise the sub-tile path — precondition for this test to cover r3 Task 9's own reconciliation, not just the unchanged 24m fast path")
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
## baked from), not the full swim/wade/dry classification parity oracle —
## see tests/test_water_classification.gd (r3 Task 9).
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
	print("MEAS test_sampler_level_at_tracks_the_field: %d probes agree with the field, %d returned NAN (field-dry part of the tile), %d offenders" % [
		checked, nan_n, offenders.size()])
	assert_true(checked > 50, "a meaningful share of the tile-grid probes got a real (non-NAN) sampler reading to check (%d)" % checked)
	assert_true(offenders.is_empty(),
		"every non-NAN sampler reading tracks the field within its own bilinear tolerance: %s" % str(offenders))
	root.free()


## Task 7 review MEDIUM (shoreline-band coverage): the ~2m band of real,
## rendered, field-wet water between the waterline curve and WaterSkin's
## INSET-ed interior lattice must be answerable by the trigger's sampler —
## a character wading right at the water's edge stands exactly there, and a
## NaN answer makes character.gd's bridge read them as fully dry (neither
## swimming nor wading; the old per-cell sampled planes covered the whole
## cell, so this is a classification regression class, same render-vs-
## classification divergence family as run 2's I4). Probe points are built
## from WaterContour.curves' own points: p = pt - k*n̂ for k in 0.3..1.8
## (n̂ is the OUTWARD/dry-side unit normal per WaterContour's contract, so
## -n̂ steps into the water), filtered to points the FIELD itself calls wet
## (level - ground > 0.02, the same gate WaterSkin._lattice_wet uses) and
## whose 24m tile actually carries a trigger (a steep-gated tile has no box
## by design — no sampler is responsible there). Each surviving point must
## get a non-NaN sampler answer within 0.1 of WaterField.level_at.
## RED-FIRST evidence: against the Task 7 interior-lattice-only sampler this
## fails (the whole k<=1.8 band is inside INSET=2.0, where that bake kept no
## lattice points at all) — transcript in r3-task-7-report.md's concern-
## resolution section; the fix rebakes the sampler from the FIELD (see
## WaterSampler.build).
func test_sampler_covers_the_shoreline_band() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var span: float = WaterField.TILE * 8.0
	var rect := Rect2(Vector2(SITE_CHUNK) * span, Vector2.ONE * span)
	var curves: Array = WaterContour.curves(ctx, rect)
	assert_gt(curves.size(), 0, "site chunk has waterline curves (precondition)")
	var root: Node3D = WaterSurfaceBuilder.new().build_chunk(water, SITE_CHUNK, region)
	var vols: Array = _volumes(root)
	assert_gt(vols.size(), 0, "trigger boxes emitted")
	# One shared sampler per chunk (pinned by test_triggers_carry_a_shared_
	# sampler above) — any trigger's meta is THE chunk sampler.
	var sampler: WaterSampler = vols[0].get_meta("sampler")
	var covered: Dictionary = {}
	for v in vols:
		covered[_cell_of(v)] = true
	var checked := 0
	var nan_n := 0
	var offenders: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var normals: PackedVector2Array = c.normals
		for i in range(0, pts.size(), 5):
			for k: float in [0.3, 0.8, 1.3, 1.8]:
				var p: Vector2 = pts[i] - normals[i] * k
				var cell := Vector2i(int(floor(p.x / WaterSkin.TILE)), int(floor(p.y / WaterSkin.TILE)))
				if not covered.has(cell):
					continue   # steep-gated/unbuilt tile: no trigger box is responsible here
				var truth: float = WaterField.level_at(ctx, p)
				var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
				if truth == -INF or truth <= g + 0.02:
					continue   # not genuinely wet per the field (bend/normal cases) — not a fair band sample
				checked += 1
				var got: float = sampler.level_at(p)
				if is_nan(got):
					nan_n += 1
					if offenders.size() < 10:
						offenders.append("p=%s k=%.1f NaN (field level %.2f, depth %.2f)" % [p, k, truth, truth - g])
				elif absf(got - truth) > 0.1 and offenders.size() < 10:
					offenders.append("p=%s k=%.1f got=%.3f truth=%.3f err=%.3f" % [p, k, got, truth, absf(got - truth)])
	print("MEAS test_sampler_covers_the_shoreline_band: %d band points checked, %d NaN, %d total offenders" % [
		checked, nan_n, offenders.size()])
	assert_true(checked >= 10, "at least 10 genuine shoreline-band points found to check (%d)" % checked)
	assert_eq(nan_n, 0,
		"no shoreline-band point may read NaN — a character wading at the water's edge would classify as dry (e.g. %s)" % str(offenders))
	assert_true(offenders.is_empty(),
		"every band point's sampler reading is within 0.1 of WaterField.level_at: %s" % str(offenders))
	root.free()


## Task 7 live-gate follow-up (coordinator's "Defect A" oracle): the sampler
## must never report a level the FIELD does not itself report at the same
## (x,z) — pinned at the exact steep-face-adjacent points from the live
## evidence (the I1 chute at (53,-1083.9) and its neighbourhood down the
## 9.7 -> 5.7 cascade step). HONESTY NOTE (probe evidence, r3-task-7-report.md
## concern resolution 2): this oracle was NEVER red — the prescribed
## "sampler bleeds across steep faces" mechanism was unreproducible, because
## the sampler's corner values are point-samples of WaterField.level_at and
## its interpolation mirrors _fill_bilinear's own (guard-free since Phase 2a;
## the old FILL_JUMP constant no longer exists). Measured divergence at every
## probed chute point: 0.0000 — the 9.700 the live gate saw IS level_at's own
## answer there (the hydrostatic fill floods the face at the upstream level;
## wet()=true). The phantom-depth defect is therefore a TRIGGER-shape issue,
## fixed by the tile level-spread gate (see test_water_skin.gd::
## test_no_trigger_where_unswimmably_steep's site stanza); this test stays as
## the permanent guarantee that the sampler itself never ADDS divergence on
## top of the field near a chute.
func test_sampler_matches_the_field_at_the_chute() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds (precondition)")
	var sampler: WaterSampler = skin.sampler
	var checked := 0
	var offenders: Array = []
	for p: Vector2 in [Vector2(53.0, -1083.9), Vector2(53.0, -1085.0), Vector2(53.0, -1087.0),
			Vector2(53.0, -1082.5), Vector2(51.0, -1084.0), Vector2(57.0, -1084.0),
			Vector2(53.0, -1090.0), Vector2(54.0, -1092.0)]:
		var truth: float = WaterField.level_at(ctx, p)
		var got: float = sampler.level_at(p)
		if truth == -INF:
			assert_true(is_nan(got), "field-dry chute point %s must read NaN from the sampler" % p)
			continue
		checked += 1
		var err: float = absf(got - truth) if not is_nan(got) else INF
		if err > 0.3 and offenders.size() < 8:
			offenders.append("p=%s got=%s truth=%.4f" % [p, ("NaN" if is_nan(got) else "%.4f" % got), truth])
	print("MEAS test_sampler_matches_the_field_at_the_chute: %d wet chute points checked, %d offenders" % [
		checked, offenders.size()])
	assert_true(checked >= 5, "the chute probe points are genuinely field-wet (%d)" % checked)
	assert_true(offenders.is_empty(),
		"the sampler tracks WaterField.level_at within 0.3 at every steep-face-adjacent point: %s" % str(offenders))
