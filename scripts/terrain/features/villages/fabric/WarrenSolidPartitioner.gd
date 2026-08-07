class_name WarrenSolidPartitioner
extends RefCounted

## Partitions the solid a WarrenExcavationCarver route left standing into
## terraced house volumes. Mass-first inverts the route-first parcelizer: the
## leftover solid IS the buildings, so this stage ASSIGNS an owner to every
## street wall instead of searching for envelopes that happen to fit a route.
##
## Ownership is structural, not statistical. `street_wall_faces` admits a
## (column, walk cell) pair only when the cheapest legal house -- a 1x1 based
## on that walk cell -- is already buildable there: MIN_HOUSE_BANDS of
## unexcavated solid above the street floor, and unexcavated bearing below it.
## Two rules then keep that fallback available for the whole pass:
##
##   1. Faces are served in ascending street-floor order, so every parcel
##      already placed shares or undercuts the current base band.
##   2. No parcel may STRADDLE a face wall (`_clipped_top`): its top either
##      stops at or below a face's floor band, or clears that face's full wall
##      height. A wall is therefore never half-owned.
##
## Together those make each face either already fully owned (skip it) or
## completely free from its floor band up (place the fallback), so the pass
## cannot strand a street wall. `street_wall_audit` checks that claim against
## an independently derived wall set -- see its own notes on why it must not
## share this class's admission rules.
##
## Bands, not metres: MIN_HOUSE_BANDS -- one storey plus WarrenBuildingParcel's
## roof reservation -- is exactly the tallest slot the carver bores (headroom
## plus a stair's second tread), so the cheapest legal house walls its street
## for the street's entire height rather than leaving a clerestory gap.
##
## Columns with less than MIN_HOUSE_BANDS of solid above the street, or
## undermined by a lower pass of the route, are deliberately NOT faces. They
## are the terraced massif's low rim and undercroft ledges -- kerbs, not
## frontages -- and spec §3 trims that leftover rather than housing it.

## Width (along the street) x depth (into the block), matching
## WarrenParcelizer.SHAPES and WarrenParcelConstruction.profile_for. Anything
## outside this family has no authored roof profile downstream, and
## WarrenBuildingParcel.seal() rejects a footprint deeper across the street
## than into the block, so the family is a contract rather than a preference.
const SHAPES: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1),
]
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
const MAX_FOOTPRINT_COLUMNS := 6
## One complete storey plus the conservative roof reservation: the shortest
## envelope WarrenBuildingParcel.seal() accepts, and -- not coincidentally --
## exactly the tallest slot the carver bores, so this is also the wall height
## one house must cover to enclose a street section on its own.
const MIN_HOUSE_BANDS := WarrenBuildingParcel.STOREY_BANDS \
	+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
