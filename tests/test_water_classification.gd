extends GutTest

# ------------------------------------------------------------
# CLASSIFICATION PARITY (r3 Task 9's own deliverable): does the character's
# ACTUAL swim/wade/dry read — replicated here, test-side, as a geometric
# trigger-rect + WaterSampler query rather than a live PhysicsServer point
# query (deterministic, no scene/physics setup needed; every trigger rect
# this codebase builds is a plain axis-aligned box, exactly what
# Area3D.BoxShape3D + intersect_point would report — see
# test_water_swim_volumes.gd's own established pattern of probing trigger
# geometry directly) — ever disagree with FIELD TRUTH (WaterField.level_at
# minus ground, the naive "how deep is the water here" question, thresholded
# the same way character.gd's own ENTER gates are (0.8 swim, 0.05 wade; no
# hysteresis/previous-state modelled here — a cold, single-shot snapshot has
# no "previous frame" to hold a hysteresis band open, so ENTER is the only
# meaningful threshold for a oneshot classification)?
#
# ALL SIX classes (deep interior, waterline band, dry bank, steep chute,
# plunge pool centre, sloped-reach mid-channel) are real parity: field truth
# and character-math must read the IDENTICAL class at every probed point,
# zero mismatches. Historically (r3 Task 7/9) the steep-chute class was the
# ONE deliberate exception — a level-SPREAD suppression mechanism forced
# character-math to read DRY over a field-claimed depth, because the OLD
# stepped profile model's flat upstream shelves really could stand phantom
# depth over a downstream face. r3 Task 12/12a's smooth monotone descent
# removed the flat shelves that phantom class depended on; r3 Task 12b
# proved the suppression mechanism dead by construction on this site and
# deleted it outright (see WaterSkin.STEEP_UNSWIMMABLE's own neighbouring
# docstring and r3-task-12b-report.md) — test_steep_chute below is now
# ordinary parity too, see its own docstring for the measured before/after.
#
# Pinned review seed/chunk — the site chunk carries the R3 cascade this task
# reconciles (see WaterSkin.gd's own TRIGGER_LEVEL_SPREAD_MAX docstring and
# r3-task-9-report.md).
# ------------------------------------------------------------

const SEED := 2697992464
const SITE_CHUNK := Vector2i(0, -6)
const MIN_PER_CLASS := 60

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
		_regions[key] = _plans[seed_v].compute_region(chunk.x * 8 + 4, chunk.y * 8 + 4, 8)
	return _regions[key]


static func _rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * (WaterField.TILE * 8.0), Vector2.ONE * WaterField.TILE * 8.0)


## --- Shared oracles ---

## Naive field truth: WaterField.level_at(p) - ground vs the ENTER thresholds
## only (0.8 swim, 0.05 wade) — a single-shot classification has no previous
## frame to hold a hysteresis band open, so EXIT thresholds don't apply here.
static func _field_truth_class(ctx: Dictionary, region, p: Vector2) -> String:
	var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
	var lvl: float = WaterField.level_at(ctx, p)
	if lvl == -INF:
		return "DRY"
	var depth: float = lvl - g
	if depth > 0.8:
		return "SWIM"
	if depth > 0.05:
		return "WADE"
	return "DRY"


## Replicates character.gd::_update_in_water's STATIC classification math
## (r3 Task 9 — depth = sampler.level_at(xz) - gp.y, NO swell term, max over
## every overlapping trigger, same 0.8/0.05 ENTER thresholds) against a real
## `skin` Dictionary ({triggers, sampler} — either WaterSkin.build()'s own
## return value or a hand-built equivalent, see the sloped-reach class
## below), querying trigger geometry directly instead of through a live
## PhysicsServer point query. `gp` is the simulated character position
## (feet, matching global_position's own convention) — mirrors the real
## code's own +0.3 knee-height probe for the CONTAINS test only, never for
## the depth subtraction (character.gd's own docstring on this exact point).
static func _character_class(skin: Dictionary, gp: Vector3) -> String:
	var probe_y: float = gp.y + 0.3
	var xz := Vector2(gp.x, gp.z)
	var sampler: WaterSampler = skin.sampler
	var best_depth := -INF
	for t: Dictionary in skin.triggers:
		var rect: Rect2 = t.rect
		if not rect.has_point(xz):
			continue
		if probe_y < float(t.bottom) or probe_y > float(t.top):
			continue
		var lvl: float = sampler.level_at(xz)
		if is_nan(lvl):
			continue
		best_depth = maxf(best_depth, lvl - gp.y)
	if best_depth > 0.8:
		return "SWIM"
	if best_depth > 0.05:
		return "WADE"
	return "DRY"


