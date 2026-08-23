class_name WarrenVolumePlan
extends RefCounted

## Sealed source of truth for the volumetric city.  A walk cell is an abstract
## floor plane at the bottom of its lattice band; PUBLIC_AIR occupies that band
## and the band above it.  Remaining envelope cells are buildable MASS, while a
## DAYLIGHT_VOID is deliberate open space and can never be inferred from absent
## render geometry.
const HORIZONTAL_CELL_SIZE_M := 3.0
const VERTICAL_BAND_SIZE_M := 1.5
const HEADROOM_BANDS := 2
# Public-route addressability must describe a building production can actually
# emit: two complete 3 m storeys plus one 3 m pitched-roof reservation. The
# former four-band test counted a one-storey box beside the route as viable even
# though the parcel transaction rejects that silhouette as visually squat.
const MIN_ADDRESS_BUILDING_BANDS := 6
# Exact two-lane turns legitimately create isolated inside-corner cells. They
# may not coalesce into a public slab: that topology is already wrong before a
# material, guard rail, or building detail can disguise it.
#
# The SLAB is the property, and it is LOCAL: it is
# MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE, plus the outright ban on a same-datum
# 2x2 walk square in seal(). Between them nothing broader than one macro cell of
# public floor can exist -- a 2x2 macro plaza is 4 connected interior cells and
# is refused as a square before it is measured here at all; a 2x3 block is 8 and
# fails the component cap.
#
# MAX_EXACT_ROUTE_INTERIOR_CELLS is the TOTAL, and the total is a corner count:
# a straight one-wide street contributes nothing, a turn one cell, a T-junction
# two. It therefore scales with how convoluted and how LARGE the public realm
# is, which is the quality this feature exists to produce.
#
# Measured over both pipelines (tests/harness/warren_mass_first_report.gd
# --stage breadth): route-first plans run 26-36 interior cells over 32-37 walk
# cells -- 0.76 to 1.09 per walk cell -- with components of 1-5. Mass-first with
# a lane network runs 29-36 over 35-45 walk cells, 0.69 to 0.88 per walk cell,
# with components of 1-5. The two pipelines build at the SAME corner density and
# the same local breadth; they differ only in how much town there is. An
# absolute 36 is therefore route-first's size, not a breadth rule, and it caps
# the street network at one route.
#
# So the total is stated as a density, floored at the old absolute value.
# INTERIOR_CELLS_PER_TEN_WALK_CELLS is 12, derived from three bounds rather than
# rounded to taste:
#   * ABOVE route-first's own measured worst density, 1.09 -- the pipeline that
#     ships defines what a legitimate corner density is.
#   * ABOVE the worst a one-wide street can reach at all. A lane that turns at
#     EVERY cell owns one isolated inside corner per cell, just under 1.0, and
#     that shape is the "convoluted, snaking" quality this feature exists to
#     produce; a bound underneath it would be throttling the goal. Pinned by
#     test_public_breadth_is_bounded_locally_not_by_total_size.
#   * BELOW what a town of many SMALL slabs would reach. Every interior
#     component may be up to MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE, and a
#     public realm packed with size-5 components runs past 2 per walk cell, so
#     the total still refuses a town that is locally legal everywhere and
#     collectively a series of courts.
# The floor means nothing that passes today can fail tomorrow, and the
# controlled A/B in task-14-report.md shows route-first ranks identically.
const MAX_EXACT_ROUTE_INTERIOR_CELLS := 36
const INTERIOR_CELLS_PER_TEN_WALK_CELLS := 12
const MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE := 5

