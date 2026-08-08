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
##   2. No parcel may STRADDLE a face wall (`_top_band`'s `required`): a house
##      built over a column whose street wall is addressed from higher up must
##      clear that wall's full height, so a wall is never half-owned.
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
##
## Owning every street wall houses the bore's front rank and nothing else, and
## a house that stands alone is a tower however short its envelope: the storeys
## a viewer counts are the ones WarrenParcelConstruction descends to natural
## ground, so an eight-band climb makes a one-storey envelope read as six.
## A second pass therefore fills every remaining site the town's OWN public
## realm can address -- `_fill_free_solid`. It is additive by construction:
## it runs only after every street wall is served, it never moves or shortens a
## house already placed, and one-column-one-house still holds, so
## `street_wall_audit`'s `unowned` bucket cannot grow. Unlike a street wall an
## infill house is optional, so it is skipped rather than forced whenever its
## roof has no join to its neighbours' or it would meet one across a corner.
##
## Its addresses are the whole excavated street network -- the bore route AND
## its secondary lanes, `excavation.public_cells()` -- plus the volume plan's
## walk cells, which is the set WarrenParcelizer._candidates has always packed
## against: the ground arcade and the elevated galleries carve public surfaces
## the bore route never had, and mass beside them is as addressable as mass
## beside the street.
##
## A lane is a street here in every sense that matters to this class. It flanks
## columns that must be owned, it addresses houses, and it is walk cells and
## frontage in the sealed plan -- so `street_wall_faces`, `_raw_street_walls`
## and `_fill_addresses` all read `public_cells()` rather than `route`. Reading
## `route` alone would leave every lane's flank unowned, which is precisely the
## hole in the street the ownership guarantee exists to forbid.

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
## Deterministic second opinions on the serving order (see _variant_key). The
## search stops at the first variant with no unjoinable roof, so seeds that
## never had a corner conflict pay for exactly one.
const PARTITION_VARIANTS := 8

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func partition(massif: WarrenMassif, excavation: WarrenExcavation,
		volume: WarrenVolumePlan = null,
		variant: int = -1) -> Array[WarrenBuildingParcel]:
	## `volume` is optional. The solid predicate this uses (massif column span
	## minus excavation.carved) is exactly what WarrenExcavationVolumeAdapter
	## puts in WarrenVolumePlan.mass_cells, so a plan can never change which
	## mass is available; passing one additionally seals every parcel, which is
	## what Task 6 needs and what proves the geometry satisfies the whole
	## downstream contract rather than merely this class's own rules.
	##
	## The one thing a plan does change is the ADDRESS set the infill pass may
	## build from -- see `_fill_addresses`. A plan straight from the adapter
	## carries only walk cells the route already contains, so it adds nothing;
	## an arcade- or gallery-extended plan carries public surfaces the bore
	## never had, and refusing to build beside them would leave the town short
	## of exactly the mass those stages exist to front.
	last_failure = ""
	last_diagnostic = {}
	var out: Array[WarrenBuildingParcel] = []
	if massif == null or not massif.is_sealed():
		last_failure = "massif missing or unsealed"
		return out
	if excavation == null or not excavation.is_sealed():
		last_failure = "excavation missing or unsealed"
		return out
	# A house is only ever placed against the neighbours already standing, so a
	# corner where no legal roof could meet is an artefact of the order houses
	# went up in, not of the solid. Re-serving the same faces in a different
	# within-band order is therefore a real second opinion, and cheap: the
	# search is integer-only and stops at the first variant that leaves no
	# unjoinable roof, which is the first one on all but a few seeds.
	var best_diagnostic: Dictionary = {}
	var best_unjoinable := 1 << 30
	# A caller that names a variant gets exactly that arrangement, so the
	# frontier can rank several partitions of one volume against every gate
	# rather than this class picking one on a criterion that knows about roofs
	# and nothing else. Naming none keeps the self-selecting behaviour.
	var first := 0 if variant < 0 else posmod(variant, PARTITION_VARIANTS)
	var count := PARTITION_VARIANTS if variant < 0 else 1
	for offset in count:
		var attempt := _partition_variant(massif, excavation, first + offset,
			volume)
		var unjoinable := int(last_diagnostic["unjoinable_roof_count"])
		if not attempt.is_empty() and unjoinable < best_unjoinable:
			out = attempt
			best_diagnostic = last_diagnostic
			best_unjoinable = unjoinable
		if best_unjoinable == 0:
			break
	last_diagnostic = best_diagnostic
	if out.size() < MIN_PARCELS:
		last_failure = "only %d houses partitioned (%s)" % [out.size(),
			last_failure]
	elif best_unjoinable > 0:
		last_failure = "%d house roofs have no join to a neighbour" \
			% best_unjoinable
	if volume != null and not _seal_all(out, volume):
		return [] as Array[WarrenBuildingParcel]
	return out


