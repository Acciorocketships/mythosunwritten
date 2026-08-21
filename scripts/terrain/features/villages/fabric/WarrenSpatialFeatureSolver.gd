class_name WarrenSpatialFeatureSolver
extends RefCounted

## Commits topology-first composed features into the still-mutable fine grid.
## Each accepted feature owns one atomic reservation and, where appropriate,
## its exact private/structural cells and construction transform. Generic room
## and roof compilation may respond to these facts but never recreate them.
const TARGET_SKYWALKS := 3
const TARGET_PREFAB_LANDMARKS := 4
const MIN_TOWER_ANNEXES_PER_THREE_STOREY_LINEAGE := \
	WarrenRoomCompositionPlanner.THREE_STOREY_TOWER_ANNEXES
const MIN_TOWER_ANNEXES_PER_TALL_LINEAGE := \
	WarrenRoomCompositionPlanner.TALL_TOWER_ANNEXES
const TARGET_BALCONIES := 6
const MIN_BALCONY_BUILDINGS := 3
const MAX_BALCONIES_PER_BUILDING := 2
const TARGET_ROOM_OUTCROPPINGS := 6
const MIN_COURT_SIDE_COUNT := 3
const MIN_COURT_DAYLIGHT_MACRO_COLUMNS := 2
const MAX_CANTILEVER_SUPPORT_ASSIGNMENT_NODES := 4096
const SKY_DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD,
]

static var last_failure := ""
static var last_audit: Dictionary = {}
static var last_skywalk_diagnostic: Dictionary = {}
static var last_outcropping_diagnostic: Dictionary = {}
static var last_annex_diagnostic: Dictionary = {}
static var _last_interstitial_rejection := ""


static func solve(grid: WarrenSpatialGrid, source: WarrenVolumePlan,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		preplanned_skywalks: Array[Dictionary] = [],
		preplanned_courtyard_bridge: Dictionary = {},
		preplanned_market: Dictionary = {},
		preplanned_landmarks: Array[Dictionary] = [],
		construction_program: SettlementFabricProgram = null,
		composition_audit: Dictionary = {}) \
		-> Array[WarrenFeatureReservation]:
	last_failure = ""
	last_audit = {}
	last_skywalk_diagnostic = {}
	last_outcropping_diagnostic = {}
	last_annex_diagnostic = {}
	if grid == null or grid.is_sealed() or source == null \
			or not source.is_sealed() or buildings.is_empty() or supports == null \
			or not supports.is_sealed():
		last_failure = "missing mutable grid, source volume, buildings, or supports"
		return [] as Array[WarrenFeatureReservation]
	var out: Array[WarrenFeatureReservation] = []
	var scale_profile := WarrenVillageScaleProfile.for_id(StringName(
		source.mass_context.get(&"scale_profile_id",
			WarrenVillageScaleProfile.LARGE)))
	if scale_profile == null:
		last_failure = "spatial features have an invalid scale profile"
		return [] as Array[WarrenFeatureReservation]
	var target_skywalks := scale_profile.skywalk_range.x
	var target_landmarks := scale_profile.landmark_range.x
	# Occupied projections are the town's visual richness: search for the top
	# of each declared range and gate acceptance at its floor, instead of
	# stopping the search the moment the minimum is met.
	var minimum_balconies := scale_profile.balcony_range.x
	var target_balconies := scale_profile.balcony_range.y
	var minimum_outcroppings := scale_profile.cantilever_range.x
	var target_outcroppings := scale_profile.cantilever_range.y
	# A village whose ground street holds no measured bazaar runs without one;
	# a profile that requires the market never reaches this stage marketless
	# because the hero-feature beam already rejected the town.
	var market: WarrenFeatureReservation = null
	if not preplanned_market.is_empty():
		market = _reserve_preplanned_market(grid, buildings, supports,
			preplanned_market)
		if market == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(market)
	elif scale_profile.requires_covered_market:
		last_failure = "required covered market was never preplanned"
		return [] as Array[WarrenFeatureReservation]
	var gateway_records := composition_audit.get(
		"perimeter_gateway_support_records", []) as Array
	var gateway_resolution: Dictionary = {}
	var gateway_supports := _reserve_frontier_gateway_supports(grid, buildings,
		supports, gateway_records, construction_program, out, source.world_seed,
		gateway_resolution)
	if int(gateway_resolution.get("satisfied_count", 0)) \
			!= gateway_records.size():
		if last_failure.is_empty():
			last_failure = "only %d of %d frontier gateway load paths fit" % [
				int(gateway_resolution.get("satisfied_count", 0)),
				gateway_records.size()]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(gateway_supports)
	var landmarks := _record_preplanned_landmarks(grid, supports,
		preplanned_landmarks)
	if landmarks.size() < target_landmarks:
		last_failure = "only %d of %d topology-first prefab landmarks survived" \
			% [landmarks.size(), target_landmarks]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(landmarks)
	var residual_jetty_supports := _reserve_residual_jetty_supports(grid,
		buildings, supports, construction_program, out, source.world_seed)
	if not last_failure.is_empty():
		return [] as Array[WarrenFeatureReservation]
	out.append_array(residual_jetty_supports)
	var arcade_overhang_supports := _reserve_arcade_overhang_supports(grid,
		buildings, supports, construction_program, out, source.world_seed)
	if not last_failure.is_empty():
		return [] as Array[WarrenFeatureReservation]
	out.append_array(arcade_overhang_supports)
	var room_overhang_supports: Array[WarrenFeatureReservation] = []
	var skywalks := _reserve_preplanned_skywalks(grid, buildings, supports,
		preplanned_skywalks, landmarks) if not preplanned_skywalks.is_empty() \
		else _reserve_skywalks(grid, buildings, supports, source.world_seed,
			target_skywalks)
	if skywalks.size() < target_skywalks:
		var detail := last_failure
		last_failure = "only %d of %d topology-first skywalks fit: %s (%s)" % [
			skywalks.size(), target_skywalks, detail,
			last_skywalk_diagnostic]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(skywalks)
	var courtyard_bridge: WarrenFeatureReservation
	if scale_profile.requires_elevated_courtyard:
		courtyard_bridge = _reserve_preplanned_courtyard_bridge_house(grid,
			buildings, supports, preplanned_courtyard_bridge)
		if courtyard_bridge == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(courtyard_bridge)
	# The court transaction sees the cantilever's actual committed
	# PRIVATE_VOLUME. It never counts its endpoint, clearance envelope, or visual
	# mesh as an enclosing facade, and the three ordinary skywalks remain fully
	# independent circulation features elsewhere in the mountain.
	var court: WarrenFeatureReservation
	if scale_profile.requires_elevated_courtyard:
		court = _reserve_courtyard(grid, source, buildings, supports)
		if court == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(court)
	room_overhang_supports = _reserve_room_overhang_supports(grid,
		buildings, supports, construction_program, out, source.world_seed)
	if not last_failure.is_empty():
		return [] as Array[WarrenFeatureReservation]
	out.append_array(room_overhang_supports)
	# Cantilever support is structure, not decoration. Reserve every measured
	# brace course before tower-breaking annexes, facade relief, or balconies are
	# allowed to spend the same clearance. This order makes the composed room DAG
	# authoritative and prevents an optional side room from blocking the bracket
	# that keeps a primary upper room physically attached.
	var outcroppings := _reserve_room_outcroppings(grid, buildings, supports,
		source.world_seed, construction_program, out, target_outcroppings)
	var unresolved_outcroppings := int(last_outcropping_diagnostic.get(
		"unresolved_integrated_cantilever_count", 0))
	var unsupported_irregular := int(last_outcropping_diagnostic.get(
		"unsupported_irregular_projection_count", 0))
	if unresolved_outcroppings != 0 or unsupported_irregular != 0:
		last_failure = ("%d cantilevers and %d irregular room projections " \
			+ "remain unsupported: %s") % [unresolved_outcroppings,
			unsupported_irregular,
			JSON.stringify(last_outcropping_diagnostic)]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(outcroppings)
	var raw_tower_annex_targets := composition_audit.get(
		"tower_relief_annex_target_by_lineage", {}) as Dictionary
	# Full-room corner overlaps remain available as diagnostic recipes, but are
	# deliberately not a production repair. If the room compiler still needs one
	# to disguise a vertical shaft, reject this construction candidate and let the
	# bounded town search choose coherent massing instead. Shallow embedded oriels
	# are selected independently below and remain the production facade relief.
	if target_outcroppings == 0 and not raw_tower_annex_targets.is_empty():
		last_failure = ("room composition requires disabled diagonal outcroppings: " \
			+ "%s") % [raw_tower_annex_targets]
		return [] as Array[WarrenFeatureReservation]
	var tower_relief := _tower_annex_targets_after_structural_outcroppings(
		raw_tower_annex_targets if target_outcroppings > 0 else {},
		outcroppings)
	var tower_annex_targets := tower_relief.targets as Dictionary
	var tower_annexes := _reserve_tower_annexes(grid, buildings, supports,
		source.world_seed, construction_program, out, tower_annex_targets)
	var tower_annex_diagnostic := last_annex_diagnostic.duplicate(true)
	var required_tower_annexes := 0
	for target_value: Variant in tower_annex_targets.values():
		required_tower_annexes += int(target_value)
	var tower_annex_relief_units := _tower_annex_relief_units(tower_annexes)
	if tower_annex_relief_units < required_tower_annexes:
		var annexes_by_source: Dictionary = {}
		for annex: WarrenFeatureReservation in tower_annexes:
			var source_id := StringName(annex.audit.annex_source_parcel_id)
			if not annexes_by_source.has(source_id):
				annexes_by_source[source_id] = []
			(annexes_by_source[source_id] as Array).append({
				"storey": int(annex.audit.annex_source_storey_index),
				"facade": String(annex.audit.annex_vertical_facade_key),
				"recipe": StringName(annex.audit.annex_recipe_id),
			})
		last_failure = ("tower-breaking room annexes supply only %d of %d " \
			+ "facade-relief units (%d assets): %s") % [
			tower_annex_relief_units, required_tower_annexes,
			tower_annexes.size(), annexes_by_source]
		return [] as Array[WarrenFeatureReservation]
	# A same-storey full-room bump-out is a diagonal union, not a small room
	# attached beyond one facade. First satisfy the mandatory anti-shaft targets
	# above, then search every eligible upper tower globally for the remaining
	# visual quota. Choosing exactly N source IDs before spatial qualification made
	# one blocked tower reject towns that still had several clear corner overlaps.
	out.append_array(tower_annexes)
	var desired_extra_diagonal := maxi(0,
		target_outcroppings - outcroppings.size() - tower_annexes.size())
	var extra_diagonal_outcrops: Array[WarrenFeatureReservation] = []
	var extra_diagonal_diagnostic: Dictionary = {}
	if desired_extra_diagonal > 0:
		var diagonal_pool := _diagonal_outcrop_target_pool(buildings,
			source.world_seed)
		extra_diagonal_outcrops = _reserve_tower_annexes(grid, buildings,
			supports, source.world_seed, construction_program, out, diagonal_pool,
			&"tower_annex", desired_extra_diagonal)
		extra_diagonal_diagnostic = last_annex_diagnostic.duplicate(true)
		tower_annexes.append_array(extra_diagonal_outcrops)
	var room_outcropping_count := outcroppings.size() + tower_annexes.size()
	if room_outcropping_count < minimum_outcroppings:
		last_failure = ("only %d of %d full-scale room outcroppings exist; " \
			+ "vertical=%d diagonal-overlap=%d: %s") % [
			room_outcropping_count, minimum_outcroppings, outcroppings.size(),
			tower_annexes.size(), JSON.stringify(extra_diagonal_diagnostic)]
		return [] as Array[WarrenFeatureReservation]
	out.append_array(extra_diagonal_outcrops)
	var diagonal_outcrop_sources: Dictionary = {}
	for annex: WarrenFeatureReservation in tower_annexes:
		diagonal_outcrop_sources[StringName(
			annex.audit.annex_source_parcel_id)] = true
	var balconies := _reserve_balconies(grid, buildings, supports,
		source.world_seed, construction_program, out, target_balconies)
	var balcony_buildings: Dictionary = {}
	for balcony: WarrenFeatureReservation in balconies:
		balcony_buildings[StringName(balcony.audit.balcony_building_id)] = true
	var minimum_balcony_buildings := mini(MIN_BALCONY_BUILDINGS,
		minimum_balconies)
	if balconies.size() < minimum_balconies \
			or balcony_buildings.size() < minimum_balcony_buildings:
		# A balcony quota is facade richness, not structure. In one-pass mode a
		# shortfall ships a plainer town instead of no town.
		if not WarrenTownSolver.feature_quotas_are_advisory():
			last_failure = ("only %d balconies across %d buildings fit; " \
				+ "need %d across %d; candidate audit=%s") \
				% [balconies.size(), balcony_buildings.size(),
					minimum_balconies, minimum_balcony_buildings,
					last_skywalk_diagnostic]
			return [] as Array[WarrenFeatureReservation]
		WarrenVolumetricSolver.last_advisory_shortfalls["balconies"] = \
			balconies.size()
		WarrenVolumetricSolver.last_advisory_shortfalls["balconies_target"] = \
			minimum_balconies
	out.append_array(balconies)
	var wraparound_balcony_count := 0
	for balcony: WarrenFeatureReservation in balconies:
		wraparound_balcony_count += int(bool(balcony.audit.get(
			"balcony_wraparound", false)))
	# Every sub-tolerance interstitial slot must now compile as exactly one
	# typed two-owner construction, or the town is rejected with a reason-coded
	# refusal. This runs after every required feature reservation so a join can
	# never steal a skywalk, market, support, annex, or balcony volume, and
	# before optional facade bays so decoration cannot consume a required join.
	var interstitial_result := _reserve_interstitial_joins(grid, buildings,
		supports, source.world_seed, construction_program, out)
	if not String(interstitial_result.get("failure", "")).is_empty():
		last_failure = String(interstitial_result.failure)
		return [] as Array[WarrenFeatureReservation]
	var interstitial_joins: Array[WarrenFeatureReservation] = []
	interstitial_joins.assign(interstitial_result.get("features", []) as Array)
	out.append_array(interstitial_joins)
	# Integrated room cantilevers above are massing facts. Add a separate finite
	# facade-bay pass for the shallow, roofed whole-room projections that break a
	# large wall plane. It runs last so it can never steal a required support,
	# balcony, skywalk, or market reservation.
	var facade_bay_target_count := maxi(2, target_balconies - 1)
	var facade_bay_targets := _facade_bay_targets(buildings, tower_annexes,
		facade_bay_target_count, source.world_seed)
	var facade_bays := _reserve_tower_annexes(grid, buildings, supports,
		source.world_seed, construction_program, out, facade_bay_targets,
		&"facade_bay", facade_bay_target_count)
	var facade_bay_diagnostic := last_annex_diagnostic.duplicate(true)
	out.append_array(facade_bays)
	last_audit = {
		"elevated_courtyard_count": int(
			scale_profile.requires_elevated_courtyard),
		"covered_market_count": int(market != null),
		"frontier_gateway_support_count": gateway_supports.size(),
		"arcade_overhang_support_count": arcade_overhang_supports.size(),
		"room_overhang_support_count": room_overhang_supports.size(),
		"frontier_gateway_direct_bearing_count": int(
			gateway_resolution.get("direct_bearing_count", 0)),
		"prefab_landmark_count": landmarks.size(),
		"enclosed_skywalk_count": skywalks.size(),
		"courtyard_bridge_house_count": int(
			scale_profile.requires_elevated_courtyard),
		"tower_annex_count": tower_annexes.size(),
		"tower_annex_source_count": tower_annex_targets.size(),
		"tower_annex_relief_unit_count": tower_annex_relief_units,
		"required_tower_annex_relief_unit_count": required_tower_annexes,
		"tower_relief_structural_outcropping_count": int(
			tower_relief.satisfied_count),
		"facade_bay_target_count": facade_bay_target_count,
		"facade_bay_source_count": facade_bay_targets.size(),
		"facade_bay_count": facade_bays.size(),
		"facade_bay_diagnostic": facade_bay_diagnostic,
		"tower_annex_diagnostic": tower_annex_diagnostic,
		"extra_diagonal_outcrop_diagnostic": extra_diagonal_diagnostic,
		"interstitial_join_count": interstitial_joins.size(),
		"interstitial_join_class_counts": interstitial_result.get(
			"class_counts", {}),
		"usable_balcony_count": balconies.size(),
		"balcony_building_count": balcony_buildings.size(),
		"wraparound_balcony_count": wraparound_balcony_count,
		"room_outcropping_count": room_outcropping_count,
		"vertical_floorplate_outcropping_count": outcroppings.size(),
		"full_scale_diagonal_overlap_count": tower_annexes.size(),
		"full_scale_diagonal_overlap_source_count":
			diagonal_outcrop_sources.size(),
		"feature_count": out.size(),
	}
	last_audit.merge(last_outcropping_diagnostic, false)
	if courtyard_bridge != null:
		last_audit.merge(courtyard_bridge.audit, false)
	if court != null:
		last_audit.merge(court.audit, false)
	if market != null:
		last_audit.merge(market.audit, false)
	return out


static func _tower_annex_targets_after_structural_outcroppings(
		targets: Dictionary,
		outcroppings: Array[WarrenFeatureReservation]) -> Dictionary:
	## A shifted occupied upper room with its exact bracket course is already a
	## macroscopic silhouette break. Count it before asking for smaller occupied
	## annexes; otherwise a decorative child can be required to overlap the very
	## support that makes the larger room possible.
	var remaining := targets.duplicate()
	var satisfied := 0
	for outcropping: WarrenFeatureReservation in outcroppings:
		var source_id := StringName(outcropping.audit.get(
			"outcrop_source_parcel_id", &""))
		var target := int(remaining.get(source_id, 0))
		if source_id.is_empty() or target <= 0:
			continue
		target -= 1
		satisfied += 1
		if target <= 0:
			remaining.erase(source_id)
		else:
			remaining[source_id] = target
	return {"targets": remaining, "satisfied_count": satisfied}


static func _tower_annex_relief_units(
		annexes: Array[WarrenFeatureReservation]) -> int:
	## A reviewed corner/wrap room changes two facade planes and is therefore a
	## stronger macro silhouette event than one flat bay. Quotas describe visible
	## relief, not an arbitrary number of child nodes.
	var units := 0
	for annex: WarrenFeatureReservation in annexes:
		var recipe_id := String(annex.audit.get("annex_recipe_id", ""))
		units += 2 if recipe_id.contains("corner") else 1
	return units


static func _diagonal_outcrop_target_pool(
		buildings: Array[WarrenBuildingVolume], world_seed: int) -> Dictionary:
	## Return every real upper-storey tower floorplate as a bounded target pool.
	## A tower room is 3 x 3 m, exactly the size of the reviewed diagonal corner
	## recipe before their shared 1.5 x 1.5 m quadrant is removed. Larger parent
	## rooms would make the same recipe read as a small applique, so they are not
	## eligible for this full-scale contract.
	var out: Dictionary = {}
	var eligible_storeys_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.kind != &"tower" or room.source_storey_index < 1:
				continue
			if not eligible_storeys_by_source.has(room.source_parcel_id):
				eligible_storeys_by_source[room.source_parcel_id] = {}
			(eligible_storeys_by_source[room.source_parcel_id] \
				as Dictionary)[room.source_storey_index] = true
	var candidates: Array[Dictionary] = []
	for source_value: Variant in eligible_storeys_by_source.keys():
		var source_id := StringName(source_value)
		var storeys := eligible_storeys_by_source[source_id] as Dictionary
		candidates.append({
			"source_id": source_id,
			"capacity": mini(storeys.size(), 2),
			"upper_storey": storeys.keys().max() if not storeys.is_empty() else -1,
			"tie": posmod(Helper._mix64(world_seed \
				^ String(source_id).hash() ^ 0x444941474f4e414c), 1000003),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.upper_storey) != int(b.upper_storey):
			return int(a.upper_storey) > int(b.upper_storey)
		return int(a.tie) < int(b.tie))
	for candidate: Dictionary in candidates:
		out[StringName(candidate.source_id)] = int(candidate.capacity)
	return out


static func _reserve_frontier_gateway_supports(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		records: Array, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation], world_seed: int,
		resolution: Dictionary = {}) \
		-> Array[WarrenFeatureReservation]:
	## A gateway house is mostly an ordinary terrain-rooted base room. Its second
	## 3 m bay crosses an existing lower street, so this transaction fastens one
	## measured two-bracket course to the exact seam between the grounded and
	## spanning halves. Nothing is stamped into the public-air cells below. If
	## later macro composition has placed a complete structural room directly
	## beneath the former span, that stronger final bearing fact supersedes the
	## source gateway recipe: record the load path without drawing brackets into
	## the room that now carries it.
	var out: Array[WarrenFeatureReservation] = []
	resolution.clear()
	resolution["satisfied_count"] = 0
	resolution["direct_bearing_count"] = 0
	if records.is_empty():
		return out
	if program == null or program.recipe(&"outcrop.support.bracketed.2") == null:
		last_failure = "frontier gateways lack the measured bracket vocabulary"
		return out
	var room_by_source: Dictionary = {}
	var building_by_room: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if room.source_storey_index == 0:
				room_by_source[room.source_parcel_id] = room
	var ordered := records.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return StringName(a.parcel_id) < StringName(b.parcel_id))
	for source_record_value: Variant in ordered:
		var source_record := source_record_value as Dictionary
		var source_id := StringName(source_record.get("parcel_id", &""))
		var room := room_by_source.get(source_id) as WarrenRoomStamp
		var building := building_by_room.get(
			room.stable_id if room != null else &"") as WarrenBuildingVolume
		if room == null or building == null \
				or room.lattice_origin.y != int(source_record.get("base_band", -1)):
			last_failure = "frontier gateway %s lost its exact base room" % source_id
			return [] as Array[WarrenFeatureReservation]
		var geometry := _frontier_gateway_geometry(room, source_record)
		var support_records := _cantilever_support_records(room, geometry, grid)
		if support_records.is_empty() \
				and _frontier_gateway_is_directly_borne(room, geometry, grid):
			resolution["satisfied_count"] = int(
				resolution.satisfied_count) + 1
			resolution["direct_bearing_count"] = int(
				resolution.direct_bearing_count) + 1
			continue
		if support_records.size() != 1:
			last_failure = ("frontier gateway %s lacks one passage-safe support " \
				+ "course: geometry=%s records=%s") % [source_id, geometry,
					support_records]
			return [] as Array[WarrenFeatureReservation]
		var related := {room.stable_id: true}
		var support_analysis := _outcrop_support_analysis(support_records,
			related, buildings, existing_features, program, world_seed)
		if not StringName(support_analysis.conflict).is_empty():
			last_failure = "frontier gateway %s support conflicts with %s" % [
				source_id, StringName(support_analysis.conflict)]
			return [] as Array[WarrenFeatureReservation]
		var feature_id := StringName("spatial.feature.frontier_gateway.%02d" \
			% out.size())
		var tx := grid.begin_transaction(feature_id)
		if not tx.reserve(room.private_cells,
				WarrenSpatialGrid.Reservation.FEATURE, feature_id) or not tx.commit():
			last_failure = "frontier gateway %s could not reserve its base-room seam" \
				% source_id
			return [] as Array[WarrenFeatureReservation]
		var feature := WarrenFeatureReservation.new(feature_id,
			&"frontier_gateway_support")
		if not feature.add_reserved_cells(room.private_cells) \
				or not feature.add_endpoint(room.private_cells[0], building.stable_id) \
				or not feature.set_support_node(building.stable_id):
			last_failure = "frontier gateway %s support identity failed" % source_id
			return [] as Array[WarrenFeatureReservation]
		for support_record: Dictionary in support_records:
			if not feature.add_construction_record(
					StringName(support_record.recipe_id),
					support_record.origin as Vector3i,
					int(support_record.yaw_quarters), &"gateway_bracket"):
				last_failure = "frontier gateway %s bracket record failed" % source_id
				return [] as Array[WarrenFeatureReservation]
		if not feature.set_audit_facts({
				"gateway_source_parcel_id": source_id,
				"gateway_room_id": room.stable_id,
				"gateway_building_id": building.stable_id,
				"gateway_is_terrain_anchored": true,
				"gateway_bearing_column": source_record.bearing_column,
				"gateway_unsupported_column": source_record.unsupported_column,
				"gateway_projection_direction":
					source_record.projection_direction,
				"gateway_lower_route_band": int(source_record.route_band),
				"gateway_support_course_count": support_records.size(),
				"gateway_support_neighbor_room_ids":
					support_analysis.neighbor_room_ids,
			}) or not feature.seal(grid, supports):
			last_failure = "frontier gateway %s support seal failed: %s" % [
				source_id, feature.last_rejection]
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
		resolution["satisfied_count"] = int(resolution.satisfied_count) + 1
	return out


