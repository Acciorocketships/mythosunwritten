# A boundary-conforming water sheet whose outer rim sits directly on
# WaterContour's smooth curves (Task 3), not on the old marching-squares
# mesher's own grid corners — this is the mesh that actually fixes the
# angular shoreline test_water_contour.gd's header documents. Two vertex
# families welded into one indexed surface:
#   - INTERIOR: a 3.0m world-aligned lattice, kept only at points >= 2.0m
#     inside a curve. "Inside" = WaterField.level_at's OWN field-truth
#     wetness (the exact same wet/dry oracle WaterContour._is_wet uses to
#     place the curves in the first place — see _lattice_wet below), gated by
#     a presence-grid-accelerated distance-to-nearest-curve-point for the
#     INSET margin. A first implementation tried a pure geometric proxy
#     instead (nearest curve point + which side of ITS outward normal p sits
#     on, no field query at all) reasoning it was the direct generalization
#     of point-in-polygon to boundaries that may not close (a chunk's curves
#     are routinely OPEN here — verified empirically on SITE_CHUNK: 3/3
#     curves open, 0 closed, a river/lake network clipped by the chunk rect
#     never closes into a polygon on this terrain) — this task's OWN
#     test_no_free_edges_except_border caught it red-handed: a curve point's
#     normal is only a reliable inside/outside signal NEAR that point: at
#     world (45,-1149), 14.6m from the nearest curve point across a wide
#     open lake, the nearest point's LOCAL outward normal pointed the wrong
#     way for this far-away query, misclassifying real wet field territory
#     as dry and leaving a hole in the interior mesh with free edges nowhere
#     near any curve (see this task's report for the full transcript). The
#     field itself has no such blind spot — it is the ground truth the
#     curves are already contours OF, so lattice wetness and curve position
#     are consistent by construction, not by geometric coincidence. Height =
#     WaterField.level_at (the brief's own rule).
#   - BOUNDARY STRIP: one vertex per curve point, ON the curve, at the
#     curve's own baked level — zippered to the interior lattice's own
#     jagged edge ring via a greedy two-polyline triangle-strip walk (the
#     standard "bridge two open polylines" algorithm), so every triangle
#     touching the curve has exactly one edge shared with its strip neighbour
#     and one edge on each polyline — no T-junction is possible by
#     construction, because the interior grid's own quad triangulation never
#     touches a boundary vertex directly; only the strip does.
# MENISCUS RIM (Task 5, see _rim): three more rows per curve point, curling
# OUTWARD (dry side) and DOWN from the strip's own curve vertex (reused as
# row0) to a buried seal under the terrain. This is what heals the strip's
# own former free edge (the curve itself, Task 4's documented "no rim yet"
# waterline) into interior geometry — the free-edge invariant TIGHTENS here:
# only the rim's own buried outer row (row3) and true chunk borders may be
# free edges from this task onward.
# FLOW FRAMES + REAL NORMALS (Task 6, see _flow_frame_at/_weld_vert): CUSTOM0
# is rebaked from Task 4's (flow.x, shore, flow.y, steep) to (s, d, slope,
# shore_dist) — continuous arc length/cross distance/profile slope along the
# nearest river trace (ponds: all zero), plus shore distance for every
# vertex regardless of mode. ARRAY_NORMAL stops being a blanket Vector3.UP:
# interior verts get a real heightfield normal (WaterField.level_at central
# differences); rim/strip rows get the meniscus curl's own local frame (UP
# rotated toward the curve's outward normal, more so per row, pinched back to
# UP at walls) — see _interior_normal/_curl_normal. _weld_vert now AVERAGES
# normals for verts that weld together (a parallel normal_accum array, summed
# on every weld hit, normalized once at the end by _bake_normals) instead of
# picking whichever call site happened to create the vertex first.
# TRIGGERS + SAMPLER (Task 7, see _triggers/WaterSampler.gd): build() now
# returns a REAL `sampler` (a frozen WaterSampler snapshot of the water
# FIELD across this chunk, baked on the interior lattice's own grid geometry
# but covering the FULL wet footprint including the INSET shoreline band —
# see WaterSampler.gd's own BACKING DATA note) instead of Task 4-6's `null`
# placeholder. `_triggers` gained the STEEP_UNSWIMMABLE gate the old
# marching-squares mesher's own volume builder used to enforce per 24m
# CELL: a tile whose max |grade_at| exceeds the gate gets no trigger box at
# all (steep water is not swimmable by design). This is the class's own
# terminal deliverable — WaterSurfaceBuilder.build_chunk now consumes
# `triggers`/`sampler` directly and the old mesher (and the per-cell sampled
# plane pair of metas it used to hang off each volume) is deleted outright;
# see r3 Task 7's report for the removal.
class_name WaterSkin
extends Object

const STEP := 3.0             # interior lattice spacing — brief's own "3.0m world-aligned lattice"
const INSET := 2.0            # brief's own "points >= 2.0m inside a curve"
const BUCKET := 3.0           # presence-grid bucket size for nearest-curve-point acceleration
const WELD_Q := 64.0          # position-quantize scale for the shared vertex weld (brief: "y*64")
const WELD_XZ_Q := 100.0      # 1cm horizontal precision — finer than WELD_Q since strip verts must weld exactly
const TILE := 24.0            # trigger tiling — matches WaterField.TILE
const TRIGGER_TOP_CLEAR := 1.7
const TRIGGER_BOTTOM_CLEAR := 5.0
# Max |grade_at| a wet TILE may carry and still get a trigger box. grade_at
# is a secant over one TRACE_STEP=12m river-trace segment (WaterField.gd);
# the legal ceiling for an ordinary (non-fall) reach is FALL_DROP_MIN/
# TRACE_STEP = 4.0/12.0 = 0.3333 — anything steeper is already classified a
# fall face by WaterField's own FALL_DROP_MIN rule, so no legitimate
# swimmable reach can secant above ~0.333. True fall faces plunge far
# harder, producing secants of ~0.5 or more. 0.45 sits between the two with
# margin on both sides: comfortably above the legal-reach ceiling (no
# swimmable water gets gated by accident) and comfortably below real fall
# secants (no fall face slips through and gets a trigger). Ported verbatim
# (constant + rationale) from the retired marching-squares mesher's own
# per-24m-CELL steep gate (r3 Task 7's own straggler grep is why the old
# class name doesn't appear in this comment — only the math is unchanged).
const STEEP_UNSWIMMABLE := 0.45

# --- Meniscus rim (Task 5) — brief's own literal per-point profile, local
# frame (outward normal n, level L, ground g): row0 = the strip's own curve
# vertex (weld-reused, not a new position); row1 = p, y=L-ROW1_DROP; row2 =
# p + reach2*n, y=L-ROW2_DROP; row3 = p + reach3*n, y = min(L-ROW3_DROP,
# g-GROUND_BURY). reach2/reach3 default to (ROW2_REACH, ROW3_REACH) and pinch
# toward WALL_PINCH at wall-flagged points — see _rim's own docstring.
const RIM_ROW1_DROP := 0.02
const RIM_ROW2_DROP := 0.18
const RIM_ROW3_DROP := 0.30
const RIM_ROW2_REACH := 0.35
const RIM_ROW3_REACH := 0.55
const RIM_WALL_PINCH := 0.05
const RIM_GROUND_BURY := 0.30