## Runs the standard parity assertion (field truth == character math) over
## `points` (Array[Vector2], world xz — the character is simulated STANDING
## ON THE GROUND at each, gp.y = surface_y, so both sides subtract against
## the identical reference height and the only remaining variable is which
## level SOURCE each side reads and whether a trigger exists there at all —
## exactly what r3 Tasks 7-9 changed). Requires >= MIN_PER_CLASS points and
## asserts zero mismatches, printing up to 10 for diagnosis.
func _assert_parity(label: String, skin: Dictionary, ctx: Dictionary, region, points: Array) -> void:
	assert_true(points.size() >= MIN_PER_CLASS,
		"%s: at least %d points to check (%d)" % [label, MIN_PER_CLASS, points.size()])
	var checked := 0
	var offenders: Array = []
	var class_counts: Dictionary = {"SWIM": 0, "WADE": 0, "DRY": 0}
	for p: Vector2 in points:
		var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
		var gp := Vector3(p.x, g, p.y)
		var truth: String = _field_truth_class(ctx, region, p)
		var got: String = _character_class(skin, gp)
		checked += 1
		class_counts[truth] = class_counts.get(truth, 0) + 1
		if truth != got and offenders.size() < 10:
			offenders.append("p=%s truth=%s got=%s" % [p, truth, got])
	print("MEAS %s: %d points checked (SWIM=%d WADE=%d DRY=%d by field truth), %d mismatches" % [
		label, checked, class_counts.SWIM, class_counts.WADE, class_counts.DRY, offenders.size()])
	assert_true(offenders.is_empty(), "%s: zero mismatches: %s" % [label, str(offenders)])


## --- Class 1: deep interior ---
## Structural classifier matches test_water_skin.gd's own test_interior_
## rides_field (>=1.5m from any curve point), filtered to naive depth > 2.0m
## (comfortably, unambiguously deep — no waterline-proximity edge case) AND
## covered by a real trigger — this site's own interior lattice extends
## right up against the cascade's own suppressed sub-tiles (a "deep by the
## naive field" point immediately upstream of a suppressed step is a
## test_steep_chute-class point wearing this class's clothes, not a real
## deep-interior sample; caught red the first time this test ran without the
## coverage filter — see r3-task-9-report.md).
func test_deep_interior() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var verts: PackedVector3Array = skin.arrays[Mesh.ARRAY_VERTEX]
	var candidates: Array = []
	for v: Vector3 in verts:
		var p := Vector2(v.x, v.z)
		if _dist_to_curves(curves, p) < 1.5:
			continue
		var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
		var lvl: float = WaterField.level_at(ctx, p)
		if lvl == -INF or lvl - g <= 2.0:
			continue
		if not _any_trigger_covers(skin, p):
			continue
		candidates.append(p)
	print("MEAS test_deep_interior: %d deep-interior candidates found on site" % candidates.size())
	_assert_parity("test_deep_interior", skin, ctx, region, candidates)


## --- Class 2: waterline band (±0.3m) ---
## p = curve_point - k*outward_normal for k in [-0.3, 0.3] (k>0 steps into
## the water, k<0 steps onto the bank — WaterContour's own outward-normal
## convention, matching test_sampler_covers_the_shoreline_band's identical
## construction), skipped when the point's own 24m tile carries no trigger
## at all (a steep-gated tile has no sampler responsible there by design —
## not a fair parity sample; the chute class covers that case on its own
## terms).
func test_waterline_band() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var candidates: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var normals: PackedVector2Array = c.normals
		for i in range(0, pts.size(), 3):
			for k: float in [-0.3, -0.15, 0.0, 0.15, 0.3]:
				var p: Vector2 = pts[i] - normals[i] * k
				if not _any_trigger_covers(skin, p):
					continue
				candidates.append(p)
	print("MEAS test_waterline_band: %d waterline-band candidates found on site" % candidates.size())
	_assert_parity("test_waterline_band", skin, ctx, region, candidates)


