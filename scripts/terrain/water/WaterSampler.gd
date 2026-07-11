# A frozen, self-contained snapshot of one chunk's water heights, built once
# per WaterSkin.build() call and handed out (via set_meta("sampler", ...)) to
# every trigger Area3D that chunk emits (WaterSurfaceBuilder.build_chunk, r3
# Task 7). Read-only after build(): level_at is a pure function over its own
# packed primitive arrays, with NO live reference back to the WaterPlan,
# HeightfieldRegion, or WaterField ctx Dictionary that built it — those are
# owned by the chunk streamer and freed on eviction (build() reads them
# during the bake only; nothing but plain floats/ints/Vector2s survives into
# the instance). Safe to call from the main thread every physics frame: no
# field query, no mutex, no dictionary walk — just a handful of array reads.
#
# BACKING DATA (r3 Task 7 review MEDIUM fix — supersedes the first bake):
# a snapshot of the FIELD, not the mesh. The first version copied
# WaterSkin._interior_lattice's kept points, but that lattice deliberately
# insets WaterSkin.INSET (2.0m) away from every waterline curve — so the
# ~2-5m band of real, rendered, field-wet water between the inset interior
# and the waterline (the boundary strip + meniscus rim zone) had no data and
# read NaN, and character.gd's bridge classified a character wading right at
# the water's edge as fully dry (the old per-cell sampled planes covered the
# whole cell; render-vs-classification divergence, the same defect family as
# run 2's I4). build() now samples WaterField.level_at itself on the SAME
# 3.0m world-snapped grid across the chunk: every grid corner the field
# calls wet (level - ground > WET_EPS, the same gate WaterSkin._lattice_wet
# uses) stores its exact level_at value regardless of any INSET; NaN only
# where the field itself says dry (or beyond the chunk's own snapshot).
#
# PRECISION: level_at interpolates over this frozen 3.0m grid with the SAME
# renormalized-over-wet-corners bilinear rule WaterField._fill_bilinear
# itself uses over its own 6.0m fill lattice (dry corners excluded, their
# weight redistributed over the wet ones; NaN when no corner is wet) — see
# that function's own docstring for why plain weighted summation cannot be
# trusted once any corner is dry. The 3.0m grid is world-snapped and
# phase-aligned with the fill's own lattice, and bilinear interpolation of
# corner samples of a bilinear function on an aligned subgrid reproduces the
# parent function EXACTLY — so on fully-wet cells the sampler equals
# WaterField.level_at (measured: max_err 0.000 across the pinned site's
# interior), and on mixed wet/dry cells (the shoreline band) it applies the
# same renormalization family the field itself does, measured within 0.1 of
# level_at at 260 real shoreline-band points (tests/
# test_water_swim_volumes.gd::test_sampler_covers_the_shoreline_band, the
# review-MEDIUM regression pin).
#
# FLOW FRAME (r3 Task 9): alongside the level grid, build() now ALSO bakes
# WaterSkin's own per-vertex flow frame (_flow_frame_at: arc length s, cross
# distance d, profile slope) onto the IDENTICAL grid geometry, so
# flow_frame_at(xz) can answer "what river frame applies HERE" for any
# character position, not just a mesh vertex. The frame arrays are supplied
# ALREADY BAKED by the caller (WaterSkin.build, via its own private
# _flow_frame_at — kept a WaterSkin-internal call so this file doesn't need a
# reverse dependency on WaterSkin's class_name) rather than recomputed here;
# this file only stores and bilinear-interpolates them, exactly mirroring how
# it already treats `_h`. Unlike level, s/d/slope are never NAN (WaterSkin's
# own "calm" rule bakes a literal 0,0,0 away from any trace) — so this grid
# needs no wet/dry renormalization, plain bilinear suffices.
class_name WaterSampler
extends RefCounted

# Same wetness gate WaterSkin._lattice_wet applies to ITS lattice (level at
# or under ground + 2cm reads as dry): the sampler must agree with the
# skin's own wet/dry oracle so the sampler's coverage is exactly the water
# the skin renders — including the shoreline band the skin covers with
# strip/rim geometry rather than lattice points.
const WET_EPS := 0.02

var _origin: Vector2
var _step: float
var _nx: int
var _nz: int
var _h: PackedFloat32Array   # nx*nz, row-major (j*_nx+i), NAN where field-dry
var _fs: PackedFloat32Array      # nx*nz, arc length s (r3 Task 9)
var _fd: PackedFloat32Array      # nx*nz, cross distance d
var _fslope: PackedFloat32Array  # nx*nz, profile slope


