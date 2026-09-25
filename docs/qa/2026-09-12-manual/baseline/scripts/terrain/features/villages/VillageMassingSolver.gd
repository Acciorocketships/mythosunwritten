class_name VillageMassingSolver
extends RefCounted

## Deterministic bounded beam search for compact terrain-led building massing.
## All slots use the same candidate/occupancy rules; tiers differ only through
## compiled semantic rosters and thresholds.
const BEAM_WIDTH := 32
const CANDIDATES_PER_STATE := 32
const SURVEY_LIMIT := 512
const NATURAL_FRONTIER_RUN := 6
const PLANS_PER_BUILDING_COUNT := 8


static func solve(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, village_program: VillageProgram,
		tier: StringName,
		reserved_volumes: Array[VillageOccupancyVolume] = []) -> VillageMassingPlan:
	var result := _solve_frontier(terrain, arrival, primary_axis,
		village_program, tier, reserved_volumes)
	var plans: Array = result.plans
	return _rejected(result.reason, result.get("audit", {})) \
		if plans.is_empty() else plans[0]


static func solve_candidates(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, village_program: VillageProgram,
		tier: StringName,
		reserved_volumes: Array[VillageOccupancyVolume] = []
		) -> Array[VillageMassingPlan]:
	var result := _solve_frontier(terrain, arrival, primary_axis,
		village_program, tier, reserved_volumes)
	var out: Array[VillageMassingPlan] = []
	out.assign(result.plans)
	return out


