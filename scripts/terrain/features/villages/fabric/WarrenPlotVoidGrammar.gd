class_name WarrenPlotVoidGrammar
extends RefCounted

## Chooses the coarse occupied plots and the only legal public void through
## them. This stage is intentionally geometry/resource free. Seed variation may
## choose among reviewed motifs and plot bands, but cannot relax connectivity,
## external-circulation, or support obligations.
const MAX_ROUTE_RADIUS_CELLS := 11
const MARKET_ALLEY_START_ACTION := 1


static func build(world_seed: int, attempt: int = 0) -> WarrenPlotVoidPlan:
	## Build the circulation first as a compact self-avoiding 3D maze. Seed and
	## attempt affect every turn; there is no fixed coordinate motif underneath
	## later cosmetic variation. The common transaction remains free to reject a
	## coarse route after exact building/headroom envelopes are known.
	var plan := WarrenPlotVoidPlan.new(&"warren.plot-void", world_seed)
	var route: Array[Dictionary] = []
	var market_ids: Array[StringName] = []
	var occupied: Dictionary = {}
	var route_volume: Dictionary = {}
	var current := Vector3i.ZERO
	var current_direction := _cardinals()[posmod(
		_seeded_hash(world_seed, attempt, 0), 4)]
	var parent_id := &"maze.landing"
	var route_index := 0
	_route_landing(route, parent_id, current)
	occupied[_cell_key(current)] = true
	_add_square_volume(route_volume, current)
	# Turns are deliberately frequent. Elevation actions always materialize a
	# square landing before another flight can begin; the audit independently
	# proves that result from the compiled surface graph.
	var actions := _actions_for_seed(world_seed)
	for action_index in actions.size():
		var action := actions[action_index]
		var is_stair := action == &"up_half" or action == &"down_half" \
			or action == &"up_full" or action == &"down_full"
		# A half flight occupies two stair bands between its adjacent 6 m squares;
		# a full flight occupies three. The old coarse grammar advanced every stair
		# by four cells, while the exact full-flight sockets advance by five. After
		# the first full rise, every later reservation was therefore one cell away
		# from the geometry it claimed to protect. That admitted many routes whose
		# stairs intersected an earlier deck only after expensive exact compilation.
		var distance := 5 if action == &"up_full" or action == &"down_full" \
			else 4 if is_stair else 2
		var next_y := current.y
		if action == &"up_half":
			next_y += 1
		elif action == &"down_half":
			next_y -= 1
		elif action == &"up_full":
			next_y += 2
		elif action == &"down_full":
			next_y -= 2
		var force_turn := action == &"turn" or is_stair
		var direction := _choose_direction(current_direction, current,
			next_y, distance, occupied, route_volume, force_turn,
			world_seed, attempt, action_index)
		if direction == Vector2i.ZERO:
			return null
		var destination := current + Vector3i(direction.x * distance,
			next_y - current.y, direction.y * distance)
		var candidate_volume := _candidate_route_volume(current, destination,
			direction, is_stair)
		assert(not candidate_volume.is_empty())
		if is_stair:
			var stair_id := StringName("maze.stair.%02d" % route_index)
			var rising := next_y > current.y
			var recipe_id := &"stair.full" if action == &"up_full" \
				or action == &"down_full" \
				else &"stair.half"
			_step(route, stair_id, recipe_id, parent_id,
				&"walk.low" if rising else &"walk.high",
				_socket(direction), _stair_yaw(direction if rising else -direction),
				true)
			route_index += 1
			var landing_id := StringName("maze.landing.%02d" % route_index)
			_step(route, landing_id,
				&"deck.corner" if next_y > 0 else &"route.corner", stair_id,
				_socket(-direction), &"walk.high" if rising else &"walk.low", 0)
			parent_id = landing_id
		else:
			var node_id := StringName("maze.route.%02d" % route_index)
			var turned := direction != current_direction
			var recipe_id := &"deck.corner" if next_y > 0 and turned \
				else &"deck.straight" if next_y > 0 \
				else &"route.corner" if turned else &"route.straight"
			_step(route, node_id, recipe_id, parent_id, _socket(-direction),
				_socket(direction), 0)
			parent_id = node_id
			# The entry square is deliberately excluded. Stalls belong inside the
			# first winding alley, bounded by later massing on both sides; allowing a
			# stall beside the seed landing made it read as a stray tent in the grass.
			if market_ids.size() < 5 and next_y == 0 \
					and action_index >= MARKET_ALLEY_START_ACTION:
				market_ids.append(node_id)
		occupied[_cell_key(destination)] = true
		for volume_cell: Variant in candidate_volume:
			route_volume[volume_cell as Vector3i] = true
		# Reserve every intermediate flight band at both endpoint datums. The
		# position qualifier expands each stored centre by the route half-width and
		# one headroom band, so later squares cannot graze either the low or high
		# half of a stair. These are conservative coarse cells only; exact recipe
		# occupancy remains the transaction authority.
		if is_stair:
			for offset in range(2, distance):
				var band := current + Vector3i(direction.x * offset, 0,
					direction.y * offset)
				occupied[_cell_key(band)] = true
				occupied[_cell_key(Vector3i(band.x, next_y, band.z))] = true
		current = destination
		current_direction = direction
		route_index += 1
	return plan if plan.seal(route, [], market_ids, []) else null


