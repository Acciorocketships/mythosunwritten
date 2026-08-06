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
	for portal: Vector3i in portals:
		if not seen.has(portal):
			last_rejection = "portal %s is not on the route" % portal
			return false
	if not _transitions_tile_the_route():
		return false
	_sealed = true
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
	var cursor := 0
	for index in transitions.size():
		var spec := transitions[index]
		var from_cell := spec["from"] as Vector3i
		var to_cell := spec["to"] as Vector3i
		if from_cell != route[cursor]:
			last_rejection = "transition %d starts at %s, walk is at %s" \
				% [index, from_cell, route[cursor]]
			return false
		var delta := to_cell - from_cell
		var run := absi(delta.x) + absi(delta.z)
		if cursor + run > route.size() - 1 or route[cursor + run] != to_cell:
			last_rejection = "transition %d to %s does not land on the walk" \
				% [index, to_cell]
			return false
		if not kind_allows(int(spec["kind"]), absi(delta.y), run):
			last_rejection = "transition %d is a rise of %d over a run of " \
				% [index, absi(delta.y)] + "%d, which kind %d forbids" \
				% [run, int(spec["kind"])]
			return false
		cursor += run
	if cursor != route.size() - 1:
		last_rejection = "transitions cover %d of %d walk cells" \
			% [cursor + 1, route.size()]
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
	## The exact cells one walk cell removes. Consumers that rebuild the
	## solid (parcelling, meshing) need this to agree with `carved` exactly
	## rather than each re-deriving a headroom convention of their own.
	var out: Array[Vector3i] = []
	for band in range(cell.y, cell.y + HEADROOM_BANDS):
		out.append(Vector3i(cell.x, band, cell.z))
	return out
