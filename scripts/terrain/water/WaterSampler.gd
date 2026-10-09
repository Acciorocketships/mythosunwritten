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
# insets away from every waterline curve, so real field-wet shoreline water
# read NaN. Production build() now freezes WaterField's own fill arrays and
# terrain twin. The independent 3m flow/wave grid remains separate; it is not
# used to reconstruct static water height.
#
# PRECISION: level_at runs WaterField's OWN fill evaluator
# (WaterField._fill_bilinear: native 6m surface, sparse 3m rescue, the
# shoreline support correction and the wall-aware crest) over a frozen copy of
# the fill arrays and a WaterGroundSnapshot of the window's point heights, so
# it is the same function as WaterField.level_at, not a hand-copy. (A hand-copy
# once omitted the shoreline support correction and classified dry film on a
# bank as wading.)
#
# FLOW PAYLOAD: alongside the legacy curvilinear frame, build() stores the
# continuous world-XZ current and its vorticity/compression diagnostics on
# the identical grid. Mesh CUSTOM1, wave-particle transport, foam generation,
# and CPU consumers therefore read one frozen field rather than independently
# reconstructing motion.
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
var _fill_origin: Vector2
var _fill_n: int
var _fill_levels: PackedFloat32Array # native WaterField fill snapshot; empty only for legacy no-fill fixtures
# Frozen evaluator input for WaterField._fill_bilinear: fill arrays plus a
# WaterGroundSnapshot standing in for the evicted region (plain data only).
var _fill_ctx: Dictionary = {}
var _fs: PackedFloat32Array      # nx*nz, arc length s (r3 Task 9)
var _fd: PackedFloat32Array      # nx*nz, cross distance d
var _fslope: PackedFloat32Array  # nx*nz, profile slope
var _wave_scale: PackedFloat32Array # nx*nz, GPU-matched depth-limited dynamic-height amplitude
var _velocity: PackedVector2Array   # nx*nz, world-XZ current
var _vorticity: PackedFloat32Array  # nx*nz, dv/dx-du/dz
var _compression: PackedFloat32Array # nx*nz, max(0,-divergence)
## Surface frames (gradient, inward bank) memoized per FRAME_CELL lattice
## point. A frame takes nine exact native fill evaluations; wave packets and
## the ripple flow texture asked for ~1,000-10,000 per frame (October 6: three
## quarters of the main thread). The snapshot is frozen, so a lattice point's
## frame never changes; each is evaluated exactly at the point itself.
const FRAME_CELL := 0.25
const FRAME_CACHE_CAP := 65536
var _frames: Dictionary = {}
var _current_surface := preload("res://scripts/terrain/water/WaterCurrentSurface.gd").new()


