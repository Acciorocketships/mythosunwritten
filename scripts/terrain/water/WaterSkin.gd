# A boundary-conforming water sheet whose outer rim sits directly on
# WaterContour's smooth curves (Task 3), not on the old marching-squares
# mesher's own grid corners — this is the mesh that actually fixes the
# angular shoreline test_water_contour.gd's header documents. Two vertex
# families welded into one indexed surface:
#   - INTERIOR: a 2.0m world-aligned render lattice, kept only at points >= 2.0m
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
# MENISCUS RIM (Task 5, see _rim): five more rows per curve point, curling
# OUTWARD (dry side) and DOWN from the strip's own curve vertex (reused as
# row0) into either a buried bank seal or a compact rounded free/drop edge.
# This is what heals the strip's
# own former free edge (the curve itself, Task 4's documented "no rim yet"
# waterline) into interior geometry — the free-edge invariant TIGHTENS here:
# only true chunk borders or row5 (buried beneath a bank, or the bottom of a
# finite 65cm free-edge lobe) may be free edges from this task onward.
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
# ARRAY_COLOR.r carries a depth-limited displacement scale. The ambient
# spectrum plus packet-field clamp can trough by at most 1.0m, so shallow
# water retains 2cm of cover over the rendered bed. CUSTOM1 separately bakes
# the continuous current/vorticity/compression shared by GPU and CPU users.
# TRIGGERS + SAMPLER (Task 7, see _triggers/WaterSampler.gd): build() now
# returns a REAL `sampler` (a frozen WaterSampler snapshot of the water
# FIELD across this chunk: native 6m fill plus sparse 3m topology rescue,
# covering the FULL wet footprint including the INSET shoreline band — see
# WaterSampler.gd's own BACKING DATA note) instead of Task 4-6's `null`
# placeholder. `_triggers` gained the STEEP_UNSWIMMABLE gate the old
# marching-squares mesher's own volume builder used to enforce per 24m
# CELL: a tile whose max |grade_at| exceeds the gate gets no trigger box at
# all (steep water is not swimmable by design). This is the class's own
# terminal deliverable — WaterSurfaceBuilder.build_chunk now consumes
# `triggers`/`sampler` directly and the old mesher (and the per-cell sampled
# plane pair of metas it used to hang off each volume) is deleted outright;
# see r3 Task 7's report for the removal.
# SHORE CONTACT + FREE-EDGE BODY: ordinary rising banks use a compact
# overshoot; a contour wall flag earns the 1.5m KayKit recess reach only when
# that point's own outward column actually contacts high ground there. This
# prevents a flanking wall from stretching an unbounded edge into a skirt.
# A true drop instead keeps a compact 0.64m profile: 4cm crest, then rows at
# -6cm, -28cm, -55cm, and -65cm. It reads as finite rounded substance rather than a
# zero-thickness plane or a row teleported to the landing ground.
class_name WaterSkin
extends Object

const STEP := 2.0             # render lattice: resolves broad geometric wave packets without aliasing
const SAMPLER_STEP := 3.0     # CPU/current lattice: stable gameplay resolution and bounded worker cost
const CURRENT_HALO := 2       # matches WaterCurrentField's finite signed-distance support
const INSET := 2.0            # brief's own "points >= 2.0m inside a curve"
const BUCKET := 3.0           # presence-grid bucket size for nearest-curve-point acceleration
const WELD_Q := 64.0          # position-quantize scale for the shared vertex weld (brief: "y*64")
const WELD_XZ_Q := WELD_Q     # one 1/64m world-space weld cell on every axis
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
# Second trigger gate (Task 7 "Defect B", sub-tile-reconciled Task 9,
# RETIRED r3 Task 12b — see r3-task-12b-report.md for the full proof): a
# level-SPREAD heuristic (a whole-tile fast path, then a finer 6m sub-tile
# fallback) used to catch a cascade-step tile carrying fill water at an
# UPSTREAM reach's flat level over the face between it and a downstream
# reach — up to the full inter-reach step of phantom standing depth over
# what rendered as a thin film. That shape was a direct consequence of the
# OLD stepped profile model (pre r3 Task 12): one flat level per reach, a
# hard cut at each trace sample, so a whole shelf could stand unblended over
# a downstream face the fill could not otherwise reach.
#
# r3 Task 12/12a's smooth monotone descent (WaterField._dense_span_curve, a
# sill-riding Fritsch-Carlson-tangent envelope) removes the flat shelf this
# heuristic depended on: every point along a descent now gets its OWN
# locally-fit level instead of a shared plateau, so WaterField.level_at (and
# this class's own WaterSampler snapshot) already reads the honest LOCAL
# value everywhere a trigger might cover — proven at the site's own
# historical phantom points (the I1 chute film point, the 5.7 plunge-pool
# centre, and a third cascade cell this task's own audit found still gated)
# via level_at landing close to the local profile trend, never the old
# upstream shelf (~9.7). Deleting the whole mechanism outright — the
# whole-tile AND sub-tile constants, the _tile_level_spread/
# _level_spread_over dense scan, and _sub_tile_triggers' hot/one-hop-
# propagate logic — was the owner's own preference once the class it existed
# to catch was proven dead by construction, over carrying dead machinery
# "just in case". Triggers are simple wet-tile coverage now: STEEP_UNSWIMMABLE
# (above) is the ONLY remaining exclusion, because it is the one gate keyed
# on real TERRAIN steepness (a genuine unswimmable fall face), not on the
# fill's own internal level bookkeeping — which a smooth ramp can no longer
# use to distinguish "phantom shelf" from "ordinary legal slope" (a
# sustained-but-legal sloped reach can concentrate real, swimmable rise
# inside a small window exactly the same way a genuine cascade step does;
# smoothness and spread-based suppression turned out to be mutually
# exclusive by construction — see r3-task-12-report.md's own follow-up
# section and r3-task-12b-report.md for the closing argument).

# --- Meniscus rim (Task 5, reshaped r3 Task 14 — see _rim's own docstring)
# — per-point profile, local frame (outward normal n, level L, ground g):
# row0 = the strip's own curve vertex (weld-reused, not a new position);
# row1 = p + 0.12n, y=L+0.04 (rounded crest, no vertical seam);
# rows2..5 curl down through L-0.06, L-0.28, L-0.55, L-0.65. Their default
# reaches are 0.30/0.48/0.60/0.64m. The last two reaches are deliberately
# spaced so successive tangents keep rotating outward/down; the former
# 0.52/0.56 pair made the penultimate segment nearly vertical and the final
# segment shallower again, an inward/concave hook. Rising banks extend to
# 0.40/0.60/0.70/0.78m; confirmed recessed walls first measure the distance
# from the signed-depth contour to the real terrain boundary, then continue a
# further 1.5m through the recessed KayKit face.  Their level shelf extends
# 0.30m behind that visible face before curling down. A point whose own 0.40m column
# drops below L forcibly keeps the compact profile unless its own 1.50m
# column really contacts the recessed wall.
const RIM_ROW1_BULGE := 0.04
const RIM_ROW2_DROP := 0.06
const RIM_ROW3_DROP := 0.28
const RIM_ROW4_DROP := 0.55
const RIM_ROW5_DROP := 0.65
const RIM_ROW1_REACH := 0.12
const RIM_ROW2_REACH := 0.30
const RIM_ROW3_REACH := 0.48
const RIM_ROW4_REACH := 0.60
const RIM_ROW5_REACH := 0.64
const RIM_RISE_REACH := 0.40
const RIM_RISE_BURY_REACH := 0.60
# KayKit's visible wall/lip line is 1.5m inside the high cell from its true
# +/-12m terrain boundary. Wall shores therefore reach the measured terrain
# contact first, then continue another 1.5m before they physically meet the
# visible rock. Ordinary rising banks retain the compact blob profile above;
# only WaterContour's independently-probed wall points use this.
const RIM_WALL_REACH := WaterField.TILE * 0.5 - CliffDressing.PLACE
const RIM_WALL_SHELF_BURY := 0.30
const RIM_WALL_OUTER_BURY := 0.40
# The waterline is a signed-depth contour interpolated on WaterField's 6m
# lattice, so it does not necessarily sit on the terrain cell boundary.  A
# fixed RIM_WALL_REACH therefore accounts for the KayKit recess but can omit
# the additional contour-to-boundary distance. Search within the same finite
# 6m support that created the signed-depth contour. A straight wall stays
# high at the far probe; a diagonal corner arm can leave this normal column
# before 6m, so a separately bounded local-sustain probe accepts a real face
# without turning a one-sample spike into a recessed wall.
const WALL_CONTACT_SCAN_STEP := 0.05
const WALL_CONTACT_SCAN_MAX := WaterField.FILL_STEP
const WALL_CONTACT_LOCAL_SUSTAIN := 0.25
# Chaikin smoothing deliberately improves the contour silhouette, but can
# move its curve inward from the field's actual signed-depth zero. The rim
# must stay level across any still-wet part of its own outward column and
# begin its curl only after field truth becomes dry. This uses the same scan
# resolution/support as wall contact so the two contact mechanisms agree.
const WET_SHELF_SCAN_STEP := WALL_CONTACT_SCAN_STEP
const WET_SHELF_SCAN_MAX := WALL_CONTACT_SCAN_MAX
# At a convex wall turn, independently extruded columns form a diagonal chord
# across the L-shaped contact and omit the corner.  Intersect their wall
# tangents to form a proper miter, but reject pathologically distant
# intersections. WaterField.FILL_STEP is the natural upper bound: no valid
# signed-depth contour can retreat more than one source lattice cell from the
# boundary it interpolates.
const WALL_MITER_DOT_MAX := 0.8
const WALL_MITER_LIMIT := WaterField.FILL_STEP
const WALL_MITER_BURY := 0.10