## Production forbids visually short buildings outright (WarrenParcelizer's
## MAX_VISUALLY_SHORT_BUILDINGS is zero), and a canyon wall one storey high is
## not a canyon wall. Counted the way WarrenParcelConstruction.proposal()
## counts it -- from the bearing datum, so a house addressed from an upper
## terrace is already tall by virtue of the stack beneath it.
const MIN_STOREYS := 2
## The same policy restated for street_wall_audit(), which must not read the
## partitioner's own constants -- if MIN_STOREYS ever drifts from the
## production rule, the audit is what notices.
const AUDIT_MIN_STOREYS := 2
const MIN_PARCELS := 10

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func partition(massif: WarrenMassif, excavation: WarrenExcavation,
		volume: WarrenVolumePlan = null) -> Array[WarrenBuildingParcel]:
	## `volume` is optional: the solid predicate this uses (massif column span
	## minus excavation.carved) is exactly what WarrenExcavationVolumeAdapter
	## puts in WarrenVolumePlan.mass_cells, so the partition is identical with
	## or without it. Passing the plan additionally seals every parcel, which
	## is what Task 6 needs and what proves the geometry satisfies the whole
	## downstream contract rather than merely this class's own rules.
	last_failure = ""
	last_diagnostic = {}
	var out: Array[WarrenBuildingParcel] = []
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return out
	if excavation == null or not excavation.is_sealed():
		last_failure = "excavation missing or unsealed"
		return out
	var faces := street_wall_faces(massif, excavation)
	var face_bands := _face_bands_by_column(faces)
	var occupied: Dictionary = {}
	var inherited := 0
	var stranded := 0
	for face: Dictionary in faces:
		if _wall_is_owned(face, occupied):
			inherited += 1
			continue
		var parcel := _house_for_face(face, massif, excavation, occupied,
			face_bands, out.size())
		if parcel == null:
			# Unreachable while the two rules above hold; recorded rather than
			# repaired so the audit names the stranded wall instead of this
			# class quietly shrinking the street.
			stranded += 1
			last_failure = "no house fits the street wall at %s from %s" % [
				face["column"], face["walk"]]
			continue
		for cell: Vector3i in occupied_cells(parcel):
			occupied[cell] = parcel.stable_id
		out.append(parcel)
	last_diagnostic = _diagnostic(out, faces, inherited, stranded)
	if out.size() < MIN_PARCELS:
		last_failure = "only %d houses partitioned" % out.size()
	if volume != null and not _seal_all(out, volume):
		return [] as Array[WarrenBuildingParcel]
	return out


static func street_wall_faces(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Dictionary]:
	## Every (column, walk cell) pair where the solid left standing beside the
	## route can carry a house addressed from that walk cell. Ordered by
	## ascending street-floor band -- the ordering the ownership guarantee
	## depends on -- then by column and direction so the total order has no
	## ties for the unstable sort_custom to resolve arbitrarily.
	var out := _admitted(_wall_candidates(massif, excavation), massif,
		excavation)
	out.sort_custom(_face_before)
	return out