var stable_id: StringName
var world_seed: int
var envelope: WarrenVolumeEnvelope
var entry_cell: Vector3i
var walk_cells: Array[Vector3i] = []
var primary_itinerary: Array[Vector3i] = []
## Typed branches are kept distinct from the primary itinerary so later
## composition gates never mistake an upper facade gallery for a terrain market
## alley merely because both are auxiliary graph nodes.
var ground_arcade_cells: Array[Vector3i] = []
var elevated_gallery_cells: Array[Vector3i] = []
## One explicitly authored elevated court may form a 2x2 macro square.  It is
## still part of elevated_gallery_cells and landing_cells; this subset exists
## only so the broad-floor gate can distinguish the requested court motif from
## an accidental plaza made by unrelated route branches.
var courtyard_cells: Array[Vector3i] = []
## One explicitly authored ground-level 2x2 market square. Generic route
## growth remains narrow; only a source-stamped square receives this exception.
var market_square_cells: Array[Vector3i] = []
var public_air_cells: Array[Vector3i] = []
var daylight_void_cells: Array[Vector3i] = []
var landing_cells: Array[Vector3i] = []
var transitions: Array[WarrenVolumeTransition] = []
var mass_cells: Dictionary = {}
## Provenance for plans synthesised from an excavated massif:
## `{"massif": WarrenMassif, "excavation": WarrenExcavation}`, empty for the
## route-first carver. It is metadata, never geometry -- seal() never reads it,
## deterministic_signature() never includes it, and a plan is exactly as valid
## with it absent -- so it sits outside the sealed contract and may be attached
## to a plan that is already sealed.
##
## For the same reason a derived clone which rebuilds this plan's geometry
## deliberately does NOT inherit it: whoever derives a plan and still needs the
## provenance re-attaches it, which keeps a stale massif from riding along
## behind a volume it no longer describes.
var mass_context: Dictionary = {}
## Real, excavated street ground a parcel may legitimately address itself to,
## but which cannot ALSO be a `walk_cells` graph node: WarrenExcavationVolumeAdapter
## registers a STAIR/RAMP's intermediate stride cell here, because its ground
## already belongs exclusively to that transition's own public-realm surface
## (WarrenVolumeTransition.surface_cells()), and WarrenVolumePublicRealmAdapter
## would collide the two claims if the same cell also had a walk node. Route-
## first never populates this -- every one of its walk cells already is a
## graph node -- so has_frontage() reduces to has_walk() exactly for every
## route-first plan; only mass-first ever puts a cell here or asks about one.
##
## Public for the same reason `mass_context` is: a derived clone (the ground
## arcade, the elevated gallery) rebuilds its own WarrenVolumePlan from
## geometry alone and has no way to know this set exists, so it does not
## inherit it. Whoever derives a plan and still needs frontage recognised
## re-attaches it explicitly, exactly like mass_context.
var frontage_cells: Dictionary = {}
var audit: Dictionary = {}
var last_rejection := ""
var _walk_set: Dictionary = {}
var _air_set: Dictionary = {}
var _void_set: Dictionary = {}
var _landing_set: Dictionary = {}
var _courtyard_set: Dictionary = {}
var _market_square_set: Dictionary = {}
## Cached fine-lattice floor ownership for public addresses.  A walk endpoint
## owns its complete 2x2 square; a stair/ramp intermediate owns only the exact
## two-lane treads from WarrenVolumeTransition.surface_cells().  Keeping this
## on the sealed source plan lets parcel packing validate the authored doorway
## before it claims a macro column, rather than discovering a floorless door
## after the whole partition has been chosen.
var _exact_route_surface_set: Dictionary = {}
var _sealed := false


func _init(p_stable_id: StringName, p_world_seed: int,
		p_envelope: WarrenVolumeEnvelope) -> void:
	stable_id = p_stable_id
	world_seed = p_world_seed
	envelope = p_envelope


func add_walk_cell(cell: Vector3i, is_primary: bool = true) -> bool:
	if _sealed or _walk_set.has(cell):
		return false
	_walk_set[cell] = true
	walk_cells.append(cell)
	if is_primary:
		primary_itinerary.append(cell)
	return true


func add_frontage(cell: Vector3i) -> bool:
	## Marks `cell` addressable (see `frontage_cells`'s doc) without making it a
	## walk_cells graph node. Idempotent, and legal whether or not `cell` is
	## also a walk cell -- has_frontage() only ever needs the union.
	if _sealed:
		return false
	frontage_cells[cell] = true
	return true


func has_frontage(cell: Vector3i) -> bool:
	return _walk_set.has(cell) or frontage_cells.has(cell)


func add_ground_arcade_cell(cell: Vector3i) -> bool:
	if not add_walk_cell(cell, false):
		return false
	ground_arcade_cells.append(cell)
	return true


func add_elevated_gallery_cell(cell: Vector3i) -> bool:
	if not add_walk_cell(cell, false):
		return false
	elevated_gallery_cells.append(cell)
	return true


func mark_courtyard_cell(cell: Vector3i) -> bool:
	if _sealed or not _walk_set.has(cell):
		return false
	if not _courtyard_set.has(cell):
		_courtyard_set[cell] = true
		courtyard_cells.append(cell)
	return add_landing(cell)


func mark_market_square_cell(cell: Vector3i) -> bool:
	if _sealed or not _walk_set.has(cell):
		return false
	if not _market_square_set.has(cell):
		_market_square_set[cell] = true
		market_square_cells.append(cell)
	return add_landing(cell)


func add_public_air(cell: Vector3i) -> void:
	assert(not _sealed)
	if not _air_set.has(cell):
		_air_set[cell] = true
		public_air_cells.append(cell)


func add_daylight_void(cell: Vector3i) -> bool:
	if _sealed or _void_set.has(cell) or _walk_set.has(cell):
		return false
	_void_set[cell] = true
	daylight_void_cells.append(cell)
	return true


func add_landing(cell: Vector3i) -> bool:
	if _sealed or not _walk_set.has(cell):
		return false
	if not _landing_set.has(cell):
		_landing_set[cell] = true
		landing_cells.append(cell)
	return true


func add_transition(value: WarrenVolumeTransition) -> bool:
	if _sealed or value == null or not value.seal():
		return false
	transitions.append(value)
	for cell: Vector3i in value.swept_air_cells:
		add_public_air(cell)
	return true


