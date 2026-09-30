class_name WarrenMassif
extends RefCounted

## Terraced solid city mass: per-column occupiable band interval. The public
## realm is carved FROM this object; it never grows to meet a route.
##
## Validation requires a connected footprint and rejects undeclared holes.
## Intentional open courts are source geometry, declared before route carving.

## Inhabited bands a terrace carries: MAX_TERRACE_STOREYS storeys plus one
## roof reservation, in WarrenBuildingParcel's units. Written out rather than
## imported so this class stays free of the parcel vocabulary; a test pins the
## arithmetic so the two cannot drift.
##
## The massif is now the complete inhabited construction envelope, grounded on
## the real terrain.  Eight storeys at the crown are enough to make a compact
## town read as a mountain while still fitting StaggeredFabricCompiler's finite
## stack vocabulary.  The final two bands are the explicit roof reservation.
## Nothing below this interval is a hidden stone substrate: bearing_at() is the
## sampled terrain on every column.
const MAX_TERRACE_STOREYS := 8
const BUILDABLE_LAYER_BANDS := 18

## Bands of continuous mass a street cell needs beside it before the plan calls
## it ADDRESSED, for towns cut from this class. Route-first keeps
## WarrenVolumePlan.MIN_ADDRESS_BUILDING_BANDS unchanged at six; the envelope
## carries the number so the two modes cannot drift and neither has to know
## about the other (WarrenVolumeEnvelope.address_bands).
##
## Six continuous bands beside a street prove that its wall belongs to a real
## two-storey-plus-roof building.  The restored deep envelope can satisfy this
## original standard even while the public route climbs through it.
const ADDRESS_BANDS := 6

## At least two ground-arcade cells must pass beneath the climbing itinerary.
## This makes overhead streets a plan fact instead of an optional decoration.
const UPPER_ROUTE_CROSSOVERS := 2

## Bands of stone a house cut from this class may stand on, carried to the
## parcel stage as WarrenVolumeEnvelope.plinth_budget_bands. Route-first keeps
## the field at zero and is byte-identical.
##
## ONE STOREY, which is the reviewer's own unit for this: "stone should only be
## used sparingly to make a house one storey taller" (ledger line 182), softened
## at line 191 to "sparing visible stone is fine where purposeful". A storey is
## WarrenBuildingParcel.STOREY_BANDS = 2 bands, so two is the whole allowance and
## a taller step is not a plinth but the masonry terrace-farm rounds 2-3
## rejected.
##
## WHAT IT BUYS, measured. A house's stack has to meet its address on a whole
## STOREY_BANDS boundary. With no budget the only way to make the arithmetic
## work is to drop the support one band BELOW the ground the house stands on --
## which is where 211 of 424 mass-first houses were found buried exactly one
## band, against zero plinths and only five footprints straddling a real step
## (task-23-report §4). The parity is a fact about the address, not about the
## hill, and the honest place to spend it is a course of stone under the house
## rather than a storey of it underground.
const PLINTH_BUDGET_BANDS := WarrenBuildingParcel.STOREY_BANDS

var world_seed: int
var columns: Dictionary = {}
var core_top_bands: int = 0
var form_id: StringName = &"hill"
## Intentional open ground, authored before streets and plots. This is distinct
## from an accidental missing construction column.
var open_court: Dictionary = {}
## The column the town field designed as its crown (its tallest lobe's
## centre). The spine climbs toward it.
var crown_column := Vector2i.ZERO
## Plinth height of the town's raised district (WarrenTownPlatform) in bands,
## zero when the town has none. Per-column membership is the column record's
## "plinth" entry; `bearing_at` is the one reader downstream stages use.
var platform_bands: int = 0
var last_rejection := ""
var _sealed := false
## September 29 town review (edges): the outermost GRADE_RINGS rings of the
## footprint are ground-level territory. Optional streets (alleys, loops, the
## spine's descent) are never bored above a column's ground there
## (`WarrenPassageLatticeRules.raises_edge`), so the edge is at-grade lanes and
## single-storey houses on the lawn, not raised streets whose houses stand on
## a storey of retaining rock.
const GRADE_RINGS := 2
var _ring_depths: Dictionary = {}


func _init(p_world_seed: int) -> void:
	world_seed = p_world_seed