static func _solve_frontier(terrain: VillageTerrainView, arrival: Vector2,
		primary_axis: Vector2, village_program: VillageProgram,
		tier: StringName,
		reserved_volumes: Array[VillageOccupancyVolume]) -> Dictionary:
	assert(terrain != null and village_program != null)
	assert(primary_axis.is_normalized())
	var program := village_program.massing_program
	if program == null:
		return {"plans": [], "reason": &"program"}
	var slots := program.slots_for_tier(tier)
	if slots.is_empty():
		return {"plans": [], "reason": &"tier"}
	var perches_by_asset: Dictionary = {}
	var base_perches_by_asset: Dictionary = {}
	var audit := {"reserved_volume_count": reserved_volumes.size(),
		"core_asset_id": program.core_asset_id,
		"base_perches": {}, "prototypes": {}}
	var datum_y := terrain.surface_y(arrival) + VillageTerrainSurvey.FLOOR_GUARD
	for slot: VillageMassingSlot in slots:
		if perches_by_asset.has(slot.asset_id):
			continue
		var spec := village_program.assets[slot.asset_id] as VillageAssetSpec
		var base := VillageTerrainSurvey.discover(
			terrain, arrival,
			spec.ground_contact_local_rect.size * 0.5, primary_axis,
			VillageTerrainSurvey.DEFAULT_SEARCH_RADIUS, SURVEY_LIMIT)
		base_perches_by_asset[slot.asset_id] = base
		audit.base_perches[String(slot.asset_id)] = base.size()
		var maximum_band := program.maximum_half_level_band(tier) \
			if spec.is_stackable() else 0
		perches_by_asset[slot.asset_id] = \
			VillageTerrainSurvey.expand_structural_variants(base, datum_y,
				program.vertical_profile, maximum_band)
	var reference: Array[VillageTerrainPerch] = base_perches_by_asset.get(
		program.core_asset_id, [])
	var core := VillageTerrainSurvey.best_core(reference)
	if core == null:
		return {"plans": [], "reason": &"terrain_perches", "audit": audit}
	# Natural relief is a ranking signal, not an existence precondition. The
	# same candidate vocabulary already contains bounded architectural half-level
	# variants, so flatter sites can construct a compact stepped district while
	# hilly sites win naturally supported perches by score. Keeping both cases in
	# one frontier avoids a separate flat-site layout and prevents a valid
	# settlement from disappearing merely because its local terrain is gentle.
	var prototypes_by_asset: Dictionary = {}
	for asset_id: StringName in perches_by_asset:
		var frontier := _candidate_frontier(perches_by_asset[asset_id], core)
		var spec := village_program.assets[asset_id] as VillageAssetSpec
		var template_slot := VillageMassingSlot.new(&"prototype", asset_id)
		var prototypes: Array[VillageMassingPlacement] = []
		for perch: VillageTerrainPerch in frontier:
			if perch.anchor.distance_to(core.anchor) \
					> VillageMassingProgram.CORE_RADIUS:
				continue
			for facade_index in 2:
				var prototype := VillageMassingPlacement.from_perch(
					template_slot, spec, perch, facade_index)
				if prototype.solid_shape().intersects(
						FeatureGroundShape.circle(arrival,
							VillageMassingProgram.ARRIVAL_RADIUS),
						VillageMassingProgram.BUILDING_GAP):
					continue
				if prototype.horizontal_reach_from(core.anchor) \
						> VillageMassingProgram.CORE_RADIUS:
					continue
				if not prototype.configure_entrance(spec, terrain,
						village_program.elevated_program):
					continue
				if _conflicts_reserved_volume(prototype, reserved_volumes):
					continue
				prototypes.append(prototype)
		prototypes_by_asset[asset_id] = prototypes
		audit.prototypes[String(asset_id)] = prototypes.size()
	var states: Array[Dictionary] = [{"placements": [], "score": 0.0}]
	var slot_frontier: Array[Dictionary] = []
	for slot: VillageMassingSlot in slots:
		var next: Array[Dictionary] = []
		var candidates: Array[VillageMassingPlacement] = \
			prototypes_by_asset[slot.asset_id]
		for state: Dictionary in states:
			# A skip branch makes rejection explicit without changing later role
			# identities. Final validity still enforces the tier's minimum fabric.
			next.append({"placements": (state.placements as Array).duplicate(),
				"score": float(state.score)})
			var admitted := 0
			for prototype: VillageMassingPlacement in candidates:
				var placement := prototype.copy_for_slot(slot)
				if not slot.admits_radius(
						placement.horizontal_reach_from(core.anchor)):
					continue
				if not _compatible(placement, state.placements):
					continue
				var placements: Array = (state.placements as Array).duplicate()
				placements.append(placement)
				next.append({"placements": placements,
					"score": _score(placements, core)})
				admitted += 1
				if admitted >= CANDIDATES_PER_STATE:
					break
		states = _prune_states(next)
		slot_frontier.append({"slot": slot.stable_key,
			"state_count": states.size(),
			"max_buildings": (states[0].placements as Array).size() \
				if not states.is_empty() else 0})
	audit["slot_frontier"] = slot_frontier
	if states.is_empty():
		return {"plans": [], "reason": &"packing", "audit": audit}
	states.sort_custom(_state_less)
	audit["frontier_state_count"] = states.size()
	audit["frontier_max_buildings"] = (states[0].placements as Array).size()
	var plans_by_count: Dictionary = {}
	var signatures: Dictionary = {}
	var first_rejection: StringName = &"packing"
	var rejection_counts: Dictionary = {}
	for state: Dictionary in states:
		var plan := _plan_from(state.placements, core)
		plan.required_building_count = program.minimum_buildings(tier)
		plan.accepted = true
		plan.accepted = plan.validate(program, tier)
		plan.reason = &"accepted" if plan.accepted \
			else plan.rejection_reason(program, tier)
		if not plan.accepted:
			rejection_counts[plan.reason] = int(
				rejection_counts.get(plan.reason, 0)) + 1
			if first_rejection == &"packing":
				first_rejection = plan.reason
			continue
		var signature := _signature(plan.placements)
		if signatures.has(signature):
			continue
		signatures[signature] = true
		var count := plan.placements.size()
		if not plans_by_count.has(count):
			plans_by_count[count] = []
		var group := plans_by_count[count] as Array
		if group.size() < PLANS_PER_BUILDING_COUNT:
			group.append(plan)
	var counts: Array = plans_by_count.keys()
	counts.sort()
	counts.reverse()
	var plans: Array[VillageMassingPlan] = []
	# Explore the ranked frontier by depth, not by exhausting every maximum-
	# count variant first. Each round still prefers the denser count, while a
	# structurally different minimum-count massing gets an early chance to prove
	# complete circulation instead of waiting behind near-duplicate failures.
	var maximum_group_size := 0
	for count: int in counts:
		maximum_group_size = maxi(maximum_group_size,
			(plans_by_count[count] as Array).size())
	for rank in maximum_group_size:
		for count: int in counts:
			var group := plans_by_count[count] as Array
			if rank < group.size():
				plans.append(group[rank])
	audit["rejection_counts"] = rejection_counts
	audit["accepted_plan_count"] = plans.size()
	return {"plans": plans,
		"reason": &"accepted" if not plans.is_empty() else first_rejection,
		"audit": audit}