func seal(p_entry_cell: Vector3i) -> bool:
	last_rejection = ""
	if _sealed or stable_id.is_empty() or envelope == null \
			or not envelope.is_sealed() or walk_cells.size() < 2 \
			or transitions.size() < 1 or p_entry_cell != primary_itinerary[0]:
		return _reject("missing envelope, entry, walk, or transitions")
	entry_cell = p_entry_cell
	for cell: Vector3i in walk_cells:
		if not envelope.contains_air_column(cell, HEADROOM_BANDS):
			return _reject("walk cell leaves the envelope at %s" % cell)
		for y in range(cell.y, cell.y + HEADROOM_BANDS):
			if not _air_set.has(Vector3i(cell.x, y, cell.z)):
				return _reject("walk cell lacks swept headroom at %s" % cell)
	if not _entry_reaches_exterior():
		return _reject("entry is not on the terrain-level envelope boundary")
	if not _validate_transitions():
		return false
	if not _all_walk_connected():
		return _reject("walk graph is disconnected")
	for cell: Vector3i in daylight_void_cells:
		if _walk_set.has(cell) or _air_set.has(cell):
			return _reject("daylight void overlaps walk or public air at %s" % cell)
	if not courtyard_cells.is_empty() and not _has_one_typed_courtyard():
		return _reject("typed courtyard is not one 2x2 elevated square")
	if not market_square_cells.is_empty() and not _has_one_typed_market_square():
		return _reject("typed market is not one 2x2 ground square")
	_exact_route_surface_set = _exact_route_surface_cells()
	mass_cells = envelope.mass_cells.duplicate()
	for cell: Vector3i in public_air_cells:
		mass_cells.erase(cell)
	for cell: Vector3i in daylight_void_cells:
		mass_cells.erase(cell)
	audit = _build_audit()
	if int(audit.landing_turn_violation_count) != 0:
		return _reject("vertical turns do not own square landings")
	if int(audit.max_transition_rise_bands) > 1:
		return _reject("transition rises more than one band")
	if int(audit.same_datum_public_square_count) != 0:
		return _reject("public route contains a broad same-datum 2x2 block")
	if int(audit.exact_route_interior_cell_count) \
			> interior_breadth_allowance(walk_cells.size()) \
			or int(audit.max_exact_route_interior_component_size) \
			> MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE:
		return _reject("exact public route expands into a broad floor slab")
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func has_walk(cell: Vector3i) -> bool:
	return _walk_set.has(cell)


func has_public_air(cell: Vector3i) -> bool:
	return _air_set.has(cell)


func has_exact_route_surface(cell: Vector3i) -> bool:
	## Whether this exact 1.5 m fine cell carries a public floor.  This is
	## deliberately stricter than has_frontage(), whose 3 m macro cell records
	## which wall belongs to the street but cannot distinguish the two real
	## treads from the two swept-headroom cells beside them.
	return _sealed and _exact_route_surface_set.has(_cell_key(cell))


func exact_route_surface_cells() -> Array[Vector3i]:
	## The canonical fine-grid floor carried by this volume. Consumers must
	## compare against this set instead of expanding macro walk nodes again: a
	## vertical stride owns only its exact two-lane tread/ramp span between the
	## square endpoint landings.
	var out: Array[Vector3i] = []
	if not _sealed:
		return out
	out.assign(_exact_route_surface_set.values())
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return _cell_key(a) < _cell_key(b))
	return out


func address_bands() -> int:
	## Bands of continuous mass beside a walk cell that make it ADDRESSED, taken
	## from the envelope the route was cut through rather than from the constant
	## above. Route-first envelopes carry
	## WarrenVolumeEnvelope.DEFAULT_ADDRESS_BANDS, which IS
	## MIN_ADDRESS_BUILDING_BANDS, so nothing about that world moves; a
	## synthesised mass-first envelope lowers it to WarrenMassif.ADDRESS_BANDS
	## because a six-band buildable layer cannot present a six-band flank to a
	## street that has left grade. See WarrenMassif.ADDRESS_BANDS for the
	## derivation and the trade.
	return envelope.address_bands if envelope != null \
		else MIN_ADDRESS_BUILDING_BANDS


func has_mass(cell: Vector3i) -> bool:
	return mass_cells.has(cell)


func deterministic_signature() -> String:
	var walk_parts := PackedStringArray()
	var transition_parts := PackedStringArray()
	for cell: Vector3i in primary_itinerary:
		walk_parts.append(_cell_key(cell))
	for value: WarrenVolumeTransition in transitions:
		transition_parts.append(value.deterministic_signature())
	var landing_parts := PackedStringArray()
	for cell: Vector3i in landing_cells:
		landing_parts.append(_cell_key(cell))
	landing_parts.sort()
	var ground_parts := PackedStringArray()
	for cell: Vector3i in ground_arcade_cells:
		ground_parts.append(_cell_key(cell))
	ground_parts.sort()
	var gallery_parts := PackedStringArray()
	for cell: Vector3i in elevated_gallery_cells:
		gallery_parts.append(_cell_key(cell))
	gallery_parts.sort()
	var market_parts := PackedStringArray()
	for cell: Vector3i in market_square_cells:
		market_parts.append(_cell_key(cell))
	market_parts.sort()
	var signature := "walk=%s|edges=%s|landings=%s|ground=%s|galleries=%s" % [
		">".join(walk_parts), ">".join(transition_parts),
		",".join(landing_parts), ",".join(ground_parts),
		",".join(gallery_parts)]
	# Preserve every legacy route signature byte-for-byte. The typed square is a
	# maze-only addition and extends the signature only when it actually exists.
	return signature if market_parts.is_empty() else "%s|market=%s" % [
		signature, ",".join(market_parts)]


