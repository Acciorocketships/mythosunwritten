class_name WarrenExcavationCarver
extends RefCounted

## Bores a climbing, mostly covered route through a WarrenMassif. Moves are
## scored, not random: inward-and-upward ambition, a cover rhythm, a
## preference for staying enclosed by full-height mass, and straight-run and
## plaza penalties. Bounded attempts; the best sealed survivor wins.
##
## The street is negative space, so the only lever the carver has is WHERE it
## removes a headroom slot -- it can never add mass to roof a cell over. Cover
## is therefore steered geometrically, through DEPTH: a walk cell whose floor
## sits `depth` bands below (top - HEADROOM_BANDS) is roofed by exactly that
## many bands. Depth 0 is an open canyon between taller neighbours, depth >= 1
## is a tunnel. Because the massif's top rises about 1.2 bands per cell of
## inward travel, moving inward while rising one band gains depth slowly,
## moving sideways while rising sheds it, and that asymmetry is what lets one
## route both climb 8+ bands and retain occasional daylight while accepting the
## much higher cover naturally produced by a true inward, addressable throat.
const HEADROOM_BANDS := WarrenExcavation.HEADROOM_BANDS
## Route length. The 22-26 family was inherited from the route-first carver,
## which never had to spend cells at grade. A mass-first route now walks a
## ground street before it climbs, and a band costs two cells on a stair, so
## MIN_GRADE_CELLS + 2 * MIN_SPAN_BANDS is already 24 before a single turn.
## Widened to 30-36, which the 17-20 band massif has the vertical room for
## and the search reaches without thinning supply (measured: acceptance is
## unchanged either side of the change).
const MIN_ROUTE_CELLS := 30
const MAX_ROUTE_CELLS := 36
## The deep inhabited envelope restores a four-storey journey between lower
## and upper public realms. Requiring the entire eighteen-band depth would leave
## no headroom at the summit, so the route owns eight bands and the remaining
## upper mass stays available for rooms, bridges, and the third-storey court.
const MIN_SPAN_BANDS := 8
## Walk cells sitting exactly on their own column's base band. The excavated
## route is the itinerary WarrenGroundArcadeSolver roots its two ground market
## branches from, and _find_path only ever considers a root where
## `root.y == envelope.ground_at(column)` -- which the adapter maps to the
## massif's base band. A route that touches grade only at its portal offers
## exactly one root, so no second branch can exist and the arcade stage fails
## by construction rather than by luck.
##
## 9 is a measured optimum, not a minimum: over 38 buildable massifs the
## grade-cell/spread pair (9, 7) clears the real arcade solver on 18 seeds,
## against 18 at (9, 8), 15 at (8, 7) and 12 at (11, 9). Demanding a longer
## ground street spends route budget the climb needs and costs more seeds
## than the extra root separation wins back.
const MIN_GRADE_CELLS := 9
## Manhattan spread required between the two furthest-apart grade cells.
## MIN_BRANCH_SEPARATION_CELLS is 4, but the arcade solver measures that
## separation against every cell of the ALREADY CARVED first branch, not
## against its root -- and that branch is 7-8 cells long and free to wander
## toward the second root. A spread of 4 is therefore necessary and nowhere
## near sufficient; 9 is what actually leaves a viable separated root once
## the first branch has spent itself, measured end to end against the real
## solver rather than reasoned about.
const MIN_GRADE_SPREAD_CELLS := 7
## The ground throat is the player's first and most hostile read of the town.
## Head-height massif walls are insufficient: a shallow edge can satisfy the
## canyon gate and then disappear when the partitioner asks for a complete
## inhabited address. Count the same transition endpoints the macro adapter
## publishes and require a material share to retain full ADDRESS_BANDS mass on
## an opposing pair of sides. The boundary portal itself makes 1.0 impossible;
## later 3D frontage and sightline gates remain stricter whole-town proofs.
const MIN_COVERED_RATIO := 0.55
## The former 0.70 ceiling forced the terrain-level throat to orbit the shallow
## massif skirt: the first route with four complete opposing addresses measured
## 0.886 because entering inhabitable depth necessarily leaves mass overhead.
## This is desirable for the requested tunnel-heavy warren. The downstream
## spatial compiler still has to realize that cover as occupied construction;
## raw unclassified mass never counts toward its stricter 0.38 production gate.
const MAX_COVERED_RATIO := 0.90
const MIN_PORTALS := 1
const MAX_PORTALS := 2
## Fraction of walk cells that must have mass standing to full street height
## on BOTH sides. "Streets bounded by tall mass on both sides" is design
## intent for this whole feature, and every other gate here is satisfied by
## one-band kerbs at a terrace lip, so it needs a gate of its own or it is
## merely an aspiration a test happened to sample.
##
## Priced against a measured trade curve over 196 buildable massifs, not
## picked: floor 0.60 costs nothing (195/196 carve), 0.65 costs 2 seeds, 0.70
## costs 12, 0.75 costs 26.
##
## 0.70 is a deliberate purchase of ~6% of seed supply, ruled by the
## coordinator: enclosure is the one note this project's review has repeated
## across five rounds, and every earlier attempt under-delivered on it while
## protecting a budget that turned out not to be the binding constraint. The
## downstream pipeline has historically rejected about half of all seeds
## anyway, so 6% here buys a guaranteed floor under every accepted town.
##
## Stopped short of 0.75 because its 14% cost also thins the candidates left
## per seed, and Tasks 3-6 stack further constraints on that slack -- seed 65
## already survives on 1 candidate of 256.
##
## Revisitable from Task 8, which renders real towns and measures end-to-end
## acceptance, with both exits named: if the downstream stages starve, lower
## it on that evidence; if the towns still do not read as canyons, raise it.
## Either way it is this one constant.
const MIN_WALL_RATIO := 0.70
## A street that runs straight for five cells stops reading as a warren
## canyon and starts reading as an avenue with a sightline down it.
const MAX_STRAIGHT_RUN := 4
## Every attempt is one complete cheap lattice bore. The corpus is wide
## because the acceptance band is narrow in two directions at once (covered
## ratio has a ceiling as well as a floor), so most attempts land outside it
## and are discarded rather than nudged.
const ATTEMPTS := 256
## Radius the inward ambition aims at. Not 0: the last two or three cells of
## the massif's peak are a plateau of at most MAX_PLATEAU_CELLS columns, and
## a route that reaches dead centre has nowhere left to be flanked.
const INNER_RADIUS_CELLS := 5.0
## The soft cover feedback remains biased toward intermittent daylight. The
## stronger inward/address objective can legitimately override it and produce
## a tunnel-heavy survivor up to MAX_COVERED_RATIO.
const TARGET_COVERED_RATIO := 0.62
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
## The move vocabulary IS the WarrenVolumeTransition contract, not a lattice
## convenience that an adapter is expected to reconcile later: a band change
## advances two cells (stair) or three (ramp), never one. A one-cell rise
## seals as no Kind at all, and expanding it downstream would mean inventing
## a route cell this carver never removed -- the carved void and the plan
## would then disagree about where the stair physically is. Every cell the
## stride passes through is carved and joins the route, so a transition's
## swept volume is void that was actually taken out.
const ACTIONS: Array[Dictionary] = [
	{"kind": WarrenVolumeTransition.Kind.LEVEL, "rise": 0, "run": 1},
	{"kind": WarrenVolumeTransition.Kind.STAIR, "rise": 1, "run": 2},
	{"kind": WarrenVolumeTransition.Kind.STAIR, "rise": -1, "run": 2},
	{"kind": WarrenVolumeTransition.Kind.RAMP, "rise": 1, "run": 3},
	{"kind": WarrenVolumeTransition.Kind.RAMP, "rise": -1, "run": 3},
]