## --- Class 3: dry bank ---
## p = curve_point - k*outward_normal for k comfortably past the shoreline
## (3-8m onto the bank), confirmed field-dry (level_at == -INF or depth <=
## 0.05) as a site precondition on the candidate set itself.
func test_dry_bank() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var curves: Array = WaterContour.curves(ctx, _rect(SITE_CHUNK))
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var candidates: Array = []
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		var normals: PackedVector2Array = c.normals
		for i in range(0, pts.size(), 3):
			for k: float in [3.0, 5.0, 8.0]:
				var p: Vector2 = pts[i] + normals[i] * k
				var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
				var lvl: float = WaterField.level_at(ctx, p)
				if lvl != -INF and lvl - g > 0.05:
					continue   # still genuinely wet this far out (a wide body) — not a fair dry-bank sample
				candidates.append(p)
	print("MEAS test_dry_bank: %d dry-bank candidates found on site" % candidates.size())
	_assert_parity("test_dry_bank", skin, ctx, region, candidates)


## --- Class 4: steep chute (HISTORICALLY the one INTENTIONAL divergence
## class — RECONCILED r3 Task 12b) ---
## Candidates come from FIELD/GEOMETRY data ONLY — pinned chute coordinates
## plus a field-static-depth filter — never from skin.triggers. (Review fix,
## r3 Task 9: the first version pre-filtered candidates through
## _any_trigger_covers, whose rect.has_point is the IDENTICAL predicate
## _character_class's own first gate applies — "0 offenders" was true by
## construction, a tautology that could never fail. Keeping candidate
## selection FIELD-only, never trigger-gated, is what keeps THIS version
## falsifiable too, see below.)
##
## The point set walks the I1 chute face itself: x in [44, 58], z in
## {-1083, -1084, -1085} — the cascade-step band where, under the OLD
## stepped profile model, the hydrostatic fill stood the 9.7 reach's flat
## level over sloping ground (the owner's I1 "a waterfall stands where the
## terrain has only slopes"; film point (53, -1083.9) pinned live at static
## depth ~2.5 over a ~0.3m film) — filtered to points the FIELD itself
## claims wet at static depth > 0.5.
##
## r3 Task 12b RECONCILIATION: this class's old premise — that character-
## math must deliberately DIVERGE from field truth here (reading DRY over a
## field-claimed depth) — was true only because the OLD model's flat
## upstream shelf made the field's own reading a lie (phantom depth over a
## real thin film). r3 Task 12/12a's smooth monotone descent removes that
## lie structurally: this span has ZERO interior sill knots
## (r3-task-12a-report.md), so there is no flat shelf anywhere along it, and
## the Task-7/9 level-SPREAD suppression that used to force the divergence
## is RETIRED (r3-task-12b-report.md's own proof — see WaterSkin.
## STEEP_UNSWIMMABLE's neighbouring docstring). Measured directly on this
## EXACT 87-point candidate set: character-math (the real trigger+sampler
## path) and field truth now agree at EVERY point — 29 read SWIM, 58 read
## WADE, 0 DRY, on BOTH sides, 0 mismatches. The assertion is therefore full
## PARITY (the same oracle every other class in this file uses), not "must
## read DRY" — asserting DRY here would now assert a MEASURED FALSEHOOD (29
## of these 87 points are genuinely, honestly >0.8m deep: small pool-like
## pockets the smooth ramp legitimately carries partway down the descent,
## not a suppressed phantom).
##
## FALSIFIABILITY (without the old TRIGGER_SUB_TILE_SPREAD_MAX=999
## induced-red mechanism, whose constant no longer exists to bump):
## candidates are selected from FIELD data alone, never through
## skin.triggers — so if a future regression left this band un-triggered
## (the OLD, correct-for-its-time behaviour), every candidate would read DRY
## against a SWIM/WADE truth and this test would fail loudly, exactly as it
## would have caught the opposite direction before r3 Task 12.
func test_steep_chute() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var candidates: Array = []
	var naive_would_swim := 0
	var naive_would_wade := 0
	for z: float in [-1083.0, -1084.0, -1085.0]:
		var x := 44.0
		while x <= 58.0 + 0.001:
			var p := Vector2(x, z)
			var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			var lvl: float = WaterField.level_at(ctx, p)
			if lvl != -INF and lvl - g > 0.5:
				candidates.append(p)
				if lvl - g > 0.8:
					naive_would_swim += 1
				else:
					naive_would_wade += 1
			x += 0.5
	print("MEAS test_steep_chute: %d field-wet chute-line points (static depth > 0.5; naive truth: %d would SWIM, %d would WADE)" % [
		candidates.size(), naive_would_swim, naive_would_wade])
	_assert_parity("test_steep_chute", skin, ctx, region, candidates)


