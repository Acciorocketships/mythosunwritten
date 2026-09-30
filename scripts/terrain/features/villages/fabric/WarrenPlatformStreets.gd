class_name WarrenPlatformStreets
extends RefCounted

## The streets of a raised district (September 29, WarrenTownPlatform), run by
## `WarrenMazeCarver.carve` straight after the spine and before loops and
## alleys, so those see them as existing street:
##
## * `carve_gate`: the gate flight, an open stair climbing along the wall
##   through the low huddle at the plinth's foot and stepping through a gate
##   in the rim onto the district's grade (the plinth itself is never bored);
## * `carve`: level lanes across the grade from the gate, until every
##   platform column fronts a lane or sits beside a fronted one -- the citadel
##   is a quarter of houses, not a stone block;
## * `carve_wall_street`: the ground lane round the plinth's foot.
##
## Each lane is the shortest level walk over the platform grade from the
## existing upper streets to a cell beside a still-unfronted column; the
## column itself stays free for its house. Lanes obey the same slot and
## no-broad-square rules as every other passage. A column no lane can reach
## stays rock (its top a walled garden), which is an audit fact, not a
## failure.
const NONE := Vector3i(2147483647, 2147483647, 2147483647)


static func carve(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary) -> int:
	## Returns the number of lane cells carved (zero without a platform).
	var columns := massif.platform_columns()
	if columns.is_empty():
		return 0
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ah := WarrenPassageLatticeRules.hash_key(world_seed, 0x9A7F,
			Vector3i(a.x, 0, a.y))
		var bh := WarrenPassageLatticeRules.hash_key(world_seed, 0x9A7F,
			Vector3i(b.x, 0, b.y))
		return ah < bh if ah != bh else a < b)
	var public: Dictionary = occupied.duplicate()
	for cell: Vector3i in excavation.public_cells():
		public[cell] = true
	var carved := 0
	var unreachable: Dictionary = {}
	var progress := true
	while progress:
		progress = false
		for column: Vector2i in columns:
			if unreachable.has(column) or _served(massif, public, column):
				continue
			var path := _path_beside(massif, excavation, public, column)
			if path.is_empty():
				unreachable[column] = true
				continue
			var added := _carve_lane(excavation, occupied, public, path)
			if added == 0:
				unreachable[column] = true
				continue
			carved += added
			progress = true
	return carved


## Strides a gate flight may take before it gives up (bounded search).
const GATE_SEARCH_NODES := 4000


static func carve_gate(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary,
		summit: Vector3i) -> Array[Vector3i]:
	## The way up: an open flight from the street network at the plinth's foot,
	## climbing along the wall through the low huddle (whose mass stays under
	## the plinth top, WarrenTownPlatform.HUDDLE_RINGS) and stepping level
	## through a gate in the rim onto the district's grade. Shortest in strides
	## (breadth first from the spine's summit at the wall's foot, else from every
	## walk node in the huddle ring, sorted), so deterministic; empty when the
	## spine already stands on the grade or no flight fits (the district then
	## stays an unbuilt rock -- an audit fact).
	## Returns the gate cell (the first grade cell) as a one-cell array.
	var none: Array[Vector3i] = []
	var columns := massif.platform_columns()
	if columns.is_empty():
		return none
	var nodes := WarrenMazeCarver._walk_nodes(excavation)
	nodes.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return WarrenMazeCarver._cell_less(a, b))
	for node: Vector3i in nodes:
		var column := Vector2i(node.x, node.z)
		if massif.is_platform(column) and node.y == massif.bearing_at(column):
			return [node] as Array[Vector3i]
	# The flight continues the spine where its climb stopped at the wall's
	# foot (so the main street leads into the citadel rather than ending
	# blind beside it); failing that, from any street at the foot.
	var gate := _gate_flight(massif, excavation, occupied, [summit] as Array[Vector3i])
	if gate.is_empty():
		gate = _gate_flight(massif, excavation, occupied, nodes)
	return gate