# --- Flow frames (Task 6) — brief's own CUSTOM0 = (s, d, slope, shore_dist):
# s = arc length from source along the nearest river trace, d = signed
# cross-channel distance, slope = continuous profile slope at s, shore_dist =
# distance to the nearest curve point (clamped). RIVER_MAX_DIST is the
# brief's own pond/river gate ("no trace within 18m" => calm pond frame);
# JUNCTION_RADIUS is the brief's own "two traces within 12m" junction-blend
# gate. See _flow_frame_at's own docstring for the full derivation.
const RIVER_MAX_DIST := 18.0
const JUNCTION_RADIUS := 12.0
# Same-trace segment-tie blend band (Task 6 review fix — see _project_on_
# trace's own docstring for the mechanism and r3-task-6-report.md "Fix: bend
# s-compression" for the red->green evidence). When the two candidate
# segments' clamped distances are within this band of each other, their
# UNCLAMPED arc-length/tangent/slope contributions are blended instead of
# hard-picked, spreading a polyline corner's intrinsic projection stall over
# the band instead of concentrating it in one shoreline step. DERIVED, not
# tuned:
#   - UPPER bound: must sit below the smallest mid-segment tie gap anywhere
#     in the river-frame domain, so the blend is strictly a corner-local
#     device and is exactly zero at every near-sample pair-flip locus (where
#     _flow_frame_at's bucket scan swaps near_si and the candidate PAIR
#     changes its minor member — any nonzero weight there would step).
#     Mid-segment, the minor candidate clamps to the shared sample at
#     distance sqrt(d^2 + (L/2)^2) against the major's perpendicular d, so
#     the gap is sqrt(d^2 + (L/2)^2) - d — smallest at the largest relevant
#     offset: d = RIVER_MAX_DIST = 18, L = 12m trace spacing gives 0.974m.
#     0.75 sits under that with margin.
#   - LOWER bound: the band must cover a corner's whole stall wedge plus
#     roughly a curve step either side to have room to spread the deficit.
#     Walking past a wedge boundary the tie gap grows quadratically
#     (~w^2/2d at walk distance w): at the pinned site's own bend (d~9m,
#     theta~6.2 deg) the gap reaches 0.75 only ~3.7m out, so the band spans
#     ~2.5 steps either side of the corner — the measured ~0.96m wedge
#     deficit spreads at <=~0.3m per 1.5m step, inside the test's own 0.5
#     tolerance with margin.
const SEG_TIE_BAND := 0.75
const SHORE_DIST_MAX := 8.0
const SHORE_RADIUS_CELLS := 4   # BUCKET=3.0m cells; safely covers an 8.0m clamp radius with slack — mirrors _nearest_curve_dist's own "radius=1 covers INSET=2.0 since BUCKET=3.0" derivation, scaled up (8.0/3.0 -> 3 cells, +1 slack for a query point sitting at its own cell's far edge)

# --- Rim normals (controller addition) — curl-rotation angle per rim row,
# about the curve tangent, sweeping from UP toward the curve's own outward
# normal n̂: row0 is always exactly UP (the meniscus crest reads as flat
# water, matching the interior lattice it welds into — see _rim's own row0 =
# strip-vertex reuse); rows 1-3 rotate UP toward n̂ by an increasing angle,
# pinched back toward 0 (UP) at wall-flagged points by the SAME
# _smoothed_wall blend _rim already uses for its reach2/reach3 pinch — a
# flush wall curtain reads as near-UP, not as a horizontal cliff face, per
# the controller brief's own "wall-pinched near-UP" rule. Expressed as
# PI-based literals (not deg_to_rad calls) so they fold to true GDScript
# constants.
const RIM_NORMAL_ANGLE1 := PI / 18.0          # 10 deg — row1, hairline crest dip
const RIM_NORMAL_ANGLE2 := PI * 2.0 / 9.0     # 40 deg — row2, the visible curl
const RIM_NORMAL_ANGLE3 := PI * 13.0 / 36.0   # 65 deg — row3, buried seal (invisible; kept continuous, not visually tuned)


## build(water, chunk, region) -> {} when dry, else:
##   arrays: Array           # Mesh.ARRAY_MAX arrays, indexed, welded (VERTEX/NORMAL/INDEX/CUSTOM0)
##   triggers: Array[Dictionary]  # {rect: Rect2, top: float, bottom: float}
##   sampler: WaterSampler   # r3 Task 7: a frozen snapshot of the FIELD across this chunk
##                           # (full wet footprint, shoreline band included — see
##                           # WaterSampler.build) — every trigger Area3D this build feeds
##                           # WaterSurfaceBuilder.build_chunk shares this ONE instance via
##                           # set_meta("sampler", sampler).
## chunk is a 192m streamer chunk (site (0,-6)) — same convention this
## codebase's water pipeline uses everywhere (see e.g. WaterField.ctx's own
## `base := Vector2(chunk.x, chunk.y) * (TILE * 8.0) - ...` calc; plan erratum,
## docs/superpowers/plans/2026-07-10-water-continuous-surface.md).
static func build(water: WaterPlan, chunk: Vector2i, region) -> Dictionary:
	var ctx: Dictionary = WaterField.ctx(water, chunk, region)
	if ctx.ponds.is_empty() and ctx.rivers.is_empty():
		return {}
	var span: float = WaterField.TILE * 8.0
	var rect := Rect2(Vector2(chunk) * span, Vector2.ONE * span)
	var curves: Array = WaterContour.curves(ctx, rect)
	if curves.is_empty():
		return {}

	var buckets: Dictionary = _build_buckets(curves)
	var st: Dictionary = {
		"ctx": ctx, "region": region, "rect": rect, "curves": curves, "buckets": buckets,
		"verts": PackedVector3Array(), "idx": PackedInt32Array(), "weld": {},
		# Task 6: normal accumulator parallel to `verts` (grown in lockstep by
		# _weld_vert — see its own docstring on why welded verts AVERAGE their
		# contributors' normals rather than picking one arbitrarily), plus two
		# per-build memo caches (trace source_cell -> cumulative arc length /
		# WaterField.profile() result) so a 2.6km trace's O(n) arc-length walk
		# and profile() lookup are each paid ONCE per build, not once per
		# vertex (WaterField.profile itself is ALSO cached whole-session by
		# source_cell — see WaterField._profiles — but that cache still costs a
		# mutex lock + dictionary hit per call; memoizing the result here
		# avoids even that per vertex/per candidate trace).
		"normal_accum": PackedVector3Array(),
		"arclen": {}, "profiles": {},
	}
	var lattice: Dictionary = _interior_lattice(st)
	if lattice.kept.is_empty():
		return {}
	_interior_mesh(st, lattice)
	for c: Dictionary in curves:
		_boundary_strip(st, lattice, c)
		_rim(st, c)
	if st.idx.is_empty():
		return {}

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st.verts
	arrays[Mesh.ARRAY_INDEX] = st.idx
	arrays[Mesh.ARRAY_NORMAL] = _bake_normals(st)
	arrays[Mesh.ARRAY_CUSTOM0] = _custom0(st)

	# Sampler bake: the FIELD across this chunk, on the lattice's own grid
	# geometry (Task 7 review MEDIUM fix — the interior lattice itself insets
	# INSET away from the waterline, so it is NOT a full-coverage height
	# source; see WaterSampler.gd's own BACKING DATA note).
	var sampler := WaterSampler.build(ctx, region, lattice.origin, STEP, lattice.nx, lattice.nz)
	return {"arrays": arrays, "triggers": _triggers(st), "sampler": sampler}


## Per-vertex CUSTOM0 = (s, d, slope, shore_dist) — Task 6's flow-frame bake,
## REPLACING Task 4's (flow.x, shore, flow.y, steep) contract (this file's
## OLD docstring here predicted exactly this: "Task 6/8 replace both the band
## and these CUSTOM0 semantics outright"). The water shader itself
## (water_unified.gdshader) is NOT updated by this task — that is Task 8's
## own deliverable — so between this commit and Task 8's, the shader reads
## these new lanes under its old flow_v/steep_v/shore_v names; a sequenced
## regression the plan itself schedules (see r3-task-6-report.md).
##   s: arc length (metres) along the nearest river trace's polyline, at the
##      vertex's own projected point.
##   d: signed cross-channel distance from that same nearest trace.
##   slope: continuous profile slope at s (central difference of
##      WaterField.profile's levels, interpolated continuously across the
##      projected segment — see _project_on_trace).
##   shore_dist: distance to the nearest curve point, clamped [0, 8].
## Ponds/lakes (no trace within RIVER_MAX_DIST=18m of the vertex): s=d=
## slope=0 (brief's own literal "calm" rule) — shore_dist is still baked
## normally, since it is a shore-proximity signal independent of river/pond
## mode. See _flow_frame_at for the full per-vertex derivation, including
## junction blending where two traces both lie within JUNCTION_RADIUS=12m.
static func _custom0(st: Dictionary) -> PackedFloat32Array:
	var cust := PackedFloat32Array()
	cust.resize(st.verts.size() * 4)
	for vi in st.verts.size():
		var v: Vector3 = st.verts[vi]
		var p := Vector2(v.x, v.z)
		var frame: Dictionary = _flow_frame_at(st, p)
		cust[vi * 4 + 0] = frame.s
		cust[vi * 4 + 1] = frame.d
		cust[vi * 4 + 2] = frame.slope
		cust[vi * 4 + 3] = frame.shore_dist
	return cust