static func _partition_variant(massif: WarrenMassif,
		excavation: WarrenExcavation,
		variant: int,
		volume: WarrenVolumePlan = null) -> Array[WarrenBuildingParcel]:
	var out: Array[WarrenBuildingParcel] = []
	var faces := street_wall_faces(massif, excavation, variant)
	var face_bands := _face_bands_by_column(faces)
	# A corner column is usually a street wall for BOTH streets that meet there,
	# so the same wall can be addressed from either -- and the choice sets the
	# house's ridge direction. Keeping every address for a wall means a corner
	# whose roof will not join its neighbour can often be turned to face the
	# other way instead of being left unjoinable.
	var addresses: Dictionary = {}
	for face: Dictionary in faces:
		var column := face["column"] as Vector2i
		var key := Vector3i(column.x, (face["walk"] as Vector3i).y, column.y)
		if not addresses.has(key):
			addresses[key] = [] as Array[Dictionary]
		(addresses[key] as Array[Dictionary]).append(face)
	var occupied: Dictionary = {}
	var claimed: Dictionary = {}
	var inherited := 0
	var stranded := 0
	var unjoinable := 0
	for face: Dictionary in faces:
		if _wall_is_owned(face, occupied):
			inherited += 1
			continue
		var wall_column := face["column"] as Vector2i
		var parcel := _house_for_face(addresses[Vector3i(wall_column.x,
			(face["walk"] as Vector3i).y, wall_column.y)] as Array[Dictionary],
			massif, excavation, claimed, face_bands, out, out.size())
		if parcel != null and not _roofs_can_meet(parcel, out) \
				and not _step_neighbours_down(parcel, out, massif, excavation,
					claimed, face_bands):
			unjoinable += 1
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
		for column: Vector2i in parcel.footprint:
			claimed[column] = parcel.stable_id
		out.append(parcel)
	var infilled := _fill_free_solid(out, massif, excavation, occupied,
		claimed, face_bands, _fill_addresses(excavation, volume, variant))
	last_diagnostic = _diagnostic(out, faces, inherited, stranded, unjoinable,
		infilled)
	return out


static func _fill_addresses(excavation: WarrenExcavation,
		volume: WarrenVolumePlan, variant: int) -> Array[Vector3i]:
	## Every public cell a house may be addressed from, ordered by ascending
	## band then by the same variant key the ownership pass sorts faces with, so
	## the whole partition stays a pure function of its integer inputs. The
	## variant permutes this pass too, though `partition` still selects between
	## variants on unjoinable street-wall roofs alone -- an infill house never
	## contributes one, because it is refused rather than carried.
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	for cell: Vector3i in excavation.public_cells():
		if not seen.has(cell):
			seen[cell] = true
			out.append(cell)
	if volume != null:
		for cell: Vector3i in volume.walk_cells:
			if not seen.has(cell):
				seen[cell] = true
				out.append(cell)
	out.sort_custom(func(left: Vector3i, right: Vector3i) -> bool:
		if left.y != right.y:
			return left.y < right.y
		var left_key := _variant_key(Vector2i(left.x, left.z), variant)
		var right_key := _variant_key(Vector2i(right.x, right.z), variant)
		if left_key.x != right_key.x:
			return left_key.x < right_key.x
		return left_key.y < right_key.y)
	return out


