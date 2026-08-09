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
## TWO STOREYS SINCE THE BUILDABLE-LAYER WAVE, not three. The massif no longer
## owns the mountain -- SettlementReliefPlan stamps it into the heightfield and
## the terrain meshes, dresses and collides it -- so this constant stopped being
## "how far down a house may reach into the hill" and became the WHOLE thickness
## of the authored layer (design §3.4). The reviewer's rule is 2-3 visible
## storeys of composed face; at three storeys plus a roof the layer alone
## already spends the whole allowance and leaves nothing for the terrain step
## the house stands on, so the layer takes two and the third storey of apparent
## height is the hill itself.
const MAX_TERRACE_STOREYS := 2
const BUILDABLE_LAYER_BANDS := 6

## Bands of continuous mass a street cell needs beside it before the plan calls
## it ADDRESSED, for towns cut from this class. Route-first keeps
## WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS unchanged at six; the envelope
## carries the number so the two modes cannot drift and neither has to know
## about the other (WarrenVolumeEnvelope.address_bands).
##
## WHY IT IS NOT SIX HERE, derived rather than preferred. A walk cell needs
## WarrenExcavation.HEADROOM_BANDS of void inside its own column, so a route
## floor may stand up to `BUILDABLE_LAYER_BANDS - HEADROOM_BANDS` = 3 bands
## above its own ground. The flank beside it then offers at most
## `BUILDABLE_LAYER_BANDS - 3` = 3 bands, so a six-band frontage demands that
## the street NEVER leave grade -- and the stamped hill's terrace risers are 2-3
## bands, which no move in the carver's vocabulary crosses without leaving
## grade. Six is therefore not a stricter bar at this geometry, it is one no
## bore can meet anywhere except on a bench.
##
## Four is the parcel transaction's OWN floor for a sealable house
## (WarrenBuildingParcel.seal refuses anything under
## STOREY_BANDS + ROOF_RESERVATION_BANDS), so the property the gate states --
## "a real building fronts this street, not a kerb" -- survives intact. What is
## given up is the second storey OF THE HOUSE, and the trade is the milestone's
## whole thesis: the terrace riser the house stands on is now real terrain, and
## it is what the composed face gains the storey back from.
const ADDRESS_BANDS := 4

## Ground-arcade cells that must run under the climbing route for a town cut
## from this class. Route-first keeps
## WarrenVolumeEnvelope.DEFAULT_UPPER_ROUTE_CROSSOVERS at two.
##
## The property is unchanged -- "one public level is the roof of another, and
## the vertical sightline is split" -- and so is the geometry it is measured
## against; what changed is how much of that geometry exists. An arcade cell
## sitting on ground band g is crossed by a route cell in the same column at
## `y >= g + WarrenVolumePlan.HEADROOM_BANDS`, and that route cell needs
## `WarrenExcavation.HEADROOM_BANDS` of void inside a column whose top is
## `g + BUILDABLE_LAYER_BANDS`, so
##
##   y in [g + 2, g + BUILDABLE_LAYER_BANDS - 3] = [g + 2, g + 3]
##
## -- a TWO BAND window. Against a 16-20 band massif the same window was eight
## to fourteen bands wide and crossings were routine. Measured over twelve
## stamped-hill seeds the arcade achieves 0 or 1 crossings and never 2, so two
## is not a stricter bar at this geometry but an unreachable one. One still
## refuses the "branch which merely wanders beside the main route" the solver's
## own constant was written against, and a town with no crossing at all still
## fails.
const UPPER_ROUTE_CROSSOVERS := 1

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


func relief_bands() -> int:
	## Bands of GROUND relief the terrain handed in under the footprint. Zero on
	## a flat frame; on a stamped site it is the settlement relief stamp read
	## back through VillageWarrenFabricSolver._sample_ground_bands.
	if columns.is_empty():
		return 0
	var lowest := 2147483647
	var highest := -2147483648
	for column: Vector2i in columns:
		lowest = mini(lowest, base_at(column))
		highest = maxi(highest, base_at(column))
	return highest - lowest


func vertical_development_bands() -> int:
	## The town's whole silhouette: lowest ground under the footprint to highest
	## roof band above it. This is what "the town has N bands of vertical
	## development" always MEANT; while the massif owned the mountain the single
	## column's own height was an exact proxy for it, and now that the terrain
	## owns everything below the layer it is not (design §3.1). Equal to
	## `relief_bands() + core layer` whenever the layer peaks over the ground's
	## peak, which the two coincident bell profiles make the ordinary case, and
	## strictly correct when they do not.
	if columns.is_empty():
		return 0
	var lowest := 2147483647
	var highest := -2147483648
	for column: Vector2i in columns:
		lowest = mini(lowest, base_at(column))
		highest = maxi(highest, top_at(column))
	return highest - lowest


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
	## DEGENERATE SINCE THE BUILDABLE-LAYER WAVE, deliberately. The second datum
	## was invented to name "the mass between natural ground and where houses
	## stop descending"; the terrain owns that mass now, and every column's whole
	## layer fits inside BUILDABLE_LAYER_BANDS by construction, so this returns
	## `base_at` for every column a builder produces. The method survives because
	## the excavation envelope copies it and the accessor is shared -- deleting it
	## mid-milestone would churn four suites to remove an identity (design §3.4).
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