static func _actions_for_seed(world_seed: int) -> Array[StringName]:
	## The vertical schedule is part of the maze geometry. Earlier seeds changed
	## only left/right ties while every attempt shared this same sequence; the
	## bounded selector could therefore converge different seeds onto one global
	## compact optimum. Four reviewed schedules move the seven external flights
	## through different parts of the walk while preserving the same +2,-1,+2,+2,
	## -1,-2,-2 height sequence, ground return, half-level offsets, and up/down/up
	## character. Direction choices and building packing remain fully hashed, so
	## these are grammar families rather than four authored towns.
	# Low-bit families deliberately form a complete 4 x 2 schedule for adjacent
	# integer seeds. The next two independent bits choose the vertical profile,
	# yielding 32 sectional families before any attempt-specific turn decisions.
	# Keeping these bits explicit (rather than re-hashing down to four buckets)
	# prevents two distinct city seeds from needlessly colliding at this first,
	# cheap geometry decision.
	var motif := posmod(world_seed, 4)
	var ordinary_phase := posmod(world_seed >> 2, 2)
	var vertical_profile := posmod(world_seed >> 3, 4)
	if motif == 0 and ordinary_phase == 0 and vertical_profile == 0:
		# Retain the most heavily screenshot-reviewed schedule as one grammar
		# family. Other phase/profile combinations of this motif use the same
		# spatial stair slots through the general family compiler below.
		return [
			&"straight", &"turn", &"straight", &"turn", &"straight",
			&"turn", &"straight", &"up_full", &"turn", &"straight",
			&"down_half", &"turn", &"straight", &"up_full", &"up_full",
			&"turn", &"straight", &"down_half", &"straight", &"down_full",
			&"turn", &"down_full", &"straight",
		] as Array[StringName]
	var stair_slots: Array[int]
	match motif:
		0:
			# The reviewed profile-0 family above may place two climbs back to
			# back. Alternate vertical profiles use the roomier cadence; otherwise
			# a half-drop variant can fold both stair clearance bands onto itself.
			stair_slots = [7, 10, 13, 16, 18, 20, 22]
		1:
			# A climb at slot four leaves only two exact ground-alley candidates
			# after the route's 6 m squares and stair headroom are rasterized.  No
			# member of that grammar family could fit both stocked frontages and an
			# inhabited source-pack anchor.  Keep this family distinct, but let its
			# ground market wind through three turns before the first rise.
			stair_slots = [7, 10, 12, 15, 17, 20, 22]
		2:
			stair_slots = [5, 8, 11, 14, 17, 20, 22]
		_:
			stair_slots = [6, 9, 12, 15, 18, 20, 22]
	var stairs := _stair_sequence(vertical_profile)
	var actions: Array[StringName] = []
	var stair_index := 0
	var ordinary_index := 0
	for action_index in 23:
		if stair_index < stair_slots.size() \
				and action_index == stair_slots[stair_index]:
			actions.append(stairs[stair_index])
			stair_index += 1
		else:
			# At most two ordinary squares continue straight. Together with every
			# stair's forced turn, this keeps sightlines short without baking a motif.
			actions.append(&"turn" if (ordinary_index + ordinary_phase) % 2 == 1 \
				else &"straight")
			ordinary_index += 1
	assert(stair_index == stairs.size())
	return actions


static func _stair_sequence(variant: int) -> Array[StringName]:
	## Every profile is an external 3D route with the same seven-flight budget,
	## the same two half drops, a non-negative running elevation, at least a five-
	## band summit, and a final return to ground. Seed variation therefore changes
	## sectional maze geometry without relaxing any circulation invariant.
	match posmod(variant, 4):
		0:
			return [
				&"up_full", &"down_half", &"up_full", &"up_full",
				&"down_half", &"down_full", &"down_full",
			]
		1:
			return [
				&"up_full", &"up_full", &"down_half", &"up_full",
				&"down_full", &"down_half", &"down_full",
			]
		2:
			return [
				&"up_full", &"up_full", &"up_full", &"down_full",
				&"down_half", &"down_half", &"down_full",
			]
		_:
			return [
				&"up_full", &"up_full", &"down_half", &"up_full",
				&"down_half", &"down_full", &"down_full",
			]