## --- Permanent reported-river depth pin ---
## This coordinate was formerly a 0.7976m knife-edge wade and could falsely
## latch swimming on one swell crest. The water overhaul deliberately
## separated rendered bathymetry from the hydraulic trace bed; it now has
## 3m of static cover and must honestly classify SWIM. The load-bearing
## invariant remains static-field parity: swell never enters the depth gate.
func test_i4_waterline_pin() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var p := Vector2(36.4, -1108.7)
	var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
	var lvl: float = WaterField.level_at(ctx, p)
	var depth: float = lvl - g
	print("MEAS test_i4_waterline_pin: field level=%.4f ground=%.4f static depth=%.4f" % [
		lvl, g, depth])
	assert_true(depth > 0.8,
		"reported river pin keeps genuinely swimmable static depth (%.4f > 0.8)" % depth)
	var got: String = _character_class(skin, Vector3(p.x, g, p.y))
	assert_eq(got, "SWIM",
		"I4 (36.4,-1108.7) matches its genuinely deep static field through the real trigger+sampler path")


## --- Class 5: plunge pool centre (controller addition 3) ---
## Mirror of test_steep_chute's own scan, inverted: points that ARE covered
## by a real trigger AND naively deep (>0.8) — the restored fraction of the
## 6 tiles Task 7 used to suppress wholesale. Unlike the chute class, this
## one IS true parity (field truth == character math == SWIM): restoring
## coverage should restore agreement, not just trigger existence.
func test_plunge_pool_centre() -> void:
	var water: WaterPlan = _water(SEED)
	var region = _region(SEED, SITE_CHUNK)
	var ctx: Dictionary = WaterField.ctx(water, SITE_CHUNK, region)
	var skin: Dictionary = WaterSkin.build(water, SITE_CHUNK, region)
	assert_false(skin.is_empty(), "site chunk builds a skin")
	if skin.is_empty():
		return
	var candidates: Array = []
	var cell_range: Dictionary = _site_cell_range()
	for cz in cell_range.cz:
		for cx in cell_range.cx:
			var lo: Vector2 = Vector2(cx, cz) * WaterSkin.TILE
			for jj in range(0, 9):
				for ii in range(0, 9):
					var p: Vector2 = lo + Vector2(ii, jj) * 3.0
					var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
					var lvl: float = WaterField.level_at(ctx, p)
					if lvl == -INF or lvl - g <= 0.8:
						continue
					if not _any_trigger_covers(skin, p):
						continue
					candidates.append(p)
			if candidates.size() >= 200:
				break
		if candidates.size() >= 200:
			break
	print("MEAS test_plunge_pool_centre: %d covered-and-deep candidates found on site" % candidates.size())
	_assert_parity("test_plunge_pool_centre", skin, ctx, region, candidates)
	# --- Third pin re-derivation (r3 Task 12b) ---
	# Controller addition 3's own pinned probe, historically labelled "the
	# 5.7 plunge pool centre" (the OLD stepped model's own flat reach value
	# at this spot). x=56.0, not the tile's own 54.0 (a tile-box edge, not
	# its centre) — see test_water_skin.gd's identical pin for why: a
	# live-gate check found a real BoxShape3D + PhysicsServer can exclude a
	# point sitting EXACTLY on a box face even though this test's own
	# Rect2.has_point-based oracle includes it (r3-task-9-report.md has the
	# measured live contrast).
	# The continuous profile still owns the surface height, while the deeper
	# rendered bathymetry now gives this historical pool pin ample cover. It
	# therefore joins the class's deep candidates instead of retaining its
	# stale pre-bathymetry WADE expectation.
	var pool_centre := Vector2(56.0, -1101.0)
	var g2: float = TerrainSurfaceField.surface_y(region, pool_centre.x, pool_centre.y)
	var lvl2: float = WaterField.level_at(ctx, pool_centre)
	print("MEAS test_plunge_pool_centre: third pin (56,-1101) level=%.4f ground=%.4f static depth=%.4f" % [
		lvl2, g2, lvl2 - g2])
	assert_true(lvl2 - g2 > 0.8, "historical plunge-pool pin retains swimmable depth")
	assert_eq(_character_class(skin, Vector3(pool_centre.x, g2, pool_centre.y)), "SWIM",
		"historical plunge-pool pin matches its %.4fm static field depth" % (lvl2 - g2))


