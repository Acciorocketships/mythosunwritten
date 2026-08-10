extends RefCounted

## GROUND FRAMES for the mass-first suites, in the plain
## `Dictionary[Vector2i -> int]` WarrenMassifBuilder.build actually takes.
##
## The massif now authors a deep 2-18-band inhabited mountain above real terrain
## (SettlementReliefPlan, stamped into HeightfieldPlan._sample). Flat ground is
## valid, but the terrain-sensitive suites still share this measured hill so
## their relief, bearing, and route-grade assertions describe the same town.
##
## `hill()` is a synthetic reproduction of what
## VillageWarrenFabricSolver._sample_ground_bands reads back off a stamped site,
## not an invention. The three numbers it reproduces were measured through the
## real chain (TerrainWorldTuning.make_relief -> make_heightfield ->
## compute_region -> VillageTerrainView -> the five-probe ceil) by
## tests/harness/warren_buildable_layer_probe.gd over seeds 0-39:
##
##   - relief under the footprint: 2-13 bands, mean 6;
##   - riser between adjacent terraces: 2-3 bands, i.e. the 4 m terrain storey
##     read through 1.5 m warren bands;
##   - bench width: 8-12 columns, i.e. SettlementReliefPlan.RING_WIDTH_CELLS of
##     24 m terrain cell divided by the 3 m column pitch.
##
## The probe harness remains the instrument of record for anything measured
## against the REAL stamp; this fixture exists so a unit suite can build a town
## in milliseconds without standing up the terrain stack.

## One 4 m terrain storey read through 1.5 m warren bands, ceiled the way the
## production sampler ceils.
const RISER_BANDS := 3
## Columns per terrace bench.
const BENCH_COLUMNS := 5
## Benches between the crown and the frame's zero band.
const BENCH_COUNT := 3


static func hill(span: int, world_seed: int = 0) -> Dictionary:
	## A terraced bell in the massif's own 3 m column lattice: a crown, one flat
	## bench per storey of relief, and band zero outside. Warped and
	## peak-offset in the same three-lobe family SettlementReliefPlan uses, so
	## the frame is not a bullseye centred on column (0, 0) and a route cannot
	## climb it by walking a perfect radius.
	var phase := float(posmod(world_seed * 73856093 ^ 2311, 1000)) / 1000.0 * TAU
	var offset := Vector2(cos(phase), sin(phase)) * 1.5
	var bands: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var local := Vector2(float(x), float(z)) - offset
			var radius := local.length()
			var angle := atan2(local.y, local.x)
			var warped := radius * (1.0 + 0.12 * sin(angle * 3.0 + phase))
			var bench := int(floor(warped / float(BENCH_COLUMNS)))
			bands[Vector2i(x, z)] = RISER_BANDS \
				* maxi(0, BENCH_COUNT - bench)
	return bands


static func flat(span: int) -> Dictionary:
	var bands: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			bands[Vector2i(x, z)] = 0
	return bands


static func ramp(span: int, bands_per_column: float = 0.25) -> Dictionary:
	## A featureless constant-gradient slope. Used only by the gate-invariance
	## property, which asks whether a shape gate charges the builder for the
	## landscape; it is deliberately not a shape any stamp produces.
	var bands: Dictionary = {}
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			bands[Vector2i(x, z)] = int(float(x + span) * bands_per_column)
	return bands
