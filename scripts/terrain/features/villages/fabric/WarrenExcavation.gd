class_name WarrenExcavation
extends RefCounted

## The carved negative space: route walk cells, all removed cells, cover
## flags, transition specs, and portals. Pure data plus derived metrics.
##
## Cells are (x, band, z). A walk cell's y is the FLOOR band; the slot the
## carver removed above it spans HEADROOM_BANDS and lives in `carved`, so
## `carved` is the complete subtraction and `route` is only its floor.
##
## This object deliberately holds no reference to the massif it came out of.
## Every massif-relative invariant -- that the removed slot stayed inside the
## solid, that a cover flag is backed by mass actually left overhead, that a
## walk cell is flanked -- is therefore the carver's to enforce and the
## tests' to re-derive independently; seal() can only validate the walk.
const HEADROOM_BANDS := 3

var world_seed: int
var route: Array[Vector3i] = []
## Secondary lanes branching off the route, or off an earlier lane. Each entry
## is `{"anchor": Vector3i, "cells": Array[Vector3i],
## "transitions": Array[Dictionary]}` with exactly the route's own contract:
## `anchor` is a cell of the already-connected public realm, `cells` is the
## ordered walk leading away from it (stride intermediates included, as in
## `route`), and `transitions` tile `[anchor] + cells` under
## WarrenVolumeTransition's rise/run rules.
##
## Kept out of `route` rather than appended to it because `route` is one
## itinerary that seal() requires to be a single unbroken walk -- and because
## every gate the primary route answers to (span, cover, portals, wall ratio,
## grade phase) is a statement about that itinerary, not about the street
## network as a whole. A lane is public realm and a street wall for ownership
## and addressing; it is not part of the route those gates measure.
var lanes: Array[Dictionary] = []
## Explicit graph edges which close an already carved lane back onto an older
## public cell.  A loop edge owns no additional walk cell: its `from` and `to`
## endpoints are adjacent cells already present in `route`/`lanes`.  Keeping
## this separate from ordered lane walks lets the source remain a set of simple
## non-revisiting paths while still sealing a cyclic public graph.
var loop_edges: Array[Dictionary] = []
## Contiguous same-datum public cells whose overhead mass the carver
## deliberately retained instead of opening to the sky. The retained tunnel
## roof bears an inhabited bridge-house while the route remains exterior air
## below it. Each entry is one ordered `Array[Vector3i]` run of already-public
## route/lane cells; `_finalize_excavation` marks them `covered` like any other
## roofed passage cell.
var bridge_spans: Array[Array] = []
## The seed-time retained-mass proof, published so it can be read rather than
## trusted. `{"seeded": Array[Dictionary], "refused": Array[Dictionary]}`;
## each record names the span cells, bridge-room storey, travel direction, and
## measured optional flank columns. Written only by `WarrenMazeCarver
## ._select_bridge_spans`; another producer leaves it empty.
var bridge_span_audit: Dictionary = {}
var carved: Dictionary = {}
var covered: Dictionary = {}
var transitions: Array[Dictionary] = []
var portals: Array[Vector3i] = []
var last_rejection := ""
var _sealed := false


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


func seal() -> bool:
	## Mirrors WarrenMassif.seal(): "sealed" names an invariant that was
	## actually checked, not a convention. A walk that teleports, folds back
	## onto a cell it already occupies, or claims headroom it never removed
	## must fail here rather than reach a consumer as a plausible street.
	if route.size() < 2:
		last_rejection = "a route of %d cells is not a walk" % route.size()
		return false
	if carved.is_empty():
		last_rejection = "nothing was removed"
		return false
	if portals.is_empty():
		last_rejection = "the route never opens to the exterior"
		return false
	var seen: Dictionary = {}
	for cell: Vector3i in route:
		if seen.has(cell):
			last_rejection = "route revisits %s" % cell
			return false
		seen[cell] = true
		for band in range(cell.y, cell.y + HEADROOM_BANDS):
			if not carved.has(Vector3i(cell.x, band, cell.z)):
				last_rejection = "walk cell %s lacks headroom band %d" \
					% [cell, band]
				return false
	for index in range(1, route.size()):
		var step := route[index] - route[index - 1]
		if absi(step.x) + absi(step.z) != 1 or absi(step.y) > 1:
			last_rejection = "route teleports from %s to %s" \
				% [route[index - 1], route[index]]
			return false
	if not _transitions_tile_the_route():
		return false
	if not _lanes_hang_off_the_public_realm(seen):
		return false
	# A town may open through either the primary itinerary or one of its sealed
	# public lanes. Validate portals only after lanes have joined `seen`; the old
	# route-only check made every secondary gate illegal by construction.
	for portal: Vector3i in portals:
		if not seen.has(portal):
			last_rejection = "portal %s is not on the public realm" % portal
			return false
	if not _loop_edges_close_the_public_graph(seen):
		return false
	if not _bridge_spans_are_legal(seen):
		return false
	_sealed = true
	return true


