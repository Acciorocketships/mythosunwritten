class_name WarrenTownPlatform
extends RefCounted

## The raised district of a multi-level town (September 29 town review,
## owner: "some parts of the city can be raised on top of a rock platform ...
## parts of the city can be almost like a castle").
##
## A platform is a component of the town FIELD, sampled with the lobes and
## clearings before any street is bored: a deterministic subset of towns
## raise a rounded-rectangle region around the crown lobe on a solid rock
## plinth two storeys high. The massif carries it as a second datum,
## `WarrenMassif.bearing_at` = ground + plinth. Everything downstream reads
## that datum rather than knowing about platforms:
##
## * the plot layer never founds a house below it (`plot_support_ok`), so the
##   plinth stays the derived rock under the upper town;
## * the sealed rock shoulder never steps below it, so the plinth is closed
##   even where the lower town beside it is low;
## * the plinth is never bored; the lower town within HUDDLE_RINGS stays
##   under its top (`huddle_top`: envelope, plot joins, roof rolls, prefabs),
##   and a gate flight climbs along the wall into the district
##   (`WarrenPlatformStreets`);
## * the kit builds the plinth as a fortification (`KitVillageBuildings`,
##   `BuildingKitAssembler._assemble_fortified`): plain coursed stone,
##   crenellated parapet (also the rim's fall guard, `parapet_guard_boxes`),
##   corner turrets and a stone gate.
##
## Pure and resource-free; the same seed always raises the same platform.

## Share of towns that get a platform. Rolled from the city seed alone, so
## a town size never decides it; never every town.
const CHANCE := 0.6
## Plinth height in storeys (a storey is `WarrenBuildingParcel.STOREY_BANDS`).
## Two: the lowest plinth a one-storey house at its foot (a storey plus its
## roof reservation) does not overtop, so the lower town huddles under the
## citadel (HUDDLE_RINGS) and the district reads from a distance.
const PLINTH_STOREYS: Array[int] = [2]
## Rings of lower town (Chebyshev, around the platform) whose envelope and
## houses stay at or below the plinth top.
const HUDDLE_RINGS := 2
## Superellipse exponent of the platform outline: 2 is an ellipse, larger is
## a squarer, more fortified outline with rounded corners.
const SQUARENESS := 4.0
## Half extents, as a share of the crown lobe's own widths, and their floor
## in macro columns (a platform must hold at least a small square of houses).
const HALF_SHARE := Vector2(0.45, 0.7)
const MIN_HALF_CELLS := 1.75
## The platform stands inside the town: its columns are at least this many
## cardinal rings in from the massif boundary, so the low town (and the low
## outer rings of the edge profile) always wraps its foot.
const MIN_RING_DEPTH := 3
## A platform holds at least a three-by-three district of houses and lanes.
const MIN_COLUMNS := 9
## Extra Manhattan columns, beyond the market approach, between the town
## mouth and the plinth (room for the market square beside the approach).
const FORECOURT_MARGIN := -1
## Half-column slides the outline may make away from the town mouth.
const MAX_SLIDE_STEPS := 12
## Bands of envelope a platform column keeps above its plinth, so an upper
## street and a two-storey house on it both fit inside the massif.
const ABOVE_PLINTH_BANDS := WarrenMazeSourcePlan.MIN_HOUSE_BANDS \
	+ WarrenBuildingParcel.STOREY_BANDS
const CARDINALS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT,
	Vector2i.UP, Vector2i.DOWN]


static func sample(seed_value: int, crown: Dictionary,
		solid: Dictionary) -> Dictionary:
	## {} for a town without a platform, else {"bands": plinth bands,
	## "columns": {Vector2i: true}, "centre": Vector2, "half": Vector2}.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"town-platform"])
	if rng.randf() >= CHANCE:
		return {}
	var bands := PLINTH_STOREYS[rng.randi_range(0, PLINTH_STOREYS.size() - 1)] \
		* WarrenBuildingParcel.STOREY_BANDS
	var width := crown.width as Vector2
	var half := Vector2(
		maxf(MIN_HALF_CELLS, width.x * rng.randf_range(HALF_SHARE.x, HALF_SHARE.y)),
		maxf(MIN_HALF_CELLS, width.y * rng.randf_range(HALF_SHARE.x, HALF_SHARE.y)))
	var centre := crown.centre as Vector2
	var columns := region(centre, half, solid, ring_depths(solid))
	if columns.size() < MIN_COLUMNS:
		return {}
	return {"bands": bands, "columns": columns, "centre": centre, "half": half}