static func _gate_flight(massif: WarrenMassif, excavation: WarrenExcavation,
		occupied: Dictionary, starts: Array[Vector3i]) -> Array[Vector3i]:
	var none: Array[Vector3i] = []
	var parent: Dictionary = {}
	var move: Dictionary = {}
	var frontier: Array[Vector3i] = []
	for node: Vector3i in starts:
		if parent.has(node) or WarrenTownPlatform.huddle_top(massif,
				Vector2i(node.x, node.z)) == 2147483647:
			continue
		parent[node] = NONE
		frontier.append(node)
	var goal := NONE
	var index := 0
	while index < frontier.size() and index < GATE_SEARCH_NODES and goal == NONE:
		var cell := frontier[index]
		index += 1
		var path_cells := _path_cells(parent, move, cell)
		var trial := occupied.duplicate()
		# The flight never passes over or under itself (its slots are not
		# carved until it is chosen): one cell per column.
		var used_columns: Dictionary = {Vector2i(cell.x, cell.z): true}
		for walked: Vector3i in path_cells:
			trial[walked] = true
			used_columns[Vector2i(walked.x, walked.z)] = true
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next_column := Vector2i(cell.x, cell.z) + direction
			# The gate: a level step from the flight onto the grade.
			if massif.is_platform(next_column):
				var gate := Vector3i(next_column.x, cell.y, next_column.y)
				if cell.y == massif.bearing_at(next_column) and not trial.has(gate) \
						and WarrenPassageLatticeRules.slot_is_borable(massif,
							excavation, gate, WarrenPassageLatticeRules.HEADROOM_BANDS,
							false, true):
					parent[gate] = cell
					move[gate] = {"cells": [gate] as Array[Vector3i], "rise": 0,
						"run": 1, "kind": WarrenVolumeTransition.Kind.LEVEL}
					goal = gate
					break
				continue
			for action: Dictionary in WarrenPassageLatticeRules.CLIMB_ACTIONS:
				var stride := WarrenPassageLatticeRules.stride_cells(massif,
					excavation, trial, cell, direction, int(action.rise),
					int(action.run), true)
				if stride.is_empty():
					continue
				var inside := true
				for stepped: Vector3i in stride:
					var stepped_column := Vector2i(stepped.x, stepped.z)
					inside = inside and not used_columns.has(stepped_column) \
						and WarrenTownPlatform.huddle_top(massif,
							stepped_column) != 2147483647
				var end: Vector3i = stride.back()
				if not inside or parent.has(end):
					continue
				parent[end] = cell
				move[end] = {"cells": stride, "rise": int(action.rise),
					"run": int(action.run), "kind": int(action.kind)}
				frontier.append(end)
		if goal != NONE:
			break
	if goal == NONE:
		return none
	var chain: Array[Vector3i] = []
	var at := goal
	while parent[at] != NONE:
		chain.push_front(at)
		at = parent[at]
	var anchor := at
	var lane_cells: Array[Vector3i] = []
	var transitions: Array[Dictionary] = []
	var from := anchor
	for end: Vector3i in chain:
		var step: Dictionary = move[end]
		WarrenPassageLatticeRules.carve_lane_stride(excavation, occupied,
			lane_cells, step.cells, int(step.rise), int(step.run))
		transitions.append({"from": from, "to": end, "kind": int(step.kind)})
		from = end
	excavation.lanes.append({"anchor": anchor, "cells": lane_cells,
		"transitions": transitions, "feature_kind": &"citadel_gate"})
	return [goal] as Array[Vector3i]


static func _path_cells(parent: Dictionary, move: Dictionary,
		cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var at := cell
	while move.has(at):
		out.append_array(move[at].cells as Array[Vector3i])
		at = parent[at]
	return out


static func carve_wall_street(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary) -> int:
	## The lane at the foot of the plinth: level ground street through the
	## ring of columns touching the platform (diagonals included, so the ring
	## is one connected band), grown from the ground network wherever it
	## meets the ring. It keeps the citadel's wall standing free above an open
	## lane -- the lower town's houses face it across the street -- instead
	## of burying it behind their backs. Cells that would close a broad public
	## square or collide with an earlier bore are skipped, so the lane may run
	## in pieces; every piece hangs off a real walk node.
	var columns := massif.platform_columns()
	if columns.is_empty():
		return 0
	var foot: Dictionary = {}
	for column: Vector2i in columns:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var next := column + Vector2i(dx, dz)
				if massif.has_column(next) and not massif.is_platform(next):
					foot[next] = true
	var public: Dictionary = occupied.duplicate()
	for cell: Vector3i in excavation.public_cells():
		public[cell] = true
	var frontier: Array[Vector3i] = []
	var seen: Dictionary = {}
	var nodes := WarrenMazeCarver._walk_nodes(excavation)
	nodes.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return WarrenMazeCarver._cell_less(a, b))
	for node: Vector3i in nodes:
		var column := Vector2i(node.x, node.z)
		if seen.has(node) or node.y != massif.base_at(column):
			continue
		var touches := foot.has(column)
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			touches = touches or foot.has(column + direction)
		if touches:
			seen[node] = true
			frontier.append(node)
	var carved := 0
	var index := 0
	while index < frontier.size():
		var from := frontier[index]
		index += 1
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(from.x, from.z) + direction
			if not foot.has(column):
				continue
			var cell := Vector3i(column.x, massif.base_at(column), column.y)
			if cell.y != from.y or seen.has(cell) or public.has(cell) \
					or not WarrenPassageLatticeRules.slot_is_borable(massif,
						excavation, cell, WarrenPassageLatticeRules.HEADROOM_BANDS) \
					or WarrenPassageLatticeRules.completes_public_square(public, cell):
				continue
			seen[cell] = true
			carved += _carve_lane(excavation, occupied, public,
				[from, cell] as Array[Vector3i], &"wall_street")
			frontier.append(cell)
	return carved