# The boundary zipper bridges a smooth 1.5m contour to a 2m interior
# lattice.  Its old greedy walk could emit a single ~6-7m fan at a narrow
# corner even though both chains were locally valid.  Such a face is large
# enough for its interpolated normal/refraction to read as a separate water
# polygon (the owner's cell (5,-49) screenshot).  Boundary faces are now
# adaptively split back to the interior lattice's own maximum edge scale.
const STRIP_EDGE_MAX := STEP * 1.41421356237 + 0.01
# r3 Task 14 review fix (drop-misfire): "rising" is confirmed along the SPAN
# the overshoot actually covers, sampled at the row's own landing distances —
# NOT at a far 1m probe that can sit past a local dip the overshoot floats
# over. RISE_PROBE_NEAR (row2's near half) and RIM_RISE_REACH (row2's landing)
# bracket the covered span; BOTH must clear the water level for the point to
# count as rising (an AND, replacing the review-flagged far-probe OR).
const RISE_PROBE_NEAR := RIM_RISE_REACH * 0.5   # 0.20 — the near end of the covered span
const RISE_MARGIN := 0.05      # clearance above L before a ground sample counts as a genuine rise (not float/interp noise on near-flat ground)

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
const SWELL_SHORE_FADE := 4.0
const SWELL_TROUGH_BOUND := 1.40 # 0.51m ambient + 0.48m packets + 0.375m interactive ripple, rounded up
const SWELL_BED_COVER := 0.02    # never let a trough uncover rendered terrain

# --- Rim normals (controller addition) — curl-rotation angle per rim row,
# about the curve tangent, sweeping from UP toward the curve's own outward
# normal n̂: row0 is always exactly UP (the meniscus crest reads as flat
# water, matching the interior lattice it welds into — see _rim's own row0 =
# strip-vertex reuse); rows 1-3 rotate UP toward n̂ by an increasing angle,
# pinched back toward 0 (UP) at wall-flagged points by the SAME
# _smoothed_flags(wall, ...) blend _rim already uses — a flush wall curtain
# reads as near-UP, not as a horizontal cliff face, per the controller
# brief's own "wall-pinched near-UP" rule. r3 Task 14: this angle pinch stays
# WALL-flag-only, deliberately NOT keyed off the broader `rise` signal that
# now drives reach2/reach3's own overshoot (see _rim's own docstring) — a
# gently rising, non-wall bank should still curl its shading normal outward
# normally; only a near-vertical wall wants the flush-UP read. Expressed as
# PI-based literals (not deg_to_rad calls) so they fold to true GDScript
# constants.
const RIM_NORMAL_ANGLE1 := PI / 18.0          # 10 deg — row1, short outward crest
const RIM_NORMAL_ANGLE2 := PI * 2.0 / 9.0     # 40 deg — row2, the visible curl
const RIM_NORMAL_ANGLE3 := PI * 13.0 / 36.0   # 65 deg — row3, buried seal (invisible; kept continuous, not visually tuned)


## build(water, chunk, region) -> {} when dry, else:
##   arrays: Array           # Mesh.ARRAY_MAX arrays, indexed, welded (VERTEX/NORMAL/INDEX/CUSTOM0/COLOR)
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
static func build(water: WaterPlan, chunk: Vector2i, region,
		field_context: WaterFieldContext = null) -> Dictionary:
	var ctx: Dictionary = field_context.raw_context() if field_context != null \
		else WaterField.ctx(water, chunk, region)
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
	lattice["ring_owner"] = _assign_ring_owners(lattice, curves)
	for ci in curves.size():
		var c: Dictionary = curves[ci]
		_boundary_strip(st, lattice, c, ci)
		_rim(st, c)
	_seal_local_surface_holes(st)
	if st.idx.is_empty():
		return {}

	var sampler_grid: Dictionary = _sampler_grid(rect)
	var current: Dictionary = _current_grid(st, sampler_grid.origin, SAMPLER_STEP,
		sampler_grid.nx, sampler_grid.nz)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st.verts
	arrays[Mesh.ARRAY_INDEX] = st.idx
	arrays[Mesh.ARRAY_NORMAL] = _bake_normals(st)
	var payload: Dictionary = _vertex_payload(st, current)
	arrays[Mesh.ARRAY_CUSTOM0] = payload.custom0
	arrays[Mesh.ARRAY_CUSTOM1] = payload.custom1
	arrays[Mesh.ARRAY_COLOR] = payload.colors

	# Sampler bake: the FIELD across this chunk, on a fixed 3m CPU grid
	# independent of render tessellation (Task 7 review MEDIUM fix — the render lattice insets
	# INSET away from the waterline, so it is NOT a full-coverage height
	# source; see WaterSampler.gd's own BACKING DATA note). r3 Task 9: also
	# bake the flow frame (s, d, slope) onto the SAME grid via this file's
	# own _flow_frame_at (the CUSTOM0 bake's own per-vertex function, reused
	# here rather than duplicated — see _flow_frame_grid) so the sampler can
	# answer flow_frame_at for any (x,z), not just a mesh vertex. Current and
	# future gameplay consumers therefore read a continuous, non-vertex-snapped
	# hydraulic frame.
	var flow: Dictionary = _flow_frame_grid(st, sampler_grid.origin, SAMPLER_STEP,
		sampler_grid.nx, sampler_grid.nz)
	var sampler := WaterSampler.build(ctx, region, sampler_grid.origin, SAMPLER_STEP,
		sampler_grid.nx, sampler_grid.nz, flow.s, flow.d, flow.slope, flow.wave_scale,
		current.velocity, current.vorticity, current.compression)
	return {"arrays": arrays, "triggers": _triggers(st), "sampler": sampler}


## Fixed world-aligned CPU grid. It deliberately stays independent of the
## denser render tessellation: current queries do not become more expensive
## merely because visual wavelets need more vertices.
static func _sampler_grid(rect: Rect2) -> Dictionary:
	var origin: Vector2 = rect.position
	origin.x = floor(origin.x / SAMPLER_STEP) * SAMPLER_STEP
	origin.y = floor(origin.y / SAMPLER_STEP) * SAMPLER_STEP
	var nx: int = int(round((rect.end.x - origin.x) / SAMPLER_STEP)) + 1
	var nz: int = int(round((rect.end.y - origin.y) / SAMPLER_STEP)) + 1
	return {"origin": origin, "nx": nx, "nz": nz}


## Bakes _flow_frame_at onto the SAMPLER's grid geometry (same origin/step/
## nx/nz as the level bake immediately above — see WaterSampler.build's own
## flow-grid params) instead of the mesh's own vertex positions, so
## WaterSampler.flow_frame_at (r3 Task 9) can answer "what river frame
## applies HERE" for ANY (x,z) in the chunk. One extra _flow_frame_at call
## per grid corner (nx*nz, the same cost class as the level bake right next
## to it, and reusing the SAME per-build arclen/profile memo caches on `st`
## — see _trace_arclen/_trace_profile) — a second full field-density bake
## paid once per chunk build on the worker thread (Task 11 perf-pass item,
## same bucket as _custom0's own per-vertex call and the trigger gates'
## per-vertex grade_at reads).
static func _flow_frame_grid(st: Dictionary, origin: Vector2, step: float, nx: int, nz: int) -> Dictionary:
	var s := PackedFloat32Array()
	var d := PackedFloat32Array()
	var slope := PackedFloat32Array()
	var wave_scale := PackedFloat32Array()
	s.resize(nx * nz)
	d.resize(nx * nz)
	slope.resize(nx * nz)
	wave_scale.resize(nx * nz)
	for j in nz:
		for i in nx:
			var p: Vector2 = origin + Vector2(i, j) * step
			var frame: Dictionary = _flow_frame_at(st, p)
			var idx: int = j * nx + i
			s[idx] = frame.s
			d[idx] = frame.d
			slope[idx] = frame.slope
			var lvl: float = WaterField.level_at(st.ctx, p)
			wave_scale[idx] = _swell_scale(st, p, lvl, frame.shore_dist) if lvl != -INF else 0.0
	return {"s": s, "d": d, "slope": slope, "wave_scale": wave_scale}