static func _choose_direction(current_direction: Vector2i, current: Vector3i,
		next_y: int, distance: int, occupied: Dictionary,
		route_volume: Dictionary, force_turn: bool,
		world_seed: int, attempt: int, action_index: int) -> Vector2i:
	var left := Vector2i(current_direction.y, -current_direction.x)
	var right := -left
	var candidates: Array[Vector2i] = [left, right]
	if not force_turn:
		candidates.append(current_direction)
	var ranked: Array[Dictionary] = []
	for direction: Vector2i in candidates:
		var destination := current + Vector3i(direction.x * distance,
			next_y - current.y, direction.y * distance)
		if not _position_clear(destination, occupied):
			continue
		var candidate_volume := _candidate_route_volume(current, destination,
			direction, distance > 2)
		if _volumes_intersect(candidate_volume, route_volume):
			continue
		if distance > 2:
			var flight_clear := true
			for offset in range(2, distance):
				var band := current + Vector3i(direction.x * offset, 0,
					direction.y * offset)
				if not _position_clear(band, occupied) \
						or not _position_clear(Vector3i(band.x, next_y, band.z),
							occupied):
					flight_clear = false
					break
			if not flight_clear:
				continue
		var radius := maxi(absi(destination.x), absi(destination.z))
		if radius > MAX_ROUTE_RADIUS_CELLS:
			continue
		var tie := posmod(_seeded_hash(world_seed, attempt,
			action_index * 17 + direction.x * 3 + direction.y * 5), 97)
		# Prefer folding back into the core before applying the seed tie-break. The
		# former tie-first ordering routinely made two distant lobes joined by one
		# long bridge: technically connected, but not a packed city. Seeded left/right
		# choices still completely change the self-avoiding walk whenever candidates
		# have comparable radius, while this lexicographic weighting prevents random
		# expansion from overwhelming the construction invariant.
		ranked.append({"direction": direction,
			"score": radius * 1000 \
				+ (absi(destination.x) + absi(destination.z)) * 100 + tie})
	if ranked.is_empty():
		return Vector2i.ZERO
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.score) < int(b.score))
	return ranked[0].direction as Vector2i


static func _candidate_route_volume(current: Vector3i,
		destination: Vector3i, direction: Vector2i, is_stair: bool) -> Dictionary:
	## Mirrors the data-only route recipe footprints exactly. Keeping this cheap
	## raster in the grammar prevents a coarse self-avoiding centreline from
	## hiding an overlapping two-lane stair or its headroom. It deliberately owns
	## no meshes, resources, collision, or support policy.
	var out: Dictionary = {}
	if not is_stair:
		_add_square_volume(out, destination)
		return out
	var rise_cells := absi(destination.y - current.y)
	if rise_cells != 1 and rise_cells != 2:
		return out
	var run_cells := rise_cells
	var rising := destination.y > current.y
	var ascent_direction := direction if rising else -direction
	var yaw := _stair_yaw(ascent_direction)
	var parent_socket_cell := current + _route_socket_cell(direction)
	var own_socket_cell := Vector3i(-1, 0, 0) if rising \
		else Vector3i(-1, rise_cells, -run_cells)
	var rotated_own_socket := FabricRecipe.transform_cell(own_socket_cell,
		Vector3i.ZERO, yaw)
	var stair_origin := parent_socket_cell \
		+ Vector3i(direction.x, 0, direction.y) - rotated_own_socket
	for lane in [-1, 0]:
		for step in rise_cells + 1:
			var local_cell := Vector3i(lane, step,
				-mini(step, run_cells))
			var world_cell := FabricRecipe.transform_cell(local_cell,
				stair_origin, yaw)
			_add_volume_cell(out, world_cell)
	_add_square_volume(out, destination)
	return out

static func _route_socket_cell(direction: Vector2i) -> Vector3i:
	if direction == Vector2i.RIGHT:
		return Vector3i(0, 0, -1)
	if direction == Vector2i.LEFT or direction == Vector2i.UP:
		return Vector3i(-1, 0, -1)
	assert(direction == Vector2i.DOWN)
	return Vector3i(-1, 0, 0)


