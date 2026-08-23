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
	Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2),
	Vector2i(1, 1),
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
static var last_courtyard_upper_diagnostic: Dictionary = {}


static func partition(massif: WarrenMassif, excavation: WarrenExcavation,
		volume: WarrenVolumePlan = null,
		variant: int = -1) -> Array[WarrenBuildingParcel]:
	## `volume` is optional. The solid predicate this uses (massif column span
	## minus excavation.carved) is exactly what WarrenExcavationVolumeAdapter
	## puts in WarrenVolumePlan.mass_cells, so a plan can never change which
	## mass is available. Passing one additionally makes the exact fine-lattice
	## route surface part of candidate selection: a stair/ramp stride is a coarse
	## frontage cell but only two of its fine cells are real floor. A candidate
	## whose authored door misses those treads is skipped before it claims solid,
	## allowing another frontage or footprint to take the wall. The final pass
	## still seals every selected parcel against the complete volume contract.
	##
	## The one thing a plan does change is the ADDRESS set the infill pass may
	## build from -- see `_fill_addresses`. A plan straight from the adapter
	## carries only walk cells the route already contains, so it adds nothing;
	## an arcade- or gallery-extended plan carries public surfaces the bore
	## never had, and refusing to build beside them would leave the town short
	## of exactly the mass those stages exist to front.
	last_failure = ""
	last_diagnostic = {}
	last_courtyard_upper_diagnostic = {}
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
	var best_corner_excess := 1 << 30
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
		var corner_pairs := _corner_only_pair_count(attempt)
		var corner_excess := maxi(0, corner_pairs * 2 - attempt.size())
		last_diagnostic["corner_only_pair_count"] = corner_pairs
		last_diagnostic["corner_only_pair_excess"] = corner_excess
		if not attempt.is_empty() and (unjoinable < best_unjoinable \
				or unjoinable == best_unjoinable \
				and corner_excess < best_corner_excess):
			out = attempt
			best_diagnostic = last_diagnostic
			best_unjoinable = unjoinable
			best_corner_excess = corner_excess
		if best_unjoinable == 0 and best_corner_excess == 0:
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
	var faces := street_wall_faces(massif, excavation, variant, volume)
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
			massif, excavation, claimed, face_bands, out, out.size(), volume)
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
		claimed, face_bands, _fill_addresses(excavation, volume, variant), volume)
	var court_upper_parcels := _fill_courtyard_upper_walls(out, massif,
		excavation, occupied, face_bands, volume)
	last_diagnostic = _diagnostic(out, faces, inherited, stranded, unjoinable,
		infilled, court_upper_parcels)
	last_diagnostic["courtyard_upper_diagnostic"] = \
		last_courtyard_upper_diagnostic.duplicate(true)
	return out