## Builds one continuous horizontal current from the hydraulic trace frame
## and a two-cell signed-distance halo. The halo is sampled from the shared
## WaterField/terrain fields, then discarded after the local bank projection;
## neighbouring chunks therefore bake the same retained border values.
static func _current_grid(st: Dictionary, origin: Vector2, step: float,
		nx: int, nz: int) -> Dictionary:
	var h: int = CURRENT_HALO
	var hnx: int = nx + h * 2
	var hnz: int = nz + h * 2
	var horigin: Vector2 = origin - Vector2.ONE * (step * float(h))
	var desired := PackedVector2Array()
	var wet := PackedByteArray()
	desired.resize(hnx * hnz)
	wet.resize(hnx * hnz)
	for j in hnz:
		for i in hnx:
			var k: int = j * hnx + i
			var p: Vector2 = horigin + Vector2(i, j) * step
			var lvl: float = WaterField.level_at(st.ctx, p)
			if lvl == -INF:
				continue
			var ground: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
			var depth: float = lvl - ground
			if depth <= WaterSampler.WET_EPS:
				continue
			wet[k] = 1
			var frame: Dictionary = _flow_frame_at(st, p)
			if frame.width <= 0.0 or frame.tangent.length_squared() <= 0.000001:
				continue
			var speed: float = WaterCurrentField.trace_speed(depth, frame.width,
				absf(frame.slope))
			var centre: float = clampf(1.0 - absf(frame.d) / maxf(frame.width, 1.0), 0.0, 1.0)
			var channel_scale: float = lerpf(0.55, 1.0,
				smoothstep(0.0, 1.0, centre))
			desired[k] = frame.tangent * speed * channel_scale
	var signed_bank: PackedFloat32Array = WaterCurrentField.signed_distance(
		wet, hnx, hnz, step)
	var solved: Dictionary = WaterCurrentField.solve_local(desired, signed_bank,
		hnx, hnz, step)
	var velocity := PackedVector2Array()
	var vorticity := PackedFloat32Array()
	var compression := PackedFloat32Array()
	velocity.resize(nx * nz)
	vorticity.resize(nx * nz)
	compression.resize(nx * nz)
	for j in nz:
		for i in nx:
			var dst: int = j * nx + i
			var src: int = (j + h) * hnx + i + h
			velocity[dst] = solved.velocity[src]
			vorticity[dst] = solved.vorticity[src]
			compression[dst] = solved.compression[src]
	return {
		"origin": origin, "step": step, "nx": nx, "nz": nz,
		"velocity": velocity, "vorticity": vorticity, "compression": compression,
	}


## Bilinear current lookup for arbitrary render vertices, including the
## contour/rim vertices that do not lie on the CPU grid.
static func _current_at(current: Dictionary, p: Vector2) -> Dictionary:
	var fx: float = clampf((p.x - current.origin.x) / current.step,
		0.0, float(current.nx - 1))
	var fz: float = clampf((p.y - current.origin.y) / current.step,
		0.0, float(current.nz - 1))
	var i0: int = mini(int(floor(fx)), current.nx - 2)
	var j0: int = mini(int(floor(fz)), current.nz - 2)
	var tx: float = fx - float(i0)
	var tz: float = fz - float(j0)
	var velocity := Vector2.ZERO
	var vorticity := 0.0
	var compression := 0.0
	for corner: Vector3 in [
		Vector3(i0, j0, (1.0 - tx) * (1.0 - tz)),
		Vector3(i0 + 1, j0, tx * (1.0 - tz)),
		Vector3(i0, j0 + 1, (1.0 - tx) * tz),
		Vector3(i0 + 1, j0 + 1, tx * tz),
	]:
		var idx: int = int(corner.y) * current.nx + int(corner.x)
		velocity += current.velocity[idx] * corner.z
		vorticity += current.vorticity[idx] * corner.z
		compression += current.compression[idx] * corner.z
	return {"velocity": velocity, "vorticity": vorticity, "compression": compression}


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
static func _vertex_payload(st: Dictionary, current: Dictionary) -> Dictionary:
	var cust := PackedFloat32Array()
	var cust1 := PackedFloat32Array()
	var colors := PackedColorArray()
	cust.resize(st.verts.size() * 4)
	cust1.resize(st.verts.size() * 4)
	colors.resize(st.verts.size())
	for vi in st.verts.size():
		var v: Vector3 = st.verts[vi]
		var p := Vector2(v.x, v.z)
		var frame: Dictionary = _flow_frame_at(st, p)
		cust[vi * 4 + 0] = frame.s
		cust[vi * 4 + 1] = frame.d
		cust[vi * 4 + 2] = frame.slope
		cust[vi * 4 + 3] = frame.shore_dist
		var flow: Dictionary = _current_at(current, p)
		cust1[vi * 4 + 0] = flow.velocity.x
		cust1[vi * 4 + 1] = flow.velocity.y
		cust1[vi * 4 + 2] = flow.vorticity
		cust1[vi * 4 + 3] = flow.compression
		var scale: float = _swell_scale(st, p, v.y, frame.shore_dist)
		colors[vi] = Color(scale, 1.0, 1.0, 1.0)
	return {"custom0": cust, "custom1": cust1, "colors": colors}


## Geometric dynamic-height amplitude at one surface sample. Shore distance still
## kills bobbing at the meniscus, but it is not a depth proxy: a broad river
## shelf can sit far from every shore and remain only centimetres deep.  The
## second gate therefore derives directly from static water-to-bed clearance.
## Multiplying the spectrum's conservative trough bound by this scale can
## never lower the vertex past ground+SWELL_BED_COVER.
static func _swell_scale(st: Dictionary, p: Vector2, water_y: float, shore_dist: float) -> float:
	var shore_t: float = clampf(shore_dist / SWELL_SHORE_FADE, 0.0, 1.0)
	var shore_scale: float = shore_t * shore_t * (3.0 - 2.0 * shore_t)
	var ground: float = TerrainSurfaceField.surface_y(st.region, p.x, p.y)
	var room: float = maxf(0.0, water_y - ground - SWELL_BED_COVER)
	var depth_scale: float = clampf(room / SWELL_TROUGH_BOUND, 0.0, 1.0)
	return minf(shore_scale, depth_scale)


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
	var width: float = lerpf(tr.widths[near.j], tr.widths[near.j + 1], near.t_c)
	if cands.size() == 2:
		var far: Dictionary = cands[1]
		var tie: float = far.dist - near.dist
		if tie < SEG_TIE_BAND:
			var mu: float = 0.5 * (1.0 - tie / SEG_TIE_BAND)
			var s_near_raw: float = lerpf(arclen[near.j], arclen[near.j + 1], near.t_raw)
			var s_far_raw: float = lerpf(arclen[far.j], arclen[far.j + 1], far.t_raw)
			s = clampf(lerpf(s_near_raw, s_far_raw, mu), 0.0, arclen[arclen.size() - 1])
			slope = lerpf(slope, _cand_slope(arclen, levels, far), mu)
			var far_width: float = lerpf(tr.widths[far.j], tr.widths[far.j + 1], far.t_c)
			width = lerpf(width, far_width, mu)
			var tb: Vector2 = near.tangent.lerp(far.tangent, mu)
			if tb.length_squared() > 0.000001:
				tangent = tb.normalized()
	var perp := Vector2(-tangent.y, tangent.x)
	var d: float = (p - near.proj).dot(perp)
	return {"dist": near.dist, "s": s, "d": d, "slope": slope,
		"tangent": tangent, "width": width, "proj": near.proj}


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
		return {"s": 0.0, "d": 0.0, "slope": 0.0, "shore_dist": shore_dist,
			"tangent": Vector2.ZERO, "width": 0.0}
	projections.sort_custom(func(pa, pb): return pa.dist < pb.dist)
	var nearest: Dictionary = projections[0]
	if nearest.dist >= RIVER_MAX_DIST:
		return {"s": 0.0, "d": 0.0, "slope": 0.0, "shore_dist": shore_dist,
			"tangent": Vector2.ZERO, "width": 0.0}
	var s: float = nearest.s
	var slope: float = nearest.slope
	var d: float = nearest.d
	var tangent: Vector2 = nearest.tangent
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
			tangent = bt
			var bperp := Vector2(-bt.y, bt.x)
			d = (p - nearest.proj).dot(bperp)
	return {"s": s, "d": d, "slope": slope, "shore_dist": shore_dist,
		"tangent": tangent, "width": nearest.width}


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
## already a unit Vector2 (WaterContour's curve-frame contract) and
## is horizontal (y=0) by construction, so {UP, outward} is an orthonormal
## pair and cos/sin naturally produce a unit result (the .normalized() below
## is defensive against float drift only). angle=0 => exactly UP (row0's own
## case, and every row at a fully wall-pinched point — see _rim's own call
## sites, which lerp `angle` toward 0.0 by the SAME _smoothed_flags(wall, ...)
## blend — r3 Task 14: this pinch is STILL wall-only, unlike reach2/reach3's
## own overshoot blend below, which now runs on the broader `rise` signal;
## see the Rim-normals constants block's own note on why the two stayed split).
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