func _loop_edges_close_the_public_graph(public_cells: Dictionary) -> bool:
	var seen_edges: Dictionary = {}
	for index in loop_edges.size():
		var edge := loop_edges[index]
		var from_cell := edge.get("from", Vector3i(2147483647, 0, 0)) \
			as Vector3i
		var to_cell := edge.get("to", Vector3i(2147483647, 0, 0)) \
			as Vector3i
		if not public_cells.has(from_cell) or not public_cells.has(to_cell):
			last_rejection = "loop edge %d names a non-public endpoint" % index
			return false
		var delta := to_cell - from_cell
		if delta.y != 0 or absi(delta.x) + absi(delta.z) != 1:
			last_rejection = "loop edge %d is not one level cardinal seam" % index
			return false
		if int(edge.get("kind", -1)) != WarrenVolumeTransition.Kind.LEVEL:
			last_rejection = "loop edge %d has a non-level seam kind" % index
			return false
		var left := from_cell if _cell_less(from_cell, to_cell) else to_cell
		var right := to_cell if left == from_cell else from_cell
		var key := "%d:%d:%d>%d:%d:%d" % [left.x, left.y, left.z,
			right.x, right.y, right.z]
		if seen_edges.has(key):
			last_rejection = "duplicate loop edge %s" % key
			return false
		seen_edges[key] = true
	return true


func _bridge_spans_are_legal(public_cells: Dictionary) -> bool:
	## A bridge span retains the overhead mass a would-be-open street cell
	## would otherwise lose, so a consumer can build an inhabited bridge-house
	## across it.
	## Each entry must be a genuine slice of already-walked public realm: a
	## contiguous, level run of cells the route or a lane actually carved, and
	## one `_finalize_excavation` in turn marked covered -- never an
	## independent claim the carver invented after the fact.
	##
	## Re-derive each span cell's travel direction from the final walk and read
	## both flank intervals back as diagnostics. Flank walls are optional in the
	## retained-roof form: the covered central roof is the bearing fact, while a
	## hollow flank becomes a deliberate daylight opening rather than invalidating
	## the span.
	var seeded := bridge_span_audit.get("seeded", []) as Array
	if not bridge_span_audit.is_empty() and seeded.size() != bridge_spans.size():
		last_rejection = "bridge proof ledger has %d seeded records for %d spans" \
			% [seeded.size(), bridge_spans.size()]
		return false
	for index in bridge_spans.size():
		var span := bridge_spans[index] as Array[Vector3i]
		if span.is_empty():
			last_rejection = "bridge span %d has no cells" % index
			return false
		for cell_index in span.size():
			var cell := span[cell_index]
			if not public_cells.has(cell):
				last_rejection = "bridge span %d cell %s is not public realm" \
					% [index, cell]
				return false
			if not bool(covered.get(cell, false)):
				last_rejection = "bridge span %d cell %s is not covered" \
					% [index, cell]
				return false
			if cell_index > 0:
				var delta := cell - span[cell_index - 1]
				if delta.y != 0 or absi(delta.x) + absi(delta.z) != 1:
					last_rejection = "bridge span %d is not contiguous at %s" \
						% [index, cell]
					return false
			var direction := _bridge_span_direction(cell)
			if direction == Vector2i.ZERO:
				last_rejection = "bridge span %d cell %s has no walk direction " \
					% [index, cell] + "to derive a flank from"
				return false
			var perpendicular := Vector2i(-direction.y, direction.x)
			var column := Vector2i(cell.x, cell.z)
			var roof_band := cell.y + HEADROOM_BANDS
			for flank: Vector2i in [column + perpendicular, column - perpendicular]:
				var solid_flank := true
				for band in range(cell.y, roof_band + 1):
					if not carved.has(Vector3i(flank.x, band, flank.y)):
						continue
					solid_flank = false
					break
				# Deliberately diagnostic only: a zero-flank span is the most open
				# bridge form, while a solid flank may become an occupied neighbour.
		if not seeded.is_empty():
			var proof := seeded[index] as Dictionary
			var proved_cells := proof.get("cells", []) as Array
			if proved_cells.size() != span.size():
				last_rejection = "bridge span %d proof cell count differs" % index
				return false
			for cell: Vector3i in span:
				if not proved_cells.has(cell):
					last_rejection = "bridge span %d proof omits %s" % [index, cell]
					return false
			var groups := proof.get("endpoint_groups", []) as Array
			if groups.size() != 2:
				last_rejection = "bridge span %d has no two endpoint groups" % index
				return false
			var endpoint_seen: Dictionary = {}
			for group_value: Variant in groups:
				var group := group_value as Array
				if group.size() != span.size():
					last_rejection = ("bridge span %d endpoint group has %d " \
						+ "columns, expected %d") % [index, group.size(),
						span.size()]
					return false
				for column_value: Variant in group:
					var endpoint := column_value as Vector2i
					if endpoint_seen.has(endpoint):
						last_rejection = "bridge span %d repeats endpoint %s" % [
							index, endpoint]
						return false
					endpoint_seen[endpoint] = true
					var adjacent := false
					for span_cell: Vector3i in span:
						adjacent = adjacent or absi(endpoint.x - span_cell.x) \
							+ absi(endpoint.y - span_cell.z) == 1
					if not adjacent:
						last_rejection = ("bridge span %d endpoint %s is not " \
							+ "adjacent to its span") % [index, endpoint]
						return false
	return true