static func _fill_courtyard_upper_walls(
		placed: Array[WarrenBuildingParcel], massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary,
		face_bands: Dictionary, volume: WarrenVolumePlan) -> int:
	## Complete the court perimeter in three dimensions. A broad lower parcel may
	## roof out exactly at the court datum while a narrower column of source mass
	## continues above it. The old whole-column claim discarded that upper mass;
	## here it becomes a separately addressed parcel whose first room names the
	## lower parcel's top occupied storey as its explicit support parent.
	if volume == null or volume.courtyard_cells.size() != 4:
		return 0
	var court_set: Dictionary = {}
	for cell: Vector3i in volume.courtyard_cells:
		court_set[cell] = true
	var added := 0
	var missing_side_count := 0
	var address_count := 0
	var shape_count := 0
	var top_fit_count := 0
	var parent_fit_count := 0
	var doorway_fit_count := 0
	var cell_fit_count := 0
	var roof_fit_count := 0
	var corner_fit_count := 0
	var top_attempts: Array[Dictionary] = []
	for direction: Vector2i in DIRECTIONS:
		if _court_side_has_private_room(placed, court_set, direction):
			continue
		missing_side_count += 1
		var accepted: WarrenBuildingParcel = null
		for address: Vector3i in volume.courtyard_cells:
			var neighbor := address + Vector3i(direction.x, 0, direction.y)
			if court_set.has(neighbor):
				continue
			address_count += 1
			for shape: Vector2i in SHAPES:
				shape_count += 1
				var footprint := _footprint(address, direction, shape.x,
					shape.y)
				var top := _top_band(footprint, address.y, massif, excavation,
					{}, face_bands)
				if top_attempts.size() < 24:
					var footprint_tops: Array[int] = []
					var grounded_columns := 0
					var first_carved := 2147483647
					for column: Vector2i in footprint:
						footprint_tops.append(massif.top_at(column))
						grounded_columns += int(_is_grounded(massif,
							excavation, column, address.y))
						for band in range(address.y, massif.top_at(column)):
							if excavation.carved.has(Vector3i(column.x, band,
									column.y)):
								first_carved = mini(first_carved, band)
								break
					top_attempts.append({"address": address,
						"direction": direction, "shape": shape,
						"footprint": footprint, "tops": footprint_tops,
						"grounded": grounded_columns, "settled_top": top,
						"first_carved": first_carved})
				if top - address.y < MIN_HOUSE_BANDS:
					continue
				top_fit_count += 1
				var parent := _best_courtyard_support_parent(placed, footprint,
					address.y)
				if parent == null:
					continue
				parent_fit_count += 1
				var candidate := WarrenBuildingParcel.new(StringName(
					"parcel.solid.%04d" % placed.size()), footprint,
					address.y, top, address,
					Vector2i(neighbor.x, neighbor.z), -direction)
				if not candidate.set_building_support(parent.stable_id,
						parent.storey_count() - 1):
					continue
				candidate = _candidate_with_exact_public_floor(candidate, volume)
				if candidate == null:
					continue
				doorway_fit_count += 1
				if not _upper_parcel_cells_fit(candidate, occupied, parent):
					continue
				cell_fit_count += 1
				if not _roofs_can_meet(candidate, placed):
					continue
				roof_fit_count += 1
				if _upper_parcel_corners_neighbor(candidate, placed, parent):
					continue
				corner_fit_count += 1
				accepted = candidate
				break
			if accepted != null:
				break
		if accepted == null:
			continue
		for cell: Vector3i in occupied_cells(accepted):
			occupied[cell] = accepted.stable_id
		placed.append(accepted)
		added += 1
		if _courtyard_private_side_count(placed, court_set) >= 3:
			break
	last_courtyard_upper_diagnostic = {
		"missing_side_count": missing_side_count,
		"address_count": address_count, "shape_count": shape_count,
		"top_fit_count": top_fit_count,
		"parent_fit_count": parent_fit_count,
		"doorway_fit_count": doorway_fit_count,
		"cell_fit_count": cell_fit_count, "roof_fit_count": roof_fit_count,
		"corner_fit_count": corner_fit_count, "accepted_count": added,
		"top_attempts": top_attempts,
	}
	return added


static func _court_side_has_private_room(
		parcels: Array[WarrenBuildingParcel], court_set: Dictionary,
		direction: Vector2i) -> bool:
	for court_value: Variant in court_set.keys():
		var court := court_value as Vector3i
		var neighbor := court + Vector3i(direction.x, 0, direction.y)
		if court_set.has(neighbor):
			continue
		var column := Vector2i(neighbor.x, neighbor.z)
		for parcel: WarrenBuildingParcel in parcels:
			if parcel.footprint.has(column) and parcel.base_band <= court.y \
					and parcel.roof_base_band() > court.y:
				return true
	return false


static func _courtyard_private_side_count(
		parcels: Array[WarrenBuildingParcel], court_set: Dictionary) -> int:
	var count := 0
	for direction: Vector2i in DIRECTIONS:
		count += int(_court_side_has_private_room(parcels, court_set,
			direction))
	return count


