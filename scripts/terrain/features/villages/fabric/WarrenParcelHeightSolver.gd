class_name WarrenParcelHeightSolver
extends RefCounted

## Assigns complete vertical variants after the horizontal parcel graph is
## packed. A footprint/address slot is immutable; only its number of complete
## storeys may change. This keeps street density independent from skyline
## composition while retaining measured roof compatibility, occupied-link
## reservations, and the stepped Gaussian descent as hard construction facts.
# Ten horizontal slots with at most four complete height variants remain small,
# but measured eaves can make late slots highly constraining. Keeping 512
# partial assignments preserves the original compatible height path plus broad
# skyline alternatives without approaching exhaustive 3^10 enumeration.
const BEAM_WIDTH := 512
const MIN_ROOF_BANDS := 3
## Corpus evidence (2026-08-05 sweep): accepted towns already sit at 0.36-0.60
## with 0-1 same-band adjacencies, and a 0.50 gate would reject half of them
## outright. Variety therefore stays a scoring preference at this gate, not a
## harder rejection.
const MAX_LARGEST_ROOF_RATIO := 0.60
# A terrain-rooted address can gain a lower storey after its horizontal slot is
# chosen.  Prefer a complete downhill roof chain, but keep one bounded relief
# obligation alive for the exact oriel/jetty pass instead of deleting an entire
# otherwise connected town. More than one unresolved shaft still reads as a
# repeated tower field and is rejected here.
const MAX_UNSTEPPED_TALL := 1

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


static func solve(horizontal: Array[WarrenBuildingParcel],
		candidates: Array[Dictionary], pair_compatibility: Callable,
		reservation: Dictionary,
		reservation_compatibility: Callable) \
		-> Array[WarrenBuildingParcel]:
	last_failure = ""
	last_diagnostic = {}
	if horizontal.is_empty():
		last_failure = "missing horizontal parcel graph"
		return [] as Array[WarrenBuildingParcel]
	var variants_by_slot: Dictionary = {}
	for candidate: Dictionary in candidates:
		var parcel := candidate.parcel as WarrenBuildingParcel
		if _storeys(parcel) < 2:
			continue
		var key := _slot_key(parcel)
		if not variants_by_slot.has(key):
			variants_by_slot[key] = [] as Array[WarrenBuildingParcel]
		(variants_by_slot[key] as Array[WarrenBuildingParcel]).append(parcel)
	var slots: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in horizontal:
		var variants: Array[WarrenBuildingParcel] = []
		var slot_key := _slot_key(parcel)
		variants.assign(variants_by_slot.get(slot_key, []) as Array)
		variants.sort_custom(func(a: WarrenBuildingParcel,
				b: WarrenBuildingParcel) -> bool:
			if a.top_band != b.top_band:
				return a.top_band < b.top_band
			return String(a.stable_id) < String(b.stable_id))
		if variants.is_empty():
			last_failure = "packed parcel has no vertical variants"
			return [] as Array[WarrenBuildingParcel]
		slots.append({"original": parcel, "variants": variants})
	# Most-constrained slots first. The final result is sorted back into the
	# horizontal graph's canonical order, so this search ordering cannot leak
	# into deterministic output.
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_size := (a.variants as Array).size()
		var b_size := (b.variants as Array).size()
		if a_size != b_size:
			return a_size < b_size
		return _slot_key(a.original as WarrenBuildingParcel) \
			< _slot_key(b.original as WarrenBuildingParcel))
	var states: Array[Dictionary] = [{
		"parcels": [] as Array[WarrenBuildingParcel],
		"score": 0.0,
	}]
	var slot_index := 0
	for slot: Dictionary in slots:
		var next_states: Array[Dictionary] = []
		for state: Dictionary in states:
			var assigned: Array[WarrenBuildingParcel] = []
			assigned.assign(state.parcels as Array)
			for parcel: WarrenBuildingParcel in slot.variants as Array:
				if not _preserves_reservation(parcel,
						reservation, reservation_compatibility) \
						or not _compatible_with_assigned(parcel, assigned,
							pair_compatibility):
					continue
				var trial := assigned.duplicate()
				trial.append(parcel)
				next_states.append({"parcels": trial,
					"score": _partial_score(trial)})
		if next_states.is_empty():
			last_failure = "measured roofs leave no vertical assignment"
			last_diagnostic = {"slot_index": slot_index,
				"slot_key": _slot_key(slot.original as WarrenBuildingParcel),
				"variant_count": (slot.variants as Array).size(),
				"incoming_state_count": states.size(),
				"original_graph_valid": _complete_graph_valid(horizontal,
					pair_compatibility, reservation, reservation_compatibility)}
			return [] as Array[WarrenBuildingParcel]
		next_states.sort_custom(_state_less)
		if next_states.size() > BEAM_WIDTH:
			next_states.resize(BEAM_WIDTH)
		states = next_states
		slot_index += 1
	var accepted: Array[Dictionary] = []
	for state: Dictionary in states:
		var parcels: Array[WarrenBuildingParcel] = []
		parcels.assign(state.parcels as Array)
		var audit := _audit(parcels)
		if int(audit.roof_band_count) < MIN_ROOF_BANDS \
				or float(audit.largest_roof_ratio) > MAX_LARGEST_ROOF_RATIO \
				or int(audit.unstepped_tall_count) > MAX_UNSTEPPED_TALL:
			continue
		accepted.append({"parcels": parcels, "audit": audit,
			"score": _final_score(audit, parcels)})
	if accepted.is_empty():
		last_failure = "no vertical assignment forms a varied stepped skyline"
		last_diagnostic = {"state_count": states.size(),
			"original_graph_audit": _audit(horizontal),
			"original_graph_valid": _complete_graph_valid(horizontal,
				pair_compatibility, reservation, reservation_compatibility),
			"best_partial": {} if states.is_empty() else _audit(
				states[0].parcels as Array)}
		return [] as Array[WarrenBuildingParcel]
	accepted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		return _signature(a.parcels as Array) < _signature(b.parcels as Array))
	var result: Array[WarrenBuildingParcel] = []
	result.assign(accepted[0].parcels as Array)
	result.sort_custom(func(a: WarrenBuildingParcel,
			b: WarrenBuildingParcel) -> bool:
		return _slot_key(a) < _slot_key(b))
	last_diagnostic = (accepted[0].audit as Dictionary).duplicate(true)
	return result