func canonical_deterministic_signature() -> String:
	## Remove cardinal rotation as a source of apparent diversity while retaining
	## the ordered 3D route, rises, run lengths, and square-landing geometry.
	## Translation is normalized to the entry so this also remains stable if a
	## future terrain adapter moves the local lattice origin.
	var candidates := PackedStringArray()
	for quarter in 4:
		var parts := PackedStringArray()
		for cell: Vector3i in primary_itinerary:
			parts.append(_canonical_cell(cell - entry_cell, quarter))
		var transition_parts := PackedStringArray()
		for value: WarrenVolumeTransition in transitions:
			var from_relative := value.from_cell - entry_cell
			var to_relative := value.to_cell - entry_cell
			transition_parts.append("%d:%s>%s" % [value.kind,
				_canonical_cell(from_relative, quarter),
				_canonical_cell(to_relative, quarter)])
		var landing_parts := PackedStringArray()
		for cell: Vector3i in landing_cells:
			landing_parts.append(_canonical_cell(cell - entry_cell, quarter))
		landing_parts.sort()
		candidates.append("walk=%s|edges=%s|landings=%s" % [
			">".join(parts), ">".join(transition_parts),
			",".join(landing_parts)])
	candidates.sort()
	return candidates[0]


func _validate_transitions() -> bool:
	var ids: Dictionary = {}
	var pairs: Dictionary = {}
	for value: WarrenVolumeTransition in transitions:
		if not value.is_sealed() or ids.has(value.stable_id) \
				or not _walk_set.has(value.from_cell) \
				or not _walk_set.has(value.to_cell):
			return _reject("transition is duplicate, unsealed, or detached")
		var pair := _undirected_pair_key(value.from_cell, value.to_cell)
		if pairs.has(pair):
			return _reject("duplicate transition between walk cells")
		ids[value.stable_id] = true
		pairs[pair] = true
	return true


func _entry_reaches_exterior() -> bool:
	var column := Vector2i(entry_cell.x, entry_cell.z)
	if entry_cell.y != envelope.ground_at(column):
		return false
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i.UP, Vector2i.DOWN]:
		if not envelope.contains_column(column + direction) \
				or envelope.height_at(column + direction) < HEADROOM_BANDS:
			return true
	return false


func _all_walk_connected() -> bool:
	var adjacency: Dictionary = {}
	for cell: Vector3i in walk_cells:
		adjacency[cell] = []
	for value: WarrenVolumeTransition in transitions:
		(adjacency[value.from_cell] as Array).append(value.to_cell)
		(adjacency[value.to_cell] as Array).append(value.from_cell)
	var reached: Dictionary = {}
	var pending: Array[Vector3i] = [entry_cell]
	while not pending.is_empty():
		var current := pending.pop_back() as Vector3i
		if reached.has(current):
			continue
		reached[current] = true
		for neighbor: Vector3i in adjacency[current] as Array:
			if not reached.has(neighbor):
				pending.append(neighbor)
	return reached.size() == walk_cells.size()