static func _reserve_residual_jetty_supports(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation], world_seed: int) \
		-> Array[WarrenFeatureReservation]:
	## Residual bridge rooms with two flanks need no added construction. A room
	## admitted from one exact flank is different: its sealed room audit carries
	## the measured bracket courses selected with the topology, and this adapter
	## reserves those attachments before balconies or facade relief can spend the
	## same envelope.
	var out: Array[WarrenFeatureReservation] = []
	if program == null:
		last_failure = "residual jetties lack a construction program"
		return out
	var ordered: Array[Dictionary] = []
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			var records := room.audit.get("bridge_support_records", []) as Array
			if records.is_empty():
				continue
			ordered.append({"building": building, "room": room,
				"records": records})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String((a.room as WarrenRoomStamp).stable_id) \
			< String((b.room as WarrenRoomStamp).stable_id))
	for entry: Dictionary in ordered:
		var building := entry.building as WarrenBuildingVolume
		var room := entry.room as WarrenRoomStamp
		var records := entry.records as Array
		var related := {room.stable_id: true}
		for flank_value: Variant in room.audit.get(
				"bridge_support_room_ids", []) as Array:
			related[StringName(flank_value)] = true
		var analysis := _outcrop_support_analysis(records, related, buildings,
			existing_features, program, world_seed)
		if not StringName(analysis.conflict).is_empty():
			last_failure = "residual jetty %s support conflicts with %s" % [
				room.stable_id, StringName(analysis.conflict)]
			return [] as Array[WarrenFeatureReservation]
		var feature_id := StringName("spatial.feature.residual_jetty.%02d" \
			% out.size())
		var tx := grid.begin_transaction(feature_id)
		if not tx.reserve(room.private_cells,
				WarrenSpatialGrid.Reservation.FEATURE, feature_id) or not tx.commit():
			last_failure = "residual jetty %s could not reserve its bracket seam" \
				% room.stable_id
			return [] as Array[WarrenFeatureReservation]
		var feature := WarrenFeatureReservation.new(feature_id,
			&"frontier_gateway_support")
		if not feature.add_reserved_cells(room.private_cells) \
				or not feature.add_endpoint(room.private_cells[0],
					building.stable_id) \
				or not feature.set_support_node(building.stable_id):
			last_failure = "residual jetty %s support identity failed" \
				% room.stable_id
			return [] as Array[WarrenFeatureReservation]
		for record_value: Variant in records:
			var record := record_value as Dictionary
			if not feature.add_construction_record(
					StringName(record.recipe_id), record.origin as Vector3i,
					int(record.yaw_quarters), StringName(record.role)):
				last_failure = "residual jetty %s bracket record failed" \
					% room.stable_id
				return [] as Array[WarrenFeatureReservation]
		if not feature.set_audit_facts({
				"gateway_room_id": room.stable_id,
				"gateway_is_terrain_anchored": false,
				"gateway_is_flank_borne": true,
				"gateway_support_course_count": records.size(),
				"gateway_support_neighbor_room_ids":
					analysis.neighbor_room_ids,
			}) or not feature.seal(grid, supports):
			last_failure = "residual jetty %s support seal failed: %s" % [
				room.stable_id, feature.last_rejection]
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	return out


static func _reserve_arcade_overhang_supports(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation], world_seed: int) \
		-> Array[WarrenFeatureReservation]:
	## A larger upper plate may bridge one exact 3 x 3 m route bay while half of
	## it bears on a tower.  That is useful carved-city massing, but the outer end
	## cannot be treated as borne merely because the size-mismatch cantilever is
	## outside the decorative diagonal-outcrop grammar.  Wrap every such passage
	## in a complete four-sided stone base, with arches only where the exact route
	## continues through its perimeter.
	var out: Array[WarrenFeatureReservation] = []
	if program == null:
		last_failure = "arcade overhangs lack the measured foundation vocabulary"
		return out
	var rooms_by_source: Dictionary = {}
	var building_by_room: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = [] \
					as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var candidates: Array[Dictionary] = []
	for rooms_value: Variant in rooms_by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			var geometry := _arcade_overhang_geometry(lower, upper, grid)
			if geometry.is_empty():
				continue
			candidates.append({"lower": lower, "upper": upper,
				"geometry": geometry})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String((a.upper as WarrenRoomStamp).stable_id) \
			< String((b.upper as WarrenRoomStamp).stable_id))
	for candidate: Dictionary in candidates:
		var lower := candidate.lower as WarrenRoomStamp
		var upper := candidate.upper as WarrenRoomStamp
		var building := building_by_room.get(upper.stable_id) \
			as WarrenBuildingVolume
		var geometry := candidate.geometry as Dictionary
		if building == null:
			last_failure = "arcade overhang %s lost its upper building" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		var record := _arcade_overhang_support_record(upper, geometry)
		if record.is_empty():
			last_failure = "arcade overhang %s has no exact foundation transform" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		if program.recipe(StringName(record.recipe_id)) == null:
			last_failure = "arcade overhang %s lacks foundation recipe %s" % [
				upper.stable_id, StringName(record.recipe_id)]
			return [] as Array[WarrenFeatureReservation]
		var related := {upper.stable_id: true, lower.stable_id: true}
		var analysis := _outcrop_support_analysis([record] as Array[Dictionary],
			related, buildings, existing_features, program, world_seed)
		if not StringName(analysis.conflict).is_empty():
			last_failure = "arcade overhang %s portal conflicts with %s" % [
				upper.stable_id, StringName(analysis.conflict)]
			return [] as Array[WarrenFeatureReservation]
		var feature_id := StringName("spatial.feature.arcade_overhang.%02d" \
			% out.size())
		var tx := grid.begin_transaction(feature_id)
		if not tx.reserve(upper.private_cells,
				WarrenSpatialGrid.Reservation.FEATURE, feature_id) or not tx.commit():
			last_failure = "arcade overhang %s could not reserve its upper seam" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		var feature := WarrenFeatureReservation.new(feature_id,
			&"arcade_overhang_support")
		if not feature.add_reserved_cells(upper.private_cells) \
				or not feature.add_endpoint(upper.private_cells[0],
					building.stable_id) \
				or not feature.set_support_node(building.stable_id) \
				or not feature.add_construction_record(
					StringName(record.recipe_id), record.origin as Vector3i,
					int(record.yaw_quarters), &"arcade_stone_foundation"):
			last_failure = "arcade overhang %s foundation identity failed" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		var neighbor_ids: Array[StringName] = [lower.stable_id]
		for neighbor_value: Variant in analysis.neighbor_room_ids:
			var neighbor_id := StringName(neighbor_value)
			if neighbor_id != upper.stable_id and not neighbor_ids.has(neighbor_id):
				neighbor_ids.append(neighbor_id)
		neighbor_ids.sort()
		if not feature.set_audit_facts({
				"arcade_upper_room_id": upper.stable_id,
				"arcade_lower_room_id": lower.stable_id,
				"arcade_is_route_spanning": true,
				"arcade_projection_direction": geometry.direction,
				"arcade_projection_depth_cells": int(geometry.depth_cells),
				"arcade_attachment_span_cells": int(
					geometry.attachment_span_cells),
				"arcade_public_air_cell_count": (
					geometry.public_air_cells as Array).size(),
				"arcade_opening_mask": int(record.opening_mask),
				"arcade_opening_count": _bit_count_4(int(record.opening_mask)),
				"arcade_support_face_count": 4,
				"arcade_support_course_count": 1,
				"arcade_support_neighbor_room_ids": neighbor_ids,
			}) or not feature.seal(grid, supports):
			last_failure = "arcade overhang %s portal seal failed: %s" % [
				upper.stable_id, feature.last_rejection]
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	return out


static func _reserve_room_overhang_supports(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation], world_seed: int) \
		-> Array[WarrenFeatureReservation]:
	## A full room is never an outcropping. A larger upper plate may nevertheless
	## project one shallow, straight course beyond its bearing mass as an authored
	## jettied overhang, provided a measured support carries that entire edge.
	## A projection over public headroom becomes one complete stone arcade shell;
	## ordinary facade overhangs receive a timber post-and-brace course. This late
	## pass deliberately follows courtyard selection, so a newly recognized arcade
	## cannot perturb the already-sealed public topology.
	var out: Array[WarrenFeatureReservation] = []
	if program == null:
		last_failure = "room overhangs lack the measured support vocabulary"
		return out
	var already_supported: Dictionary = {}
	for feature: WarrenFeatureReservation in existing_features:
		for key: StringName in [&"arcade_upper_room_id", &"gateway_room_id",
				&"overhang_upper_room_id"]:
			var room_id := StringName(feature.audit.get(key, &""))
			if not room_id.is_empty():
				already_supported[room_id] = true
	var rooms_by_source: Dictionary = {}
	var building_by_room: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = [] \
					as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var candidates: Array[Dictionary] = []
	for rooms_value: Variant in rooms_by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			if already_supported.has(upper.stable_id):
				continue
			var geometry := _shallow_room_overhang_geometry(lower, upper, grid)
			if geometry.is_empty() or _cantilever_is_directly_borne(
					upper, geometry, grid):
				continue
			candidates.append({"lower": lower, "upper": upper,
				"building": building_by_room.get(upper.stable_id),
				"geometry": geometry})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String((a.upper as WarrenRoomStamp).stable_id) \
			< String((b.upper as WarrenRoomStamp).stable_id))
	for candidate: Dictionary in candidates:
		var lower := candidate.lower as WarrenRoomStamp
		var upper := candidate.upper as WarrenRoomStamp
		var building := candidate.building as WarrenBuildingVolume
		var geometry := candidate.geometry as Dictionary
		if building == null:
			last_failure = "room overhang %s lost its building" % upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		var public_arcade := _public_arcade_geometry(upper, geometry, grid)
		var crosses_public_headroom := false
		for column_value: Variant in geometry.extension_columns as Array:
			var column := column_value as Vector2i
			var below := Vector3i(column.x, upper.lattice_origin.y - 1,
				column.y)
			crosses_public_headroom = crosses_public_headroom \
				or grid.use_at(below) == WarrenSpatialGrid.Use.PUBLIC_AIR
		if crosses_public_headroom and public_arcade.is_empty() \
				and int(geometry.get("depth_cells", 0)) > 1:
			var undercroft_uses: Array[Dictionary] = []
			for column_value: Variant in geometry.extension_columns as Array:
				var column := column_value as Vector2i
				for y in range(grid.minimum.y, upper.lattice_origin.y):
					var cell := Vector3i(column.x, y, column.y)
					undercroft_uses.append({"cell": cell,
						"use": grid.use_at(cell),
						"floor": grid.face_claim(cell, Vector3i.DOWN)})
			last_failure = ("room overhang %s crosses public headroom without " \
				+ "an exact four-sided arcade footprint: %s uses=%s") % [
				upper.stable_id, JSON.stringify(geometry),
				JSON.stringify(undercroft_uses)]
			return [] as Array[WarrenFeatureReservation]
		var records: Array[Dictionary] = []
		if not public_arcade.is_empty():
			for course_top_value: Variant in public_arcade.get(
					"support_course_top_cells", [upper.lattice_origin.y]):
				var course_geometry := public_arcade.duplicate(true)
				course_geometry["support_origin_y"] = int(course_top_value)
				var arcade_record := _arcade_overhang_support_record(upper,
					course_geometry)
				if arcade_record.is_empty():
					records.clear()
					break
				records.append(arcade_record)
		else:
			records = _cantilever_support_records(upper, geometry, grid)
			# A shallow room jetty needs a legible wall bracket, not a second
			# storey-height post. The native diagonal asset carries a long upright;
			# although its measured endpoints touch the facade and soffit, repeated
			# courses read as timber poles hanging through the town. Reserve the
			# compact authored bracket for ordinary room overhangs. Public-passage
			# spans retain their complete four-sided masonry portal above.
			records = _shallow_cantilever_support_records(records)
		if records.is_empty():
			last_failure = "room overhang %s has no complete support course" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		var related := {upper.stable_id: true, lower.stable_id: true}
		var conflict_features: Array[WarrenFeatureReservation] = []
		for prior_feature: WarrenFeatureReservation in existing_features:
			if prior_feature.kind != &"room_overhang_support":
				conflict_features.append(prior_feature)
		# Adjacent overhang courses are one timber frame. Their eventual measured
		# intersections become explicit seams in the compiler, so they must not
		# veto one another during this town-wide structural pass.
		var analysis := _outcrop_support_analysis(records, related, buildings,
			conflict_features, program, world_seed)
		if not StringName(analysis.conflict).is_empty():
			last_failure = "room overhang %s support conflicts with %s" % [
				upper.stable_id, StringName(analysis.conflict)]
			return [] as Array[WarrenFeatureReservation]
		var feature_id := StringName("spatial.feature.room_overhang.%02d" \
			% out.size())
		var tx := grid.begin_transaction(feature_id)
		if not tx.reserve(upper.private_cells,
				WarrenSpatialGrid.Reservation.FEATURE, feature_id) or not tx.commit():
			last_failure = "room overhang %s could not reserve its upper seam" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		var feature := WarrenFeatureReservation.new(feature_id,
			&"room_overhang_support")
		if not feature.add_reserved_cells(upper.private_cells) \
				or not feature.add_endpoint(upper.private_cells[0],
					building.stable_id) \
				or not feature.set_support_node(building.stable_id):
			last_failure = "room overhang %s support identity failed" \
				% upper.stable_id
			return [] as Array[WarrenFeatureReservation]
		for record: Dictionary in records:
			if not feature.add_construction_record(StringName(record.recipe_id),
					record.origin as Vector3i, int(record.yaw_quarters),
					StringName(record.role)):
				last_failure = "room overhang %s support record failed" \
					% upper.stable_id
				return [] as Array[WarrenFeatureReservation]
		if not feature.set_audit_facts({
				"overhang_upper_room_id": upper.stable_id,
				"overhang_lower_room_id": lower.stable_id,
				"overhang_is_supported": true,
				"overhang_projection_direction": geometry.direction,
				"overhang_projection_depth_cells": int(geometry.depth_cells),
				"overhang_attachment_span_cells": int(
					geometry.attachment_span_cells),
				"overhang_extension_column_count": int(
					geometry.extension_column_count),
				"overhang_support_material": &"stone" \
					if not public_arcade.is_empty() else &"timber",
				"overhang_support_face_count": records.size() * 4 \
					if not public_arcade.is_empty() else records.size(),
				"overhang_opening_mask": int(records[0].get("opening_mask", 0)),
				"overhang_support_course_count": records.size(),
				"overhang_support_neighbor_room_ids":
					analysis.neighbor_room_ids,
			}) or not feature.seal(grid, supports):
			last_failure = "room overhang %s support seal failed: %s" % [
				upper.stable_id, feature.last_rejection]
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	return out