func _bridge_span_direction(cell: Vector3i) -> Vector2i:
	## The unit travel direction a bridge cell was reached by, re-derived from
	## the walk itself (route, or an `[anchor] + lane.cells` walk) rather than
	## trusted from carve-time bookkeeping -- this is exactly the datum the
	## flank re-check above needs and seal() has no other way to reconstruct
	## without a massif reference.
	var route_index := route.find(cell)
	if route_index > 0:
		var previous := route[route_index - 1]
		return Vector2i(cell.x - previous.x, cell.z - previous.z)
	for lane: Dictionary in lanes:
		var walk: Array[Vector3i] = [lane.get("anchor", Vector3i.ZERO) as Vector3i]
		walk.append_array(lane.get("cells", []) as Array[Vector3i])
		var lane_index := walk.find(cell)
		if lane_index > 0:
			var previous := walk[lane_index - 1]
			return Vector2i(cell.x - previous.x, cell.z - previous.z)
	return Vector2i.ZERO


func _lanes_hang_off_the_public_realm(seen: Dictionary) -> bool:
	## A lane is public realm, so it is held to the route's own contract: it
	## walks without teleporting, it owns the headroom it claims, its
	## transitions tile it exactly, and no cell of it is a second claim on
	## ground the route or an earlier lane already took.
	##
	## The one rule that is a lane's alone is the anchor: a lane must start from
	## a transition endpoint that already exists when it is declared, so the
	## whole graph is reachable from the route's mouth by construction. A stride
	## intermediate is public floor, but its transition already owns that column's
	## surface and it therefore cannot become a second walk node or lane junction.
	## WarrenVolumePlan._all_walk_connected() rejects the entire town for an
	## orphan alley one stage later, and it names only the symptom.
	var walk_nodes: Dictionary = {route[0]: true}
	for transition: Dictionary in transitions:
		walk_nodes[transition["to"] as Vector3i] = true
	for index in lanes.size():
		var lane := lanes[index]
		var anchor := lane["anchor"] as Vector3i
		if not walk_nodes.has(anchor):
			last_rejection = "lane %d is anchored at %s, which is not a walk " \
				% [index, anchor] + "node the route or an earlier lane reaches"
			return false
		var cells := lane["cells"] as Array[Vector3i]
		if cells.is_empty():
			last_rejection = "lane %d has no cells" % index
			return false
		var walk: Array[Vector3i] = [anchor]
		walk.append_array(cells)
		for cell: Vector3i in cells:
			if seen.has(cell):
				last_rejection = "lane %d revisits public realm at %s" \
					% [index, cell]
				return false
			seen[cell] = true
			for band in range(cell.y, cell.y + HEADROOM_BANDS):
				if not carved.has(Vector3i(cell.x, band, cell.z)):
					last_rejection = "lane cell %s lacks headroom band %d" \
						% [cell, band]
					return false
		for step_index in range(1, walk.size()):
			var step := walk[step_index] - walk[step_index - 1]
			if absi(step.x) + absi(step.z) != 1 or absi(step.y) > 1:
				last_rejection = "lane %d teleports from %s to %s" \
					% [index, walk[step_index - 1], walk[step_index]]
				return false
		if not _transitions_tile(walk, lane["transitions"] as Array[Dictionary],
				"lane %d" % index):
			return false
		for transition: Dictionary in lane["transitions"] as Array[Dictionary]:
			walk_nodes[transition["to"] as Vector3i] = true
	return true


func _transitions_tile_the_route() -> bool:
	## The transitions must decompose the walk exactly: consecutive, gapless,
	## first starting at the route's mouth and last ending at its terminus,
	## with every span a rise/run that its own Kind actually permits.
	##
	## This is the excavation's half of a contract WarrenVolumeTransition
	## enforces on the other side. If a span here were, say, a one-cell rise,
	## the adapter that builds the real transition would have to invent a
	## route cell to stretch it over -- and the carved void would then
	## disagree with the sealed plan about where the stair is.
	return _transitions_tile(route, transitions, "route")


