class_name WarrenPlatformStreets
extends RefCounted

## The streets of a raised district (September 29, WarrenTownPlatform), run by
## `WarrenMazeCarver.carve` straight after the spine and before loops and
## alleys, so those see them as existing street:
##
## * `carve_gate`: prefer a supported entrance bored into the district, then
##   climb within it; otherwise an open stair climbing along the wall
##   through the low huddle at the plinth's foot and stepping through a gate
##   in the rim onto the district's grade;
## * `carve`: level lanes across the grade from the gate, until every
##   platform column fronts a lane or sits beside a fronted one -- the citadel
##   is a quarter of houses, not a stone block;
## * `carve_wall_street`: the ground lane round the plinth's foot.
## * `carve_tunnel`: a supported lower route between two existing streets.
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


## Connect successively higher districts through their lower district's grade.
## The view changes only the reference datum; all carving belongs to the one
## real excavation and all final consumers read the original bearing field.
static func carve_nested_gates(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary) -> int:
	var levels: Array[int] = []
	for column: Vector2i in massif.platform_columns():
		var height := massif.plinth_at(column)
		if height not in levels: levels.append(height)
	levels.sort()
	var connected := 0
	for index in range(1,levels.size()):
		var lower := levels[index-1]
		var view := WarrenMassif.new(world_seed)
		for column: Vector2i in massif.platform_columns():
			if massif.plinth_at(column) < lower: continue
			var record: Dictionary = massif.columns[column].duplicate()
			record.base = massif.base_at(column)+lower
			record.plinth = maxi(0,massif.plinth_at(column)-lower)
			record.terrace = int(record.top)-int(record.base)
			view.columns[column] = record
		# Test each complete approach/ascent before it consumes lower-city space.
		var gate := carve_gate(world_seed,view,excavation,occupied,NONE)
		var public := {}
		for cell: Vector3i in excavation.public_cells(): public[cell] = true
		var approaches: Array[Array] = []
		var endpoints := {}
		if gate.is_empty():
			for column: Vector2i in view.columns:
				if view.is_platform(column) or WarrenTownPlatform.huddle_top(view,column) == 2147483647: continue
				var path := _path_beside(massif,excavation,public,column)
				if path.is_empty() or endpoints.has(path.back()): continue
				endpoints[path.back()] = true
				approaches.append(path)
		approaches.sort_custom(func(a: Array,b: Array) -> bool:
			return a.size()<b.size() if a.size()!=b.size() else WarrenMazeCarver._cell_less(a.back(),b.back()))
		const FIELDS := ["route","transitions","lanes","loop_edges","carved","covered","portals",
			"bridge_spans","bridge_span_audit","bridge_bearing_columns","bridge_directions",
			"construction_reservations","frontage_reservations","tunnel_cells","tunnel_attrition","court_clearings"]
		for approach: Array in approaches:
			if not gate.is_empty(): break
			var trial := WarrenExcavation.new(world_seed)
			for key: String in FIELDS: trial.set(key,excavation.get(key).duplicate(true))
			var trial_occupied := occupied.duplicate()
			var trial_public := public.duplicate()
			var path: Array[Vector3i] = []
			path.assign(approach)
			_carve_lane(trial,trial_occupied,trial_public,path)
			gate = carve_gate(world_seed,view,trial,trial_occupied,NONE)
			if gate.is_empty(): continue
			for key: String in FIELDS: excavation.set(key,trial.get(key))
			occupied.clear()
			occupied.merge(trial_occupied)
		if gate.is_empty(): break
		connected += 1
	return connected


## Strides a gate flight may take before it gives up (bounded search).
const GATE_SEARCH_NODES := 4000


static func carve_gate(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary,
		summit: Vector3i) -> Array[Vector3i]:
	## The way up first seeks a supported interior entrance and stair. When
	## none fits, use an open flight from the street network at the plinth's foot,
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
	var gate := _gate_flight(massif, excavation, occupied, nodes, true)
	if gate.is_empty():
		gate = _gate_flight(massif, excavation, occupied, [summit] as Array[Vector3i])
	if gate.is_empty():
		gate = _gate_flight(massif, excavation, occupied, nodes)
	return gate