static func _best_courtyard_support_parent(
		parcels: Array[WarrenBuildingParcel], footprint: Array[Vector2i],
		base_band: int) -> WarrenBuildingParcel:
	var best: WarrenBuildingParcel = null
	var best_overlap := 0
	for parcel: WarrenBuildingParcel in parcels:
		if parcel.roof_base_band() != base_band or parcel.storey_count() < 1:
			continue
		var overlap := 0
		for column: Vector2i in footprint:
			overlap += int(parcel.footprint.has(column))
		if overlap > best_overlap:
			best = parcel
			best_overlap = overlap
	return best if best_overlap >= maxi(1,
		ceili(float(footprint.size()) * 0.25)) else null


static func _upper_parcel_cells_fit(parcel: WarrenBuildingParcel,
		occupied: Dictionary, parent: WarrenBuildingParcel) -> bool:
	for cell: Vector3i in occupied_cells(parcel):
		if not occupied.has(cell):
			continue
		if StringName(occupied[cell]) != parent.stable_id \
				or cell.y < parent.roof_base_band() or cell.y >= parent.top_band:
			return false
	return true


static func _upper_parcel_corners_neighbor(parcel: WarrenBuildingParcel,
		placed: Array[WarrenBuildingParcel], parent: WarrenBuildingParcel) -> bool:
	for other: WarrenBuildingParcel in placed:
		if other == parent or parcel.top_band <= other.base_band \
				or other.top_band <= parcel.base_band:
			continue
		if _contact_direction(parcel.footprint, other.footprint) \
				== Vector2i.ZERO \
				and _footprints_share_a_corner(parcel.footprint, other.footprint):
			return true
	return false


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
		addresses: Array[Vector3i], volume: WarrenVolumePlan) -> int:
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
				claimed, face_bands, out, volume)
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
		placed: Array[WarrenBuildingParcel],
		volume: WarrenVolumePlan) -> WarrenBuildingParcel:
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
			parcel = _candidate_with_exact_public_floor(parcel, volume)
			if parcel == null:
				# Door phase is fixed by the footprint profile, so lowering the same
				# roof cannot move it onto the other half of the street square.
				break
			if _roofs_can_meet(parcel, placed) \
					and not _corners_a_neighbour(parcel, placed):
				return parcel
			top = _top_band(footprint, address.y, massif, excavation, claimed,
				face_bands, top - 1)
	return null


static func street_wall_faces(massif: WarrenMassif,
		excavation: WarrenExcavation, variant: int = 0,
		volume: WarrenVolumePlan = null) -> Array[Dictionary]:
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
	var out := _admitted(_wall_candidates(massif, excavation, volume), massif,
		excavation)
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _face_before(left, right, variant))
	return out