static func _compatible_with_assigned(parcel: WarrenBuildingParcel,
		assigned: Array[WarrenBuildingParcel],
		pair_compatibility: Callable) -> bool:
	if not pair_compatibility.is_valid():
		return true
	for other: WarrenBuildingParcel in assigned:
		if not bool(pair_compatibility.call(parcel, other)):
			return false
	return true


static func _complete_graph_valid(parcels: Array[WarrenBuildingParcel],
		pair_compatibility: Callable, reservation: Dictionary,
		reservation_compatibility: Callable) -> bool:
	for index in parcels.size():
		var parcel := parcels[index]
		if not _preserves_reservation(parcel, reservation,
				reservation_compatibility):
			return false
		var prior: Array[WarrenBuildingParcel] = []
		prior.assign(parcels.slice(0, index))
		if not _compatible_with_assigned(parcel, prior, pair_compatibility):
			return false
	return true


static func _preserves_reservation(parcel: WarrenBuildingParcel,
		reservation: Dictionary, compatibility: Callable) -> bool:
	return reservation.is_empty() or not compatibility.is_valid() \
		or bool(compatibility.call(parcel, reservation))


static func _partial_score(parcels: Array[WarrenBuildingParcel]) -> float:
	var roof_counts: Dictionary = {}
	var tall_count := 0
	for parcel: WarrenBuildingParcel in parcels:
		roof_counts[parcel.top_band] = int(roof_counts.get(parcel.top_band, 0)) + 1
		tall_count += int(_storeys(parcel) >= 3)
	return float(_largest_count(roof_counts)) * 900.0 \
		- float(roof_counts.size()) * 1300.0 \
		- float(mini(tall_count, 3)) * 260.0 \
		+ float(_unstepped_tall_count(parcels)) * 5000.0 \
		- float(_stepped_pair_count(parcels)) * 400.0 \
		+ float(_same_band_neighbor_pair_count(parcels)) * 500.0 \
		- float(mini(_atomic_perpendicular_pair_count(parcels), 2)) * 350.0


static func _final_score(audit: Dictionary,
		parcels: Array[WarrenBuildingParcel]) -> float:
	## A same-band adjacency is not merely un-stepped: it merges two rooflines
	## into one datum and forces the joined-profile roof family, so it costs
	## variety twice. Penalising it directly is what lets the shell, boarded,
	## and modular roof families coexist on honestly different heights.
	return float(audit.largest_roof_ratio) * 5000.0 \
		- float(audit.roof_band_count) * 800.0 \
		- float(audit.half_level_roof_pair_count) * 450.0 \
		- float(audit.stepped_roof_pair_count) * 450.0 \
		+ float(_same_band_neighbor_pair_count(parcels)) * 700.0 \
		- float(mini(int(audit.atomic_perpendicular_roof_pair_count), 2)) \
			* 1200.0 \
		+ float(maxi(0, int(audit.tall_building_count) - 3)) * 500.0 \
		+ float(int(audit.unstepped_tall_count)) * 12000.0 \
		+ float(_uniform_neighbor_pair_count(parcels)) * 6000.0


