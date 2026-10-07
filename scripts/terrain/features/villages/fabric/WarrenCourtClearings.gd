class_name WarrenCourtClearings
extends RefCounted
## Courtyard clearings: open rooms reserved inside the massif while streets
## are bored. Placement is a biased draw, never a rule: columns far from any
## street (big uncut blocks) are more likely, ground level moderately
## favoured, size/shape/purpose drawn from the town's character. Only
## guardrails are hard: a legal deck column at the floor, minimum width 2
## (every cell lies in a fully contained 2x2 block), and no overlap with other
## reservations or earlier clearings. Pure: nothing is carved here.

const ATTEMPTS_PER_CLEARING := 24
const SALT_CENTRE := 0x434C4552
const SALT_SHAPE := 0x53484150  # "SHAP"; was SALT_FLOOR ("FLOR") until Oct 7 -- reshuffles shapes under overrides only (off by default)
const SALT_GROW := 0x47524F57
const SALT_ANCHOR := 0x414E4348
const SALT_SIZE := 0x53495A45
const STREET_REACH := 6
const FLOOR_STEP := 2
const DECK_LEVEL_BANDS := 6


static func street_distance(massif: WarrenMassif, excavation: WarrenExcavation) -> Dictionary:
	## Column -> 4-neighbour steps over the massif to the nearest column holding
	## a public cell (those columns are 0). Columns no street reaches are absent.
	var distance := {}
	var frontier: Array[Vector2i] = []
	for cell: Vector3i in excavation.public_cells():
		var column := Vector2i(cell.x, cell.z)
		if massif.has_column(column) and not distance.has(column):
			distance[column] = 0
			frontier.append(column)
	frontier.sort_custom(WarrenPlotPlanner.column_less)
	var index := 0
	while index < frontier.size():
		var column := frontier[index]
		index += 1
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := column + direction
			if massif.has_column(next) and not distance.has(next):
				distance[next] = int(distance[column]) + 1
				frontier.append(next)
	return distance


static func propose(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation,
		profile: WarrenVillageScaleProfile) -> Array[Dictionary]:
	var character := TownCharacter.of(profile, world_seed)
	var wanted := character.count(&"clearing_count")
	var out: Array[Dictionary] = []
	if wanted <= 0:
		return out
	var empty := WarrenMazeSourcePlan.new(world_seed, profile, massif, excavation)
	var blocked := WarrenPlotPlanner.blocked_columns(empty)
	var street := street_distance(massif, excavation)
	var by_band := {}
	for cell: Vector3i in excavation.public_cells():
		if not by_band.has(cell.y):
			by_band[cell.y] = {}
		by_band[cell.y][Vector2i(cell.x, cell.z)] = true
	var candidates := _candidates(empty, street, blocked, character, by_band)
	var taken := {}
	var attempt := 0
	while out.size() < wanted and attempt < wanted * ATTEMPTS_PER_CLEARING and not candidates.is_empty():
		attempt += 1
		var centre := _weighted_pick(candidates, character.roll(&"clearing_block_bias", Vector2i(attempt, SALT_CENTRE)))
		if taken.has(centre.column):
			continue
		var floor_band := int(centre.floor)
		var shape := character.pick(&"clearing_shape", Vector2i(attempt, SALT_SHAPE))
		var area := character.count(&"clearing_area")
		var cells := _grow(empty, centre.column as Vector2i, floor_band, area,
			shape, blocked, taken, street, character, attempt)
		if cells.size() < maxi(4, area / 2):
			continue
		for column: Vector2i in cells:
			taken[column] = true
		var key := Vector2i(out.size(), floor_band)
		out.append({"cells": cells, "floor": floor_band, "shape": shape, "area": area,
			"purpose": character.pick(&"clearing_purpose", key),
			"cover": character.pick(&"clearing_cover", key)})
	return out