func _build_audit() -> Dictionary:
	var ramp_count := 0
	var stair_count := 0
	var level_count := 0
	var max_rise := 0
	var landing_violations := 0
	var transition_by_cell: Dictionary = {}
	for cell: Vector3i in walk_cells:
		transition_by_cell[cell] = []
	for value: WarrenVolumeTransition in transitions:
		max_rise = maxi(max_rise, absi(value.to_cell.y - value.from_cell.y))
		match value.kind:
			WarrenVolumeTransition.Kind.RAMP:
				ramp_count += 1
			WarrenVolumeTransition.Kind.STAIR:
				stair_count += 1
			_:
				level_count += 1
		(transition_by_cell[value.from_cell] as Array).append(value)
		(transition_by_cell[value.to_cell] as Array).append(value)
	for cell: Vector3i in walk_cells:
		var incident := transition_by_cell[cell] as Array
		for first_index in incident.size():
			for second_index in range(first_index + 1, incident.size()):
				var first := incident[first_index] as WarrenVolumeTransition
				var second := incident[second_index] as WarrenVolumeTransition
				if not first.is_vertical() and not second.is_vertical():
					continue
				var first_direction := Vector2i(first.other(cell).x - cell.x,
					first.other(cell).z - cell.z)
				var second_direction := Vector2i(second.other(cell).x - cell.x,
					second.other(cell).z - cell.z)
				first_direction = Vector2i(signi(first_direction.x), signi(first_direction.y))
				second_direction = Vector2i(signi(second_direction.x), signi(second_direction.y))
				if _dot(first_direction, second_direction) == 0 \
						and not _landing_set.has(cell):
					landing_violations += 1
	var overhang_count := 0
	var addressed_count := 0
	var all_overhang_count := 0
	var all_addressed_count := 0
	var elevations: Dictionary = {}
	var route_columns: Dictionary = {}
	var primary_walks: Dictionary = {}
	for primary_cell: Vector3i in primary_itinerary:
		primary_walks[primary_cell] = true
	for cell: Vector3i in walk_cells:
		elevations[cell.y] = true
		var is_primary := primary_walks.has(cell)
		if is_primary:
			var column_key := _column_key(Vector2i(cell.x, cell.z))
			if not route_columns.has(column_key):
				route_columns[column_key] = []
			(route_columns[column_key] as Array).append(cell.y)
		var has_overhang := false
		var top := envelope.top_at(Vector2i(cell.x, cell.z))
		for y in range(cell.y + HEADROOM_BANDS, top):
			if mass_cells.has(Vector3i(cell.x, y, cell.z)) \
					or _walk_set.has(Vector3i(cell.x, y, cell.z)):
				has_overhang = true
				break
		if has_overhang:
			all_overhang_count += 1
			overhang_count += int(is_primary)
		var has_address := false
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			var frontage_complete := true
			for y in range(cell.y, cell.y + address_bands()):
				if not mass_cells.has(Vector3i(cell.x + direction.x, y,
						cell.z + direction.y)):
					frontage_complete = false
					break
			if frontage_complete:
				has_address = true
				break
		if has_address:
			all_addressed_count += 1
			addressed_count += int(is_primary)
	var crossover_count := 0
	for heights_value: Variant in route_columns.values():
		var heights := heights_value as Array
		heights.sort()
		for index in range(heights.size() - 1):
			if int(heights[index + 1]) - int(heights[index]) >= HEADROOM_BANDS:
				crossover_count += 1
				break
	var deep_shaft_count := 0
	var central_column_count := 0
	for column_value: Variant in envelope.height_bands.keys():
		var column := column_value as Vector2i
		if envelope.height_at(column) < ceili(float(envelope.max_height_bands) * 0.65):
			continue
		central_column_count += 1
		var blocked := false
		for y in range(envelope.ground_at(column), envelope.top_at(column)):
			var cell := Vector3i(column.x, y, column.y)
			if mass_cells.has(cell) or _walk_set.has(cell):
				blocked = true
				break
		if not blocked:
			deep_shaft_count += 1
	var max_straight := _max_straight_run()
	var same_datum_fold_count := 0
	var same_datum_near_fold_count := 0
	# Non-consecutive itinerary cells which return beside one another at the
	# same height materialize as one broad timber slab.  Count that topology
	# directly; compactness is desirable only when the revisit is vertically
	# separated and therefore creates an over/under maze episode.
	for left_index in primary_itinerary.size():
		var left := primary_itinerary[left_index]
		for right_index in range(left_index + 2, primary_itinerary.size()):
			var right := primary_itinerary[right_index]
			if left.y != right.y:
				continue
			var distance := absi(left.x - right.x) + absi(left.z - right.z)
			same_datum_fold_count += int(distance == 1)
			same_datum_near_fold_count += int(distance == 2)
	var terrain_street_count := 0
	for cell: Vector3i in walk_cells:
		var is_terrain_street := cell.y == envelope.ground_at(
			Vector2i(cell.x, cell.z))
		terrain_street_count += int(is_terrain_street)
	var ground_arcade_count := ground_arcade_cells.size()
	var ground_primary_count := 0
	var ground_primary_addressed_count := 0
	var ground_primary_opposed_count := 0
	var ground_primary_two_sided_count := 0
	for index in primary_itinerary.size():
		var cell: Vector3i = primary_itinerary[index]
		var column := Vector2i(cell.x, cell.z)
		if cell.y != envelope.ground_at(column):
			continue
		ground_primary_count += 1
		var address_sides := _complete_address_side_count(cell)
		ground_primary_addressed_count += int(address_sides >= 1)
		ground_primary_opposed_count += int(_has_opposed_address_sides(cell))
		ground_primary_two_sided_count += int(
			_has_route_relative_address_sides(index))
	var ground_arcade_upper_crossover_count := 0
	for cell: Vector3i in ground_arcade_cells:
		ground_arcade_upper_crossover_count += int(
			_has_higher_public_walk_in_column(cell))
	return {
		"walk_cell_count": walk_cells.size(),
		"transition_count": transitions.size(),
		"level_transition_count": level_count,
		"ramp_transition_count": ramp_count,
		"stair_transition_count": stair_count,
		"max_transition_rise_bands": max_rise,
		"landing_turn_violation_count": landing_violations,
		"elevation_band_count": elevations.size(),
		"overhang_walk_cell_count": overhang_count,
		"overhang_walk_ratio": float(overhang_count) \
			/ float(primary_itinerary.size()),
		"all_overhang_walk_ratio": float(all_overhang_count) \
			/ float(walk_cells.size()),
		"addressed_walk_cell_count": addressed_count,
		"addressed_walk_ratio": float(addressed_count) \
			/ float(primary_itinerary.size()),
		"all_addressed_walk_ratio": float(all_addressed_count) \
			/ float(walk_cells.size()),
		"route_crossover_count": crossover_count,
		"central_column_count": central_column_count,
		"deep_vertical_shaft_count": deep_shaft_count,
		"deep_vertical_shaft_ratio": 0.0 if central_column_count == 0 else \
			float(deep_shaft_count) / float(central_column_count),
		"max_straight_run_cells": max_straight,
		"same_datum_route_fold_count": same_datum_fold_count,
		"same_datum_route_near_fold_count": same_datum_near_fold_count,
		"same_datum_public_square_count": _same_datum_public_square_count(),
		"exact_route_interior_cell_count": _exact_route_interior_cells().size(),
		"max_exact_route_interior_component_size":
			_max_exact_route_interior_component_size(),
		"terrain_street_walk_cell_count": terrain_street_count,
		"auxiliary_walk_cell_count": walk_cells.size()
			- primary_itinerary.size(),
		"ground_arcade_walk_cell_count": ground_arcade_count,
		"ground_arcade_upper_crossover_count":
			ground_arcade_upper_crossover_count,
		"ground_primary_walk_cell_count": ground_primary_count,
		"ground_primary_addressable_walk_cell_count":
			ground_primary_addressed_count,
		"ground_primary_addressable_walk_ratio": 1.0 \
			if ground_primary_count == 0 else \
			float(ground_primary_addressed_count) / float(ground_primary_count),
		"ground_primary_opposed_address_walk_cell_count":
			ground_primary_opposed_count,
		"ground_primary_opposed_address_walk_ratio": 1.0 \
			if ground_primary_count == 0 else \
			float(ground_primary_opposed_count) / float(ground_primary_count),
		"ground_primary_two_sided_address_walk_cell_count":
			ground_primary_two_sided_count,
		"ground_primary_two_sided_address_walk_ratio": 1.0 \
			if ground_primary_count == 0 else \
			float(ground_primary_two_sided_count) / float(ground_primary_count),
		"elevated_gallery_walk_cell_count": elevated_gallery_cells.size(),
		"elevated_courtyard_walk_cell_count": courtyard_cells.size(),
		"market_square_walk_cell_count": market_square_cells.size(),
		"daylight_void_cell_count": daylight_void_cells.size(),
		"courtyard_daylight_macro_column_count":
			_courtyard_daylight_macro_column_count(),
	}