## Cumulative arc length per trace sample (PackedFloat32Array, same size as
## tr.points), memoized on `st` by source_cell so a 2.6km trace's O(n) walk is
## paid once per build, not once per vertex (brief's own explicit warning —
## see this file's Task 6 header note). Purely a sum of consecutive-sample
## Euclidean XZ distances — no field queries, so even the FIRST computation is
## cheap (unlike WaterField.profile's own terrain-walk cost).
static func _trace_arclen(st: Dictionary, tr: RiverTrace) -> PackedFloat32Array:
	if st.arclen.has(tr.source_cell):
		return st.arclen[tr.source_cell]
	var n: int = tr.points.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(1, n):
		out[i] = out[i - 1] + tr.points[i - 1].distance_to(tr.points[i])
	st.arclen[tr.source_cell] = out
	return out


## Per-build memo over WaterField.profile (itself already cached whole-session
## by source_cell — see WaterField._profiles — but every call still pays a
## mutex lock + dictionary hit; this avoids that per vertex/per candidate
## trace too). Safe to call from the chunk worker thread: profile() already
## guards its own cache end-to-end (see WaterField.gd's own comment on why).
static func _trace_profile(st: Dictionary, tr: RiverTrace) -> Dictionary:
	if st.profiles.has(tr.source_cell):
		return st.profiles[tr.source_cell]
	var prof: Dictionary = WaterField.profile(tr, st.region)
	st.profiles[tr.source_cell] = prof
	return prof


## Central-difference profile slope AT sample index i (one-sided at either
## end of the trace) — metres of level drop per metre of arc length, positive
## downstream (matches WaterField.grade_at's own upstream-minus-downstream
## sign convention). Shared by _project_on_trace, which lerps this between a
## segment's two endpoint samples so the baked slope is continuous in s (no
## jump at a sample boundary) rather than the plan's literal single-segment
## secant.
static func _central_slope(arclen: PackedFloat32Array, levels: PackedFloat32Array, i: int) -> float:
	var n: int = levels.size()
	var lo: int = maxi(i - 1, 0)
	var hi: int = mini(i + 1, n - 1)
	if hi <= lo:
		return 0.0
	return (levels[lo] - levels[hi]) / maxf(arclen[hi] - arclen[lo], 0.001)


## Projects p onto trace `tr`'s polyline near sample index `near_si` (a
## nearby-sample hint from the caller's own bucket scan — see
## _flow_frame_at), checking only the (up to) two segments touching that
## sample rather than the whole polyline: TRACE_STEP=12m sample spacing and
## the caller's bucket search radius together mean `near_si` sits within one
## segment of the true nearest point for any query point this file calls with
## (same trust the rest of this file already extends to WaterField's own
## identically-shaped bucket scans — see _flow_frame_at). Returns {} when
## `tr` has no valid segment at all near near_si (a single-sample trace —
## callers already filter tr.points.size()<2 before reaching here, so this is
## defensive, not a real production case on this codebase's traces).
##
## SEGMENT-TIE BLEND (Task 6 review fix — the "bend s-compression" defect,
## caught red on the pinned site and quantified by the reviewer as a third to
## half a wave cycle of Task 8 phase error; r3-task-6-report.md has the
## red->green transcripts). Nearest-point projection onto a polyline is
## genuinely FLAT across the outside wedge of any corner: for a corner C
## between segment directions w1/w2 (exterior angle theta), every query in
## the wedge {r.w1 >= 0, r.w2 <= 0} clamps BOTH candidate feet to C itself,
## so s reads exactly s(C) for the wedge's whole angular width — a shoreline
## walker at offset d crosses d*theta metres of walk (0.96m at the pinned
## site's own bend: d~8.8m, theta~6.2 deg) with ZERO s advance, which
## concentrated the polyline's intrinsic corner arc-length deficit into one
## 1.5m step (measured red: |Δs - step| = 1.008 against the test's 0.5
## bound). The first version hard-picked the strictly-nearest candidate,
## which cannot help — INSIDE the wedge both candidates' clamped s values
## are identical (s(C)), so no pick OR blend of clamped values ever advances.
## The fix blends the two candidates' UNCLAMPED (raw-t extrapolated) arc
## lengths whenever their clamped distances tie within SEG_TIE_BAND: the raw
## extrapolations straddle s(C) by ±d*sin(angle-into-wedge), so their blend
## advances at ~the walk rate through the wedge, spreading the deficit over
## the whole tie band (~2.5 steps either side at this site) instead of one
## step — measured post-fix worst |Δs - step| in the bend window: see the
## report (analytic prediction ~0.30). Blend weight mu = 0.5*(1 - tie/BAND),
## LINEAR in the distance DIFFERENCE, deliberately NOT the junction blend's
## literal 1/d^2: a same-trace tie's two distances are near-EQUAL by
## construction (both ~= the corner distance), so 1/d^2 degenerates to ~50/50
## across the entire band and then snaps to 0 at the band edge — a step of
## ~0.5*(s_far - s_near) ~= 0.46m, i.e. it would reintroduce the very
## discontinuity class being fixed. The difference-driven taper reaches 0
## continuously at the band edge (C0 with the pure-nearest region), and
## SEG_TIE_BAND's own derivation guarantees mu == 0 at every near-sample
## pair-flip locus (see the constant's comment), so the pair swap stays
## seamless. tangent and slope blend by the same mu (tangent renormalized;
## consecutive same-trace segment tangents never oppose, so no sign fix is
## needed, unlike the cross-trace junction blend); `dist`/`proj` stay the
## TRUE nearest's (the RIVER_MAX_DIST gate and the junction 1/d^2 weights
## must read real distances). The blended s clamps to [0, total] as a rail
## against raw-t extrapolation past the trace's global endpoints.
static func _project_on_trace(st: Dictionary, tr: RiverTrace, p: Vector2, near_si: int) -> Dictionary:
	var n: int = tr.points.size()
	var cands: Array = []
	for j in [near_si - 1, near_si]:
		if j < 0 or j + 1 >= n:
			continue
		var a: Vector2 = tr.points[j]
		var b: Vector2 = tr.points[j + 1]
		var seg: Vector2 = b - a
		var seg_len2: float = seg.length_squared()
		var t_raw: float = ((p - a).dot(seg) / seg_len2) if seg_len2 > 0.000001 else 0.0
		var t_c: float = clampf(t_raw, 0.0, 1.0)
		var proj: Vector2 = a + seg * t_c
		var tangent: Vector2 = (seg / sqrt(seg_len2)) if seg_len2 > 0.000001 else Vector2(1, 0)
		cands.append({"j": j, "t_raw": t_raw, "t_c": t_c, "proj": proj,
			"dist": p.distance_to(proj), "tangent": tangent})
	if cands.is_empty():
		return {}
	if cands.size() == 2 and cands[1].dist < cands[0].dist:
		cands.reverse()
	var near: Dictionary = cands[0]
	var arclen: PackedFloat32Array = _trace_arclen(st, tr)
	var prof: Dictionary = _trace_profile(st, tr)
	var levels: PackedFloat32Array = prof.levels
	var s: float = lerpf(arclen[near.j], arclen[near.j + 1], near.t_c)
	var slope: float = _cand_slope(arclen, levels, near)
	var tangent: Vector2 = near.tangent
	if cands.size() == 2:
		var far: Dictionary = cands[1]
		var tie: float = far.dist - near.dist
		if tie < SEG_TIE_BAND:
			var mu: float = 0.5 * (1.0 - tie / SEG_TIE_BAND)
			var s_near_raw: float = lerpf(arclen[near.j], arclen[near.j + 1], near.t_raw)
			var s_far_raw: float = lerpf(arclen[far.j], arclen[far.j + 1], far.t_raw)
			s = clampf(lerpf(s_near_raw, s_far_raw, mu), 0.0, arclen[arclen.size() - 1])
			slope = lerpf(slope, _cand_slope(arclen, levels, far), mu)
			var tb: Vector2 = near.tangent.lerp(far.tangent, mu)
			if tb.length_squared() > 0.000001:
				tangent = tb.normalized()
	var perp := Vector2(-tangent.y, tangent.x)
	var d: float = (p - near.proj).dot(perp)
	return {"dist": near.dist, "s": s, "d": d, "slope": slope, "tangent": tangent, "proj": near.proj}


## One candidate's continuous profile slope: _central_slope at the segment's
## two endpoint samples, lerped by the candidate's own CLAMPED t (slope is
## defined pointwise ALONG the trace, so the tie blend above mixes the two
## candidates' in-range slope reads rather than extrapolating the central-
## difference lerp past a segment end the way the raw-t arc length must).
static func _cand_slope(arclen: PackedFloat32Array, levels: PackedFloat32Array, cand: Dictionary) -> float:
	return lerpf(_central_slope(arclen, levels, cand.j),
		_central_slope(arclen, levels, cand.j + 1), cand.t_c)