const WEIGHT_RADIUS := 85.0
const WEIGHT_DEPTH := 210.0
const WEIGHT_FLANK := 140.0
## A flank is any mass standing beside the floor band, which a one-band kerb
## at a terrace lip satisfies. A WALL is mass reaching the full height of the
## street slot -- the thing that actually makes a canyon read as a canyon
## rather than as a belvedere. Steered for separately and harder, because
## every gate in the brief is satisfied by kerbs alone.
const WEIGHT_WALL := 240.0
const PENALTY_UNWALLED := 420.0
const PENALTY_UNFLANKED := 900.0
const PENALTY_REVERSE := 700.0
const PENALTY_STRAIGHT := 110.0
const PENALTY_STRAIGHT_CAP := 900.0
const BONUS_TURN := 60.0
const BONUS_RISE := 260.0
## Charged per cell a stride consumes. Route length is the scarce resource
## once a band costs two cells: without this a three-cell ramp and a two-cell
## stair reaching the same band score alike, and the corpus spends its 22-26
## cells before the span gate is met.
const COST_PER_STRIDE_CELL := 55.0
## Pull that makes the ground street travel outward from the mouth rather
## than circle near it. Only active while the grade run is being laid.
const WEIGHT_GRADE_TRAVEL := 55.0
const WEIGHT_GRADE_INWARD := 420.0
const BONUS_GRADE_TWO_SIDED_ADDRESS := 1150.0
const PENALTY_GRADE_SINGLE_ADDRESS := 420.0
const PENALTY_GRADE_UNADDRESSED := 1100.0
## Reward for the climbing route passing over a cell it already walked at
## least a full street height below -- the over/under crossing the ground
## arcade stage counts as MIN_UPPER_ROUTE_CROSSOVERS.
const BONUS_CROSSOVER := 120.0
const PENALTY_EXTRA_PORTAL := 600.0
const PENALTY_SAME_DATUM_FOLD := 400.0
## Cover rhythm: desired depth is DEPTH_MID + DEPTH_SWING * sin(...), floored
## at 0. The floor is the whole point -- the fraction of the cycle the sine
## spends below it is the fraction of the route that surfaces, so the pair
## sets the open/roofed mix directly instead of hoping the terrain supplies
## one.
##
## DEPTH_MID fell 1.1 -> 0.8 -> 0.0 and BALANCE_PULL rose 5.0 -> 8.0 purely
## empirically, as the route lengthened and then gained a ground street: a
## grade cell run inward under the mass is roofed by whatever the terrace
## happens to be, which the carver cannot choose, so the climbing half has to
## surface much harder to keep the whole route inside the covered band. At the
## earlier values "too buried" was the largest rejection bucket at every
## length family tried. There is no principled derivation behind either
## number -- they are the settings that maximised survivors, and they should
## be re-measured rather than reasoned about if the route shape changes
## again.
const DEPTH_MID := 0.0
const DEPTH_SWING := 2.6
## How hard the running covered ratio pulls the desired depth back toward
## TARGET_COVERED_RATIO, in bands per unit of ratio error.
const BALANCE_PULL := 8.0
## How hard survivor selection pulls the finished ratio to the middle of the
## acceptance band, against the span and both-sides-walled terms it competes
## with. At 700 the span term simply outbid it and every seed settled within
## 0.005 of the 0.70 ceiling -- legal, but one massif tweak away from having
## no survivor at all.
const COVER_CENTRING_WEIGHT := 2200.0

## --- Secondary lanes ---------------------------------------------------------
## One route cannot seed a village. Every house needs a public address --
## WarrenBuildingParcel.seal() rejects outright any address the volume plan does
## not hold frontage for -- and one bore plus its two arcade branches offers
## about 45 of them across a ~565 column massif. That, not the partitioner, is
## what caps a mass-first town at 23-26 houses and leaves the hill reading as a
## mesa with a hamlet on one edge.
##
## Lanes are the street web that lifts the ceiling: one cell wide, hugging the
## terrace contours, cutting through a riser where the mass allows, and
## downstream just ordinary walk cells that the existing address, frontage,
## arcade, door and partition machinery sees with no special-casing.
##
## They are bored into the WINNING route, after every route gate has already
## selected it, so route acceptance is byte-identical to the pre-lane carver:
## the same itineraries clear the length, span, grade, cover, portal and wall
## gates in the same order. What a lane may then do to the chosen itinerary is
## bounded by _route_gates_survive(), which re-measures flanking, enclosure and
## cover on the finished solid and rolls the lane back whole if any of them
## moved.
const MAX_LANES := 16
## A two-cell stub is a doorway, not a lane; nine cells is about as far as a
## contour runs before the terrace it follows has been spent.
const MIN_LANE_CELLS := 3
const MAX_LANE_CELLS := 9
## Total lane cells one town may carry.
##
## Priced against a measured trade curve, not chosen. This constant was 24 while
## WarrenVolumePlan bounded inside corners by an ABSOLUTE 36: lane corners and
## arcade corners competed for one fixed allowance, the arcade ran last and
## lost, and clearance over the committed window collapsed .75 -> .58 -> .42 as
## the budget went 24 -> 28 -> 32.
##
## With that allowance re-derived as a density (see
## WarrenVolumePlan.INTERIOR_CELLS_PER_TEN_WALK_CELLS), the competition is gone
## and the curve changes shape entirely -- arcade clearance over seeds 16-31
## against the 0.55 floor tests/test_warren_excavation.gd pins, and mean houses
## over the frontier seeds 6, 7, 8, 11:
##
##   lane cells  0     24    40    64    96
##   arcade      .73   .67   .67   .67   .67
##   mean houses 29.8  61.2  --    73.8  79.2
##
## 64 is where the budget stops being what limits the network: three of four
## seeds plateau below it on lane legality alone, and 96 only lets one seed run
## on to 124 houses. Clearance is flat across the whole range, so nothing is
## being traded for this.
const MAX_LANE_CELLS_TOTAL := 64
## Manhattan separation demanded between two lanes' anchors, so the network
## spreads over the hill instead of fraying one stretch of the route.
##
## Three while the corner allowance was absolute, because anchors were not the
## binding constraint then. At 2 the web reaches four to twelve lanes per town
## instead of one to five -- measured 61.2 mean houses against 55.8 -- and it is
## anchors, not the cell budget, that let a lane hang off an earlier lane's tip
## and walk the network out across the hill.
const MIN_LANE_ANCHOR_SEPARATION := 2
## A lane must earn the mass it removes: the cheapest legal house is one storey
## plus WarrenBuildingParcel's roof reservation, and a lane cell that fronts no
## column able to carry even that has addressed nothing.
const MIN_LANE_HOUSE_BANDS := WarrenBuildingParcel.STOREY_BANDS \
	+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
## A lane runs no straighter than this before it must turn. Lower than the
## route's MAX_STRAIGHT_RUN because a lane has no climb to justify a long
## sightline, and a medieval hill town's back lanes bend constantly.
const MAX_LANE_STRAIGHT_RUN := 3
## Columns around the route's ground street that lanes must leave alone,
## measured in 4-connected column distance.
##
## Derived from WarrenGroundArcadeSolver, not chosen: its second market branch
## may only root on a grade route cell at least MIN_BRANCH_SEPARATION_CELLS
## columns from every AUXILIARY walk cell (:134-144), and it measures that
## distance in columns alone, ignoring height. A lane is auxiliary walk realm,
## so a lane anywhere near the ground street -- even eight bands above it --
## disqualifies every root the arcade had, and the seed loses its whole
## frontier. Measured: with lanes free to run at grade, seeds 6, 7 and 8 all
## reported "no separated secondary ground arcade" on every bore.
##
## The ground street's own branches are the arcade's job. Lanes are the terrace
## network above it, which is also where the addresses the town is short of
## actually are: the rim is 2-4 bands tall and can carry no house at all.
const LANE_ARCADE_RESERVE_CELLS := WarrenGroundArcadeSolver \
	.MIN_BRANCH_SEPARATION_CELLS
const LANE_WEIGHT_ADDRESS := 320.0
const LANE_WEIGHT_TRAVEL := 110.0
## Charged per band of level change. Lanes follow the contours by preference and
## climb only where a riser leaves them nowhere else to go, which is what makes
## them read as terrace lanes rather than as more stairs.
const LANE_PENALTY_RISE := 150.0
const LANE_PENALTY_STRAIGHT := 190.0
const LANE_BONUS_COVER := 90.0
## Charged per neighbouring public cell within one band. Two lanes running side
## by side are a plaza with a wall down the middle, and the exact-resolution
## surface audits count them as one slab.
const LANE_PENALTY_CROWD := 260.0
const LANE_COST_PER_STRIDE_CELL := 45.0

static var last_failure := ""
static var last_diagnostic: Dictionary = {}
## Lane-reserve experiment knobs (tests/harness/warren_density_probe.gd).
## Defaults reproduce the class constants exactly; production never sets them.
static var lane_reserve_radius := LANE_ARCADE_RESERVE_CELLS
static var lane_reserve_clearance_bands := 1 << 30


static func carve(world_seed: int, massif: WarrenMassif,
		scale_profile: WarrenVillageScaleProfile = null) -> WarrenExcavation:
	var ranked := carve_ranked(world_seed, massif, scale_profile, 1)
	return ranked[0] if not ranked.is_empty() else null