func _courtyard_daylight_macro_column_count() -> int:
	var columns: Dictionary = {}
	for court: Vector3i in courtyard_cells:
		for daylight: Vector3i in daylight_void_cells:
			if daylight.x == court.x and daylight.z == court.z \
					and daylight.y >= court.y + HEADROOM_BANDS:
				columns[Vector2i(court.x, court.z)] = true
				break
	return columns.size()


func _complete_address_side_count(cell: Vector3i) -> int:
	var result := 0
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i.UP, Vector2i.DOWN]:
		var complete := true
		for y in range(cell.y, cell.y + address_bands()):
			if not mass_cells.has(Vector3i(cell.x + direction.x, y,
					cell.z + direction.y)):
				complete = false
				break
		result += int(complete)
	return result


func _has_opposed_address_sides(cell: Vector3i) -> bool:
	for axis: Array[Vector2i] in [
			[Vector2i.LEFT, Vector2i.RIGHT] as Array[Vector2i],
			[Vector2i.UP, Vector2i.DOWN] as Array[Vector2i]]:
		var complete_pair := true
		for direction: Vector2i in axis:
			for y in range(cell.y, cell.y + address_bands()):
				if not mass_cells.has(Vector3i(cell.x + direction.x, y,
						cell.z + direction.y)):
					complete_pair = false
					break
			if not complete_pair:
				break
		if complete_pair:
			return true
	return false


func _has_route_relative_address_sides(index: int) -> bool:
	var required := _route_side_directions(primary_itinerary, index)
	if required.size() != 2:
		return false
	for direction: Vector2i in required:
		if not _has_complete_address_in_direction(primary_itinerary[index],
				direction):
			return false
	return true


func _has_complete_address_in_direction(cell: Vector3i,
		direction: Vector2i) -> bool:
	for y in range(cell.y, cell.y + address_bands()):
		if not mass_cells.has(Vector3i(cell.x + direction.x, y,
				cell.z + direction.y)):
			return false
	return true


static func _route_side_directions(nodes: Array[Vector3i], index: int) \
		-> Array[Vector2i]:
	## Streets are judged in their own frame. Straight nodes need the two
	## perpendicular flanks; a right-angle node needs the two directions not
	## occupied by its incoming and outgoing route; endpoints use their flanks.
	var open_directions: Dictionary = {}
	for neighbor_index: int in [index - 1, index + 1]:
		if neighbor_index < 0 or neighbor_index >= nodes.size():
			continue
		var delta := nodes[neighbor_index] - nodes[index]
		var direction := Vector2i(signi(delta.x), signi(delta.z))
		if direction != Vector2i.ZERO:
			open_directions[direction] = true
	if open_directions.size() == 1:
		var tangent: Vector2i = open_directions.keys()[0]
		return [Vector2i(-tangent.y, tangent.x),
			Vector2i(tangent.y, -tangent.x)] as Array[Vector2i]
	var out: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN,
			Vector2i.LEFT, Vector2i.UP]:
		if not open_directions.has(direction):
			out.append(direction)
	return out if out.size() == 2 else [] as Array[Vector2i]


func _has_higher_public_walk_in_column(cell: Vector3i) -> bool:
	for other: Vector3i in walk_cells:
		if other.x == cell.x and other.z == cell.z \
				and other.y - cell.y >= HEADROOM_BANDS:
			return true
	return false