## Per-vertex flow frame — the brief's own CUSTOM0 payload (s, d, slope,
## shore_dist), Task 6's core deliverable. Candidate traces are found via
## ctx.buckets (WaterField.ctx's OWN TILE=24m spatial hash over every river
## sample — see WaterField.gd's own `_claim`/`_channel_membership_level` for
## the identical "3x3 bucket-cell scan, one nearest sample per candidate
## trace" pattern mirrored here, per this task's own brief: reuse WaterField's
## existing spatial patterns rather than inventing new ones), then refined to
## a precise segment projection per candidate trace (_project_on_trace).
## Ponds/lakes: no candidate trace within RIVER_MAX_DIST=18m => s=d=slope=0
## (brief's own literal rule) — shore_dist is computed unconditionally, since
## it means "distance to shore" regardless of river/pond mode.
## Junction blending (brief: "two traces within 12m: weight by 1/d^2, blend s
## direction only"): with CUSTOM0 carrying no separate direction channel, "s
## direction" is read here as the LOCAL TANGENT the s axis is measured
## along — s and slope themselves still come entirely from the nearest trace
## alone (the plan doc's own words: "nearest-trace wins"; blending two
## different traces' raw arc-length numbers would be physically meaningless,
## e.g. averaging "1200m along the main stem" with "40m along a tributary").
## What DOES need blending is the axis d's sign is measured against: at a
## confluence, nearest-trace selection flips abruptly from one trace to the
## other as the query point crosses the zone's own midline, and each trace's
## raw tangent can point a different way — an unblended, hard-switched cross
## axis would show as a visible seam in the Task 8 wave direction right at
## that flip line. Blending the tangent (1/d^2-weighted, oriented onto the
## nearest trace's own tangent sense first so a tributary's "downstream"
## doesn't fight the main stem's) makes that axis rotate smoothly through the
## junction instead of snapping, while d's magnitude still reflects the true
## (nearest-trace) cross distance. Recorded here per the plan's own "Known
## judgment points delegated to implementers" note (junction blend falloff,
## Task 6) — see r3-task-6-report.md for the full rationale.
static func _flow_frame_at(st: Dictionary, p: Vector2) -> Dictionary:
	var shore_dist: float = clampf(_nearest_curve_dist(st, p, SHORE_RADIUS_CELLS), 0.0, SHORE_DIST_MAX)
	var ctx: Dictionary = st.ctx
	var cell := Vector2i(int(floor(p.x / WaterField.TILE)), int(floor(p.y / WaterField.TILE)))
	var near_si_by_trace: Dictionary = {}   # river index -> {si, d} nearest SAMPLE (not yet segment-projected)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b: Array = ctx.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var ti: int = ref.x
				var si: int = ref.y
				var sample_d: float = ctx.rivers[ti].points[si].distance_to(p)
				if not near_si_by_trace.has(ti) or sample_d < near_si_by_trace[ti].d:
					near_si_by_trace[ti] = {"si": si, "d": sample_d}
	var projections: Array = []
	for ti in near_si_by_trace:
		var tr: RiverTrace = ctx.rivers[ti]
		if tr.points.size() < 2:
			continue
		var proj: Dictionary = _project_on_trace(st, tr, p, near_si_by_trace[ti].si)
		if not proj.is_empty():
			projections.append(proj)
	if projections.is_empty():
		return {"s": 0.0, "d": 0.0, "slope": 0.0, "shore_dist": shore_dist}
	projections.sort_custom(func(pa, pb): return pa.dist < pb.dist)
	var nearest: Dictionary = projections[0]
	if nearest.dist >= RIVER_MAX_DIST:
		return {"s": 0.0, "d": 0.0, "slope": 0.0, "shore_dist": shore_dist}
	var s: float = nearest.s
	var slope: float = nearest.slope
	var d: float = nearest.d
	if projections.size() > 1 and nearest.dist < JUNCTION_RADIUS and projections[1].dist < JUNCTION_RADIUS:
		var second: Dictionary = projections[1]
		var w1: float = 1.0 / maxf(nearest.dist * nearest.dist, 0.01)
		var w2: float = 1.0 / maxf(second.dist * second.dist, 0.01)
		var t2: Vector2 = second.tangent
		if t2.dot(nearest.tangent) < 0.0:
			t2 = -t2
		var blended: Vector2 = nearest.tangent * w1 + t2 * w2
		if blended.length_squared() > 0.000001:
			var bt: Vector2 = blended.normalized()
			var bperp := Vector2(-bt.y, bt.x)
			d = (p - nearest.proj).dot(bperp)
	return {"s": s, "d": d, "slope": slope, "shore_dist": shore_dist}


## Interior water-surface normal at (p, center_level): a heightfield normal
## from WaterField.level_at central differences at +-1.5m (controller brief's
## own literal probe width), i.e. Vector3(-dh/dx, 1, -dh/dz) normalized. Falls
## back to a ONE-SIDED difference on whichever axis has a dry (-INF) probe
## (an interior lattice point can legitimately sit close enough to INSET=2.0m
## from a curve that one +-1.5m probe crosses it — see _slope_component) so a
## near-shore interior vertex still gets a real, if less precise, slope
## estimate instead of silently dropping to flat UP.
static func _interior_normal(st: Dictionary, p: Vector2, center_level: float) -> Vector3:
	var ctx: Dictionary = st.ctx
	var e := 1.5
	var hx1: float = WaterField.level_at(ctx, p + Vector2(e, 0.0))
	var hx0: float = WaterField.level_at(ctx, p - Vector2(e, 0.0))
	var hz1: float = WaterField.level_at(ctx, p + Vector2(0.0, e))
	var hz0: float = WaterField.level_at(ctx, p - Vector2(0.0, e))
	var dhdx: float = _slope_component(hx0, center_level, hx1, e)
	var dhdz: float = _slope_component(hz0, center_level, hz1, e)
	return Vector3(-dhdx, 1.0, -dhdz).normalized()


## One axis of a central difference, degrading gracefully to a one-sided
## difference when either probe is dry (WaterField.level_at == -INF) and to
## flat (0.0) only when BOTH are — see _interior_normal's own docstring.
static func _slope_component(h_minus: float, h0: float, h_plus: float, e: float) -> float:
	var minus_ok: bool = h_minus > -INF
	var plus_ok: bool = h_plus > -INF
	if minus_ok and plus_ok:
		return (h_plus - h_minus) / (2.0 * e)
	if plus_ok:
		return (h_plus - h0) / e
	if minus_ok:
		return (h0 - h_minus) / e
	return 0.0


## Rim-row normal: UP rotated toward the curve's own outward normal n̂ by
## `angle`, about the (implicit) curve tangent axis — the controller brief's
## own "curl's outward-and-down rotation about the curve tangent". n̂ is
## already a unit Vector2 (WaterContour._outward_normal's own contract) and
## is horizontal (y=0) by construction, so {UP, outward} is an orthonormal
## pair and cos/sin naturally produce a unit result (the .normalized() below
## is defensive against float drift only). angle=0 => exactly UP (row0's own
## case, and every row at a fully wall-pinched point — see _rim's own call
## sites, which lerp `angle` toward 0.0 by the SAME _smoothed_wall blend that
## already pinches reach2/reach3).
static func _curl_normal(nrm2d: Vector2, angle: float) -> Vector3:
	var outward := Vector3(nrm2d.x, 0.0, nrm2d.y)
	return (Vector3.UP * cos(angle) + outward * sin(angle)).normalized()