static func _public_arcade_geometry(upper: WarrenRoomStamp,
		shallow: Dictionary, grid: WarrenSpatialGrid) -> Dictionary:
	## Convert a late shallow room overhang into the exact 3 x 3 m portal shell
	## used by the original tower-to-slim grammar. Partial public-air overlap is
	## never accepted: all four columns and both headroom bands belong to the same
	## arcade, and every exterior route opening is recorded before construction.
	if upper == null or grid == null or shallow.is_empty() \
			or int(shallow.get("depth_cells", 0)) != 2 \
			or int(shallow.get("attachment_span_cells", 0)) != 2 \
			or int(shallow.get("extension_column_count", 0)) != 4:
		return {}
	var extension: Dictionary = {}
	for column_value: Variant in shallow.extension_columns as Array:
		extension[column_value as Vector2i] = true
	# Descend complete native storey courses until the route's exact public floor
	# is reached. A shell around upper headroom alone would still visibly float;
	# every intermediate course must remain wholly PUBLIC_AIR so the repeated
	# arch modules preserve rather than fill the carved passage.
	var public_air_cells: Array[Vector3i] = []
	var support_course_top_cells: Array[int] = []
	var passage_y := upper.lattice_origin.y
	var found_public_floor := false
	while passage_y - WarrenSpatialGrid.STOREY_CELLS >= grid.minimum.y:
		var course_base_y := passage_y - WarrenSpatialGrid.STOREY_CELLS
		var course_cells: Array[Vector3i] = []
		var complete_public_course := true
		var course_has_complete_public_floor := true
		for column_value: Variant in extension.keys():
			var column := column_value as Vector2i
			for y in range(course_base_y, passage_y):
				var cell := Vector3i(column.x, y, column.y)
				if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
					complete_public_course = false
					break
				course_cells.append(cell)
			if int(grid.face_claim(Vector3i(column.x, course_base_y,
					column.y), Vector3i.DOWN).get("kind", -1)) \
					!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				course_has_complete_public_floor = false
			if not complete_public_course:
				break
		if not complete_public_course:
			break
		support_course_top_cells.append(passage_y)
		public_air_cells.append_array(course_cells)
		passage_y = course_base_y
		if course_has_complete_public_floor:
			found_public_floor = true
			break
	if not found_public_floor or support_course_top_cells.is_empty():
		return {}
	var opening_directions: Array[Vector3i] = []
	for opening_direction: Vector3i in [Vector3i.FORWARD, Vector3i.RIGHT,
			Vector3i.BACK, Vector3i.LEFT]:
		var direction_2d := Vector2i(opening_direction.x, opening_direction.z)
		var opens := false
		for column_value: Variant in extension.keys():
			var column := column_value as Vector2i
			var neighbor_column := column + direction_2d
			if extension.has(neighbor_column):
				continue
			var neighbor := Vector3i(neighbor_column.x, passage_y,
				neighbor_column.y)
			var floor_claim := grid.face_claim(neighbor, Vector3i.DOWN)
			if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					and int(floor_claim.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				opens = true
				break
		if opens:
			opening_directions.append(opening_direction)
	if opening_directions.is_empty():
		return {}
	return {
		"valid": true,
		"direction": shallow.direction,
		"depth_cells": 2,
		"attachment_span_cells": 2,
		"attachment_columns": shallow.attachment_columns,
		"extension_columns": shallow.extension_columns,
		"extension_column_count": 4,
		"public_air_cells": public_air_cells,
		"opening_directions": opening_directions,
		"support_course_top_cells": support_course_top_cells,
	}


static func _arcade_overhang_geometry(lower: WarrenRoomStamp,
		upper: WarrenRoomStamp, grid: WarrenSpatialGrid) -> Dictionary:
	## Recognize only the basic, legible case: a two-cell tower plate is one half
	## of a four-cell slim/row plate, and the other 3 x 3 m half spans two full
	## public-air bands. Larger or diagonal cases stay in their own grammars.
	if lower == null or upper == null or grid == null \
			or upper.lattice_origin.y - lower.lattice_origin.y \
				!= WarrenSpatialGrid.STOREY_CELLS:
		return {}
	var lower_columns := _room_columns(lower)
	var upper_columns := _room_columns(upper)
	if lower_columns.size() != 4 or upper_columns.size() != 8:
		return {}
	var extension: Dictionary = {}
	for column_value: Variant in upper_columns.keys():
		var column := column_value as Vector2i
		if not lower_columns.has(column):
			extension[column] = true
	for column_value: Variant in lower_columns.keys():
		if not upper_columns.has(column_value):
			return {}
	if extension.size() != 4 or not _columns_are_connected(extension):
		return {}
	var lower_bounds := _column_bounds(lower_columns)
	var extension_bounds := _column_bounds(extension)
	var lower_min := lower_bounds.minimum as Vector2i
	var lower_max := lower_bounds.maximum as Vector2i
	var extension_min := extension_bounds.minimum as Vector2i
	var extension_max := extension_bounds.maximum as Vector2i
	var direction := Vector2i.ZERO
	if extension_max.x == lower_min.x - 1 \
			and extension_min.x == lower_min.x - 2 \
			and extension_min.y == lower_min.y \
			and extension_max.y == lower_max.y:
		direction = Vector2i.LEFT
	elif extension_min.x == lower_max.x + 1 \
			and extension_max.x == lower_max.x + 2 \
			and extension_min.y == lower_min.y \
			and extension_max.y == lower_max.y:
		direction = Vector2i.RIGHT
	elif extension_max.y == lower_min.y - 1 \
			and extension_min.y == lower_min.y - 2 \
			and extension_min.x == lower_min.x \
			and extension_max.x == lower_max.x:
		direction = Vector2i.UP
	elif extension_min.y == lower_max.y + 1 \
			and extension_max.y == lower_max.y + 2 \
			and extension_min.x == lower_min.x \
			and extension_max.x == lower_max.x:
		direction = Vector2i.DOWN
	if direction == Vector2i.ZERO:
		return {}
	var attachment: Dictionary = {}
	for column_value: Variant in lower_columns.keys():
		var column := column_value as Vector2i
		if extension.has(column + direction):
			attachment[column] = true
	if attachment.size() != 2:
		return {}
	var public_air_cells: Array[Vector3i] = []
	for column_value: Variant in extension.keys():
		var column := column_value as Vector2i
		for y in range(upper.lattice_origin.y - WarrenSpatialGrid.STOREY_CELLS,
				upper.lattice_origin.y):
			var cell := Vector3i(column.x, y, column.y)
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				return {}
			public_air_cells.append(cell)
	var opening_directions: Array[Vector3i] = []
	var passage_y := upper.lattice_origin.y - WarrenSpatialGrid.STOREY_CELLS
	for opening_direction: Vector3i in [Vector3i.FORWARD, Vector3i.RIGHT,
			Vector3i.BACK, Vector3i.LEFT]:
		var direction_2d := Vector2i(opening_direction.x, opening_direction.z)
		var opens := false
		for column_value: Variant in extension.keys():
			var column := column_value as Vector2i
			var neighbor_column := column + direction_2d
			if extension.has(neighbor_column):
				continue
			var neighbor := Vector3i(neighbor_column.x, passage_y,
				neighbor_column.y)
			var floor_claim := grid.face_claim(neighbor, Vector3i.DOWN)
			if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					and int(floor_claim.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				opens = true
				break
		if opens:
			opening_directions.append(opening_direction)
	if opening_directions.is_empty():
		return {}
	return {
		"valid": true,
		"direction": direction,
		"depth_cells": 2,
		"attachment_span_cells": 2,
		"attachment_columns": _sorted_columns(attachment),
		"extension_columns": _sorted_columns(extension),
		"public_air_cells": public_air_cells,
		"opening_directions": opening_directions,
	}


static func _arcade_overhang_support_record(upper: WarrenRoomStamp,
		geometry: Dictionary) -> Dictionary:
	if upper == null or not bool(geometry.get("valid", false)):
		return {}
	var direction_2d := geometry.get("direction", Vector2i.ZERO) as Vector2i
	var direction := Vector3i(direction_2d.x, 0, direction_2d.y)
	var yaw := _yaw_for_local_direction(Vector3i.BACK, direction)
	if yaw < 0:
		return {}
	var span_direction_3d := FabricRecipe.transform_direction(Vector3i.RIGHT,
		yaw)
	var span_direction := Vector2i(span_direction_3d.x, span_direction_3d.z)
	var attachment: Array[Vector2i] = []
	attachment.assign(geometry.get("attachment_columns", []) as Array)
	if attachment.size() != 2:
		return {}
	attachment.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * span_direction.x + a.y * span_direction.y \
			< b.x * span_direction.x + b.y * span_direction.y)
	if attachment[1] != attachment[0] + span_direction:
		return {}
	var opening_mask := 0
	for world_direction_value: Variant in geometry.get("opening_directions", []):
		var local_direction := FabricRecipe.transform_direction(
			world_direction_value as Vector3i, 4 - yaw)
		opening_mask |= _arcade_portal_bit(local_direction)
	if opening_mask <= 0:
		return {}
	return {
		"recipe_id": SettlementFabricProgram \
			.arcade_overhang_foundation_recipe_id(opening_mask),
		"origin": Vector3i(attachment[0].x, int(geometry.get(
			"support_origin_y", upper.lattice_origin.y)),
			attachment[0].y),
		"yaw_quarters": yaw,
		"role": &"arcade_stone_foundation",
		"opening_mask": opening_mask,
	}


static func _arcade_portal_bit(direction: Vector3i) -> int:
	match direction:
		Vector3i.FORWARD:
			return SettlementFabricProgram.FEATURE_PORTAL_NORTH
		Vector3i.RIGHT:
			return SettlementFabricProgram.FEATURE_PORTAL_EAST
		Vector3i.BACK:
			return SettlementFabricProgram.FEATURE_PORTAL_SOUTH
		Vector3i.LEFT:
			return SettlementFabricProgram.FEATURE_PORTAL_WEST
		_:
			return 0


static func _bit_count_4(mask: int) -> int:
	var count := 0
	for bit in 4:
		count += int(mask & (1 << bit) != 0)
	return count


static func _frontier_gateway_is_directly_borne(room: WarrenRoomStamp,
		geometry: Dictionary, grid: WarrenSpatialGrid) -> bool:
	if room == null or grid == null or not bool(geometry.get("valid", false)):
		return false
	var attachment: Array[Vector2i] = []
	attachment.assign(geometry.get("attachment_columns", []) as Array)
	var direction_2d := geometry.get("direction", Vector2i.ZERO) as Vector2i
	if attachment.size() != 2 \
			or absi(direction_2d.x) + absi(direction_2d.y) != 1:
		return false
	return _cantilever_course_is_directly_borne(grid, attachment,
		Vector3i(direction_2d.x, 0, direction_2d.y), room.lattice_origin.y,
		int(geometry.get("depth_cells", 0)))


static func _frontier_gateway_geometry(room: WarrenRoomStamp,
		record: Dictionary) -> Dictionary:
	var bearing_macro := record.get("bearing_column", Vector2i.ZERO) as Vector2i
	var unsupported_macro := record.get(
		"unsupported_column", Vector2i.ZERO) as Vector2i
	var direction := unsupported_macro - bearing_macro
	if room == null or absi(direction.x) + absi(direction.y) != 1:
		return {}
	var room_columns := _room_columns(room)
	var bearing: Dictionary = {}
	var extension: Dictionary = {}
	for x_offset in 2:
		for z_offset in 2:
			bearing[Vector2i(bearing_macro.x * 2 + x_offset,
				bearing_macro.y * 2 + z_offset)] = true
			extension[Vector2i(unsupported_macro.x * 2 + x_offset,
				unsupported_macro.y * 2 + z_offset)] = true
	if room_columns.size() != bearing.size() + extension.size():
		return {}
	for column_value: Variant in bearing.keys():
		if not room_columns.has(column_value):
			return {}
	for column_value: Variant in extension.keys():
		if not room_columns.has(column_value):
			return {}
	var attachment: Dictionary = {}
	for column_value: Variant in bearing.keys():
		var column := column_value as Vector2i
		if extension.has(column + direction):
			attachment[column] = true
	if attachment.size() != 2:
		return {}
	return {
		"valid": true,
		"rejection": &"",
		"direction": direction,
		"depth_cells": 2,
		"attachment_span_cells": 2,
		"attachment_columns": _sorted_columns(attachment),
		"extension_columns": _sorted_columns(extension),
		"extension_column_count": extension.size(),
		"bearing_column_count": bearing.size(),
		"bearing_ratio": 0.5,
	}


static func _reserve_tower_annexes(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation],
		tower_annex_targets: Dictionary,
		feature_kind: StringName = &"tower_annex",
		selection_limit: int = -1) \
		-> Array[WarrenFeatureReservation]:
	last_annex_diagnostic = {"feature_kind": feature_kind}
	if program == null or feature_kind not in [&"tower_annex", &"facade_bay"]:
		return [] as Array[WarrenFeatureReservation]
	var rooms_by_source: Dictionary = {}
	var building_by_room: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = [] \
					as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var target_sources: Dictionary = {}
	for source_value: Variant in tower_annex_targets.keys():
		var source_id := StringName(source_value)
		if rooms_by_source.has(source_id) \
				and int(tower_annex_targets[source_value]) > 0:
			target_sources[source_id] = int(
				tower_annex_targets[source_value])
	if target_sources.is_empty():
		last_annex_diagnostic["target_source_count"] = 0
		return [] as Array[WarrenFeatureReservation]
	var endpoint_count := 0
	var eligible_endpoint_count := 0
	var recipe_attempt_count := 0
	var feature_overlap_rejection_count := 0
	var body_rejection_count := 0
	var clearance_rejection_count := 0
	var room_envelope_rejection_count := 0
	var partial_roof_rejection_count := 0
	var protected_partial_roof_crown := \
		_partial_roof_campaign_crown_cells(grid, buildings)
	var used_endpoint_cells: Dictionary = {}
	for feature: WarrenFeatureReservation in existing_features:
		for endpoint: Dictionary in feature.endpoints:
			used_endpoint_cells[endpoint.cell as Vector3i] = true
	var owner_ids_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not owner_ids_by_source.has(room.source_parcel_id):
				owner_ids_by_source[room.source_parcel_id] = {}
			(owner_ids_by_source[room.source_parcel_id] \
				as Dictionary)[building.stable_id] = true
	# A tower-breaking annex needs enough volume to disrupt a repeated vertical
	# stack. Ordinary facade relief is a different architectural operation: it
	# must remain a shallow, framed projection of the parent wall. Keeping these
	# finite vocabularies separate prevents a decorative bay from becoming a
	# complete miniature house glued to another house.
	var recipe_ids: Array[StringName] = []
	# Facade bays are occupied pieces of architecture, not attic-window props or
	# complete rooms attached at the facade. Each reviewed oriel crosses the
	# parent wall plane: half of its 1.5 m shell is embedded and half projects.
	if feature_kind == &"facade_bay":
		recipe_ids.assign([
			&"outcrop.embedded.blue", &"outcrop.embedded.orange",
			&"outcrop.embedded.amber",
		])
	else:
		# Every structural annex is now the full-scale diagonal union. The former
		# straight 3 m boxes (`outcrop.blue/orange`) and dormer/flue/cap decorations
		# remain valid vocabulary elsewhere, but cannot satisfy a room bump-out or
		# tower-massing obligation.
		recipe_ids.assign([
			&"outcrop.corner.wrap.left.blue",
			&"outcrop.corner.wrap.right.blue",
			&"outcrop.corner.wrap.left.orange",
			&"outcrop.corner.wrap.right.orange",
			&"outcrop.corner.wrap.left.amber",
			&"outcrop.corner.wrap.right.amber",
		])
	var candidates: Array[Dictionary] = []
	for endpoint: Dictionary in _balcony_room_endpoints(buildings):
		endpoint_count += 1
		var room := endpoint.room as WarrenRoomStamp
		if not target_sources.has(room.source_parcel_id) \
				or room.source_storey_index < 1 \
				or feature_kind == &"tower_annex" and room.kind != &"tower" \
				or used_endpoint_cells.has(endpoint.cell as Vector3i):
			continue
		# A shallow bay may decorate a complete eave or a fully covered lower
		# storey. It must not consume one cell of a setback roof campaign: that
		# turns the surviving authored roof into an isolated flat lid beside the
		# bay or a skywalk. Reject the optional bay here, while the grid still
		# carries the authoritative roof faces, instead of asking the roof
		# compiler to disguise a broken run later.
		if feature_kind == &"facade_bay" \
				and _room_has_partial_roof_campaign(grid, room):
			partial_roof_rejection_count += 1
			continue
		eligible_endpoint_count += 1
		var facing := endpoint.facing as Vector3i
		var building := endpoint.building as WarrenBuildingVolume
		var parent_theme := WarrenSpatialFabricCompiler \
			._architectural_district_theme(room.lattice_origin, world_seed)
		var allowed_owner_ids := owner_ids_by_source[room.source_parcel_id] \
			as Dictionary
		for recipe_id: StringName in recipe_ids:
			recipe_attempt_count += 1
			# The extrusion is part of this building's shell, so it must use the
			# exact district facade family of its parent. A differently coloured
			# annex made the clean lattice union still read as a second prefab.
			if not String(recipe_id).ends_with(".%s" % String(parent_theme)):
				continue
			var recipe := program.recipe(recipe_id)
			if recipe == null or not recipe.has_tag(&"outcropping") \
					or recipe.bearing_parent_count != 1:
				continue
			if feature_kind == &"tower_annex" and (not recipe.has_tag(
					&"full_scale_diagonal_overlap") or not recipe.has_tag(
					&"no_duplicate_overlap_shell")):
				continue
			var socket := recipe.socket(&"room.back")
			var yaw := _yaw_for_local_direction(Vector3i.FORWARD, -facing)
			if socket.is_empty() or yaw < 0:
				continue
			var socket_world := (endpoint.cell as Vector3i) + facing
			var origin := socket_world - FabricRecipe.transform_cell(
				socket.cell as Vector3i, Vector3i.ZERO, yaw)
			var feature_bounds := FabricRecipe.lattice_transform(origin, yaw) \
				* recipe.local_clearance_bounds
			# Grid cells protect topology; this catches an authored dormer cheek,
			# eave, or brace that reaches into an already committed balcony,
			# support, skywalk, or structural outcropping between cells. The final
			# compiler must never be asked to repair such an overlap visually.
			if _feature_bounds_overlap_existing_features(feature_bounds,
					existing_features, program):
				feature_overlap_rejection_count += 1
				continue
			var body := _feature_recipe_cells(recipe, origin, yaw)
			if body.is_empty() or not WarrenVolumetricSolver \
					._skywalk_body_fits_grid(grid, body):
				body_rejection_count += 1
				continue
			# The projection may be attached to a sound parent yet occupy the crown
			# of a neighboring setback room. Treat every partial roof campaign as a
			# protected town-wide construction run; otherwise a valid three/four-cell
			# roof can be reduced to the isolated one-cell cap caught in review.
			if feature_kind == &"facade_bay" \
					and _cell_sets_overlap(body, protected_partial_roof_crown):
				partial_roof_rejection_count += 1
				continue
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": origin, "yaw_quarters": yaw}]
			var clearance := WarrenVolumetricSolver \
				._skywalk_visual_clearance_cells(components, program)
			var clearance_audit := _balcony_clearance_audit(grid, clearance,
				body, allowed_owner_ids, origin.y)
			if not bool(clearance_audit.get("fits", false)):
				clearance_rejection_count += 1
				continue
			if not _tower_annex_clears_room_envelopes(recipe, origin,
					yaw, room.source_parcel_id, buildings, program, world_seed):
				room_envelope_rejection_count += 1
				continue
			candidates.append({"recipe_id": recipe_id, "origin": origin,
				"yaw_quarters": yaw, "body": body, "clearance": clearance,
				"body_cell_count": body.size(),
				"clearance_only": clearance_audit.clearance_only,
				"covered_public_cells": clearance_audit.covered_public_cells,
				"endpoint_cell": endpoint.cell, "socket_world": socket_world,
				"facing": facing,
				"vertical_facade_key": _tower_annex_vertical_facade_key(
					endpoint.cell as Vector3i, facing),
				"room": room, "building": building,
				"embedded_partial_extrusion": recipe.has_tag(
					&"embedded_oriel"),
				"embedded_depth_m": 0.03 if recipe.has_tag(
					&"embedded_oriel") else 0.0,
				"projected_depth_m": 0.87 if recipe.has_tag(
					&"embedded_oriel") else 0.0,
				"full_scale_diagonal_overlap": recipe.has_tag(
					&"full_scale_diagonal_overlap"),
				"compound_union_shell": recipe.has_tag(
					&"compound_union_shell"),
				"matches_parent_palette": true,
				"allowed_owner_ids": allowed_owner_ids,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(room.stable_id).hash() * 31 \
					^ String(recipe_id).hash() * 47 \
					^ (endpoint.cell as Vector3i).x * 73856093 \
					^ (endpoint.cell as Vector3i).z * 19349663), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_room := a.room as WarrenRoomStamp
		var b_room := b.room as WarrenRoomStamp
		if a_room.source_storey_index != b_room.source_storey_index:
			return a_room.source_storey_index > b_room.source_storey_index
		if int(a.body_cell_count) != int(b.body_cell_count):
			# Structural tower relief should be emphatic; ordinary facade bays
			# should remain visually subordinate to their parent room.
			return int(a.body_cell_count) < int(b.body_cell_count) \
				if feature_kind == &"facade_bay" \
				else int(a.body_cell_count) > int(b.body_cell_count)
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var existing_kind_count := existing_features.filter(
		func(feature: WarrenFeatureReservation) -> bool:
			return feature.kind == feature_kind).size()
	var refreshed_rejection_count := 0
	var commit_rejection_count := 0
	var source_ids: Array[StringName] = []
	if feature_kind == &"facade_bay":
		# Candidates already rank upper rooms first, then use the deterministic
		# visual tie. Preserve that ordering while reducing to one search lane per
		# lineage; lexical parcel order has no architectural meaning.
		for candidate: Dictionary in candidates:
			var source_id := (candidate.room as WarrenRoomStamp).source_parcel_id
			if not source_ids.has(source_id):
				source_ids.append(source_id)
	else:
		source_ids.assign(target_sources.keys())
		source_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
	var selected_by_source: Dictionary = {}
	for source_id: StringName in source_ids:
		selected_by_source[source_id] = [] as Array[Dictionary]
	# Round-robin selection prevents one especially open shaft from consuming the
	# relief budget. Pass one chooses the strongest upper room. Pass two prefers a
	# two-storey separation; a same/adjacent-storey fallback is allowed only when
	# it turns onto a different world-space facade and uses another authored mass
	# profile. That creates a wider or stepped compound silhouette without
	# accepting two vertically repeated bay windows on one box face.
	var relief_round_count := 0
	for target_value: Variant in target_sources.values():
		relief_round_count = maxi(relief_round_count, int(target_value))
	for relief_round in relief_round_count:
		for source_id: StringName in source_ids:
			if relief_round >= int(target_sources[source_id]):
				continue
			var prior := selected_by_source[source_id] as Array[Dictionary]
			var chosen: Dictionary = {}
			var chosen_distance := -1
			for candidate: Dictionary in candidates:
				var room := candidate.room as WarrenRoomStamp
				if room.source_parcel_id != source_id:
					continue
				var vertical_distance := 0
				if not prior.is_empty():
					var first_room := prior[0].room as WarrenRoomStamp
					vertical_distance = absi(room.source_storey_index \
						- first_room.source_storey_index)
					if not _tower_annexes_have_silhouette_separation(candidate,
							prior[0]):
						continue
				if not WarrenVolumetricSolver._skywalk_body_fits_grid(grid,
						candidate.body as Dictionary):
					continue
				var refreshed := _balcony_clearance_audit(grid,
					candidate.clearance as Dictionary,
					candidate.body as Dictionary,
					candidate.allowed_owner_ids as Dictionary,
					(candidate.origin as Vector3i).y)
				if not bool(refreshed.get("fits", false)):
					refreshed_rejection_count += 1
					continue
				if chosen.is_empty() or vertical_distance > chosen_distance:
					chosen = candidate.duplicate()
					chosen["clearance_only"] = refreshed.clearance_only
					chosen["covered_public_cells"] = \
						refreshed.covered_public_cells
					chosen_distance = vertical_distance
			if chosen.is_empty():
				continue
			var feature := _commit_tower_annex(grid, chosen, supports,
				existing_kind_count + out.size(), feature_kind)
			if feature == null:
				commit_rejection_count += 1
				continue
			prior.append(chosen)
			out.append(feature)
			if selection_limit >= 0 and out.size() >= selection_limit:
				break
		if selection_limit >= 0 and out.size() >= selection_limit:
			break
	last_annex_diagnostic = {
		"feature_kind": feature_kind,
		"target_source_count": target_sources.size(),
		"endpoint_count": endpoint_count,
		"eligible_endpoint_count": eligible_endpoint_count,
		"recipe_attempt_count": recipe_attempt_count,
		"feature_overlap_rejection_count": feature_overlap_rejection_count,
		"body_rejection_count": body_rejection_count,
		"clearance_rejection_count": clearance_rejection_count,
		"room_envelope_rejection_count": room_envelope_rejection_count,
		"partial_roof_rejection_count": partial_roof_rejection_count,
		"candidate_count": candidates.size(),
		"refreshed_rejection_count": refreshed_rejection_count,
		"commit_rejection_count": commit_rejection_count,
		"selected_count": out.size(),
	}
	return out


static func _room_has_partial_roof_campaign(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp) -> bool:
	if grid == null or room == null:
		return false
	var top_y := room.lattice_origin.y + WarrenSpatialGrid.STOREY_CELLS - 1
	var top_cell_count := 0
	var exposed_crown_count := 0
	for cell: Vector3i in room.private_cells:
		if cell.y != top_y:
			continue
		top_cell_count += 1
		# Generic shell/roof faces are derived only after feature selection. At
		# this stage the exact equivalent is the crown cell above the room: any
		# non-private cell becomes an exposed roof interface, while continuing
		# inhabited mass covers it. Existing explicit feature seams are already
		# protected by the candidate clearance checks.
		if grid.use_at(cell + Vector3i.UP) \
				!= WarrenSpatialGrid.Use.PRIVATE_VOLUME:
			exposed_crown_count += 1
	return exposed_crown_count > 0 and exposed_crown_count < top_cell_count


static func _partial_roof_campaign_crown_cells(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume]) -> Dictionary:
	var out: Dictionary = {}
	if grid == null:
		return out
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not _room_has_partial_roof_campaign(grid, room):
				continue
			var top_y := room.lattice_origin.y \
				+ WarrenSpatialGrid.STOREY_CELLS - 1
			for cell: Vector3i in room.private_cells:
				if cell.y == top_y and grid.use_at(cell + Vector3i.UP) \
						!= WarrenSpatialGrid.Use.PRIVATE_VOLUME:
					out[cell + Vector3i.UP] = room.stable_id
	return out


static func _cell_sets_overlap(left: Dictionary, right: Dictionary) -> bool:
	if left.size() > right.size():
		return _cell_sets_overlap(right, left)
	for cell_value: Variant in left.keys():
		if right.has(cell_value):
			return true
	return false


static func _tower_annexes_have_silhouette_separation(candidate: Dictionary,
		prior: Dictionary) -> bool:
	if candidate.is_empty() or prior.is_empty() \
			or candidate.recipe_id == prior.recipe_id:
		return false
	var candidate_room := candidate.get("room") as WarrenRoomStamp
	var prior_room := prior.get("room") as WarrenRoomStamp
	if candidate_room == null or prior_room == null:
		return false
	var vertical_distance := absi(candidate_room.source_storey_index \
		- prior_room.source_storey_index)
	if vertical_distance >= 2:
		return true
	return vertical_distance <= 1 \
		and String(candidate.get("vertical_facade_key", "")) \
			!= String(prior.get("vertical_facade_key", ""))


static func _tower_annex_vertical_facade_key(endpoint: Vector3i,
		facing: Vector3i) -> String:
	return "%d,%d/%d,%d" % [endpoint.x, endpoint.z, facing.x, facing.z]


static func _facade_bay_targets(buildings: Array[WarrenBuildingVolume],
		tower_annexes: Array[WarrenFeatureReservation], target_count: int,
		world_seed: int) -> Dictionary:
	## One bay per lineage is enough to create a recognisable macroscopic wall
	## rhythm without turning every facade module into noisy applique. Return the
	## complete ranked source pool here: `target_count` caps successful commits,
	## not search attempts. The former first-N shortlist could select two cramped
	## lineages and conclude that an otherwise open town had no bay locations.
	if target_count <= 0:
		return {}
	var excluded: Dictionary = {}
	for annex: WarrenFeatureReservation in tower_annexes:
		excluded[StringName(annex.audit.get(
			"annex_source_parcel_id", &""))] = true
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_storey_index < 1 or excluded.has(
					room.source_parcel_id) or seen.has(room.source_parcel_id):
				continue
			seen[room.source_parcel_id] = true
			candidates.append({
				"source_id": room.source_parcel_id,
				"upper_storey": room.source_storey_index,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(room.source_parcel_id).hash() \
					^ 0x4641434144454241), 1000003),
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.upper_storey) != int(b.upper_storey):
			return int(a.upper_storey) > int(b.upper_storey)
		return int(a.tie) < int(b.tie))
	var out: Dictionary = {}
	for index in candidates.size():
		out[StringName(candidates[index].source_id)] = 1
	return out


static func _tower_annex_clears_room_envelopes(recipe: FabricRecipe,
		origin: Vector3i, yaw_quarters: int, own_source_id: StringName,
		buildings: Array[WarrenBuildingVolume], program: SettlementFabricProgram,
		world_seed: int) -> bool:
	## The integer clearance raster protects topology, but authored eaves and
	## facade details can cross a cell boundary by centimetres. Use the same
	## measured AABBs as SettlementFabricPlan before reserving an annex; only
	## rooms in its own source lineage are explicit visual seams.
	var annex_bounds := FabricRecipe.lattice_transform(origin, yaw_quarters) \
		* recipe.local_clearance_bounds
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_parcel_id == own_source_id:
				continue
			var recipe_ids: Array[StringName] = [
				WarrenSpatialFabricCompiler._room_recipe_id(room, world_seed),
				WarrenSpatialFabricCompiler._room_recipe_id(room, world_seed, false),
			]
			var seen: Dictionary = {}
			for recipe_id: StringName in recipe_ids:
				if seen.has(recipe_id):
					continue
				seen[recipe_id] = true
				var room_recipe := program.recipe(recipe_id)
				if room_recipe == null:
					return false
				var room_bounds := FabricRecipe.lattice_transform(
					room.lattice_origin, room.yaw_quarters) \
					* room_recipe.local_clearance_bounds
				if SettlementFabricPlan._aabb_overlaps_volume(annex_bounds,
						room_bounds):
					return false
	return true


