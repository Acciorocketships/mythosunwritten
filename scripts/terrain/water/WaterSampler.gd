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


## Bakes a sampler by sampling WaterField.level_at across the given grid
## (origin/step/nx/nz — WaterSkin.build passes its OWN interior-lattice grid
## geometry, so sampler coverage and mesh lattice stay column-aligned). Every
## grid corner the field calls wet stores its exact level; dry corners stay
## NAN. `ctx`/`region` are read during this call only — no reference to
## either survives into the returned instance (chunk eviction frees them).
static func build(ctx: Dictionary, region, origin: Vector2, step: float, nx: int, nz: int) -> WaterSampler:
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
	return s


## Water height at world (x,z); NAN when the field itself said dry here at
## bake time, or the point falls outside this chunk's own snapshot entirely.
## Mixed wet/dry cells renormalize the bilinear weights over the wet corners
## only — the exact rule WaterField._fill_bilinear applies to its own -INF
## corners (see this file's header PRECISION note); a fully-wet cell reduces
## to plain bilinear (weights already sum to 1).
func level_at(xz: Vector2) -> float:
	var fx: float = (xz.x - _origin.x) / _step
	var fz: float = (xz.y - _origin.y) / _step
	if fx < 0.0 or fz < 0.0 or fx > float(_nx - 1) or fz > float(_nz - 1):
		return NAN
	var i0: int = mini(int(floor(fx)), _nx - 2)
	var j0: int = mini(int(floor(fz)), _nz - 2)
	var tx: float = fx - float(i0)
	var tz: float = fz - float(j0)
	var corners := [
		[i0, j0, (1.0 - tx) * (1.0 - tz)],
		[i0 + 1, j0, tx * (1.0 - tz)],
		[i0, j0 + 1, (1.0 - tx) * tz],
		[i0 + 1, j0 + 1, tx * tz],
	]
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