## Sums accumulated per-weld-key normal contributions (see _weld_vert) into
## one final unit normal per vertex. Summing unit-ish vectors then
## normalizing is the standard vertex-normal-averaging identity (dividing by
## the contributor COUNT first would point the same direction — normalize is
## scale-invariant — so _weld_vert accumulates a running sum only, no count
## needed). A vertex whose contributors happen to cancel exactly (a
## vanishingly unlikely, purely theoretical opposite-pair) falls back to UP
## rather than a zero-length/NaN normal.
static func _bake_normals(st: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(st.normal_accum.size())
	for i in out.size():
		var acc: Vector3 = st.normal_accum[i]
		out[i] = acc.normalized() if acc.length_squared() > 0.000001 else Vector3.UP
	return out


## Assembles the committed ArrayMesh from build()'s own `arrays` — CUSTOM0 as
## RGBA float, the one shared sheet material's own expected surface format.
static func commit(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


## --- Presence-grid acceleration (brief's own "point-in-polygon by winding
## over the chunk's curves + presence-grid acceleration") ---
##
## Buckets every curve point by its floor(p/BUCKET) cell so nearest-point
## lookup only ever scans the query point's own cell + 8 neighbours instead
## of every curve point in the chunk — the same "world-aligned spatial hash"
## acceleration pattern WaterField.ctx's own `buckets` (river samples by 24m
## cell) already uses for the same reason.
static func _build_buckets(curves: Array) -> Dictionary:
	var buckets: Dictionary = {}
	for ci in curves.size():
		var c: Dictionary = curves[ci]
		var pts: PackedVector2Array = c.pts
		for i in pts.size():
			var cell := Vector2i(int(floor(pts[i].x / BUCKET)), int(floor(pts[i].y / BUCKET)))
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(Vector2i(ci, i))
	return buckets


## Nearest curve-point distance to `p`, searched via the bucket (radius_cells
## bucket neighbourhood — 1 comfortably covers any curve point within INSET=
## 2.0 of p given BUCKET=STEP=3.0, since a point up to 2.0m outside p's own
## cell can only ever land in an immediately-adjacent cell). Returns INF when
## no curve point exists within that window — for the INSET gate (see
## _lattice_wet) that already means "far enough from every curve," so the
## caller never needs to widen the search: INF is a fully decided answer, not
## an inconclusive one, unlike a "which side" test that needs a REAL nearest
## point to have any direction to compare against.
static func _nearest_curve_dist(st: Dictionary, p: Vector2, radius_cells: int) -> float:
	var cell := Vector2i(int(floor(p.x / BUCKET)), int(floor(p.y / BUCKET)))
	var best := INF
	for dz in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var b: Array = st.buckets.get(cell + Vector2i(dx, dz), [])
			for ref: Vector2i in b:
				var q: Vector2 = st.curves[ref.x].pts[ref.y]
				best = minf(best, p.distance_to(q))
	return best


## True when p is >= INSET metres inside a curve: WaterField.level_at's own
## field-truth wetness (identical oracle to WaterContour._is_wet — the exact
## source the curves themselves are contours of, so this can never disagree
## with where the curves say the shore is) AND no curve point lies within
## INSET of p (the presence-grid-accelerated bucket scan above — a cheap
## existence check, not a full nearest-point search: for the sole purpose of
## "does anything sit closer than INSET," an early INF from a 1-cell-radius
## bucket scan already means "no," since nothing outside that radius could
## be closer than INSET < BUCKET). See this file's header for why the FIELD
## (not a curve point's own local outward-normal side) decides wet/dry: a
## curve point's normal is only reliable near that point, and this task's
## own test_no_free_edges_except_border caught the geometric-only version
## misclassifying real wet territory 14.6m from the nearest curve point
## across a wide lake.
static func _lattice_wet(st: Dictionary, p: Vector2) -> Dictionary:
	var lvl: float = WaterField.level_at(st.ctx, p)
	if lvl == -INF:
		return {"wet": false, "dist": 0.0}
	var g: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
	if lvl <= g + 0.02:
		return {"wet": false, "dist": 0.0}
	var dist: float = _nearest_curve_dist(st, p, 1)
	return {"wet": dist >= INSET, "dist": dist}


## Builds the kept-point set: 3.0m world-aligned lattice (origin snapped to
## the world STEP grid, same "floor(x/STEP)*STEP" convention WaterContour's
## own presence grid uses — this is what makes two neighbouring chunks'
## lattices land on IDENTICAL world columns/rows at their shared border) over
## `rect`, each point tested by _lattice_wet, height = WaterField.level_at
## (the brief's own rule for interior vertices).
## Index bounds are computed directly from the rect span (a 192m chunk is
## EXACTLY 64 * STEP), NOT filtered through Rect2.has_point: an earlier
## version used has_point as a
## belt-and-braces bounds check and it silently dropped the entire i=64 /
## j=64 column and row — Godot's Rect2.has_point treats the far edge as
## EXCLUSIVE (verified directly: has_point(rect.position+rect.size) is
## false), so the lattice's own rightmost/bottommost world-border column
## never got a vertex at all. That produced a REAL free-edge defect (this
## task's report): the interior mesh's second-to-last column (one lattice
## step shy of the true border) had nothing to zip to — no curve runs there
## either, since the water is simply wet straight through to the border with
## no shoreline in that stretch — leaving a dangling jagged edge nowhere
## near border OR curve. Plain integer index loops need no such filter: the
## chunk span is an exact multiple of STEP by construction, so i/j in
## [0, nx-1]/[0, nz-1] can never leave [origin, origin+span] in the first
## place.
## Returns {"kept": Dictionary[Vector2i -> {p: Vector2, y: float}], "nx": int,
## "nz": int, "origin": Vector2} — kept is keyed by LATTICE INDEX (i,j), not
## world position, so _interior_mesh can do O(1) neighbour lookups.
static func _interior_lattice(st: Dictionary) -> Dictionary:
	var rect: Rect2 = st.rect
	var origin: Vector2 = rect.position
	origin.x = floor(origin.x / STEP) * STEP
	origin.y = floor(origin.y / STEP) * STEP
	var nx: int = int(round((rect.position.x + rect.size.x - origin.x) / STEP)) + 1
	var nz: int = int(round((rect.position.y + rect.size.y - origin.y) / STEP)) + 1
	var kept: Dictionary = {}
	for j in nz:
		for i in nx:
			var p: Vector2 = origin + Vector2(i, j) * STEP
			var w: Dictionary = _lattice_wet(st, p)
			if not w.wet:
				continue
			var y: float = WaterField.level_at(st.ctx, p)
			if y == -INF:
				continue
			kept[Vector2i(i, j)] = {"p": p, "y": y}
	return {"kept": kept, "nx": nx, "nz": nz, "origin": origin}


## Emits the interior sheet: for every 2x2 lattice-cell block whose all 4
## corners are kept, two triangles (a standard quad split, +Y winding — this
## codebase's one water-mesh convention). A kept point missing ANY
## of its 4 potential quads (i.e. it borders at least one dropped neighbour
## or the lattice edge) is recorded into lattice.edge_ring — the jagged
## interior boundary the boundary strip zips onto next.
static func _interior_mesh(st: Dictionary, lattice: Dictionary) -> void:
	var kept: Dictionary = lattice.kept
	var nx: int = lattice.nx
	var nz: int = lattice.nz
	var vi: Dictionary = {}   # Vector2i(i,j) -> vertex index, only for kept points USED by a quad
	var on_edge: Dictionary = {}   # Vector2i(i,j) -> true (kept point touches >=1 missing quad)

	var vert_for := func(ij: Vector2i) -> int:
		if vi.has(ij):
			return vi[ij]
		var e: Dictionary = kept[ij]
		var nrm: Vector3 = _interior_normal(st, e.p, e.y)
		var idx: int = _weld_vert(st, e.p, e.y, nrm)
		vi[ij] = idx
		return idx

	for j in nz - 1:
		for i in nx - 1:
			var c00 := Vector2i(i, j)
			var c10 := Vector2i(i + 1, j)
			var c01 := Vector2i(i, j + 1)
			var c11 := Vector2i(i + 1, j + 1)
			var quad_ok: bool = kept.has(c00) and kept.has(c10) and kept.has(c01) and kept.has(c11)
			if not quad_ok:
				for c: Vector2i in [c00, c10, c01, c11]:
					if kept.has(c):
						on_edge[c] = true
				continue
			var a: int = vert_for.call(c00)
			var b: int = vert_for.call(c10)
			var cc: int = vert_for.call(c11)
			var d: int = vert_for.call(c01)
			for t in [[a, d, cc], [a, cc, b]]:
				for k in 3:
					st.idx.append(t[k])
	# Edge-ring membership is EXACTLY "kept point with a missing IN-RANGE
	# quad" (flagged by the sweep above) — deliberately NOT also every kept
	# point on the lattice's outer index bound. A first version blanket-
	# flagged the outer bound too ("never has all 4 quads available"), which
	# is true but answers the wrong question: a border-row point whose
	# in-chunk quads all exist needs no strip coverage (its missing quads lie
	# ACROSS the chunk border, where the NEIGHBOUR chunk's own lattice —
	# world-aligned, same columns — provides the geometry; a free edge along
	# the border line is the one legitimately-free class this pipeline has).
	# Injecting such points into a curve's ring is not just wasted work — it
	# FOLDS the ring chain:
	# caught red-handed on pond chunk (-4,-18)'s south border, where a wet
	# inlet's horseshoe curve exits the chunk and fully-quad-covered border
	# point (-606,-3456) (5.6m from the curve, inside capture) got chained
	# between (-609,-3456) and (-609,-3453) — a 3.0m-tie the greedy walk
	# broke toward the geometrically wrong side, doubling the chain back on
	# itself and stranding 2 free edges where the fold overlapped the
	# interior quads (this task's report has the full trace).
	lattice["edge_ring"] = on_edge
	lattice["vi"] = vi


## Orders a scattered set of ring points into a "necklace" by greedy nearest-
## neighbour chaining in plain 2D space, starting from whichever ring point
## sits closest to the curve's own first point (so the chain's own start end
## agrees with the curve's index-0 end — see _boundary_strip's own
## direction-agreement requirement). This REPLACED an earlier version that
## sorted ring points by projecting each onto the curve's own arc-length
## parameterization (nearest-point-on-polyline, standard technique) — that
## approach is fundamentally unsound within about one lattice-STEP (3.0m) of
## any curve corner tighter than the lattice spacing: TWO incoming/outgoing
## curve segments meeting at a sharp vertex both clamp their nearest-point
## projection to that SAME vertex for every nearby ring point regardless of
## which side of the corner it is actually on, collapsing distinct points to
## identical (or, with an unclamped-projection variant tried next,
## unreliably ordered) arc values. Measured directly on this task's own
## pinned site (see the report): a genuine L-shaped shore corner at
## (35.23,-1044.02) — already WaterContour's own documented hard case, see
## that file's _outward_normal docstring — produced 2-4 ring points whose
## nearest curve segments were all >2m away at wildly extrapolated
## projection parameters (measured t_raw up to 5.48 on a ~1.5m segment,
## meaningless that far out), so NEITHER arc-projection variant could order
## them correctly; the resulting locally non-monotonic ring left 4 free
## edges stranded exactly at that corner. A pure 2D nearest-neighbour chain
## has no such blind spot: it never touches the curve's own parameterization
## at all, only the ring points' mutual distances, which stay well-behaved
## (each ring point's true nearest ring neighbour is always another ring
## point roughly one lattice STEP away, corner or not) — verified directly
## against the same offending corner: the chain visits ...(30,-1041),
## (33,-1041), (36,-1041), (39,-1041), (39,-1044), (39,-1047)... in exactly
## the geometrically correct order, and independently verified globally
## (sampling the curve's own point index at 7 checkpoints from 0 to 221 and
## finding each one's nearest ring-chain position) that chain order tracks
## curve index order monotonically end to end, not just locally at the
## corner.
## Bucket-accelerated (same BUCKET-sized spatial hash the curve-point lookup
## already uses — ring points are LATTICE points, always exactly STEP=3.0m
## apart from a true neighbour, so a 3x3-bucket search around the current
## chain tip always finds its real nearest unvisited neighbour without
## scanning the whole ring): O(ring_size) amortised per curve instead of the
## naive O(ring_size^2) a linear scan would cost.
static func _order_ring_by_nn_chain(ring_pts: Array, start_ref: Vector2) -> Array:
	var n: int = ring_pts.size()
	if n <= 1:
		return range(n)
	var rbuckets: Dictionary = {}
	for i in n:
		var cell := Vector2i(int(floor(ring_pts[i].x / BUCKET)), int(floor(ring_pts[i].y / BUCKET)))
		if not rbuckets.has(cell):
			rbuckets[cell] = []
		rbuckets[cell].append(i)

	var start_i := 0
	var start_d := INF
	for i in n:
		var d: float = ring_pts[i].distance_to(start_ref)
		if d < start_d:
			start_d = d
			start_i = i

	var visited := PackedByteArray()
	visited.resize(n)
	var order: Array = [start_i]
	visited[start_i] = 1
	var cur := start_i
	for _k in n - 1:
		var cur_p: Vector2 = ring_pts[cur]
		var cell := Vector2i(int(floor(cur_p.x / BUCKET)), int(floor(cur_p.y / BUCKET)))
		var best_i := -1
		var best_d := INF
		var radius := 1
		# Widen the bucket search until a candidate is found — bounded by n
		# (the whole ring), so this always terminates even for a
		# pathologically sparse leftover set near the very end of the chain.
		while best_i == -1 and radius <= n:
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dz)) != radius and radius > 1:
						continue   # only scan the NEW outer ring on widened passes
					for i: int in rbuckets.get(cell + Vector2i(dx, dz), []):
						if visited[i] == 1:
							continue
						var d: float = cur_p.distance_to(ring_pts[i])
						if d < best_d:
							best_d = d
							best_i = i
			radius += 1
		order.append(best_i)
		visited[best_i] = 1
		cur = best_i
	return order