static func _fill_free_solid(out: Array[WarrenBuildingParcel],
		massif: WarrenMassif, excavation: WarrenExcavation,
		occupied: Dictionary, claimed: Dictionary, face_bands: Dictionary,
		addresses: Array[Vector3i]) -> int:
	## Houses the solid the ownership pass left standing, so a tall stack is
	## embedded in shorter neighbours instead of rising out of bare ground.
	##
	## Safe for every guarantee the ownership pass established, which is the
	## only reason it may run at all: it starts after the last street wall has
	## been served, so no face it could have taken is still waiting; it adds
	## parcels only on columns `claimed` says are free, so one-column-one-house
	## and the no-overlap rule hold; `_top_band` applies the same terrace,
	## parity, storey-minimum and no-straddle rules; and it never moves or
	## shortens a standing house, so nothing owned can become unowned.
	var placed := 0
	for address: Vector3i in addresses:
		for direction: Vector2i in DIRECTIONS:
			var parcel := _infill_house(address, direction, massif, excavation,
				claimed, face_bands, out)
			if parcel == null:
				continue
			for cell: Vector3i in occupied_cells(parcel):
				occupied[cell] = parcel.stable_id
			for column: Vector2i in parcel.footprint:
				claimed[column] = parcel.stable_id
			out.append(parcel)
			placed += 1
	return placed


static func _infill_house(address: Vector3i, direction: Vector2i,
		massif: WarrenMassif, excavation: WarrenExcavation,
		claimed: Dictionary, face_bands: Dictionary,
		placed: Array[WarrenBuildingParcel]) -> WarrenBuildingParcel:
	## The largest house that fits this address facing this way and joins every
	## roof it touches, or null. Concessions are ranked as they are for a street
	## wall -- a lower roof before a smaller footprint -- but there is no
	## fallback beneath them: nothing depends on this house existing, so an
	## adjacency the compiled vocabulary cannot express is refused outright
	## rather than recorded and carried.
	var stable_id := StringName("parcel.solid.%04d" % placed.size())
	var threshold := Vector2i(address.x + direction.x, address.z + direction.y)
	if claimed.has(threshold):
		return null
	for shape: Vector2i in SHAPES:
		var footprint := _footprint(address, direction, shape.x, shape.y)
		var top := _top_band(footprint, address.y, massif, excavation, claimed,
			face_bands)
		while top > address.y:
			var parcel := WarrenBuildingParcel.new(stable_id, footprint,
				address.y, top, address, threshold, -direction)
			if _roofs_can_meet(parcel, placed) \
					and not _corners_a_neighbour(parcel, placed):
				return parcel
			top = _top_band(footprint, address.y, massif, excavation, claimed,
				face_bands, top - 1)
	return null


static func street_wall_faces(massif: WarrenMassif,
		excavation: WarrenExcavation, variant: int = 0) -> Array[Dictionary]:
	## Every (column, walk cell) pair where the solid left standing beside the
	## route can carry a house addressed from that walk cell. Ordered by
	## ascending street-floor band -- the ordering the ownership guarantee
	## depends on -- then by column and direction so the total order has no
	## ties for the unstable sort_custom to resolve arbitrarily.
	##
	## `variant` permutes only the order of faces sharing a band. Ascending band
	## order, which the ownership guarantee rests on, is identical in every
	## variant, and so is the admitted face SET -- `_admitted` decides that per
	## column from the solid alone. A variant therefore changes which house
	## claims a corner first, never which walls have to be claimed.
	var out := _admitted(_wall_candidates(massif, excavation), massif,
		excavation)
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _face_before(left, right, variant))
	return out


