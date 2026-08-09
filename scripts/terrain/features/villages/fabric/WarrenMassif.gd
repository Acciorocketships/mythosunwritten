class_name WarrenMassif
extends RefCounted

## Terraced solid city mass: per-column occupiable band interval. The public
## realm is carved FROM this object; it never grows to meet a route.
##
## "Solid" is an invariant seal() actually checks, not just a naming
## convention: a builder bug that fragments the footprint (see
## WarrenMassifBuilder's fix-round-1 history) must fail here, not silently
## pass through as a solid mass with holes in it.

## Inhabited bands a terrace carries: MAX_TERRACE_STOREYS storeys plus one
## roof reservation, in WarrenBuildingParcel's units. Written out rather than
## imported so this class stays free of the parcel vocabulary; a test pins the
## arithmetic so the two cannot drift.
##
## It is what makes `bearing_at` a cap on built height: a house rooted at the
## terrace and topping out at the massif top spans exactly this many bands.
const MAX_TERRACE_STOREYS := 3
const BUILDABLE_LAYER_BANDS := 8

var world_seed: int
var columns: Dictionary = {}
var core_top_bands: int = 0
var last_rejection := ""
var _sealed := false


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


func seal() -> bool:
	if columns.is_empty():
		last_rejection = "empty massif"
		return false
	if not _is_single_component():
		last_rejection = "footprint is not a single connected component"
		return false
	var hole: Variant = _find_interior_hole()
	if hole != null:
		last_rejection = "interior hole at column %s" % str(hole)
		return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_column(column: Vector2i) -> bool:
	return columns.has(column)


func top_at(column: Vector2i) -> int:
	return int((columns.get(column, {}) as Dictionary).get("top", 0))


func base_at(column: Vector2i) -> int:
	return int((columns.get(column, {}) as Dictionary).get("base", 0))


func layer_at(column: Vector2i) -> int:
	## Bands of MASSIF above this column's own input ground -- the only part of
	## the solid this class authored. Every shape gate scores this rather than
	## `top_at`, because `top_at` also carries whatever relief the terrain
	## handed in through `ground_bands`, and charging the builder for the
	## landscape is what made a smooth slope read as a 12-14 cell plateau and a
	## terrace riser read as an 8-band cliff (terrain audit, ledger line 208).
	##
	## The invariance this buys: a constant-thickness buildable layer draped
	## over any ground whatsoever is gate-neutral, so flat, sloped and terraced
	## input produce identical verdicts. On flat input `layer_at == top_at`, so
	## nothing about the pinned flat corpus moves.
	return top_at(column) - base_at(column)


func bearing_at(column: Vector2i) -> int:
	## The terrace a house standing on this column rests on -- a SECOND datum,
	## deliberately distinct from `base_at`.
	##
	## `base_at` is natural ground, and every street, address, arcade and cover
	## rule keeps measuring mass from it, so a street stays flanked by real
	## inhabited height. `bearing_at` is only where an inhabited stack STOPS
	## descending. The mass between the two is hill: unbuilt solid the fabric
	## renders as retained stone rather than as more storeys of house.
	##
	## Never above the massif top and never below natural ground, so a column
	## whose whole span already fits inside the buildable layer is untouched
	## and its houses descend exactly as they always did.
	return maxi(base_at(column), top_at(column) - BUILDABLE_LAYER_BANDS)


func terrace_levels() -> Array[int]:
	## Distinct LAYER thicknesses, so the >=MIN_TERRACE_LEVELS gate measures how
	## articulated the built mass is. Counting distinct absolute tops passed
	## vacuously on relief: every band the ground itself stepped through
	## registered as another terrace the builder never authored.
	var seen: Dictionary = {}
	for column: Vector2i in columns:
		seen[layer_at(column)] = true
	var out: Array[int] = []
	out.assign(seen.keys())
	out.sort()
	return out


func widest_plateau_cells() -> int:
	## Largest 4-connected component sharing one LAYER thickness. Grouping by
	## absolute top instead makes a constant-thickness layer on a ramp -- where
	## the base rises exactly as the terrace falls -- read as one huge plateau,
	## which is the audit's observed 12-14 cell plateau on a slope.
	var visited: Dictionary = {}
	var widest := 0
	for start_value: Variant in columns.keys():
		var start := start_value as Vector2i
		if visited.has(start):
			continue
		var level := layer_at(start)
		var frontier: Array[Vector2i] = [start]
		var count := 0
		visited[start] = true
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			count += 1
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := cell + direction
				if visited.has(neighbor) or not columns.has(neighbor) \
						or layer_at(neighbor) != level:
					continue
				visited[neighbor] = true
				frontier.append(neighbor)
		widest = maxi(widest, count)
	return widest


func _is_single_component() -> bool:
	## Flood fill on existence alone (ignoring top band), mirroring the
	## sibling WarrenVolumeEnvelope._seal() convention of validating the
	## solid's continuity before sealing.
	var keys: Array = columns.keys()
	if keys.is_empty():
		return true
	var start := keys[0] as Vector2i
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	visited[start] = true
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + direction
			if visited.has(neighbor) or not columns.has(neighbor):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return visited.size() == columns.size()


func _find_interior_hole() -> Variant:
	## A pocket of missing columns that is unreachable from outside the
	## footprint: not the natural boundary taper, but a puncture through the
	## middle of the solid, of ANY size or shape. A 4-neighbour-presence
	## heuristic here only ever catches a puncture that is exactly one cell
	## wide -- a 2-or-more-cell void has at least one interior cell whose
	## neighbour is another missing cell, so that heuristic misses it
	## entirely. Detected instead by flood-filling the empty space starting
	## one cell outside the bounding box (a cell that is empty by
	## construction, since it lies past every column's min/max): whatever
	## empty cell inside the box that fill never reaches is enclosed.
	## Returns the first such column found, or null if there is none.
	if columns.is_empty():
		return null
	var min_x := 2147483647
	var max_x := -2147483648
	var min_z := 2147483647
	var max_z := -2147483648
	for column: Vector2i in columns:
		min_x = mini(min_x, column.x)
		max_x = maxi(max_x, column.x)
		min_z = mini(min_z, column.y)
		max_z = maxi(max_z, column.y)
	var outer_min_x := min_x - 1
	var outer_max_x := max_x + 1
	var outer_min_z := min_z - 1
	var outer_max_z := max_z + 1

	var reached_from_outside: Dictionary = {}
	var start := Vector2i(outer_min_x, outer_min_z)
	reached_from_outside[start] = true
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + direction
			if neighbor.x < outer_min_x or neighbor.x > outer_max_x \
					or neighbor.y < outer_min_z or neighbor.y > outer_max_z:
				continue
			if reached_from_outside.has(neighbor) or columns.has(neighbor):
				continue
			reached_from_outside[neighbor] = true
			frontier.append(neighbor)

	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, z)
			if columns.has(cell) or reached_from_outside.has(cell):
				continue
			return cell
	return null
