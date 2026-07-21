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
# PRECISION: level_at evaluates the native 6m surface plus WaterField's sparse
# topology-only 3m rescue, using the exact same signed-depth interpolation at
# both resolutions. An earlier sampler resampled static height onto another
# grid; across wet/dry cells that second interpolation changed levels by up to
# 0.44m and could classify a dry/wading point as swimming. Freezing the actual
# dual-resolution field is bit-for-bit faithful to WaterField.level_at.
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
var _fill_ground: PackedFloat32Array # native terrain heights for the mixed wet/dry taper
var _fill_sub_levels: PackedFloat32Array # sparse 3m topology rescues, -INF elsewhere
var _fill_sub_ground: PackedFloat32Array # frozen one-ring terrain for rescued cells
var _fs: PackedFloat32Array      # nx*nz, arc length s (r3 Task 9)
var _fd: PackedFloat32Array      # nx*nz, cross distance d
var _fslope: PackedFloat32Array  # nx*nz, profile slope
var _wave_scale: PackedFloat32Array # nx*nz, GPU-matched depth-limited dynamic-height amplitude
var _velocity: PackedVector2Array   # nx*nz, world-XZ current
var _vorticity: PackedFloat32Array  # nx*nz, dv/dx-du/dz
var _compression: PackedFloat32Array # nx*nz, max(0,-divergence)


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
		s._fill_n = WaterField.FILL_M + 1
		s._fill_levels = PackedFloat32Array(ctx.fill.levels)
		if ctx.fill.has("sub_levels"):
			s._fill_sub_levels = PackedFloat32Array(ctx.fill.sub_levels)
			s._fill_sub_ground = PackedFloat32Array(ctx.fill.sub_ground)
		s._fill_ground = PackedFloat32Array()
		s._fill_ground.resize(s._fill_n * s._fill_n)
		for j in s._fill_n:
			for i in s._fill_n:
				var p: Vector2 = s._fill_origin + Vector2(i, j) * WaterField.FILL_STEP
				s._fill_ground[j * s._fill_n + i] = \
					TerrainSurfaceField.surface_y(region, p.x, p.y)
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


## Exact frozen equivalent of WaterField._fill_bilinear. `xz` has already
## passed the chunk-snapshot bounds gate in level_at; the native fill itself
## extends another 30m around that chunk, so these indices are always valid.
func _native_fill_level_at(xz: Vector2) -> float:
	var coarse: float = _native_coarse_fill_level_at(xz)
	if _fill_sub_levels.is_empty():
		return coarse
	var sub_n := WaterField.FILL_SUB_M + 1
	var fx: float = (xz.x - _fill_origin.x) / WaterField.FILL_SUB_STEP
	var fz: float = (xz.y - _fill_origin.y) / WaterField.FILL_SUB_STEP
	var i0: int = clampi(int(floor(fx)), 0, WaterField.FILL_SUB_M - 1)
	var j0: int = clampi(int(floor(fz)), 0, WaterField.FILL_SUB_M - 1)
	var touched := false
	for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(1, 1)]:
		if _fill_sub_levels[(j0 + d.y) * sub_n + i0 + d.x] != -INF:
			touched = true
			break
	if not touched:
		return coarse
	return _native_sub_fill_level_at(xz, i0, j0, fx, fz)