static func _wall_candidates(massif: WarrenMassif,
		excavation: WarrenExcavation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if massif == null or excavation == null:
		return out
	for walk: Vector3i in excavation.public_cells():
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
	## One column, one house -- so where the route passes a column twice, only
	## the higher street can be addressed from it.
	##
	## This is not a simplification for its own sake, it is what the asset stage
	## requires. WarrenParcelConstruction descends a fully-borne house from its
	## addressed floor to its bearing datum as one continuous stack, and
	## WarrenAssetPlan._proposal_extends_parcel_safely() then insists every
	## descended cell be a bearing opportunity -- which WarrenPrunedMassPlan
	## defines as source mass that is NOT another parcel's retained building
	## mass. A house standing on a column another house already occupies lower
	## down therefore fails to seal, however disjoint their bands are.
	##
	## The higher wall wins because it is the one that can be rooted without
	## undercutting anything; the lower wall becomes the plinth beneath it and
	## joins the kerbs and ledges as trimmed leftover. Resolved per column,
	## highest street first, so admission depends only on the terraced solid --
	## never on what the serving pass happened to place first.
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
			if _top_band(footprint, band, massif, excavation, {}, {}) <= band:
				continue
			admitted.append(Vector2i(band, wall))
			break
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
	for walk: Vector3i in excavation.public_cells():
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
	# the addressed floor -- which stops at the terrace, not at natural ground.
	var support := massif.bearing_at(column)
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
	# The deepest terrace under the footprint, floored at the highest natural
	# ground -- WarrenParcelConstruction._support_base_band's rule exactly, and
	# for its reasons: a terrace caps the descent, terrain ends it.
	var ground := -(1 << 30)
	var terrace := 1 << 30
	for column: Vector2i in footprint:
		ground = maxi(ground, massif.base_at(column))
		terrace = mini(terrace, massif.bearing_at(column))
	ground = maxi(ground, terrace)
	var support := ground
	if posmod(base - ground, WarrenBuildingParcel.STOREY_BANDS) != 0:
		support -= 1
	needed -= base - mini(support, base)
	return maxi(MIN_HOUSE_BANDS, needed + posmod(needed, 2))


static func _face_before(left: Dictionary, right: Dictionary,
		variant: int) -> bool:
	var left_walk := left["walk"] as Vector3i
	var right_walk := right["walk"] as Vector3i
	if left_walk.y != right_walk.y:
		return left_walk.y < right_walk.y
	var left_key := _variant_key(left["column"] as Vector2i, variant)
	var right_key := _variant_key(right["column"] as Vector2i, variant)
	if left_key.x != right_key.x:
		return left_key.x < right_key.x
	if left_key.y != right_key.y:
		return left_key.y < right_key.y
	return int(left["order"]) < int(right["order"])


static func _variant_key(column: Vector2i, variant: int) -> Vector2i:
	## Each variant is a different total order on a band's columns -- swapping
	## the major axis and/or its direction. Total, so the unstable sort_custom
	## never has a tie to break arbitrarily, and a pure permutation, so no
	## variant can admit or drop a face.
	match posmod(variant, PARTITION_VARIANTS):
		1:
			return Vector2i(column.y, column.x)
		2:
			return Vector2i(-column.x, -column.y)
		3:
			return Vector2i(-column.y, -column.x)
		4:
			return Vector2i(column.x + column.y, column.x - column.y)
		5:
			return Vector2i(column.x - column.y, column.x + column.y)
		6:
			return Vector2i(-column.x - column.y, column.y - column.x)
		7:
			return Vector2i(column.y - column.x, -column.x - column.y)
		_:
			return column


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


static func _house_for_face(addresses: Array[Dictionary],
		massif: WarrenMassif, excavation: WarrenExcavation,
		claimed: Dictionary, face_bands: Dictionary,
		placed: Array[WarrenBuildingParcel],
		index: int) -> WarrenBuildingParcel:
	## Preference order: the wall's first address, then its largest footprint,
	## then the highest roof its terrace allows -- but only among roofs that can
	## actually MEET the neighbours already standing. A lower roof is tried
	## before a smaller house, and a smaller house before turning the house to
	## face the wall's other street, because each is a larger concession than
	## the last.
	var stable_id := StringName("parcel.solid.%04d" % index)
	var joinable_fallback: WarrenBuildingParcel = null
	var unjoinable: WarrenBuildingParcel = null
	for face: Dictionary in addresses:
		var walk := face["walk"] as Vector3i
		var direction := face["direction"] as Vector2i
		var threshold := face["column"] as Vector2i
		for shape: Vector2i in SHAPES:
			var footprint := _footprint(walk, direction, shape.x, shape.y)
			var top := _top_band(footprint, walk.y, massif, excavation,
				claimed, face_bands)
			while top > walk.y:
				var parcel := WarrenBuildingParcel.new(stable_id, footprint,
					walk.y, top, walk, threshold, -direction)
				var joins := _roofs_can_meet(parcel, placed)
				if joins and not _corners_a_neighbour(parcel, placed):
					return parcel
				# Rank the concessions rather than taking whichever came first:
				# a house that at least joins its neighbours' roofs is a smaller
				# defect than one that also corners them.
				if joins and joinable_fallback == null:
					joinable_fallback = parcel
				if unjoinable == null:
					unjoinable = parcel
				top = _top_band(footprint, walk.y, massif, excavation, claimed,
					face_bands, top - 1)
	# Ownership outranks both: a street wall belonging to nobody is a hole in
	# the town, while an unbuildable adjacency costs this candidate and the
	# frontier moves on. Counted in last_diagnostic either way.
	if joinable_fallback != null:
		return joinable_fallback
	#
	# Deliberately NOT also preferring a footprint that shares a party wall with
	# a standing neighbour, though the construction gate does score buildings on
	# forming connected terraces: SHAPES is ordered largest first and each
	# smaller shape is a strict subset of the larger, so the first admissible
	# candidate already touches everything any candidate could. Measured: adding
	# that preference changed no seed's contact metrics at all.
	return unjoinable


static func _roofs_can_meet(parcel: WarrenBuildingParcel,
		placed: Array[WarrenBuildingParcel]) -> bool:
	## Whether every roof this house would touch has a construction rule in
	## FabricRoofJunctionModuleTable -- decided here, while the house can still
	## be moved, rather than discovered at assembly.
	##
	## The table's whole vocabulary turns on one fact: a junction between roofs
	## at DIFFERENT heights is a STEPPED_EAVE_WALL or STEPPED_GABLE_WALL, and it
	## implements both unconditionally. Only equal-height junctions are
	## restricted, and there are exactly three of those:
	##
	##   PARALLEL_VALLEY (side by side along one street) -> EAVE_FLASHING,
	##     accepted unconditionally.
	##   RIDGE_CONTINUATION (back to back, ridges in line) -> accepted only when
	##     the contact spans BOTH gables full width, which for two houses of
	##     equal width fully overlapping is exactly true. Common here, because
	##     a one-column-wide house has a one-column gable.
	##   PERPENDICULAR_VALLEY (across a corner) -> a bisected valley, which
	##     needs a four-cell eave-to-gable join between two width-two houses at
	##     an exact run offset, with at most one such valley per roof. The
	##     leftover solid does not produce that shape on purpose and mostly
	##     cannot: its houses are predominantly one column wide, and a
	##     width-one house has no valley recipe at all. Avoided rather than
	##     chased -- avoiding an uncompilable adjacency is a fix, inventing a
	##     roof is not.
	##
	## Heights come from the terraces regardless; this only decides which of a
	## column's legal terrace steps a house takes.
	##
	## Equality of `top_band` is exactly equality of the roof datum the
	## classifier compares: FabricRoofTopologyPlan._roof_base() is
	## origin.y + storeys * STOREY_BANDS, which for every parcel this class
	## builds reduces to top_band - ROOF_RESERVATION_BANDS.
	for other: WarrenBuildingParcel in placed:
		if other != parcel and not _pair_can_meet(parcel, other):
			return false
	return true


static func _corners_a_neighbour(parcel: WarrenBuildingParcel,
		placed: Array[WarrenBuildingParcel]) -> bool:
	## Whether this house would meet another only at a corner -- diagonally,
	## with no shared face. Such a pair is the one arrangement the compiled
	## vocabulary cannot express, and it is rejected far downstream as
	## interpenetrating geometry.
	##
	## The exemption from SettlementFabricPlan's visual-envelope test is a
	## declared seam, and WarrenAssetCompiler._party_wall_seams declares one only
	## where StaggeredFabricCompiler.classified_roof_seam_compatible() holds --
	## which requires the pair to have EXACTLY ONE roof junction, i.e. to share a
	## face. Corner neighbours have none, so they are never exempt; and their
	## authored roofs overhang their footprints by about a third of a metre on
	## every side, so the two overhangs always meet across the shared corner by
	## more than the 0.10 m contact tolerance. Both houses are rooted at the
	## terrain, so their envelopes always overlap vertically too.
	##
	## Route-first never produces this pair either: its packing ran
	## WarrenAssetCompiler.parcels_are_visually_compatible as a search predicate,
	## which applies the same envelope test. Partitioning had no such filter.
	for other: WarrenBuildingParcel in placed:
		if _contact_direction(parcel.footprint, other.footprint) \
				!= Vector2i.ZERO:
			continue
		if _footprints_share_a_corner(parcel.footprint, other.footprint):
			return true
	return false


static func _footprints_share_a_corner(left: Array[Vector2i],
		right: Array[Vector2i]) -> bool:
	var occupied: Dictionary = {}
	for column: Vector2i in right:
		occupied[column] = true
	for column: Vector2i in left:
		for step: Vector2i in [Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1)]:
			if occupied.has(column + step):
				return true
	return false


