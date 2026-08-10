class_name WarrenPublicRealmCarver
extends RefCounted

## Bounded deterministic search which removes one connected exterior public
## realm from a terrain-relative city mass.  The search works entirely on plain
## lattice data.  It is intentionally ignorant of meshes and authored assets.
const ROUTE_CELL_FAMILIES: Array[int] = [22, 23]
const MIN_ROUTE_CELLS := 22
const MAX_ROUTE_CELLS := 23
# Route length is an orthogonal bounded topology family, not a hash side
# effect. The 22-cell family leaves the most Gaussian mass for roofed frontage;
# the 23-cell family supplies one additional turn when exterior air cannot
# escape through the denser route. Both families receive the same deterministic
# attempt corpus, so adding the fallback cannot perturb or dilute the compact
# layouts. Longer routes were measured and rejected because they opened the
# town faster than they improved circulation. A measured 21-cell experiment was
# also rejected: on the compact Gaussian envelope it could not retain both the
# occupied-link sockets and the varied stepped skyline required by construction.
# Ninety-six cheap lattice attempts per family give the construction-aware
# frontier enough independent turns without expanding its fixed asset budget.
const ATTEMPTS_PER_ROUTE_FAMILY := 96
const COMPACT_ROUTE_ATTEMPTS := ATTEMPTS_PER_ROUTE_FAMILY
# GDScript does not accept Packed/typed Array.size() in a constant expression.
# The invariant is covered by the route-family corpus test so extending the
# vocabulary cannot silently leave this bounded search stale.
const MAX_ATTEMPTS := 192
const MAX_STRAIGHT_RUN := 4
## Shared complete-building-frontage floor.  Mass-first's low-level excavation
## selection must apply this before choosing one bore, and the adapted common
## volume applies it again after every derived public-realm branch.  One named
## authority prevents the upstream and downstream gates from silently drifting.
const MIN_ADDRESSED_WALK_RATIO := 0.55
## Complete route-relative inhabited addresses on both sides of the primary
## terrain-level throat.  A straight node requires its opposing flanks, while a
## right-angle turn requires the two remaining (adjacent) facade directions.
## The mass-first excavation enforces this while choosing its bore; the common
## volume gate repeats it after auxiliary market arcades have removed more mass.
## This is deliberately stronger than head-height wall enclosure: the latter can
## be a shallow massif lip that no complete building may occupy.
const MIN_GROUND_PRIMARY_TWO_SIDED_ADDRESS_RATIO := 0.30
# The entrance is a small piece of topology, not whatever the vertical search
# happens to choose on its first few iterations. Two terrain-level moves make
# an inward-right-angle throat. The first move stays on natural terrain; the
# dogleg may begin the climb by one band. Requiring both destinations to match
# natural ground discarded the motif whenever the warped Gaussian edge stepped
# beneath its second leg, even though the ordinary public-realm contract already
# has complete ramp/stair modules for that exact one-band transition.
const ENTRY_THROAT_MOVE_COUNT := 2
const ENTRY_THROAT_ATTEMPT_OFFSET := ATTEMPTS_PER_ROUTE_FAMILY / 2
# The structural score keeps every survivor within the same hard quality gate,
# then this bounded style term prevents different world seeds from repeatedly
# converging on one globally optimal route shape. It changes which real route
# wins; seed identity is never inserted into a geometry signature.
const STYLE_SELECTION_JITTER := 240.0
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]


static func solve(world_seed: int,
		ground_bands: Dictionary = {}) -> WarrenVolumePlan:
	var envelope := WarrenVolumeEnvelope.build(world_seed, ground_bands)
	if envelope == null:
		return null
	return solve_envelope(world_seed, envelope)


static func solve_envelope(world_seed: int,
		envelope: WarrenVolumeEnvelope) -> WarrenVolumePlan:
	if envelope == null or not envelope.is_sealed():
		return null
	var best: WarrenVolumePlan
	var best_score := INF
	for attempt in MAX_ATTEMPTS:
		var candidate := _grow_candidate(world_seed, attempt, envelope)
		if candidate == null or not _passes_topology_gate(candidate):
			continue
		var score := _plan_score(candidate)
		if best == null or score < best_score:
			best = candidate
			best_score = score
	return best