static func carve(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation,
		occupied: Dictionary, profile: WarrenVillageScaleProfile) -> void:
	## Realise the proposals as reserved open rooms, each joined to the street
	## network by at least one level access lane from a doorstep beside it, plus
	## further separated lanes by odds. Each clearing is reserved before its lanes
	## are searched, so no lane bores through it; one that overlaps any existing
	## reservation or bored air, or that no street reaches at its floor, is
	## withdrawn whole
	## (reservations released, nothing carved).
	var proposals := propose(world_seed, massif, excavation, profile)
	if proposals.is_empty():
		return
	var character := TownCharacter.of(profile, world_seed)
	for proposal: Dictionary in proposals:
		var floor_band := int(proposal.floor)
		# Reserve this clearing before its own lanes are searched, so no lane
		# bores through it. An earlier clearing's lane may already have bored
		# through this one: then it is withdrawn whole.
		var claims := {}
		var clash := false
		for column: Vector2i in proposal.cells:
			for band in range(floor_band - 1, floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
				var cell := Vector3i(column.x, band, column.y)
				clash = clash or excavation.carved.has(cell) \
					or excavation.construction_reservations.has(cell)
				claims[cell] = true
		if clash:
			continue
		for cell: Vector3i in claims:
			excavation.construction_reservations[cell] = true
		var inside := {}
		for column: Vector2i in proposal.cells:
			inside[column] = true
		var public := {}
		for cell: Vector3i in excavation.public_cells():
			public[cell] = true
		var walk_nodes := {}
		for cell: Vector3i in WarrenMazeCarver._walk_nodes(excavation):
			walk_nodes[cell] = true
		var flights := excavation.flight_cells()
		var doorsteps: Array[Vector3i] = []
		for column: Vector2i in proposal.cells:
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := column + direction
				if inside.has(next) or not massif.has_column(next):
					continue
				var step := Vector3i(next.x, floor_band, next.y)
				# A flight's tread is never a doorstep.
				if flights.has(step):
					continue
				if not doorsteps.has(step):
					doorsteps.append(step)
		doorsteps.sort_custom(WarrenExcavation._cell_less)
		var connections: Array[Dictionary] = []
		for step: Vector3i in doorsteps:
			var connection: Dictionary = {"anchor": step, "cells": [] as Array[Vector3i]} \
				if walk_nodes.has(step) \
				else WarrenMazeCarver._level_gate_connection(massif, excavation, public,
					walk_nodes, step, true, true)
			if not connection.is_empty():
				connections.append(connection)
		if connections.is_empty():
			# Guardrail: an unreachable clearing is withdrawn whole.
			for cell: Vector3i in claims:
				excavation.construction_reservations.erase(cell)
			continue
		connections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var na := (a.cells as Array).size()
			var nb := (b.cells as Array).size()
			if na != nb:
				return na < nb
			return WarrenExcavation._cell_less(_door_of(a), _door_of(b)))
		var chosen: Array[Dictionary] = [connections[0]]
		for i in range(1, connections.size()):
			var far_enough := true
			for c: Dictionary in chosen:
				var a := _door_of(c)
				var b := _door_of(connections[i])
				far_enough = far_enough and absi(a.x - b.x) + absi(a.z - b.z) > 3
			if far_enough and character.chance(&"clearing_extra_link_chance",
					Vector3i(i, floor_band, excavation.court_clearings.size())):
				chosen.append(connections[i])
		for connection: Dictionary in chosen:
			var cells: Array[Vector3i] = []
			cells.assign(connection.cells)
			if cells.is_empty():
				continue
			var previous: Vector3i = connection.anchor
			var transitions: Array[Dictionary] = []
			for cell: Vector3i in cells:
				transitions.append({"from": previous, "to": cell,
					"kind": WarrenVolumeTransition.Kind.LEVEL})
				occupied[cell] = true
				for band in range(cell.y, cell.y + WarrenPassageLatticeRules.HEADROOM_BANDS):
					excavation.carved[Vector3i(cell.x, band, cell.z)] = true
				previous = cell
			excavation.lanes.append({"anchor": connection.anchor, "cells": cells,
				"transitions": transitions, "feature_kind": &"court_clearing_access"})
		var record := proposal.duplicate()
		var doors: Array[Vector3i] = []
		for connection: Dictionary in chosen:
			doors.append(_door_of(connection))
		record["door_walk"] = doors[0]
		record["doors"] = doors
		record["links"] = chosen.size()
		excavation.court_clearings.append(record)


static func _door_of(connection: Dictionary) -> Vector3i:
	## The doorstep beside the clearing: the lane's last cell, or the anchor
	## itself when the doorstep already is a walk node.
	var cells: Array = connection.cells
	return connection.anchor if cells.is_empty() else cells.back()


static func _candidates(plan: WarrenMazeSourcePlan, street: Dictionary, blocked: Dictionary,
		character: TownCharacter, by_band: Dictionary) -> Array[Dictionary]:
	## (column, floor) pairs weighted by street distance ^ bias, ground x weight.
	var out: Array[Dictionary] = []
	var massif := plan.massif
	var bias := character.value(&"clearing_block_bias")
	var ground := character.value(&"clearing_ground_weight")
	var columns: Array = massif.columns.keys()
	columns.sort_custom(WarrenPlotPlanner.column_less)
	for column: Vector2i in columns:
		var distance := int(street.get(column, 0))
		if distance <= 0 or blocked.has(column):
			continue
		var low := massif.bearing_at(column)
		var high := massif.top_at(column)
		var base_weight := pow(maxf(0.01, float(distance)), bias)
		for floor_band in range(low, high + 1, FLOOR_STEP):
			if not _street_at_band(by_band, column, floor_band) \
					or _reserved(plan.excavation, column, floor_band):
				continue
			if WarrenPlotReservations._deck_column_ok(plan, column, floor_band, {}, blocked, DECK_LEVEL_BANDS):
				out.append({"column": column, "floor": floor_band,
					"weight": base_weight * (ground if floor_band == low else 1.0)})
	return out