static func _gate_flight(massif: WarrenMassif, excavation: WarrenExcavation,
		occupied: Dictionary, starts: Array[Vector3i], interior: bool = false) -> Array[Vector3i]:
	var none: Array[Vector3i] = []
	# Nested rings are entered in order. This ascent may cut only the next
	# district; a later gate owns any higher district's foundations.
	var next_plinth := 2147483647
	for column: Vector2i in massif.platform_columns():
		next_plinth = mini(next_plinth,massif.plinth_at(column))
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
			if massif.is_platform(next_column) and not interior:
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
					int(action.run), true, interior, interior)
				if stride.is_empty():
					continue
				var inside := true
				for stepped: Vector3i in stride:
					var stepped_column := Vector2i(stepped.x, stepped.z)
					if interior and massif.is_platform(stepped_column) and massif.plinth_at(stepped_column) != next_plinth:
						inside = false
					inside = inside and not used_columns.has(stepped_column) \
						and (WarrenTownPlatform.huddle_top(massif,
							stepped_column) != 2147483647 or interior and massif.is_platform(stepped_column))
				var end: Vector3i = stride.back()
				if not inside or parent.has(end):
					continue
				parent[end] = cell
				move[end] = {"cells": stride, "rise": int(action.rise),
					"run": int(action.run), "kind": int(action.kind)}
				frontier.append(end)
				if interior and massif.is_platform(Vector2i(end.x,end.z)) \
						and end.y == massif.bearing_at(Vector2i(end.x,end.z)):
					var complete := _path_cells(parent, move, end)
					if not _gate_cover_cells(massif, excavation, complete, _gate_path_carved(parent, move, end)).is_empty():
						goal = end
						break
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
	var covers := _gate_cover_cells(massif, excavation, lane_cells) if interior else {}
	# Later lanes and district tunnels must keep the accepted load paths.
	var path_columns := {}
	for cell: Vector3i in lane_cells: path_columns[Vector2i(cell.x,cell.z)] = true
	for cell: Vector3i in covers:
		var top: int = covers[cell]
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var side := Vector2i(cell.x,cell.z)+direction
			if path_columns.has(side) or not massif.is_platform(side): continue
			if massif.base_at(side)>cell.y or massif.bearing_at(side)<=top: continue
			var clear := true
			for band in range(cell.y,top+1):
				if excavation.carved.has(Vector3i(side.x,band,side.y)): clear = false
			if clear:
				for band in range(cell.y,top+1):
					excavation.construction_reservations[Vector3i(side.x,band,side.y)] = true
	excavation.lanes.append({"anchor": anchor, "cells": lane_cells,
		"transitions": transitions, "feature_kind": &"citadel_gate", "gate_covers": covers})
	return [goal] as Array[Vector3i]


static func _gate_path_carved(parent: Dictionary, move: Dictionary, end: Vector3i) -> Dictionary:
	var swept := {}
	var at := end
	while parent[at] != NONE:
		var stride: Dictionary = move[at]
		for i in stride.cells.size():
			var cell: Vector3i = stride.cells[i]
			var bands := WarrenPassageLatticeRules.stride_slot_bands(int(stride.rise),int(stride.run),i+1)
			for band in range(cell.y,cell.y+bands): swept[Vector3i(cell.x,band,cell.z)] = true
		at = parent[at]
	return swept


static func _gate_cover_cells(massif: WarrenMassif, excavation: WarrenExcavation,
		cells: Array[Vector3i], swept: Dictionary = {}) -> Dictionary:
	# Only the entrance's level passage keeps a ceiling. Ascending treads
	# emerge into the upper street; their complete swept slot stays open.
	var columns := {}
	for cell: Vector3i in cells: columns[Vector2i(cell.x,cell.z)] = true
	var covers := {}
	for cell: Vector3i in cells:
		var column := Vector2i(cell.x,cell.z)
		var top := cell.y + WarrenExcavation.HEADROOM_BANDS
		if not massif.is_platform(column) or top >= massif.bearing_at(column): continue
		# A floor-phase change needs a taller slot; never cap it by guessing.
		if excavation.carved.has(Vector3i(cell.x,top,cell.z)) or swept.has(Vector3i(cell.x,top,cell.z)): continue
		var flanks := 0
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var side := column + direction
			if columns.has(side) or not massif.is_platform(side): continue
			if massif.base_at(side) > cell.y or massif.bearing_at(side) <= top: continue
			var clear := true
			for band in range(cell.y,top+1):
				if excavation.carved.has(Vector3i(side.x,band,side.y)): clear = false
			flanks += int(clear)
		if flanks >= 2: covers[cell] = top
	return covers


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