func _native_coarse_fill_level_at(xz: Vector2) -> float:
	var fx: float = (xz.x - _fill_origin.x) / WaterField.FILL_STEP
	var fz: float = (xz.y - _fill_origin.y) / WaterField.FILL_STEP
	var i0: int = clampi(int(floor(fx)), 0, _fill_n - 2)
	var j0: int = clampi(int(floor(fz)), 0, _fill_n - 2)
	var tx: float = clampf(fx - float(i0), 0.0, 1.0)
	var tz: float = clampf(fz - float(j0), 0.0, 1.0)
	var native_corners: Array = [
		[i0, j0, (1.0 - tx) * (1.0 - tz)],
		[i0 + 1, j0, tx * (1.0 - tz)],
		[i0, j0 + 1, (1.0 - tx) * tz],
		[i0 + 1, j0 + 1, tx * tz],
	]
	var wet_weight := 0.0
	var wet_acc := 0.0
	for cnr: Array in native_corners:
		var h: float = _fill_levels[cnr[1] * _fill_n + cnr[0]]
		if h == -INF:
			continue
		wet_acc += h * cnr[2]
		wet_weight += cnr[2]
	if wet_weight <= 0.0:
		return NAN
	if wet_weight >= 1.0 - 0.000001:
		return wet_acc
	var wet_ref: float = wet_acc / wet_weight
	var acc := 0.0
	for cnr: Array in native_corners:
		var idx: int = cnr[1] * _fill_n + cnr[0]
		var h: float = _fill_levels[idx]
		if h == -INF:
			h = minf(wet_ref,
				_fill_ground[idx] + WaterField.EPS - WaterField.SHORE_DRY_DEPTH)
		acc += h * cnr[2]
	return acc


## Frozen equivalent of WaterField._fill_bilinear_sub. Only cells touching
## a sparse topology rescue take this path; all other samples retain the
## native 6m evaluation above exactly.
func _native_sub_fill_level_at(xz: Vector2, i0: int, j0: int,
		fx: float, fz: float) -> float:
	var sub_n := WaterField.FILL_SUB_M + 1
	var tx: float = clampf(fx - float(i0), 0.0, 1.0)
	var tz: float = clampf(fz - float(j0), 0.0, 1.0)
	var corners := [
		[i0, j0, (1.0 - tx) * (1.0 - tz)],
		[i0 + 1, j0, tx * (1.0 - tz)],
		[i0, j0 + 1, (1.0 - tx) * tz],
		[i0 + 1, j0 + 1, tx * tz],
	]
	var corner_levels := PackedFloat32Array()
	corner_levels.resize(4)
	var corner_ground := PackedFloat32Array()
	corner_ground.resize(4)
	var wet_weight := 0.0
	var wet_acc := 0.0
	for k in corners.size():
		var cnr: Array = corners[k]
		var idx: int = cnr[1] * sub_n + cnr[0]
		var ground: float = _fill_sub_ground[idx]
		if ground == INF:
			# WaterField freezes a complete one-ring around every rescue. An
			# absent value means this is not a valid refined cell; preserve the
			# canonical coarse answer rather than inventing terrain at runtime.
			return _native_coarse_fill_level_at(xz)
		var h: float = _fill_sub_levels[idx]
		if h == -INF:
			var q: Vector2 = _fill_origin \
				+ Vector2(cnr[0], cnr[1]) * WaterField.FILL_SUB_STEP
			h = _native_coarse_fill_level_at(q)
		corner_levels[k] = h
		corner_ground[k] = ground
		if not is_nan(h) and h > ground + WaterField.EPS:
			wet_acc += h * cnr[2]
			wet_weight += cnr[2]
	if wet_weight <= 0.0:
		return NAN
	if wet_weight >= 1.0 - 0.000001:
		return wet_acc
	var wet_ref: float = wet_acc / wet_weight
	var acc := 0.0
	for k in corners.size():
		var h: float = corner_levels[k]
		if is_nan(h) or h <= corner_ground[k] + WaterField.EPS:
			h = minf(wet_ref, corner_ground[k] + WaterField.EPS \
				- WaterField.SHORE_DRY_DEPTH)
		acc += h * corners[k][2]
	return acc


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
	var corners: Array = _corners(xz)
	if corners.is_empty():
		return Vector2.ZERO
	var velocity := Vector2.ZERO
	for cnr: Array in corners:
		velocity += _velocity[cnr[1] * _nx + cnr[0]] * cnr[2]
	return velocity


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
