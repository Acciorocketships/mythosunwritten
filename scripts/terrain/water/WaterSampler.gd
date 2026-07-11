# A frozen, self-contained snapshot of one chunk's water heights, built once
# per WaterSkin.build() call and handed out (via set_meta("sampler", ...)) to
# every trigger Area3D that chunk emits (WaterSurfaceBuilder.build_chunk, r3
# Task 7). Read-only after build(): level_at is a pure function over its own
# packed primitive arrays, with NO live reference back to the WaterPlan,
# HeightfieldRegion, or WaterField ctx Dictionary that built it — those are
# owned by the chunk streamer and freed on eviction. Safe to call from the
# main thread every physics frame: no field query, no mutex, no dictionary
# walk — just two array reads and a lerp.
#
# BACKING DATA (controller brief item 3): built directly from
# WaterSkin._interior_lattice's own return shape — the exact presence/level
# data WaterSkin.build() already computes for the interior mesh (position +
# WaterField.level_at height per point >= WaterSkin.INSET metres inside a
# curve, on WaterSkin.STEP's 3.0m world-aligned grid) — rather than
# re-querying WaterField a second time. That dictionary is copied wholesale
# into two plain arrays (origin/step/nx/nz + a flat PackedFloat32Array of
# heights, NAN where the lattice point was never kept), so nothing here
# retains the ctx/region/water objects the original query used.
#
# PRECISION: level_at bilinear-interpolates over this frozen 3.0m grid — the
# SAME resolution WaterSkin's own interior mesh already renders at, and
# finer than WaterField.level_at's own hydrostatic-fill lattice
# (WaterField.FILL_STEP = 6.0m, itself already bilinear — see
# WaterField._fill_bilinear). Interpolating a second time over a grid that is
# a strict refinement of the field's own bilinear source cannot introduce
# error of a different ORDER than the field's own answer already carries at
# that point — verified directly (tests/test_water_swim_volumes.gd's
# test_sampler_level_at_tracks_the_field): every non-NAN sampler reading on
# the pinned site tracks WaterField.level_at within a small fraction of a
# metre. Two honest gaps, both by design, both read the same fail-safe way
# (NAN = "no swimmable depth answer here", the same direction the trigger
# boxes themselves already round toward — see WaterSurfaceBuilder.build_chunk):
#   1. Within roughly WaterSkin.INSET (2.0m) of a shoreline curve, where the
#      interior lattice deliberately keeps no point (that band is real
#      water — it renders as the boundary strip/meniscus rim — but this
#      sampler was built from the INTERIOR lattice alone, per the
#      controller brief's own "presence/level data the skin already
#      computes").
#   2. Outside the chunk's own kept footprint entirely (dry, or a
#      neighbouring chunk's water — each chunk's sampler only knows its own
#      snapshot).
class_name WaterSampler
extends RefCounted

var _origin: Vector2
var _step: float
var _nx: int
var _nz: int
var _h: PackedFloat32Array   # nx*nz, row-major (j*_nx+i), NAN where not kept


## Builds a sampler from WaterSkin._interior_lattice's own return shape
## ({kept: Dictionary[Vector2i -> {p: Vector2, y: float}], nx: int, nz: int,
## origin: Vector2} — see that function's own docstring). `step` is the
## lattice spacing (WaterSkin.STEP), passed explicitly rather than read off
## WaterSkin itself so this class stays a plain, reusable "frozen bilinear
## grid" with no compile-time dependency on its one current producer. Copies
## only plain Vector2/float/int primitives out of `lattice` — no reference to
## the WaterSkin build state `st` (which holds ctx/region/water) crosses into
## the sampler.
static func build(lattice: Dictionary, step: float) -> WaterSampler:
	var s := WaterSampler.new()
	s._origin = lattice.origin
	s._step = step
	s._nx = lattice.nx
	s._nz = lattice.nz
	s._h = PackedFloat32Array()
	s._h.resize(s._nx * s._nz)
	s._h.fill(NAN)
	var kept: Dictionary = lattice.kept
	for ij: Vector2i in kept:
		var e: Dictionary = kept[ij]
		s._h[ij.y * s._nx + ij.x] = e.y
	return s


## Bilinear height at world (x,z); NAN when any of the query's 4 surrounding
## lattice corners is dry/unkept, or the point falls outside the chunk's own
## snapshot entirely (see this file's header for the two NAN cases).
func level_at(xz: Vector2) -> float:
	var fx: float = (xz.x - _origin.x) / _step
	var fz: float = (xz.y - _origin.y) / _step
	var i0: int = int(floor(fx))
	var j0: int = int(floor(fz))
	if i0 < 0 or j0 < 0 or i0 + 1 >= _nx or j0 + 1 >= _nz:
		return NAN
	var h00: float = _h[j0 * _nx + i0]
	var h10: float = _h[j0 * _nx + i0 + 1]
	var h01: float = _h[(j0 + 1) * _nx + i0]
	var h11: float = _h[(j0 + 1) * _nx + i0 + 1]
	if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
		return NAN
	var tx: float = fx - float(i0)
	var tz: float = fz - float(j0)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