## Bakes a sampler from WaterField's own native fill arrays. The supplied
## origin/step/nx/nz grid is retained for flow, waves, and legacy no-fill test
## contexts; production static height is not resampled through it. `ctx` and
## `region` are read during this call only — no reference to either survives
## into the returned instance (chunk eviction frees them).
## `flow_s`/`flow_d`/`flow_slope` (r3 Task 9): the SAME grid's own baked flow
## frame, PRE-COMPUTED by the caller (see this file's header) — must be
## nx*nz, row-major (j*_nx+i), matching `origin`/`step`/`nx`/`nz` exactly.
static func build(ctx: Dictionary, region, origin: Vector2, step: float, nx: int, nz: int,
		flow_s: PackedFloat32Array = PackedFloat32Array(),
		flow_d: PackedFloat32Array = PackedFloat32Array(),
		flow_slope: PackedFloat32Array = PackedFloat32Array(),
		wave_scale: PackedFloat32Array = PackedFloat32Array(),
		flow_velocity: PackedVector2Array = PackedVector2Array(),
		flow_vorticity: PackedFloat32Array = PackedFloat32Array(),
		flow_compression: PackedFloat32Array = PackedFloat32Array()) -> WaterSampler:
	var s := WaterSampler.new()
	s._origin = origin
	s._step = step
	s._nx = nx
	s._nz = nz
	s._h = PackedFloat32Array()
	# Exact static-level snapshot. Packed arrays retain their primitive backing
	# data independently of the ctx Dictionary's lifetime (copy-on-write), so
	# this remains scene-free and safe after the streamer evicts its build ctx.
	if ctx.has("fill") and ctx.has("fill_base"):
		s._fill_origin = ctx.fill_base
		s._fill_n = ctx.get("fill_size", WaterField.FILL_M + 1)
		s._fill_levels = PackedFloat32Array(ctx.fill.levels)
		var fill := {"levels": s._fill_levels}
		if ctx.fill.has("sub_levels"):
			fill["sub_levels"] = PackedFloat32Array(ctx.fill.sub_levels)
			fill["sub_ground"] = PackedFloat32Array(ctx.fill.sub_ground)
			if ctx.fill.has("sub_dry"):
				fill["sub_dry"] = PackedByteArray(ctx.fill.sub_dry)
		var window := Rect2(s._fill_origin, Vector2.ONE * float(s._fill_n - 1) * WaterField.FILL_STEP)
		var node_ground := PackedFloat64Array(); node_ground.resize(s._fill_levels.size()); node_ground.fill(INF)
		s._fill_ctx = {"fill_base": s._fill_origin, "fill_size": s._fill_n, "fill": fill,
			"region": WaterGroundSnapshot.capture(region, window), "node_ground": node_ground}
	else:
		# Legacy/synthetic no-fill context: retain the older mesh-grid snapshot
		# as a safe fallback. Production chunk contexts always take the exact,
		# smaller native-fill path above.
		s._h.resize(nx * nz)
		s._h.fill(NAN)
		for j in nz:
			for i in nx:
				var p: Vector2 = origin + Vector2(i, j) * step
				var lvl: float = WaterField.level_at(ctx, p)
				if lvl == -INF:
					continue
				var g: float = TerrainTileField.surface_y(region, p.x, p.y)
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
	s._wave_scale = wave_scale if wave_scale.size() == n else _ones(n)
	s._velocity = flow_velocity if flow_velocity.size() == n else _zero_vectors(n)
	s._vorticity = flow_vorticity if flow_vorticity.size() == n else _zeros(n)
	s._compression = flow_compression if flow_compression.size() == n else _zeros(n)
	return s


static func _zeros(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


static func _ones(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(1.0)
	return a


static func _zero_vectors(n: int) -> PackedVector2Array:
	var a := PackedVector2Array()
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


## Cheap ownership test: xz lies in this chunk's snapshot and a current
## reaches it (a grid corner with nonzero velocity). Wave packets and the
## ripple flow texture only ask which chunk's current to read, and calm or dry
## points are dropped either way, so they use this instead of a full native
## level evaluation per candidate chunk.
func covers_current(xz: Vector2) -> bool:
	var fx: float = (xz.x - _origin.x) / _step
	var fz: float = (xz.y - _origin.y) / _step
	if fx < 0.0 or fz < 0.0 or fx > float(_nx-1) or fz > float(_nz-1): return false
	var i := mini(int(floor(fx)),_nx-2)
	var j := mini(int(floor(fz)),_nz-2)
	var index := j*_nx+i
	return _velocity[index] != Vector2.ZERO or _velocity[index+1] != Vector2.ZERO or _velocity[index+_nx] != Vector2.ZERO or _velocity[index+_nx+1] != Vector2.ZERO


## Preserve the corner accumulation order without allocating four nested
## Arrays for each wave's start and midpoint every frame.
func _interpolated_velocity(xz: Vector2) -> Vector2:
	var fx: float = (xz.x-_origin.x)/_step
	var fz: float = (xz.y-_origin.y)/_step
	if fx < 0.0 or fz < 0.0 or fx > float(_nx-1) or fz > float(_nz-1): return Vector2.ZERO
	var i := mini(int(floor(fx)),_nx-2)
	var j := mini(int(floor(fz)),_nz-2)
	var tx := fx-float(i)
	var tz := fz-float(j)
	var index := j*_nx+i
	var velocity := Vector2.ZERO
	velocity += _velocity[index]*((1.0-tx)*(1.0-tz))
	velocity += _velocity[index+1]*(tx*(1.0-tz))
	velocity += _velocity[index+_nx]*((1.0-tx)*tz)
	velocity += _velocity[index+_nx+1]*(tx*tz)
	return velocity


## Water height at world (x,z); NAN when the field itself said dry here at
## bake time, or the point falls outside this chunk's own snapshot entirely.
## Mixed wet/dry cells use WaterField's signed-depth shoreline taper; a
## fully-wet cell reduces to plain bilinear.
func level_at(xz: Vector2) -> float:
	var corners: Array = _corners(xz)
	if corners.is_empty():
		return NAN
	if not _fill_levels.is_empty():
		return _native_fill_level_at(xz)
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


## WaterField._fill_bilinear over the frozen fill and ground snapshot. `xz`
## has already passed the chunk-snapshot bounds gate in level_at; the native
## fill extends another 42m around that chunk. NAN where the field is dry.
func _native_fill_level_at(xz: Vector2) -> float:
	var level: float = WaterField._fill_bilinear(_fill_ctx, xz)
	return NAN if level == -INF else level


## Flow frame (arc length s, cross distance d, profile slope), packed as
## Vector3(s, d, slope) — r3 Task 9, frozen the same way level_at is. Plain
## bilinear (no wet/dry renormalization needed: s/d/slope are never NAN,
## WaterSkin bakes a literal 0,0,0 "calm" frame away from any trace — see
## this file's header) over the SAME grid level_at interpolates. Also
## Vector3.ZERO outside this chunk's own snapshot, identical to a genuine
## calm frame; no separate "out of bounds" signal is needed here the way NAN
## is for level.
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


## World-XZ current used by the wave-particle and foam simulations. Calm
## water and points outside this chunk snapshot return zero.
func velocity_at(xz: Vector2) -> Vector2:
	return current_frame_at(xz)[0]


## Current, surface gradient and inward bank direction evaluated together.
## This is a detached local value, not a mutable cache shared by consumers.
func current_frame_at(xz: Vector2) -> PackedVector2Array:
	var velocity := _interpolated_velocity(xz)
	if velocity.length_squared() < .000001:
		return PackedVector2Array([velocity,Vector2.ZERO,Vector2.ZERO])
	var frame := _surface_frame(xz)
	if frame.is_empty():
		return PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])
	return PackedVector2Array([WaterCurrentField.surface_current(velocity,frame[0],frame[1]),frame[0],frame[1]])