static func _grade(massif: WarrenMassif, column: Vector2i) -> Vector3i:
	return Vector3i(column.x, massif.bearing_at(column), column.y)


static func _served(massif: WarrenMassif, public: Dictionary,
		column: Vector2i) -> bool:
	## Fronted itself, or beside a fronted platform column at the same grade:
	## a house seeded there grows across it (the plot layer's footprint
	## growth and orphan sweep), so it needs no lane of its own.
	if _fronted(massif, public, column):
		return true
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var next := column + direction
		if massif.is_platform(next) \
				and massif.bearing_at(next) == massif.bearing_at(column) \
				and not public.has(_grade(massif, next)) \
				and _fronted(massif, public, next):
			return true
	return false


static func _fronted(massif: WarrenMassif, public: Dictionary,
		column: Vector2i) -> bool:
	## A street at this column's grade in it or beside it: a house here has
	## a door (or the column is street itself).
	var grade := _grade(massif, column)
	if public.has(grade):
		return true
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		if public.has(grade + Vector3i(direction.x, 0, direction.y)):
			return true
	return false


static func _path_beside(massif: WarrenMassif, excavation: WarrenExcavation,
		public: Dictionary, target: Vector2i) -> Array[Vector3i]:
	## Shortest level walk over the platform grade from an existing upper
	## street to a cell beside `target` (never through it). The first cell is
	## the existing street the lane branches from.
	var band := massif.bearing_at(target)
	var parent: Dictionary = {}
	var frontier: Array[Vector3i] = []
	# A lane branches from a walk NODE (a flight's tread is not a landing).
	var nodes: Dictionary = {}
	for node: Vector3i in WarrenMazeCarver._walk_nodes(excavation):
		nodes[node] = true
	for column: Vector2i in massif.platform_columns():
		var cell := _grade(massif, column)
		if cell.y == band and nodes.has(cell):
			parent[cell] = NONE
			frontier.append(cell)
	var goal := NONE
	var index := 0
	while index < frontier.size() and goal == NONE:
		var cell := frontier[index]
		index += 1
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := cell + Vector3i(direction.x, 0, direction.y)
			var column := Vector2i(next.x, next.z)
			if parent.has(next) or column == target \
					or not massif.is_platform(column) \
					or massif.bearing_at(column) != band or public.has(next) \
					or not WarrenPassageLatticeRules.slot_is_borable(massif,
						excavation, next, WarrenPassageLatticeRules.HEADROOM_BANDS,
						false, true) \
					or WarrenPassageLatticeRules.completes_public_square(public, next):
				continue
			parent[next] = cell
			if absi(column.x - target.x) + absi(column.y - target.y) == 1:
				goal = next
				break
			frontier.append(next)
	var path: Array[Vector3i] = []
	var cell := goal
	while cell != NONE:
		path.push_front(cell)
		cell = parent[cell]
	# A lane of new cells only: the branch point plus at least one cell.
	if path.size() < 2:
		path.clear()
	return path


static func _carve_lane(excavation: WarrenExcavation, occupied: Dictionary,
		public: Dictionary, path: Array[Vector3i],
		kind: StringName = &"upper_town") -> int:
	var cells: Array[Vector3i] = []
	var transitions: Array[Dictionary] = []
	for index in range(1, path.size()):
		var cell := path[index]
		if WarrenPassageLatticeRules.completes_public_square(public, cell):
			break
		cells.append(cell)
		transitions.append({"from": path[index - 1], "to": cell,
			"kind": WarrenVolumeTransition.Kind.LEVEL})
		occupied[cell] = true
		public[cell] = true
		for band in range(cell.y, cell.y + WarrenPassageLatticeRules.HEADROOM_BANDS):
			excavation.carved[Vector3i(cell.x, band, cell.z)] = true
	if not cells.is_empty():
		excavation.lanes.append({"anchor": path[0], "cells": cells,
			"transitions": transitions, "feature_kind": kind})
	return cells.size()