static func _step_neighbours_down(parcel: WarrenBuildingParcel,
		placed: Array[WarrenBuildingParcel], massif: WarrenMassif,
		excavation: WarrenExcavation, claimed: Dictionary,
		face_bands: Dictionary) -> bool:
	## Last resort when a wall's house has no roof left that joins its
	## neighbours: step the offending NEIGHBOURS down a storey instead.
	##
	## Safe for every other guarantee, which is why it is available at all. A
	## neighbour's base band never moves, so the wall it was built for stays
	## owned at the street's own floor; one column carries one house, so
	## lowering a roof cannot expose a wall some other house was covering; and
	## `_top_band` re-derives the lower roof under the same terrace, parity,
	## storey-minimum and no-straddle rules as the original. Only the skyline
	## changes, and it changes downward onto another of the same terrace's
	## legal steps. Reverted wholesale unless every affected roof ends up
	## joinable, so a failed repair leaves the partition exactly as it was.
	var conflicts: Array[WarrenBuildingParcel] = []
	for other: WarrenBuildingParcel in placed:
		if not _pair_can_meet(parcel, other):
			conflicts.append(other)
	var restored: Array[int] = []
	for other: WarrenBuildingParcel in conflicts:
		restored.append(other.top_band)
	var repaired := true
	for other: WarrenBuildingParcel in conflicts:
		var freed := claimed.duplicate()
		for column: Vector2i in other.footprint:
			freed.erase(column)
		# Walk this neighbour's remaining terrace steps, not merely the next
		# one down: the first lower roof may simply collide with a different
		# neighbour, while the one below it clears both.
		var settled := false
		var candidate := other.top_band
		while not settled:
			candidate = _top_band(other.footprint, other.base_band, massif,
				excavation, freed, face_bands, candidate - 1)
			if candidate <= other.base_band:
				break
			other.top_band = candidate
			settled = _pair_can_meet(parcel, other) \
				and _roofs_can_meet(other, placed)
		if not settled:
			repaired = false
			break
	if repaired:
		repaired = _roofs_can_meet(parcel, placed)
	if not repaired:
		for index in conflicts.size():
			conflicts[index].top_band = restored[index]
	return repaired