## The bounded bore search, returning up to `limit` laned and sealed
## survivors ordered best-first by _candidate_score (ties broken by bore
## index, so the order is deterministic). carve() is exactly the head of this
## list. Callers that must satisfy a gate this carver does not know about (the
## public-realm topology gate applied by the mass-first frontier) can walk the
## ranking instead of discarding a whole attempt because its single best
## survivor missed a count by one; profiling showed all 12 x 256 bores of a
## compact seed thrown away that way while gate-passing survivors sat at
## ranks 1-5.
static func carve_ranked(world_seed: int, massif: WarrenMassif,
		scale_profile: WarrenVillageScaleProfile, limit: int) \
		-> Array[WarrenExcavation]:
	var out: Array[WarrenExcavation] = []
	last_failure = "no attempt sealed"
	last_diagnostic = {
		"best_grade_two_sided_address_ratio": 0.0,
		"best_grade_two_sided_address_count": 0,
		"best_grade_endpoint_count": 0,
	}
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return out
	var constraints := _scale_constraints(scale_profile)
	var portals := _portal_cells(massif)
	if portals.is_empty():
		last_failure = "no boundary column can host a portal"
		return out
	var survivors: Array[Dictionary] = []
	var rejected: Dictionary = {}
	for attempt in ATTEMPTS:
		var candidate := _bore(world_seed, attempt, massif, portals, rejected,
			constraints)
		if candidate == null:
			continue
		survivors.append({"score": _candidate_score(candidate, massif),
			"attempt": attempt, "candidate": candidate})
	if survivors.is_empty():
		last_failure = "no attempt sealed (%s; best two-sided grade %d/%d=%.3f)" % [
			_tally(rejected),
			int(last_diagnostic.best_grade_two_sided_address_count),
			int(last_diagnostic.best_grade_endpoint_count),
			float(last_diagnostic.best_grade_two_sided_address_ratio)]
		return out
	survivors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.score) != float(b.score):
			return float(a.score) < float(b.score)
		return int(a.attempt) < int(b.attempt))
	last_failure = ""
	# Lanes are carved into survivors, never into candidates: every gate above
	# has already chosen these routes against the unlaned solid, so the ranking
	# is exactly the one the pre-lane carver made. Each is re-sealed with its
	# lanes so nothing downstream can receive a network seal() has not
	# validated; one that fails re-seal is dropped and the next takes its rank.
	for index in mini(limit, survivors.size()):
		var excavation := survivors[index].candidate as WarrenExcavation
		_carve_lanes(world_seed, excavation, massif,
			int(constraints.lane_budget), int(constraints.lane_cell_budget))
		if not excavation.seal():
			if out.is_empty():
				last_failure = "lane network rejected: %s" \
					% excavation.last_rejection
			continue
		out.append(excavation)
	if not out.is_empty():
		last_failure = ""
	return out


static func _reject(rejected: Dictionary, reason: String) -> void:
	## Which gate ate the corpus is the only useful thing to say when a
	## bounded search finds nothing; "no attempt sealed" alone sends the next
	## reader back to re-instrumenting the same loop by hand.
	rejected[reason] = int(rejected.get(reason, 0)) + 1


static func _tally(rejected: Dictionary) -> String:
	var reasons: Array = rejected.keys()
	reasons.sort()
	var parts: Array[String] = []
	for reason: String in reasons:
		parts.append("%s x%d" % [reason, int(rejected[reason])])
	return ", ".join(parts)


static func _bore(world_seed: int, attempt: int, massif: WarrenMassif,
		portals: Array[Vector3i], rejected: Dictionary,
		constraints: Dictionary = {}) -> WarrenExcavation:
	if constraints.is_empty():
		constraints = _scale_constraints(null)
	var portal := portals[posmod(_hash(world_seed, attempt, 1, 0),
		portals.size())]
	var excavation := WarrenExcavation.new(world_seed)
	var route_min := int(constraints.route_min)
	var route_max := int(constraints.route_max)
	var target := route_min + posmod(_hash(world_seed, attempt, 3, 0),
		route_max - route_min + 1)
	var style := _style(world_seed, attempt, portal)
	var route_set: Dictionary = {}
	var current := portal
	var direction := Vector2i.ZERO
	var straight_run := 0
	var roofed := 0
	_carve_cell(excavation, route_set, current, HEADROOM_BANDS)
	roofed += int(_depth_of(massif, current, HEADROOM_BANDS) > 0)
	var move_index := 0
	while excavation.route.size() < target:
		var selected := _best_move(world_seed, attempt, move_index, target,
			style, current, direction, straight_run, roofed, massif,
			excavation, route_set, target - excavation.route.size(), constraints)
		if selected.is_empty():
			break
		var stride: Array = selected["cells"]
		var move_direction := selected["direction"] as Vector2i
		var rise := int(selected["rise"])
		var run := int(selected["run"])
		var endpoint := stride[stride.size() - 1] as Vector3i
		excavation.transitions.append({
			"from": current,
			"to": endpoint,
			"kind": int(selected["kind"]),
		})
		for offset in range(1, run + 1):
			var cell := stride[offset - 1] as Vector3i
			var bands := _stride_slot_bands(rise, run, offset)
			_carve_cell(excavation, route_set, cell, bands)
			roofed += int(_depth_of(massif, cell, bands) > 0)
		straight_run = straight_run + stride.size() \
			if move_direction == direction else stride.size()
		direction = move_direction
		current = endpoint
		move_index += 1
	_finalize(excavation, massif)
	if excavation.route.size() < route_min \
			or excavation.route.size() > route_max:
		_reject(rejected, "route length")
		return null
	if excavation.route_span_bands() < int(constraints.span_min):
		_reject(rejected, "span")
		return null
	var grade := _grade_cells(massif, excavation)
	if grade.size() < int(constraints.grade_min):
		_reject(rejected, "too little at grade")
		return null
	if _grade_spread(grade) < int(constraints.grade_spread_min):
		_reject(rejected, "grade street too compact")
		return null
	var grade_endpoints := _grade_route_address_records(massif, excavation)
	var two_sided_grade_endpoints := 0
	for endpoint: Dictionary in grade_endpoints:
		two_sided_grade_endpoints += int(bool(endpoint.two_sided))
	var two_sided_grade_ratio := float(two_sided_grade_endpoints) \
		/ float(maxi(1, grade_endpoints.size()))
	if two_sided_grade_ratio > float(last_diagnostic.get(
			"best_grade_two_sided_address_ratio", 0.0)):
		var endpoint_diagnostic: Array[Dictionary] = []
		for endpoint: Dictionary in grade_endpoints:
			var cell := endpoint.cell as Vector3i
			endpoint_diagnostic.append({
				"cell": cell,
				"two_sided": bool(endpoint.two_sided),
				"required_directions": endpoint.required_directions,
				"complete_sides": _complete_address_side_count(massif,
					excavation, cell),
			})
		last_diagnostic = {
			"best_grade_two_sided_address_ratio": two_sided_grade_ratio,
			"best_grade_two_sided_address_count": two_sided_grade_endpoints,
			"best_grade_endpoint_count": grade_endpoints.size(),
			"best_grade_endpoints": endpoint_diagnostic,
			"best_grade_covered_ratio": excavation.covered_ratio(),
		}
	if grade_endpoints.is_empty() or float(two_sided_grade_endpoints) \
			/ float(grade_endpoints.size()) \
			< WarrenPublicRealmCarver.MIN_GROUND_PRIMARY_TWO_SIDED_ADDRESS_RATIO:
		_reject(rejected, "one-sided grade street")
		return null
	if excavation.covered_ratio() < MIN_COVERED_RATIO:
		_reject(rejected, "too open")
		return null
	if excavation.covered_ratio() > MAX_COVERED_RATIO:
		_reject(rejected, "too buried")
		return null
	if excavation.portals.size() < MIN_PORTALS \
			or excavation.portals.size() > MAX_PORTALS:
		_reject(rejected, "portals")
		return null
	var walled := 0
	for cell: Vector3i in excavation.route:
		# Flanking and enclosure were steered for at every step against the
		# mass standing at the time; only the finished excavation knows what a
		# later step took back out from beside an earlier cell. Re-measured
		# here so both gates are enforced against the final solid, not against
		# a snapshot of it.
		if _flank_count(massif, excavation, cell) < 1:
			_reject(rejected, "unflanked cell")
			return null
		walled += int(_wall_count(massif, excavation, cell) >= 2)
	if float(walled) / float(excavation.route.size()) < MIN_WALL_RATIO:
		_reject(rejected, "open-sided")
		return null
	# A two-band wall can enclose a player's head while still being too shallow
	# to become an inhabited facade.  Select only bores whose remaining mass can
	# carry a complete six-band address along the same share required by the
	# common WarrenVolumePlan gate.  This was always re-measured for lane
	# preservation below, but omitting it here let `carve()` choose an
	# unbuildable winner and discard other legal bores in its 256-candidate set.
	var addressed := _route_endpoint_addressed_count(massif, excavation)
	var endpoint_count := excavation.transitions.size() + 1
	if float(addressed) / float(endpoint_count) \
			< WarrenPublicRealmCarver.MIN_ADDRESSED_WALK_RATIO:
		_reject(rejected, "shallow frontage")
		return null
	if not excavation.seal():
		# Bucketed, not keyed on last_rejection: that string carries cell
		# coordinates, so using it as a key would grow one tally entry per
		# failing attempt instead of summarising them.
		_reject(rejected, "unsealed walk")
		return null
	return excavation