static func _wall_candidates(massif: WarrenMassif,
		excavation: WarrenExcavation,
		volume: WarrenVolumePlan = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if massif == null or excavation == null:
		return out
	var public_cells: Array[Vector3i] = []
	var seen_public: Dictionary = {}
	for walk: Vector3i in excavation.public_cells():
		if not seen_public.has(walk):
			seen_public[walk] = true
			public_cells.append(walk)
	# Arcades, upper galleries, and the typed third-storey courtyard are carved
	# after the excavation. They are still streets in the sealed source plan and
	# their buildable faces are mandatory town walls, not optional infill. The
	# derived excavation owns their void, while the volume supplies their exact
	# public floor nodes.
	if volume != null:
		for walk: Vector3i in volume.walk_cells:
			if not seen_public.has(walk):
				seen_public[walk] = true
				public_cells.append(walk)
	for walk: Vector3i in public_cells:
		var wall_bands := maxi(MIN_HOUSE_BANDS, excavation.slot_bands(walk))
		for direction_index in DIRECTIONS.size():
			var direction := DIRECTIONS[direction_index]
			var column := Vector2i(walk.x + direction.x, walk.z + direction.y)
			var grounded := _can_carry_house(massif, excavation, column,
				walk.y)
			var court_span := not grounded \
				and _can_carry_courtyard_span(massif, excavation, walk,
					direction, volume)
			if not grounded and not court_span:
				continue
			out.append({
				"column": column,
				"walk": walk,
				"direction": direction,
				"wall_bands": wall_bands,
				"order": direction_index,
				"mixed_span": court_span,
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
	var mixed_span_bands_by_column: Dictionary = {}
	for candidate: Dictionary in candidates:
		var column := candidate["column"] as Vector2i
		if not walls_by_column.has(column):
			walls_by_column[column] = {}
		var walls := walls_by_column[column] as Dictionary
		var band := (candidate["walk"] as Vector3i).y
		walls[band] = maxi(int(walls.get(band, 0)),
			int(candidate["wall_bands"]))
		if bool(candidate.get("mixed_span", false)):
			if not mixed_span_bands_by_column.has(column):
				mixed_span_bands_by_column[column] = {}
			(mixed_span_bands_by_column[column] as Dictionary)[band] = true
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
			var admits_span := (mixed_span_bands_by_column.get(column, {}) \
				as Dictionary).has(band)
			if not admits_span and _top_band(footprint, band, massif,
					excavation, {}, {}) <= band:
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


static func _can_carry_courtyard_span(massif: WarrenMassif,
		excavation: WarrenExcavation, walk: Vector3i,
		walk_to_building: Vector2i, volume: WarrenVolumePlan) -> bool:
	## The required third-storey court may sit directly over a lower public
	## passage. Its facade column is then intentionally undermined, but a deeper
	## room is still a real building when at least half its complete footprint
	## bears continuously behind that opening. Admit only that named topology and
	## only through the same full-envelope math the serving pass will rerun.
	## (A measured attempt to widen this gate to every carver-covered street was
	## a no-op: a street-level candidate anchors its envelope inside the carved
	## slot, so `_top_band` clips it to zero height. Tunnel-top rooms must enter
	## as support-parent children of flanking parcels or through the residual
	## backfill pass — see the town-quality plan ledger.)
	if volume == null or not volume.courtyard_cells.has(walk):
		return false
	var threshold := Vector2i(walk.x + walk_to_building.x,
		walk.z + walk_to_building.y)
	for shape: Vector2i in SHAPES:
		if shape.x * shape.y < 2:
			continue
		var footprint := _footprint(walk, walk_to_building, shape.x,
			shape.y)
		var top := _top_band(footprint, walk.y, massif, excavation, {}, {})
		if top <= walk.y:
			continue
		var probe := WarrenBuildingParcel.new(&"parcel.court.span.probe",
			footprint, walk.y, top, walk, threshold, -walk_to_building)
		if _candidate_with_exact_public_floor(probe, volume) != null:
			return true
	return false


static func unowned_route_faces(parcels: Array[WarrenBuildingParcel],
		excavation: WarrenExcavation,
		massif: WarrenMassif) -> Array[Vector3i]:
	## Street walls this partition left to nobody. See street_wall_audit() for
	## why this deliberately does NOT consult street_wall_faces().
	return street_wall_audit(parcels, excavation, massif)["unowned"] \
		as Array[Vector3i]


static func street_wall_audit(parcels: Array[WarrenBuildingParcel],
		excavation: WarrenExcavation, massif: WarrenMassif,
		volume: WarrenVolumePlan = null) -> Dictionary:
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
	for wall: Vector3i in _raw_street_walls(massif, excavation, volume):
		audit["wall_count"] = int(audit["wall_count"]) + 1
		if owned.has(wall):
			audit["owned_count"] = int(audit["owned_count"]) + 1
			continue
		var column := Vector2i(wall.x, wall.z)
		(audit[_wall_verdict(massif, excavation, column_tops, column, wall.y)] \
			as Array[Vector3i]).append(wall)
	return audit


static func _raw_street_walls(massif: WarrenMassif,
		excavation: WarrenExcavation,
		volume: WarrenVolumePlan = null) -> Array[Vector3i]:
	## Every column face the route actually runs past with solid standing at the
	## street's own floor band, keyed by (column, floor band). Raw geometry
	## only: no notion of what is buildable enters here.
	var seen: Dictionary = {}
	var out: Array[Vector3i] = []
	if massif == null or excavation == null:
		return out
	var public_cells: Array[Vector3i] = []
	var seen_public: Dictionary = {}
	for walk: Vector3i in excavation.public_cells():
		if not seen_public.has(walk):
			seen_public[walk] = true
			public_cells.append(walk)
	if volume != null:
		for walk: Vector3i in volume.walk_cells:
			if not seen_public.has(walk):
				seen_public[walk] = true
				public_cells.append(walk)
	for walk: Vector3i in public_cells:
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
	# APPARENT FACE above this column's own stamped ground -- the same honest
	# restatement `_minimum_bands` carries, and arithmetically identical to the
	# storeys-from-support form it replaces on every offset. The audit stays
	# independent of the partitioner's admission code; what it stops sharing is
	# a support datum the storey-parity fudge had pushed under the terrain.
	var ground := mini(massif.bearing_at(column), base)
	var target := AUDIT_MIN_STOREYS * WarrenBuildingParcel.STOREY_BANDS \
		+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
	if envelope + base - ground < target \
			- posmod(base - ground, WarrenBuildingParcel.STOREY_BANDS):
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
	# APPARENT FACE, counted from the stamped ground under the footprint rather
	# than from the support datum. Identical arithmetic to the pre-Wave-5 rule
	# on every offset (verified case by case: an even offset always matched, and
	# an odd one matched because the support was pushed one band UNDER the
	# ground and the even round-up gave the band straight back). What changes is
	# only what the sentence MEANS: it no longer credits a room buried under the
	# terrain, and where an odd address offset leaves the target one band out of
	# reach the missing band is the plinth stone the house now stands on
	# (WarrenMassif.PLINTH_BUDGET_BANDS) instead of a storey nobody can see.
	#
	# Rounded DOWN to the envelope's own even step, and that direction is forced
	# rather than chosen: an envelope is even (WarrenBuildingParcel.seal), and
	# rounding an odd offset UP would demand seven bands over a street standing
	# one band above its ground -- one more than WarrenMassif's whole buildable
	# layer, so no such house could exist anywhere.
	var ground := -(1 << 30)
	for column: Vector2i in footprint:
		ground = maxi(ground, massif.bearing_at(column))
	needed -= base - mini(ground, base)
	return maxi(MIN_HOUSE_BANDS, needed - posmod(needed, 2))


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
		index: int, volume: WarrenVolumePlan) -> WarrenBuildingParcel:
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
				parcel = _candidate_with_exact_public_floor(parcel, volume)
				if parcel == null:
					break
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


static func _candidate_with_exact_public_floor(parcel: WarrenBuildingParcel,
		volume: WarrenVolumePlan) -> WarrenBuildingParcel:
	if volume == null:
		return parcel
	for door_phase in 2:
		var phased := WarrenBuildingParcel.new(parcel.stable_id,
			parcel.footprint, parcel.base_band, parcel.top_band,
			parcel.address_walk_cell, parcel.threshold_column,
			parcel.frontage_direction, door_phase, parcel.flat_roof)
		if not parcel.support_parent_parcel_id.is_empty() \
				and not phased.set_building_support(
					parcel.support_parent_parcel_id,
					parcel.support_parent_storey_index):
			continue
		if _candidate_has_exact_public_floor(phased, volume):
			return phased
	return null


static func _candidate_has_exact_public_floor(parcel: WarrenBuildingParcel,
		volume: WarrenVolumePlan) -> bool:
	var landing := WarrenParcelConstruction.candidate_address_landing(parcel,
		volume)
	return landing.x != 2147483647 \
		and volume.has_exact_route_surface(landing)


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
	var parcel_ridge := _ridge_direction(parcel)
	var other_ridge := _ridge_direction(other)
	if (parcel_ridge.x == 0) != (other_ridge.x == 0):
		return false
	if contact.x * parcel_ridge.x + contact.y * parcel_ridge.y == 0:
		return true
	var span := _contact_span(parcel.footprint, other.footprint, contact)
	return span == _gable_width_cells(parcel, parcel_ridge) \
		and span == _gable_width_cells(other, other_ridge)


static func _ridge_direction(parcel: WarrenBuildingParcel) -> Vector2i:
	## Every original parcel family runs its ridge into the plot, along the
	## frontage normal. The broad/shallow row is deliberately rotated: its ridge
	## follows the two-module street facade. Derive this before sealing so source
	## search and FabricRoofTopologyPlan classify the same contact.
	var perpendicular := Vector2i(-parcel.frontage_direction.y,
		parcel.frontage_direction.x)
	return perpendicular if parcel.footprint.size() == 2 \
		and _footprint_depth(parcel) == 1 \
		else parcel.frontage_direction


static func _gable_width_cells(parcel: WarrenBuildingParcel,
		ridge: Vector2i) -> int:
	## Complete gable span is the footprint extent perpendicular to the ridge.
	## For a row this is its one-cell depth, not its two-cell street frontage.
	var size := _footprint_size(parcel.footprint)
	return size.y if ridge.x != 0 else size.x


static func _footprint_size(footprint: Array[Vector2i]) -> Vector2i:
	var minimum := Vector2i(1 << 30, 1 << 30)
	var maximum := Vector2i(-(1 << 30), -(1 << 30))
	for column: Vector2i in footprint:
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	return maximum - minimum + Vector2i.ONE


static func _footprint_depth(parcel: WarrenBuildingParcel) -> int:
	var size := _footprint_size(parcel.footprint)
	return size.x if parcel.frontage_direction.x != 0 else size.y


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
	# A footprint spanning more relief than one explicit foundation course would
	# be supported at its highest corner and float above the lowest. That is a
	# masonry terrace, not a terrain-rooted house; let a narrower footprint fit
	# the step instead.
	# A fully borne footprint descends to its natural bearing datum during
	# construction, so its addressed street band is not a plinth height. A mixed
	# span cannot descend through its intentionally open columns and therefore
	# stays at `base`; only that case must also prove the actual lift here.
	var support_band := base if bearing < footprint.size() else 1 << 30
	if not footprint_fits_plinth_budget(massif, footprint, support_band):
		return base
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


static func footprint_fits_plinth_budget(massif: WarrenMassif,
		footprint: Array[Vector2i], support_band: int = 1 << 30) -> bool:
	if massif == null or footprint.is_empty():
		return false
	var lowest_ground := 2147483647
	var highest_ground := -2147483648
	for column: Vector2i in footprint:
		if not massif.has_column(column):
			return false
		lowest_ground = mini(lowest_ground, massif.bearing_at(column))
		highest_ground = maxi(highest_ground, massif.bearing_at(column))
	if highest_ground - lowest_ground > WarrenMassif.PLINTH_BUDGET_BANDS:
		return false
	return support_band == 1 << 30 \
		or support_band - lowest_ground <= WarrenMassif.PLINTH_BUDGET_BANDS


static func _corner_only_pair_count(parcels: Array[WarrenBuildingParcel]) -> int:
	var count := 0
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			if _contact_direction(left.footprint, right.footprint) \
					== Vector2i.ZERO and _footprints_share_a_corner(
						left.footprint, right.footprint):
				count += 1
	return count


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
		unjoinable: int, infilled: int,
		court_upper_parcels: int = 0) -> Dictionary:
	var families: Dictionary = {}
	var footprint_cells := 0
	var alternate_door_phases := 0
	for parcel: WarrenBuildingParcel in parcels:
		var family := "%dcell" % parcel.footprint.size()
		families[family] = int(families.get(family, 0)) + 1
		footprint_cells += parcel.footprint.size()
		alternate_door_phases += int(parcel.address_door_phase == 1)
	return {
		"street_wall_face_count": faces.size(),
		"parcel_count": parcels.size(),
		"infill_house_count": infilled,
		"courtyard_upper_parcel_count": court_upper_parcels,
		"faces_walled_by_a_neighbour": inherited,
		"stranded_face_count": stranded,
		"unjoinable_roof_count": unjoinable,
		"footprint_cell_count": footprint_cells,
		"footprint_families": families,
		"alternate_door_phase_count": alternate_door_phases,
	}