## Bridges curve `c`'s own point chain (one vertex per point, ON the curve,
## at the curve's OWN baked level — the brief's literal rule) to the interior
## lattice's edge-ring vertices that lie near this curve, via a greedy
## two-polyline triangle-strip walk (the standard "zipper" algorithm for
## triangulating the region between two roughly-parallel open polylines: at
## each step, compare the two candidate diagonals — advancing the curve
## cursor vs advancing the ring cursor — and take whichever is SHORTER,
## which keeps the strip from producing long, crossing, or degenerate
## triangles). Both polylines are walked in the SAME direction (the ring is
## pre-ordered by _order_ring_by_nn_chain, whose chain starts at the ring
## point nearest this curve's own first point, so index order on both sides
## already agrees) — this is what guarantees no T-junction: the
## interior lattice's own quad triangulation (_interior_mesh) never emits a
## triangle touching a boundary vertex at all, so the strip is the ONLY
## geometry connecting the two, and every strip triangle shares a full edge
## with its neighbour in the strip, never a partial one.
static func _boundary_strip(st: Dictionary, lattice: Dictionary, c: Dictionary) -> void:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var n: int = pts.size()
	if n < 2:
		return
	# Curve-chain vertices: one per curve point, ON the curve, at its own level.
	# Normal is always exactly UP — this IS row0 (see _rim's own docstring on
	# the weld-key reuse), and row0's curl angle is 0 by design (_curl_normal).
	var curve_vi := PackedInt32Array()
	curve_vi.resize(n)
	for i in n:
		curve_vi[i] = _weld_vert(st, pts[i], levels[i], Vector3.UP)

	# Ring: interior edge-ring points within a short capture radius of THIS
	# curve (a chunk can carry multiple curves — a ring point must only zip
	# to the curve it actually borders, not a distant unrelated one), ordered
	# by 2D nearest-neighbour chaining (_order_ring_by_nn_chain — see its own
	# docstring for why this replaced an arc-length-projection sort).
	# Capture radius is DERIVED from the worst-case edge-ring geometry, not
	# tuned: a kept point lands on the edge ring because one of its quad
	# neighbours was dropped, and an inset-dropped neighbour sits < INSET
	# (2.0m) from the curve; the kept point itself sits at most one lattice
	# diagonal (STEP*sqrt(2) ~= 4.24m) from that neighbour, so a genuine
	# edge-ring point can legitimately lie up to INSET + STEP*sqrt(2) ~= 6.24m
	# from the curve it borders. The first version used STEP*1.8 = 5.4m
	# ("comfortably catches the adjacent lattice row") and was caught
	# under-derived on the isolated-pond chunk (-4,-18): a real edge-ring
	# point at 5.625m (diagonally inside the pond bowl's corner) missed
	# capture, stranding 3 free edges on interior lattice points (this task's
	# report). INSET + STEP*1.5 = 6.5m covers the true bound with slack.
	var capture: float = INSET + STEP * 1.5
	var ring_pts: Array = []
	var ring_y: Array = []
	for ij: Vector2i in lattice.edge_ring:
		var e: Dictionary = lattice.kept[ij]
		var d: float = _dist_point_to_curve(c, e.p)
		if d > capture:
			continue
		ring_pts.append(e.p)
		ring_y.append(e.y)
	if ring_pts.is_empty():
		return   # nothing nearby yet kept (e.g. a sliver curve with no adjacent interior) — no strip to build
	var order: Array = _order_ring_by_nn_chain(ring_pts, pts[0])
	var ring_vi := PackedInt32Array()
	ring_vi.resize(order.size())
	for k in order.size():
		var oi: int = order[k]
		var nrm: Vector3 = _interior_normal(st, ring_pts[oi], ring_y[oi])
		ring_vi[k] = _weld_vert(st, ring_pts[oi], ring_y[oi], nrm)

	_zip_strip(st, curve_vi, ring_vi, c.closed)


