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
## route both climb 8+ bands and surface often enough to stay inside the
## 0.55-0.70 covered band instead of burying itself the moment it heads in.
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
const MIN_COVERED_RATIO := 0.55
const MAX_COVERED_RATIO := 0.70
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
## The cover feedback aims at the middle of the acceptance band rather than
## either edge, so an attempt that drifts still has room on both sides.
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
const WEIGHT_GRADE_TRAVEL := 240.0
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

static var last_failure := ""


static func carve(world_seed: int, massif: WarrenMassif) -> WarrenExcavation:
	last_failure = "no attempt sealed"
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return null
	var portals := _portal_cells(massif)
	if portals.is_empty():
		last_failure = "no boundary column can host a portal"
		return null
	var best: WarrenExcavation = null
	var best_score := INF
	var rejected: Dictionary = {}
	for attempt in ATTEMPTS:
		var candidate := _bore(world_seed, attempt, massif, portals, rejected)
		if candidate == null:
			continue
		var score := _candidate_score(candidate, massif)
		if best == null or score < best_score:
			best = candidate
			best_score = score
	if best != null:
		last_failure = ""
	else:
		last_failure = "no attempt sealed (%s)" % _tally(rejected)
	return best


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
		portals: Array[Vector3i], rejected: Dictionary) -> WarrenExcavation:
	var portal := portals[posmod(_hash(world_seed, attempt, 1, 0),
		portals.size())]
	var excavation := WarrenExcavation.new(world_seed)
	var target := MIN_ROUTE_CELLS + posmod(_hash(world_seed, attempt, 3, 0),
		MAX_ROUTE_CELLS - MIN_ROUTE_CELLS + 1)
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
			excavation, route_set, target - excavation.route.size())
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
	if excavation.route.size() < MIN_ROUTE_CELLS \
			or excavation.route.size() > MAX_ROUTE_CELLS:
		_reject(rejected, "route length")
		return null
	if excavation.route_span_bands() < MIN_SPAN_BANDS:
		_reject(rejected, "span")
		return null
	var grade := _grade_cells(massif, excavation)
	if grade.size() < MIN_GRADE_CELLS:
		_reject(rejected, "too little at grade")
		return null
	if _grade_spread(grade) < MIN_GRADE_SPREAD_CELLS:
		_reject(rejected, "grade street too compact")
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
	if not excavation.seal():
		# Bucketed, not keyed on last_rejection: that string carries cell
		# coordinates, so using it as a key would grow one tally entry per
		# failing attempt instead of summarising them.
		_reject(rejected, "unsealed walk")
		return null
	return excavation


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
		var grade_neighbours := 0
		for direction: Vector2i in DIRECTIONS:
			var neighbour := column + direction
			if massif.has_column(neighbour) \
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
		route_set: Dictionary, budget: int) -> Dictionary:
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
			if excavation.route.size() < MIN_GRADE_CELLS \
					and not _stride_is_at_grade(massif, stride):
				continue
			var score := _move_score(world_seed, attempt, move_index, target,
				style, current, stride, int(action["rise"]), direction,
				current_direction, straight_run, roofed, massif, excavation,
				route_set, direction_index * ACTIONS.size() + action_index)
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
		route_set: Dictionary, action_index: int) -> float:
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
	var target_radius := lerpf(portal_radius, INNER_RADIUS_CELLS,
		minf(1.0, progress * radius_rush))
	var score := absf(radius - target_radius) * WEIGHT_RADIUS
	if excavation.route.size() < MIN_GRADE_CELLS:
		# While the ground street is being laid the inward term is the wrong
		# ambition: it is satisfied by circling at a constant radius, which
		# is precisely how the grade run ended up a tight compact knot with
		# no two roots far enough apart to hang a second arcade branch on.
		# Reward travel from the mouth instead, so the street actually goes
		# somewhere before it starts to climb.
		var travelled_from_portal := absi(endpoint.x - int(style["portal_x"])) \
			+ absi(endpoint.z - int(style["portal_z"]))
		score -= float(travelled_from_portal) * WEIGHT_GRADE_TRAVEL

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
	if excavation.route.size() >= MIN_GRADE_CELLS:
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


static func _hash(world_seed: int, attempt: int, a: int, b: int) -> int:
	var value := world_seed * 73856093 ^ attempt * 50331653 \
		^ a * 83492791 ^ b * 19349663
	return posmod(value, 2147483647)