static func _same_band_neighbor_pair_count(
		parcels: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			result += int(left.top_band == right.top_band \
				and _footprints_neighbor(left, right))
	return result


static func _audit(parcels: Array[WarrenBuildingParcel]) -> Dictionary:
	var roof_counts: Dictionary = {}
	var tall_count := 0
	var half_pairs := 0
	for parcel: WarrenBuildingParcel in parcels:
		roof_counts[parcel.top_band] = int(roof_counts.get(parcel.top_band, 0)) + 1
		tall_count += int(_storeys(parcel) >= 3)
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			if _footprints_neighbor(left, right):
				half_pairs += int(absi(left.top_band - right.top_band) == 1)
	return {
		"roof_band_count": roof_counts.size(),
		"largest_roof_count": _largest_count(roof_counts),
		"largest_roof_ratio": float(_largest_count(roof_counts)) \
			/ float(maxi(1, parcels.size())),
		"tall_building_count": tall_count,
		"unstepped_tall_count": _unstepped_tall_count(parcels),
		"stepped_roof_pair_count": _stepped_pair_count(parcels),
		"half_level_roof_pair_count": half_pairs,
		"atomic_perpendicular_roof_pair_count":
			_atomic_perpendicular_pair_count(parcels),
	}


static func _unstepped_tall_count(parcels: Array[WarrenBuildingParcel]) -> int:
	var downhill: Dictionary = {}
	var terminals: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		downhill[parcel.stable_id] = [] as Array[StringName]
		if _storeys(parcel) <= 2 and parcel.source != null \
				and parcel.base_band == parcel.source.envelope.ground_at(
					parcel.threshold_column):
			terminals[parcel.stable_id] = true
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			if not _footprints_neighbor(left, right):
				continue
			var delta := left.top_band - right.top_band
			if absi(delta) < 1 or absi(delta) > 2:
				continue
			var higher := left if delta > 0 else right
			var lower := right if delta > 0 else left
			(downhill[higher.stable_id] as Array[StringName]).append(
				lower.stable_id)
	var result := 0
	for parcel: WarrenBuildingParcel in parcels:
		if _storeys(parcel) >= 3:
			result += int(not _reaches_terminal(parcel.stable_id, downhill,
				terminals))
	return result


static func _reaches_terminal(start: StringName, downhill: Dictionary,
		terminals: Dictionary) -> bool:
	var pending: Array[StringName] = [start]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: StringName = pending.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		if terminals.has(current):
			return true
		for next_value: StringName in downhill.get(current, []):
			pending.append(next_value)
	return false


static func _stepped_pair_count(parcels: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			var delta := absi(left.top_band - right.top_band)
			result += int(delta >= 1 and delta <= 2 \
				and _footprints_neighbor(left, right))
	return result


static func _uniform_neighbor_pair_count(
		parcels: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			var left := parcels[left_index]
			var right := parcels[right_index]
			result += int(left.top_band == right.top_band \
				and left.width_cells == right.width_cells \
				and left.depth_cells == right.depth_cells \
				and _footprints_neighbor(left, right))
	return result


static func _atomic_perpendicular_pair_count(
		parcels: Array[WarrenBuildingParcel]) -> int:
	var result := 0
	for left_index in parcels.size():
		for right_index in range(left_index + 1, parcels.size()):
			result += int(WarrenParcelizer._pair_has_atomic_perpendicular_roof(
				parcels[left_index], parcels[right_index]))
	return result


static func _footprints_neighbor(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel) -> bool:
	for left_column: Vector2i in left.footprint:
		for right_column: Vector2i in right.footprint:
			if absi(left_column.x - right_column.x) \
					+ absi(left_column.y - right_column.y) == 1:
				return true
	return false


static func _storeys(parcel: WarrenBuildingParcel) -> int:
	return int(WarrenParcelConstruction.proposal(parcel).get("storeys", 0))


static func _slot_key(parcel: WarrenBuildingParcel) -> String:
	return parcel.slot_signature()


static func _largest_count(counts: Dictionary) -> int:
	var result := 0
	for value: Variant in counts.values():
		result = maxi(result, int(value))
	return result


static func _state_less(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.score), float(b.score)):
		return float(a.score) < float(b.score)
	return _signature(a.parcels as Array) < _signature(b.parcels as Array)


static func _signature(parcels_value: Array) -> String:
	var parts := PackedStringArray()
	for value: Variant in parcels_value:
		var parcel := value as WarrenBuildingParcel
		parts.append("%s:%d" % [_slot_key(parcel), parcel.top_band])
	parts.sort()
	return "|".join(parts)