static func _reserved(excavation: WarrenExcavation, column: Vector2i, floor_band: int) -> bool:
	## A clearing never shares another construction envelope: no band of its
	## span (floor-1 .. floor+MIN_HOUSE_BANDS-1) may already be reserved.
	for band in range(floor_band - 1, floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS):
		if excavation.construction_reservations.has(Vector3i(column.x, band, column.y)):
			return true
	return false


static func _street_at_band(by_band: Dictionary, column: Vector2i, floor_band: int) -> bool:
	## A floor (ground or raised) needs a public cell at exactly that band within
	## reach, so a level access lane can connect it.
	var at: Dictionary = by_band.get(floor_band, {})
	for dx in range(-STREET_REACH, STREET_REACH + 1):
		var span := STREET_REACH - absi(dx)
		for dz in range(-span, span + 1):
			if at.has(column + Vector2i(dx, dz)):
				return true
	return false


static func _weighted_pick(candidates: Array[Dictionary], r: float) -> Dictionary:
	var total := 0.0
	for c: Dictionary in candidates:
		total += float(c.weight)
	var target := r * total
	for c: Dictionary in candidates:
		target -= float(c.weight)
		if target < 0.0:
			return c
	return candidates.back()


static func _legal(plan: WarrenMazeSourcePlan, column: Vector2i, floor_band: int,
		blocked: Dictionary, taken: Dictionary, street: Dictionary) -> bool:
	return not taken.has(column) and int(street.get(column, 0)) > 0 \
		and not _reserved(plan.excavation, column, floor_band) \
		and WarrenPlotReservations._deck_column_ok(plan, column, floor_band, {}, blocked, DECK_LEVEL_BANDS)


static func _grow(plan: WarrenMazeSourcePlan, centre: Vector2i, floor_band: int, area: int,
		shape: StringName, blocked: Dictionary, taken: Dictionary, street: Dictionary,
		character: TownCharacter, attempt: int) -> Array[Vector2i]:
	## The drawn shape caps the piece count: rect 1, two_rect 2, three_rect 3,
	## blob up to area/4 2x2 blocks. Each piece (>= 2x2) is placed whole at the
	## first legal offset of a seeded scan, the first containing the centre and
	## later ones containing a cell beside the clearing. A piece that cannot be
	## placed ends the growth; the caller judges the area reached.
	var rect_count: int = {&"rect": 1, &"two_rect": 2, &"three_rect": 3}.get(shape, 0)
	var pieces := rect_count if rect_count > 0 else maxi(1, area / 4)
	var per_piece := maxi(4, area / rect_count) if rect_count > 0 else 4
	var memo := {}
	var cells := {}
	for piece in pieces:
		var size_key := Vector4i(attempt, piece, SALT_GROW, SALT_SIZE)
		var anchor_key := Vector4i(attempt, piece, SALT_GROW, SALT_ANCHOR)
		var w := 2
		var d := 2
		if rect_count > 0:
			w = 2 + int(character.roll(&"clearing_area", size_key) * maxf(1.0, sqrt(float(per_piece)) - 1.0))
			d = maxi(2, per_piece / w)
		var anchors: Array[Vector2i] = [centre]
		if not cells.is_empty():
			anchors.clear()
			var keys: Array = cells.keys()
			keys.sort_custom(WarrenPlotPlanner.column_less)
			var start := int(character.roll(&"clearing_area", anchor_key) * float(keys.size()))
			for i in keys.size():
				var cell: Vector2i = keys[(start + i) % keys.size()]
				for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
					if not cells.has(cell + direction):
						anchors.append(cell + direction)
		var placed := false
		for anchor: Vector2i in anchors:
			var offsets := w * d
			var first := int(character.roll(&"clearing_area", Vector4i(anchor.x, anchor.y, piece, SALT_ANCHOR)) * float(offsets))
			for i in offsets:
				var o := (first + i) % offsets
				var corner := anchor - Vector2i(o % w, o / w)
				var block: Array[Vector2i] = []
				var legal := true
				for x in w:
					for z in d:
						var column := corner + Vector2i(x, z)
						if cells.has(column):
							continue
						if not memo.has(column):
							memo[column] = _legal(plan, column, floor_band, blocked, taken, street)
						if not memo[column]:
							legal = false
							break
						block.append(column)
					if not legal:
						break
				if legal:
					for column: Vector2i in block:
						cells[column] = true
					placed = true
					break
			if placed:
				break
		if not placed:
			break
	var out: Array[Vector2i] = []
	out.assign(cells.keys())
	out.sort_custom(WarrenPlotPlanner.column_less)
	return out