func _same_datum_public_square_count() -> int:
	## Every macro walk cell becomes an exact 2x2 player-width surface. Four
	## same-height macro cells in a square therefore become one featureless 4x4
	## fine-cell slab, even when those cells belong to different route branches.
	## Reject that topology here, before parcelization, so a market extension or
	## gallery can never turn a narrow negative-space alley into a plaza.
	var result := 0
	for cell: Vector3i in walk_cells:
		var right := cell + Vector3i.RIGHT
		var back := cell + Vector3i.BACK
		var diagonal := cell + Vector3i(1, 0, 1)
		if not _walk_set.has(right) or not _walk_set.has(back) \
				or not _walk_set.has(diagonal):
			continue
		# Exactly one typed courtyard is allowed to be broad by design. Every
		# cell is named before seal(), so unrelated galleries cannot borrow the
		# exemption merely by touching one corner of it.
		if _courtyard_set.has(cell) and _courtyard_set.has(right) \
				and _courtyard_set.has(back) \
				and _courtyard_set.has(diagonal):
			continue
		if _market_square_set.has(cell) and _market_square_set.has(right) \
				and _market_square_set.has(back) \
				and _market_square_set.has(diagonal):
			continue
		result += 1
	return result


func _has_one_typed_courtyard() -> bool:
	if courtyard_cells.size() != 4:
		return false
	for cell: Vector3i in courtyard_cells:
		if _courtyard_set.has(cell + Vector3i.RIGHT) \
				and _courtyard_set.has(cell + Vector3i.BACK) \
				and _courtyard_set.has(cell + Vector3i(1, 0, 1)):
			return true
	return false


func _has_one_typed_market_square() -> bool:
	## GROUND square, in the sense that separates it from `courtyard_cells`:
	## one 2x2 whose four cells share a datum and none of which is cut BELOW
	## the terrain it stands on. Written as equality while every ground frame
	## was flat, where the two readings coincide -- and only there. A level
	## 2x2 on a hillside always has a low side standing on the mass the
	## terrain step left under it, so equality made the universal market
	## impossible on real ground rather than merely rarer (task D1; the same
	## rule relaxed the same way in `WarrenMazeCarver._stamp_market_square`,
	## which is the only producer of these cells). Strictly a relaxation, so
	## nothing that seals today stops sealing; a square below its own ground
	## would be cut terrain and stays refused.
	if market_square_cells.size() != 4:
		return false
	for cell: Vector3i in market_square_cells:
		if _market_square_set.has(cell + Vector3i.RIGHT) \
				and _market_square_set.has(cell + Vector3i.BACK) \
				and _market_square_set.has(cell + Vector3i(1, 0, 1)):
			for market_cell: Vector3i in market_square_cells:
				if market_cell.y != cell.y \
						or market_cell.y < envelope.ground_at(
							Vector2i(market_cell.x, market_cell.z)):
					return false
			return true
	return false


static func interior_breadth_allowance(walk_cell_count: int) -> int:
	## Inside corners a public realm of this size may own. Integer arithmetic
	## throughout, because this decides acceptance and acceptance is
	## deterministic.
	##
	## Floored at MAX_EXACT_ROUTE_INTERIOR_CELLS, which is what makes the change
	## conservative in the only direction that matters: the allowance is never
	## below what it was, so no plan that seals today can stop sealing. Route-
	## first's walk count is structurally at most 23 primary
	## (ROUTE_CELL_FAMILIES) + 7 and 4 arcade + 8 gallery = 42, so the density
	## branch can raise its allowance from 36 to at most 51 -- and the controlled
	## A/B over seeds 0-7 in task-14-report.md shows not one ranked candidate,
	## attempt or ordering changes, because route-first's own plans top out at 36
	## inside corners for reasons of their own.
	return maxi(MAX_EXACT_ROUTE_INTERIOR_CELLS,
		(walk_cell_count * INTERIOR_CELLS_PER_TEN_WALK_CELLS + 9) / 10)


func exact_route_breadth_allows(
		additional_macro_cells: Array[Vector3i] = []) -> bool:
	## The one authority on "is this public realm too broad", so a solver
	## carving new cells asks the same question seal() will ask afterwards
	## rather than reconstructing it from the constants.
	var audit := exact_route_breadth_audit(additional_macro_cells)
	return int(audit.interior_cell_count) <= interior_breadth_allowance(
			walk_cells.size() + additional_macro_cells.size()) \
		and int(audit.max_interior_component_size) \
			<= MAX_EXACT_ROUTE_INTERIOR_COMPONENT_SIZE


func exact_route_breadth_audit(
		additional_macro_cells: Array[Vector3i] = []) -> Dictionary:
	var interior := _exact_route_interior_cells(additional_macro_cells)
	return {
		"interior_cell_count": interior.size(),
		"max_interior_component_size": _max_cell_component_size(interior),
		"interior_component_sizes": _cell_component_sizes(interior),
	}


static func _cell_component_sizes(cells: Dictionary) -> PackedInt32Array:
	## Every connected inside-corner component, descending. The COUNT of these
	## cells scales with how many corners the public realm turns; only their
	## SIZE says anything about breadth, which is why both are reported.
	var remaining := cells.duplicate()
	var out := PackedInt32Array()
	while not remaining.is_empty():
		var first_key := String(remaining.keys()[0])
		var frontier: Array[Vector3i] = [remaining[first_key] as Vector3i]
		remaining.erase(first_key)
		var size := 0
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			size += 1
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var key := _cell_key(cell + direction)
				if remaining.has(key):
					frontier.append(remaining[key] as Vector3i)
					remaining.erase(key)
		out.append(size)
	out.sort()
	out.reverse()
	return out