static func _pair_can_meet(parcel: WarrenBuildingParcel,
		other: WarrenBuildingParcel) -> bool:
	if parcel.top_band != other.top_band:
		return true
	var contact := _contact_direction(parcel.footprint, other.footprint)
	if contact == Vector2i.ZERO:
		return true
	if (parcel.frontage_direction.x == 0) \
			!= (other.frontage_direction.x == 0):
		return false
	if _crosses_frontage(parcel.frontage_direction, contact):
		return true
	var span := _contact_span(parcel.footprint, other.footprint, contact)
	return span == _width_cells(parcel) and span == _width_cells(other)


static func _width_cells(parcel: WarrenBuildingParcel) -> int:
	## Gable width: the footprint's extent across its ridge, derived the way
	## WarrenBuildingParcel.seal() derives width_cells, so it is available
	## before the parcel has been sealed.
	var minimum := Vector2i(1 << 30, 1 << 30)
	var maximum := Vector2i(-(1 << 30), -(1 << 30))
	for column: Vector2i in parcel.footprint:
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var size := maximum - minimum + Vector2i.ONE
	return size.y if parcel.frontage_direction.x != 0 else size.x


static func _contact_span(left: Array[Vector2i], right: Array[Vector2i],
		direction: Vector2i) -> int:
	var occupied: Dictionary = {}
	for column: Vector2i in right:
		occupied[column] = true
	var count := 0
	for column: Vector2i in left:
		count += int(occupied.has(column + direction))
	return count