static func _add_square_volume(volume: Dictionary, origin: Vector3i) -> void:
	for x in [-1, 0]:
		for z in [-1, 0]:
			_add_volume_cell(volume, origin + Vector3i(x, 0, z))


static func _add_volume_cell(volume: Dictionary, surface_cell: Vector3i) -> void:
	volume[surface_cell] = true
	volume[surface_cell + Vector3i.UP] = true


static func _volumes_intersect(a: Dictionary, b: Dictionary) -> bool:
	for cell_value: Variant in a:
		if b.has(cell_value as Vector3i):
			return true
	return false


static func _position_clear(position: Vector3i, occupied: Dictionary) -> bool:
	# Public modules are two cells wide, while this grammar stores only their
	# centreline. Reserve the surrounding cell as a resource-free Minkowski margin
	# as well as the walk/headroom bands. Merely rejecting identical centres let a
	# later stair graze an earlier corner; the exact transaction then discarded
	# most candidates for overlaps that were already inevitable from the coarse
	# geometry. Successive centres remain two cells apart and are therefore legal.
	for y_offset in [-1, 0, 1]:
		for x_offset in [-1, 0, 1]:
			for z_offset in [-1, 0, 1]:
				if occupied.has(_cell_key(position + Vector3i(x_offset, y_offset,
						z_offset))):
					return false
	return true


static func _cardinals() -> Array[Vector2i]:
	return [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func _socket(direction: Vector2i) -> StringName:
	if direction == Vector2i.RIGHT:
		return &"walk.east"
	if direction == Vector2i.LEFT:
		return &"walk.west"
	if direction == Vector2i.UP:
		return &"walk.north"
	assert(direction == Vector2i.DOWN)
	return &"walk.south"


static func _stair_yaw(ascent_direction: Vector2i) -> int:
	if ascent_direction == Vector2i.UP:
		return 0
	if ascent_direction == Vector2i.LEFT:
		return 1
	if ascent_direction == Vector2i.DOWN:
		return 2
	assert(ascent_direction == Vector2i.RIGHT)
	return 3


static func _seeded_hash(world_seed: int, attempt: int, salt: int) -> int:
	var value := world_seed ^ (attempt * 0x45d9f3b) ^ (salt * 0x119de1f3)
	value = int((value ^ (value >> 16)) * 0x45d9f3b)
	value = int((value ^ (value >> 16)) * 0x45d9f3b)
	return value ^ (value >> 16)


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _route_landing(route: Array[Dictionary], stable_id: StringName,
		origin: Vector3i) -> void:
	route.append({
		"stable_id": stable_id,
		"recipe_id": &"route.landing",
		"origin": origin,
		"parent_id": &"",
		"yaw_quarters": 0,
	})


static func _step(route: Array[Dictionary], stable_id: StringName,
		recipe_id: StringName, parent_id: StringName, own_socket: StringName,
		parent_socket: StringName, yaw_quarters: int,
		bearing_parent: bool = false) -> void:
	route.append({
		"stable_id": stable_id,
		"recipe_id": recipe_id,
		"parent_id": parent_id,
		"own_socket": own_socket,
		"parent_socket": parent_socket,
		"yaw_quarters": yaw_quarters,
		"bearing_parent": bearing_parent,
	})


static func _secondary_step(route: Array[Dictionary], stable_id: StringName,
		recipe_id: StringName, origin: Vector3i, yaw_quarters: int,
		parents: Array[StringName], bonds: Array[Dictionary]) -> void:
	route.append({
		"stable_id": stable_id,
		"recipe_id": recipe_id,
		"origin": origin,
		"yaw_quarters": yaw_quarters,
		"parents": parents,
		"bonds": bonds,
		"primary": false,
	})


static func _plot(stable_id: StringName, kind: StringName, origin: Vector3i,
		storeys: int, yaw_quarters: int, route_y: int) -> Dictionary:
	return {
		"stable_id": stable_id,
		"kind": kind,
		"origin": origin,
		"storeys": storeys,
		"yaw_quarters": yaw_quarters,
		"route_y": route_y,
		"support_mode": &"grounded_stack" if origin.y == 0 \
			else &"retained_half_perch",
		"occupied_cells": [],
	}


static func _market(stable_id: StringName, origin: Vector3i,
		yaw_quarters: int, family: int) -> Dictionary:
	return {
		"stable_id": stable_id,
		"kind": &"market",
		"origin": origin,
		"storeys": 0,
		"yaw_quarters": yaw_quarters,
		"route_y": 0,
		"support_mode": &"grounded_stack",
		"occupied_cells": [],
		"market_family": family,
	}
