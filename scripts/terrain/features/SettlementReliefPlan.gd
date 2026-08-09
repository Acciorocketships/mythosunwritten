class_name SettlementReliefPlan
extends RefCounted

## SETTLEMENT RELIEF STAMP -- the landform a mass-first town stands on,
## authored as real terrain instead of drawn by the village fabric.
##
## Duck-typed into HeightfieldPlan exactly the way the water carve is
## (HeightfieldPlan._sample): the carve LOWERS the continuous field before
## quantization, this RAISES it, and everything downstream -- storey
## quantization, the trickle-down clamp, the level tier, cliff classification,
## KayKit cliff dressing, grass suppression and terrain collision -- follows
## with no new rendering code at all. See
## docs/superpowers/specs/2026-08-09-warren-terrain-integration-design.md §3.2.
##
## THE FORMULA. The stamp is a FILL to a target elevation, not an additive
## bump:
##
##     relief(cell) = clamp(profile(cell) - max(0, h(cell) - h_floor), 0, budget)
##
## so the composed field is `max(h, h_floor + profile)`. That single expression
## is the design's three-mode split (§3.8) with no branches: on a flat site the
## natural rise is 0 and the town gets the whole profile (STAMP); on a site that
## already carries the relief the natural rise cancels the profile and the stamp
## returns zero everywhere (CONFORM); in between it supplies only the deficit
## (BLEND). Being a fill also means the part of the hill the stamp owns is a
## surface this class fully determines, which is what makes the terrace BENCHES
## provable rather than hoped for -- see `_profile`.
##
## CONTRACT (each item pinned by tests/test_settlement_relief.gd):
##  - pure function of (world_seed, SEED_VERSION, cell); the memos never change
##    a value, exactly as HeightfieldPlan._samples never does;
##  - MONOTONE RAISE ONLY -- never negative, never lowers natural ground;
##    conform-only is a ZERO stamp, not a negative one;
##  - zero where the water carve is non-zero (enforced by HeightfieldPlan._sample,
##    which is the only place that knows the carve it actually applied) and the
##    outer radius is bounded below SettlementPlan.WATER_CLEARANCE so the two
##    writers can never argue in the first place;
##  - bounded against the storey ceiling so the quantizer's clamp can never
##    silently truncate the hilltop into the wide plateau MAX_PLATEAU_CELLS
##    exists to forbid;
##  - window independent: a pure per-cell function leaves HeightfieldPlan's
##    storey_margin() proof untouched.

const SEED_VERSION := 1

## THE RELIEF BUDGET -- the one number that says how much ground the stamp may
## add, in metres above the site's own natural ground.
##
## OPEN RULING, and this constant is where that ruling lands. The project's
## reviewer has been asked whether a TERRAIN-AUTHORED KayKit cliff counts as
## "visible stone" under the 2-3 storey rule (mass-first ledger lines 214/218);
## THAT RULING SETS THE FINAL NUMBER. If terrain cliffs read as landscape, the
## budget can grow to three or four storeys and the hill gets real crags; if
## they read as masonry, it stays at or below this value. Nothing else in the
## milestone may be tuned to compensate for the budget -- change this constant.
##
## Until then, deliberately conservative: 8.0 m = 2 terrain storeys = 5.33
## warren bands, which is the design's own measured ceiling for a 99 m
## footprint that must stay free of cliff tops (§3.1, "a 2-cell footprint
## radius buys only 2 storeys = 8 m = 5.3 bands of ground rise inside the
## town"). Raising it widens `outer_radius_cells`, which two tests bound: the
## stamp must stay inside its own settlement super-cell and inside
## SettlementPlan.WATER_CLEARANCE.
const RELIEF_BUDGET_METRES := 8.0

## Radial shape, in 24 m terrain cells. The profile is a TERRACED bell: a flat
## crown, then one flat ring per storey of budget, then a smooth foot that
## meets pre-existing ground. Each ring is a genuine bench -- see `_profile`.
const CROWN_RADIUS_CELLS := 1.0
const RING_WIDTH_CELLS := 1.4
const FOOT_WIDTH_CELLS := 1.2
## Sub-cell displacement of the crown from the settlement cell, so the hill is
## not a bullseye centred on its own site marker.
const PEAK_OFFSET_CELLS := 0.45
## Angular warp, the same three-lobe family WarrenMassifBuilder uses for the
## massif footprint (WarrenMassifBuilder.gd:50-68) so the hill keeps the
## character the massif used to author -- in its own salt space.
const WARP_LOBES := 3.0
const WARP_STRENGTH_MIN := 0.12
const WARP_STRENGTH_SPAN := 0.14