static func _carve_lanes(world_seed: int, excavation: WarrenExcavation,
		massif: WarrenMassif, lane_budget: int = MAX_LANES,
		lane_cell_budget: int = MAX_LANE_CELLS_TOTAL) -> void:
	## Grows the lane network onto a chosen route. Purely additive: a lane that
	## cannot be grown, cannot be grown far enough, or costs the route one of its
	## own gates is rolled back whole, so the worst case is the route this
	## function was handed.
	##
	## Anchors are re-enumerated after every lane, so a lane may hang off an
	## earlier lane's tip as well as off the route. That is what makes this a WEB
	## rather than a comb: the route occupies one winding corridor, and lanes
	## hanging only off it can never reach the far terraces. Branching off a
	## lane's own far end -- which the anchor separation rule pushes them toward
	## -- walks the network outward across the hill.
	var reserve := _arcade_reserve(massif, excavation)
	var addressed := _route_addressed_count(massif, excavation)
	var used: Array[Vector3i] = []
	var tried: Dictionary = {}
	var total := 0
	while excavation.lanes.size() < lane_budget \
			and total < lane_cell_budget:
		var next := _next_lane_anchor(world_seed, excavation, used, tried)
		if next.is_empty():
			break
		var cell := next[0]
		tried[cell] = true
		var lane := _grow_lane(world_seed, excavation, massif, cell, reserve,
			lane_cell_budget - total)
		if lane.is_empty():
			continue
		excavation.lanes.append(lane)
		if not _lane_survives(excavation, massif, addressed):
			_roll_back_lane(excavation)
			continue
		# Rollback bookkeeping, not part of the sealed lane record.
		lane.erase("carved")
		used.append(cell)
		total += (lane["cells"] as Array[Vector3i]).size()


static func _next_lane_anchor(world_seed: int, excavation: WarrenExcavation,
		used: Array[Vector3i], tried: Dictionary) -> Array[Vector3i]:
	## The next untried anchor far enough from every lane already grown, or an
	## empty array. Returned as a list rather than a nullable cell so the caller
	## stays statically typed.
	for anchor: Vector3i in _lane_anchors(world_seed, excavation):
		if tried.has(anchor) or _too_near(anchor, used):
			continue
		return [anchor] as Array[Vector3i]
	return [] as Array[Vector3i]