func _transitions_tile(walk: Array[Vector3i], specs: Array[Dictionary],
		label: String) -> bool:
	## One tiling rule for every walk in the excavation. Lanes are held to the
	## same contract as the route because the adapter builds them into the same
	## WarrenVolumeTransition vocabulary; a lane allowed a one-cell rise would
	## reach the plan as no Kind at all.
	var cursor := 0
	for index in specs.size():
		var spec := specs[index]
		var from_cell := spec["from"] as Vector3i
		var to_cell := spec["to"] as Vector3i
		if from_cell != walk[cursor]:
			last_rejection = "%s transition %d starts at %s, walk is at %s" \
				% [label, index, from_cell, walk[cursor]]
			return false
		var delta := to_cell - from_cell
		var run := absi(delta.x) + absi(delta.z)
		if cursor + run > walk.size() - 1 or walk[cursor + run] != to_cell:
			last_rejection = "%s transition %d to %s does not land on the walk" \
				% [label, index, to_cell]
			return false
		if not kind_allows(int(spec["kind"]), absi(delta.y), run):
			last_rejection = "%s transition %d is a rise of %d over a run of " \
				% [label, index, absi(delta.y)] + "%d, which kind %d forbids" \
				% [run, int(spec["kind"])]
			return false
		cursor += run
	if cursor != walk.size() - 1:
		last_rejection = "%s transitions cover %d of %d walk cells" \
			% [label, cursor + 1, walk.size()]
		return false
	return true


static func kind_allows(kind: int, rise: int, run: int) -> bool:
	## The rise/run each WarrenVolumeTransition.Kind accepts, mirroring that
	## class's own seal(). Kept here so the excavation can refuse to emit a
	## span no transition could ever be built from, without depending on a
	## transition instance to find out.
	match kind:
		WarrenVolumeTransition.Kind.LEVEL:
			return rise == 0 and run == 1
		WarrenVolumeTransition.Kind.STAIR:
			return rise == 1 and run == 2
		WarrenVolumeTransition.Kind.RAMP:
			return rise == 1 and run >= 3
	return false


func is_sealed() -> bool:
	return _sealed


func lane_cells() -> Array[Vector3i]:
	## Every cell of every lane, in lane then walk order. Anchors are excluded:
	## an anchor belongs to whatever public realm the lane hangs off, and
	## counting it here would double-count a route cell as a lane cell.
	var out: Array[Vector3i] = []
	for lane: Dictionary in lanes:
		out.append_array(lane["cells"] as Array[Vector3i])
	return out


func public_cells() -> Array[Vector3i]:
	## The whole street network -- route then lanes -- which is what "a street"
	## means to street-wall ownership, addressing and the surface stages. Every
	## consumer that asks "is there a street beside this column" must ask this
	## rather than `route`, or a lane's flank goes unowned and unhoused.
	var out: Array[Vector3i] = []
	out.append_array(route)
	out.append_array(lane_cells())
	return out


func covered_ratio() -> float:
	if route.is_empty():
		return 0.0
	var count := 0
	for cell: Vector3i in route:
		count += int(bool(covered.get(cell, false)))
	return float(count) / float(route.size())


func route_span_bands() -> int:
	var low := 1 << 30
	var high := -(1 << 30)
	for cell: Vector3i in route:
		low = mini(low, cell.y)
		high = maxi(high, cell.y)
	return high - low


func slot_bands(cell: Vector3i) -> int:
	## Height of the void actually removed above this walk cell, read back off
	## `carved` rather than assumed. Not every cell is HEADROOM_BANDS tall: a
	## stair's intermediate cell carries both treads, so it is one band
	## taller, and anything reasoning about what is left overhead has to ask
	## rather than assume.
	var count := 0
	while carved.has(Vector3i(cell.x, cell.y + count, cell.z)):
		count += 1
	return count


func headroom_slot(cell: Vector3i) -> Array[Vector3i]:
	## The NOMINAL bore slot above one walk cell: HEADROOM_BANDS tall, the
	## convention every consumer that reserves headroom shares rather than
	## re-deriving one of its own.
	##
	## It is NOT the truth for any specific cell (review finding 2026-08-23,
	## minor): since the open-to-sky policy a street's real slot runs to the
	## envelope, and a stair's intermediate cell carries both treads, so both
	## are taller than this. `carved` -- read through `slot_bands` -- is what
	## a cell really lost; ask that whenever the answer has to be exact.
	var out: Array[Vector3i] = []
	for band in range(cell.y, cell.y + HEADROOM_BANDS):
		out.append(Vector3i(cell.x, band, cell.z))
	return out


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