## Assembles the committed ArrayMesh from build()'s own `arrays`: CUSTOM0 is
## the curvilinear river frame; CUSTOM1 is the shared current plus its local
## vorticity/compression; COLOR.r is the depth-limited displacement scale.
static func commit(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
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


## Builds the kept-point set: 2.0m world-aligned render lattice (origin snapped to
## the world STEP grid, same "floor(x/STEP)*STEP" convention WaterContour's
## own presence grid uses — this is what makes two neighbouring chunks'
## lattices land on IDENTICAL world columns/rows at their shared border) over
## `rect`, each point tested by _lattice_wet, height = WaterField.level_at
## (the brief's own rule for interior vertices).
## Index bounds are computed directly from the rect span (a 192m chunk is
## an exact integer multiple of STEP), NOT filtered through Rect2.has_point: an earlier
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


static func _point_on_rect_border(p: Vector2, rect: Rect2) -> bool:
	var hi: Vector2 = rect.position + rect.size
	return absf(p.x - rect.position.x) < 0.02 or absf(p.x - hi.x) < 0.02 \
		or absf(p.y - rect.position.y) < 0.02 or absf(p.y - hi.y) < 0.02


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
## (35.23,-1044.02) — already WaterContour's own documented hard case —
## produced 2-4 ring points whose
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


## Assigns every INTERNAL edge-ring lattice point to the SINGLE contour it
## actually borders: its nearest curve by polyline distance (_dist_point_to_
## curve). There is deliberately no distance cutoff. `edge_ring` contains
## only kept points beside a missing IN-RANGE quad, so every entry is by
## construction part of a real wet/dry boundary represented by one of this
## chunk's contours. A former 6.5m capture cutoff assumed the raw marching
## contour could never move farther from the lattice; the later smoothing
## and blob-like meniscus make that assumption false at long concave descents,
## leaving genuine ring points unowned and exposed as free interior edges.
##
## WHY NEAREST-ONLY (not "every curve within capture", the original rule):
## a chunk can carry multiple curves, and this file's own prior version of
## _boundary_strip let EACH curve independently claim any ring point within
## ITS OWN capture radius — correct when curves run far apart, but wherever
## two curves' own shorelines face each other across a gap under 2*capture
## (a sill lip a few metres from the pool it drops into, still its own
## separate curve because the ground genuinely steps between them — see
## r3-task-12c-report.md's pond-chunk (-4,-18) sill-hump geometry) a ring
## point belonging to curve B legitimately also fell inside curve A's own
## capture radius, so curve A's OWN _order_ring_by_nn_chain call absorbed it
## too. That contamination is what actually broke the mesh: it didn't merely
## add a stray point, it starved curve A's greedy nearest-neighbour chain at
## the one corner where the chain's own start (nearest ring point to the
## curve's pts[0], which can sit exactly on an "L" where the ring branches
## two ways — see _order_ring_by_nn_chain's own tie-break) ties two directions
## at equal distance: with contamination present, the tie's losing branch
## gets postponed past the ENTIRE rest of curve A's genuine ring and is
## finally forced to bridge to a contaminated point instead of doubling back
## to its own true neighbour (5 stranded free edges, all within 3m of the
## pond chunk's sill lip). Gating each ring point to its single nearest curve
## removes the contamination outright — the stranded corner point then
## legitimately becomes the chain's own LAST entry again, which the existing
## closed-curve wraparound triangle (_zip_strip's own "CLOSED-ANNULUS CLOSING
## TRIANGLE") already bridges back to the chain's first entry, healing the
## corner with no separate fix needed. Assigned ONCE per build (not
## per-curve) since ownership doesn't depend on which curve is asking.
static func _assign_ring_owners(lattice: Dictionary, curves: Array) -> Dictionary:
	var owners: Dictionary = {}
	for ij: Vector2i in lattice.edge_ring:
		var e: Dictionary = lattice.kept[ij]
		var best_ci := -1
		var best_d := INF
		for ci in curves.size():
			var d: float = _dist_point_to_curve(curves[ci], e.p)
			if d < best_d:
				best_d = d
				best_ci = ci
		if best_ci >= 0:
			owners[ij] = best_ci
	return owners


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
static func _boundary_strip(st: Dictionary, lattice: Dictionary, c: Dictionary, ci: int) -> void:
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

	# Ring: interior edge-ring points OWNED by THIS curve (r3 Task 12c —
	# _assign_ring_owners, called once in build(), already resolved each
	# edge-ring point to its single nearest curve; see that function's own
	# docstring for why "every curve within capture" — the original rule —
	# let two curves facing each other across a narrow gap both claim the
	# same points), ordered by 2D nearest-neighbour chaining
	# (_order_ring_by_nn_chain — see its own docstring for why this replaced
	# an arc-length-projection sort).
	var owners: Dictionary = lattice.ring_owner
	var ring_pts: Array = []
	var ring_y: Array = []
	for ij: Vector2i in lattice.edge_ring:
		if int(owners.get(ij, -1)) != ci:
			continue
		var e: Dictionary = lattice.kept[ij]
		ring_pts.append(e.p)
		ring_y.append(e.y)
	if ring_pts.is_empty():
		return   # nothing nearby yet kept (e.g. a sliver curve with no adjacent interior) — no strip to build
	var order: Array = _order_ring_by_nn_chain(ring_pts, pts[0])
	if c.closed:
		var closed_ring := _weld_ring_order(st, ring_pts, ring_y, order)
		_zip_strip(st, curve_vi, closed_ring, true)
		return

	# One open contour can border several disconnected kept-lattice rings
	# where the channel narrows below the 2m interior grid. The old zipper
	# forced those rings into one necklace, creating 53m triangles across dry
	# terrain at the reported descent. Split both at spatial gaps and at jumps
	# between distant portions of a self-approaching contour, then partition
	# the contour among the resulting local runs.
	var runs: Array = _open_ring_runs(ring_pts, order, pts)
	if runs.is_empty():
		return
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.lo < b.lo)
	var boundaries: Array[int] = [0]
	for ri in runs.size() - 1:
		var cut: int = clampi(roundi((float(runs[ri].hi) + float(runs[ri + 1].lo)) * 0.5),
			boundaries[-1], n - 1)
		boundaries.append(cut)
	boundaries.append(n - 1)

	var previous_ring_end := -1
	for ri in runs.size():
		var run: Dictionary = runs[ri]
		var run_order: Array = run.order
		if _nearest_curve_vertex(pts, ring_pts[run_order[0]]) \
			> _nearest_curve_vertex(pts, ring_pts[run_order[-1]]):
			run_order.reverse()
		var ring_vi: PackedInt32Array = _weld_ring_order(st, ring_pts, ring_y, run_order)
		var start_i: int = boundaries[ri]
		var end_i: int = boundaries[ri + 1]
		if end_i <= start_i:
			end_i = mini(n - 1, start_i + 1)
		var local_curve := PackedInt32Array()
		for curve_i in range(start_i, end_i + 1):
			local_curve.append(curve_vi[curve_i])
		_zip_strip(st, local_curve, ring_vi, false)
		if previous_ring_end >= 0:
			# Both neighbouring strips share curve_vi[start_i]. This cap heals
			# their two local connector edges and the lattice edge between runs.
			_emit_strip_tri(st, curve_vi[start_i], previous_ring_end, ring_vi[0])
		previous_ring_end = ring_vi[-1]


static func _weld_ring_order(st: Dictionary, ring_pts: Array, ring_y: Array,
		order: Array) -> PackedInt32Array:
	var ring_vi := PackedInt32Array()
	ring_vi.resize(order.size())
	for k in order.size():
		var oi: int = order[k]
		var nrm: Vector3 = _interior_normal(st, ring_pts[oi], ring_y[oi])
		ring_vi[k] = _weld_vert(st, ring_pts[oi], ring_y[oi], nrm)
	return ring_vi