static func region(centre: Vector2, half: Vector2, solid: Dictionary,
		depth: Dictionary) -> Dictionary:
	## The platform outline (a squared superellipse) over the massif's deep
	## columns, largest connected piece.
	var inside: Dictionary = {}
	for column_value: Variant in solid.keys():
		var column := column_value as Vector2i
		if int(depth.get(column, 0)) < MIN_RING_DEPTH:
			continue
		var q := (Vector2(column) - centre) / half
		if pow(absf(q.x), SQUARENESS) + pow(absf(q.y), SQUARENESS) <= 1.0:
			inside[column] = true
	# Opened by a 3x3 square: every column belongs to a full three-by-three
	# block, so a lane with houses on both sides always fits (no one- or
	# two-column slivers of plinth).
	var opened: Dictionary = {}
	for column_value: Variant in inside.keys():
		var corner := column_value as Vector2i
		var whole := true
		for dz in 3:
			for dx in 3:
				whole = whole and inside.has(corner + Vector2i(dx, dz))
		if not whole:
			continue
		for dz in 3:
			for dx in 3:
				opened[corner + Vector2i(dx, dz)] = true
	return _largest_component(opened)


static func clear_forecourt(platform: Dictionary, massif: WarrenMassif,
		profile: WarrenVillageScaleProfile, world_seed: int) -> Dictionary:
	## The town mouth and its market square stand in the LOW town: the plinth
	## keeps its distance from the gate the carver will open (the mouth is a
	## boundary column, chosen before the platform is raised, and the plinth
	## never changes which one it is). While any platform column lies within
	## the market approach's Manhattan reach of the mouth, the whole outline
	## slides away from the mouth, so the district keeps its shape.
	if platform.is_empty():
		return platform
	var portal: Variant = WarrenMazeCarver.primary_portal(massif, profile,
		world_seed)
	if portal == null:
		return platform
	var mouth := Vector2i((portal as Vector3i).x, (portal as Vector3i).z)
	var reach := WarrenMazeCarver.market_cell_count(profile) + FORECOURT_MARGIN
	var solid := massif.columns
	var depth := ring_depths(solid)
	var centre := platform.centre as Vector2
	var away := (centre - Vector2(mouth)).normalized()
	var columns: Dictionary = platform.columns
	for step in MAX_SLIDE_STEPS:
		var clear := true
		for column: Vector2i in columns:
			if absi(column.x - mouth.x) + absi(column.y - mouth.y) <= reach:
				clear = false
				break
		if clear:
			break
		centre += away * 0.5
		columns = region(centre, platform.half as Vector2, solid, depth)
	for column: Vector2i in columns:
		if absi(column.x - mouth.x) + absi(column.y - mouth.y) <= reach:
			return {}
	var out := platform.duplicate()
	out["centre"] = centre
	out["columns"] = columns
	if columns.size() < MIN_COLUMNS: return {}
	out["tiers"] = nested_tiers(world_seed, out)
	return out


## Nested districts require two full columns of lower city around each wall.
## A separate seed stream chooses whether an eligible district rises again.
static func nested_tiers(seed_value: int, outer: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parent := outer
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"town-fortified-rings"])
	for index in 2:
		if rng.randf() >= 0.6: break
		var centre: Vector2 = parent.centre + Vector2(rng.randf_range(-0.5,0.5),rng.randf_range(-0.5,0.5))
		var half: Vector2 = parent.half * rng.randf_range(0.5,0.7)
		var columns := region(centre,half,parent.columns,ring_depths(parent.columns))
		if columns.size() < MIN_COLUMNS: break
		var tier := {"columns":columns,"centre":centre,"half":half,
			"bands":int(parent.bands)+2*WarrenBuildingParcel.STOREY_BANDS}
		out.append(tier)
		parent = tier
	return out


## The fortification's parapet: a solid stone course this high (fabric
## metres; the kit's native vertical unit is the same) along every open rim
## edge, crenellated above. It is the rim's fall guard, so the public realm
## plants no timber rail there (`parapet_guard_boxes`).
const PARAPET_HEIGHT := 1.2
const PARAPET_HALF_DEPTH := 0.15