static func _compatible(candidate: VillageMassingPlacement,
		placements: Array) -> bool:
	for value: Variant in placements:
		var other := value as VillageMassingPlacement
		# A later compact core may weave past open market activity, but it may
		# never descend through another inhabited shell. This proof keeps the
		# frontier focused on arrangements support can actually materialize.
		if candidate.overlaps(other, VillageMassingProgram.BUILDING_GAP) \
				or candidate.support_shape().intersects(other.solid_shape()) \
				or other.support_shape().intersects(candidate.solid_shape()) \
				or candidate.access_conflicts(other,
					VillageMassingProgram.ACCESS_CLEARANCE):
			return false
	return true


static func _conflicts_reserved_volume(candidate: VillageMassingPlacement,
		reserved: Array[VillageOccupancyVolume]) -> bool:
	if reserved.is_empty():
		return false
	var solid := VillageOccupancyVolume.new(VillageOccupancy.Role.SOLID,
		candidate.solid_centre, candidate.solid_half_extents,
		candidate.solid_angle, candidate.solid_min_y, candidate.solid_max_y,
		StringName("candidate.%s.solid" % candidate.stable_key))
	var access_delta := candidate.entrance_ground_contact - candidate.entrance
	var access_length := access_delta.length()
	var access: VillageOccupancyVolume
	if access_length > 0.001:
		access = VillageOccupancyVolume.new(VillageOccupancy.Role.HEADROOM,
			(candidate.entrance + candidate.entrance_ground_contact) * 0.5,
			Vector2(access_length * 0.5, candidate.access_half_width),
			access_delta.angle(), candidate.access_min_y,
			candidate.access_max_y,
			StringName("candidate.%s.access" % candidate.stable_key))
	for volume: VillageOccupancyVolume in reserved:
		if solid.overlaps(volume):
			return true
		if access != null and volume.role == VillageOccupancy.Role.SOLID \
				and access.overlaps(volume):
			return true
	return false


static func _score(placements: Array, core: VillageTerrainPerch) -> float:
	if placements.is_empty():
		return 0.0
	var radius := 0.0
	var natural := 0
	var half_rises := 0
	var bands: Dictionary = {}
	var nearest_sum := 0.0
	var facing_links := 0
	var platformizable_pairs := 0
	var ground_buildings := 0
	for value: Variant in placements:
		var placement := value as VillageMassingPlacement
		radius = maxf(radius, placement.horizontal_reach_from(core.anchor))
		natural += 1 if placement.perch.is_naturally_supported() else 0
		ground_buildings += 1 if placement.ground_accessible else 0
		half_rises += 1 if _is_half_rise(placement.perch) else 0
		bands[placement.perch.architectural_band] = true
		var nearest := VillageMassingProgram.MAX_LINK_RADIUS * 2.0
		for other_value: Variant in placements:
			var other := other_value as VillageMassingPlacement
			if other == placement:
				continue
			nearest = minf(nearest,
				placement.solid_centre.distance_to(other.solid_centre))
			if String(placement.stable_key) < String(other.stable_key) \
					and _doors_face(placement, other):
				facing_links += 1
			if String(placement.stable_key) < String(other.stable_key) \
					and _is_platformizable_pair(placement, other):
				platformizable_pairs += 1
		nearest_sum += nearest
	var count := placements.size()
	var mean_nearest := nearest_sum / float(count)
	return float(count) * 1000.0 - radius * 8.0 \
		- mean_nearest * 5.0 + float(natural) * 18.0 \
		+ float(mini(bands.size(),
			VillageMassingProgram.MIN_ELEVATION_BANDS)) * 100.0 \
		+ float(mini(half_rises, 2)) * 36.0 \
		+ float(mini(ground_buildings, 4)) * 22.0 \
		+ float(mini(platformizable_pairs, 3)) * 140.0 \
		+ float(mini(facing_links, VillageMassingProgram.MAX_AERIAL_LINKS)) \
			* 28.0