static func with_columns(p_world_seed: int, p_columns: Dictionary,
		p_core_top_bands: int) -> WarrenMassif:
	## Factory for a massif built from already-decided column bands (an edited
	## copy of a sealed massif, e.g.) rather than from the Gaussian builder.
	## Still just data until the caller calls seal() -- this never seals on
	## its own, so a caller that forgets to seal gets the same unsealed-object
	## contract as `WarrenMassif.new(...)` followed by manual field writes.
	var massif := WarrenMassif.new(p_world_seed)
	massif.columns = p_columns
	massif.core_top_bands = p_core_top_bands
	return massif


func seal() -> bool:
	if not validate_construction():
		return false
	return finish_construction()


func finish_construction() -> bool:
	## Production freezes the already-authored field without a quality gate.
	_sealed = true
	return true


func validate_construction() -> bool:
	## Read-only connectivity inspection for tests and edited review fixtures.
	if columns.is_empty():
		last_rejection = "empty massif"
		return false
	if not _is_single_component():
		last_rejection = "footprint is not a single connected component"
		return false
	for column: Vector2i in open_court:
		if columns.has(column):
			last_rejection = "court overlaps construction at %s" % column
			return false
	var hole: Variant = _find_interior_hole(true)
	if hole != null:
		last_rejection = "interior hole at column %s" % str(hole)
		return false
	return true


func is_sealed() -> bool:
	return _sealed


func has_column(column: Vector2i) -> bool:
	return columns.has(column)


func ring_depth(column: Vector2i) -> int:
	## Rings from the footprint boundary: 1 for a column with a cardinal
	## neighbour outside the massif, 0 outside it. Cached once sealed.
	if not columns.has(column):
		return 0
	if _ring_depths.is_empty() or not _sealed:
		var depths := _compute_ring_depths()
		if not _sealed:
			return int(depths.get(column, 0))
		_ring_depths = depths
	return int(_ring_depths.get(column, 0))


func _compute_ring_depths() -> Dictionary:
	var depth: Dictionary = {}
	var frontier: Array[Vector2i] = []
	var order: Array[Vector2i] = []
	order.assign(columns.keys())
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for column: Vector2i in order:
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
				Vector2i.DOWN]:
			if not columns.has(column + direction):
				depth[column] = 1
				frontier.append(column)
				break
	var index := 0
	while index < frontier.size():
		var column: Vector2i = frontier[index]
		index += 1
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
				Vector2i.DOWN]:
			var next := column + direction
			if columns.has(next) and not depth.has(next):
				depth[next] = int(depth[column]) + 1
				frontier.append(next)
	return depth


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
	## The whole envelope is inhabitable construction.  Houses descend to the
	## sampled terrain rather than stopping on an abstract terrace, so a tall
	## centre becomes stacked rooms and roofs instead of a stone podium.
	## The one exception is the town's raised district: there houses stand on
	## the platform's rock plinth, `plinth_at` bands above the ground.
	return base_at(column) + plinth_at(column)


func plinth_at(column: Vector2i) -> int:
	## Bands of platform rock under the raised district; zero elsewhere.
	return int((columns.get(column, {}) as Dictionary).get("plinth", 0))


func is_platform(column: Vector2i) -> bool:
	return plinth_at(column) > 0


func platform_rim_depth(column: Vector2i) -> int:
	## Rings in from the district's rim: 1 on an edge column, 2 just inside;
	## 0 off the platform. Chebyshev, so a corner's diagonal neighbour is 2.
	if not is_platform(column):
		return 0
	for ring in range(1, 64):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) == ring and ring > 0 \
						and not is_platform(column + Vector2i(dx, dz)) \
						and (ring > 1 or dx == 0 or dz == 0):
					return ring
	return 64


func is_platform_edge(column: Vector2i) -> bool:
	## A platform column on the district's rim (a cardinal neighbour is not
	## raised): its plinth face is the retaining wall.
	if not is_platform(column):
		return false
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP,
			Vector2i.DOWN]:
		if not is_platform(column + direction):
			return true
	return false


func platform_columns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for column: Vector2i in columns:
		if plinth_at(column) > 0:
			out.append(column)
	out.sort()
	return out


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


func _find_interior_hole(exclude_declared_court: bool = false) -> Variant:
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
			if exclude_declared_court and open_court.has(cell):
				continue
			return cell
	return null