## One seeded through-route between existing lower streets. The entire bore
## is proved before mutation; every segment retains two bearing neighbours.
static func carve_tunnel(world_seed: int, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary) -> int:
	if massif.platform_columns().is_empty(): return 0
	var nodes := {}
	for cell: Vector3i in WarrenMazeCarver._walk_nodes(excavation): nodes[cell] = true
	var candidates: Array[Array] = []
	for start: Vector3i in nodes:
		if massif.is_platform(Vector2i(start.x,start.z)): continue
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var step := Vector3i(direction.x,0,direction.y)
			var path: Array[Vector3i] = [start]
			for distance in range(1,9):
				var cell := start+step*distance
				if not massif.is_platform(Vector2i(cell.x,cell.z)):
					_offer_tunnel(candidates,path,cell,nodes,massif,excavation)
					break
				if not WarrenPassageLatticeRules.slot_is_borable(massif,excavation,
					cell,WarrenExcavation.HEADROOM_BANDS,false,false,true): break
				path.append(cell)
				# At most one turn: a short corner entrance can connect adjacent
				# street faces without crossing the whole district.
				for turn: Vector3i in [Vector3i(-step.z,0,step.x),Vector3i(step.z,0,-step.x)]:
					var bent: Array[Vector3i] = path.duplicate()
					for run in range(1,9-distance):
						var next := cell+turn*run
						if not massif.is_platform(Vector2i(next.x,next.z)):
							_offer_tunnel(candidates,bent,next,nodes,massif,excavation)
							break
						if not WarrenPassageLatticeRules.slot_is_borable(massif,excavation,
							next,WarrenExcavation.HEADROOM_BANDS,false,false,true): break
						bent.append(next)
	if candidates.is_empty(): return 0
	candidates.sort_custom(func(a: Array,b: Array) -> bool:
		if a.size()!=b.size(): return a.size()<b.size()
		var ah := WarrenPassageLatticeRules.hash_key(world_seed,0x7a117,a[0])
		var bh := WarrenPassageLatticeRules.hash_key(world_seed,0x7a117,b[0])
		if ah!=bh: return ah<bh
		for i in range(a.size()):
			if a[i]!=b[i]: return WarrenMazeCarver._cell_less(a[i],b[i])
		return false)
	var selected: Array = candidates[0]
	var cells: Array[Vector3i] = []
	var transitions: Array[Dictionary] = []
	for i in range(1,selected.size()-1):
		var cell: Vector3i = selected[i]
		cells.append(cell)
		occupied[cell] = true
		transitions.append({"from":selected[i-1],"to":cell,"kind":WarrenVolumeTransition.Kind.LEVEL})
		for band in range(cell.y,cell.y+WarrenExcavation.HEADROOM_BANDS):
			excavation.carved[Vector3i(cell.x,band,cell.z)] = true
	excavation.lanes.append({"anchor":selected[0],"cells":cells,
		"transitions":transitions,"feature_kind":&"wall_tunnel",
		"support_columns":_tunnel_supports(selected)})
	excavation.loop_edges.append({"from":cells.back(),"to":selected.back(),
		"kind":WarrenVolumeTransition.Kind.LEVEL})
	return cells.size()


## Every interior cell has two unbored cardinal neighbours. At a bend these
## meet at the outside corner; along a straight run they are opposing piers.
static func _tunnel_supports(path: Array) -> Dictionary:
	var supports := {}
	for i in range(1,path.size()-1):
		var cell: Vector3i = path[i]
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var neighbour := cell+Vector3i(direction.x,0,direction.y)
			if neighbour==path[i-1] or neighbour==path[i+1]: continue
			supports[Vector2i(neighbour.x,neighbour.z)] = cell.y
	return supports


static func _offer_tunnel(candidates: Array[Array], interior: Array[Vector3i],
		exit_cell: Vector3i, nodes: Dictionary, massif: WarrenMassif,
		excavation: WarrenExcavation) -> void:
	if interior.size()<3 or not nodes.has(exit_cell): return
	var path: Array[Vector3i] = interior.duplicate()
	path.append(exit_cell)
	var supports := _tunnel_supports(path)
	for column: Vector2i in supports:
		var floor_band: int = supports[column]
		if path.has(Vector3i(column.x,floor_band,column.y)): return
		if not massif.is_platform(column) or massif.base_at(column)>floor_band \
			or massif.bearing_at(column)<=floor_band+WarrenExcavation.HEADROOM_BANDS: return
		for band in range(floor_band,floor_band+WarrenExcavation.HEADROOM_BANDS+1):
			if excavation.carved.has(Vector3i(column.x,band,column.y)): return
	candidates.append(path)