static func _state_less(a: Dictionary, b: Dictionary) -> bool:
	var a_count := (a.placements as Array).size()
	var b_count := (b.placements as Array).size()
	if a_count != b_count:
		return a_count > b_count
	if float(a.score) != float(b.score):
		return float(a.score) > float(b.score)
	return _signature(a.placements) < _signature(b.placements)


static func _prune_states(values: Array[Dictionary]) -> Array[Dictionary]:
	values.sort_custom(_state_less)
	if values.size() <= BEAM_WIDTH:
		return values
	var selected: Array[Dictionary] = []
	var selected_signatures: Dictionary = {}
	var compositions: Dictionary = {}
	# Keep the best representative of each partial elevation/support
	# composition before filling the remaining frontier by score. A narrow beam
	# can therefore discover a good complete fabric without erasing a useful
	# third height band during the first few semantic slots.
	for state: Dictionary in values:
		var composition := _composition_key(state.placements)
		if compositions.has(composition):
			continue
		compositions[composition] = true
		selected.append(state)
		selected_signatures[_signature(state.placements)] = true
		if selected.size() >= BEAM_WIDTH:
			return selected
	for state: Dictionary in values:
		var signature := _signature(state.placements)
		if selected_signatures.has(signature):
			continue
		selected.append(state)
		if selected.size() >= BEAM_WIDTH:
			break
	return selected


static func _composition_key(placements: Array) -> String:
	var bands: Dictionary = {}
	var natural := 0
	var half_rises := 0
	var platformizable_pairs := 0
	for value: Variant in placements:
		var placement := value as VillageMassingPlacement
		bands[placement.perch.architectural_band] = true
		natural += 1 if placement.perch.is_naturally_supported() else 0
		half_rises += 1 if _is_half_rise(placement.perch) else 0
		for other_value: Variant in placements:
			var other := other_value as VillageMassingPlacement
			if String(placement.stable_key) < String(other.stable_key) \
					and _is_platformizable_pair(placement, other):
				platformizable_pairs += 1
	var ordered_bands: Array = bands.keys()
	ordered_bands.sort()
	var band_parts: PackedStringArray = []
	for band: int in ordered_bands:
		band_parts.append(str(band))
	return "%d:%d:%d:%d:%s" % [placements.size(), natural, half_rises,
		platformizable_pairs, ",".join(band_parts)]


static func _candidate_frontier(values: Array,
		core: VillageTerrainPerch) -> Array[VillageTerrainPerch]:
	var natural: Array[VillageTerrainPerch] = []
	var retained_base: Array[VillageTerrainPerch] = []
	var retained_by_band: Dictionary = {}
	for value: Variant in values:
		var perch := value as VillageTerrainPerch
		if perch.is_naturally_supported():
			natural.append(perch)
		elif perch.architectural_band <= 0:
			retained_base.append(perch)
		else:
			if not retained_by_band.has(perch.architectural_band):
				retained_by_band[perch.architectural_band] = []
			(retained_by_band[perch.architectural_band] as Array).append(perch)
	var local_less := func(a: VillageTerrainPerch,
			b: VillageTerrainPerch) -> bool:
		return _local_candidate_less(a, b, core)
	natural.sort_custom(local_less)
	retained_base.sort_custom(local_less)
	var retained_bands: Array = retained_by_band.keys()
	retained_bands.sort()
	for band: int in retained_bands:
		(retained_by_band[band] as Array).sort_custom(local_less)
	var out: Array[VillageTerrainPerch] = []
	var natural_index := 0
	var retained_indices: Array[int] = [0]
	var retained_groups: Array = [retained_base]
	for band: int in retained_bands:
		retained_groups.append(retained_by_band[band])
		retained_indices.append(0)
	# A stratified frontier encodes the structural priority without erasing the
	# retaining-edge candidates that create the vertical fabric. This remains
	# one general search vocabulary: the beam, not a later fallback, decides the
	# final mix.
	while natural_index < natural.size() \
			or _groups_have_remaining(retained_groups, retained_indices):
		for _index in NATURAL_FRONTIER_RUN:
			if natural_index >= natural.size():
				break
			out.append(natural[natural_index])
			natural_index += 1
		for group_index in retained_groups.size():
			var group: Array = retained_groups[group_index]
			var index: int = retained_indices[group_index]
			if index >= group.size():
				continue
			out.append(group[index])
			retained_indices[group_index] = index + 1
	return out