static func _wall_candidates(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if massif == null or excavation == null:
		return out
	for walk: Vector3i in excavation.route:
		var wall_bands := maxi(MIN_HOUSE_BANDS, excavation.slot_bands(walk))
		for direction_index in DIRECTIONS.size():
			var direction := DIRECTIONS[direction_index]
			var column := Vector2i(walk.x + direction.x, walk.z + direction.y)
			if not _can_carry_house(massif, excavation, column, walk.y):
				continue
			out.append({
				"column": column,
				"walk": walk,
				"direction": direction,
				"wall_bands": wall_bands,
				"order": direction_index,
			})
	return out


static func _admitted(candidates: Array[Dictionary], massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Dictionary]:
	## Where the route passes a column twice within one envelope's height, the
	## two walls cannot both be housed: an even-band envelope rooted at the
	## lower street either stops short of the upper wall or ends inside it, and
	## the upper street's own house would have to start inside the lower one.
	## The upper wall wins, because it is the one a house can be rooted at
	## without undercutting anything, and the lower wall joins the kerbs and
	## ledges as trimmed leftover. Resolved per column, highest street first,
	## so admission depends only on the terraced solid -- never on what the
	## serving pass happened to place first.
	var walls_by_column: Dictionary = {}
	for candidate: Dictionary in candidates:
		var column := candidate["column"] as Vector2i
		if not walls_by_column.has(column):
			walls_by_column[column] = {}
		var walls := walls_by_column[column] as Dictionary
		var band := (candidate["walk"] as Vector3i).y
		walls[band] = maxi(int(walls.get(band, 0)),
			int(candidate["wall_bands"]))
	var admitted_by_column: Dictionary = {}
	for column_value: Variant in walls_by_column.keys():
		var column := column_value as Vector2i
		var bands: Array[int] = []
		bands.assign((walls_by_column[column] as Dictionary).keys())
		bands.sort()
		bands.reverse()
		var admitted: Array[Vector2i] = []
		var footprint: Array[Vector2i] = [column]
		for band: int in bands:
			var wall := int((walls_by_column[column] as Dictionary)[band])
			# Admission asks the identical question the serving pass will ask,
			# through the identical code path, so "this face was admitted" and
			# "its fallback house is legal" can never drift apart.
			if _top_band(footprint, band, massif, excavation, {},
					{column: admitted}) <= band:
				continue
			admitted.append(Vector2i(band, wall))
		admitted_by_column[column] = admitted
	var out: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		var admitted := admitted_by_column[candidate["column"]] as Array[Vector2i]
		var band := (candidate["walk"] as Vector3i).y
		for wall: Vector2i in admitted:
			if wall.x == band:
				out.append(candidate)
				break
	return out


static func unowned_route_faces(parcels: Array[WarrenBuildingParcel],
		excavation: WarrenExcavation,
		massif: WarrenMassif) -> Array[Vector3i]:
	## Street walls this partition left to nobody. See street_wall_audit() for
	## why this deliberately does NOT consult street_wall_faces().
	return street_wall_audit(parcels, excavation, massif)["unowned"] \
		as Array[Vector3i]


static func street_wall_audit(parcels: Array[WarrenBuildingParcel],
		excavation: WarrenExcavation, massif: WarrenMassif) -> Dictionary:
	## The gate Task 6 should run, and an oracle deliberately independent of the
	## partitioner it audits.
	##
	## Sharing `street_wall_faces()` between the partition and its audit would
	## make the audit blind to exactly the failure worth catching: mis-set the
	## admission threshold and a genuinely buildable wall vanishes from BOTH,
	## so a visibly under-built town reports zero unowned faces. So the wall set
	## here is re-derived from the raw route, massif and carved void, and the
	## reasons a wall may go unhoused are re-derived from WarrenBuildingParcel's
	## OWN contract (STOREY_BANDS, ROOF_RESERVATION_BANDS) and the production
	## no-visually-short-houses policy -- never from this class's constants.
	## The formula duplication is the point: if the partitioner's rules drift
	## from the contract they claim to implement, walls land in `unowned` and
	## the gate fires instead of quietly agreeing.
	##
	## Every raw wall lands in exactly one bucket:
	##   owned_count  a house occupies the wall cell at the street's own floor
	##                band (owning the column but starting a terrace higher is
	##                the same hole in the street as owning nothing)
	##   plinth       unhoused here, but the column carries a house further up
	##   kerb         too little solid above the street for any sealable
	##                envelope -- the terraced rim, not a frontage
	##   undermined   carved out beneath, so nothing can bear on it
	##   short        sealable, but only as a house production calls visually
	##                short
	##   unowned      none of the above: a real gap in the street wall
	var owned: Dictionary = {}
	var column_tops: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for cell: Vector3i in occupied_cells(parcel):
			owned[cell] = true
		for column: Vector2i in parcel.footprint:
			column_tops[column] = maxi(int(column_tops.get(column, -(1 << 30))),
				parcel.top_band)
	var audit := {
		"wall_count": 0,
		"owned_count": 0,
		"plinth": [] as Array[Vector3i],
		"kerb": [] as Array[Vector3i],
		"undermined": [] as Array[Vector3i],
		"short": [] as Array[Vector3i],
		"unowned": [] as Array[Vector3i],
	}
	for wall: Vector3i in _raw_street_walls(massif, excavation):
		audit["wall_count"] = int(audit["wall_count"]) + 1
		if owned.has(wall):
			audit["owned_count"] = int(audit["owned_count"]) + 1
			continue
		var column := Vector2i(wall.x, wall.z)
		(audit[_wall_verdict(massif, excavation, column_tops, column, wall.y)] \
			as Array[Vector3i]).append(wall)
	return audit


static func _raw_street_walls(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Vector3i]:
	## Every column face the route actually runs past with solid standing at the
	## street's own floor band, keyed by (column, floor band). Raw geometry
	## only: no notion of what is buildable enters here.
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	if massif == null or excavation == null:
		return out
	for walk: Vector3i in excavation.route:
		for direction: Vector2i in DIRECTIONS:
			var column := Vector2i(walk.x + direction.x, walk.z + direction.y)
			var wall := Vector3i(column.x, walk.y, column.y)
			if seen.has(wall) or not massif.has_column(column) \
					or massif.base_at(column) > walk.y \
					or massif.top_at(column) <= walk.y \
					or excavation.carved.has(wall):
				continue
			seen[wall] = true
			out.append(wall)
	return out


static func _wall_verdict(massif: WarrenMassif, excavation: WarrenExcavation,
		column_tops: Dictionary, column: Vector2i, base: int) -> StringName:
	if int(column_tops.get(column, -(1 << 30))) > base:
		return &"plinth"
	for band in range(massif.base_at(column), base):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return &"undermined"
	var clear := 0
	for band in range(base, massif.top_at(column)):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			break
		clear += 1
	var envelope := clear - clear % WarrenBuildingParcel.STOREY_BANDS
	if envelope < WarrenBuildingParcel.STOREY_BANDS \
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS:
		return &"kerb"
	# Storeys as WarrenParcelConstruction.proposal() counts them: the envelope's
	# own rooms plus whatever complete storeys its bearing stack adds beneath
	# the addressed floor.
	var support := massif.base_at(column)
	if posmod(base - support, WarrenBuildingParcel.STOREY_BANDS) != 0:
		support -= 1
	var storeys := (envelope - WarrenBuildingParcel.ROOF_RESERVATION_BANDS \
		+ base - support) / WarrenBuildingParcel.STOREY_BANDS
	if storeys < AUDIT_MIN_STOREYS:
		return &"short"
	return &"unowned"


static func occupied_cells(parcel: WarrenBuildingParcel) -> Array[Vector3i]:
	## Mirrors WarrenBuildingParcel._occupied_cells without requiring the
	## parcel to have been sealed against a volume plan first, so occupancy
	## bookkeeping and the audit agree with WarrenParcelPlan's overlap check.
	var out: Array[Vector3i] = []
	for column: Vector2i in parcel.footprint:
		for band in range(parcel.base_band, parcel.top_band):
			out.append(Vector3i(column.x, band, column.y))
	return out


static func _can_carry_house(massif: WarrenMassif,
		excavation: WarrenExcavation, column: Vector2i, base: int) -> bool:
	## Cheap prefilter for the face set: the column exists, its ground is at or
	## below the street, and nothing is carved from its ground up through the
	## house it would have to carry. Bearing is included because
	## WarrenBuildingParcel.seal() requires continuous bearing under at least
	## half a footprint, which for a single column means that column. Whether
	## the resulting envelope is actually legal is decided by `_top_band`,
	## which _admitted() calls directly.
	if not massif.has_column(column) or massif.base_at(column) > base:
		return false
	var footprint: Array[Vector2i] = [column]
	var needed := _minimum_bands(massif, footprint, base, true)
	if massif.top_at(column) < base + needed:
		return false
	for band in range(massif.base_at(column), base + needed):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _minimum_bands(massif: WarrenMassif, footprint: Array[Vector2i],
		base: int, grounded: bool) -> int:
	## The shortest envelope that both seals and reads as a house. Built
	## storeys are counted from the bearing datum exactly as
	## WarrenParcelConstruction.proposal() counts them, so a house addressed
	## from an upper terrace inherits the storeys of the stack below it and
	## needs only the seal minimum, while one addressed at the ground street
	## has nothing beneath it and must be a genuine two-storey envelope.
	var needed := MIN_STOREYS * WarrenBuildingParcel.STOREY_BANDS \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	if not grounded:
		# A mixed-span parcel deliberately stays at its addressed level rather
		# than descending, so it must carry its own storeys.
		return maxi(MIN_HOUSE_BANDS, needed)
	var ground := -(1 << 30)
	for column: Vector2i in footprint:
		ground = maxi(ground, massif.base_at(column))
	var support := ground
	if posmod(base - ground, WarrenBuildingParcel.STOREY_BANDS) != 0:
		support -= 1
	needed -= base - mini(support, base)
	return maxi(MIN_HOUSE_BANDS, needed + posmod(needed, 2))


static func _face_before(left: Dictionary, right: Dictionary) -> bool:
	var left_walk := left["walk"] as Vector3i
	var right_walk := right["walk"] as Vector3i
	if left_walk.y != right_walk.y:
		return left_walk.y < right_walk.y
	var left_column := left["column"] as Vector2i
	var right_column := right["column"] as Vector2i
	if left_column.x != right_column.x:
		return left_column.x < right_column.x
	if left_column.y != right_column.y:
		return left_column.y < right_column.y
	return int(left["order"]) < int(right["order"])


static func _face_bands_by_column(faces: Array[Dictionary]) -> Dictionary:
	## column -> ascending [floor band, wall height] pairs. The no-straddle rule
	## needs every face on a column, including ones this pass has not reached
	## yet, so a parcel placed early cannot half-cover a wall claimed later.
	var out: Dictionary = {}
	for face: Dictionary in faces:
		var column := face["column"] as Vector2i
		if not out.has(column):
			out[column] = [] as Array[Vector2i]
		var walls := out[column] as Array[Vector2i]
		var entry := Vector2i((face["walk"] as Vector3i).y,
			int(face["wall_bands"]))
		if not walls.has(entry):
			walls.append(entry)
	for column_value: Variant in out.keys():
		(out[column_value] as Array[Vector2i]).sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return out


static func _wall_is_owned(face: Dictionary, occupied: Dictionary) -> bool:
	var column := face["column"] as Vector2i
	var walk := face["walk"] as Vector3i
	for band in range(walk.y, walk.y + int(face["wall_bands"])):
		if not occupied.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _house_for_face(face: Dictionary, massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary,
		face_bands: Dictionary, index: int) -> WarrenBuildingParcel:
	var walk := face["walk"] as Vector3i
	var direction := face["direction"] as Vector2i
	var threshold := face["column"] as Vector2i
	for shape: Vector2i in SHAPES:
		var footprint := _footprint(walk, direction, shape.x, shape.y)
		var top := _top_band(footprint, walk.y, massif, excavation, occupied,
			face_bands)
		if top <= walk.y:
			continue
		return WarrenBuildingParcel.new(
			StringName("parcel.solid.%04d" % index), footprint, walk.y, top,
			walk, threshold, -direction)
	return null


static func _footprint(walk: Vector3i, walk_to_building: Vector2i, width: int,
		depth: int) -> Array[Vector2i]:
	## WarrenParcelizer._footprint with the lateral variant fixed at zero, so
	## the facade always grows along +perpendicular from its threshold.
	##
	## That is not a simplification, it is the only variant that works. The
	## authored two-wide profiles put their doorway in the macro column at the
	## -perpendicular end of the facade (WarrenParcelConstruction.profile_for
	## uses door_cell.x == -1, and local +X maps to this perpendicular), so the
	## other variant hands the door to the neighbouring column and
	## door_serves_address() -- which WarrenParcelPlan.seal() rejects on --
	## fails. The parcelizer emits both and filters; there is nothing to filter
	## if the losing variant is never built.
	var perpendicular := Vector2i(-walk_to_building.y, walk_to_building.x)
	var threshold := Vector2i(walk.x, walk.z) + walk_to_building
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_offset in width:
			out.append(threshold + walk_to_building * depth_offset \
				+ perpendicular * width_offset)
	return out


static func _top_band(footprint: Array[Vector2i], base: int,
		massif: WarrenMassif, excavation: WarrenExcavation,
		occupied: Dictionary, face_bands: Dictionary) -> int:
	## Tops follow the terraces: the roof datum is the LOWEST massif top under
	## the footprint, then cut back to whatever the excavated void, an existing
	## neighbour, or a street wall claimed later actually leaves standing.
	## Returns `base` (a zero-height, always-rejected envelope) for any
	## footprint that is not a legal house here.
	if footprint.size() > MAX_FOOTPRINT_COLUMNS:
		return base
	var top := 1 << 30
	var bearing := 0
	for column: Vector2i in footprint:
		if not massif.has_column(column) or massif.base_at(column) > base:
			return base
		top = mini(top, massif.top_at(column))
		bearing += int(_is_grounded(massif, excavation, column, base))
	if bearing * 2 < footprint.size():
		return base
	for column: Vector2i in footprint:
		for band in range(base, top):
			var cell := Vector3i(column.x, band, column.y)
			if excavation.carved.has(cell) or occupied.has(cell):
				top = band
				break
	var settled := _settled_top(footprint, base, top, face_bands)
	if settled - base < _minimum_bands(massif, footprint, base,
			bearing == footprint.size()):
		return base
	return settled


static func _settled_top(footprint: Array[Vector2i], base: int, top: int,
		face_bands: Dictionary) -> int:
	## Parity and the no-straddle rule have to hold at the SAME top, so they are
	## iterated to a fixpoint rather than applied once each: rounding an
	## odd-height envelope down by one band can drop its roof back inside a
	## wall it had just cleared, which is exactly how a single orphaned wall
	## cell appears. Each round strictly lowers the top, so this terminates.
	var settled := top
	for _round in range(top - base + 2):
		var height := settled - base
		settled = base + height - height % 2
		if settled <= base:
			return base
		var clipped := _clipped_top(footprint, base, settled, face_bands)
		if clipped == settled:
			return settled
		settled = clipped
	return base


static func _clipped_top(footprint: Array[Vector2i], base: int, top: int,
		face_bands: Dictionary) -> int:
	## The no-straddle rule. A parcel may rise past a street wall on one of its
	## columns only if it covers that wall completely; otherwise it stops at
	## the wall's floor and leaves the whole wall to the house that will be
	## addressed from it. Half-owned walls are what would break the guarantee.
	var result := top
	for column: Vector2i in footprint:
		for wall: Vector2i in face_bands.get(column, [] as Array[Vector2i]) \
				as Array[Vector2i]:
			if wall.x <= base or result <= wall.x or result >= wall.x + wall.y:
				continue
			result = wall.x
	return result


static func _is_grounded(massif: WarrenMassif, excavation: WarrenExcavation,
		column: Vector2i, base: int) -> bool:
	## Mirrors WarrenBuildingParcel._has_continuous_bearing against the solid
	## the excavation left, so the bearing majority is measured here on the
	## same terms seal() will later re-measure it on.
	for band in range(massif.base_at(column), base):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _seal_all(parcels: Array[WarrenBuildingParcel],
		volume: WarrenVolumePlan) -> bool:
	for parcel: WarrenBuildingParcel in parcels:
		if not parcel.seal(volume):
			last_failure = "parcel %s did not seal against the volume plan" \
				% parcel.stable_id
			return false
		if not WarrenParcelConstruction.door_serves_address(parcel):
			last_failure = "parcel %s door does not open onto its address" \
				% parcel.stable_id
			return false
	return true


static func _diagnostic(parcels: Array[WarrenBuildingParcel],
		faces: Array[Dictionary], inherited: int,
		stranded: int) -> Dictionary:
	var families: Dictionary = {}
	var footprint_cells := 0
	for parcel: WarrenBuildingParcel in parcels:
		var family := "%dcell" % parcel.footprint.size()
		families[family] = int(families.get(family, 0)) + 1
		footprint_cells += parcel.footprint.size()
	return {
		"street_wall_face_count": faces.size(),
		"parcel_count": parcels.size(),
		"faces_walled_by_a_neighbour": inherited,
		"stranded_face_count": stranded,
		"footprint_cell_count": footprint_cells,
		"footprint_families": families,
	}