## Bakes a sampler by sampling WaterField.level_at across the given grid
## (origin/step/nx/nz — WaterSkin.build passes its OWN interior-lattice grid
## geometry, so sampler coverage and mesh lattice stay column-aligned). Every
## grid corner the field calls wet stores its exact level; dry corners stay
## NAN. `ctx`/`region` are read during this call only — no reference to
## either survives into the returned instance (chunk eviction frees them).
## `flow_s`/`flow_d`/`flow_slope` (r3 Task 9): the SAME grid's own baked flow
## frame, PRE-COMPUTED by the caller (see this file's header) — must be
## nx*nz, row-major (j*_nx+i), matching `origin`/`step`/`nx`/`nz` exactly.
static func build(ctx: Dictionary, region, origin: Vector2, step: float, nx: int, nz: int,
		flow_s: PackedFloat32Array = PackedFloat32Array(),
		flow_d: PackedFloat32Array = PackedFloat32Array(),
		flow_slope: PackedFloat32Array = PackedFloat32Array()) -> WaterSampler:
	var s := WaterSampler.new()
	s._origin = origin
	s._step = step
	s._nx = nx
	s._nz = nz
	s._h = PackedFloat32Array()
	s._h.resize(nx * nz)
	s._h.fill(NAN)
	for j in nz:
		for i in nx:
			var p: Vector2 = origin + Vector2(i, j) * step
			var lvl: float = WaterField.level_at(ctx, p)
			if lvl == -INF:
				continue
			var g: float = TerrainSurfaceField.surface_y(region, p.x, p.y)
			if lvl <= g + WET_EPS:
				continue
			s._h[j * nx + i] = lvl
	# Flow frame: same grid, zero-filled when the caller didn't supply one
	# (e.g. pre-Task-9 test fixtures that build a sampler without a flow
	# bake) — a zero frame is exactly WaterSkin's own "calm" convention, so
	# flow_frame_at degrades to "no river motion" rather than erroring.
	var n: int = nx * nz
	s._fs = flow_s if flow_s.size() == n else _zeros(n)
	s._fd = flow_d if flow_d.size() == n else _zeros(n)
	s._fslope = flow_slope if flow_slope.size() == n else _zeros(n)
	return s


static func _zeros(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


## Shared bilinear corner/weight lookup for `xz` (four [i, j, weight]
## triples) — factored out of level_at so flow_frame_at (r3 Task 9) reuses
## the exact same cell/weight math instead of a second hand-copy. Empty when
## `xz` falls outside this chunk's own snapshot; callers decide what that
## means for their own quantity (level_at: NAN/"dry"; flow_frame_at:
## Vector3.ZERO/"calm" — see that function's own docstring).
func _corners(xz: Vector2) -> Array:
	var fx: float = (xz.x - _origin.x) / _step
	var fz: float = (xz.y - _origin.y) / _step
	if fx < 0.0 or fz < 0.0 or fx > float(_nx - 1) or fz > float(_nz - 1):
		return []
	var i0: int = mini(int(floor(fx)), _nx - 2)
	var j0: int = mini(int(floor(fz)), _nz - 2)
	var tx: float = fx - float(i0)
	var tz: float = fz - float(j0)
	return [
		[i0, j0, (1.0 - tx) * (1.0 - tz)],
		[i0 + 1, j0, tx * (1.0 - tz)],
		[i0, j0 + 1, (1.0 - tx) * tz],
		[i0 + 1, j0 + 1, tx * tz],
	]


## Water height at world (x,z); NAN when the field itself said dry here at
## bake time, or the point falls outside this chunk's own snapshot entirely.
## Mixed wet/dry cells renormalize the bilinear weights over the wet corners
## only — the exact rule WaterField._fill_bilinear applies to its own -INF
## corners (see this file's header PRECISION note); a fully-wet cell reduces
## to plain bilinear (weights already sum to 1).
func level_at(xz: Vector2) -> float:
	var corners: Array = _corners(xz)
	if corners.is_empty():
		return NAN
	var wsum := 0.0
	var acc := 0.0
	for cnr: Array in corners:
		var h: float = _h[cnr[1] * _nx + cnr[0]]
		if is_nan(h):
			continue
		acc += h * cnr[2]
		wsum += cnr[2]
	if wsum <= 0.0:
		return NAN
	return acc / wsum


## Flow frame (arc length s, cross distance d, profile slope), packed as
## Vector3(s, d, slope) — r3 Task 9, frozen the same way level_at is. Plain
## bilinear (no wet/dry renormalization needed: s/d/slope are never NAN,
## WaterSkin bakes a literal 0,0,0 "calm" frame away from any trace — see
## this file's header) over the SAME grid level_at interpolates. Also
## Vector3.ZERO outside this chunk's own snapshot; the character's
## river-train mirror treats that identically to a genuine calm frame (its
## own river_present gate already zeroes the whole term at (0,0,0)), so no
## separate "out of bounds" signal is needed here the way NAN is for level.
func flow_frame_at(xz: Vector2) -> Vector3:
	var corners: Array = _corners(xz)
	if corners.is_empty():
		return Vector3.ZERO
	var s := 0.0
	var d := 0.0
	var slope := 0.0
	for cnr: Array in corners:
		var idx: int = cnr[1] * _nx + cnr[0]
		var w: float = cnr[2]
		s += _fs[idx] * w
		d += _fd[idx] * w
		slope += _fslope[idx] * w
	return Vector3(s, d, slope)