## Headroom kept clear of the quantizer's `max_storeys` clamp
## (HeightfieldPlan.quantize_storey:153-154). A stamp allowed to reach that
## clamp saturates and renders as a wide flat plateau -- design risk 2 -- and
## raising HEIGHTFIELD_MAX_STOREYS is forbidden because it is the clamp window
## margin and re-rolls the entire world. More than one storey, so the reserve
## survives every rounding mode ("mean" rounds, "max" ceils).
const CEILING_MARGIN_METRES := 4.5

const _SALT_PHASE := 2311
const _SALT_WARP := 2417
const _SALT_PEAK_X := 2521
const _SALT_PEAK_Z := 2633
const _CACHE_CAP := 256

var _world_seed: int
var _settlements                       # duck-typed: site_for(super) -> Dictionary
var _amplitude: float
var _max_storeys: int
var _budget: float
var _outer_cells: float
var _ceiling: float
var _natural_override: Callable = Callable()
var _site_cache: Dictionary = {}

## DIAGNOSTIC ONLY, never an input to a value: set when the storey-ceiling
## clamp actually had to bite, with the worst deficit in metres. The shipped
## configuration must never trip it (tests/test_settlement_relief.gd), and the
## flag is what makes that assertable instead of invisible. Depends on which
## cells were sampled, so it is a report, not part of the pure function.
##
## Written by whichever thread samples the field. In production that is the
## terrain worker and nothing else, under the same confinement that already
## covers HeightfieldPlan's sample memo and WaterPlan's trace caches
## (FieldTerrainStreamer.gd:60-62) -- so no lock, and no read from the main
## thread.
var ceiling_clamped := false
var ceiling_deficit_metres := 0.0


## `p_amplitude` / `p_max_storeys` are REQUIRED and must be the same values the
## HeightfieldPlan this stamp is attached to was built with: the ceiling clamp
## and the fill formula both read the natural field, so a stamp with a
## different amplitude is measuring a different world. Production callers go
## through TerrainWorldTuning.make_relief rather than copying literals -- see
## that file's header on harness/streamer divergence. (Named literally rather
## than defaulted from TerrainWorldTuning so this class carries no dependency
## back on the wiring layer that constructs it.)
func _init(world_seed: int, settlements, p_amplitude: float,
		p_max_storeys: int,
		p_budget_metres: float = RELIEF_BUDGET_METRES) -> void:
	assert(settlements != null)
	assert(settlements.has_method("site_for"),
		"SettlementReliefPlan needs a site source exposing site_for(super_cell)")
	assert(p_amplitude > 0.0)
	assert(p_max_storeys > 0)
	assert(p_budget_metres >= 0.0, "the relief stamp only ever raises")
	_world_seed = world_seed
	_settlements = settlements
	_amplitude = p_amplitude
	_max_storeys = p_max_storeys
	_budget = p_budget_metres
	_outer_cells = outer_radius_cells(_budget)
	_ceiling = float(p_max_storeys) * HeightfieldPlan.STOREY_HEIGHT \
		- CEILING_MARGIN_METRES


## Whether a shipping world stamps at all. The hill belongs to MASS-FIRST
## towns; a route-first village is laid on natural terrain by the existing
## conform-only machinery and must keep seeing a world byte-identical to
## today's. Mass-first is opt-in (WarrenTownSolver.GENERATION_MODE defaults to
## route-first), so this is false in every shipping world until that default
## changes -- which is the production-safety guarantee for this wave, and the
## reason the streamer can attach the stamp unconditionally.
static func is_active() -> bool:
	return WarrenTownSolver.GENERATION_MODE == WarrenTownSolver.MODE_MASS_FIRST


## Number of flat terrace tiers the profile carries, one per storey of budget.
static func terrace_steps(budget_metres: float) -> int:
	return maxi(1, int(round(budget_metres / HeightfieldPlan.STOREY_HEIGHT)))