static func _groups_have_remaining(groups: Array, indices: Array) -> bool:
	for index in groups.size():
		if int(indices[index]) < (groups[index] as Array).size():
			return true
	return false


static func _local_candidate_less(a: VillageTerrainPerch,
		b: VillageTerrainPerch, core: VillageTerrainPerch) -> bool:
	var a_distance := a.anchor.distance_squared_to(core.anchor)
	var b_distance := b.anchor.distance_squared_to(core.anchor)
	if a_distance != b_distance:
		return a_distance < b_distance
	if a.useful_relief_score != b.useful_relief_score:
		return a.useful_relief_score > b.useful_relief_score
	if a.distance_from_arrival != b.distance_from_arrival:
		return a.distance_from_arrival < b.distance_from_arrival
	return String(a.candidate_key) < String(b.candidate_key)


static func _signature(placements: Array) -> String:
	var parts: PackedStringArray = []
	for value: Variant in placements:
		var placement := value as VillageMassingPlacement
		parts.append("%s@%s" % [placement.stable_key,
			"%s/f%d" % [placement.perch.candidate_key,
				placement.facade_index]])
	return "|".join(parts)


static func _plan_from(values: Array,
		core: VillageTerrainPerch) -> VillageMassingPlan:
	var plan := VillageMassingPlan.new()
	plan.core = core
	plan.placements.assign(values)
	plan.building_count = plan.placements.size()
	if plan.placements.is_empty():
		return plan
	var natural := 0
	var half_rises := 0
	var bands: Dictionary = {}
	var nearest_sum := 0.0
	var platformizable_pairs := 0
	for placement: VillageMassingPlacement in plan.placements:
		plan.core_radius = maxf(plan.core_radius,
			placement.horizontal_reach_from(core.anchor))
		natural += 1 if placement.perch.is_naturally_supported() else 0
		plan.ground_building_count += 1 if placement.ground_accessible else 0
		half_rises += 1 if _is_half_rise(placement.perch) else 0
		bands[placement.perch.architectural_band] = true
		var nearest := VillageMassingProgram.MAX_LINK_RADIUS * 2.0
		for other: VillageMassingPlacement in plan.placements:
			if other == placement:
				continue
			nearest = minf(nearest,
				placement.solid_centre.distance_to(other.solid_centre))
			if String(placement.stable_key) < String(other.stable_key) \
					and _is_platformizable_pair(placement, other):
				platformizable_pairs += 1
		nearest_sum += nearest
	plan.natural_ratio = float(natural) / float(plan.placements.size())
	plan.half_rise_count = half_rises
	# This solver's vocabulary currently contains only natural shelves and
	# retaining terraces, both attached to real terrain. Future platform and
	# cantilever placements will reduce this ratio through the same audit field.
	plan.terrain_support_ratio = 1.0
	plan.elevation_band_count = bands.size()
	plan.platformizable_pair_count = platformizable_pairs
	plan.mean_nearest_distance = nearest_sum / float(plan.placements.size())
	return plan


static func _is_half_rise(perch: VillageTerrainPerch) -> bool:
	return perch != null and perch.architectural_band > 0 \
		and perch.architectural_band % 2 == 1


static func _is_platformizable_pair(a: VillageMassingPlacement,
		b: VillageMassingPlacement) -> bool:
	return not a.ground_accessible and not b.ground_accessible \
		and is_equal_approx(a.floor_y, b.floor_y) \
		and a.entrance.distance_to(b.entrance) \
			<= VillageMassingProgram.MAX_PLATFORM_JOIN_RADIUS + 0.001


static func _doors_face(a: VillageMassingPlacement,
		b: VillageMassingPlacement) -> bool:
	var delta := b.entrance - a.entrance
	var distance := delta.length()
	if distance <= 0.001 or distance > VillageMassingProgram.MAX_LINK_RADIUS:
		return false
	var direction := delta / distance
	return a.entrance_outward.dot(direction) >= 0.25 \
		and b.entrance_outward.dot(-direction) >= 0.25


static func _rejected(reason: StringName,
		audit: Dictionary = {}) -> VillageMassingPlan:
	var plan := VillageMassingPlan.new()
	plan.reason = reason
	plan.candidate_audit = audit
	return plan