static func _open_ring_runs(ring_pts: Array, order: Array,
		pts: PackedVector2Array) -> Array:
	const CURVE_INDEX_JUMP := 8
	var runs: Array = []
	var current: Array[int] = [order[0]]
	var previous_curve_i: int = _nearest_curve_vertex(pts, ring_pts[order[0]])
	for k in range(1, order.size()):
		var oi: int = order[k]
		var previous_oi: int = order[k - 1]
		var curve_i: int = _nearest_curve_vertex(pts, ring_pts[oi])
		var spatial_gap: float = ring_pts[previous_oi].distance_to(ring_pts[oi])
		if spatial_gap > STRIP_EDGE_MAX or absi(curve_i - previous_curve_i) > CURVE_INDEX_JUMP:
			runs.append(_ring_run(current, ring_pts, pts))
			current = [oi]
		else:
			current.append(oi)
		previous_curve_i = curve_i
	if not current.is_empty():
		runs.append(_ring_run(current, ring_pts, pts))
	return runs


static func _ring_run(order: Array[int], ring_pts: Array,
		pts: PackedVector2Array) -> Dictionary:
	var lo := pts.size() - 1
	var hi := 0
	for oi in order:
		var curve_i: int = _nearest_curve_vertex(pts, ring_pts[oi])
		lo = mini(lo, curve_i)
		hi = maxi(hi, curve_i)
	return {"order": order, "lo": lo, "hi": hi}