## Meniscus rim (Task 5): three new vertex rows per curve point, curling the
## water's visible edge DOWN and OUTWARD (toward the dry bank, +normal) from
## the boundary strip's own curve vertex, then diving under the terrain so
## the sheet always seals against the ground with no gap — the brief's own
## literal per-point profile (local frame: outward normal n, level L, ground
## g):
##   row0 = the EXISTING strip curve vertex (p, L) itself — reused by weld
##          key, NOT a new vertex. This is the load-bearing seam: row0 must
##          resolve to the exact same index _boundary_strip already put in
##          curve_vi (guaranteed by _weld_vert's own key = quantized (x,z,y),
##          identical inputs here (pts[i], levels[i]) to what _boundary_strip
##          just used two lines above the call site in build()). Without this
##          reuse, Task 4's own documented free edge (the curve itself — "no
##          rim yet, the boundary strip's own outer edge IS the waterline's
##          free edge") never gets covered by the row0-row1 band below, and
##          would stay free forever instead of healing into interior mesh —
##          this is the concrete mechanism behind this task's tightened
##          free-edge invariant (see test_free_edges_only_buried_rim_or_border).
##   row1 = p,             y = L - 0.02   (the meniscus crest: a hairline dip
##          right at the water's own edge before the surface curls away —
##          same xz as row0, so this first "riser" is a near-vertical 2cm lip)
##   row2 = p + reach2*n,  y = L - 0.18
##   row3 = p + reach3*n,  y = min(L - 0.30, g(p + reach3*n) - 0.30) (buried
##          seal, ALWAYS >=0.30m under both the water level AND the actual
##          ground sample at its own xz, so it can never pop back above
##          either regardless of local terrain undulation — the "ALWAYS
##          under ground" the brief itself calls out).
## reach2/reach3 default to (RIM_ROW2_REACH, RIM_ROW3_REACH) and pinch toward
## a flush RIM_WALL_PINCH at wall-flagged points (brief: "water meets wall
## flush, no bulge into rock") — SMOOTHED across neighbouring curve points
## (_smoothed_wall, a 3-tap tent filter over the raw wall flags) rather than
## switched hard per point: a lone wall flag flapping true/false between
## adjacent ~1.5m-spaced curve points (a real occurrence near the WALL_SLOPE
## threshold, see WaterContour._attributes' own rise-from-level probe) would
## otherwise zigzag the rim's outer silhouette in and out every segment; the
## smoothed reach eases the pinch in/out over roughly one segment either side
## of a transition instead of jumping.
## Triangulation: 3 "bands" (row0-row1, row1-row2, row2-row3), each a
## standard quad split per curve segment — same [a,d,cc],[a,cc,b] corner
## convention _interior_mesh's own quad split uses (a=row_k[i], b=row_k[j],
## d=row_{k+1}[i], cc=row_{k+1}[j]) — through _emit_tri, so winding stays
## whatever consistent rule the rest of this file already applies; this
## function never picks triangle order by hand. Closed curves wrap (j wraps
## to 0 at the last segment); open curves stop one segment short and instead
## get an end cap at each of their two exposed ends (_rim_end_cap) — without
## it the three riser edges at an open end (row0-row1, row1-row2, row2-row3)
## are each used by exactly one band triangle (no i-1 column to share the
## other side), a real free-edge defect caught directly on SITE_CHUNK's own
## three open (border-to-border) curves before the cap existed (this task's
## report has the transcript).
static func _rim(st: Dictionary, c: Dictionary) -> void:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var normals: PackedVector2Array = c.normals
	var wall: PackedByteArray = c.wall
	var n: int = pts.size()
	if n < 2:
		return
	var closed: bool = c.closed
	var wf: PackedFloat32Array = _smoothed_wall(wall, closed)

	var row0 := PackedInt32Array()
	var row1 := PackedInt32Array()
	var row2 := PackedInt32Array()
	var row3 := PackedInt32Array()
	row0.resize(n)
	row1.resize(n)
	row2.resize(n)
	row3.resize(n)
	for i in n:
		var p: Vector2 = pts[i]
		var nrm: Vector2 = normals[i]
		var lvl: float = levels[i]
		# Curl angle per row, about the curve tangent, pinched toward 0 (UP) at
		# wall points by the SAME wf[i] blend that already pinches reach2/
		# reach3 — see _curl_normal's own docstring.
		var ang1: float = lerpf(RIM_NORMAL_ANGLE1, 0.0, wf[i])
		var ang2: float = lerpf(RIM_NORMAL_ANGLE2, 0.0, wf[i])
		var ang3: float = lerpf(RIM_NORMAL_ANGLE3, 0.0, wf[i])
		row0[i] = _weld_vert(st, p, lvl, Vector3.UP)
		row1[i] = _weld_vert(st, p, lvl - RIM_ROW1_DROP, _curl_normal(nrm, ang1))
		var reach2: float = lerpf(RIM_ROW2_REACH, RIM_WALL_PINCH, wf[i])
		var reach3: float = lerpf(RIM_ROW3_REACH, RIM_WALL_PINCH, wf[i])
		var p2: Vector2 = p + nrm * reach2
		row2[i] = _weld_vert(st, p2, lvl - RIM_ROW2_DROP, _curl_normal(nrm, ang2))
		var p3: Vector2 = p + nrm * reach3
		var g3: float = TerrainSurfaceField.surface_y(st.region, p3.x, p3.y)
		var y3: float = minf(lvl - RIM_ROW3_DROP, g3 - RIM_GROUND_BURY)
		row3[i] = _weld_vert(st, p3, y3, _curl_normal(nrm, ang3))

	var lim: int = n if closed else n - 1
	for i in lim:
		var j: int = (i + 1) % n
		_emit_tri(st, row0[i], row1[i], row1[j])
		_emit_tri(st, row0[i], row1[j], row0[j])
		_emit_tri(st, row1[i], row2[i], row2[j])
		_emit_tri(st, row1[i], row2[j], row1[j])
		_emit_tri(st, row2[i], row3[i], row3[j])
		_emit_tri(st, row2[i], row3[j], row2[j])

	if not closed:
		_rim_end_cap(st, row0[0], row1[0], row2[0], row3[0])
		var last: int = n - 1
		_rim_end_cap(st, row0[last], row1[last], row2[last], row3[last])


## Caps an open curve's rim ladder at one exposed end (see _rim's own
## docstring for why this is needed). A 2-triangle fan from row0 through
## row1/row2/row3 — (row0,row1,row2) and (row0,row2,row3) — shares an edge
## with each of the three band triangles that otherwise left row0-row1,
## row1-row2, row2-row3 single-used (now double-used, healed), at the cost of
## exactly one NEW free edge: the fan's own closing diagonal row0-row3. That
## is the minimum any triangulation of an open 4-point profile can achieve —
## the quad (row0,row1,row2,row3) has 4 boundary edges, 3 already carry one
## use each from the bands, so 2 triangles can heal those 3 but must open a
## 4th boundary edge to close the shape (any 2-triangle fan, from any apex,
## has this same count — verified by hand for all four apex choices before
## picking row0, the simplest to reach from this call site). The remaining
## row0-row3 edge is itself accounted for under this task's tightened
## invariant: row0 sits exactly at the curve's own point, which for every
## open curve WaterContour._clip_to_rect produces is an exact chunk-border
## crossing (verified directly on both pinned sites — SITE_CHUNK's three
## open curves and the pond chunk's horseshoe — this task's report has the
## coordinates), and row3 trivially satisfies the buried-outer-row test at
## distance 0 from itself.
static func _rim_end_cap(st: Dictionary, i0: int, i1: int, i2: int, i3: int) -> void:
	_emit_tri(st, i0, i1, i2)
	_emit_tri(st, i0, i2, i3)


## Tent-filtered (0.25/0.5/0.25) copy of `wall` as a continuous per-point
## blend weight for _rim's own reach2/reach3 lerp — see _rim's docstring for
## why a hard per-point pinch switch zigzags the rim at wall/shore
## transitions. Open curves clamp at their own ends (duplicate the edge
## value, the standard fixed-boundary convention for a 1D filter); closed
## curves wrap.
static func _smoothed_wall(wall: PackedByteArray, closed: bool) -> PackedFloat32Array:
	var n: int = wall.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var prev_i: int = (i - 1 + n) % n if closed else maxi(i - 1, 0)
		var next_i: int = (i + 1) % n if closed else mini(i + 1, n - 1)
		out[i] = 0.25 * float(wall[prev_i]) + 0.5 * float(wall[i]) + 0.25 * float(wall[next_i])
	return out


