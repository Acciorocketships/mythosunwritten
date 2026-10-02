class_name ReliefPrimitives
extends RefCounted

## Structural noise building blocks for regime relief (spec 2026-10-02 §4).
## Every function is static and a pure function of position, seed and explicit
## parameters in metres. Value noise comes from Helper._value_noise01; octaves
## are rotated about the origin so lattice axes never line up.

const OCTAVE_TURN := 0.61


static func vnoise01(p: Vector2, seed: int, wavelength_m: float) -> float:
	return Helper._value_noise01(Vector3(p.x, 0.0, p.y), seed, wavelength_m)


static func vnoise(p: Vector2, seed: int, wavelength_m: float) -> float:
	return vnoise01(p, seed, wavelength_m) * 2.0 - 1.0


static func warp(p: Vector2, seed: int, amplitude_m: float, wavelength_m: float) -> Vector2:
	if amplitude_m <= 0.0:
		return p
	return p + Vector2(vnoise(p, seed + 11, wavelength_m), vnoise(p, seed + 13, wavelength_m)) * amplitude_m


## Billowy |noise| sum in [0, 1]: gentle rolling ground.
static func hummock(p: Vector2, seed: int, wavelength_m: float, octaves: int) -> float:
	var total := 0.0
	var norm := 0.0
	var amp := 1.0
	var lam := wavelength_m
	for o in octaves:
		total += absf(vnoise(p.rotated(OCTAVE_TURN * o), seed + 17 * o, lam)) * amp
		norm += amp
		amp *= 0.5
		lam *= 0.5
	return total / norm


## Ridged multifractal in [0, 1]: crests (1) form connected networks. Each octave
## is weighted by the previous one so detail concentrates on the ridges.
static func ridged(p: Vector2, seed: int, wavelength_m: float, octaves: int, sharpness: float) -> float:
	var total := 0.0
	var norm := 0.0
	var amp := 1.0
	var weight := 1.0
	var lam := wavelength_m
	for o in octaves:
		var r := pow(1.0 - absf(vnoise(p.rotated(OCTAVE_TURN * o), seed + 17 * o, lam)), sharpness)
		r *= weight
		weight = clampf(r * 1.6, 0.0, 1.0)
		total += r * amp
		norm += amp
		amp *= 0.5
		lam *= 0.5
	return total / norm


## Central-difference gradient (per metre) of a two-octave ridged field.
static func ridged_gradient(p: Vector2, seed: int, wavelength_m: float, sharpness: float) -> Vector2:
	var e := wavelength_m * 0.02
	var dx := ridged(p + Vector2(e, 0.0), seed, wavelength_m, 2, sharpness) \
		- ridged(p - Vector2(e, 0.0), seed, wavelength_m, 2, sharpness)
	var dz := ridged(p + Vector2(0.0, e), seed, wavelength_m, 2, sharpness) \
		- ridged(p - Vector2(0.0, e), seed, wavelength_m, 2, sharpness)
	return Vector2(dx, dz) / (2.0 * e)


## Multiplier that lowers crests into passes at roughly spacing_m intervals.
static func pass_mod(p: Vector2, seed: int, spacing_m: float, depth: float) -> float:
	return 1.0 - depth * smoothstep(0.55, 0.8, vnoise01(p, seed, spacing_m))


## Grooves and spurs running downhill: a Gabor-like sum of jittered kernels,
## each a cosine across the downhill direction, in a compactly supported window.
static func gully(p: Vector2, seed: int, spacing_m: float, downhill: Vector2) -> float:
	if downhill.length_squared() < 1e-12:
		return 0.0
	var across := Vector2(-downhill.y, downhill.x).normalized()
	var q := p / spacing_m
	var c := Vector2i(floori(q.x), floori(q.y))
	var total := 0.0
	var weights := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dz)
			var centre := Vector2(cell) + Vector2(
				0.25 + 0.5 * Helper._cell_hash01(seed, cell.x, cell.y),
				0.25 + 0.5 * Helper._cell_hash01(seed + 1, cell.x, cell.y))
			var d := q - centre
			# Compact window (zero at 1.25 cells): kernels outside the 3x3 block
			# sit at least 1.25 cells away, so they contribute exactly nothing
			# and the sum is continuous; the own-cell kernel is within 1.06.
			var w := maxf(0.0, 1.0 - d.length_squared() / (1.25 * 1.25))
			w *= w
			var phase := Helper._cell_hash01(seed + 2, cell.x, cell.y) * TAU
			total += w * cos(TAU * d.dot(across) + phase)
			weights += w
	return clampf(total / maxf(weights, 1e-6), -1.0, 1.0)


## Max over the 3x3 neighbouring cells of a radial bump around each admitted
## site (hash < density). Sites sit in [0.2, 0.8] of their cell, so any site
## outside the 3x3 block is at least 1.2 cells away: radius_m <= spacing_m keeps
## the field exactly continuous. edge in [0, 1) flattens the bump's top/floor.
static func sites_bump(p: Vector2, seed: int, spacing_m: float, density: float, radius_m: float, edge: float) -> float:
	assert(radius_m <= spacing_m, "ReliefPrimitives.sites_bump: radius must not exceed spacing")
	var q := p / spacing_m
	var c := Vector2i(floori(q.x), floori(q.y))
	var best := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell := c + Vector2i(dx, dz)
			if Helper._cell_hash01(seed + 3, cell.x, cell.y) >= density:
				continue
			var site := (Vector2(cell) + Vector2(
				0.2 + 0.6 * Helper._cell_hash01(seed, cell.x, cell.y),
				0.2 + 0.6 * Helper._cell_hash01(seed + 1, cell.x, cell.y))) * spacing_m
			var size := 0.6 + 0.4 * Helper._cell_hash01(seed + 2, cell.x, cell.y)
			var r := radius_m * size
			var d := p.distance_to(site)
			if d < r:
				best = maxf(best, (1.0 - smoothstep(edge, 1.0, d / r)) * size)
	return best


## Worley F1/F2 (metres) over a 5x5 block (exact for sites in [0.25, 0.75]),
## plus the nearest cell's hash for per-cell variation.
static func worley(p: Vector2, seed: int, spacing_m: float) -> Vector3:
	var q := p / spacing_m
	var c := Vector2i(floori(q.x), floori(q.y))
	var f1 := INF
	var f2 := INF
	var id := 0.0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cell := c + Vector2i(dx, dz)
			var site := Vector2(cell) + Vector2(
				0.25 + 0.5 * Helper._cell_hash01(seed, cell.x, cell.y),
				0.25 + 0.5 * Helper._cell_hash01(seed + 1, cell.x, cell.y))
			var d := q.distance_to(site)
			if d < f1:
				f2 = f1
				f1 = d
				id = Helper._cell_hash01(seed + 2, cell.x, cell.y)
			elif d < f2:
				f2 = d
	return Vector3(f1 * spacing_m, f2 * spacing_m, id)


## Treads on multiples of step; each riser occupies the top riser_frac of its
## step interval. Monotone, continuous, exact on treads.
static func terrace(h: float, step: float, riser_frac: float) -> float:
	var k := floorf(h / step)
	var t := smoothstep(1.0 - riser_frac, 1.0, h / step - k)
	return (k + t) * step
