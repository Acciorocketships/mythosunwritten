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
const MIN_ROUTE_CELLS := 22
const MAX_ROUTE_CELLS := 26
const MIN_SPAN_BANDS := 8
const MIN_COVERED_RATIO := 0.55
const MAX_COVERED_RATIO := 0.70
const MIN_PORTALS := 1
const MAX_PORTALS := 2
## A street that runs straight for five cells stops reading as a warren
## canyon and starts reading as an avenue with a sightline down it.
const MAX_STRAIGHT_RUN := 4
## Every attempt is one complete cheap lattice bore. The corpus is wide
## because the acceptance band is narrow in two directions at once (covered
## ratio has a ceiling as well as a floor), so most attempts land outside it
## and are discarded rather than nudged.
const ATTEMPTS := 192
## Radius the inward ambition aims at. Not 0: the last two or three cells of
## the massif's peak are a plateau of at most MAX_PLATEAU_CELLS columns, and
## a route that reaches dead centre has nowhere left to be flanked.
const INNER_RADIUS_CELLS := 3.0
## The cover feedback aims at the middle of the acceptance band rather than
## either edge, so an attempt that drifts still has room on both sides.
const TARGET_COVERED_RATIO := 0.62
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
const RISES: Array[int] = [1, 0, -1]

const WEIGHT_RADIUS := 120.0
const WEIGHT_DEPTH := 210.0
const WEIGHT_FLANK := 140.0
## A flank is any mass standing beside the floor band, which a one-band kerb
## at a terrace lip satisfies. A WALL is mass reaching the full height of the
## street slot -- the thing that actually makes a canyon read as a canyon
## rather than as a belvedere. Steered for separately and harder, because
## every gate in the brief is satisfied by kerbs alone.
const WEIGHT_WALL := 190.0
const PENALTY_UNWALLED := 420.0
const PENALTY_UNFLANKED := 900.0
const PENALTY_REVERSE := 700.0
const PENALTY_STRAIGHT := 110.0
const PENALTY_STRAIGHT_CAP := 900.0
const BONUS_TURN := 60.0
const BONUS_RISE := 90.0
const PENALTY_EXTRA_PORTAL := 600.0
const PENALTY_SAME_DATUM_FOLD := 400.0
## Cover rhythm: desired depth is DEPTH_MID + DEPTH_SWING * sin(...), floored
## at 0. The floor is the whole point -- the fraction of the cycle the sine
## spends below it is the fraction of the route that surfaces, so the pair
## sets the open/roofed mix directly instead of hoping the terrain supplies
## one.
const DEPTH_MID := 1.1
const DEPTH_SWING := 2.6
## How hard the running covered ratio pulls the desired depth back toward
## TARGET_COVERED_RATIO, in bands per unit of ratio error.
const BALANCE_PULL := 5.0
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
	var current := portal
	var direction := Vector2i.ZERO
	var straight_run := 0
	var roofed := 0
	_carve_cell(excavation, current)
	roofed += int(_depth_of(massif, current) > 0)
	for step in range(1, target):
		var selected := _best_move(world_seed, attempt, step, target, style,
			current, direction, straight_run, roofed, massif, excavation)
		if selected.is_empty():
			break
		var destination := selected["destination"] as Vector3i
		var move_direction := selected["direction"] as Vector2i
		if destination.y != current.y:
			excavation.transitions.append({
				"from": current,
				"to": destination,
				"kind": WarrenVolumeTransition.Kind.STAIR,
			})
		straight_run = straight_run + 1 if move_direction == direction else 1
		direction = move_direction
		current = destination
		_carve_cell(excavation, current)
		roofed += int(_depth_of(massif, current) > 0)
	_finalize(excavation, massif)
	if excavation.route.size() < MIN_ROUTE_CELLS \
			or excavation.route.size() > MAX_ROUTE_CELLS:
		_reject(rejected, "route length")
		return null
	if excavation.route_span_bands() < MIN_SPAN_BANDS:
		_reject(rejected, "span")
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
	for cell: Vector3i in excavation.route:
		# Flanking was steered for at every step against the mass standing at
		# the time; only the finished excavation knows what a later step took
		# back out from beside an earlier cell. Re-checked here so the gate is
		# enforced against the final solid, not against a snapshot of it.
		if _flank_count(massif, excavation, cell) < 1:
			_reject(rejected, "unflanked cell")
			return null
	if not excavation.seal():
		_reject(rejected, excavation.last_rejection)
		return null
	return excavation


static func _carve_cell(excavation: WarrenExcavation, cell: Vector3i) -> void:
	excavation.route.append(cell)
	for band in range(cell.y, cell.y + HEADROOM_BANDS):
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
		var roof := Vector3i(cell.x, cell.y + HEADROOM_BANDS, cell.z)
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
		if exposed:
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
		"radius_rush": 0.9 + float(posmod(_hash(world_seed, attempt, 11, 0),
			8)) * 0.1,
		"portal_radius": Vector2(float(portal.x), float(portal.z)).length(),
	}