## --- Class 6: sloped-reach mid-channel ---
## Same hand-built-fill-lattice fixture as test_water_skin.gd's own
## test_sub_tile_reconciliation_keeps_a_legal_sloped_reach (see that test's
## docstring for why a hand-built fill lattice, not a RiverTrace + profile(),
## is the right fixture here) — grade 0.2, within controller addition 2's own
## (0.083, 0.333] legal band, spanning one 24m tile. Exercises the FULL
## character-math path (a real WaterSampler built over the reach, not just
## trigger existence) end to end.
func test_sloped_reach_mid_channel() -> void:
	var region := HeightfieldRegion.new({}, {})
	var m1: int = WaterField.FILL_M + 1
	var levels := PackedFloat32Array()
	levels.resize(m1 * m1)
	var top_level := 10.0
	var grade := 0.2
	for j in m1:
		for i in m1:
			levels[j * m1 + i] = top_level - grade * float(j) * WaterField.FILL_STEP
	var fill_base := Vector2(0.0, 0.0)
	var ctx: Dictionary = {"ponds": [], "rivers": [], "buckets": {}, "region": region,
		"fill_base": fill_base, "fill": {"levels": levels}}

	var verts := PackedVector3Array()
	for zz in [1.0, 4.0, 7.0, 10.0, 13.0, 16.0, 19.0, 22.0]:
		for xx in [13.0, 15.0]:
			verts.append(Vector3(xx, WaterField.level_at(ctx, Vector2(xx, zz)), zz))
	var st: Dictionary = {"verts": verts, "region": region, "ctx": ctx}
	var triggers: Array = WaterSkin._triggers(st)
	# r3 Task 12b: the spread gate (whole-tile + sub-tile suppression) is
	# RETIRED — triggers are now simple wet-tile coverage, so a legal sloped
	# reach can no longer be suppressed AT ALL (the property this test guarded
	# is now structural, not gate-dependent). This synthetic reach (x in
	# [13,15], z in [1,22], fill_base origin) lies wholly inside the single
	# 24m tile (0,0), so it keeps exactly ONE trigger — was 4 under the old
	# sub-tile model. The load-bearing content is the parity assertion below.
	assert_eq(triggers.size(), 1, "precondition: the legal sloped reach keeps its (single wet-tile) trigger — not suppressed")

	# A real sampler over the reach's own grid (3m step, matching WaterSkin's
	# interior lattice spacing) — exercises WaterSampler.level_at exactly as
	# WaterSkin.build's own sampler bake does, just without the flow-frame
	# arrays (this class's own assertion is static-depth only, so a
	# flow-frame-less sampler — flow_frame_at falls back to Vector3.ZERO,
	# "calm", see WaterSampler.build's own default-params note — is a fair,
	# minimal fixture).
	var sampler := WaterSampler.build(ctx, region, Vector2(0.0, 0.0), 3.0, 9, 9)
	var skin: Dictionary = {"triggers": triggers, "sampler": sampler}

	var points: Array = []
	for i in range(0, 61):
		var zz2: float = 0.2 + (23.6 * float(i) / 60.0)
		points.append(Vector2(14.0, zz2))
	_assert_parity("test_sloped_reach_mid_channel", skin, ctx, region, points)


## --- helpers ---

static func _dist_to_curves(curves: Array, p: Vector2) -> float:
	var best := INF
	for c: Dictionary in curves:
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			best = minf(best, pts[i].distance_to(p))
	return best


static func _any_trigger_covers(skin: Dictionary, p: Vector2) -> bool:
	for t: Dictionary in skin.triggers:
		if t.rect.has_point(p):
			return true
	return false


## SITE_CHUNK's own 24m-CELL index range: chunk (0,-6) spans world
## (0,-1152)..(192,-960) — a 192m chunk is EXACTLY 8 WaterSkin.TILE(24m)
## cells per side, so cell origin = chunk * 8 in cell units (NOT chunk *
## WaterField.TILE, which would double-apply the 24m factor). Computed once
## here, not hand-typed per scan loop, after one hand-typed copy (range(-8,0)
## instead of range(-48,-40)) silently scanned world x/z near the ORIGIN
## instead of the pinned site far to the south — caught when test_steep_chute/
## test_plunge_pool_centre both found zero candidates on a chunk known (from
## every other test in this suite) to be full of both.
static func _site_cell_range() -> Dictionary:
	var origin_cell := Vector2i(SITE_CHUNK.x * 8, SITE_CHUNK.y * 8)
	return {"cx": range(origin_cell.x, origin_cell.x + 8), "cz": range(origin_cell.y, origin_cell.y + 8)}