## Radius, in terrain cells, past which the stamp is exactly zero. Two
## properties depend on it and both are tested:
##  - it must stay under 8 cells, because SettlementPlan places every site at
##    least 8 cells inside its own 32-cell super cell
##    (SettlementPlan._compute_site:55-57 offsets it into [8, 23]), so a stamp
##    narrower than that can never reach a cell belonging to another super
##    cell -- which is what lets relief_at_cell resolve a site with ONE lookup;
##  - it must stay under SettlementPlan.WATER_CLEARANCE (108 m), so the raise
##    and the carve can never contest a cell.
static func outer_radius_cells(budget_metres: float) -> float:
	if budget_metres <= 0.0:
		return 0.0
	return CROWN_RADIUS_CELLS \
		+ float(terrace_steps(budget_metres) - 1) * RING_WIDTH_CELLS \
		+ FOOT_WIDTH_CELLS


func budget_metres() -> float:
	return _budget


func outer_radius_metres() -> float:
	return _outer_cells * HeightfieldPlan.TILE


## Test-only mirror of HeightfieldPlan.set_raw_height_override. The fill
## formula and the ceiling clamp both read the NATURAL ground, so a synthetic
## field swapped into the heightfield must be swapped in here too or the two
## disagree about what the ground is. HeightfieldPlan keeps the pair in lockstep
## automatically (set_raw_height_override / set_relief_plan both forward), so no
## caller has to remember.
func set_natural_height_override(fn: Callable) -> void:
	_natural_override = fn
	_site_cache.clear()


## Metres of ground to ADD at tile cell (cx, cz). Always >= 0.
##
## HOT PATH: called for every cell of every region window. Sites are one per
## 32x32 cells and a stamp covers ~40 of them, so the overwhelming majority of
## calls exit on the super-cell lookup or the bounding-box reject before any
## noise is evaluated.
func relief_at_cell(cx: int, cz: int) -> float:
	if _budget <= 0.0:
		return 0.0
	var site: Dictionary = _site_context(Vector2i(cx, cz))
	if site.is_empty():
		return 0.0
	var peak: Vector2 = site["peak"]
	var dx := float(cx) - peak.x
	var dz := float(cz) - peak.y
	if absf(dx) > _outer_cells or absf(dz) > _outer_cells:
		return 0.0
	var profile := _profile(dx, dz, site)
	if profile <= 0.0:
		return 0.0
	var natural := natural_height_at_cell(cx, cz)
	# Only a natural RISE above the site's own ground cancels the profile. A
	# natural dip must not be allowed to add to it, or the fill would exceed the
	# budget in the hollows -- the budget is a promise about added elevation.
	var rise := maxf(0.0, natural - float(site["floor"]))
	var relief := clampf(profile - rise, 0.0, _budget)
	if relief <= 0.0:
		return 0.0
	var headroom := maxf(0.0, _ceiling - natural)
	if relief > headroom:
		ceiling_clamped = true
		ceiling_deficit_metres = maxf(ceiling_deficit_metres,
			relief - headroom)
		relief = headroom
	return relief


## The pre-stamp continuous height at a cell, in metres. Same expression
## HeightfieldPlan uses for its own raw field, so "natural ground" means the
## same thing on both sides of the seam.
func natural_height_at_cell(cx: int, cz: int) -> float:
	if _natural_override.is_valid():
		return float(_natural_override.call(cx, cz))
	return HeightfieldPlan.height01(Vector3(float(cx) * HeightfieldPlan.TILE,
		0.0, float(cz) * HeightfieldPlan.TILE), _world_seed, true) * _amplitude


## Metres of profile above the site's own ground at a cell, before the natural
## rise cancels any of it and before the ceiling clamp. The fill's target
## SHAPE, exposed so a test can assert the terraces are flat without
## re-deriving them.
func profile_at_cell(cx: int, cz: int) -> float:
	var site := _site_context(Vector2i(cx, cz))
	if site.is_empty():
		return 0.0
	var peak: Vector2 = site["peak"]
	return _profile(float(cx) - peak.x, float(cz) - peak.y, site)