static func _arcade_reserve(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Dictionary:
	## Columns within the reserve radius of any grade route cell, which are the
	## columns the ground arcade needs free of auxiliary walk realm, mapped to
	## the highest grade band that reserved them so a lane can be judged by how
	## far above the ground street it runs.
	var out: Dictionary = {}
	var radius := lane_reserve_radius
	for cell: Vector3i in excavation.route:
		if not _is_at_grade(massif, cell):
			continue
		for x in range(cell.x - radius + 1, cell.x + radius):
			for z in range(cell.z - radius + 1, cell.z + radius):
				if absi(x - cell.x) + absi(z - cell.z) < radius:
					var column := Vector2i(x, z)
					out[column] = maxi(int(out.get(column, -(1 << 30))), cell.y)
	return out


static func _reserved_for_lane(reserve: Dictionary, cell: Vector3i) -> bool:
	## A reserved column blocks a lane cell unless the lane runs at least the
	## clearance above the ground street that reserved it.
	var column := Vector2i(cell.x, cell.z)
	if not reserve.has(column):
		return false
	return cell.y - int(reserve[column]) < lane_reserve_clearance_bands


static func _route_addressed_count(massif: WarrenMassif,
		excavation: WarrenExcavation) -> int:
	## Route cells with a complete WarrenMassif.ADDRESS_BANDS frontage on at
	## least one side, restated against the massif and the carved
	## void -- which for a mass-first plan IS `mass_cells`, since
	## WarrenExcavationVolumeAdapter builds the envelope from the massif and
	## seal() then subtracts exactly this excavation.
	##
	## The topology gate demands 0.55 of the route be addressed this way. Lanes
	## remove mass beside the route, so without pinning this a lane could carve
	## away the very frontage the route was admitted for. Pinned as an exact
	## count rather than against the 0.55 floor: the route was chosen with this
	## many addressed cells and a lane is not entitled to spend the margin.
	var out := 0
	for cell: Vector3i in excavation.route:
		out += int(_cell_has_complete_address(massif, excavation, cell))
	return out


static func _route_endpoint_addressed_count(massif: WarrenMassif,
		excavation: WarrenExcavation) -> int:
	## WarrenExcavationVolumeAdapter publishes the bore's first cell plus one
	## logical walk node per move endpoint.  Stair/ramp intermediate columns are
	## physical treads and frontage, but never graph nodes, so counting them in
	## the topology ratio lets shallow landings hide behind deep treads.
	var out := int(_cell_has_complete_address(massif, excavation,
		excavation.route[0]))
	for transition: Dictionary in excavation.transitions:
		out += int(_cell_has_complete_address(massif, excavation,
			transition.to as Vector3i))
	return out


static func _cell_has_complete_address(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i) -> bool:
	for direction: Vector2i in DIRECTIONS:
		if _direction_has_complete_address(massif, excavation, cell, direction):
			return true
	return false


static func _direction_has_complete_address(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i,
		direction: Vector2i) -> bool:
	var column := Vector2i(cell.x + direction.x, cell.z + direction.y)
	for band in range(cell.y, cell.y + WarrenMassif.ADDRESS_BANDS):
		if not massif.has_column(column) or band < massif.base_at(column) \
				or band >= massif.top_at(column) \
				or excavation.carved.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _complete_address_side_count(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i) -> int:
	var out := 0
	for direction: Vector2i in DIRECTIONS:
		out += int(_direction_has_complete_address(massif, excavation, cell,
			direction))
	return out


static func _grade_route_address_records(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Dictionary]:
	## Match WarrenExcavationVolumeAdapter's logical primary itinerary: the bore
	## entrance plus each transition endpoint. Intermediate stair/ramp cells are
	## physical treads, not independent public nodes. Required facade directions
	## are route-relative: opposite on a straight, adjacent around a bend, and
	## perpendicular at an endpoint. This proves that a winding street has walls
	## on both of its actual sides instead of rejecting every chicane for lacking
	## one world-axis pair.
	var nodes: Array[Vector3i] = [excavation.route[0]]
	for transition: Dictionary in excavation.transitions:
		nodes.append(transition.to as Vector3i)
	var out: Array[Dictionary] = []
	for index in nodes.size():
		var cell := nodes[index]
		if not _is_at_grade(massif, cell):
			continue
		var required := _route_side_directions(nodes, index)
		var two_sided := required.size() == 2
		for direction: Vector2i in required:
			two_sided = two_sided and _direction_has_complete_address(
				massif, excavation, cell, direction)
		out.append({"cell": cell, "required_directions": required,
			"two_sided": two_sided})
	return out


static func _route_side_directions(nodes: Array[Vector3i], index: int) \
		-> Array[Vector2i]:
	var open_directions: Dictionary = {}
	for neighbor_index: int in [index - 1, index + 1]:
		if neighbor_index < 0 or neighbor_index >= nodes.size():
			continue
		var delta := nodes[neighbor_index] - nodes[index]
		var direction := Vector2i(signi(delta.x), signi(delta.z))
		if direction != Vector2i.ZERO:
			open_directions[direction] = true
	if open_directions.size() == 1:
		var tangent := open_directions.keys()[0] as Vector2i
		return [Vector2i(-tangent.y, tangent.x),
			Vector2i(tangent.y, -tangent.x)] as Array[Vector2i]
	var out: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		if not open_directions.has(direction):
			out.append(direction)
	return out if out.size() == 2 else [] as Array[Vector2i]


static func _lane_anchors(world_seed: int,
		excavation: WarrenExcavation) -> Array[Vector3i]:
	## Every cell a lane may hang off, in a deterministic hash order.
	##
	## Only transition ENDPOINTS qualify. WarrenExcavationVolumeAdapter makes a
	## stride's intermediate cell frontage rather than a walk node, because the
	## vertical transition already owns that ground's public surface; hanging a
	## lane off one would need a second transition into a cell the plan has no
	## graph node for.
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	for cell: Vector3i in _walk_nodes(excavation):
		if seen.has(cell):
			continue
		seen[cell] = true
		out.append(cell)
	out.sort_custom(func(left: Vector3i, right: Vector3i) -> bool:
		var left_key := _hash(world_seed, 8191, left.x * 131 + left.z,
			left.y)
		var right_key := _hash(world_seed, 8191, right.x * 131 + right.z,
			right.y)
		if left_key != right_key:
			return left_key < right_key
		if left.y != right.y:
			return left.y < right.y
		if left.x != right.x:
			return left.x < right.x
		return left.z < right.z)
	return out


static func _walk_nodes(excavation: WarrenExcavation) -> Array[Vector3i]:
	var out: Array[Vector3i] = [excavation.route[0]]
	for spec: Dictionary in excavation.transitions:
		out.append(spec["to"] as Vector3i)
	for lane: Dictionary in excavation.lanes:
		for spec: Dictionary in lane["transitions"] as Array[Dictionary]:
			out.append(spec["to"] as Vector3i)
	return out


static func _too_near(anchor: Vector3i, used: Array[Vector3i]) -> bool:
	for other: Vector3i in used:
		if absi(anchor.x - other.x) + absi(anchor.z - other.z) \
				< MIN_LANE_ANCHOR_SEPARATION:
			return true
	return false


static func _grow_lane(world_seed: int, excavation: WarrenExcavation,
		massif: WarrenMassif, anchor: Vector3i, reserve: Dictionary,
		budget: int) -> Dictionary:
	## One lane, grown greedily from `anchor` and committed to `carved` as it
	## goes so each move sees the solid the last one left. Returns {} and undoes
	## its own carving unless it reached MIN_LANE_CELLS.
	var target := mini(budget, MIN_LANE_CELLS + posmod(_hash(world_seed, 2749,
		anchor.x * 131 + anchor.z, anchor.y),
		MAX_LANE_CELLS - MIN_LANE_CELLS + 1))
	if target < MIN_LANE_CELLS:
		return {}
	var public_set := _public_set(excavation)
	var cells: Array[Vector3i] = []
	var transitions: Array[Dictionary] = []
	var carved: Array[Vector3i] = []
	var current := anchor
	var direction := Vector2i.ZERO
	var straight := 0
	var move_index := 0
	while cells.size() < target:
		var selected := _best_lane_move(world_seed, excavation, massif, anchor,
			current, direction, straight, public_set, reserve,
			target - cells.size(), move_index)
		if selected.is_empty():
			break
		var stride := selected["cells"] as Array[Vector3i]
		var rise := int(selected["rise"])
		var run := int(selected["run"])
		transitions.append({"from": current, "to": stride[run - 1],
			"kind": int(selected["kind"])})
		for offset in range(1, run + 1):
			var cell := stride[offset - 1]
			var bands := _stride_slot_bands(rise, run, offset)
			cells.append(cell)
			public_set[cell] = true
			for band in range(cell.y, cell.y + bands):
				var air := Vector3i(cell.x, band, cell.z)
				excavation.carved[air] = true
				carved.append(air)
		var moved := selected["direction"] as Vector2i
		straight = straight + run if moved == direction else run
		direction = moved
		current = stride[run - 1]
		move_index += 1
	if cells.size() < MIN_LANE_CELLS:
		for air: Vector3i in carved:
			excavation.carved.erase(air)
		return {}
	return {"anchor": anchor, "cells": cells, "transitions": transitions,
		"carved": carved}


static func _public_set(excavation: WarrenExcavation) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in excavation.public_cells():
		out[cell] = true
	return out


static func _best_lane_move(world_seed: int, excavation: WarrenExcavation,
		massif: WarrenMassif, anchor: Vector3i, current: Vector3i,
		current_direction: Vector2i, straight_run: int, public_set: Dictionary,
		reserve: Dictionary, budget: int, move_index: int) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	for direction_index in DIRECTIONS.size():
		var direction := DIRECTIONS[direction_index]
		for action_index in ACTIONS.size():
			var action := ACTIONS[action_index]
			var run := int(action["run"])
			if run > budget:
				continue
			if direction == -current_direction \
					and current_direction != Vector2i.ZERO:
				continue
			if direction == current_direction \
					and straight_run + run > MAX_LANE_STRAIGHT_RUN:
				continue
			var stride := _lane_stride_cells(massif, excavation, public_set,
				reserve, current, direction, int(action["rise"]), run)
			if stride.is_empty():
				continue
			var score := _lane_move_score(world_seed, excavation, massif, anchor,
				stride, int(action["rise"]), run, direction, current_direction,
				straight_run, public_set,
				move_index * 37 + direction_index * ACTIONS.size() + action_index)
			if score < best_score:
				best_score = score
				best = {"cells": stride, "direction": direction,
					"kind": int(action["kind"]), "rise": int(action["rise"]),
					"run": run}
	return best


static func _lane_stride_cells(massif: WarrenMassif,
		excavation: WarrenExcavation, public_set: Dictionary,
		reserve: Dictionary, current: Vector3i, direction: Vector2i, rise: int,
		run: int) -> Array[Vector3i]:
	## A lane's stride, on exactly the route's slot legality -- the same
	## _slot_is_borable and the same surface-band arithmetic, so every cell a
	## transition will later claim is void that was actually removed from inside
	## the solid.
	##
	## Two rules are the lane's own. It may not run beside existing public realm
	## at its own band (that is one wide surface, not two streets), and every
	## cell must front a column that can carry a house, which is what a lane is
	## excavated for.
	var out: Array[Vector3i] = []
	var occupied := public_set.duplicate()
	var previous := current
	for offset in range(1, run + 1):
		var span := _surface_band_span(rise, run, offset)
		var cell := Vector3i(current.x + direction.x * offset,
			current.y + span.x, current.z + direction.y * offset)
		if not _slot_is_borable(massif, excavation, cell,
				span.y - span.x + HEADROOM_BANDS):
			return [] as Array[Vector3i]
		if _reserved_for_lane(reserve, cell) \
				or _completes_public_square(occupied, cell) \
				or _folds_onto_route(occupied, previous, cell) \
				or _addressable_sides(massif, excavation, cell) < 1:
			return [] as Array[Vector3i]
		occupied[cell] = true
		out.append(cell)
		previous = cell
	return out


static func _addressable_sides(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i) -> int:
	## Neighbouring columns that could carry a WELL-PROPORTIONED house addressed
	## from this cell. Mirrors WarrenSolidPartitioner._can_carry_house's
	## question against the raw solid: ground at or below the street, and nothing
	## carved from that ground up through the house it would have to hold.
	##
	## Bounded above as well as below, which is a lane's rule and not the
	## route's. A street cut more than WarrenMassif.BUILDABLE_LAYER_BANDS below
	## a column's top has no plinth for the house to descend to, so that house
	## is simply as tall as the solid over it -- the multi-storey slab this whole
	## round of review rejected. Lanes choose where they are cut, so they may
	## simply decline to address a face they would turn into a tower; the bore
	## has a climb to complete and cannot.
	var out := 0
	for direction: Vector2i in DIRECTIONS:
		var column := Vector2i(cell.x + direction.x, cell.z + direction.y)
		if not massif.has_column(column) or massif.base_at(column) > cell.y \
				or massif.top_at(column) < cell.y + MIN_LANE_HOUSE_BANDS \
				or massif.top_at(column) \
					> cell.y + WarrenMassif.BUILDABLE_LAYER_BANDS:
			continue
		var clear := true
		for band in range(massif.base_at(column),
				cell.y + MIN_LANE_HOUSE_BANDS):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				clear = false
				break
		out += int(clear)
	return out


static func _lane_move_score(world_seed: int, excavation: WarrenExcavation,
		massif: WarrenMassif, anchor: Vector3i, stride: Array[Vector3i],
		rise: int, run: int, direction: Vector2i, current_direction: Vector2i,
		straight_run: int, public_set: Dictionary, salt: int) -> float:
	## What a lane wants, in order: addresses, distance from the street it left,
	## the contour it is already on, and a roof over it now and then. Nothing
	## here asks for enclosure on both sides -- a terrace lane open on its
	## downhill side is correct hill-town form and gets a parapet from the
	## surface stages, not a building.
	var endpoint := stride[run - 1]
	var addresses := 0
	var covered := 0
	var crowding := 0
	for cell: Vector3i in stride:
		addresses += _addressable_sides(massif, excavation, cell)
		covered += int(_depth_of(massif, cell, HEADROOM_BANDS) > 0)
		for direction_offset: Vector2i in DIRECTIONS:
			for band_offset in [-1, 0, 1]:
				var neighbour := Vector3i(cell.x + direction_offset.x,
					cell.y + band_offset, cell.z + direction_offset.y)
				crowding += int(public_set.has(neighbour))
	var travelled := absi(endpoint.x - anchor.x) + absi(endpoint.z - anchor.z)
	var score := float(run) * LANE_COST_PER_STRIDE_CELL \
		- float(addresses) / float(run) * LANE_WEIGHT_ADDRESS \
		- float(travelled) * LANE_WEIGHT_TRAVEL \
		- float(covered) / float(run) * LANE_BONUS_COVER \
		+ float(crowding) * LANE_PENALTY_CROWD \
		+ float(absi(rise)) * LANE_PENALTY_RISE
	if direction == current_direction:
		score += float(straight_run + run) * LANE_PENALTY_STRAIGHT
	var tie := posmod(_hash(world_seed, 6151, salt,
		endpoint.y * 131 + endpoint.x * 17 + endpoint.z), 997)
	return score + float(tie) * 0.05


static func _lane_survives(excavation: WarrenExcavation,
		massif: WarrenMassif, addressed: int) -> bool:
	## Every gate the ROUTE answered to, re-measured on the solid the lanes left,
	## plus the lane network's own address rule re-measured over all of it.
	##
	## The route gates ran before any lane existed, so without this a lane could
	## take an earlier cell's canyon wall and the excavation would still claim
	## the enclosure ratio it was selected for. Cover is included even though the
	## one-solid-band rule in _slot_is_borable makes it invariant by
	## construction: an invariant nothing checks is an argument, not a guarantee.
	var walled := 0
	for cell: Vector3i in excavation.route:
		if _flank_count(massif, excavation, cell) < 1:
			return false
		walled += int(_wall_count(massif, excavation, cell) >= 2)
		var roof := Vector3i(cell.x, cell.y + excavation.slot_bands(cell), cell.z)
		if bool(excavation.covered.get(cell, false)) \
				!= (massif.top_at(Vector2i(cell.x, cell.z)) > roof.y \
					and not excavation.carved.has(roof)):
			return false
	if float(walled) / float(excavation.route.size()) < MIN_WALL_RATIO:
		return false
	if _route_addressed_count(massif, excavation) < addressed:
		return false
	for cell: Vector3i in excavation.lane_cells():
		if _addressable_sides(massif, excavation, cell) < 1:
			return false
	return true


static func _roll_back_lane(excavation: WarrenExcavation) -> void:
	var lane: Dictionary = excavation.lanes.pop_back()
	for air: Vector3i in lane["carved"] as Array[Vector3i]:
		excavation.carved.erase(air)


static func _carve_cell(excavation: WarrenExcavation, route_set: Dictionary,
		cell: Vector3i, bands: int) -> void:
	excavation.route.append(cell)
	route_set[cell] = true
	for band in range(cell.y, cell.y + bands):
		excavation.carved[Vector3i(cell.x, band, cell.z)] = true


static func _finalize(excavation: WarrenExcavation,
		massif: WarrenMassif) -> void:
	## Cover and portals are resolved once, against the finished solid, so
	## both are measurements of what the excavation left rather than claims
	## made while it was still changing. The roof-band check is what makes
	## `covered` independent of the one-solid-band separation rule in
	## _slot_is_borable: that rule currently keeps two passes of the route far
	## enough apart that the upper one can never take the lower one's roof,
	## but nothing here relies on it still doing so.
	excavation.covered.clear()
	excavation.portals.clear()
	for cell: Vector3i in excavation.route:
		var column := Vector2i(cell.x, cell.z)
		var roof := Vector3i(cell.x, cell.y + excavation.slot_bands(cell),
			cell.z)
		excavation.covered[cell] = massif.top_at(column) > roof.y \
			and not excavation.carved.has(roof)
		if _opens_to_exterior(massif, cell):
			excavation.portals.append(cell)


static func _opens_to_exterior(massif: WarrenMassif, cell: Vector3i) -> bool:
	## A portal is a mouth in the massif's outer wall, not merely a low
	## frontage: it needs a 4-neighbour that is outside the footprint
	## entirely, so daylight reaches the slot from the side.
	for direction: Vector2i in DIRECTIONS:
		if not massif.has_column(Vector2i(cell.x + direction.x,
				cell.z + direction.y)):
			return true
	return false


static func _portal_cells(massif: WarrenMassif) -> Array[Vector3i]:
	## Boundary columns tall enough to host a full-height doorway at their
	## own ground band. Sorted by coordinate so the attempt corpus indexes a
	## stable list regardless of Dictionary key order.
	var out: Array[Vector3i] = []
	for column_value: Variant in massif.columns.keys():
		var column := column_value as Vector2i
		var base := massif.base_at(column)
		if massif.top_at(column) < base + HEADROOM_BANDS:
			continue
		var exposed := false
		for direction: Vector2i in DIRECTIONS:
			if not massif.has_column(column + direction):
				exposed = true
				break
		if not exposed:
			continue
		# A mouth in a thin rim pocket dead-ends the ground street on its
		# first or second move: every grade neighbour is too short to hold a
		# slot, and the attempt is spent. Require the mouth to open onto at
		# least two columns that can themselves host a grade cell, which is
		# the cheapest available proxy for "there is a street's worth of
		# ground mass through here".
		#
		# Tall enough is necessary but not sufficient once the ground under the
		# massif has relief of its own. EVERY action's first stride cell sits on
		# the move's STARTING band (_surface_band_span returns a zero low for
		# offset 1 of a stair and a ramp alike), so a 4-neighbour whose own
		# ground stands at a different band can never be entered at grade: it is
		# either above the bored slot or below its own base. Counting it here
		# hands the bore a mouth whose ground street dies on move one. Same-band
		# is a no-op on flat input, where every base is equal.
		var grade_neighbours := 0
		for direction: Vector2i in DIRECTIONS:
			var neighbour := column + direction
			if massif.has_column(neighbour) \
					and massif.base_at(neighbour) == base \
					and massif.top_at(neighbour) - massif.base_at(neighbour) \
						>= HEADROOM_BANDS:
				grade_neighbours += 1
		if grade_neighbours < 2:
			continue
		out.append(Vector3i(column.x, base, column.y))
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	return out


static func _style(world_seed: int, attempt: int,
		portal: Vector3i) -> Dictionary:
	## Per-attempt shape of the two ambitions. Varying the cover rhythm's
	## phase and period, and how eagerly the route drives inward, is what
	## makes a corpus of 192 bores explore instead of re-deriving one route
	## with different tie-breaks.
	return {
		"phase": float(posmod(_hash(world_seed, attempt, 5, 0), 1000)) \
			/ 1000.0 * TAU,
		"cycles": 1.0 + float(posmod(_hash(world_seed, attempt, 7, 0), 5)) \
			* 0.5,
		"radius_rush": 0.45 + float(posmod(_hash(world_seed, attempt, 11, 0),
			8)) * 0.07,
		"portal_radius": Vector2(float(portal.x), float(portal.z)).length(),
		"portal_x": portal.x,
		"portal_z": portal.z,
	}


static func _best_move(world_seed: int, attempt: int, move_index: int,
		target: int, style: Dictionary, current: Vector3i,
		current_direction: Vector2i, straight_run: int, roofed: int,
		massif: WarrenMassif, excavation: WarrenExcavation,
		route_set: Dictionary, budget: int, constraints: Dictionary) -> Dictionary:
	## Single-pass minimum rather than a sort: sort_custom is not stable, and
	## a stable winner is a determinism requirement, not a nicety.
	var best: Dictionary = {}
	var best_score := INF
	for direction_index in DIRECTIONS.size():
		var direction := DIRECTIONS[direction_index]
		for action_index in ACTIONS.size():
			var action := ACTIONS[action_index]
			var run := int(action["run"])
			if run > budget:
				continue
			var stride := _stride_cells(massif, excavation, route_set, current,
				direction, int(action["rise"]), run)
			if stride.is_empty():
				continue
			# The ground street comes first and is not negotiable: until the
			# route has laid down MIN_GRADE_CELLS cells on the base band, the
			# only legal moves are ones that stay there. Steering for it with
			# a score term instead left the grade run at the mercy of the
			# inward and climbing terms, which is how the route ended up
			# touching grade exactly twice.
			if excavation.route.size() < int(constraints.grade_min) \
					and not _stride_is_at_grade(massif, stride):
				continue
			var score := _move_score(world_seed, attempt, move_index, target,
				style, current, stride, int(action["rise"]), direction,
				current_direction, straight_run, roofed, massif, excavation,
				route_set, direction_index * ACTIONS.size() + action_index,
				constraints)
			if score < best_score:
				best_score = score
				best = {
					"cells": stride,
					"direction": direction,
					"kind": int(action["kind"]),
					"rise": int(action["rise"]),
					"run": run,
				}
	return best


static func _is_at_grade(massif: WarrenMassif, cell: Vector3i) -> bool:
	## Exactly on the column's base band -- the only cells
	## WarrenGroundArcadeSolver._find_path will accept as a branch root, since
	## it compares against envelope.ground_at() with no tolerance.
	return cell.y == massif.base_at(Vector2i(cell.x, cell.z))


static func _stride_is_at_grade(massif: WarrenMassif,
		stride: Array[Vector3i]) -> bool:
	for cell: Vector3i in stride:
		if not _is_at_grade(massif, cell):
			return false
	return true


static func _grade_cells(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for cell: Vector3i in excavation.route:
		if _is_at_grade(massif, cell):
			out.append(cell)
	return out


static func _grade_spread(grade: Array[Vector3i]) -> int:
	## Manhattan distance between the two furthest-apart grade cells.
	var widest := 0
	for i in grade.size():
		for j in range(i + 1, grade.size()):
			widest = maxi(widest, absi(grade[i].x - grade[j].x)
				+ absi(grade[i].z - grade[j].z))
	return widest


static func _surface_band_span(rise: int, run: int, offset: int) -> Vector2i:
	## The lowest and highest band, relative to a stride's starting band, on
	## which WarrenVolumeTransition.surface_cells() will place walking surface
	## inside the macro cell `offset` steps along that stride.
	##
	## Read off that method's own micro-lane arithmetic rather than
	## approximated, because the two do not agree at macro resolution unless
	## you follow it exactly. surface_cells() walks 2*run-2 micro steps and
	## rounds `lerp` at each; micro step `along` falls in macro cell
	## `(along + 1) / 2`. For a STAIR (run 2) BOTH micro steps land in the one
	## intermediate cell, at the lower tread and then the upper -- so that
	## cell's void has to span two bands. Interpolating once per macro cell
	## instead put its floor on the upper tread alone and left the lower half
	## of every flight standing in solid mass. A RAMP (run 3) gives each of
	## its two gap cells a single band, which is why only stairs diverged.
	if rise == 0:
		return Vector2i.ZERO
	var gap := run * 2 - 2
	var low := rise
	var high := rise
	var found := false
	for along in range(1, gap + 1):
		if (along + 1) / 2 != offset:
			continue
		var band := roundi(lerpf(0.0, float(rise),
			float(along) / float(gap + 1)))
		low = band if not found else mini(low, band)
		high = band if not found else maxi(high, band)
		found = true
	return Vector2i(low, high)


static func _stride_slot_bands(rise: int, run: int, offset: int) -> int:
	## Height of void one stride cell needs: its own walking surface span plus
	## standing headroom above the highest tread in it.
	var span := _surface_band_span(rise, run, offset)
	return span.y - span.x + HEADROOM_BANDS


static func _completes_public_square(occupied: Dictionary,
		cell: Vector3i) -> bool:
	## Mirrors WarrenVolumePlan._same_datum_public_square_count() exactly:
	## four same-band walk cells in a square expand into one featureless 4x4
	## slab of player-width surface, and the plan rejects that outright.
	## Enforced here as a hard rule rather than left to the same-datum fold
	## PENALTY, which is only a preference -- a long ground street at one
	## datum closes squares readily, and every one of them was a route the
	## adapter then threw away with "public route contains a broad same-datum
	## 2x2 block".
	for x_offset in [-1, 0]:
		for z_offset in [-1, 0]:
			var origin := cell + Vector3i(x_offset, 0, z_offset)
			var complete := true
			for corner: Vector3i in [origin, origin + Vector3i.RIGHT,
					origin + Vector3i.BACK, origin + Vector3i(1, 0, 1)]:
				if corner != cell and not occupied.has(corner):
					complete = false
					break
			if complete:
				return true
	return false


static func _stride_cells(massif: WarrenMassif, excavation: WarrenExcavation,
		route_set: Dictionary, current: Vector3i, direction: Vector2i,
		rise: int, run: int) -> Array[Vector3i]:
	## Every cell a move passes through, each placed on the lowest band
	## surface_cells() will claim inside it and cleared to the height that
	## method's span demands. Returns empty if any cell of the stride cannot
	## be bored -- a partially legal stride is not a legal move.
	var out: Array[Vector3i] = []
	var occupied := route_set.duplicate()
	for offset in range(1, run + 1):
		var span := _surface_band_span(rise, run, offset)
		var cell := Vector3i(current.x + direction.x * offset,
			current.y + span.x, current.z + direction.y * offset)
		if not _slot_is_borable(massif, excavation, cell,
				span.y - span.x + HEADROOM_BANDS):
			return [] as Array[Vector3i]
		if _completes_public_square(occupied, cell):
			return [] as Array[Vector3i]
		occupied[cell] = true
		out.append(cell)
	return out


static func _slot_is_borable(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i, bands: int) -> bool:
	## The whole slot must lie inside the solid. Allowing the top of it to
	## poke out through the massif's skin would let the route "excavate"
	## cells that were already sky and walk the roofs instead of the streets.
	var column := Vector2i(cell.x, cell.z)
	if not massif.has_column(column):
		return false
	if cell.y < massif.base_at(column):
		return false
	if cell.y + bands > massif.top_at(column):
		return false
	# One solid band has to survive between two passes of the route through
	# the same column, otherwise the "tunnel crossing" is really one tall
	# shaft with a street somewhere in the middle of it.
	for band in range(cell.y - 1, cell.y + bands + 1):
		if excavation.carved.has(Vector3i(cell.x, band, cell.z)):
			return false
	return true


static func _move_score(world_seed: int, attempt: int, move_index: int,
		target: int, style: Dictionary, current: Vector3i,
		stride: Array[Vector3i], rise: int, direction: Vector2i,
		current_direction: Vector2i, straight_run: int, roofed: int,
		massif: WarrenMassif, excavation: WarrenExcavation,
		route_set: Dictionary, action_index: int,
		constraints: Dictionary) -> float:
	## Scored per MOVE, not per cell: a stair spends two of the route's cells
	## and a ramp three, so the terms that describe where the street ends up
	## are read at the endpoint while the terms that describe what it is like
	## to walk along it are averaged over the stride. Without that split a
	## three-cell ramp would collect three cells' worth of enclosure reward
	## and outbid a stair that reaches the same band for one cell less.
	var run := stride.size()
	var endpoint := stride[run - 1]
	var travelled := excavation.route.size() + run
	var progress := minf(1.0, float(travelled) / float(maxi(1, target - 1)))
	var portal_radius: float = style["portal_radius"]
	var radius_rush: float = style["radius_rush"]
	var phase: float = style["phase"]
	var cycles: float = style["cycles"]

	var radius := Vector2(float(endpoint.x), float(endpoint.z)).length()
	var target_radius := lerpf(portal_radius, float(constraints.inner_radius),
		minf(1.0, progress * radius_rush))
	var score := absf(radius - target_radius) * WEIGHT_RADIUS
	if excavation.route.size() < int(constraints.grade_min):
		# The grade street must travel far enough to seed two arcade roots, but
		# unqualified Manhattan travel can run back around the Gaussian skirt.
		# Reward mostly radial penetration into inhabitable depth, with a small
		# independent travel term to keep the route from knotting at the mouth.
		var travelled_from_portal := absi(endpoint.x - int(style["portal_x"])) \
			+ absi(endpoint.z - int(style["portal_z"]))
		score -= float(travelled_from_portal) * WEIGHT_GRADE_TRAVEL
		var inward_travel := maxf(0.0, portal_radius - radius)
		score -= inward_travel * WEIGHT_GRADE_INWARD
		var two_sided_addresses := 0
		var single_addresses := 0
		for cell: Vector3i in stride:
			var first_side := Vector2i(-direction.y, direction.x)
			var second_side := -first_side
			var first_complete := _direction_has_complete_address(massif,
				excavation, cell, first_side)
			var second_complete := _direction_has_complete_address(massif,
				excavation, cell, second_side)
			two_sided_addresses += int(first_complete and second_complete)
			single_addresses += int(first_complete != second_complete)
		var unaddressed := run - two_sided_addresses - single_addresses
		score -= float(two_sided_addresses) * BONUS_GRADE_TWO_SIDED_ADDRESS
		score += float(single_addresses) * PENALTY_GRADE_SINGLE_ADDRESS
		score += float(unaddressed) * PENALTY_GRADE_UNADDRESSED

	var achieved := float(roofed) / float(maxi(1, excavation.route.size()))
	var balance := clampf(achieved - TARGET_COVERED_RATIO, -1.0, 1.0)
	var desired_depth := maxi(0, roundi(DEPTH_MID
		+ DEPTH_SWING * sin(progress * TAU * cycles + phase)
		- balance * BALANCE_PULL))
	var depth_error := 0.0
	var flanks := 0
	var walls := 0
	var unflanked := 0
	var unwalled := 0
	var exposed := false
	var folded := false
	for offset in range(1, run + 1):
		var cell := stride[offset - 1]
		depth_error += absf(float(_depth_of(massif, cell,
			_stride_slot_bands(rise, run, offset)) - desired_depth))
		var cell_flanks := _flank_count(massif, excavation, cell)
		var cell_walls := _wall_count(massif, excavation, cell)
		flanks += cell_flanks
		walls += cell_walls
		unflanked += int(cell_flanks < 1)
		unwalled += int(cell_walls < 1)
		exposed = exposed or _opens_to_exterior(massif, cell)
		folded = folded or _folds_onto_route(route_set, current, cell)
	var span := float(run)
	score += depth_error / span * WEIGHT_DEPTH
	score -= float(flanks) / span * WEIGHT_FLANK
	score -= float(walls) / span * WEIGHT_WALL
	score += float(unflanked) * PENALTY_UNFLANKED
	score += float(unwalled) * PENALTY_UNWALLED

	if current_direction != Vector2i.ZERO:
		if direction == -current_direction:
			score += PENALTY_REVERSE
		elif direction == current_direction:
			score += float(maxi(0, straight_run + run - 1)) * PENALTY_STRAIGHT
			if straight_run + run > MAX_STRAIGHT_RUN:
				score += PENALTY_STRAIGHT_CAP
		else:
			score -= BONUS_TURN
	# Climb is now rationed: a band costs two route cells at best, and the
	# span gate wants eight of them out of a 22-26 cell budget. Reward the
	# rise and charge for the cells it took, or the search spends its budget
	# on level cells and lands short.
	score -= float(endpoint.y - current.y) * BONUS_RISE
	score += float(run) * COST_PER_STRIDE_CELL

	# WarrenGroundArcadeSolver needs two of its ground cells to run BENEATH
	# the climbing itinerary (MIN_UPPER_ROUTE_CROSSOVERS), and it carves those
	# cells beside the grade street. A climb that spirals away from the ground
	# street therefore satisfies every gate here and still fails the arcade
	# stage, so the climb is rewarded for passing back over the street it came
	# from once it is high enough to be a roof rather than a neighbour.
	if excavation.route.size() >= int(constraints.grade_min):
		# Checked over the cell AND its four neighbours, because the arcade
		# branches are new cells carved BESIDE the grade street, not the
		# street itself -- passing directly over the route alone leaves the
		# branch cells in the open.
		var crossings := 0
		for cell: Vector3i in stride:
			for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT,
					Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var column := Vector2i(cell.x + offset.x, cell.z + offset.y)
				var ceiling := cell.y - HEADROOM_BANDS
				var found := false
				for band in range(massif.base_at(column), ceiling + 1):
					if route_set.has(Vector3i(column.x, band, column.y)):
						found = true
						break
				crossings += int(found)
		score -= float(mini(crossings, 4)) * BONUS_CROSSOVER
	# A second mouth is allowed but never sought: only the last stretch of the
	# walk may pay its way back out to daylight.
	if exposed and progress < 0.85:
		score += PENALTY_EXTRA_PORTAL
	# A cell that lands 4-adjacent to an earlier cell at the same floor band
	# widens the street into a plaza when the two lanes are materialised. An
	# over/under crossing is the point of a warren; a fold is not.
	if folded:
		score += PENALTY_SAME_DATUM_FOLD

	var tie := posmod(_hash(world_seed, attempt,
		move_index * 31 + action_index,
		endpoint.y * 131 + endpoint.x * 17 + endpoint.z), 997)
	return score + float(tie) * 0.05


static func _folds_onto_route(route_set: Dictionary, current: Vector3i,
		cell: Vector3i) -> bool:
	for direction: Vector2i in DIRECTIONS:
		var neighbour := Vector3i(cell.x + direction.x, cell.y,
			cell.z + direction.y)
		if neighbour != current and route_set.has(neighbour):
			return true
	return false


static func _depth_of(massif: WarrenMassif, cell: Vector3i,
		bands: int) -> int:
	## Bands of mass left above this cell's own slot. A stair's intermediate
	## cell carries two treads, so its slot is a band taller and its roof
	## correspondingly thinner -- passing the height in keeps cover honest
	## rather than assuming every cell is HEADROOM_BANDS tall.
	return massif.top_at(Vector2i(cell.x, cell.z)) - cell.y - bands


static func _flank_count(massif: WarrenMassif, excavation: WarrenExcavation,
		cell: Vector3i) -> int:
	var flanked := 0
	for direction: Vector2i in DIRECTIONS:
		var side := Vector3i(cell.x + direction.x, cell.y,
			cell.z + direction.y)
		var column := Vector2i(side.x, side.z)
		if massif.has_column(column) and massif.top_at(column) > cell.y \
				and not excavation.carved.has(side):
			flanked += 1
	return flanked


static func _wall_count(massif: WarrenMassif, excavation: WarrenExcavation,
		cell: Vector3i) -> int:
	## Sides where mass still stands to the full height of the street slot,
	## so the street is enclosed rather than merely edged.
	var walls := 0
	for direction: Vector2i in DIRECTIONS:
		var column := Vector2i(cell.x + direction.x, cell.z + direction.y)
		if not massif.has_column(column) \
				or massif.top_at(column) < cell.y + HEADROOM_BANDS:
			continue
		var open := false
		for band in range(cell.y, cell.y + HEADROOM_BANDS):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				open = true
				break
		if not open:
			walls += 1
	return walls


static func _candidate_score(excavation: WarrenExcavation,
		massif: WarrenMassif) -> float:
	## Every survivor already satisfies every gate, so this only chooses
	## between legal routes: the deepest climb, walled to full street height
	## on both sides for as much of its length as possible, with the covered
	## ratio nearest the middle of the band rather than clinging to an edge.
	var walled := 0
	var straightest := 0
	var run := 0
	var previous := Vector2i.ZERO
	for index in excavation.route.size():
		walled += int(_wall_count(massif, excavation,
			excavation.route[index]) >= 2)
		if index == 0:
			continue
		var step := excavation.route[index] - excavation.route[index - 1]
		var direction := Vector2i(step.x, step.z)
		run = run + 1 if direction == previous else 1
		previous = direction
		straightest = maxi(straightest, run)
	return -float(excavation.route_span_bands()) * 200.0 \
		- float(walled) / float(excavation.route.size()) * 900.0 \
		- float(excavation.transitions.size()) * 12.0 \
		+ absf(excavation.covered_ratio() - TARGET_COVERED_RATIO) \
			* COVER_CENTRING_WEIGHT \
		+ float(straightest) * 40.0


static func _scale_constraints(
		scale_profile: WarrenVillageScaleProfile) -> Dictionary:
	var profile := scale_profile if scale_profile != null \
		else WarrenVillageScaleProfile.review_fixture()
	var grade_min := clampi(roundi(float(profile.radius_cells) * 0.75), 6, 9)
	return {
		"route_min": profile.route_cell_range.x,
		"route_max": profile.route_cell_range.y,
		"span_min": profile.route_span_range.x,
		"grade_min": grade_min,
		"grade_spread_min": maxi(4, grade_min - 2),
		"inner_radius": maxf(3.0, float(profile.radius_cells) * 0.42),
		"lane_budget": profile.lane_budget,
		"lane_cell_budget": profile.lane_cell_budget,
	}


static func _hash(world_seed: int, attempt: int, a: int, b: int) -> int:
	var value := world_seed * 73856093 ^ attempt * 50331653 \
		^ a * 83492791 ^ b * 19349663
	return posmod(value, 2147483647)