## Position lookup for a welded vertex index — used by the zipper's own
## distance comparisons (verts are already in world space post-weld, so this
## is just an array read, not a recompute).
static func _vpos(st: Dictionary, vi: int) -> Vector3:
	return st.verts[vi]


## The zipper walk itself: bridges chain A (curve, size n) to chain B (sorted
## ring, size m) with a greedy shortest-diagonal triangle strip. `closed`
## wraps A back to index 0 at the end (a closed curve's own last point
## connects to its first). Every read of A's frontier vertex goes through
## `a[i % n]`, never `a[i]` raw: with closed=true the A-cursor legitimately
## exhausts AT i == end_a == n (one past the last index — the state meaning
## "wrapped fully back to a[0]"), and the B-only advance branch still needs
## the frontier vertex then — a raw a[i] read there is an out-of-bounds
## crash, caught red-handed on the isolated-pond chunk (-4,-18)'s closed
## curve (n=124: "Out of bounds get index '124'", trace in this task's
## report; the open-curve site chunk never trips it because an open A stops
## at end_a == n-1, a valid index). For open curves i % n == i in every
## reachable state, so the wrap arithmetic is a no-op there.
## CLOSED-ANNULUS CLOSING TRIANGLE: for a closed curve the strip region
## between the curve loop and its ring is an annulus — after the main walk
## ends (frontier edge (a[0], b[m-1]), since A has wrapped to a[0] and B
## stands at its last point) the strip must close back to its own START
## edge (a[0], b[0]) or the gap between the ring's last and first points is
## left as a hole in the sheet (free edges on interior lattice points,
## nowhere near curve or border). The two edges share a[0], so ONE triangle
## (a[0], b[m-1], b[0]) spans the gap exactly. m == 1 needs none (the walk
## already fanned every A segment around the single ring vertex); open
## curves need none (their strip has two genuine ends, not a loop).
static func _zip_strip(st: Dictionary, a: PackedInt32Array, b: PackedInt32Array, closed: bool) -> void:
	var n: int = a.size()
	var m: int = b.size()
	if m == 0:
		return
	var end_a: int = n if closed else n - 1   # closed: n segments (wraps); open: n-1 segments
	var i := 0
	var j := 0
	while i < end_a or j < m - 1:
		var can_adv_a: bool = i < end_a
		var can_adv_b: bool = j < m - 1
		if can_adv_a and can_adv_b:
			var a_next: int = a[(i + 1) % n]
			# Candidate 1: advance A — triangle (a[i], a_next, b[j]).
			var d1: float = _vpos(st, a_next).distance_to(_vpos(st, b[j]))
			# Candidate 2: advance B — triangle (a[i], b[j+1], b[j]).
			var d2: float = _vpos(st, a[i % n]).distance_to(_vpos(st, b[j + 1]))
			if d1 <= d2:
				_emit_tri(st, a[i % n], a_next, b[j])
				i += 1
			else:
				_emit_tri(st, a[i % n], b[j + 1], b[j])
				j += 1
		elif can_adv_a:
			var a_next2: int = a[(i + 1) % n]
			_emit_tri(st, a[i % n], a_next2, b[j])
			i += 1
		else:
			_emit_tri(st, a[i % n], b[j + 1], b[j])
			j += 1
	if closed and m >= 2:
		_emit_tri(st, a[0], b[m - 1], b[0])


## Emits one strip triangle. Winding: the curve chain `a` runs along the
## WATER'S edge and the ring chain `b` runs along the interior (wet) side —
## for the sheet to wind +Y (this codebase's one water-mesh convention), the
## triangle order (p0, p1, p2) must place the INTERIOR vertex so the
## computed normal points up; empirically fixed against the interior mesh's
## own known-+Y quads (see test_all_triangles_wind_up-style check in this
## task's own test suite) as (p_a_first, p_b_or_a_next, p_ring_or_a) below.
static func _emit_tri(st: Dictionary, i0: int, i1: int, i2: int) -> void:
	var v0: Vector3 = st.verts[i0]
	var v1: Vector3 = st.verts[i1]
	var v2: Vector3 = st.verts[i2]
	var nrm: Vector3 = (v1 - v0).cross(v2 - v0)
	var order: Array = [i0, i1, i2] if nrm.y >= 0.0 else [i0, i2, i1]
	for k in order:
		st.idx.append(k)


## Distance from p to curve c's own polyline (segment-nearest, not just
## point-nearest) — used only to gate which ring points capture to which
## curve when a chunk carries several (a straight point-to-point distance
## can miss a ring point that projects cleanly onto a segment MIDPOINT).
static func _dist_point_to_curve(c: Dictionary, p: Vector2) -> float:
	var pts: PackedVector2Array = c.pts
	var n: int = pts.size()
	var lim: int = n if c.closed else n - 1
	var best := INF
	for i in lim:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var seg: Vector2 = b - a
		var seg_len2: float = seg.length_squared()
		var t: float = clampf((p - a).dot(seg) / seg_len2, 0.0, 1.0) if seg_len2 > 0.000001 else 0.0
		best = minf(best, p.distance_to(a + seg * t))
	return best


## Shared weld: dedupes by quantized (x, z, y*64) per the brief's explicit
## key — WELD_XZ_Q (1cm) horizontal precision is finer than the y*64
## (~1.6cm) vertical precision because two DIFFERENT strip triangles
## legitimately reuse the exact SAME curve point (a curve-chain vertex is
## referenced by every triangle touching that point along the strip) and
## must resolve to one shared index, while two merely-nearby interior lattice
## points must NOT collapse into each other.
## Task 6: also accumulates `nrm` into the parallel normal_accum array (see
## _bake_normals) — a weld HIT adds another contributor to the SAME index's
## running sum (welded verts average, per the controller brief) instead of
## keeping whichever call site happened to create the vertex first; a weld
## MISS seeds the new vertex's own first (and often only) contributor.
static func _weld_vert(st: Dictionary, p: Vector2, y: float, nrm: Vector3) -> int:
	var key := Vector3i(roundi(p.x * WELD_XZ_Q), roundi(p.y * WELD_XZ_Q), roundi(y * WELD_Q))
	if st.weld.has(key):
		var idx: int = st.weld[key]
		st.normal_accum[idx] = st.normal_accum[idx] + nrm
		return idx
	var idx: int = st.verts.size()
	st.verts.append(Vector3(p.x, y, p.y))
	st.weld[key] = idx
	st.normal_accum.append(nrm)
	return idx


## Triggers (r3 Task 7 — real wiring, not scaffolding): one box per 24m TILE
## touched by any built vertex (kept interior, boundary-strip, OR rim),
## footprint from this class's own presence data (`st.verts`) — top = max
## level in the tile + TRIGGER_TOP_CLEAR, bottom = min ground in the tile -
## TRIGGER_BOTTOM_CLEAR (this codebase's existing swim-trigger tiling/
## clearance convention). A tile whose max |grade_at| exceeds
## STEEP_UNSWIMMABLE gets NO trigger at all — see that constant's own
## docstring; a fall face is not swimmable water by design, so a character
## must fall/slide through it rather than float. WaterSurfaceBuilder.
## build_chunk turns every entry here into an Area3D carrying
## set_meta("sampler", sampler) (build()'s own single frozen WaterSampler for
## the whole chunk) — there is no more per-cell sampled-plane meta pair; a
## query anywhere inside the box reads that one snapshot instead (see
## WaterSampler.gd).
static func _triggers(st: Dictionary) -> Array:
	var cells: Dictionary = {}   # Vector2i cell -> {top: float, bottom: float, max_grade: float}
	for v: Vector3 in st.verts:
		var cell := Vector2i(int(floor(v.x / TILE)), int(floor(v.z / TILE)))
		var g: float = TerrainSurfaceField.surface_y(st.region, v.x, v.z)
		var grade: float = absf(WaterField.grade_at(st.ctx, Vector2(v.x, v.z)))
		if not cells.has(cell):
			cells[cell] = {"top": v.y, "bottom": g, "max_grade": grade}
		else:
			cells[cell].top = maxf(cells[cell].top, v.y)
			cells[cell].bottom = minf(cells[cell].bottom, g)
			cells[cell].max_grade = maxf(cells[cell].max_grade, grade)
	var out: Array = []
	for cell: Vector2i in cells:
		var e: Dictionary = cells[cell]
		if e.max_grade > STEEP_UNSWIMMABLE:
			continue   # steep water: no trigger, unswimmable by design
		out.append({
			"rect": Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE),
			"top": e.top + TRIGGER_TOP_CLEAR,
			"bottom": e.bottom - TRIGGER_BOTTOM_CLEAR,
		})
	return out