static func diagnostic_candidate(world_seed: int, attempt: int,
		ground_bands: Dictionary = {}) -> WarrenVolumePlan:
	## Harness-only view of a sealed survivor before the corpus quality gate. The
	## production solve still returns only candidates satisfying every gate.
	var envelope := WarrenVolumeEnvelope.build(world_seed, ground_bands)
	return null if envelope == null else _grow_candidate(world_seed, attempt,
		envelope, true)


static func sealed_candidate(world_seed: int, attempt: int,
		envelope: WarrenVolumeEnvelope) -> WarrenVolumePlan:
	## Construction-coupled planners may compare a bounded set of already-sealed
	## topology survivors. They cannot weaken or bypass the carver's own gate.
	var candidate := _grow_candidate(world_seed, attempt, envelope)
	return candidate if candidate != null and _passes_topology_gate(candidate) \
		else null


static func topology_score(plan: WarrenVolumePlan) -> float:
	return INF if plan == null or not plan.is_sealed() else _plan_score(plan)


static func passes_topology_gate(plan: WarrenVolumePlan) -> bool:
	## Read-only view of the same corpus quality bar sealed_candidate() applies,
	## for topology built outside this carver (the mass-first excavation path).
	## Exposing the one authority is deliberate: a second copy of these
	## thresholds would let the two generation modes drift apart silently. This
	## can only reject a candidate, never admit one, so no existing caller's
	## result can change.
	return plan != null and _passes_topology_gate(plan)


static func _grow_candidate(world_seed: int, attempt: int,
		envelope: WarrenVolumeEnvelope,
		allow_unsealed_diagnostic: bool = false) -> WarrenVolumePlan:
	var entries := envelope.boundary_entry_cells(WarrenVolumePlan.HEADROOM_BANDS)
	if entries.is_empty():
		return null
	var family_index := clampi(attempt / ATTEMPTS_PER_ROUTE_FAMILY, 0,
		ROUTE_CELL_FAMILIES.size() - 1)
	var family_attempt := posmod(attempt, ATTEMPTS_PER_ROUTE_FAMILY)
	var entry_window := mini(entries.size(), 20)
	var entry := entries[posmod(_hash(world_seed, family_attempt, 3, 0, 0),
		entry_window)]
	var target_count: int = ROUTE_CELL_FAMILIES[family_index]
	var route: Array[Vector3i] = [entry]
	var route_set: Dictionary = {entry: true}
	var air_set: Dictionary = {}
	var column_heights: Dictionary = {}
	_add_column_height(column_heights, entry)
	for cell: Vector3i in _walk_air(entry):
		air_set[cell] = true
	var transition_specs: Array[Dictionary] = []
	var landing_set: Dictionary = {}
	var current_direction := Vector2i.ZERO
	var last_was_vertical := false
	var straight_run := 0
	for step_index in range(1, target_count):
		var current: Vector3i = route.back()
		var candidates := _candidate_moves(world_seed, family_attempt, step_index,
			current, current_direction, straight_run, target_count, entry,
			envelope, route, route_set, air_set, column_heights)
		if candidates.is_empty():
			break
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.score) < float(b.score))
		var selected := candidates[0]
		var destination := selected.destination as Vector3i
		var direction := selected.direction as Vector2i
		var kind := int(selected.kind) as WarrenVolumeTransition.Kind
		var vertical: bool = destination.y != current.y
		if current_direction != Vector2i.ZERO \
				and _dot(current_direction, direction) == 0 \
				and (last_was_vertical or vertical):
			landing_set[current] = true
		transition_specs.append({
			"from": current,
			"to": destination,
			"kind": kind,
			"air": selected.air_cells,
		})
		route.append(destination)
		route_set[destination] = true
		_add_column_height(column_heights, destination)
		for air_cell: Vector3i in selected.air_cells as Array:
			air_set[air_cell] = true
		straight_run = straight_run + 1 if direction == current_direction else 1
		current_direction = direction
		last_was_vertical = vertical
	var plan := WarrenVolumePlan.new(
		StringName("warren.volume.%d.%02d" % [world_seed, attempt]),
		world_seed, envelope)
	for cell: Vector3i in route:
		if not plan.add_walk_cell(cell):
			plan.last_rejection = "diagnostic: duplicate walk cell %s" % cell
			return plan if allow_unsealed_diagnostic else null
	for index in transition_specs.size():
		var spec := transition_specs[index]
		var swept: Array[Vector3i] = []
		swept.assign(spec.air as Array)
		var transition := WarrenVolumeTransition.new(
			StringName("volume.transition.%02d" % index),
			spec.from as Vector3i, spec.to as Vector3i,
			int(spec.kind) as WarrenVolumeTransition.Kind, swept)
		if not plan.add_transition(transition):
			plan.last_rejection = "diagnostic: invalid transition %d from %s to %s" % [
				index, spec.from, spec.to]
			return plan if allow_unsealed_diagnostic else null
	for landing_value: Variant in landing_set.keys():
		if not plan.add_landing(landing_value as Vector3i):
			plan.last_rejection = "diagnostic: invalid landing %s" % landing_value
			return plan if allow_unsealed_diagnostic else null
	if plan.seal(entry):
		return plan
	return plan if allow_unsealed_diagnostic else null