func _profile(dx: float, dz: float, site: Dictionary) -> float:
	## TERRACED BELL, in metres above the site's own ground.
	##
	## A flat crown at the full budget, then one FLAT RING per storey of budget,
	## then a smooth foot easing the last ring down to nothing.
	##
	## The rings are the point, and they were measured rather than assumed. Wave
	## 1 proved that an at-grade street is contour-bound -- every action's first
	## stride cell sits on the move's starting band -- so
	## WarrenExcavationCarver.MIN_GRADE_CELLS is unsatisfiable the moment the
	## ground under the town slopes continuously. On a synthetic flat field the
	## 4 m storey quantizer terraces ANY profile, smooth or stepped, so the
	## difference is invisible; on the real noisy field it is decisive. A/B with
	## a smooth bell of the same budget, measured over real seeds: the largest
	## constant-band run under the footprint fell 767 -> 308 columns (seed 7) and
	## 861 -> 535 (seed 3), seed 3's bore stopped sealing entirely ("grade street
	## too compact" x18), and seed 2 gained three cliff tops inside the town that
	## the terraced profile does not produce. Being piecewise constant is what
	## keeps the fill surface exactly flat where it dominates, instead of letting
	## the natural residual wander across a cone.
	##
	## Monotone non-increasing in the warped radius by construction, and
	## continuous at the last ring / foot seam, so the hill never steps back up
	## on the way out and never drops more than one storey between rings.
	var r := sqrt(dx * dx + dz * dz)
	var warped := r
	if r > 0.0:
		warped = r * (1.0 + float(site["warp"]) \
			* sin(WARP_LOBES * atan2(dz, dx) + float(site["phase"])))
		warped = maxf(warped, 0.0)
	if warped <= CROWN_RADIUS_CELLS:
		return _budget
	var steps := terrace_steps(_budget)
	var ring := int(floor((warped - CROWN_RADIUS_CELLS) / RING_WIDTH_CELLS)) + 1
	if ring < steps:
		return _budget - float(ring) * HeightfieldPlan.STOREY_HEIGHT
	var foot_inner := CROWN_RADIUS_CELLS \
		+ float(steps - 1) * RING_WIDTH_CELLS
	var foot_height := _budget - float(steps - 1) * HeightfieldPlan.STOREY_HEIGHT
	var t := (warped - foot_inner) / FOOT_WIDTH_CELLS
	if t >= 1.0:
		return 0.0
	return foot_height * (1.0 - SlopeProfile.smootherstep(clampf(t, 0.0, 1.0)))


func _site_context(cell: Vector2i) -> Dictionary:
	## One lookup, because a stamp can never leave its own super cell -- see
	## outer_radius_cells for the proof and the test that pins it.
	var super_cell := SettlementPlan.super_of(cell)
	var cached: Variant = _site_cache.get(super_cell)
	if cached != null:
		return cached
	if _site_cache.size() >= _CACHE_CAP:
		_site_cache.clear()
	var context: Dictionary = {}
	var site: Dictionary = _settlements.site_for(super_cell)
	if site.has("cell"):
		var site_cell: Vector2i = site["cell"]
		context = {
			"cell": site_cell,
			"peak": Vector2(site_cell) + Vector2(
				_unit(_SALT_PEAK_X, site_cell) * PEAK_OFFSET_CELLS,
				_unit(_SALT_PEAK_Z, site_cell) * PEAK_OFFSET_CELLS),
			"phase": _roll(_SALT_PHASE, site_cell) * TAU,
			"warp": WARP_STRENGTH_MIN \
				+ _roll(_SALT_WARP, site_cell) * WARP_STRENGTH_SPAN,
			"floor": natural_height_at_cell(site_cell.x, site_cell.y),
		}
	_site_cache[super_cell] = context
	return context


func _roll(salt: int, cell: Vector2i) -> float:
	var value := Helper._mix64(_world_seed ^ SEED_VERSION ^ salt)
	value = Helper._mix64(value ^ Helper._mix64(cell.x))
	value = Helper._mix64(value ^ Helper._mix64(cell.y))
	return float(value & 0x7FFFFFFF) / float(0x80000000)


func _unit(salt: int, cell: Vector2i) -> float:
	return _roll(salt, cell) * 2.0 - 1.0