static func _crosses_frontage(frontage: Vector2i, contact: Vector2i) -> bool:
	## Whether a contact meets this house on an eave rather than a gable end.
	## A parcel's ridge runs along its frontage axis
	## (FabricRoofTopologyPlan._axes takes the ridge from the proposal yaw, and
	## WarrenParcelConstruction._yaw_for_frontage picks that yaw so local BACK
	## maps to the frontage), so a contact perpendicular to the frontage is an
	## eave seam and one along it is a gable end.
	return contact.x * frontage.x + contact.y * frontage.y == 0


static func _contact_direction(left: Array[Vector2i],
		right: Array[Vector2i]) -> Vector2i:
	## The direction FabricRoofTopologyPlan._contact would pick: the one with
	## the most touching cells. Macro adjacency is the whole story because a
	## proposal's occupied cells are exactly its footprint at double
	## resolution -- no eave overhangs a neighbouring column.
	var occupied: Dictionary = {}
	for column: Vector2i in right:
		occupied[column] = true
	var best := Vector2i.ZERO
	var best_count := 0
	for direction: Vector2i in DIRECTIONS:
		var count := 0
		for column: Vector2i in left:
			count += int(occupied.has(column + direction))
		if count > best_count:
			best = direction
			best_count = count
	return best


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
		claimed: Dictionary, face_bands: Dictionary,
		ceiling: int = 1 << 30) -> int:
	## Tops follow the terraces: the roof datum is the LOWEST massif top under
	## the footprint, then cut back to whatever the excavated void or a street
	## wall claimed later actually leaves standing. Returns `base` (a
	## zero-height, always-rejected envelope) for any footprint that is not a
	## legal house here.
	##
	## `ceiling` asks for the best legal roof no higher than a given band, which
	## is how the caller walks a column's terrace steps downward: every answer
	## still satisfies parity, the storey minimum and the no-straddle rule, so a
	## stepped-down roof is as valid as the tallest one.
	if footprint.size() > MAX_FOOTPRINT_COLUMNS:
		return base
	var top := ceiling
	var bearing := 0
	var required := base
	for column: Vector2i in footprint:
		if not massif.has_column(column) or massif.base_at(column) > base:
			return base
		# One column, one house: a column another house already stands on is
		# spent, because the second house would have to be descended through
		# the first and WarrenAssetPlan forbids that (see _admitted).
		if claimed.has(column):
			return base
		# A column whose own street wall is addressed from higher up may still
		# be built over -- but only by a house tall enough to wall that street
		# itself, so the wall ends up owned rather than stranded and the column
		# still carries exactly one house. Anything shorter would stop inside
		# the higher wall and leave it to a house that can no longer be rooted.
		for wall: Vector2i in face_bands.get(column, [] as Array[Vector2i]) \
				as Array[Vector2i]:
			if wall.x > base:
				required = maxi(required, wall.x + wall.y)
		top = mini(top, massif.top_at(column))
		bearing += int(_is_grounded(massif, excavation, column, base))
	if bearing * 2 < footprint.size():
		return base
	for column: Vector2i in footprint:
		for band in range(base, top):
			if excavation.carved.has(Vector3i(column.x, band, column.y)):
				top = band
				break
	var settled := base + (top - base) - (top - base) % 2
	if settled < required or settled - base < _minimum_bands(massif, footprint,
			base, bearing == footprint.size()):
		return base
	return settled


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
		faces: Array[Dictionary], inherited: int, stranded: int,
		unjoinable: int, infilled: int) -> Dictionary:
	var families: Dictionary = {}
	var footprint_cells := 0
	for parcel: WarrenBuildingParcel in parcels:
		var family := "%dcell" % parcel.footprint.size()
		families[family] = int(families.get(family, 0)) + 1
		footprint_cells += parcel.footprint.size()
	return {
		"street_wall_face_count": faces.size(),
		"parcel_count": parcels.size(),
		"infill_house_count": infilled,
		"faces_walled_by_a_neighbour": inherited,
		"stranded_face_count": stranded,
		"unjoinable_roof_count": unjoinable,
		"footprint_cell_count": footprint_cells,
		"footprint_families": families,
	}