static func _candidate_moves(world_seed: int, attempt: int, step_index: int,
		current: Vector3i, current_direction: Vector2i, straight_run: int,
		target_count: int, entry: Vector3i, envelope: WarrenVolumeEnvelope,
		route: Array[Vector3i], route_set: Dictionary, air_set: Dictionary,
		column_heights: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var action_specs: Array[Dictionary] = [
		{"kind": WarrenVolumeTransition.Kind.LEVEL, "rise": 0, "run": 1},
		{"kind": WarrenVolumeTransition.Kind.RAMP, "rise": 1, "run": 3},
		{"kind": WarrenVolumeTransition.Kind.RAMP, "rise": -1, "run": 3},
		{"kind": WarrenVolumeTransition.Kind.STAIR, "rise": 1, "run": 2},
		{"kind": WarrenVolumeTransition.Kind.STAIR, "rise": -1, "run": 2},
	]
	for direction_index in DIRECTIONS.size():
		var direction := DIRECTIONS[direction_index]
		for action_index in action_specs.size():
			var action := action_specs[action_index]
			var run := int(action.run)
			var rise := int(action.rise)
			var destination := current + Vector3i(direction.x * run, rise,
				direction.y * run)
			if route_set.has(destination):
				continue
			if not _entry_throat_move_is_legal(attempt, step_index, entry, current,
					destination, direction, current_direction,
					int(action.kind) as WarrenVolumeTransition.Kind, envelope):
				continue
			var swept := _transition_air(current, destination, run)
			if not _swept_air_is_legal(swept, current, envelope, air_set):
				continue
			var score := _move_score(world_seed, attempt, step_index,
				target_count, entry, current, destination, direction,
				current_direction, straight_run,
				int(action.kind) as WarrenVolumeTransition.Kind,
				envelope, route, column_heights, action_index,
				direction_index)
			out.append({
				"destination": destination,
				"direction": direction,
				"kind": action.kind,
				"air_cells": swept,
				"score": score,
			})
	return out


static func _move_score(world_seed: int, attempt: int, step_index: int,
		target_count: int, entry: Vector3i, current: Vector3i,
		destination: Vector3i, direction: Vector2i,
		current_direction: Vector2i, straight_run: int,
		kind: WarrenVolumeTransition.Kind, envelope: WarrenVolumeEnvelope,
		route: Array[Vector3i], column_heights: Dictionary,
		action_index: int, direction_index: int) -> float:
	var progress := float(step_index) / float(maxi(1, target_count - 1))
	var entry_radius := Vector2(float(entry.x), float(entry.z)).length()
	var phase := float(posmod(_hash(world_seed, attempt, 47, 0, 0),
		1000003)) / 1000003.0 * TAU
	var target_radius := lerpf(entry_radius, 2.0 + sin(progress * TAU * 1.5
		+ phase) * 0.85, minf(1.0, progress * 1.35))
	var radius := Vector2(float(destination.x), float(destination.z)).length()
	var column := Vector2i(destination.x, destination.z)
	var available_relative_height := envelope.top_at(column) \
		- envelope.ground_at(column) - envelope.address_bands
	# Ceiling -3 (was -4) and amplitude 1.6 (was 1.25): review round 5 asked for
	# routes that genuinely snake UP through the mass; the extra band of ambition
	# and deeper undulation buy more climb without touching hard gates.
	var target_relative_y := clampi(roundi(lerpf(0.0,
		float(maxi(2, envelope.max_height_bands - 3)), progress)
		+ sin(progress * TAU * 2.0 + phase) * 1.6),
		0, maxi(0, available_relative_height))
	var relative_y := destination.y - envelope.ground_at(column)
	# Route-shape weights are corpus-calibrated: 100/90 height weight and
	# -705/-680 revisit both cost two corpus seeds ("no exact optional-infill
	# variant"); 82/-650/-180 keeps 6/12 acceptance with the best overpass mix.
	var score := absf(radius - target_radius) * 105.0 \
		+ absf(float(relative_y - target_relative_y)) * 82.0
	var address_side_count := _envelope_address_side_count(destination,
		envelope)
	score -= float(address_side_count) * 170.0
	if address_side_count == 0:
		score += 800.0
	if current_direction != Vector2i.ZERO:
		if direction == current_direction:
			score += float(maxi(0, straight_run - 1)) * 115.0
			if straight_run >= MAX_STRAIGHT_RUN:
				score += 900.0
		elif direction == -current_direction:
			score += 700.0
		else:
			score -= 70.0
	if destination.y != current.y:
		score -= 70.0 if kind == WarrenVolumeTransition.Kind.RAMP else 0.0
	else:
		score += 55.0 if relative_y != target_relative_y else 0.0
	var column_key := _column_key(column)
	if column_heights.has(column_key):
		for prior_y_value: Variant in column_heights[column_key] as Array:
			if absi(int(prior_y_value) - destination.y) \
					>= WarrenVolumePlan.HEADROOM_BANDS:
				# A column the route visits at two separated heights is the seed
				# of a tunnel: mass fills between the passes and the lower street
				# runs under it. This is the primary covered-path lever; -780 and
				# -705 both cost corpus seeds, so -650 stands.
				score -= 650.0
				break
	# A route folded beside itself at the same datum coalesces into a broad slab
	# when the two player-width lanes are materialized. Reward true over/under
	# crossings, but repel non-consecutive same-height segments. This makes the
	# public realm read as narrow negative space cut through the buildings rather
	# than a plaza that the buildings happen to surround.
	var has_same_level_neighbor := false
	var has_same_level_nearby := false
	var has_vertical_crossover := false
	for prior_index in maxi(0, route.size() - 1):
		var prior := route[prior_index]
		var horizontal_distance := absi(prior.x - destination.x) \
			+ absi(prior.z - destination.z)
		var vertical_distance := absi(prior.y - destination.y)
		if horizontal_distance == 1:
			if vertical_distance >= WarrenVolumePlan.HEADROOM_BANDS:
				has_vertical_crossover = true
			else:
				has_same_level_neighbor = true
		elif horizontal_distance == 2 and vertical_distance == 0:
			has_same_level_nearby = true
	# This is deliberately a feature penalty, not a per-cell sum: a necessary
	# compact hairpin should cost once, whereas accumulating the charge against
	# every earlier cell made complete routes impossible in tight envelopes.
	score += 520.0 if has_same_level_neighbor else 0.0
	score += 110.0 if has_same_level_nearby else 0.0
	score -= 180.0 if has_vertical_crossover else 0.0
	var tie := posmod(_hash(world_seed, attempt, step_index * 31
		+ action_index * 7 + direction_index, destination.x, destination.z), 1009)
	return score + float(tie) * 0.035


static func _entry_throat_move_is_legal(attempt: int, step_index: int,
		entry: Vector3i,
		current: Vector3i, destination: Vector3i, direction: Vector2i,
		current_direction: Vector2i, kind: WarrenVolumeTransition.Kind,
		envelope: WarrenVolumeEnvelope) -> bool:
	# Half of each grammar family retains an organic terrain-following entry. The
	# other half begins with a right-angle street throat, giving the construction
	# frontier both naturally climbing and deliberately enclosed alternatives.
	if step_index > ENTRY_THROAT_MOVE_COUNT:
		return true
	if attempt < ENTRY_THROAT_ATTEMPT_OFFSET:
		return true
	var destination_column := Vector2i(destination.x, destination.z)
	var current_column := Vector2i(current.x, current.z)
	# The first move heads deeper into the Gaussian construction envelope. Height
	# is a more reliable notion of "inside" than distance to the origin because
	# the envelope is deliberately warped and skewed.
	if step_index == 1:
		if kind != WarrenVolumeTransition.Kind.LEVEL \
				or destination.y != envelope.ground_at(destination_column):
			return false
		# A warped Gaussian edge commonly has a one-cell plateau. Equal height is
		# still an inward move with the same future roofable mass; only an actual
		# downhill move would point the entrance back toward the perimeter.
		if envelope.height_at(destination_column) \
				< envelope.height_at(current_column):
			return false
		if _horizontal_radius(destination) >= _horizontal_radius(current):
			return false
	# The middle move is the grammar's dogleg.  It cannot continue or reverse the
	# first segment, so an adversarial entry camera never sees the primary route
	# as a straight cut through the town.
	if step_index == 2:
		var ground := envelope.ground_at(destination_column)
		if destination.y < ground or destination.y > ground + 1:
			return false
		return current_direction != Vector2i.ZERO \
			and _dot(current_direction, direction) == 0 \
			and envelope.height_at(destination_column) \
				>= envelope.height_at(Vector2i(entry.x, entry.z))
	return true


static func _horizontal_radius(cell: Vector3i) -> float:
	return Vector2(float(cell.x), float(cell.z)).length_squared()


static func _transition_air(from_cell: Vector3i, to_cell: Vector3i,
		run: int) -> Array[Vector3i]:
	var unique: Dictionary = {}
	var out: Array[Vector3i] = []
	for offset in range(run + 1):
		var ratio := float(offset) / float(run)
		var x := roundi(lerpf(float(from_cell.x), float(to_cell.x), ratio))
		var z := roundi(lerpf(float(from_cell.z), float(to_cell.z), ratio))
		var interpolated_y := lerpf(float(from_cell.y), float(to_cell.y), ratio)
		var low_y := floori(interpolated_y)
		var high_y := ceili(interpolated_y)
		for y in range(low_y,
				high_y + WarrenVolumePlan.HEADROOM_BANDS):
			var cell := Vector3i(x, y, z)
			if not unique.has(cell):
				unique[cell] = true
				out.append(cell)
	return out


static func _walk_air(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in range(cell.y, cell.y + WarrenVolumePlan.HEADROOM_BANDS):
		out.append(Vector3i(cell.x, y, cell.z))
	return out


static func _swept_air_is_legal(swept: Array[Vector3i],
		current: Vector3i, envelope: WarrenVolumeEnvelope,
		air_set: Dictionary) -> bool:
	for cell: Vector3i in swept:
		if not envelope.mass_cells.has(cell):
			return false
		if air_set.has(cell) and not (cell.x == current.x and cell.z == current.z
				and cell.y >= current.y
				and cell.y < current.y + WarrenVolumePlan.HEADROOM_BANDS):
			return false
	return true
static func _passes_topology_gate(plan: WarrenVolumePlan) -> bool:
	return plan.is_sealed() \
		and int(plan.audit.walk_cell_count) >= MIN_ROUTE_CELLS \
		and int(plan.audit.elevation_band_count) >= 4 \
		and int(plan.audit.ramp_transition_count) >= 1 \
		and int(plan.audit.landing_turn_violation_count) == 0 \
		and int(plan.audit.max_transition_rise_bands) <= 1 \
		and float(plan.audit.overhang_walk_ratio) >= 0.25 \
		and float(plan.audit.addressed_walk_ratio) >= MIN_ADDRESSED_WALK_RATIO \
		and float(plan.audit.get(
			"ground_primary_two_sided_address_walk_ratio", 0.0)) \
			>= MIN_GROUND_PRIMARY_TWO_SIDED_ADDRESS_RATIO \
		and float(plan.audit.deep_vertical_shaft_ratio) <= 0.10 \
		and int(plan.audit.same_datum_route_fold_count) == 0 \
		and int(plan.audit.max_straight_run_cells) <= MAX_STRAIGHT_RUN


static func _plan_score(plan: WarrenVolumePlan) -> float:
	var attempt := _attempt_from_id(plan.stable_id)
	var style01 := float(posmod(_hash(plan.world_seed, attempt, 211, 0, 0),
		1000003)) / 1000003.0
	return -float(plan.audit.route_crossover_count) * 700.0 \
		- float(plan.audit.overhang_walk_ratio) * 420.0 \
		- float(plan.audit.addressed_walk_ratio) * 180.0 \
		- float(plan.audit.elevation_band_count) * 45.0 \
		- float(plan.audit.ramp_transition_count) * 18.0 \
		+ float(plan.audit.deep_vertical_shaft_ratio) * 1200.0 \
		+ float(plan.audit.same_datum_route_near_fold_count) * 95.0 \
		+ float(plan.audit.max_straight_run_cells) * 25.0 \
		+ style01 * STYLE_SELECTION_JITTER


static func _attempt_from_id(stable_id: StringName) -> int:
	var parts := String(stable_id).split(".")
	for index in range(parts.size() - 1, -1, -1):
		var token := parts[index] as String
		if token.is_valid_int():
			return int(token)
	return 0


static func _add_column_height(columns: Dictionary, cell: Vector3i) -> void:
	var key := _column_key(Vector2i(cell.x, cell.z))
	if not columns.has(key):
		columns[key] = []
	(columns[key] as Array).append(cell.y)


static func _column_key(column: Vector2i) -> String:
	return "%d:%d" % [column.x, column.y]


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _dot(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.x + a.y * b.y


static func _envelope_address_side_count(cell: Vector3i,
		envelope: WarrenVolumeEnvelope) -> int:
	var count := 0
	for direction: Vector2i in DIRECTIONS:
		var column := Vector2i(cell.x + direction.x, cell.z + direction.y)
		if envelope.contains_column(column) \
				and envelope.ground_at(column) <= cell.y \
				and envelope.top_at(column) \
					>= cell.y + envelope.address_bands:
			count += 1
	return count


static func _hash(seed_value: int, attempt: int, salt: int,
		x: int, z: int) -> int:
	# Mix seed and attempt independently before combining them. The former linear
	# expression let a different attempt partly cancel an adjacent world seed, so
	# two seeds could search an identical route and converge on the same city.
	# Keeping every multiplication below 2^63 also makes the result portable
	# across worker and headless builds.
	const MODULUS := 2147483629
	var seed_mix := posmod(seed_value, MODULUS)
	seed_mix = posmod((seed_mix ^ (seed_mix >> 16)) * 48271 \
		+ 1013904223, MODULUS)
	var attempt_mix := posmod(attempt * 214013 + salt * 12345, MODULUS)
	attempt_mix = posmod((attempt_mix ^ (attempt_mix >> 11)) * 69621 \
		+ 374761393, MODULUS)
	var value := seed_mix ^ attempt_mix ^ (x * 73856093) ^ (z * 19349663)
	value = posmod((value ^ (value >> 13)) * 1274126177, MODULUS)
	return value