static func _best_move(world_seed: int, attempt: int, step: int, target: int,
		style: Dictionary, current: Vector3i, current_direction: Vector2i,
		straight_run: int, roofed: int, massif: WarrenMassif,
		excavation: WarrenExcavation) -> Dictionary:
	## Single-pass minimum rather than a sort: sort_custom is not stable, and
	## a stable winner is a determinism requirement, not a nicety.
	var best: Dictionary = {}
	var best_score := INF
	for direction_index in DIRECTIONS.size():
		var direction := DIRECTIONS[direction_index]
		for rise_index in RISES.size():
			var destination := current + Vector3i(direction.x,
				RISES[rise_index], direction.y)
			if not _slot_is_borable(massif, excavation, destination):
				continue
			var score := _move_score(world_seed, attempt, step, target, style,
				current, destination, direction, current_direction,
				straight_run, roofed, massif, excavation,
				direction_index * RISES.size() + rise_index)
			if score < best_score:
				best_score = score
				best = {"destination": destination, "direction": direction}
	return best


static func _slot_is_borable(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i) -> bool:
	## The whole headroom slot must lie inside the solid. Allowing the top of
	## the slot to poke out through the massif's skin would let the route
	## "excavate" cells that were already sky and walk the roofs instead of
	## the streets.
	var column := Vector2i(cell.x, cell.z)
	if not massif.has_column(column):
		return false
	if cell.y < massif.base_at(column):
		return false
	if cell.y + HEADROOM_BANDS > massif.top_at(column):
		return false
	# One solid band has to survive between two passes of the route through
	# the same column, otherwise the "tunnel crossing" is really one
	# six-band shaft with a street somewhere in the middle of it.
	for band in range(cell.y - 1, cell.y + HEADROOM_BANDS + 1):
		if excavation.carved.has(Vector3i(cell.x, band, cell.z)):
			return false
	return true


static func _move_score(world_seed: int, attempt: int, step: int, target: int,
		style: Dictionary, current: Vector3i, destination: Vector3i,
		direction: Vector2i, current_direction: Vector2i, straight_run: int,
		roofed: int, massif: WarrenMassif, excavation: WarrenExcavation,
		move_index: int) -> float:
	var progress := float(step) / float(maxi(1, target - 1))
	var portal_radius: float = style["portal_radius"]
	var radius_rush: float = style["radius_rush"]
	var phase: float = style["phase"]
	var cycles: float = style["cycles"]

	var radius := Vector2(float(destination.x), float(destination.z)).length()
	var target_radius := lerpf(portal_radius, INNER_RADIUS_CELLS,
		minf(1.0, progress * radius_rush))
	var score := absf(radius - target_radius) * WEIGHT_RADIUS

	var achieved := float(roofed) / float(maxi(1, step))
	var balance := clampf(achieved - TARGET_COVERED_RATIO, -1.0, 1.0)
	var desired_depth := maxi(0, roundi(DEPTH_MID
		+ DEPTH_SWING * sin(progress * TAU * cycles + phase)
		- balance * BALANCE_PULL))
	score += absf(float(_depth_of(massif, destination) - desired_depth)) \
		* WEIGHT_DEPTH

	var flanks := _flank_count(massif, excavation, destination)
	score -= float(flanks) * WEIGHT_FLANK
	if flanks < 1:
		score += PENALTY_UNFLANKED
	var walls := _wall_count(massif, excavation, destination)
	score -= float(walls) * WEIGHT_WALL
	if walls < 1:
		score += PENALTY_UNWALLED

	if current_direction != Vector2i.ZERO:
		if direction == -current_direction:
			score += PENALTY_REVERSE
		elif direction == current_direction:
			score += float(maxi(0, straight_run - 1)) * PENALTY_STRAIGHT
			if straight_run >= MAX_STRAIGHT_RUN:
				score += PENALTY_STRAIGHT_CAP
		else:
			score -= BONUS_TURN
	score -= float(destination.y - current.y) * BONUS_RISE

	# A second mouth is allowed but never sought: only the last stretch of the
	# walk may pay its way back out to daylight.
	if _opens_to_exterior(massif, destination) and progress < 0.85:
		score += PENALTY_EXTRA_PORTAL
	# A cell that lands 4-adjacent to an earlier cell at the same floor band
	# widens the street into a plaza when the two lanes are materialised. An
	# over/under crossing is the point of a warren; a fold is not.
	for prior: Vector3i in excavation.route:
		if prior.y == destination.y \
				and absi(prior.x - destination.x) \
					+ absi(prior.z - destination.z) == 1 \
				and prior != current:
			score += PENALTY_SAME_DATUM_FOLD
			break

	var tie := posmod(_hash(world_seed, attempt, step * 31 + move_index,
		destination.y * 131 + destination.x * 17 + destination.z), 997)
	return score + float(tie) * 0.05


static func _depth_of(massif: WarrenMassif, cell: Vector3i) -> int:
	## Bands of mass left above the headroom slot at this cell's own column.
	return massif.top_at(Vector2i(cell.x, cell.z)) - cell.y - HEADROOM_BANDS


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
	return -float(excavation.route_span_bands()) * 90.0 \
		- float(walled) / float(excavation.route.size()) * 500.0 \
		- float(excavation.transitions.size()) * 12.0 \
		+ absf(excavation.covered_ratio() - TARGET_COVERED_RATIO) \
			* COVER_CENTRING_WEIGHT \
		+ float(straightest) * 40.0


static func _hash(world_seed: int, attempt: int, a: int, b: int) -> int:
	var value := world_seed * 73856093 ^ attempt * 50331653 \
		^ a * 83492791 ^ b * 19349663
	return posmod(value, 2147483647)