static func parapet_guard_boxes(massif: WarrenMassif,
		retained: Dictionary) -> Array[AABB]:
	## One box per open rim edge of the plinth (fine cells): the parapet the
	## kit builds there (BuildingKitAssembler._assemble_fortified).
	var out: Array[AABB] = []
	if massif == null:
		return out
	var size := FabricRecipe.CELL_SIZE
	for value: Variant in retained.keys():
		var cell := value as Vector3i
		var column := Vector2i(floori(cell.x / 2.0), floori(cell.z / 2.0))
		if not massif.is_platform(column) or cell.y != massif.bearing_at(column) - 1:
			continue
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if retained.has(cell + direction):
				continue
			var centre := Vector3(cell) * size + Vector3(direction) * size * 0.5
			var half := Vector3(PARAPET_HALF_DEPTH, 0.0, PARAPET_HALF_DEPTH) \
				+ Vector3(absi(direction.z), 0, absi(direction.x)) * size * 0.5
			out.append(AABB(Vector3(centre.x - half.x, float(cell.y + 1) * size,
				centre.z - half.z), Vector3(half.x * 2.0, PARAPET_HEIGHT, half.z * 2.0)))
	return out


static func huddle_top(massif: WarrenMassif, column: Vector2i) -> int:
	## The highest band (roof included) the lower town may reach on `column`:
	## within HUDDLE_RINGS of the raised district, its own ground plus the
	## plinth height -- no house at the wall's foot stands taller than the
	## wall -- or 2147483647 where there is no higher nearby district.
	## Ground-relative, like every other massif profile. A lower raised
	## district obeys the next higher ring in the same way as the low town.
	if massif == null:
		return 2147483647
	var plinth := 0
	for dz in range(-HUDDLE_RINGS, HUDDLE_RINGS + 1):
		for dx in range(-HUDDLE_RINGS, HUDDLE_RINGS + 1):
			plinth = maxi(plinth, massif.plinth_at(column + Vector2i(dx, dz)))
	if plinth <= massif.plinth_at(column):
		return 2147483647
	return massif.base_at(column) + maxi(plinth, WarrenMazeSourcePlan.MIN_HOUSE_BANDS)


static func crown_column(platform: Dictionary) -> Vector2i:
	## The platform column nearest its own centroid: the citadel is the
	## town's crown, the summit the spine climbs to.
	if not (platform.get("tiers",[]) as Array).is_empty():
		platform = platform.tiers.back()
	var sum := Vector2.ZERO
	for column: Vector2i in platform.columns:
		sum += Vector2(column)
	var centre := sum / float((platform.columns as Dictionary).size())
	var best := Vector2i.ZERO
	var best_distance := INF
	var order: Array = (platform.columns as Dictionary).keys()
	order.sort()
	for column: Vector2i in order:
		var distance := Vector2(column).distance_squared_to(centre)
		if distance < best_distance:
			best_distance = distance
			best = column
	return best


static func ring_depths(solid: Dictionary) -> Dictionary:
	## Cardinal ring of every column, 1 on the massif boundary.
	var depth: Dictionary = {}
	var frontier: Array[Vector2i] = []
	var order: Array = solid.keys()
	order.sort()
	for column: Vector2i in order:
		for direction: Vector2i in CARDINALS:
			if not solid.has(column + direction):
				depth[column] = 1
				frontier.append(column)
				break
	var index := 0
	while index < frontier.size():
		var column := frontier[index]
		index += 1
		for direction: Vector2i in CARDINALS:
			var next := column + direction
			if solid.has(next) and not depth.has(next):
				depth[next] = int(depth[column]) + 1
				frontier.append(next)
	return depth


static func _largest_component(cells: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var best: Array[Vector2i] = []
	var order: Array = cells.keys()
	order.sort()
	for start: Vector2i in order:
		if seen.has(start):
			continue
		var members: Array[Vector2i] = [start]
		seen[start] = true
		var index := 0
		while index < members.size():
			var cell := members[index]
			index += 1
			for direction: Vector2i in CARDINALS:
				var next := cell + direction
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					members.append(next)
		if members.size() > best.size():
			best = members
	var out: Dictionary = {}
	for cell: Vector2i in best:
		out[cell] = true
	return out