## The surface frame at the FRAME_CELL lattice point nearest xz (memoized).
func _surface_frame(xz: Vector2) -> PackedVector2Array:
	var key := Vector2i((xz / FRAME_CELL).round())
	var frame: Variant = _frames.get(key)
	if frame == null:
		if _frames.size() >= FRAME_CACHE_CAP:
			_frames.clear()
		frame = WaterCurrentField.sample_surface_frame(Vector2(key) * FRAME_CELL, _current_surface_level_at)
		_frames[key] = frame
	return frame


## Derivatives use the retained native halo, including across a chunk edge.
## The public velocity query still admits only this chunk's own points.
func _current_surface_level_at(xz: Vector2) -> float:
	if not _fill_levels.is_empty():
		var coverage := Rect2(_fill_origin, Vector2.ONE * ((_fill_n - 1) * WaterField.FILL_STEP))
		if coverage.has_point(xz):
			return _current_fill_level_at(xz)
	return level_at(xz)


## Evaluate the same frozen surface with its immutable fine corners cached.
func _current_fill_level_at(p: Vector2) -> float:
	var level: float = _current_surface.sample(_fill_ctx,p)
	return NAN if level == -INF else level


## (vorticity, compression) paired with velocity_at for wave turning and
## physically generated foam.
func flow_diagnostics_at(xz: Vector2) -> Vector2:
	var corners: Array = _corners(xz)
	if corners.is_empty():
		return Vector2.ZERO
	var diagnostics := Vector2.ZERO
	for cnr: Array in corners:
		var idx: int = cnr[1] * _nx + cnr[0]
		diagnostics += Vector2(_vorticity[idx], _compression[idx]) * cnr[2]
	return diagnostics


## GPU-matched vertical dynamic-height amplitude at world (x,z). Plain bilinear
## interpolation is correct because the mesh's COLOR.r varies linearly over
## its faces too.  Outside this chunk snapshot, return zero so an invalid
## lookup cannot add unbounded buoyancy motion.
func wave_scale_at(xz: Vector2) -> float:
	var corners: Array = _corners(xz)
	if corners.is_empty():
		return 0.0
	var scale := 0.0
	for cnr: Array in corners:
		scale += _wave_scale[cnr[1] * _nx + cnr[0]] * cnr[2]
	return clampf(scale, 0.0, 1.0)