static func _commit_tower_annex(grid: WarrenSpatialGrid,
		candidate: Dictionary, supports: WarrenSupportGraph,
		ordinal: int, feature_kind: StringName = &"tower_annex") \
		-> WarrenFeatureReservation:
	var feature_token := "tower-annex" if feature_kind == &"tower_annex" \
		else "facade-bay"
	var feature_id := StringName("spatial.feature.%s.%02d" % [feature_token,
		ordinal])
	var body_dict := candidate.body as Dictionary
	var body: Array[Vector3i] = []
	body.assign(body_dict.keys())
	body.sort_custom(_cell_less)
	var clearance_only: Array[Vector3i] = []
	clearance_only.assign((candidate.clearance_only as Dictionary).keys())
	var covered_public: Array[Vector3i] = []
	covered_public.assign((candidate.covered_public_cells as Dictionary).keys())
	var endpoint_cell := candidate.endpoint_cell as Vector3i
	var socket_world := candidate.socket_world as Vector3i
	var building := candidate.building as WarrenBuildingVolume
	var room := candidate.room as WarrenRoomStamp
	var base_y := (candidate.origin as Vector3i).y
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not covered_public.is_empty() and not tx.reserve(covered_public,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_dict.has(neighbor):
				continue
			var opens_to_room := Vector2i(cell.x, cell.z) \
					== Vector2i(socket_world.x, socket_world.z) \
				and neighbor == endpoint_cell + Vector3i.UP * (cell.y - base_y)
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if opens_to_room:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT \
					if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			if not tx.claim_face(cell, direction, kind, feature_id):
				return null
	if not tx.commit():
		return null
	var feature := WarrenFeatureReservation.new(feature_id, feature_kind)
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(endpoint_cell, building.stable_id) \
			or not feature.add_construction_record(
				StringName(candidate.recipe_id), candidate.origin as Vector3i,
				int(candidate.yaw_quarters), &"occupied_room_annex") \
			or not feature.set_support_node(building.stable_id) \
			or not feature.set_audit_facts({
				"annex_room_id": room.stable_id,
				"annex_building_id": building.stable_id,
				"annex_source_parcel_id": room.source_parcel_id,
				"annex_recipe_id": StringName(candidate.recipe_id),
				"annex_breaks_tower_lineage": feature_kind == &"tower_annex",
				"annex_endpoint_facing": candidate.facing as Vector3i,
				"annex_source_storey_index": room.source_storey_index,
				"annex_vertical_facade_key": "%s/%d,%d/%d,%d" % [
					String(room.source_parcel_id), endpoint_cell.x,
					endpoint_cell.z, (candidate.facing as Vector3i).x,
					(candidate.facing as Vector3i).z],
				"annex_relief_profile_key": "%s/%s" % [
					String(room.source_parcel_id), String(candidate.recipe_id)],
				"annex_reserved_cell_count": body.size(),
				"annex_is_embedded_partial_extrusion": bool(candidate.get(
					"embedded_partial_extrusion", false)),
				"annex_embedded_depth_m": float(candidate.get(
					"embedded_depth_m", 0.0)),
				"annex_projected_depth_m": float(candidate.get(
					"projected_depth_m", 0.0)),
				"annex_is_full_scale_diagonal_overlap": bool(candidate.get(
					"full_scale_diagonal_overlap", false)),
				"annex_uses_compound_union_shell": bool(candidate.get(
					"compound_union_shell", false)),
				"annex_matches_parent_palette": bool(candidate.get(
					"matches_parent_palette", false)),
			}) or not feature.seal(grid, supports):
		return null
	return feature


static func _record_preplanned_landmarks(grid: WarrenSpatialGrid,
		supports: WarrenSupportGraph,
		reservations: Array[Dictionary]) -> Array[WarrenFeatureReservation]:
	## Landmark volume, clearance, terrain bearing, doorway, and shell faces were
	## committed before room composition. This phase only seals the immutable
	## semantic records; it never searches for a new transform after packing.
	var out: Array[WarrenFeatureReservation] = []
	for reservation: Dictionary in reservations:
		var feature_id := StringName(reservation.get("feature_id", &""))
		var body: Array[Vector3i] = []
		body.assign((reservation.get("body", {}) as Dictionary).keys())
		body.sort_custom(_cell_less)
		var bearing: Array[Vector3i] = []
		bearing.assign((reservation.get("bearing_cells", {}) as Dictionary).keys())
		bearing.sort_custom(_cell_less)
		var entrance_cell := reservation.get("entrance_cell",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		var landing_cell := reservation.get("landing_cell",
			Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
		if feature_id.is_empty() or body.is_empty() or bearing.is_empty() \
				or not body.has(entrance_cell):
			last_failure = "preplanned prefab landmark record is incomplete"
			return [] as Array[WarrenFeatureReservation]
		for cell: Vector3i in body:
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or grid.owner_name_at(cell) != feature_id:
				last_failure = "prefab landmark %s lost body cell %s" % [
					feature_id, cell]
				return [] as Array[WarrenFeatureReservation]
		var blocker_ids: Array[StringName] = []
		blocker_ids.assign((reservation.get("blocker_parcels", {}) \
			as Dictionary).keys())
		blocker_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		var feature := WarrenFeatureReservation.new(feature_id,
			&"prefab_landmark")
		if not feature.add_reserved_cells(body) \
				or not feature.add_terrain_bearing_cells(bearing) \
				or not feature.add_endpoint(entrance_cell, feature_id) \
				or not feature.add_construction_record(
					StringName(reservation.recipe_id),
					reservation.origin as Vector3i,
					int(reservation.yaw_quarters), &"terrain_rooted_landmark") \
				or not feature.set_audit_facts({
					"landmark_recipe_id": StringName(reservation.recipe_id),
					"landmark_source_family": StringName(
						reservation.source_family),
					"landmark_entrance_cell": entrance_cell,
					"landmark_public_landing_cell": landing_cell,
					"landmark_terrain_bearing_cell_count": bearing.size(),
					"landmark_visual_clearance_cell_count": (
						reservation.clearance as Dictionary).size(),
					"landmark_height_cell_count": int(
						reservation.height_cell_count),
					"landmark_displaced_parcel_ids": blocker_ids,
					"landmark_publicly_addressed": true,
					"landmark_terrain_rooted": true,
				}) or not feature.seal(grid, supports):
			last_failure = "prefab landmark feature seal failed: %s" \
				% feature.last_rejection
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	return out


static func _reserve_preplanned_courtyard_bridge_house(
		grid: WarrenSpatialGrid, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph,
		reservation: Dictionary) -> WarrenFeatureReservation:
	## Commit the one-ended inhabited projection selected before room
	## composition. Unlike an ordinary skywalk, this is a room-scale cantilever:
	## one real building bears it, its far end remains occupied, and it encloses
	## only the court-edge cells that its measured body physically occupies.
	if reservation.is_empty() or StringName(reservation.get("feature_id", &"")) \
			!= WarrenVolumetricSolver.COURTYARD_BRIDGE_FEATURE_ID:
		last_failure = "missing topology-first courtyard bridge house"
		return null
	var owner_ids := reservation.get("owner_parcel_ids", []) as Array
	var endpoints := reservation.get("owner_endpoints", []) as Array
	if owner_ids.size() != 1 or endpoints.size() != 1:
		last_failure = "courtyard bridge house lacks one source endpoint"
		return null
	var source_parcel_id := StringName(owner_ids[0])
	var endpoint_record := endpoints[0] as Dictionary
	var endpoint_cell := endpoint_record.cell as Vector3i
	var endpoint_facing := endpoint_record.facing as Vector3i
	var resolved: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_parcel_id != source_parcel_id \
					or not room.has_private_cell(endpoint_cell):
				continue
			if not resolved.is_empty():
				last_failure = "courtyard bridge endpoint has multiple room owners"
				return null
			resolved = {"building": building, "room": room}
	if resolved.is_empty():
		last_failure = "courtyard bridge house lost its exact room endpoint"
		return null
	var body_set := reservation.get("reserved_cells", {}) as Dictionary
	if not body_set.has(endpoint_cell + endpoint_facing):
		last_failure = "courtyard bridge body does not begin outside its room"
		return null
	var body: Array[Vector3i] = []
	body.assign(body_set.keys())
	body.sort_custom(_cell_less)
	var lower_public_columns := _lower_public_columns(grid, body)
	if lower_public_columns.size() < 2:
		last_failure = "courtyard bridge house lost the lower public street"
		return null
	var feature_id := WarrenVolumetricSolver.COURTYARD_BRIDGE_FEATURE_ID
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (reservation.get("visual_clearance_cells", {}) \
			as Dictionary).keys():
		if body_set.has(cell_value):
			continue
		var cell := cell_value as Vector3i
		if (grid.reservation_bits_at(cell) \
				& WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE) != 0:
			last_failure = "courtyard bridge clearance changed before commit at %s" \
				% cell
			return null
		clearance_only.append(cell)
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		last_failure = "could not stage courtyard bridge house: %s" \
			% tx.last_rejection
		return null
	var endpoint_owner := (resolved.building as WarrenBuildingVolume).stable_id
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if neighbor == endpoint_cell:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				last_failure = "could not stage courtyard bridge face at %s" % cell
				return null
	if not tx.commit():
		last_failure = "courtyard bridge house rejected: %s" % tx.last_rejection
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"courtyard_bridge_house")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(endpoint_cell, endpoint_owner):
		last_failure = "could not record courtyard bridge volume or endpoint"
		return null
	var components := reservation.get("components", []) as Array
	for component_index in components.size():
		var component := components[component_index] as Dictionary
		if not feature.add_construction_record(StringName(component.recipe_id),
				component.origin as Vector3i, int(component.yaw_quarters),
				StringName("component.%02d" % component_index)):
			last_failure = "could not record courtyard bridge component"
			return null
	var room := resolved.room as WarrenRoomStamp
	if components.size() != 2 or not feature.set_support_node(endpoint_owner) \
			or not feature.set_audit_facts({
				"courtyard_bridge_house_room_id": room.stable_id,
				"courtyard_bridge_house_source_parcel_id": source_parcel_id,
				"courtyard_bridge_house_endpoint_facing": endpoint_facing,
				"courtyard_bridge_house_component_count": components.size(),
				"courtyard_bridge_house_lower_public_column_count":
					lower_public_columns.size(),
				"courtyard_bridge_house_side_mask": int(reservation.get(
					"courtyard_side_mask", 0)),
				"courtyard_bridge_house_visual_clearance_cell_count":
					body.size() + clearance_only.size(),
			}) or not feature.seal(grid, supports):
		last_failure = "courtyard bridge feature seal failed: %s" \
			% feature.last_rejection
		return null
	return feature


static func _reserve_courtyard(grid: WarrenSpatialGrid,
		source: WarrenVolumePlan, buildings: Array[WarrenBuildingVolume],
		supports: WarrenSupportGraph) -> WarrenFeatureReservation:
	var floors: Dictionary = {}
	for macro: Vector3i in source.courtyard_cells:
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				last_failure = "elevated court floor left public air at %s" % cell
				return null
			floors[cell] = true
	if floors.size() < 16:
		last_failure = "elevated court is smaller than the required 6 x 6 m"
		return null
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	var protected: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor := floor_value as Vector3i
		minimum_y = mini(minimum_y, floor.y)
		maximum_y = maxi(maximum_y, floor.y)
		for y_offset in WarrenSpatialGrid.STOREY_CELLS:
			var air := floor + Vector3i.UP * y_offset
			if grid.use_at(air) != WarrenSpatialGrid.Use.PUBLIC_AIR:
				last_failure = "elevated court lacks protected headroom at %s" % air
				return null
			protected[air] = true
		var macro_column := Vector2i(floor.x / 2, floor.z / 2)
		if floor.y - source.envelope.ground_at(macro_column) \
				< WarrenSpatialGrid.STOREY_CELLS * 2:
			last_failure = "court is not on the third-storey datum"
			return null
	if minimum_y != maximum_y:
		last_failure = "elevated court floor is not coplanar"
		return null
	var below: Dictionary = {}
	var above: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor := floor_value as Vector3i
		for offset in range(1, 9):
			var candidate := floor + Vector3i.DOWN * offset
			if grid.use_at(candidate) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				below[candidate] = true
		for offset in range(2, 9):
			var candidate := floor + Vector3i.UP * offset
			if grid.use_at(candidate) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				above[candidate] = true
	var route_threading := WarrenElevatedFrontageSolver \
		._courtyard_vertical_route_floor_counts(source.courtyard_cells, source)
	var underbuilt_columns := 0
	for macro: Vector3i in source.courtyard_cells:
		underbuilt_columns += int(WarrenElevatedFrontageSolver \
			._has_inhabited_mass_below(macro, source))
	if underbuilt_columns \
			< WarrenElevatedFrontageSolver.MIN_COURTYARD_UNDERBUILT_COLUMNS:
		last_failure = "elevated court lacks complete inhabited support below"
		return null
	var daylight_columns := int(source.audit.get(
		"courtyard_daylight_macro_column_count", 0))
	if daylight_columns < MIN_COURT_DAYLIGHT_MACRO_COLUMNS:
		last_failure = "elevated court has only %d open-sky columns" \
			% daylight_columns
		return null
	var court_columns: Dictionary = {}
	for macro: Vector3i in source.courtyard_cells:
		court_columns[Vector2i(macro.x, macro.z)] = true
	var daylight_air_cell_count := 0
	for macro: Vector3i in source.daylight_void_cells:
		if not court_columns.has(Vector2i(macro.x, macro.z)):
			continue
		for cell: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			if grid.use_at(cell) != WarrenSpatialGrid.Use.DAYLIGHT_AIR:
				last_failure = "courtyard daylight shaft lost at %s" % cell
				return null
			daylight_air_cell_count += 1
	for value: Variant in below.keys():
		protected[value] = true
	for value: Variant in above.keys():
		protected[value] = true
	var side_endpoints := _courtyard_side_endpoints(grid, floors)
	if side_endpoints.size() < MIN_COURT_SIDE_COUNT:
		last_failure = "elevated court is addressed on only %d sides" % \
			side_endpoints.size()
		return null
	var feature_id := StringName("spatial.feature.courtyard.%d" % \
		source.world_seed)
	var protected_cells: Array[Vector3i] = []
	protected_cells.assign(protected.keys())
	protected_cells.sort_custom(_cell_less)
	var reserve := grid.begin_transaction(feature_id)
	if not reserve.reserve(protected_cells, WarrenSpatialGrid.Reservation.FEATURE,
			feature_id) or not reserve.commit():
		last_failure = "elevated court reservation failed: %s" % \
			reserve.last_rejection
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"third_storey_courtyard")
	if not feature.add_reserved_cells(protected_cells):
		last_failure = "could not record elevated court cells"
		return null
	var support_owner := &""
	for endpoint: Dictionary in side_endpoints:
		if not feature.add_endpoint(endpoint.cell as Vector3i,
				StringName(endpoint.owner_id)):
			last_failure = "could not record court facade endpoint"
			return null
		var endpoint_owner := StringName(endpoint.owner_id)
		if support_owner.is_empty() and supports.reaches_terrain(endpoint_owner):
			support_owner = endpoint_owner
	if support_owner.is_empty() or not feature.set_support_node(support_owner) \
			or not feature.set_audit_facts({
				"courtyard_floor_cell_count": floors.size(),
				"courtyard_underbuilt_macro_column_count": underbuilt_columns,
				"courtyard_below_route_cell_count": int(route_threading.below),
				"courtyard_upper_route_cell_count": int(route_threading.above),
				"courtyard_addressed_side_count": side_endpoints.size(),
				"courtyard_floor_band": minimum_y,
				"courtyard_daylight_macro_column_count": daylight_columns,
				"courtyard_daylight_air_cell_count": daylight_air_cell_count,
			}) or not feature.seal(grid, supports):
		last_failure = "elevated court feature seal failed: %s" % \
			feature.last_rejection
		return null
	return feature


static func _reserve_balconies(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation],
		target_count: int = TARGET_BALCONIES) \
		-> Array[WarrenFeatureReservation]:
	## Search the actual three-dimensional residual void around upper room
	## sockets. A candidate is a complete measured recipe and owns its deck,
	## private headroom, guards, door seam, support, and clearance before roofs
	## are allowed to compile around it.
	if program == null:
		return [] as Array[WarrenFeatureReservation]
	var used_endpoint_cells: Dictionary = {}
	for feature: WarrenFeatureReservation in existing_features:
		for endpoint: Dictionary in feature.endpoints:
			used_endpoint_cells[endpoint.cell as Vector3i] = true
	var allowed_owner_ids_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not allowed_owner_ids_by_source.has(room.source_parcel_id):
				allowed_owner_ids_by_source[room.source_parcel_id] = {}
			(allowed_owner_ids_by_source[room.source_parcel_id] \
				as Dictionary)[building.stable_id] = true
	var room_clearance_bounds := _room_clearance_bounds(buildings, program,
		world_seed)
	var rejection_counts := {
		&"missing_recipe": 0,
		&"missing_socket": 0,
		&"unrelated_room_overlap": 0,
		&"existing_feature_overlap": 0,
		&"body_blocked": 0,
		&"missing_return_contact": 0,
		&"missing_public_stair_landing": 0,
		&"portal_room_overlap": 0,
		&"clearance_blocked": 0,
	}
	var stair_rejection_samples: Array[Dictionary] = []
	var clearance_rejection_samples: Array[Dictionary] = []
	var recipe_ids: Array[StringName] = [
		&"balcony.wrap.left.blue.planted",
		&"balcony.wrap.right.orange.planted",
		&"balcony.wrap.left.amber.planted",
		&"balcony.wrap.right.blue.planted",
	]
	# Compact hills frequently place their upper facade beside no lower public
	# landing at all.  Preserve the fully connected wraparound stair as the first
	# choice, then admit the measured private walk-out vocabulary only for the
	# compact two-balcony budget.  A walk-out is still a real destination through
	# its parent-room portal: it owns one continuous deck, a completely guarded
	# outer perimeter, and two authored brackets.  Larger towns retain the richer
	# public-stair contract used by their non-zero balcony minimum.
	if target_count <= 2:
		recipe_ids.append_array([
			&"balcony.walkout.deep.left.blue.planted",
			&"balcony.walkout.deep.right.orange.planted",
			&"balcony.walkout.deep.left.amber.planted",
			&"balcony.walkout.deep.right.blue.planted",
			&"balcony.bracketed.left.blue.planted",
			&"balcony.bracketed.right.orange.planted",
			&"balcony.bracketed.left.amber.planted",
			&"balcony.bracketed.right.blue.planted",
		] as Array[StringName])
	var candidates: Array[Dictionary] = []
	for endpoint: Dictionary in _balcony_room_endpoints(buildings):
		var endpoint_cell := endpoint.cell as Vector3i
		if used_endpoint_cells.has(endpoint_cell):
			continue
		var facing := endpoint.facing as Vector3i
		var room := endpoint.room as WarrenRoomStamp
		var building := endpoint.building as WarrenBuildingVolume
		var owner_ids := allowed_owner_ids_by_source.get(room.source_parcel_id,
			{}) as Dictionary
		var phase := posmod(Helper._mix64(world_seed \
			^ String(room.stable_id).hash() ^ endpoint_cell.x * 73856093 \
			^ endpoint_cell.z * 19349663), recipe_ids.size())
		for recipe_offset in recipe_ids.size():
			var recipe_id := recipe_ids[(phase + recipe_offset) % recipe_ids.size()]
			var recipe := program.recipe(recipe_id)
			if recipe == null or not recipe.has_tag(&"balcony"):
				rejection_counts[&"missing_recipe"] += 1
				continue
			# The exact return-contact proof below is the authority. Wider houses may
			# use this finite L only when their transformed doorway is genuinely one
			# cell from a corner and the return reaches the same building's side wall;
			# a mid-facade placement simply produces no contact and is rejected.
			var socket := recipe.socket(&"room.back")
			var yaw := _yaw_for_local_direction(Vector3i.FORWARD, -facing)
			if socket.is_empty() or yaw < 0:
				rejection_counts[&"missing_socket"] += 1
				continue
			var socket_world := endpoint_cell + facing
			var origin := socket_world - FabricRecipe.transform_cell(
				socket.cell as Vector3i, Vector3i.ZERO, yaw)
			var body := _feature_recipe_cells(recipe, origin, yaw)
			if body.is_empty() or not WarrenVolumetricSolver \
					._skywalk_body_fits_grid(grid, body):
				rejection_counts[&"body_blocked"] += 1
				continue
			var return_contacts := _balcony_return_contact_cells(grid, body,
				building.stable_id, endpoint_cell, facing, origin.y)
			var wraparound := recipe.has_tag(&"wraparound_balcony")
			# A wrap must actually turn back into the owning building.  Compact private
			# walk-outs are the deliberately separate straight vocabulary above; their
			# room portal, deck, guards, and brackets are the complete construction.
			if wraparound and return_contacts.is_empty():
				rejection_counts[&"missing_return_contact"] += 1
				continue
			var stair_high := recipe.socket(&"stair.high")
			var stair_low := recipe.socket(&"stair.low")
			if wraparound and (stair_high.is_empty() or stair_low.is_empty()):
				rejection_counts[&"missing_public_stair_landing"] += 1
				continue
			var stair_high_world: Array[Vector3i] = []
			var stair_low_world: Array[Vector3i] = []
			if wraparound:
				stair_high_world.append(FabricRecipe.transform_cell(
					stair_high.cell as Vector3i, origin, yaw))
				stair_low_world.append(FabricRecipe.transform_cell(
					stair_low.cell as Vector3i, origin, yaw))
			var stair_lands := true
			for index in stair_low_world.size():
				var low_cell := stair_low_world[index]
				var stair_floor := grid.face_claim(low_cell, Vector3i.DOWN)
				stair_lands = stair_lands and body.has(stair_high_world[index]) \
					and grid.use_at(low_cell) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					and not stair_floor.is_empty() \
					and int(stair_floor.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR
			if not stair_lands:
				rejection_counts[&"missing_public_stair_landing"] += 1
				if stair_rejection_samples.size() < 12:
					var nearby_public_floors: Array[Vector3i] = []
					for nearby_z in range(origin.z - 3, origin.z + 4):
						for nearby_x in range(origin.x - 3, origin.x + 4):
							var nearby := Vector3i(nearby_x, origin.y - 1,
								nearby_z)
							var nearby_floor := grid.face_claim(nearby,
								Vector3i.DOWN)
							if grid.use_at(nearby) \
									== WarrenSpatialGrid.Use.PUBLIC_AIR \
									and int(nearby_floor.get("kind", -1)) \
										== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
								nearby_public_floors.append(nearby)
					stair_rejection_samples.append({
						"recipe_id": recipe_id,
						"origin": origin,
						"yaw": yaw,
						"high": stair_high_world,
						"high_in_body": [body.has(stair_high_world[0])],
						"low": stair_low_world,
						"low_use": [grid.use_at(stair_low_world[0])],
						"low_floor_kind": [int(grid.face_claim(
							stair_low_world[0], Vector3i.DOWN).get("kind", -1))],
						"nearby_public_floors": nearby_public_floors,
					})
				continue
			if _feature_bounds_overlap_unrelated_room(recipe, origin, yaw,
					building.stable_id, room.source_parcel_id,
					return_contacts, room_clearance_bounds):
				rejection_counts[&"unrelated_room_overlap"] += 1
				continue
			# The feature also changes its parent shell from a closed wall module to
			# one complete door-and-jamb variant.  That measured joint can project
			# farther than the base room even when the balcony itself is clear.  Prove
			# at least one normal/fallback facade phase here, before committing grid
			# cells; otherwise final fabric compilation can discover the collision too
			# late and reject an otherwise useful town.
			if _balcony_portal_overlaps_unrelated_room(room, facing, world_seed,
					program, room_clearance_bounds):
				rejection_counts[&"portal_room_overlap"] += 1
				continue
			var balcony_bounds := FabricRecipe.lattice_transform(origin, yaw) \
				* recipe.local_clearance_bounds
			# Room-scale cantilever supports are committed before balconies, but
			# their sloped/bracketed meshes are construction records rather than
			# private-volume cells. Compare the exact measured AABBs here; the grid
			# reservation alone cannot represent that oblique visual envelope.
			if _feature_bounds_overlap_existing_features(balcony_bounds,
					existing_features, program):
				rejection_counts[&"existing_feature_overlap"] += 1
				continue
			var components: Array[Dictionary] = [{"recipe_id": recipe_id,
				"origin": origin, "yaw_quarters": yaw}]
			var clearance := WarrenVolumetricSolver \
				._skywalk_visual_clearance_cells(components, program)
			var clearance_audit := _balcony_clearance_audit(grid, clearance,
				body, owner_ids, origin.y)
			if not bool(clearance_audit.get("fits", false)):
				rejection_counts[&"clearance_blocked"] += 1
				if clearance_rejection_samples.size() < 8:
					var clearance_sample := clearance_audit.duplicate()
					clearance_sample["origin"] = origin
					clearance_sample["recipe_id"] = recipe_id
					clearance_rejection_samples.append(clearance_sample)
				continue
			var facade_key := _balcony_facade_key(endpoint_cell, facing)
			var guard_segment_count := 0
			var support_count := 0
			for placement: Dictionary in recipe.placements:
				guard_segment_count += int(String(placement.id).begins_with("guard."))
				support_count += int(String(placement.id).begins_with("support.") \
					or String(placement.id).begins_with("brace."))
			var minimum_walk_x := 2147483647
			var maximum_walk_x := -2147483648
			for walk_cell: Vector3i in recipe.walk_cells:
				minimum_walk_x = mini(minimum_walk_x, walk_cell.x)
				maximum_walk_x = maxi(maximum_walk_x, walk_cell.x)
			var usable_width_cells := maximum_walk_x - minimum_walk_x + 1
			var door_lateral_clearance_cells := mini(
				(socket.cell as Vector3i).x - minimum_walk_x,
				maximum_walk_x - (socket.cell as Vector3i).x)
			# A straight platform is only a valid doorway destination when its side
			# rails begin at least one full cell away from the threshold bay.
			if not wraparound and door_lateral_clearance_cells < 1:
				rejection_counts[&"body_blocked"] += 1
				continue
			candidates.append({"recipe_id": recipe_id, "origin": origin,
				"yaw_quarters": yaw, "body": body, "clearance": clearance,
				"clearance_only": clearance_audit.clearance_only,
				"covered_public_cells": clearance_audit.covered_public_cells,
				"endpoint_cell": endpoint_cell, "endpoint_facing": facing,
				"socket_world": socket_world, "room": room,
				"building": building, "allowed_owner_ids": owner_ids,
				"facade_key": facade_key,
				"wraparound": wraparound,
				"deep_walkout": recipe.has_tag(&"deep_walkout"),
				"has_public_stair": wraparound,
				"stair_high_cells": stair_high_world,
				"stair_low_cells": stair_low_world,
				"stair_outward": FabricRecipe.transform_direction(
					stair_high.facing as Vector3i, yaw) if wraparound \
					else Vector3i.ZERO,
				"return_contact_cells": return_contacts,
				"usable_floor_cell_count": recipe.walk_cells.size(),
				"usable_width_cells": usable_width_cells,
				"door_lateral_clearance_cells": door_lateral_clearance_cells,
				"guard_segment_count": guard_segment_count,
				"support_count": support_count,
				"covered_public_count": int(clearance_audit.covered_public_count),
				"tie": posmod(Helper._mix64(world_seed ^ String(recipe_id).hash()
					^ endpoint_cell.x * 31 ^ endpoint_cell.y * 43 \
					^ endpoint_cell.z * 47), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.wraparound) != bool(b.wraparound):
			return bool(a.wraparound)
		if bool(a.deep_walkout) != bool(b.deep_walkout):
			return bool(a.deep_walkout)
		if int(a.covered_public_count) != int(b.covered_public_count):
			return int(a.covered_public_count) > int(b.covered_public_count)
		var a_room := a.room as WarrenRoomStamp
		var b_room := b.room as WarrenRoomStamp
		if a_room.source_storey_index != b_room.source_storey_index:
			return a_room.source_storey_index > b_room.source_storey_index
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var count_by_building: Dictionary = {}
	var used_facades: Dictionary = {}
	var used_rooms: Dictionary = {}
	var wraparound_count := 0
	for candidate: Dictionary in candidates:
		if out.size() >= target_count:
			break
		var building := candidate.building as WarrenBuildingVolume
		var room := candidate.room as WarrenRoomStamp
		if int(count_by_building.get(building.stable_id, 0)) \
				>= MAX_BALCONIES_PER_BUILDING or used_rooms.has(room.stable_id) \
				or used_facades.has(String(candidate.facade_key)):
			continue
		# Earlier accepted balconies may have consumed this residual void; rerun
		# the exact checks against the current grid before committing.
		var body := candidate.body as Dictionary
		if not WarrenVolumetricSolver._skywalk_body_fits_grid(grid, body):
			continue
		var refreshed := _balcony_clearance_audit(grid,
			candidate.clearance as Dictionary, body,
			candidate.allowed_owner_ids as Dictionary,
			(candidate.origin as Vector3i).y)
		if not bool(refreshed.get("fits", false)):
			continue
		candidate["clearance_only"] = refreshed.clearance_only
		candidate["covered_public_cells"] = refreshed.covered_public_cells
		candidate["covered_public_count"] = refreshed.covered_public_count
		var feature := _commit_balcony(grid, candidate, supports, out.size())
		if feature == null:
			continue
		out.append(feature)
		wraparound_count += int(bool(candidate.wraparound))
		count_by_building[building.stable_id] = int(count_by_building.get(
			building.stable_id, 0)) + 1
		used_rooms[room.stable_id] = true
		used_facades[String(candidate.facade_key)] = true
	last_skywalk_diagnostic["balcony_candidate_count"] = candidates.size()
	last_skywalk_diagnostic["balcony_rejection_counts"] = rejection_counts
	last_skywalk_diagnostic["balcony_stair_rejection_samples"] = \
		stair_rejection_samples
	last_skywalk_diagnostic["balcony_clearance_rejection_samples"] = \
		clearance_rejection_samples
	return out


static func _balcony_portal_overlaps_unrelated_room(room: WarrenRoomStamp,
		world_facing: Vector3i, world_seed: int,
		program: SettlementFabricProgram,
		room_bounds: Array[Dictionary]) -> bool:
	## Return true only when every finite parent-shell phase intersects an
	## unrelated room.  The compiler already prefers phase B and falls back to
	## phase A; balcony selection must preserve that same bounded choice.
	if room == null or program == null:
		return true
	var local_facing := FabricRecipe.transform_direction(world_facing,
		-room.yaw_quarters)
	var portal_bit := WarrenSpatialFabricCompiler._portal_bit_for_facing(
		local_facing)
	if portal_bit == 0:
		return true
	var seen: Dictionary = {}
	for allow_phase_b in [true, false]:
		var recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(room,
			world_seed, allow_phase_b, portal_bit)
		if seen.has(recipe_id):
			continue
		seen[recipe_id] = true
		var recipe := program.recipe(recipe_id)
		if recipe == null:
			continue
		var bounds := FabricRecipe.lattice_transform(room.lattice_origin,
			room.yaw_quarters) * recipe.local_clearance_bounds
		var fits := true
		for record: Dictionary in room_bounds:
			if StringName(record.room_id) == room.stable_id \
					or StringName(record.source_parcel_id) == room.source_parcel_id:
				continue
			if SettlementFabricPlan._aabb_overlaps_volume(bounds,
					record.bounds as AABB):
				fits = false
				break
		if fits:
			return false
	return true


static func _commit_balcony(grid: WarrenSpatialGrid, candidate: Dictionary,
		supports: WarrenSupportGraph, ordinal: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.balcony.%02d" % ordinal)
	var body_dict := candidate.body as Dictionary
	var body: Array[Vector3i] = []
	body.assign(body_dict.keys())
	body.sort_custom(_cell_less)
	var clearance_only: Array[Vector3i] = []
	clearance_only.assign((candidate.clearance_only as Dictionary).keys())
	var covered_public: Array[Vector3i] = []
	covered_public.assign((candidate.covered_public_cells as Dictionary).keys())
	var endpoint_cell := candidate.endpoint_cell as Vector3i
	var socket_world := candidate.socket_world as Vector3i
	var building := candidate.building as WarrenBuildingVolume
	var room := candidate.room as WarrenRoomStamp
	var allowed_owner_ids := candidate.allowed_owner_ids as Dictionary
	var base_y := (candidate.origin as Vector3i).y
	var stair_high_cells := candidate.stair_high_cells as Array[Vector3i]
	var stair_low_cells := candidate.stair_low_cells as Array[Vector3i]
	var stair_outward := candidate.stair_outward as Vector3i
	var has_public_stair := bool(candidate.get("has_public_stair", false))
	var is_deep_walkout := bool(candidate.get("deep_walkout", false))
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not covered_public.is_empty() and not tx.reserve(covered_public,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_dict.has(neighbor):
				continue
			var opens_to_room := Vector2i(cell.x, cell.z) \
					== Vector2i(socket_world.x, socket_world.z) \
				and neighbor == endpoint_cell + Vector3i.UP * (cell.y - base_y)
			var kind := WarrenSpatialGrid.FaceKind.OPEN_SEAM
			if opens_to_room:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT \
					if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif allowed_owner_ids.has(grid.owner_name_at(neighbor)):
				kind = WarrenSpatialGrid.FaceKind.FACADE
			elif cell in stair_high_cells and direction == stair_outward:
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif cell.y == base_y:
				kind = WarrenSpatialGrid.FaceKind.GUARD
			if not tx.claim_face(cell, direction, kind, feature_id):
				return null
	if not tx.commit():
		return null
	var feature := WarrenFeatureReservation.new(feature_id, &"balcony")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(endpoint_cell, building.stable_id) \
			or not feature.add_construction_record(
				StringName(candidate.recipe_id), candidate.origin as Vector3i,
				int(candidate.yaw_quarters), &"occupied_balcony") \
			or not feature.set_support_node(building.stable_id) \
			or not feature.set_audit_facts({
				"balcony_room_id": room.stable_id,
				"balcony_building_id": building.stable_id,
				"balcony_source_parcel_id": room.source_parcel_id,
				"balcony_recipe_id": StringName(candidate.recipe_id),
				"balcony_endpoint_facing": candidate.endpoint_facing as Vector3i,
				"balcony_wraparound": bool(candidate.wraparound),
				"balcony_return_contact_cell_count": (
					candidate.return_contact_cells as Array).size(),
				"balcony_usable_width_cells": int(
					candidate.usable_width_cells),
				"balcony_usable_depth_cells": 3 \
					if bool(candidate.wraparound) else 2 if is_deep_walkout else 1,
				"balcony_usable_floor_cell_count": int(
					candidate.usable_floor_cell_count),
				"balcony_door_count": 1,
				"balcony_guard_segment_count": int(
					candidate.guard_segment_count),
				"balcony_open_guard_seam_count": 1,
				"balcony_door_guard_opening_count": 1,
				"balcony_access_kind": &"room_door_and_public_stair" \
					if has_public_stair else &"private_room_walkout",
				"balcony_stair_count": int(has_public_stair),
				"balcony_stair_high_landing_cells": stair_high_cells,
				"balcony_stair_low_landing_cells": stair_low_cells,
				"balcony_stair_connected_to_public_floor": has_public_stair,
				"balcony_door_clearance_depth_cells": 3 \
					if bool(candidate.wraparound) else 2 if is_deep_walkout else 1,
				"balcony_door_lateral_clearance_cells": int(
					candidate.door_lateral_clearance_cells),
				"balcony_continuous_front_deck": true,
				"balcony_support_kind": &"full_storey_diagonal_braces" \
					if has_public_stair or is_deep_walkout \
					else &"shallow_timber_brackets",
				"balcony_support_count": int(candidate.support_count),
				"balcony_reserved_headroom_cell_count": body.size(),
				"balcony_visual_clearance_cell_count":
					(candidate.clearance as Dictionary).size(),
				"balcony_covered_public_cell_count": covered_public.size(),
				"balcony_facade_key": String(candidate.facade_key),
			}) or not feature.seal(grid, supports):
		return null
	return feature


static func _reserve_interstitial_joins(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation]) -> Dictionary:
	## Consume every one-cell interstitial slot with a typed two-owner
	## construction. A slot is a 1.5 m residual course trapped between occupied
	## walls; coincidental mesh adjacency is not a seam, so each slot becomes
	## deliberately sealed infill (buried under bridging mass or capped to the
	## sky). The former one-sided lean-to shoulder is intentionally retired: a
	## roof spanning a 1.5 m residual slot read as an unattached roof even when
	## its conservative envelope and bearing seam were technically valid. Any slot without a
	## complete authored closure rejects the town with a reason-coded refusal.
	if program == null:
		return {"failure": "interstitial joins need the measured vocabulary"}
	var raw_gap_cells: Dictionary = {}
	var gap_cells: Dictionary = {}
	for cell_value: Variant in grid.cells_with_use(
			WarrenSpatialGrid.Use.ALLOCATABLE):
		var cell := cell_value as Vector3i
		if not WarrenVolumetricSolver._is_one_cell_interstitial_gap(grid, cell):
			continue
		raw_gap_cells[cell] = true
		# Air exclusively reserved by a composed feature, or flanked by a
		# feature's own authored wall, is that feature's typed void; the
		# final audit reports it under its own key and the join transaction
		# must not fill it with mass.
		if WarrenVolumetricSolver._cell_has_exclusive_feature_reservation(
				grid, cell) \
				or WarrenVolumetricSolver._interstitial_gap_is_feature_adjacent(
					grid, cell):
			continue
		gap_cells[cell] = true
	# Never consume only half of a straight roof shoulder. A skywalk or another
	# composed feature may reserve one cell of the air band above that shoulder;
	# sealing its unreserved neighbor alone bisects the otherwise valid 3 m roof
	# run and forces the roof compiler to expose a one-cell lid. Keep the complete
	# raw run available to the roof transaction whenever any member is excluded.
	var partial_run_cells: Dictionary = {}
	for cell_value: Variant in gap_cells.keys():
		var cell := cell_value as Vector3i
		var detail := WarrenVolumetricSolver._interstitial_gap_detail(grid, cell)
		var run_direction := Vector3i(0, 0, 1) \
			if StringName(detail.axis) == &"x" else Vector3i(1, 0, 0)
		var raw_run: Array[Vector3i] = [cell]
		for sign: int in [-1, 1]:
			var cursor := cell + run_direction * sign
			while raw_gap_cells.has(cursor) \
					and StringName(WarrenVolumetricSolver \
						._interstitial_gap_detail(grid, cursor).axis) \
						== StringName(detail.axis):
				raw_run.append(cursor)
				cursor += run_direction * sign
		var has_excluded_member := false
		for run_cell: Vector3i in raw_run:
			has_excluded_member = has_excluded_member \
				or not gap_cells.has(run_cell)
		if has_excluded_member:
			for run_cell: Vector3i in raw_run:
				partial_run_cells[run_cell] = true
	for cell_value: Variant in partial_run_cells.keys():
		gap_cells.erase(cell_value as Vector3i)
	var features: Array[WarrenFeatureReservation] = []
	var class_counts: Dictionary = {}
	if gap_cells.is_empty():
		return {"features": features, "class_counts": class_counts,
			"failure": ""}
	var ordered_cells: Array[Vector3i] = []
	ordered_cells.assign(gap_cells.keys())
	# Bands must resolve bottom-up: a filled lower strip is the bearing fact a
	# stacked slit band above it relies on.
	ordered_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z)
	# Claimed cells from earlier constructions in this same pass count as
	# support for stacked slit bands discovered above them.
	var claimed: Dictionary = {}
	var ordinal := 0
	for start_cell: Vector3i in ordered_cells:
		if claimed.has(start_cell):
			continue
		var run := _interstitial_run(grid, gap_cells, claimed, start_cell)
		var run_cells := run.cells as Array[Vector3i]
		var trap_axis := StringName(run.axis)
		# A maximal run may mix conditions (one end buried under a stacked
		# slit, the other open beside a public route). Take the longest
		# classifiable prefix, commit it, and continue with the remainder.
		while not run_cells.is_empty():
			var prefix_size := run_cells.size()
			var classified: Dictionary = {}
			while prefix_size >= 1:
				var prefix: Array[Vector3i] = []
				for offset in prefix_size:
					prefix.append(run_cells[offset])
				classified = _classify_interstitial_run(grid, claimed, prefix,
					trap_axis)
				if StringName(classified.get("class", &"")) != &"unresolved":
					break
				prefix_size -= 1
			if prefix_size < 1:
				return {"failure": ("interstitial slot %s (axis %s) is " \
					+ "unresolved: %s") % [run_cells[0], trap_axis,
					String(classified.get("reason", "no closure"))]}
			var accepted: Array[Vector3i] = []
			for offset in prefix_size:
				accepted.append(run_cells[offset])
			var run_class := StringName(classified.get("class", &""))
			var chunks := _interstitial_chunks(accepted)
			for chunk: Array[Vector3i] in chunks:
				var feature := _commit_interstitial_join(grid, buildings,
					supports, world_seed, program, chunk, trap_axis,
					classified, ordinal)
				if feature == null:
					return {"failure": ("interstitial join at %s could not " \
						+ "commit its %s construction: %s") % [chunk[0],
						run_class, _last_interstitial_rejection]}
				features.append(feature)
				ordinal += 1
				for cell: Vector3i in chunk:
					claimed[cell] = true
				var chunk_class := StringName(feature.audit.get(
					"interstitial_class", run_class))
				class_counts[chunk_class] = int(class_counts.get(
					chunk_class, 0)) + 1
			run_cells = run_cells.slice(prefix_size)
	return {"features": features, "class_counts": class_counts, "failure": ""}


static func _interstitial_run(grid: WarrenSpatialGrid, gap_cells: Dictionary,
		claimed: Dictionary, start_cell: Vector3i) -> Dictionary:
	## Collect the maximal straight single-band run through the start cell along
	## its free axis. The trap axis comes from the same wall test as the audit.
	var detail := WarrenVolumetricSolver._interstitial_gap_detail(grid,
		start_cell)
	var trap_axis := StringName(detail.axis)
	var run_direction := Vector3i(0, 0, 1) if trap_axis == &"x" \
		else Vector3i(1, 0, 0)
	var cells: Array[Vector3i] = [start_cell]
	for sign: int in [-1, 1]:
		var cursor: Vector3i = start_cell + run_direction * sign
		while gap_cells.has(cursor) and not claimed.has(cursor) \
				and StringName(WarrenVolumetricSolver._interstitial_gap_detail(
					grid, cursor).axis) == trap_axis:
			if sign < 0:
				cells.push_front(cursor)
			else:
				cells.append(cursor)
			cursor += run_direction * sign
	return {"cells": cells, "axis": trap_axis}


static func _classify_interstitial_run(grid: WarrenSpatialGrid,
		_claimed: Dictionary, run_cells: Array[Vector3i],
		_trap_axis: StringName) -> Dictionary:
	## Decide whether the deliberately sealed strip is buried by upper mass or
	## capped to the sky, and whether it bears below or side-anchors to its two
	## occupied neighbours. One-sided sloping closures are not admitted here:
	## their roof footprint is necessarily wider than this residual course and
	## proved visually ambiguous in adversarial captures.
	var bearing_below := true
	for cell: Vector3i in run_cells:
		var below := cell + Vector3i.DOWN
		if grid.use_at(below) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				or String(grid.owner_name_at(below)).begins_with(
					"spatial.feature."):
			bearing_below = false
			break
	var covered_above := true
	for cell: Vector3i in run_cells:
		var above := cell + Vector3i.UP
		if grid.use_at(above) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				and not WarrenVolumetricSolver._is_one_cell_interstitial_gap(
					grid, above):
			covered_above = false
			break
	# Every trapped course seals as deliberate infill. With a
	# continuing wall or bridging cover above it reads as a stepped seam;
	# with two flush walltops it reads as a joined parapet between the two
	# houses; over an alley it becomes the soffit of a one-cell underpass.
	# The trap predicate already guarantees occupied walls on both sides and
	# never includes public air, so a side-anchored blocking course is always
	# a coherent authored closure.
	return {"class": &"sealed_infill",
		"buried": covered_above,
		"bearing_kind": &"below" if bearing_below else &"side"}


static func _interstitial_chunks(run_cells: Array[Vector3i]) -> Array:
	## Authored sealed closures exist in 1/2-cell strips. Longer runs split
	## deterministically from the run start so no oversized cap is stretched
	## across an unrelated pair of buildings.
	var out: Array = []
	var index := 0
	while index < run_cells.size():
		var take := 0
		take = mini(2, run_cells.size() - index)
		var chunk: Array[Vector3i] = []
		for offset in take:
			chunk.append(run_cells[index + offset])
		out.append(chunk)
		index += take
	return out


static func _commit_interstitial_join(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		_world_seed: int, program: SettlementFabricProgram,
		chunk: Array[Vector3i], trap_axis: StringName, classified: Dictionary,
		ordinal: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.interstitial_join.%02d" \
		% ordinal)
	var run_direction := Vector3i(0, 0, 1) if trap_axis == &"x" \
		else Vector3i(1, 0, 0)
	var trap_positive := Vector3i(1, 0, 0) if trap_axis == &"x" \
		else Vector3i(0, 0, 1)
	var yaw := -1
	for candidate_yaw in 4:
		if FabricRecipe.transform_direction(Vector3i(1, 0, 0), candidate_yaw) \
				== run_direction:
			yaw = candidate_yaw
			break
	if yaw < 0:
		_last_interstitial_rejection = "no yaw maps the recipe run axis"
		return null
	var origin := chunk[0]
	var chunk_class := &"sealed_infill"
	# A strip whose top is buried under bridging mass omits the cap.
	var buried := bool(classified.get("buried", false))
	var recipe_id := StringName("interstitial.seal.%d.%s" % [chunk.size(),
		"buried" if buried else "capped"])
	var recipe := program.recipe(recipe_id)
	if recipe == null:
		_last_interstitial_rejection = "missing measured recipe %s" % recipe_id
		return null
	var wall_owners: Dictionary = {}
	var cover_owners: Dictionary = {}
	var bearing_owner: StringName = &""
	for cell: Vector3i in chunk:
		for side: int in [-1, 1]:
			var wall_cell: Vector3i = cell + trap_positive * side
			if grid.use_at(wall_cell) == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				wall_owners[grid.owner_name_at(wall_cell)] = true
		# Mass bridging directly over a buried strip is part of the join's
		# sealed relationship: its storey legitimately grazes the strip's
		# conservative envelope from above.
		var above: Vector3i = cell + Vector3i.UP
		if grid.use_at(above) == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
			cover_owners[grid.owner_name_at(above)] = true
	# The support node must be a real building whose chain reaches terrain;
	# an earlier strip below a stacked slit is claimed mass, not a support
	# lineage the sealed graph can walk.
	var below := origin + Vector3i.DOWN
	if grid.use_at(below) == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
			and not String(grid.owner_name_at(below)).begins_with(
				"spatial.feature."):
		bearing_owner = grid.owner_name_at(below)
	if bearing_owner == &"":
		# Side-anchored strips bear on a flanking wall or covering owner;
		# deterministic first by name so repeated solves bind the identical
		# parent.
		var owner_ids: Array = wall_owners.keys()
		owner_ids.append_array(cover_owners.keys())
		owner_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
			return String(a) < String(b))
		for owner_value: Variant in owner_ids:
			if not String(StringName(owner_value)).begins_with(
					"spatial.feature."):
				bearing_owner = StringName(owner_value)
				break
		if bearing_owner == &"":
			_last_interstitial_rejection = \
				"no terrain-reaching building anchors the strip"
			return null
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(chunk, [WarrenSpatialGrid.Use.ALLOCATABLE] \
				as Array[int]) \
			or not tx.reserve(chunk, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(chunk, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		_last_interstitial_rejection = "grid claim: %s" % tx.last_rejection
		return null
	var chunk_set: Dictionary = {}
	for cell: Vector3i in chunk:
		chunk_set[cell] = true
	for cell: Vector3i in chunk:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if chunk_set.has(neighbor):
				continue
			# An adjacent strip committed earlier in this same pass, or a
			# carved public interface, may already own this exact face; typed
			# prior claims stay authoritative.
			if not grid.face_claim(cell, direction).is_empty():
				continue
			var neighbor_use := grid.use_at(neighbor)
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if neighbor_use == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				kind = WarrenSpatialGrid.FaceKind.PARTY_WALL
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			if not tx.claim_face(cell, direction, kind, feature_id):
				_last_interstitial_rejection = "face %s/%s: %s" % [cell,
					direction, tx.last_rejection]
				return null
	if not tx.commit():
		_last_interstitial_rejection = "commit: %s" % tx.last_rejection
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"interstitial_join")
	var wall_owner_ids: Array[StringName] = []
	wall_owner_ids.assign(wall_owners.keys())
	wall_owner_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var cover_owner_ids: Array[StringName] = []
	cover_owner_ids.assign(cover_owners.keys())
	cover_owner_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	if not feature.add_reserved_cells(chunk) \
			or not feature.add_construction_record(recipe_id, origin, yaw,
				chunk_class) \
			or not feature.set_support_node(bearing_owner) \
			or not feature.set_audit_facts({
				"interstitial_class": chunk_class,
				"interstitial_recipe_id": recipe_id,
				"interstitial_cell_count": chunk.size(),
				"interstitial_trap_axis": trap_axis,
				"interstitial_wall_owner_ids": wall_owner_ids,
				"interstitial_cover_owner_ids": cover_owner_ids,
				"interstitial_bearing_owner_id": bearing_owner,
				"interstitial_bearing_kind": StringName(classified.get(
					"bearing_kind", &"below")),
				"interstitial_upper_owner_id": StringName(classified.get(
					"upper_owner", &"")),
				"interstitial_buried": bool(classified.get("buried", false)),
			}) or not feature.seal(grid, supports):
		_last_interstitial_rejection = "reservation seal: %s" \
			% feature.last_rejection
		return null
	return feature


static func _balcony_return_contact_cells(grid: WarrenSpatialGrid,
		body: Dictionary, building_id: StringName, endpoint_cell: Vector3i,
		endpoint_facing: Vector3i, base_y: int) -> Array[Vector3i]:
	## A corner return must physically meet the owning side wall, independently
	## of the doorway's frontal face. The current one-cell return may meet a side
	## face of the same corner room cell, so direction—not cell identity—is the
	## exact distinction between a true wrap and a straight shelf.
	var contacts: Dictionary = {}
	for cell_value: Variant in body.keys():
		var cell := cell_value as Vector3i
		if cell.y != base_y:
			continue
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if grid.owner_name_at(neighbor) \
					!= building_id:
				continue
			if neighbor == endpoint_cell and direction == -endpoint_facing:
				continue
			contacts[neighbor] = true
	var out: Array[Vector3i] = []
	out.assign(contacts.keys())
	out.sort_custom(_cell_less)
	return out


static func _balcony_room_endpoints(
		buildings: Array[WarrenBuildingVolume]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			# Ground-floor decks read as porches. Balconies must contribute to the
			# interlocked upper silhouette and therefore begin on storey two.
			if room.source_storey_index < 1:
				continue
			var footprint := _room_footprint(room.kind)
			if footprint.is_empty():
				continue
			var minimum := footprint.minimum as Vector2i
			var maximum := minimum + footprint.size as Vector2i - Vector2i.ONE
			# Private feature apertures use the finite authored centre module on each
			# facade. The L recipe may still reach a corner on a 3 m or 6 m frontage;
			# its exact side-face contact below is what proves a genuine return.
			for local: Dictionary in [
				{"cell": Vector3i(maximum.x, 0, 0), "facing": Vector3i.RIGHT},
				{"cell": Vector3i(minimum.x, 0, 0), "facing": Vector3i.LEFT},
				{"cell": Vector3i(0, 0, minimum.y), "facing": Vector3i.FORWARD},
				{"cell": Vector3i(0, 0, maximum.y), "facing": Vector3i.BACK},
			]:
				out.append({"cell": FabricRecipe.transform_cell(
					local.cell as Vector3i, room.lattice_origin,
					room.yaw_quarters), "facing": FabricRecipe.transform_direction(
					local.facing as Vector3i, room.yaw_quarters),
					"room": room, "building": building})
	return out


static func _feature_recipe_cells(recipe: FabricRecipe, origin: Vector3i,
		yaw_quarters: int) -> Dictionary:
	var out: Dictionary = {}
	for cells: Array[Vector3i] in [recipe.solid_cells, recipe.walk_cells,
			recipe.headroom_cells]:
		for local_cell: Vector3i in cells:
			out[FabricRecipe.transform_cell(local_cell, origin, yaw_quarters)] = true
	return out


static func _room_clearance_bounds(
		buildings: Array[WarrenBuildingVolume], program: SettlementFabricProgram,
		world_seed: int) -> Array[Dictionary]:
	## Feature raster clearance and authored visual clearance answer different
	## questions. Cache both possible facade phases for every final room so a
	## balcony cannot fit between lattice cells while clipping a neighbour's
	## eaves, ivy, sign, or other measured projection.
	var out: Array[Dictionary] = []
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			var seen_recipes: Dictionary = {}
			for allow_phase_b in [true, false]:
				var recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
					room, world_seed, allow_phase_b)
				if seen_recipes.has(recipe_id):
					continue
				seen_recipes[recipe_id] = true
				var recipe := program.recipe(recipe_id)
				if recipe == null:
					continue
				out.append({
					"building_id": building.stable_id,
					"source_parcel_id": room.source_parcel_id,
					"room_id": room.stable_id,
					"private_cells": room.private_cells.duplicate(),
					"bounds": FabricRecipe.lattice_transform(room.lattice_origin,
						room.yaw_quarters) * recipe.local_clearance_bounds,
				})
	return out


static func _feature_bounds_overlap_unrelated_room(recipe: FabricRecipe,
		origin: Vector3i, yaw_quarters: int, building_id: StringName,
		related_source_id: StringName, return_contacts: Array[Vector3i],
		room_bounds: Array[Dictionary]) -> bool:
	var feature_bounds := FabricRecipe.lattice_transform(origin, yaw_quarters) \
		* recipe.local_clearance_bounds
	for record: Dictionary in room_bounds:
		var same_source := StringName(record.source_parcel_id) == related_source_id
		var return_room := StringName(record.building_id) == building_id \
			and _cells_intersect(record.private_cells as Array[Vector3i],
				return_contacts)
		# The doorway's source stack and the exact side-wall return room are named
		# construction seams. Every other room remains an unrelated hard obstacle.
		if same_source or return_room:
			continue
		if SettlementFabricPlan._aabb_overlaps_volume(feature_bounds,
				record.bounds as AABB):
			return true
	return false


static func _cells_intersect(left: Array[Vector3i],
		right: Array[Vector3i]) -> bool:
	for cell: Vector3i in right:
		if left.has(cell):
			return true
	return false


static func _balcony_clearance_audit(grid: WarrenSpatialGrid,
		clearance: Dictionary, body: Dictionary, allowed_owner_ids: Dictionary,
		base_y: int) -> Dictionary:
	if clearance.is_empty():
		return {"fits": false}
	var clearance_only: Dictionary = {}
	var covered_public: Dictionary = {}
	for cell_value: Variant in clearance.keys():
		var cell := cell_value as Vector3i
		if not grid.contains(cell):
			# A full-height balcony brace may deliberately terminate a few
			# centimetres inside immutable terrain below the spatial lattice. Keep
			# that load path instead of lifting it or rejecting the balcony; only
			# vertically-below cells within the grid's horizontal footprint qualify.
			var maximum := grid.minimum + grid.size
			if cell.y < grid.minimum.y and cell.x >= grid.minimum.x \
					and cell.x < maximum.x and cell.z >= grid.minimum.z \
					and cell.z < maximum.z:
				continue
			return {"fits": false, "reason": &"outside_grid",
				"blocked_cell": cell}
		if body.has(cell):
			continue
		var use_value := grid.use_at(cell)
		var owner_id := grid.owner_name_at(cell)
		if use_value == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				and allowed_owner_ids.has(owner_id):
			continue
		if use_value == WarrenSpatialGrid.Use.PUBLIC_AIR and cell.y < base_y:
			covered_public[cell] = true
			continue
		if use_value not in [WarrenSpatialGrid.Use.OUTSIDE,
				WarrenSpatialGrid.Use.ALLOCATABLE]:
			return {"fits": false, "reason": &"occupied",
				"blocked_cell": cell, "blocked_use": use_value,
				"blocked_owner": owner_id}
		if (grid.reservation_bits_at(cell) & (
				WarrenSpatialGrid.Reservation.FEATURE \
					| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)) != 0:
			return {"fits": false, "reason": &"reserved",
				"blocked_cell": cell,
				"blocked_reservations": grid.reservation_bits_at(cell)}
		clearance_only[cell] = true
	return {"fits": true, "clearance_only": clearance_only,
		"covered_public_cells": covered_public,
		"covered_public_count": covered_public.size()}


static func _feature_bounds_overlap_existing_features(bounds: AABB,
		existing_features: Array[WarrenFeatureReservation],
		program: SettlementFabricProgram) -> bool:
	for feature: WarrenFeatureReservation in existing_features:
		for record: Dictionary in feature.construction_records:
			var recipe := program.recipe(StringName(record.recipe_id))
			if recipe == null:
				return true
			var existing_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(bounds,
					existing_bounds):
				return true
	return false


static func _balcony_facade_key(cell: Vector3i, facing: Vector3i) -> String:
	# Deliberately omit Y: equivalent XZ/facing coordinates may not repeat up a
	# facade, which prevents a balcony stack from recreating the tower pattern.
	return "%d:%d/%d:%d" % [cell.x, cell.z, facing.x, facing.z]


static func _yaw_for_local_direction(local_direction: Vector3i,
		target_direction: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(local_direction, yaw) \
				== target_direction:
			return yaw
	return -1


static func _reserve_preplanned_market(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		reservation: Dictionary) -> WarrenFeatureReservation:
	## Commit the exact topology-first canopy/posts around an existing four-cell
	## public aisle. The public cells retain their canonical route owner; the
	## market incorporates them through a named construction seam instead of
	## painting a disconnected prefab beside the street after packing.
	if reservation.is_empty():
		last_failure = "covered market has no pre-partition reservation"
		return null
	var feature_id := StringName(reservation.get("feature_id", &""))
	var backing_parcel_id := StringName(reservation.get(
		"backing_parcel_id", &""))
	var backing_cell := reservation.get("backing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var backing_building: WarrenBuildingVolume
	var backing_room: WarrenRoomStamp
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.source_parcel_id != backing_parcel_id \
					or not room.has_private_cell(backing_cell):
				continue
			if backing_room != null:
				last_failure = "covered market backing socket has multiple room owners"
				return null
			backing_building = building
			backing_room = room
	if feature_id.is_empty() or backing_building == null or backing_room == null \
			or not backing_building.feature_ids.has(feature_id):
		last_failure = "covered market lost its exact backing room"
		return null
	var body: Array[Vector3i] = []
	body.assign((reservation.get("reserved_cells", {}) as Dictionary).keys())
	body.sort_custom(_cell_less)
	var public_cells: Array[Vector3i] = []
	public_cells.assign((reservation.get("public_cells", {}) as Dictionary).keys())
	public_cells.sort_custom(_cell_less)
	var covered_aisle_cells := reservation.get("covered_aisle_cells", {}) \
		as Dictionary
	var bearing_cells: Array[Vector3i] = []
	bearing_cells.assign((reservation.get("bearing_cells", {}) \
		as Dictionary).keys())
	if body.is_empty() or public_cells.size() < 4 \
			or covered_aisle_cells.size() != 4 or bearing_cells.is_empty():
		last_failure = "covered market reservation is incomplete"
		return null
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var overhead_public_floor_seam_count := 0
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.reserve(public_cells,
				WarrenSpatialGrid.Reservation.CONSTRUCTION_SEAM, feature_id) \
			or not tx.reserve(bearing_cells,
				WarrenSpatialGrid.Reservation.TERRAIN_BEARING, feature_id) \
			or not tx.assign_use(body,
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME, feature_id):
		last_failure = "could not stage topology-first covered market"
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.SOFFIT \
					if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PUBLIC_AIR \
					else WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			var existing := grid.face_claim(cell, direction)
			if not existing.is_empty():
				# A topology-first market may fit immediately beneath an upper
				# public route. Its canopy and that route meet at one physical
				# interface; the already-sealed PUBLIC_FLOOR remains the authority
				# instead of being overwritten by a duplicate ROOF label.
				if direction == Vector3i.UP and int(existing.kind) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
					overhead_public_floor_seam_count += 1
					continue
				last_failure = "covered-market face conflicts at %s toward %s" % [
					cell, direction]
				return null
			if not tx.claim_face(cell, direction, kind, feature_id):
				last_failure = "could not stage covered-market interface at %s" % cell
				return null
	if not tx.commit():
		last_failure = "covered market %s rejected: %s" % [feature_id,
			tx.last_rejection]
		return null
	var components := reservation.get("components", []) as Array
	if components.size() != 1:
		last_failure = "covered market is not one atomic reviewed construction"
		return null
	var component := components[0] as Dictionary
	var feature := WarrenFeatureReservation.new(feature_id, &"covered_market")
	if not feature.add_reserved_cells(body) \
			or not feature.add_public_cells(public_cells) \
			or not feature.add_endpoint(backing_cell,
				backing_building.stable_id) \
			or not feature.add_construction_record(
				StringName(component.recipe_id), component.origin as Vector3i,
				int(component.yaw_quarters), &"covered_bazaar") \
			or not feature.set_support_node(backing_building.stable_id) \
			or not feature.set_audit_facts({
				"market_aisle_cell_count": public_cells.size(),
				"market_covered_aisle_cell_count": covered_aisle_cells.size(),
				"market_aisle_extension_cell_count": int(reservation.get(
					"aisle_extension_cell_count", 0)),
				"market_new_public_cell_count": int(reservation.get(
					"new_public_cell_count", 0)),
				"market_street_entrance_edge_count": int(reservation.get(
					"street_entrance_edge_count", 0)),
				"market_street_entrance_width": int(reservation.get(
					"street_entrance_width", 0)),
				"market_stocked_bay_count": 2,
				"market_continuous_canopy": true,
				"market_overhead_public_floor_seam_count":
					overhead_public_floor_seam_count,
				"market_open_horizon_max_cells": int(reservation.get(
					"open_horizon_max_cells", 2147483647)),
				"market_open_horizon_total_cells": int(reservation.get(
					"open_horizon_total_cells", 2147483647)),
				"market_core_radius_squared": float(reservation.get(
					"core_radius_squared", INF)),
				"market_backing_room_id": backing_room.stable_id,
				"market_backing_building_id": backing_building.stable_id,
				"market_backing_parcel_id": backing_parcel_id,
				"market_recipe_id": StringName(component.recipe_id),
				"market_terrain_bearing_cell_count": bearing_cells.size(),
			}) or not feature.seal(grid, supports):
		last_failure = "covered market feature seal failed: %s" % \
			feature.last_rejection
		return null
	return feature


static func _reserve_preplanned_skywalks(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		reservations: Array[Dictionary],
		landmarks: Array[WarrenFeatureReservation] = []) \
		-> Array[WarrenFeatureReservation]:
	## Commit the exact feature-set selected before room partition. The former
	## late scanner threw those reservations away and tried to rediscover only
	## straight links after rooms had consumed the surrounding mass, which made
	## a topology-first plan indistinguishable from the retired detail pass.
	var out: Array[WarrenFeatureReservation] = []
	var offset_rooms := _offset_room_ids(buildings)
	for reservation_index in reservations.size():
		var reservation := reservations[reservation_index]
		var resolved := _resolve_preplanned_endpoints(grid, reservation, buildings,
			landmarks)
		if resolved.size() != 2:
			last_skywalk_diagnostic = _preplanned_endpoint_diagnostic(grid,
				reservation, buildings, reservation_index)
			last_failure = "preplanned skywalk %d lost an exact room endpoint" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var endpoint_owner_ids: Dictionary = {}
		var offset_endpoint_count := 0
		var landmark_endpoint_count := 0
		for endpoint: Dictionary in resolved:
			endpoint_owner_ids[StringName(endpoint.building_id)] = true
			var is_landmark := StringName(endpoint.get("endpoint_kind", &"")) \
				== &"landmark"
			landmark_endpoint_count += int(is_landmark)
			offset_endpoint_count += int(is_landmark or offset_rooms.has(
				StringName(endpoint.room_id)))
		if endpoint_owner_ids.size() != 2 or offset_endpoint_count < 1:
			last_failure = "preplanned skywalk %d lacks two owners or an offset endpoint" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var body_set := reservation.get("reserved_cells", {}) as Dictionary
		var body: Array[Vector3i] = []
		body.assign(body_set.keys())
		body.sort_custom(_cell_less)
		if body.is_empty():
			last_failure = "preplanned skywalk %d has no reserved body" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var lower_public_columns := _lower_public_columns(grid, body)
		if lower_public_columns.size() < 2:
			last_failure = "preplanned skywalk %d lost public circulation below" \
				% reservation_index
			return [] as Array[WarrenFeatureReservation]
		var feature := _commit_preplanned_skywalk(grid, reservation, resolved,
			body, lower_public_columns.size(), supports, reservation_index,
			offset_endpoint_count, landmark_endpoint_count)
		if feature == null:
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
	last_skywalk_diagnostic = {
		"preplanned_count": reservations.size(),
		"accepted_count": out.size(),
		"late_reinference_used": false,
	}
	return out


static func _preplanned_endpoint_diagnostic(grid: WarrenSpatialGrid,
		reservation: Dictionary, buildings: Array[WarrenBuildingVolume],
		reservation_index: int) -> Dictionary:
	var facts: Array[Dictionary] = []
	var owner_ids := reservation.get("owner_parcel_ids", []) as Array
	var endpoints := reservation.get("owner_endpoints", []) as Array
	for endpoint_index in mini(owner_ids.size(), endpoints.size()):
		var source_parcel_id := StringName(owner_ids[endpoint_index])
		var endpoint := endpoints[endpoint_index] as Dictionary
		var cell := endpoint.cell as Vector3i
		var source_rooms: Array[Dictionary] = []
		for building: WarrenBuildingVolume in buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.source_parcel_id != source_parcel_id:
					continue
				source_rooms.append({"building_id": building.stable_id,
					"room_id": room.stable_id, "origin": room.lattice_origin,
					"storey": room.source_storey_index,
					"contains_endpoint": room.has_private_cell(cell)})
		facts.append({"source_parcel_id": source_parcel_id, "cell": cell,
			"facing": endpoint.facing, "grid_use": grid.use_at(cell),
			"grid_owner": grid.owner_name_at(cell), "source_rooms": source_rooms})
	return {"reservation_index": reservation_index,
		"endpoint_facts": facts,
		"endpoint_pair_key": WarrenVolumetricSolver \
			._skywalk_endpoint_pair_key(reservation)}


static func _resolve_preplanned_endpoints(grid: WarrenSpatialGrid,
		reservation: Dictionary,
		buildings: Array[WarrenBuildingVolume],
		landmarks: Array[WarrenFeatureReservation] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var landmark_by_id: Dictionary = {}
	for landmark: WarrenFeatureReservation in landmarks:
		landmark_by_id[landmark.stable_id] = landmark
	var owner_ids := reservation.get("owner_parcel_ids", []) as Array
	var endpoints := reservation.get("owner_endpoints", []) as Array
	if owner_ids.size() != 2 or endpoints.size() != 2:
		return out
	var body := reservation.get("reserved_cells", {}) as Dictionary
	for endpoint_index in 2:
		var source_parcel_id := StringName(owner_ids[endpoint_index])
		var endpoint := endpoints[endpoint_index] as Dictionary
		var cell := endpoint.cell as Vector3i
		var facing := endpoint.facing as Vector3i
		if not body.has(cell + facing):
			return [] as Array[Dictionary]
		var landmark := landmark_by_id.get(source_parcel_id) \
			as WarrenFeatureReservation
		if landmark != null:
			if not landmark.reserved_cells.has(cell) \
					or grid.use_at(cell) != WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or grid.owner_name_at(cell) != landmark.stable_id:
				return [] as Array[Dictionary]
			out.append({"cell": cell, "facing": facing,
				"building_id": landmark.stable_id,
				"room_id": landmark.stable_id,
				"source_parcel_id": landmark.stable_id,
				"endpoint_kind": &"landmark"})
			continue
		var endpoint_match: Dictionary = {}
		for building: WarrenBuildingVolume in buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.source_parcel_id != source_parcel_id \
						or not room.has_private_cell(cell):
					continue
				if not endpoint_match.is_empty():
					return [] as Array[Dictionary]
				endpoint_match = {"cell": cell, "facing": facing,
					"building_id": building.stable_id,
					"room_id": room.stable_id,
					"source_parcel_id": source_parcel_id,
					"endpoint_kind": &"room"}
		if endpoint_match.is_empty():
			return [] as Array[Dictionary]
		out.append(endpoint_match)
	return out


static func _lower_public_columns(grid: WarrenSpatialGrid,
		body: Array[Vector3i]) -> Dictionary:
	var minimum_y := 2147483647
	for cell: Vector3i in body:
		minimum_y = mini(minimum_y, cell.y)
	var out: Dictionary = {}
	for cell: Vector3i in body:
		if cell.y != minimum_y:
			continue
		for down in range(1, 9):
			if grid.use_at(cell + Vector3i.DOWN * down) \
					== WarrenSpatialGrid.Use.PUBLIC_AIR:
				out[Vector2i(cell.x, cell.z)] = true
				break
	return out


static func _commit_preplanned_skywalk(grid: WarrenSpatialGrid,
		reservation: Dictionary, resolved: Array[Dictionary],
		body: Array[Vector3i], lower_public_column_count: int,
		supports: WarrenSupportGraph, ordinal: int,
		offset_endpoint_count: int,
		landmark_endpoint_count: int = 0) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.skywalk.%02d" % ordinal)
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var endpoint_cells: Dictionary = {}
	var endpoint_owner_ids: Dictionary = {}
	for endpoint: Dictionary in resolved:
		endpoint_cells[endpoint.cell as Vector3i] = true
		endpoint_owner_ids[StringName(endpoint.building_id)] = true
	var clearance_only: Array[Vector3i] = []
	for cell_value: Variant in (reservation.get("visual_clearance_cells", {}) \
			as Dictionary).keys():
		if body_set.has(cell_value):
			continue
		var cell := cell_value as Vector3i
		var existing_visual := (grid.reservation_bits_at(cell) \
			& WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE) != 0
		if existing_visual:
			var endpoint_owns_clearance := false
			for owner_value: Variant in endpoint_owner_ids.keys():
				if grid.reservation_owned_by(cell,
						WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE,
						StringName(owner_value)):
					endpoint_owns_clearance = true
					break
			if endpoint_owns_clearance:
				continue
			# Candidate selection already rejects intersecting measured AABBs for
			# every pair in the accepted triple. Two disjoint eaves may still touch
			# the same conservative 1.5 m raster cell; the earlier skywalk keeps
			# ownership of that coarse cell and the later one relies on the exact
			# pair proof. Solid/private volume remains mutually exclusive below.
			var prior_skywalk_owns_clearance := false
			for prior_ordinal in ordinal:
				var prior_id := StringName("spatial.feature.skywalk.%02d" \
					% prior_ordinal)
				if grid.reservation_owned_by(cell,
						WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE,
						prior_id):
					prior_skywalk_owns_clearance = true
					break
			if prior_skywalk_owns_clearance:
				continue
			last_failure = "skywalk clearance changed before commit at %s; owners=%s" \
				% [cell, grid.reservation_owner_names_at(cell,
					WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE)]
			return null
		clearance_only.append(cell)
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not clearance_only.is_empty() and not tx.reserve(clearance_only,
				WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		last_failure = "could not stage preplanned skywalk %s" % feature_id
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if endpoint_cells.has(neighbor):
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				last_failure = "could not stage skywalk interface at %s" % cell
				return null
	if not tx.commit():
		last_failure = "preplanned skywalk %s rejected: %s" % [feature_id,
			tx.last_rejection]
		return null
	var feature := WarrenFeatureReservation.new(feature_id,
		&"enclosed_skywalk")
	if not feature.add_reserved_cells(body):
		last_failure = "could not record preplanned skywalk volume"
		return null
	for endpoint: Dictionary in resolved:
		if not feature.add_endpoint(endpoint.cell as Vector3i,
				StringName(endpoint.building_id)):
			last_failure = "could not record preplanned skywalk endpoint"
			return null
	var components := reservation.get("components", []) as Array
	for component_index in components.size():
		var component := components[component_index] as Dictionary
		if not feature.add_construction_record(
				StringName(component.recipe_id), component.origin as Vector3i,
				int(component.yaw_quarters), StringName("component.%02d" \
					% component_index)):
			last_failure = "could not record skywalk construction component"
			return null
	var left := resolved[0]
	var right := resolved[1]
	var support_owner := &""
	for endpoint: Dictionary in resolved:
		var candidate_owner := StringName(endpoint.building_id)
		if supports.reaches_terrain(candidate_owner):
			support_owner = candidate_owner
			break
	var endpoint_bindings: Array[Dictionary] = []
	for endpoint: Dictionary in resolved:
		endpoint_bindings.append({
			"endpoint_kind": StringName(endpoint.endpoint_kind),
			"owner_id": StringName(endpoint.building_id),
			"room_id": StringName(endpoint.room_id),
			"cell": endpoint.cell,
			"facing": endpoint.facing,
		})
	if support_owner.is_empty() or not feature.set_support_node(support_owner) \
			or not feature.set_audit_facts({
				"skywalk_kind": StringName(reservation.get("kind", &"straight")),
				"skywalk_component_count": components.size(),
				"skywalk_lower_public_column_count": lower_public_column_count,
				"skywalk_offset_endpoint_count": offset_endpoint_count,
				"skywalk_landmark_endpoint_count": landmark_endpoint_count,
				"skywalk_visual_clearance_cell_count": body.size() \
					+ clearance_only.size(),
				"skywalk_endpoint_bindings": endpoint_bindings,
				"skywalk_left_room_id": StringName(left.room_id),
				"skywalk_right_room_id": StringName(right.room_id),
				"skywalk_endpoint_pair_key": WarrenVolumetricSolver \
					._skywalk_endpoint_pair_key(reservation),
			}) or not feature.seal(grid, supports):
		last_failure = "preplanned skywalk feature seal failed: %s" \
			% feature.last_rejection
		return null
	return feature


static func _courtyard_side_endpoints(grid: WarrenSpatialGrid,
		floors: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for direction: Vector3i in SKY_DIRECTIONS:
		var endpoint: Dictionary = {}
		var cells: Array[Vector3i] = []
		cells.assign(floors.keys())
		cells.sort_custom(_cell_less)
		for floor: Vector3i in cells:
			if floors.has(floor + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				var neighbor := floor + direction + Vector3i.UP * y_offset
				if grid.use_at(neighbor) == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
					endpoint = {"cell": neighbor,
						"owner_id": grid.owner_name_at(neighbor),
						"direction": direction}
					break
			if not endpoint.is_empty():
				break
		if not endpoint.is_empty():
			out.append(endpoint)
	return out


static func _reserve_skywalks(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, target_count: int = TARGET_SKYWALKS) \
		-> Array[WarrenFeatureReservation]:
	var endpoints := _room_endpoints(buildings)
	var by_key: Dictionary = {}
	for endpoint: Dictionary in endpoints:
		by_key[_endpoint_key(endpoint.cell as Vector3i,
			endpoint.facing as Vector3i)] = endpoint
	var candidates: Array[Dictionary] = []
	var endpoint_pair_count := 0
	var offset_endpoint_pair_count := 0
	for left: Dictionary in endpoints:
		var facing := left.facing as Vector3i
		for distance: int in [3, 5, 7]:
			var right_cell := (left.cell as Vector3i) + facing * distance
			var right := by_key.get(_endpoint_key(right_cell, -facing), {}) \
				as Dictionary
			if right.is_empty() or left.building_id == right.building_id \
					or String(left.room_id) > String(right.room_id):
				continue
			endpoint_pair_count += 1
			offset_endpoint_pair_count += int(bool(left.offset_floorplate) \
				or bool(right.offset_floorplate))
			var candidate := _skywalk_candidate(grid, left, right, distance)
			if not candidate.is_empty():
				candidate["tie"] = posmod(Helper._mix64(world_seed \
					^ String(left.room_id).hash() ^ String(right.room_id).hash()),
					1000003)
				candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.lower_public_column_count) != int(b.lower_public_column_count):
			return int(a.lower_public_column_count) \
				> int(b.lower_public_column_count)
		if int(a.distance) != int(b.distance):
			return int(a.distance) > int(b.distance)
		return int(a.tie) < int(b.tie))
	var out: Array[WarrenFeatureReservation] = []
	var endpoint_pairs: Dictionary = {}
	var candidate_summaries: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		candidate_summaries.append({
			"left": StringName(candidate.left.building_id),
			"right": StringName(candidate.right.building_id),
			"distance": int(candidate.distance),
			"origin": candidate.origin,
		})
		if out.size() >= target_count:
			break
		var pair_key := _pair_key(StringName(candidate.left.building_id),
			StringName(candidate.right.building_id))
		if endpoint_pairs.has(pair_key):
			continue
		var feature := _commit_skywalk(grid, candidate, supports, out.size())
		if feature == null:
			continue
		endpoint_pairs[pair_key] = true
		out.append(feature)
	last_skywalk_diagnostic = {
		"room_endpoint_count": endpoints.size(),
		"endpoint_pair_count": endpoint_pair_count,
		"offset_endpoint_pair_count": offset_endpoint_pair_count,
		"clear_candidate_count": candidates.size(),
		"accepted_count": out.size(),
		"candidates": candidate_summaries,
	}
	return out


static func _skywalk_candidate(grid: WarrenSpatialGrid, left: Dictionary,
		right: Dictionary, distance: int) -> Dictionary:
	if not bool(left.offset_floorplate) and not bool(right.offset_floorplate):
		return {}
	var direction := left.facing as Vector3i
	var length_cells := distance - 1
	var yaw := _yaw_from_right(direction)
	if yaw < 0 or length_cells not in [2, 4, 6]:
		return {}
	var minimum_x := -length_cells / 2
	var first_gap := (left.cell as Vector3i) + direction
	var origin := first_gap - FabricRecipe.transform_cell(
		Vector3i(minimum_x, 0, 0), Vector3i.ZERO, yaw)
	var body: Dictionary = {}
	for y in 4:
		for z in range(-1, 1):
			for x in range(minimum_x, minimum_x + length_cells):
				var cell := FabricRecipe.transform_cell(Vector3i(x, y, z),
					origin, yaw)
				if not grid.contains(cell) or grid.use_at(cell) not in [
						WarrenSpatialGrid.Use.OUTSIDE,
						WarrenSpatialGrid.Use.ALLOCATABLE] \
						or (grid.reservation_bits_at(cell) \
							& WarrenSpatialGrid.Reservation.FEATURE) != 0:
					return {}
				body[cell] = true
	var lower_public_columns: Dictionary = {}
	for body_value: Variant in body.keys():
		var body_cell := body_value as Vector3i
		if body_cell.y != origin.y:
			continue
		for down in range(1, 9):
			var lower := body_cell + Vector3i.DOWN * down
			if grid.use_at(lower) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				lower_public_columns[Vector2i(body_cell.x, body_cell.z)] = true
				break
	if lower_public_columns.size() < 2:
		return {}
	var body_cells: Array[Vector3i] = []
	body_cells.assign(body.keys())
	body_cells.sort_custom(_cell_less)
	return {"left": left, "right": right, "distance": distance,
		"origin": origin, "yaw_quarters": yaw, "body_cells": body_cells,
		"lower_public_column_count": lower_public_columns.size()}


static func _commit_skywalk(grid: WarrenSpatialGrid, candidate: Dictionary,
		supports: WarrenSupportGraph, ordinal: int) -> WarrenFeatureReservation:
	var feature_id := StringName("spatial.feature.skywalk.%02d" % ordinal)
	var body := candidate.body_cells as Array[Vector3i]
	var body_set: Dictionary = {}
	for cell: Vector3i in body:
		body_set[cell] = true
	var left := candidate.left as Dictionary
	var right := candidate.right as Dictionary
	var endpoints: Dictionary = {
		left.cell as Vector3i: true,
		right.cell as Vector3i: true,
	}
	var tx := grid.begin_transaction(feature_id)
	if not tx.require_use(body, [WarrenSpatialGrid.Use.OUTSIDE,
			WarrenSpatialGrid.Use.ALLOCATABLE] as Array[int]) \
			or not tx.reserve(body, WarrenSpatialGrid.Reservation.FEATURE \
				| WarrenSpatialGrid.Reservation.PRIVATE_CONNECTION \
				| WarrenSpatialGrid.Reservation.VISUAL_CLEARANCE, feature_id) \
			or not tx.assign_use(body, WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				feature_id):
		return null
	for cell: Vector3i in body:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if body_set.has(neighbor):
				continue
			var kind := WarrenSpatialGrid.FaceKind.FACADE
			if endpoints.has(neighbor):
				kind = WarrenSpatialGrid.FaceKind.OPEN_SEAM
			elif direction == Vector3i.UP:
				kind = WarrenSpatialGrid.FaceKind.ROOF
			elif direction == Vector3i.DOWN:
				kind = WarrenSpatialGrid.FaceKind.PRIVATE_FLOOR
			if not tx.claim_face(cell, direction, kind, feature_id):
				return null
	if not tx.commit():
		return null
	var distance := int(candidate.distance)
	var recipe_id := &"skywalk.3.blue" if distance == 3 \
		else &"skywalk.6.orange" if distance == 5 else &"skywalk.9.blue"
	var feature := WarrenFeatureReservation.new(feature_id,
		&"enclosed_skywalk")
	if not feature.add_reserved_cells(body) \
			or not feature.add_endpoint(left.cell as Vector3i,
				StringName(left.building_id)) \
			or not feature.add_endpoint(right.cell as Vector3i,
				StringName(right.building_id)) \
			or not feature.set_support_node(StringName(left.building_id)) \
			or not feature.add_construction_record(recipe_id,
				candidate.origin as Vector3i, int(candidate.yaw_quarters)) \
			or not feature.set_audit_facts({
				"skywalk_distance_cells": distance,
				"skywalk_lower_public_column_count": int(
					candidate.lower_public_column_count),
				"skywalk_left_room_id": StringName(left.room_id),
				"skywalk_right_room_id": StringName(right.room_id),
			}) or not feature.seal(grid, supports):
		return null
	return feature


static func _reserve_room_outcroppings(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume], supports: WarrenSupportGraph,
		world_seed: int, program: SettlementFabricProgram,
		existing_features: Array[WarrenFeatureReservation] = [],
		_target_count: int = TARGET_ROOM_OUTCROPPINGS) \
		-> Array[WarrenFeatureReservation]:
	if program == null or program.recipe(&"outcrop.support.bracketed.2") == null \
			or program.recipe(&"outcrop.support.diagonal.2") == null \
			or program.recipe(&"outcrop.support.bracketed.1") == null \
			or program.recipe(&"outcrop.support.diagonal.1") == null:
		last_failure = "room outcroppings lack the measured bracket vocabulary"
		return [] as Array[WarrenFeatureReservation]
	var building_by_room: Dictionary = {}
	var rooms_by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			building_by_room[room.stable_id] = building
			if not rooms_by_source.has(room.source_parcel_id):
				rooms_by_source[room.source_parcel_id] = [] \
					as Array[WarrenRoomStamp]
			(rooms_by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var candidates: Array[Dictionary] = []
	for rooms_value: Variant in rooms_by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			var delta := Vector2i(upper.lattice_origin.x - lower.lattice_origin.x,
				upper.lattice_origin.z - lower.lattice_origin.z)
			if delta == Vector2i.ZERO:
				continue
			var geometry := _room_cantilever_geometry(lower, upper)
			if geometry.is_empty():
				continue
			candidates.append({"lower": lower, "upper": upper,
				"building": building_by_room[upper.stable_id], "delta": delta,
				"extension_column_count": int(geometry.extension_column_count),
				"cantilever_geometry": geometry,
				"tie": posmod(Helper._mix64(world_seed \
					^ String(upper.stable_id).hash()), 1000003)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_valid := bool((a.cantilever_geometry as Dictionary).valid)
		var b_valid := bool((b.cantilever_geometry as Dictionary).valid)
		if a_valid != b_valid:
			return a_valid
		if int(a.extension_column_count) != int(b.extension_column_count):
			return int(a.extension_column_count) > int(b.extension_column_count)
		return int(a.tie) < int(b.tie))
	var valid_candidate_count := 0
	var rejection_counts: Dictionary = {}
	for candidate: Dictionary in candidates:
		var geometry := candidate.cantilever_geometry as Dictionary
		valid_candidate_count += int(bool(geometry.valid))
		if not bool(geometry.valid):
			var rejection := StringName(geometry.rejection)
			rejection_counts[rejection] = int(rejection_counts.get(rejection, 0)) + 1
	var out: Array[WarrenFeatureReservation] = []
	var measured_support_conflict_count := 0
	var measured_support_conflict_kinds: Dictionary = {}
	var directly_borne_cantilever_count := 0
	var support_required_cantilever_count := 0
	var selected_support_required_cantilever_count := 0
	var selected_directly_borne_cantilever_count := 0
	var directly_borne_irregular_projection_count := 0
	var supported_irregular_projection_count := 0
	var unsupported_irregular_projection_count := 0
	var unsupported_irregular_projection_details: Array[Dictionary] = []
	var supported_irregular_upper_ids: Dictionary = {}
	for existing_feature: WarrenFeatureReservation in existing_features:
		for key: StringName in [&"overhang_upper_room_id",
				&"arcade_upper_room_id", &"gateway_room_id"]:
			var supported_upper_id := StringName(existing_feature.audit.get(
				key, &""))
			if not supported_upper_id.is_empty():
				supported_irregular_upper_ids[supported_upper_id] = true
	var support_entries: Array[Dictionary] = []
	var support_options_by_upper: Dictionary = {}
	for candidate: Dictionary in candidates:
		# Invalid shifted rooms remain in the diagnostic census so future grammar
		# changes cannot silently reintroduce them, but they are not outcroppings.
		# A corner-shifted box or a mostly floating upper plate must never satisfy
		# this feature quota merely because some columns differ from the floor below.
		var geometry := candidate.cantilever_geometry as Dictionary
		var upper := candidate.upper as WarrenRoomStamp
		if not bool(geometry.valid):
			var extension: Array[Vector2i] = []
			extension.assign(geometry.get("extension_columns", []) as Array)
			if supported_irregular_upper_ids.has(upper.stable_id):
				supported_irregular_projection_count += 1
			elif _projection_columns_are_directly_borne(upper, extension, grid):
				directly_borne_irregular_projection_count += 1
			else:
				unsupported_irregular_projection_count += 1
				if unsupported_irregular_projection_details.size() < 12:
					var lower := candidate.lower as WarrenRoomStamp
					var shallow := _shallow_room_overhang_geometry(lower,
						upper, grid)
					unsupported_irregular_projection_details.append({
						"upper_room_id": upper.stable_id,
						"lower_room_id": lower.stable_id,
						"upper_kind": upper.kind,
						"lower_kind": lower.kind,
						"upper_origin": upper.lattice_origin,
						"lower_origin": lower.lattice_origin,
						"vertical_delta_cells": upper.lattice_origin.y \
							- lower.lattice_origin.y,
						"shallow_grid_geometry": shallow,
						"rejection": StringName(geometry.get(
							"rejection", &"unclassified")),
						"extension_column_count": extension.size(),
					})
			continue
		# Recomposition can move a room beyond the immediately preceding room in
		# its source lineage while landing it directly on a different inhabited
		# volume. That is a genuine floorplate outcropping but not a floating one;
		# the exact grid below every projected column is its visible load path.
		if _cantilever_is_directly_borne(upper, geometry, grid):
			directly_borne_cantilever_count += 1
			continue
		support_required_cantilever_count += 1
		var support_records := _cantilever_support_records(upper, geometry, grid)
		if support_records.is_empty():
			measured_support_conflict_count += 1
			measured_support_conflict_kinds[&"missing_support_course"] = int(
				measured_support_conflict_kinds.get(
					&"missing_support_course", 0)) + 1
			continue
		var related_room_ids := {
			upper.stable_id: true,
			(candidate.lower as WarrenRoomStamp).stable_id: true,
		}
		# Supports are mandatory structure. Choose them as one town-wide measured
		# transaction instead of greedily freezing the first diagonal course: a
		# later neighboring outcrop may need that same volume and may only become
		# solvable when the earlier course uses its reviewed shallow bracket.
		var support_options := _cantilever_support_options(support_records,
			related_room_ids, buildings, existing_features, program, world_seed)
		if support_options.is_empty():
			var failed_analysis := _outcrop_support_analysis(support_records,
				related_room_ids, buildings, existing_features, program, world_seed)
			var support_conflict := StringName(failed_analysis.conflict)
			if support_conflict.is_empty():
				support_conflict = &"support_configuration"
			measured_support_conflict_count += 1
			measured_support_conflict_kinds[support_conflict] = int(
				measured_support_conflict_kinds.get(support_conflict, 0)) + 1
			continue
		var support_key := String(upper.stable_id)
		support_entries.append({"key": support_key,
			"candidate": candidate, "options": support_options})
	var assignment_state := {"visited_node_count": 0,
		"peak_assigned_count": 0}
	var support_assignments := _assign_cantilever_supports(support_entries,
		assignment_state)
	if support_assignments.size() != support_entries.size():
		var unresolved_assignment_count := support_entries.size()
		measured_support_conflict_count += unresolved_assignment_count
		measured_support_conflict_kinds[&"feature.room_outcropping"] = int(
			measured_support_conflict_kinds.get(
				&"feature.room_outcropping", 0)) + unresolved_assignment_count
	else:
		support_options_by_upper = support_assignments
	for candidate: Dictionary in candidates:
		if not bool((candidate.cantilever_geometry as Dictionary).valid):
			continue
		var building := candidate.building as WarrenBuildingVolume
		var upper := candidate.upper as WarrenRoomStamp
		var geometry := candidate.cantilever_geometry as Dictionary
		var directly_borne := _cantilever_is_directly_borne(upper, geometry, grid)
		var support_records: Array[Dictionary] = []
		var support_analysis := {"neighbor_room_ids": [] as Array[StringName]}
		if not directly_borne:
			var support_key := String(upper.stable_id)
			if not support_options_by_upper.has(support_key):
				continue
			var support_option := support_options_by_upper[support_key] as Dictionary
			support_records.assign(support_option.records as Array)
			support_analysis = support_option.analysis as Dictionary
		var feature_id := StringName("spatial.feature.outcrop.%02d" % out.size())
		var tx := grid.begin_transaction(feature_id)
		if not tx.reserve(upper.private_cells,
				WarrenSpatialGrid.Reservation.FEATURE, feature_id) \
				or not tx.commit():
			continue
		var feature := WarrenFeatureReservation.new(feature_id,
			&"room_outcropping")
		if not feature.add_reserved_cells(upper.private_cells) \
				or not feature.add_endpoint(upper.private_cells[0],
					building.stable_id) \
				or not feature.set_support_node(building.stable_id):
			last_failure = "room outcropping support identity failed"
			return [] as Array[WarrenFeatureReservation]
		for record: Dictionary in support_records:
			if not feature.add_construction_record(StringName(record.recipe_id),
					record.origin as Vector3i, int(record.yaw_quarters),
					StringName(record.role)):
				last_failure = "room outcropping bracket record failed"
				return [] as Array[WarrenFeatureReservation]
		if not feature.set_audit_facts({
					"outcrop_source_parcel_id": upper.source_parcel_id,
					"outcrop_upper_room_id": upper.stable_id,
					"outcrop_lower_room_id": (candidate.lower \
						as WarrenRoomStamp).stable_id,
					"outcrop_extension_column_count": int(
						candidate.extension_column_count),
					"outcrop_room_footprint_column_count": \
						upper.private_cells.size() / WarrenSpatialGrid.STOREY_CELLS,
					"outcrop_is_integrated_cantilever": bool(geometry.valid),
					"outcrop_projection_direction": geometry.direction as Vector2i,
					"outcrop_projection_directions": geometry.get(
						"projection_directions", []),
					"outcrop_projection_direction_count": int(geometry.get(
						"projection_direction_count", 0)),
					"outcrop_is_diagonal_overlap": bool(geometry.get(
						"is_diagonal_overlap", false)),
					"outcrop_overlap_column_count": int(geometry.get(
						"overlap_column_count", 0)),
					"outcrop_projection_depth_cells": int(geometry.depth_cells),
					"outcrop_attachment_span_cells": int(
						geometry.attachment_span_cells),
					"outcrop_bearing_column_count": int(geometry.bearing_column_count),
					"outcrop_bearing_ratio": float(geometry.bearing_ratio),
					"outcrop_support_course_count": support_records.size(),
					"outcrop_support_neighbor_room_ids":
						support_analysis.neighbor_room_ids,
					"outcrop_is_directly_borne": directly_borne,
					"outcrop_diagonal_support_course_count": support_records.filter(
						func(record: Dictionary) -> bool:
							return String(record.recipe_id).begins_with(
								"outcrop.support.diagonal.")).size(),
					"outcrop_geometry_rejection": StringName(geometry.rejection),
				}) or not feature.seal(grid, supports):
			last_failure = "room outcropping seal failed: %s" % \
				feature.last_rejection
			return [] as Array[WarrenFeatureReservation]
		out.append(feature)
		if directly_borne:
			selected_directly_borne_cantilever_count += 1
		else:
			selected_support_required_cantilever_count += 1
	last_outcropping_diagnostic = {
		"room_outcropping_candidate_count": candidates.size(),
		"integrated_cantilever_candidate_count": valid_candidate_count,
		"noncantilever_outcropping_candidate_count": candidates.size() \
			- valid_candidate_count,
		"selected_integrated_cantilever_count": out.filter(
			func(feature: WarrenFeatureReservation) -> bool:
				return bool(feature.audit.get(
					"outcrop_is_integrated_cantilever", false))).size(),
		"outcrop_diagonal_support_course_count": out.reduce(
			func(total: int, feature: WarrenFeatureReservation) -> int:
				return total + int(feature.audit.get(
					"outcrop_diagonal_support_course_count", 0)), 0),
		"cantilever_rejection_counts": rejection_counts,
		"cantilever_measured_support_conflict_count":
			measured_support_conflict_count,
		"cantilever_measured_support_conflict_kinds":
			measured_support_conflict_kinds,
		"directly_borne_integrated_cantilever_count":
			directly_borne_cantilever_count,
		"selected_directly_borne_integrated_cantilever_count":
			selected_directly_borne_cantilever_count,
		"directly_borne_irregular_projection_count":
			directly_borne_irregular_projection_count,
		"supported_irregular_projection_count":
			supported_irregular_projection_count,
		"unsupported_irregular_projection_count":
			unsupported_irregular_projection_count,
		"unsupported_irregular_projection_details":
			unsupported_irregular_projection_details,
		"support_required_integrated_cantilever_count":
			support_required_cantilever_count,
		"unresolved_integrated_cantilever_count":
			support_required_cantilever_count \
			- selected_support_required_cantilever_count,
		"cantilever_support_assignment_node_count": int(
			assignment_state.visited_node_count),
		"cantilever_support_assignment_peak_count": int(
			assignment_state.peak_assigned_count),
	}
	return out


static func _cantilever_support_options(records: Array[Dictionary],
		related_room_ids: Dictionary, buildings: Array[WarrenBuildingVolume],
		existing_features: Array[WarrenFeatureReservation],
		program: SettlementFabricProgram, world_seed: int) -> Array[Dictionary]:
	## Each diagonal course has one authored shallow alternative. Enumerating
	## per-course choices matters: replacing an entire facade at once can move a
	## collision from one end of a room to the other and falsely reject a sound
	## mixed support course.
	var diagonal_indices: Array[int] = []
	for index in records.size():
		if String(records[index].recipe_id).begins_with(
				"outcrop.support.diagonal."):
			diagonal_indices.append(index)
	var option_count := 1 << diagonal_indices.size()
	var out: Array[Dictionary] = []
	for mask in option_count:
		var option_records: Array[Dictionary] = []
		for source: Dictionary in records:
			option_records.append(source.duplicate(true))
		for bit in diagonal_indices.size():
			if mask & (1 << bit):
				var source_recipe := StringName(
					option_records[diagonal_indices[bit]].recipe_id)
				option_records[diagonal_indices[bit]]["recipe_id"] = \
					&"outcrop.support.bracketed.1" \
					if source_recipe == &"outcrop.support.diagonal.1" \
					else &"outcrop.support.bracketed.2"
		var analysis := _outcrop_support_analysis(option_records,
			related_room_ids, buildings, existing_features, program, world_seed)
		if not StringName(analysis.conflict).is_empty():
			continue
		var bounds := _cantilever_support_bounds(option_records, program)
		if bounds.size() != option_records.size():
			continue
		out.append({"records": option_records, "analysis": analysis,
			"bounds": bounds,
			"diagonal_count": option_records.filter(
				func(record: Dictionary) -> bool:
					return String(record.recipe_id).begins_with(
						"outcrop.support.diagonal.")).size(),
			"tie": mask})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.diagonal_count) != int(b.diagonal_count):
			return int(a.diagonal_count) > int(b.diagonal_count)
		return int(a.tie) < int(b.tie))
	return out


static func _cantilever_support_bounds(records: Array[Dictionary],
		program: SettlementFabricProgram) -> Array[AABB]:
	var out: Array[AABB] = []
	if program == null:
		return out
	for record: Dictionary in records:
		var recipe := program.recipe(StringName(record.recipe_id))
		if recipe == null or not recipe.has_tag(&"cantilever_support"):
			return [] as Array[AABB]
		out.append(FabricRecipe.lattice_transform(record.origin as Vector3i,
			int(record.yaw_quarters)) * recipe.local_clearance_bounds)
	return out


static func _assign_cantilever_supports(entries: Array[Dictionary],
		state: Dictionary) -> Dictionary:
	var ordered := entries.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_options := (a.options as Array).size()
		var b_options := (b.options as Array).size()
		if a_options != b_options:
			return a_options < b_options
		return String(a.key) < String(b.key))
	var assignments: Dictionary = {}
	var claimed_supports: Array[Dictionary] = []
	if _assign_cantilever_supports_recursive(ordered, 0, claimed_supports,
			assignments, state):
		return assignments
	return {}


static func _assign_cantilever_supports_recursive(entries: Array,
		position: int, claimed_supports: Array[Dictionary], assignments: Dictionary,
		state: Dictionary) -> bool:
	state["visited_node_count"] = int(state.visited_node_count) + 1
	state["peak_assigned_count"] = maxi(int(state.peak_assigned_count), position)
	if int(state.visited_node_count) > MAX_CANTILEVER_SUPPORT_ASSIGNMENT_NODES:
		return false
	if position >= entries.size():
		return true
	var entry := entries[position] as Dictionary
	for option_value: Variant in entry.options as Array:
		var option := option_value as Dictionary
		var overlaps := false
		var option_bounds: Array[AABB] = []
		option_bounds.assign(option.bounds as Array)
		var option_records: Array[Dictionary] = []
		option_records.assign(option.get("records", []) as Array)
		for bounds_index in option_bounds.size():
			var bounds := option_bounds[bounds_index]
			var record := option_records[bounds_index] as Dictionary \
				if bounds_index < option_records.size() else {}
			for claimed: Dictionary in claimed_supports:
				if SettlementFabricPlan._aabb_overlaps_volume(bounds,
						claimed.bounds as AABB) \
						and not _cantilever_supports_share_frame(record,
							claimed.record as Dictionary):
					overlaps = true
					break
			if overlaps:
				break
		if overlaps:
			continue
		var old_support_count := claimed_supports.size()
		for bounds_index in option_bounds.size():
			claimed_supports.append({"bounds": option_bounds[bounds_index],
				"record": option_records[bounds_index] as Dictionary \
					if bounds_index < option_records.size() else {}})
		assignments[String(entry.key)] = option
		if _assign_cantilever_supports_recursive(entries, position + 1,
				claimed_supports, assignments, state):
			return true
		assignments.erase(String(entry.key))
		claimed_supports.resize(old_support_count)
	return false


static func _cantilever_supports_share_frame(left: Dictionary,
		right: Dictionary) -> bool:
	## Cantilever courses are authored pieces of one town-wide timber frame. Their
	## conservative AABBs may overlap at shared posts, consecutive lifts, or a
	## perpendicular braced joint; the fabric compiler records those intersections
	## as explicit joinery seams. Feature and inhabited-room envelopes were already
	## checked before this global assignment and remain hard conflicts.
	if left.is_empty() or right.is_empty():
		return false
	return String(left.get("recipe_id", "")).begins_with(
		"outcrop.support.") and String(right.get("recipe_id", "")).begins_with(
			"outcrop.support.")


static func _shallow_cantilever_support_records(
		records: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source: Dictionary in records:
		var record := source.duplicate(true)
		var source_id := String(record.get("recipe_id", ""))
		record["recipe_id"] = &"outcrop.support.bracketed.1" \
			if source_id.ends_with(".1") \
			else &"outcrop.support.bracketed.2"
		out.append(record)
	return out


static func _outcrop_support_analysis(
		support_records: Array[Dictionary], related_room_ids: Dictionary,
		buildings: Array[WarrenBuildingVolume],
		existing_features: Array[WarrenFeatureReservation],
		program: SettlementFabricProgram, world_seed: int) -> Dictionary:
	## Brackets are selected as measured construction, not added after topology.
	## They may enter the conservative envelopes of the exact upper/lower room
	## plates they join. A measured intersection with another inhabited room is
	## an explicit load-bearing seam, not a conflict: the compiler names that
	## room as an additional attachment parent. Previously reserved composed
	## features remain hard conflicts because a brace may not pierce a market,
	## balcony, skywalk, or courtyard asset.
	var support_bounds: Array[AABB] = []
	var neighbor_room_ids: Dictionary = {}
	for record: Dictionary in support_records:
		var support_recipe := program.recipe(StringName(record.recipe_id))
		if support_recipe == null or not support_recipe.has_tag(
				&"cantilever_support"):
			return {"conflict": &"missing_support_recipe",
				"neighbor_room_ids": [] as Array[StringName]}
		support_bounds.append(FabricRecipe.lattice_transform(
			record.origin as Vector3i, int(record.yaw_quarters)) \
			* support_recipe.local_clearance_bounds)
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if related_room_ids.has(room.stable_id):
				continue
			# Room compilation already tries the rich phase-B facade first and falls
			# back to its plain measured shell when a sealed feature needs the same
			# clearance. Requiring a support to clear *both* possible facades made
			# optional laundry, ivy, or bay detail veto load-bearing brackets before
			# that fallback mechanism could run. The plain shell is the only hard
			# structural envelope here; the room compiler will sacrifice decoration,
			# never the support.
			var room_recipe_id := WarrenSpatialFabricCompiler._room_recipe_id(
				room, world_seed, false)
			var room_recipe := program.recipe(room_recipe_id)
			if room_recipe == null:
				return {"conflict": &"missing_room_recipe",
					"neighbor_room_ids": [] as Array[StringName]}
			var room_bounds := FabricRecipe.lattice_transform(
				room.lattice_origin, room.yaw_quarters) \
				* room_recipe.local_clearance_bounds
			for bounds: AABB in support_bounds:
				if SettlementFabricPlan._aabb_overlaps_volume(bounds,
						room_bounds):
					neighbor_room_ids[room.stable_id] = true
	for feature: WarrenFeatureReservation in existing_features:
		for record: Dictionary in feature.construction_records:
			var feature_recipe := program.recipe(StringName(record.recipe_id))
			if feature_recipe == null:
				return {"conflict": &"missing_feature_recipe",
					"neighbor_room_ids": [] as Array[StringName]}
			var feature_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* feature_recipe.local_clearance_bounds
			for bounds: AABB in support_bounds:
				if SettlementFabricPlan._aabb_overlaps_volume(bounds,
						feature_bounds):
					return {"conflict": StringName("feature.%s" % feature.kind),
						"neighbor_room_ids": [] as Array[StringName]}
	var ordered_neighbor_ids: Array[StringName] = []
	ordered_neighbor_ids.assign(neighbor_room_ids.keys())
	ordered_neighbor_ids.sort()
	return {"conflict": &"", "neighbor_room_ids": ordered_neighbor_ids}


static func _cantilever_is_directly_borne(upper: WarrenRoomStamp,
		geometry: Dictionary, grid: WarrenSpatialGrid) -> bool:
	if upper == null or grid == null or not bool(geometry.get("valid", false)):
		return false
	var extension: Array[Vector2i] = []
	extension.assign(geometry.get("extension_columns", []) as Array)
	return _projection_columns_are_directly_borne(upper, extension, grid)


static func _projection_columns_are_directly_borne(upper: WarrenRoomStamp,
		extension: Array[Vector2i], grid: WarrenSpatialGrid) -> bool:
	# An empty extension means the upper floorplate is a setback wholly inside
	# the lower one. It is fully borne even when its authored origin/yaw changed.
	if upper == null or grid == null:
		return false
	if extension.is_empty():
		return true
	for column: Vector2i in extension:
		var below := Vector3i(column.x, upper.lattice_origin.y - 1, column.y)
		if grid.use_at(below) not in [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
			return false
	return true


static func _cantilever_support_records(upper: WarrenRoomStamp,
		geometry: Dictionary, grid: WarrenSpatialGrid = null) \
		-> Array[Dictionary]:
	## Tile each leg of the diagonal overlap with native 1.5/3 m bracket courses.
	## The two perpendicular courses meet as one authored corner frame: no mesh is
	## stretched and no independent room is attached at the end of the parent.
	var out: Array[Dictionary] = []
	if upper == null or not bool(geometry.get("valid", false)):
		return out
	var courses: Array[Dictionary] = []
	courses.assign(geometry.get("projection_courses", []) as Array)
	# Retain the single-course adapter for old diagnostic fixtures which exercise
	# support tiling directly. Production outcroppings always provide two courses.
	if courses.is_empty():
		courses.append({
			"direction": geometry.get("direction", Vector2i.ZERO),
			"depth_cells": int(geometry.get("depth_cells", 0)),
			"attachment_columns": geometry.get("attachment_columns", []),
		})
	for course_index in courses.size():
		var course_records := _cantilever_support_course_records(upper,
			geometry, courses[course_index], course_index, grid)
		if course_records.is_empty():
			return [] as Array[Dictionary]
		out.append_array(course_records)
	return out


static func _cantilever_support_course_records(upper: WarrenRoomStamp,
		geometry: Dictionary, course: Dictionary, course_index: int,
		grid: WarrenSpatialGrid = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var direction_2d := course.get("direction", Vector2i.ZERO) as Vector2i
	var direction := Vector3i(direction_2d.x, 0, direction_2d.y)
	var yaw := _yaw_for_local_direction(Vector3i.BACK, direction)
	if yaw < 0:
		return out
	var span_direction_3d := FabricRecipe.transform_direction(Vector3i.RIGHT,
		yaw)
	var span_direction := Vector2i(span_direction_3d.x, span_direction_3d.z)
	var attachment: Array[Vector2i] = []
	attachment.assign(course.get("attachment_columns", []) as Array)
	if attachment.size() == 1:
		# A one-column corner jetty still receives the native two-brace course:
		# the second brace lands on the adjacent borne floor column instead of
		# inventing a scaled one-off support asset.
		var bearing_columns: Dictionary = {}
		for bearing_value: Variant in geometry.get("bearing_columns", []) as Array:
			bearing_columns[bearing_value as Vector2i] = true
		var anchor := attachment[0]
		for sign_value in [-1, 1]:
			var neighbor := anchor + span_direction * int(sign_value)
			if bearing_columns.has(neighbor):
				attachment.append(neighbor)
				break
	if attachment.size() < 2:
		return out
	attachment.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * span_direction.x + a.y * span_direction.y \
			< b.x * span_direction.x + b.y * span_direction.y)
	for index in range(1, attachment.size()):
		if attachment[index] != attachment[index - 1] + span_direction:
			return [] as Array[Dictionary]
	for index in range(0, attachment.size(), 2):
		var column := attachment[index]
		var course_size := mini(2, attachment.size() - index)
		var course_columns: Array[Vector2i] = [column]
		if course_size == 2:
			course_columns.append(column + span_direction)
		# A neighboring lower room may bear only this 3 m slice of a longer
		# outcropping. Omit that brace course while retaining brackets beneath the
		# genuinely open slices; otherwise the full-width support recipe intersects
		# the very construction already carrying it.
		if _cantilever_course_is_directly_borne(grid, course_columns, direction,
				upper.lattice_origin.y, int(course.get("depth_cells", 0))):
			continue
		var recipe_id := StringName("outcrop.support.diagonal.%d" % course_size) \
			if _diagonal_cantilever_sweep_is_clear(grid, course_columns,
				direction, upper.lattice_origin.y) \
			else StringName("outcrop.support.bracketed.%d" % course_size)
		out.append({
			"recipe_id": recipe_id,
			"origin": Vector3i(column.x, upper.lattice_origin.y, column.y),
			"yaw_quarters": yaw,
			"role": StringName("cantilever_support.%02d.%02d" % [
				course_index, index / 2]),
		})
	return out


static func _cantilever_course_is_directly_borne(grid: WarrenSpatialGrid,
		attachment_columns: Array[Vector2i], direction: Vector3i,
		upper_base_y: int, projection_depth: int) -> bool:
	if grid == null or attachment_columns.is_empty() or projection_depth < 1:
		return false
	for attachment: Vector2i in attachment_columns:
		for depth in range(1, projection_depth + 1):
			var column := Vector2i(attachment.x + direction.x * depth,
				attachment.y + direction.z * depth)
			if grid.use_at(Vector3i(column.x, upper_base_y - 1, column.y)) \
					not in [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
						WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
				return false
	return true


static func _diagonal_cantilever_sweep_is_clear(grid: WarrenSpatialGrid,
		attachment_columns: Array[Vector2i], direction: Vector3i,
		upper_base_y: int) -> bool:
	## The native brace drops 3.606 m (slightly over two fine bands) and projects
	## 2.372 m from its facade post. Conservatively inspect three bands below the
	## room and two outward columns. Private mass is allowed here because the
	## measured-envelope pass immediately afterwards proves it belongs to the
	## upper/lower room pair; public, daylight, service, or court structure is
	## never pierced by a decorative support.
	if grid == null:
		return false
	for attachment: Vector2i in attachment_columns:
		for depth in [0, 1, 2]:
			var column := Vector2i(attachment.x + direction.x * depth,
				attachment.y + direction.z * depth)
			for y in range(upper_base_y - 3, upper_base_y):
				var use_value := grid.use_at(Vector3i(column.x, y, column.y))
				if use_value in [WarrenSpatialGrid.Use.PUBLIC_AIR,
						WarrenSpatialGrid.Use.DAYLIGHT_AIR,
						WarrenSpatialGrid.Use.SERVICE_VOID,
						WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
					return false
	return true


static func _shallow_room_overhang_geometry(lower: WarrenRoomStamp,
		upper: WarrenRoomStamp, grid: WarrenSpatialGrid = null) -> Dictionary:
	## Recognize one straight, at-most-3 m-deep projection of a room with at
	## least a 6 x 3 m floorplate. A compact 3 x 3 m tower is never eligible: an
	## unsupported part of that module reads as the entire box jutting outward.
	if lower == null or upper == null:
		return {}
	var consecutive := upper.lattice_origin.y - lower.lattice_origin.y \
		== WarrenSpatialGrid.STOREY_CELLS
	if grid == null and not consecutive:
		return {}
	# A lineage may resume above a neighboring macro room after one source block
	# was consumed by recomposition. In the final grid, only the immediately
	# underlying occupied course is bearing; a distant same-lineage floorplate is
	# ancestry, not support.
	var lower_columns := _room_columns(lower) if consecutive else {}
	var upper_columns := _room_columns(upper)
	if upper_columns.size() < 8:
		return {}
	var bearing: Dictionary = {}
	var extension: Dictionary = {}
	for column_value: Variant in upper_columns.keys():
		var column := column_value as Vector2i
		var below := Vector3i(column.x, upper.lattice_origin.y - 1, column.y)
		if lower_columns.has(column) or grid != null \
				and grid.use_at(below) in [WarrenSpatialGrid.Use.PRIVATE_VOLUME,
					WarrenSpatialGrid.Use.STRUCTURAL_VOLUME]:
			bearing[column] = true
		else:
			extension[column] = true
	if extension.is_empty() or bearing.size() * 2 < upper_columns.size() \
			or not _columns_are_connected(extension):
		return {}
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i.UP, Vector2i.DOWN]:
		var attachments: Dictionary = {}
		var max_depth := 0
		var valid := true
		for column_value: Variant in extension.keys():
			var column := column_value as Vector2i
			var attached := false
			for depth in range(1, 3):
				var inward := column - direction * depth
				if bearing.has(inward):
					attachments[inward] = true
					max_depth = maxi(max_depth, depth)
					attached = true
					break
			if not attached:
				valid = false
				break
		if not valid or attachments.size() < 2:
			continue
		var span := Vector2i(-direction.y, direction.x)
		var ordered := _sorted_columns(attachments)
		ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x * span.x + a.y * span.y \
				< b.x * span.x + b.y * span.y)
		var plane := ordered[0].x * direction.x \
			+ ordered[0].y * direction.y
		for index in ordered.size():
			var attachment := ordered[index]
			if attachment.x * direction.x + attachment.y * direction.y \
					!= plane or index > 0 \
					and attachment != ordered[index - 1] + span:
				valid = false
				break
		if not valid:
			continue
		return {
			"valid": true,
			"rejection": &"",
			"direction": direction,
			"projection_directions": [direction] as Array[Vector2i],
			"projection_direction_count": 1,
			"projection_courses": [{
				"direction": direction,
				"depth_cells": max_depth,
				"attachment_columns": ordered,
			}] as Array[Dictionary],
			"is_diagonal_overlap": false,
			"overlap_column_count": bearing.size(),
			"depth_cells": max_depth,
			"attachment_span_cells": attachments.size(),
			"attachment_columns": ordered,
			"bearing_columns": _sorted_columns(bearing),
			"extension_columns": _sorted_columns(extension),
			"extension_column_count": extension.size(),
			"bearing_column_count": bearing.size(),
			"bearing_ratio": float(bearing.size()) / float(upper_columns.size()),
		}
	return {}


static func _room_cantilever_geometry(lower: WarrenRoomStamp,
		upper: WarrenRoomStamp) -> Dictionary:
	## A full-scale room outcropping is the user's diagonal-overlap diagram: the
	## next congruent floorplate moves exactly one 1.5 m cell on both axes. Most of
	## the room therefore remains integrated with its parent while an L-shaped
	## corner projects across two facades. A one-axis shift is deliberately not an
	## outcropping; it reads as another box glued to the end of the first.
	var lower_columns := _room_columns(lower)
	var upper_columns := _room_columns(upper)
	if lower_columns.size() < 4 or upper_columns.size() < 4:
		return {}
	var lower_bounds := _column_bounds(lower_columns)
	var upper_bounds := _column_bounds(upper_columns)
	var lower_size := (lower_bounds.maximum as Vector2i) \
		- (lower_bounds.minimum as Vector2i) + Vector2i.ONE
	var upper_size := (upper_bounds.maximum as Vector2i) \
		- (upper_bounds.minimum as Vector2i) + Vector2i.ONE
	if lower_columns.size() != lower_size.x * lower_size.y \
			or upper_columns.size() != upper_size.x * upper_size.y:
		return _cantilever_rejection({}, 0, upper_columns.size(),
			&"nonrectangular_floorplate")
	var extension: Dictionary = {}
	var bearing_columns: Dictionary = {}
	var bearing := 0
	for column_value: Variant in upper_columns.keys():
		var column := column_value as Vector2i
		if lower_columns.has(column):
			bearing += 1
			bearing_columns[column] = true
		else:
			extension[column] = true
	if lower_columns.size() != upper_columns.size() or lower_size != upper_size:
		return _cantilever_rejection(extension, bearing, upper_columns.size(),
			&"full_scale_overlap_required")
	var offset := (upper_bounds.minimum as Vector2i) \
		- (lower_bounds.minimum as Vector2i)
	if absi(offset.x) != 1 or absi(offset.y) != 1:
		return _cantilever_rejection({}, 0, upper_columns.size(),
			&"diagonal_overlap_required", offset, maxi(absi(offset.x),
				absi(offset.y)))
	if extension.is_empty():
		return {}
	if not _columns_are_connected(extension):
		return _cantilever_rejection(extension, bearing,
			upper_columns.size(), &"disconnected_projection", offset, 1)
	var bearing_ratio := float(bearing) / float(upper_columns.size())
	if bearing_ratio < 0.50:
		return _cantilever_rejection(extension, bearing,
			upper_columns.size(), &"insufficient_bearing", offset, 1)
	var directions: Array[Vector2i] = [
		Vector2i(signi(offset.x), 0), Vector2i(0, signi(offset.y)),
	]
	var projection_courses: Array[Dictionary] = []
	var all_attachment: Dictionary = {}
	for direction: Vector2i in directions:
		var attachment: Dictionary = {}
		for bearing_value: Variant in bearing_columns.keys():
			var bearing_column := bearing_value as Vector2i
			if extension.has(bearing_column + direction):
				attachment[bearing_column] = true
				all_attachment[bearing_column] = true
		if attachment.is_empty():
			return _cantilever_rejection(extension, bearing,
				upper_columns.size(), &"attachment_too_narrow", direction, 1)
		projection_courses.append({
			"direction": direction,
			"depth_cells": 1,
			"attachment_columns": _sorted_columns(attachment),
		})
	return {
		"valid": true,
		"rejection": &"",
		"direction": directions[0],
		"projection_directions": directions,
		"projection_direction_count": directions.size(),
		"projection_courses": projection_courses,
		"is_diagonal_overlap": true,
		"overlap_column_count": bearing,
		"depth_cells": 1,
		"attachment_span_cells": all_attachment.size(),
		"attachment_columns": _sorted_columns(all_attachment),
		"bearing_columns": _sorted_columns(bearing_columns),
		"extension_columns": _sorted_columns(extension),
		"extension_column_count": extension.size(),
		"bearing_column_count": bearing,
		"bearing_ratio": bearing_ratio,
	}


static func _cantilever_rejection(extension: Dictionary, bearing: int,
		upper_count: int, rejection: StringName,
		direction: Vector2i = Vector2i.ZERO, depth: int = 0,
		attachment_span: int = 0) -> Dictionary:
	return {
		"valid": false,
		"rejection": rejection,
		"direction": direction,
		"depth_cells": depth,
		"attachment_span_cells": attachment_span,
		"extension_columns": _sorted_columns(extension),
		"extension_column_count": extension.size(),
		"bearing_column_count": bearing,
		"bearing_ratio": float(bearing) / float(upper_count) \
			if upper_count > 0 else 0.0,
	}


static func _room_columns(room: WarrenRoomStamp) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in room.private_cells:
		out[Vector2i(cell.x, cell.z)] = true
	return out


static func _column_bounds(columns: Dictionary) -> Dictionary:
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in columns.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	return {"minimum": minimum, "maximum": maximum}


static func _columns_are_connected(columns: Dictionary) -> bool:
	if columns.is_empty():
		return false
	var keys: Array = columns.keys()
	var frontier: Array[Vector2i] = [keys[0] as Vector2i]
	var visited: Dictionary = {frontier[0]: true}
	while not frontier.is_empty():
		var column: Vector2i = frontier.pop_back()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			var neighbor := column + direction
			if columns.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)
	return visited.size() == columns.size()


static func _sorted_columns(columns: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(columns.keys())
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	return out


static func _room_endpoints(buildings: Array[WarrenBuildingVolume]) \
		-> Array[Dictionary]:
	var offset_rooms := _offset_room_ids(buildings)
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			var footprint := _room_footprint(room.kind)
			if footprint.is_empty():
				continue
			var minimum := footprint.minimum as Vector2i
			var maximum := minimum + footprint.size as Vector2i - Vector2i.ONE
			var locals: Array[Dictionary] = []
			for z in [minimum.y, 0, maximum.y]:
				locals.append({"cell": Vector3i(maximum.x, 0, z),
					"facing": Vector3i.RIGHT})
				locals.append({"cell": Vector3i(minimum.x, 0, z),
					"facing": Vector3i.LEFT})
			for x in [minimum.x, 0, maximum.x]:
				locals.append({"cell": Vector3i(x, 0, maximum.y),
					"facing": Vector3i.BACK})
				locals.append({"cell": Vector3i(x, 0, minimum.y),
					"facing": Vector3i.FORWARD})
			for local: Dictionary in locals:
				var cell := FabricRecipe.transform_cell(local.cell as Vector3i,
					room.lattice_origin, room.yaw_quarters)
				var facing := FabricRecipe.transform_direction(
					local.facing as Vector3i, room.yaw_quarters)
				var key := "%s/%s/%s" % [room.stable_id, cell, facing]
				if seen.has(key):
					continue
				seen[key] = true
				out.append({"cell": cell, "facing": facing,
					"building_id": building.stable_id,
					"room_id": room.stable_id,
					"offset_floorplate": offset_rooms.has(room.stable_id)})
	return out


static func _offset_room_ids(buildings: Array[WarrenBuildingVolume]) \
		-> Dictionary:
	var by_source: Dictionary = {}
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not by_source.has(room.source_parcel_id):
				by_source[room.source_parcel_id] = [] as Array[WarrenRoomStamp]
			(by_source[room.source_parcel_id] \
				as Array[WarrenRoomStamp]).append(room)
	var out: Dictionary = {}
	for rooms_value: Variant in by_source.values():
		var rooms := rooms_value as Array[WarrenRoomStamp]
		rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
			return a.source_storey_index < b.source_storey_index)
		for index in range(1, rooms.size()):
			var lower := rooms[index - 1]
			var upper := rooms[index]
			if lower.lattice_origin.x != upper.lattice_origin.x \
					or lower.lattice_origin.z != upper.lattice_origin.z:
				out[upper.stable_id] = true
	return out


static func _room_footprint(kind: StringName) -> Dictionary:
	match kind:
		&"tower":
			return {"minimum": Vector2i(-1, -1), "size": Vector2i(2, 2)}
		&"slim":
			return {"minimum": Vector2i(-1, -2), "size": Vector2i(2, 4)}
		&"row":
			return {"minimum": Vector2i(-2, -1), "size": Vector2i(4, 2)}
		&"long":
			return {"minimum": Vector2i(-2, -3), "size": Vector2i(4, 6)}
		&"building":
			return {"minimum": Vector2i(-2, -2), "size": Vector2i(4, 4)}
		_:
			return {}


static func _yaw_from_right(direction: Vector3i) -> int:
	for yaw in 4:
		if FabricRecipe.transform_direction(Vector3i.RIGHT, yaw) == direction:
			return yaw
	return -1


static func _endpoint_key(cell: Vector3i, facing: Vector3i) -> String:
	return "%d:%d:%d/%d:%d:%d" % [cell.x, cell.y, cell.z, facing.x,
		facing.y, facing.z]


static func _pair_key(left: StringName, right: StringName) -> String:
	return "%s|%s" % [String(left), String(right)] \
		if String(left) < String(right) else "%s|%s" % [String(right),
			String(left)]


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