static func _nearest_curve_vertex(pts: PackedVector2Array, p: Vector2) -> int:
	var best_i := 0
	var best_d := INF
	for i in pts.size():
		var d: float = pts[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


## Five-band meniscus profile in the contour's outward-normal frame:
##   row0: (p, L), weld-reusing the boundary strip's curve vertex;
##   row1: +0.12m, L+0.04m — a short crest that removes the old vertical seam;
##   row2: default +0.30m, L-0.06m;
##   row3: default +0.48m, L-0.28m;
##   row4: default +0.60m, L-0.55m;
##   row5: default +0.64m, L-0.65m.
##
## Rising banks extend rows2..5 to 0.40/0.60/0.70/0.78m. A contour wall flag is
## only allowed to extend them through the KayKit face when the point's own
## outward column finds sustained high ground within one 6m fill cell. The measured contact distance
## is added to the KayKit face's own 1.5m recess: the signed-depth waterline can
## sit between the terrain boundary and the contour, so a fixed 1.5m extrusion
## alone is not enough. At confirmed walls rows2..4 remain a water-level shelf
## through the visible face and another 0.30m behind it; the downward curl starts
## only between row4 and row5.  When adjacent wall normals turn, their outer
## tangent lines are intersected and the level shelf is mitred through that
## point instead of cutting the corner off with a diagonal chord. This keeps
## rounded cliff turns visibly full instead of meeting the wall with the bottom
## of a sloping meniscus. It also avoids letting an off-axis wall stretch a
## genuine free edge into a skirt. Smoothing the reach flags avoids sawteeth, but a
## local drop at 0.40m overrides that smoothing unless the direct wall-contact
## test succeeded. Free/drop edges consequently keep the compact four-step
## curl; bank edges disappear below terrain. Five quad bands connect adjacent
## columns, and open contours receive a four-triangle six-vertex end cap.
static func _rim(st: Dictionary, c: Dictionary) -> void:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var normals: PackedVector2Array = c.normals
	var n: int = pts.size()
	if n < 2:
		return
	var closed: bool = c.closed
	var contacts: Dictionary = _wall_contacts(st, c)
	var wall_contact: PackedByteArray = contacts.flags
	var wall_face_reach: PackedFloat32Array = contacts.face_reach
	var wet_shelf_reach: PackedFloat32Array = _wet_shelf_reaches(st, c)
	var wf: PackedFloat32Array = _smoothed_flags(wall_contact, closed)
	var rise: PackedByteArray = _rising_flags(st, c, wall_contact)
	var rf: PackedFloat32Array = _smoothed_flags(rise, closed)
	# A wall/rise flag is deliberately smoothed along the contour so the bank
	# contact silhouette does not sawtooth.  That blend must stop at a genuine
	# free edge, however: otherwise one adjacent wall column can stretch the
	# drop column toward the cliff and recreate the sharp skirt this rim exists
	# to remove.  The point's own outward span is authoritative for a drop.
	for i in n:
		var drop_probe: Vector2 = pts[i] + normals[i] * RIM_RISE_REACH
		var drop_ground: float = TerrainSurfaceField.surface_y(
			st.region, drop_probe.x, drop_probe.y)
		if drop_ground < levels[i] - RISE_MARGIN and wall_contact[i] == 0:
			wf[i] = 0.0
			rf[i] = 0.0

	var row0 := PackedInt32Array()
	var row1 := PackedInt32Array()
	var row2 := PackedInt32Array()
	var row3 := PackedInt32Array()
	var row4 := PackedInt32Array()
	var row5 := PackedInt32Array()
	row0.resize(n)
	row1.resize(n)
	row2.resize(n)
	row3.resize(n)
	row4.resize(n)
	row5.resize(n)
	for i in n:
		var p: Vector2 = pts[i]
		var nrm: Vector2 = normals[i]
		var lvl: float = levels[i]
		# Curl angle per row, about the curve tangent, pinched toward 0 (UP) at
		# wall points by the SAME wf[i] blend — see _curl_normal's own
		# docstring. Deliberately wall-only (not rf[i]): see the Rim-normals
		# constants block's own r3 Task 14 note.
		# A direct contact is authoritative at full strength. `wf` may extend a
		# fractional transition into neighbouring columns, but filtering must
		# never shorten a point that independently proved it hits the wall.
		var wall_strength: float = maxf(wf[i], float(wall_contact[i]))
		var wet_shelf_strength := 1.0 \
			if wet_shelf_reach[i] > RIM_ROW1_REACH else 0.0
		var level_strength: float = maxf(wall_strength, wet_shelf_strength)
		var ang1: float = lerpf(RIM_NORMAL_ANGLE1, 0.0, wall_strength)
		var ang2: float = lerpf(RIM_NORMAL_ANGLE2, 0.0, wall_strength)
		var ang3: float = lerpf(RIM_NORMAL_ANGLE3, 0.0, wall_strength)
		var ang4: float = lerpf(PI * 4.0 / 9.0, 0.0, wall_strength)
		row0[i] = _weld_vert(st, p, lvl, Vector3.UP)
		# Start moving outward immediately.  The old row1 reused p.xz and only
		# changed Y, which made the meniscus begin with a literal vertical
		# repair seam.  A short outward crest reads as one rounded body instead.
		var p1: Vector2 = p + nrm * RIM_ROW1_REACH
		row1[i] = _weld_vert(st, p1,
			lvl + RIM_ROW1_BULGE * (1.0 - level_strength),
			_curl_normal(nrm, ang1))
		# reach2/reach3: the default (falling/level ground) reach, OR
		# overshoot to RIM_RISE_REACH wherever rf[i] says the bank RISES — r3
		# Task 14's universal shore-overshoot; see _rising_flags and this
		# function's own docstring.
		var reach2: float = lerpf(RIM_ROW2_REACH, RIM_RISE_REACH, rf[i])
		# The buried row must remain farther out than the visible row.  The old
		# rising-bank path collapsed both to 0.40m, creating a second vertical
		# skirt edge precisely where the water met a cliff face.
		var reach3: float = lerpf(RIM_ROW3_REACH, RIM_RISE_BURY_REACH, rf[i])
		var reach4: float = lerpf(RIM_ROW4_REACH,
			RIM_RISE_BURY_REACH + 0.10, rf[i])
		var reach5: float = lerpf(RIM_ROW5_REACH,
			RIM_RISE_BURY_REACH + 0.18, rf[i])
		# The smoothed curve is a visual boundary, not permission to contradict
		# the underlying signed-depth field. If the outward column remains wet,
		# carry a level shelf to its first dry transition. The small increasing
		# offsets keep the buried rows ordered without creating a visible slope;
		# on a rising bank they are below terrain, while a true free edge has a
		# zero wet reach and retains the compact meniscus below.
		if wet_shelf_strength > 0.0:
			reach2 = maxf(reach2, wet_shelf_reach[i])
			reach3 = maxf(reach3, wet_shelf_reach[i] + 0.05)
			reach4 = maxf(reach4, wet_shelf_reach[i] + 0.10)
			reach5 = maxf(reach5, wet_shelf_reach[i] + 0.20)
		# `wf` is smoothed to keep neighbouring wall/non-wall columns from
		# forming a sawtooth silhouette.  It upgrades only a true wall reach;
		# rf's ordinary rising-bank path stays at 0.40/0.60m.
		var face_reach: float = wall_face_reach[i] \
			if wall_face_reach[i] >= 0.0 else RIM_WALL_REACH
		reach2 = lerpf(reach2, face_reach, wall_strength)
		# At a confirmed wall row3 and row4 share the same XZ landing behind
		# the rock and both belong to the level shelf. Giving the lower contact
		# row an extra 10cm of horizontal reach used the curl, rather than the
		# shelf, to fill the outside of rounded corners.
		reach3 = lerpf(reach3, face_reach + RIM_WALL_SHELF_BURY, wall_strength)
		reach4 = lerpf(reach4, face_reach + RIM_WALL_SHELF_BURY, wall_strength)
		reach5 = lerpf(reach5, face_reach + RIM_WALL_OUTER_BURY, wall_strength)
		var p2: Vector2 = p + nrm * reach2
		# A genuine bank keeps the old under-ground landing.  A falling shore is
		# deliberately different: row2 remains close to the surface and starts a
		# compact rounded sidewall instead of teleporting to the landing ground.
		# That short exposed curl is thickness, not a horizontal water film.
		# A confirmed recessed wall needs a horizontal TOP contact sheet all the
		# way through the visible face.  Extending XZ alone left row2/row3 at their
		# free-edge drop heights, so the mesh technically reached the corner using
		# only its lower curl while the visible surface dipped by ~0.5m.  Lift the
		# three contact rows back to L with the same smoothed wall weight; row5
		# turns down behind the face and seals the mesh.
		var y2: float = lerpf(lvl - RIM_ROW2_DROP, lvl, level_strength)
		row2[i] = _weld_vert(st, p2, y2, _curl_normal(nrm, ang2))
		var p3: Vector2 = p + nrm * reach3
		var y3: float = lerpf(lvl - RIM_ROW3_DROP, lvl, level_strength)
		row3[i] = _weld_vert(st, p3, y3, _curl_normal(nrm, ang3))
		var p4: Vector2 = p + nrm * reach4
		var y4: float = lerpf(lvl - RIM_ROW4_DROP, lvl, level_strength)
		row4[i] = _weld_vert(st, p4, y4, _curl_normal(nrm, ang4))
		var p5: Vector2 = p + nrm * reach5
		row5[i] = _weld_vert(st, p5, lvl - RIM_ROW5_DROP,
			_curl_normal(nrm, PI * 4.0 / 9.0))

	var lim: int = n if closed else n - 1
	for i in lim:
		var j: int = (i + 1) % n
		_emit_tri(st, row0[i], row1[i], row1[j])
		_emit_tri(st, row0[i], row1[j], row0[j])
		_emit_tri(st, row1[i], row2[i], row2[j])
		_emit_tri(st, row1[i], row2[j], row1[j])
		_emit_tri(st, row2[i], row3[i], row3[j])
		_emit_tri(st, row2[i], row3[j], row2[j])
		var miter: Dictionary = _wall_turn_miter(
			st, row4, normals, levels, wall_contact, i, j)
		if miter.is_empty():
			_emit_tri(st, row3[i], row4[i], row4[j])
			_emit_tri(st, row3[i], row4[j], row3[j])
			_emit_tri(st, row4[i], row5[i], row5[j])
			_emit_tri(st, row4[i], row5[j], row4[j])
		else:
			# The ordinary row3->row4 band ends on the old diagonal chord.
			# Add the missing level triangle out to the true L-corner, then
			# route the buried curl around that same miter. These three faces
			# deliberately share the unsplit row4 chord: recursively splitting
			# each triangle independently can choose a different longest edge,
			# producing T-junctions along the shared chord. The miter distance is
			# already bounded below the reported non-local-face limit.
			_emit_tri(st, row3[i], row4[i], row4[j])
			_emit_tri(st, row3[i], row4[j], row3[j])
			_emit_tri(st, row4[i], miter.top, row4[j])
			_emit_tri(st, row4[i], row5[i], miter.buried)
			_emit_tri(st, row4[i], miter.buried, miter.top)
			_emit_tri(st, miter.top, miter.buried, row5[j])
			_emit_tri(st, miter.top, row5[j], row4[j])

	if not closed:
		_rim_end_cap(st, row0[0], row1[0], row2[0], row3[0], row4[0], row5[0])
		var last: int = n - 1
		_rim_end_cap(st, row0[last], row1[last], row2[last], row3[last], row4[last], row5[last])


## Four-triangle fan closing the six-point rim ladder at an open contour
## endpoint. It pairs each of the five band-end edges and leaves only the
## row0-row5 diagonal, which is accounted for by the endpoint's exact chunk
## border plus the outer-row invariant.
static func _rim_end_cap(st: Dictionary, i0: int, i1: int, i2: int, i3: int,
		i4: int, i5: int) -> void:
	_emit_tri(st, i0, i1, i2)
	_emit_tri(st, i0, i2, i3)
	_emit_tri(st, i0, i3, i4)
	_emit_tri(st, i0, i4, i5)


## Tent-filtered (0.25/0.5/0.25) copy of a per-point PackedByteArray flag
## (either `wall`, for _rim's own curl-angle pinch, or r3 Task 14's own
## `rise` — see _rim's two call sites) as a continuous per-point blend
## weight — see _rim's docstring for why a hard per-point flag switch
## zigzags the rim's outer silhouette at a wall/shore or rise/fall
## transition. Open curves clamp at their own ends (duplicate the edge
## value, the standard fixed-boundary convention for a 1D filter); closed
## curves wrap. (Renamed from _smoothed_wall, r3 Task 14: the filter itself
## is generic — it never reads anything wall-specific — and is now called on
## two different flag arrays.)
static func _smoothed_flags(flags: PackedByteArray, closed: bool) -> PackedFloat32Array:
	var n: int = flags.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var prev_i: int = (i - 1 + n) % n if closed else maxi(i - 1, 0)
		var next_i: int = (i + 1) % n if closed else mini(i + 1, n - 1)
		out[i] = 0.25 * float(flags[prev_i]) + 0.5 * float(flags[i]) + 0.25 * float(flags[next_i])
	return out


## Per-point RISING flag: true when the bank genuinely climbs above the water
## level across the span the compact overshoot covers, or direct recessed-wall
## contact has already been confirmed.
##
## The covered span is [0, RIM_RISE_REACH] — where row2 (the only rim row
## whose Y is the bulge, not a buried seal) actually lands. It is sampled at
## RISE_PROBE_NEAR (the near half, 0.20m) AND RIM_RISE_REACH (the landing,
## 0.40m); BOTH must clear the level by RISE_MARGIN (an AND). The FIRST
## submission used a far OR — ground at 0.5m OR 1.0m above level — which the
## review caught as unsound: RIM_RISE_REACH (0.40m) sits BEFORE either of
## those probes, so on a curve point whose ground DIPS at 0.2-0.5m then rises
## again by 1.0m, the 1.0m probe alone authorised the overshoot while row2
## floated over the un-sampled local dip — a film over a drop, the exact
## artifact this redesign exists to kill. Gating on the covered span instead
## means a dip anywhere the overshoot actually reaches vetoes it. _rim also
## gives a local drop final authority over neighbouring smoothed flags.
##
## Folding `wall` in is never redundant risk and sometimes strictly helps:
## WaterContour's own wall probe (WALL_SLOPE=1.2 at 0.5m/1.5m) already implies
## a rise clearing RISE_MARGIN by a wide margin wherever it fires (0.5m of run
## at slope 1.2 is 0.6m of rise, comfortably past RISE_MARGIN=0.05), so OR-ing
## it in costs nothing on the common path — but it also catches the rare case
## where a genuinely near-vertical face's OWN span samples happen to land on a
## locally stepped/quantized rock shelf that reads flat there (the same
## corner-crest hazard WaterContour._attributes' own docstring documents for
## the wall flag's rise-from-level anchor).
static func _rising_flags(st: Dictionary, c: Dictionary,
		wall_contact: PackedByteArray) -> PackedByteArray:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var normals: PackedVector2Array = c.normals
	var n: int = pts.size()
	var out := PackedByteArray()
	out.resize(n)
	for i in n:
		if wall_contact[i] == 1:
			out[i] = 1
			continue
		var p: Vector2 = pts[i]
		var nrm: Vector2 = normals[i]
		var lvl: float = levels[i]
		var pnear: Vector2 = p + nrm * RISE_PROBE_NEAR
		var pland: Vector2 = p + nrm * RIM_RISE_REACH
		var gnear: float = TerrainSurfaceField.surface_y(st.region, pnear.x, pnear.y)
		var gland: float = TerrainSurfaceField.surface_y(st.region, pland.x, pland.y)
		out[i] = 1 if (gnear > lvl + RISE_MARGIN and gland > lvl + RISE_MARGIN) else 0
	return out


## Distance for which each smoothed contour point's own outward column is
## still visibly wet according to the final field. WaterContour smooths and
## resamples the raw signed-depth zero, so a point can legitimately land up
## to nearly a metre inside the true wet region (the reported (-17,-20)
## inner corner measured 0.75m of continuous water past the curve). Starting
## a downward meniscus at the smoothed point then draws a concave-looking
## bulb over water that should still be level.
##
## Scan only the first continuous wet run. A narrow dry cliff arm may be
## followed by water again on the far side; that arm is handled as a recessed
## wall by `_wall_contacts`, not flooded across at terrain-top height. This
## distinction is what fixes the reported cliff/saddle joins without turning
## a real island into a water sheet.
static func _wet_shelf_reaches(st: Dictionary, c: Dictionary) -> PackedFloat32Array:
	var pts: PackedVector2Array = c.pts
	var normals: PackedVector2Array = c.normals
	var out := PackedFloat32Array()
	out.resize(pts.size())
	for i in pts.size():
		var last_wet := 0.0
		var saw_wet := false
		var d := 0.0
		while d <= WET_SHELF_SCAN_MAX + 0.0001:
			var q: Vector2 = pts[i] + normals[i] * d
			var wet: bool = WaterField.wet(st.ctx, st.region, q)
			if wet:
				saw_wet = true
				last_wet = d
			elif saw_wet:
				break
			else:
				break
			d += WET_SHELF_SCAN_STEP
		out[i] = last_wet
	return out


## WaterContour deliberately checks the outward normal and its +/-45-degree
## flanks so a rounded cliff turn inherits both wall arms. That generous flag
## must not turn a genuinely unbounded edge into a bank skirt merely because a
## wall exists off to one side. Search only the signed-depth field's finite 6m
## interpolation support for the first high-ground sample in THIS point's
## outward column. A hit both confirms the wall and measures the contour's
## retreat from the real terrain boundary. The visible face is another 1.5m
## inside the high cell, so `face_reach = contact + RIM_WALL_REACH`; omitting
## `contact` was the fixed-distance bug that left exact recessed corners dry.
static func _wall_contacts(st: Dictionary, c: Dictionary) -> Dictionary:
	var pts: PackedVector2Array = c.pts
	var levels: PackedFloat32Array = c.levels
	var normals: PackedVector2Array = c.normals
	var wall: PackedByteArray = c.wall
	var flags := PackedByteArray()
	var face_reach := PackedFloat32Array()
	flags.resize(pts.size())
	face_reach.resize(pts.size())
	face_reach.fill(-1.0)
	for i in pts.size():
		if wall[i] == 0:
			continue
		# A straight wall remains high at the far end of the finite field span.
		# A diagonal corner arm may cross this normal column only locally, so
		# the far probe is one of two independent sustain witnesses below.
		var far_q: Vector2 = pts[i] + normals[i] * WALL_CONTACT_SCAN_MAX
		var far_ground: float = TerrainSurfaceField.surface_y(
			st.region, far_q.x, far_q.y)
		var far_high: bool = far_ground > levels[i] + RISE_MARGIN
		var contact := -1.0
		var d := 0.0
		while d <= WALL_CONTACT_SCAN_MAX + 0.0001:
			var q: Vector2 = pts[i] + normals[i] * d
			var ground: float = TerrainSurfaceField.surface_y(st.region, q.x, q.y)
			if ground > levels[i] + RISE_MARGIN:
				contact = d
				break
			d += WALL_CONTACT_SCAN_STEP
		var sustained_local := false
		if contact >= 0.0:
			var sustain_q: Vector2 = pts[i] + normals[i] \
				* (contact + WALL_CONTACT_LOCAL_SUSTAIN)
			var sustain_ground: float = TerrainSurfaceField.surface_y(
				st.region, sustain_q.x, sustain_q.y)
			sustained_local = sustain_ground > levels[i] + RISE_MARGIN
		if contact >= 0.0 and (far_high or sustained_local):
			flags[i] = 1
			face_reach[i] = contact + RIM_WALL_REACH
	return {"flags": flags, "face_reach": face_reach}


## Builds the missing convex join between two directly-confirmed wall
## columns whose outward directions turn. Each row4 endpoint already sits on
## its own buried wall-contact line. Intersecting the two lines tangent to
## those walls gives the L-corner's proper miter; a direct segment between the
## endpoints is merely a diagonal chord and cuts that corner off. Returns one
## level `top` vertex plus a slightly farther/lower `buried` vertex used to
## route the terminal curl around it. The caller owns the surrounding faces.
static func _wall_turn_miter(st: Dictionary, row4: PackedInt32Array,
		normals: PackedVector2Array, levels: PackedFloat32Array,
		wall_contact: PackedByteArray, i: int, j: int) -> Dictionary:
	if wall_contact[i] == 0 or wall_contact[j] == 0:
		return {}
	var ni: Vector2 = normals[i]
	var nj: Vector2 = normals[j]
	if ni.dot(nj) >= WALL_MITER_DOT_MAX:
		return {}
	var ti := Vector2(-ni.y, ni.x)
	var tj := Vector2(-nj.y, nj.x)
	var denom: float = ti.cross(tj)
	if absf(denom) < 0.0001:
		return {}
	var ai3: Vector3 = st.verts[row4[i]]
	var aj3: Vector3 = st.verts[row4[j]]
	var ai := Vector2(ai3.x, ai3.z)
	var aj := Vector2(aj3.x, aj3.z)
	var along_i: float = (aj - ai).cross(tj) / denom
	var corner: Vector2 = ai + ti * along_i
	if corner.distance_to(ai) > WALL_MITER_LIMIT \
		or corner.distance_to(aj) > WALL_MITER_LIMIT:
		return {}
	var level: float = (levels[i] + levels[j]) * 0.5
	var top: int = _weld_vert(st, corner, level, Vector3.UP)
	var bisector: Vector2 = ni + nj
	if bisector.length_squared() < 0.0001:
		return {}
	bisector = bisector.normalized()
	var buried_p: Vector2 = corner + bisector * WALL_MITER_BURY
	var buried: int = _weld_vert(st, buried_p, level - RIM_ROW5_DROP,
		_curl_normal(bisector, PI * 4.0 / 9.0))
	return {"top": top, "buried": buried}


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
				_emit_strip_tri(st, a[i % n], a_next, b[j])
				i += 1
			else:
				_emit_strip_tri(st, a[i % n], b[j + 1], b[j])
				j += 1
		elif can_adv_a:
			var a_next2: int = a[(i + 1) % n]
			_emit_strip_tri(st, a[i % n], a_next2, b[j])
			i += 1
		else:
			_emit_strip_tri(st, a[i % n], b[j + 1], b[j])
			j += 1
	if closed and m >= 2:
		_emit_strip_tri(st, a[0], b[m - 1], b[0])


## Emits a boundary-strip face at the same local scale as the 2m interior
## lattice.  The greedy zipper decides topology, but it does not constrain
## the width of the triangle it creates: at a tight corner one contour step
## could fan directly to a ring point 6-7m away.  Recursively bisecting the
## longest horizontal edge preserves that topology and watertight weld while
## sampling the real water field at each new point, so normals/refraction and
## descent height no longer interpolate across a giant polygon.
static func _emit_strip_tri(st: Dictionary, i0: int, i1: int, i2: int) -> void:
	var ids: Array[int] = [i0, i1, i2]
	var longest_k := -1
	var longest := 0.0
	for k in 3:
		var a: Vector3 = _vpos(st, ids[k])
		var b: Vector3 = _vpos(st, ids[(k + 1) % 3])
		var span: float = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if span > longest:
			longest = span
			longest_k = k
	if longest <= STRIP_EDGE_MAX:
		_emit_tri(st, i0, i1, i2)
		return

	var ia: int = ids[longest_k]
	var ib: int = ids[(longest_k + 1) % 3]
	var ic: int = ids[(longest_k + 2) % 3]
	var va: Vector3 = _vpos(st, ia)
	var vb: Vector3 = _vpos(st, ib)
	var p := Vector2(va.x + vb.x, va.z + vb.z) * 0.5
	var level: float = WaterField.level_at(st.ctx, p)
	if level == -INF:
		level = (va.y + vb.y) * 0.5
	var mid: int = _weld_vert(st, p, level, _interior_normal(st, p, level))
	_emit_strip_tri(st, ia, mid, ic)
	_emit_strip_tri(st, mid, ib, ic)


## Emits one strip triangle. Winding: the curve chain `a` runs along the
## WATER'S edge and the ring chain `b` runs along the interior (wet) side —
## for the sheet to wind +Y (this codebase's one water-mesh convention), the
## triangle order (p0, p1, p2) must place the INTERIOR vertex so the
## computed normal points up; empirically fixed against the interior mesh's
## own known-+Y quads (see test_all_triangles_wind_up-style check in this
## task's own test suite) as (p_a_first, p_b_or_a_next, p_ring_or_a) below.
static func _emit_tri(st: Dictionary, i0: int, i1: int, i2: int) -> void:
	if i0 == i1 or i1 == i2 or i2 == i0:
		return
	var v0: Vector3 = st.verts[i0]
	var v1: Vector3 = st.verts[i1]
	var v2: Vector3 = st.verts[i2]
	var nrm: Vector3 = (v1 - v0).cross(v2 - v0)
	if nrm.length_squared() <= 0.00000001:
		return
	var order: Array = [i0, i1, i2] if nrm.y >= 0.0 else [i0, i2, i1]
	for k in order:
		st.idx.append(k)


## Closes small water-level loops left where two independently zipped
## contour strips meet.  This operates on the finished mesh edge graph—the
## actual topology—rather than trying to infer a junction from nearest-curve
## ownership.  It is deliberately narrow: only closed loops of at most 12
## vertices, made entirely of local-scale edges, whose centroid is genuinely
## wet in WaterField may be triangulated.  Chunk borders, buried rim edges,
## open seams, and large regions are never eligible.
static func _seal_local_surface_holes(st: Dictionary) -> void:
	var count: Dictionary = {}
	var idx: PackedInt32Array = st.idx
	for ti in range(0, idx.size(), 3):
		for k in 3:
			var a: int = idx[ti + k]
			var b: int = idx[ti + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			count[key] = int(count.get(key, 0)) + 1

	var unused: Dictionary = {}
	var adjacency: Dictionary = {}
	for edge: Vector2i in count:
		if int(count[edge]) != 1:
			continue
		var a: Vector3 = st.verts[edge.x]
		var b: Vector3 = st.verts[edge.y]
		if _point_on_rect_border(Vector2(a.x, a.z), st.rect) \
			and _point_on_rect_border(Vector2(b.x, b.z), st.rect):
			continue
		if not _at_visible_water_level(st, a) or not _at_visible_water_level(st, b):
			continue
		unused[edge] = true
		if not adjacency.has(edge.x):
			adjacency[edge.x] = []
		if not adjacency.has(edge.y):
			adjacency[edge.y] = []
		adjacency[edge.x].append(edge.y)
		adjacency[edge.y].append(edge.x)

	while not unused.is_empty():
		var first: Vector2i = unused.keys()[0]
		var component_edges: Array[Vector2i] = []
		var pending: Array[Vector2i] = [first]
		var component_vertices: Dictionary = {}
		unused.erase(first)
		while not pending.is_empty():
			var edge: Vector2i = pending.pop_back()
			component_edges.append(edge)
			component_vertices[edge.x] = true
			component_vertices[edge.y] = true
			for vi: int in [edge.x, edge.y]:
				for other: int in adjacency.get(vi, []):
					var neighbour := Vector2i(mini(vi, other), maxi(vi, other))
					if unused.has(neighbour):
						unused.erase(neighbour)
						pending.append(neighbour)

		if component_vertices.size() < 3 or component_vertices.size() > 12:
			continue
		var closed := true
		for vi: int in component_vertices:
			var degree := 0
			for other: int in adjacency.get(vi, []):
				var edge := Vector2i(mini(vi, other), maxi(vi, other))
				if component_edges.has(edge):
					degree += 1
			if degree != 2:
				closed = false
				break
		if not closed:
			continue

		var cycle: Array[int] = [component_vertices.keys()[0]]
		var previous := -1
		var current: int = cycle[0]
		while true:
			var next := -1
			for candidate: int in adjacency[current]:
				if candidate != previous:
					next = candidate
					break
			if next < 0 or next == cycle[0]:
				break
			cycle.append(next)
			previous = current
			current = next
		if cycle.size() != component_vertices.size():
			continue

		var polygon := PackedVector2Array()
		var centroid := Vector2.ZERO
		var max_edge := 0.0
		for vi: int in cycle:
			var v: Vector3 = st.verts[vi]
			var p := Vector2(v.x, v.z)
			polygon.append(p)
			centroid += p
		centroid /= float(cycle.size())
		for i in cycle.size():
			max_edge = maxf(max_edge, polygon[i].distance_to(polygon[(i + 1) % cycle.size()]))
		if max_edge > STRIP_EDGE_MAX:
			continue
		var level: float = WaterField.level_at(st.ctx, centroid)
		var ground: float = TerrainSurfaceField.surface_y(st.region, centroid.x, centroid.y)
		if level == -INF or level <= ground + 0.02:
			continue
		if absf(_polygon_area(polygon)) > STEP * STEP * 4.0:
			continue
		var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for ti in range(0, triangles.size(), 3):
			_emit_fill_triangle(st, cycle, triangles[ti], triangles[ti + 1],
				triangles[ti + 2])


## Geometry2D's ear clipper is allowed to omit collinear polygon vertices.
## That is geometrically harmless but topologically wrong here: the omitted
## contour point is also used by the meniscus, so replacing A-M-B by A-B
## leaves both chains as coincident free edges (and a crack-prone T-junction).
## Reinsert every cycle vertex lying on each ear edge, then triangulate that
## still-convex subdivided ear as a fan. The fill therefore shares the exact
## boundary segmentation already owned by the strip/rim.
static func _emit_fill_triangle(st: Dictionary, cycle: Array[int], ia: int,
		ib: int, ic: int) -> void:
	var corners: Array[int] = [cycle[ia], cycle[ib], cycle[ic]]
	var perimeter: Array[int] = []
	for edge_i in 3:
		var a: int = corners[edge_i]
		var b: int = corners[(edge_i + 1) % 3]
		var av3: Vector3 = st.verts[a]
		var bv3: Vector3 = st.verts[b]
		var av := Vector2(av3.x, av3.z)
		var bv := Vector2(bv3.x, bv3.z)
		var edge: Vector2 = bv - av
		var edge_len2: float = edge.length_squared()
		var between: Array[Dictionary] = []
		if edge_len2 > 0.000001:
			for vi: int in cycle:
				if vi == a or vi == b:
					continue
				var v3: Vector3 = st.verts[vi]
				var v := Vector2(v3.x, v3.z)
				var t: float = (v - av).dot(edge) / edge_len2
				if t <= 0.0001 or t >= 0.9999:
					continue
				if v.distance_to(av + edge * t) <= 0.02:
					between.append({"vi": vi, "t": t})
		between.sort_custom(func(a_item: Dictionary, b_item: Dictionary) -> bool:
			return a_item.t < b_item.t)
		perimeter.append(a)
		for item: Dictionary in between:
			perimeter.append(item.vi)
	for k in range(1, perimeter.size() - 1):
		# Polygon edges are local by the caller's gate, but an ear diagonal can
		# span two render cells. Keep the existing bounded-face subdivision.
		_emit_strip_tri(st, perimeter[0], perimeter[k], perimeter[k + 1])


static func _at_visible_water_level(st: Dictionary, v: Vector3) -> bool:
	var p := Vector2(v.x, v.z)
	var level: float = WaterField.level_at(st.ctx, p)
	return level != -INF and absf(v.y - level) <= 0.08


static func _polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in polygon.size():
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		twice_area += a.x * b.y - b.x * a.y
	return twice_area * 0.5


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
## key — the same 1/64m precision on every world axis. Two DIFFERENT strip triangles
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


## Triggers (r3 Task 7 — real wiring, not scaffolding; r3 Task 9 — sub-tile
## reconciliation, RETIRED r3 Task 12b): one box per 24m TILE touched by any
## built vertex (kept interior, boundary-strip, OR rim), footprint from this
## class's own presence data (`st.verts`) — top = max level in the tile +
## TRIGGER_TOP_CLEAR, bottom = min ground in the tile - TRIGGER_BOTTOM_CLEAR
## (this codebase's existing swim-trigger tiling/clearance convention). A
## tile whose max |grade_at| exceeds STEEP_UNSWIMMABLE gets NO trigger at
## all — see that constant's own docstring; a fall face is not swimmable
## water by design, so a character must fall/slide through it rather than
## float.
##
## r3 Task 12b: this is back to simple wet-tile coverage, one box per
## touched TILE with no further splitting — the whole-tile/sub-tile level-
## SPREAD suppression Tasks 7/9 layered on top (TRIGGER_LEVEL_SPREAD_MAX,
## TRIGGER_SUB_TILE_SPREAD_MAX, _tile_level_spread/_level_spread_over,
## _sub_tile_triggers) is DELETED — see STEEP_UNSWIMMABLE's own neighbouring
## docstring (above) for why, and r3-task-12b-report.md for the proof.
## WaterSurfaceBuilder.build_chunk turns every entry here into an Area3D
## carrying set_meta("sampler", sampler) (build()'s own single frozen
## WaterSampler for the whole chunk) — there is no more per-cell sampled-
## plane meta pair; a query anywhere inside the box reads that one snapshot
## instead (see WaterSampler.gd).
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