func _exact_route_surface_cells(
		additional_macro_cells: Array[Vector3i] = []) -> Dictionary:
	## Mirror the adapter's exact 1.5 m surface projection without depending on a
	## downstream render plan. Endpoint cells expand to 2x2 lanes; each vertical
	## transition contributes its canonical intermediate treads.
	var result: Dictionary = {}
	for macro_cell: Vector3i in walk_cells:
		var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
			macro_cell.z * 2)
		for x_offset in 2:
			for z_offset in 2:
				var cell := origin + Vector3i(x_offset, 0, z_offset)
				result[_cell_key(cell)] = cell
	for transition: WarrenVolumeTransition in transitions:
		for cell: Vector3i in transition.surface_cells():
			result[_cell_key(cell)] = cell
	for macro_cell: Vector3i in additional_macro_cells:
		var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
			macro_cell.z * 2)
		for x_offset in 2:
			for z_offset in 2:
				var cell := origin + Vector3i(x_offset, 0, z_offset)
				result[_cell_key(cell)] = cell
	return result


func _exact_route_interior_cells(
		additional_macro_cells: Array[Vector3i] = []) -> Dictionary:
	var surfaces := _exact_route_surface_cells(additional_macro_cells)
	var result: Dictionary = {}
	for cell_value: Variant in surfaces.values():
		var cell := cell_value as Vector3i
		if surfaces.has(_cell_key(cell + Vector3i.LEFT)) \
				and surfaces.has(_cell_key(cell + Vector3i.RIGHT)) \
				and surfaces.has(_cell_key(cell + Vector3i.FORWARD)) \
				and surfaces.has(_cell_key(cell + Vector3i.BACK)):
			result[_cell_key(cell)] = cell
	# The four fine-lattice inside cells of the explicitly typed 6 x 6 m court
	# are its authored usable floor, not evidence that the surrounding alleys
	# have widened. Remove only that exact square from the generic breadth audit;
	# any interior cells created where other routes accrete around it remain and
	# are still component-gated below.
	if courtyard_cells.size() == 4:
		_remove_typed_square_interior(result, _courtyard_macro_origin())
	if market_square_cells.size() == 4:
		_remove_typed_square_interior(result, _market_macro_origin())
	return result


static func _remove_typed_square_interior(result: Dictionary,
		origin: Vector3i) -> void:
	if origin.x == 2147483647:
		return
	var fine_origin := Vector3i(origin.x * 2, origin.y, origin.z * 2)
	for x_offset in [1, 2]:
		for z_offset in [1, 2]:
			result.erase(_cell_key(fine_origin \
				+ Vector3i(x_offset, 0, z_offset)))


func _courtyard_macro_origin() -> Vector3i:
	for cell: Vector3i in courtyard_cells:
		if _courtyard_set.has(cell + Vector3i.RIGHT) \
				and _courtyard_set.has(cell + Vector3i.BACK) \
				and _courtyard_set.has(cell + Vector3i(1, 0, 1)):
			return cell
	return Vector3i(2147483647, 0, 0)


func _market_macro_origin() -> Vector3i:
	for cell: Vector3i in market_square_cells:
		if _market_square_set.has(cell + Vector3i.RIGHT) \
				and _market_square_set.has(cell + Vector3i.BACK) \
				and _market_square_set.has(cell + Vector3i(1, 0, 1)):
			return cell
	return Vector3i(2147483647, 0, 0)


func _max_exact_route_interior_component_size() -> int:
	return _max_cell_component_size(_exact_route_interior_cells())


static func _max_cell_component_size(cells: Dictionary) -> int:
	var remaining := cells.duplicate()
	var maximum := 0
	while not remaining.is_empty():
		var first_key := String(remaining.keys()[0])
		var frontier: Array[Vector3i] = [remaining[first_key] as Vector3i]
		remaining.erase(first_key)
		var size := 0
		while not frontier.is_empty():
			var cell: Vector3i = frontier.pop_back()
			size += 1
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var key := _cell_key(cell + direction)
				if remaining.has(key):
					frontier.append(remaining[key] as Vector3i)
					remaining.erase(key)
		maximum = maxi(maximum, size)
	return maximum


func _max_straight_run() -> int:
	var maximum := 0
	var current := 0
	var previous_direction := Vector2i.ZERO
	for index in range(primary_itinerary.size() - 1):
		var delta := primary_itinerary[index + 1] - primary_itinerary[index]
		var direction := Vector2i(signi(delta.x), signi(delta.z))
		if direction == previous_direction:
			current += 1
		else:
			current = 1
			previous_direction = direction
		maximum = maxi(maximum, current)
	return maximum


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false


static func _undirected_pair_key(a: Vector3i, b: Vector3i) -> String:
	var a_key := _cell_key(a)
	var b_key := _cell_key(b)
	return "%s|%s" % [a_key, b_key] if a_key < b_key else "%s|%s" % [b_key, a_key]


static func _column_key(column: Vector2i) -> String:
	return "%d:%d" % [column.x, column.y]


static func _dot(a: Vector2i, b: Vector2i) -> int:
	return a.x * b.x + a.y * b.y


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _canonical_cell(cell: Vector3i, quarter: int) -> String:
	var rotated := Vector2i(cell.x, cell.z)
	for _index in posmod(quarter, 4):
		rotated = Vector2i(rotated.y, -rotated.x)
	return "%d:%d:%d" % [rotated.x, cell.y, rotated.y]
