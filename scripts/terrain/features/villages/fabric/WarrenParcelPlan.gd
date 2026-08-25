class_name WarrenParcelPlan
extends RefCounted

## Sealed parcel interpretation of one WarrenVolumePlan.  Unselected source mass
## is not emitted implicitly: later coherent pruning classifies it as exterior,
## daylight void, support, or discarded envelope before construction compilation.
var stable_id: StringName
var source: WarrenVolumePlan
var parcels: Array[WarrenBuildingParcel] = []
var connection_reservations: Array[Dictionary] = []
var retained_mass_cells: Dictionary = {}
var urban_core_columns: Dictionary = {}
var daylight_void_columns: Dictionary = {}
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


func _init(p_stable_id: StringName, p_source: WarrenVolumePlan) -> void:
	stable_id = p_stable_id
	source = p_source


func seal(p_parcels: Array[WarrenBuildingParcel],
		p_connection_reservations: Array[Dictionary] = []) -> bool:
	if _sealed or stable_id.is_empty() or source == null \
			or not source.is_sealed() or p_parcels.is_empty():
		return _reject("missing source or parcels")
	var ids: Dictionary = {}
	var parcel_by_id: Dictionary = {}
	var occupied_owners: Dictionary = {}
	for parcel: WarrenBuildingParcel in p_parcels:
		if parcel == null or not parcel.is_sealed() \
				or ids.has(parcel.stable_id) \
				or not WarrenParcelConstruction.door_serves_address(parcel):
			return _reject("null, unsealed, or duplicate parcel")
		ids[parcel.stable_id] = true
		parcel_by_id[parcel.stable_id] = parcel
	for parcel: WarrenBuildingParcel in p_parcels:
		if not parcel.support_parent_parcel_id.is_empty() \
				and not _building_support_is_valid(parcel, parcel_by_id):
			return _reject("parcel %s has invalid building support %s:%d" % [
				parcel.stable_id, parcel.support_parent_parcel_id,
				parcel.support_parent_storey_index])
		for cell: Vector3i in parcel.occupied_cells():
			if occupied_owners.has(cell):
				var prior := parcel_by_id[StringName(
					occupied_owners[cell])] as WarrenBuildingParcel
				if not _overlap_is_support_roof_seam(parcel, prior, cell):
					return _reject("parcels overlap at %s" % cell)
				retained_mass_cells[cell] = true
				continue
			occupied_owners[cell] = parcel.stable_id
			retained_mass_cells[cell] = true
		parcels.append(parcel)
	for reservation: Dictionary in p_connection_reservations:
		if StringName(reservation.get("recipe_id", "")).is_empty() \
				or (reservation.get("components", []) as Array).is_empty() \
				or (reservation.get("reserved_cells", {}) as Dictionary).is_empty():
			return _reject("invalid occupied-link reservation")
		connection_reservations.append(reservation.duplicate(true))
	audit = _build_audit(occupied_owners)
	if int(audit.detached_parcel_count) != 0 \
			or int(audit.overlapping_parcel_cell_count) != 0 \
			or int(audit.transverse_parcel_count) != 0:
		return _reject("parcel topology or orientation audit failed")
	if int(audit.unsupported_perimeter_parcel_count) != 0:
		return _reject(("%d of %d buildable-frontier parcels lack a sealed " \
			+ "load path: %s") \
			% [int(audit.unsupported_perimeter_parcel_count),
				int(audit.perimeter_parcel_count),
				audit.unsupported_perimeter_details])
	_sealed = true
	return true


func _building_support_is_valid(child: WarrenBuildingParcel,
		parcel_by_id: Dictionary) -> bool:
	return building_support_is_valid(child,
		parcel_by_id.get(child.support_parent_parcel_id) \
			as WarrenBuildingParcel)


## The complete building-on-building bearing seam, as one rule any producer of
## a seam can ask BEFORE it declares one. Lifted out of the sealed-plan check
## (2026-08-23) rather than restated: a translator that decides a stack and a
## plan that refuses one must never read two different rules.
static func building_support_is_valid(child: WarrenBuildingParcel,
		parent: WarrenBuildingParcel) -> bool:
	if parent == null:
		return false
	# Legacy seam (unchanged): the child's floor IS the parent's own roof base,
	# because a pitched parent reserves its roof volume and the upper building
	# starts where that reservation starts.
	#
	# Additive (2026-08-23, controller ruling on stacked houses): a FLAT-roofed
	# parent has no pitched reservation at all -- its top band is one band of
	# slab -- so a building standing on it stands on the TOP FACE of that slab,
	# which is `parent.top_band`. `flat_roof` is false on every parcel the
	# route-first and mass-first partitioners build, so this branch is
	# unreachable outside the plot model and the legacy rule is byte-identical.
	if child.base_band != parent.roof_base_band() \
			and not (parent.flat_roof \
				and child.base_band == parent.top_band):
		return false
	var overlap := 0
	for column: Vector2i in child.footprint:
		overlap += int(parent.footprint.has(column))
	if overlap < maxi(1, ceili(float(child.footprint.size()) * 0.25)):
		return false
	var parent_proposal := WarrenParcelConstruction.proposal(parent)
	return not parent_proposal.is_empty() \
		and child.support_parent_storey_index \
			== int(parent_proposal.storeys) - 1


func _overlap_is_support_roof_seam(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel, cell: Vector3i) -> bool:
	var child := left
	var parent := right
	if child.support_parent_parcel_id != parent.stable_id:
		child = right
		parent = left
	if child.support_parent_parcel_id != parent.stable_id:
		return false
	return child.base_band == parent.roof_base_band() \
		and cell.y >= parent.roof_base_band() and cell.y < parent.top_band


func is_sealed() -> bool:
	return _sealed


func deterministic_signature() -> String:
	var parts := PackedStringArray()
	for parcel: WarrenBuildingParcel in parcels:
		parts.append(parcel.deterministic_signature())
	parts.sort()
	var reservation_parts := PackedStringArray()
	for reservation: Dictionary in connection_reservations:
		var component_parts := PackedStringArray()
		for component: Dictionary in reservation.components as Array:
			component_parts.append("%s@%s/r%d" % [component.recipe_id,
				component.origin, int(component.yaw_quarters)])
		component_parts.sort()
		reservation_parts.append("%s[%s]" % [reservation.kind,
			",".join(component_parts)])
	reservation_parts.sort()
	return "%s|links=%s" % ["|".join(parts),
		",".join(reservation_parts)]


func _build_audit(occupied_owners: Dictionary) -> Dictionary:
	var base_bands: Dictionary = {}
	var base_band_counts: Dictionary = {}
	var roof_bands: Dictionary = {}
	var roof_band_counts: Dictionary = {}
	var addressed_walks: Dictionary = {}
	var overpass_count := 0
	var elevated_count := 0
	var mixed_span_count := 0
	var transverse_count := 0
	var detached_count := 0
	var visually_short_count := 0
	var grounded_count := 0
	var perimeter_count := 0
	var grounded_perimeter_count := 0
	var gateway_supported_perimeter_count := 0
	var gateway_support_records: Array[Dictionary] = []
	var unsupported_perimeter_details: Array[Dictionary] = []
	var footprint_families: Dictionary = {}
	var footprint_family_counts: Dictionary = {}
	var footprint_cell_count := 0
	var parcel_columns: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		base_bands[parcel.base_band] = true
		base_band_counts[parcel.base_band] = int(base_band_counts.get(
			parcel.base_band, 0)) + 1
		roof_bands[parcel.top_band] = true
		roof_band_counts[parcel.top_band] = int(roof_band_counts.get(
			parcel.top_band, 0)) + 1
		addressed_walks[parcel.address_walk_cell] = true
		overpass_count += int(parcel.has_occupied_overpass)
		mixed_span_count += int(parcel.support_mode == &"mixed_span")
		if parcel.base_band > source.envelope.ground_at(parcel.threshold_column):
			elevated_count += 1
		if parcel.depth_cells < parcel.width_cells \
				and not (parcel.width_cells == 2 \
					and parcel.depth_cells == 1):
			transverse_count += 1
		# has_frontage(), not has_walk(): a mass-first parcel may legitimately
		# address a STAIR/RAMP's intermediate stride cell, which is real
		# excavated street ground but never a walk_cells graph node (see
		# WarrenVolumePlan.frontage_cells). Route-first never populates that
		# set, so this is has_walk() exactly for every route-first plan.
		if not source.has_frontage(parcel.address_walk_cell):
			detached_count += 1
		# APPARENT FACE, the same restatement the retired packing search's own
		# uses and the same verdict the storey form gave -- see
		# WarrenParcelConstruction.MIN_APPARENT_FACE_BANDS. The two must agree:
		# one is what the packer refuses, the other is what the audit reports.
		visually_short_count += int(WarrenParcelConstruction.proposal(
			parcel).is_empty()
			or WarrenParcelConstruction.apparent_face_bands(parcel)
				< WarrenParcelConstruction.MIN_APPARENT_FACE_BANDS)
		grounded_count += int(parcel.base_band == source.envelope.ground_at(
			parcel.threshold_column))
		if WarrenParcelConstruction.touches_envelope_boundary(parcel):
			perimeter_count += 1
			var perimeter_grounded := WarrenParcelConstruction \
				.has_perimeter_grounding(parcel)
			grounded_perimeter_count += int(perimeter_grounded)
			var gateway_support := WarrenParcelConstruction \
				.perimeter_gateway_support(parcel)
			gateway_supported_perimeter_count += int(
				not gateway_support.is_empty())
			if not gateway_support.is_empty():
				gateway_support_records.append(gateway_support)
			elif not perimeter_grounded:
				unsupported_perimeter_details.append({
					"parcel_id": parcel.stable_id,
					"footprint": parcel.footprint,
					"base_band": parcel.base_band,
					"top_band": parcel.top_band,
					"support_mode": parcel.support_mode,
					"bearing_column_count": parcel.bearing_columns.size(),
					"has_occupied_overpass": parcel.has_occupied_overpass,
				})
		var footprint_family := "%dx%d" % [parcel.width_cells,
			parcel.depth_cells]
		footprint_families[footprint_family] = true
		footprint_family_counts[footprint_family] = int(
			footprint_family_counts.get(footprint_family, 0)) + 1
		footprint_cell_count += parcel.area_cells()
		for column: Vector2i in parcel.footprint:
			var key := _column_key(column)
			if not parcel_columns.has(key):
				parcel_columns[key] = []
			(parcel_columns[key] as Array).append(parcel)
	var stacked_columns := 0
	for column_parcels_value: Variant in parcel_columns.values():
		var column_parcels := column_parcels_value as Array
		if column_parcels.size() >= 2:
			stacked_columns += 1
	var half_level_pairs := 0
	var stepped_roof_pairs := 0
	var neighboring_pairs := 0
	var same_base_neighbor_pairs := 0
	var repeated_row_neighbor_pairs := 0
	var downhill_neighbors: Dictionary = {}
	var low_terminal_ids: Dictionary = {}
	var proposal_storeys: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		var storeys := int(WarrenParcelConstruction.proposal(parcel).get(
			"storeys", 0))
		proposal_storeys[parcel.stable_id] = storeys
		downhill_neighbors[parcel.stable_id] = [] as Array[StringName]
		# A descent terminates at an ordinary two-storey, terrain-addressed house.
		# One-storey escape buildings are forbidden in production; requiring one as
		# the terminal made every three-storey stack report as unstepped even when it
		# already descended into a proper ground-level townhouse.
		if storeys <= 2 and parcel.base_band == source.envelope.ground_at(
				parcel.threshold_column):
			low_terminal_ids[parcel.stable_id] = true
	for first_index in parcels.size():
		for second_index in range(first_index + 1, parcels.size()):
			var first := parcels[first_index]
			var second := parcels[second_index]
			var footprints_neighbor := _footprints_neighbor(first, second)
			if footprints_neighbor:
				neighboring_pairs += 1
				same_base_neighbor_pairs += int(first.base_band \
					== second.base_band)
				repeated_row_neighbor_pairs += int(first.base_band \
					== second.base_band and first.top_band == second.top_band \
					and first.width_cells == second.width_cells \
					and first.depth_cells == second.depth_cells \
					and first.frontage_direction == second.frontage_direction)
			if absi(first.base_band - second.base_band) == 1 \
					and footprints_neighbor:
				half_level_pairs += 1
			var roof_delta := first.top_band - second.top_band
			if absi(roof_delta) >= 1 and absi(roof_delta) <= 2 \
					and footprints_neighbor:
				stepped_roof_pairs += 1
				var higher := first if roof_delta > 0 else second
				var lower := second if roof_delta > 0 else first
				(downhill_neighbors[higher.stable_id] \
					as Array[StringName]).append(lower.stable_id)
	var tall_parcel_count := 0
	var stepped_descent_count := 0
	for parcel: WarrenBuildingParcel in parcels:
		# Three repeated storeys already read as a tall uniform shaft at gameplay
		# scale. Treat them as tall for the Gaussian descent audit; waiting for four
		# let exactly the visibly repetitive stacks escape the composition rule.
		if int(proposal_storeys.get(parcel.stable_id, 0)) < 3:
			continue
		tall_parcel_count += 1
		stepped_descent_count += int(_reaches_low_roof_terminal(
			parcel.stable_id, downhill_neighbors, low_terminal_ids))
	var contact_components := _contact_components()
	var largest_contact_component_count := _largest_component_size(
		contact_components)
	var area_by_id: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		area_by_id[parcel.stable_id] = parcel.area_cells()
	var isolated_building_count := 0
	for component: Array in contact_components:
		isolated_building_count += int(component.size() == 1)
	var bounded_walk_count := 0
	var two_sided_walk_count := 0
	var primary_bounded_walk_count := 0
	var primary_two_sided_walk_count := 0
	var ground_primary_walk_count := 0
	var ground_primary_bounded_walk_count := 0
	var ground_primary_two_sided_walk_count := 0
	var arcade_walk_count := 0
	var arcade_bounded_walk_count := 0
	var primary_walks: Dictionary = {}
	for primary_cell: Vector3i in source.primary_itinerary:
		primary_walks[primary_cell] = true
	var ground_arcade_cells: Dictionary = {}
	for arcade_cell: Vector3i in source.ground_arcade_cells:
		ground_arcade_cells[arcade_cell] = true
	var elevated_gallery_cells: Dictionary = {}
	for gallery_cell: Vector3i in source.elevated_gallery_cells:
		elevated_gallery_cells[gallery_cell] = true
	var gallery_walk_count := 0
	var gallery_bounded_walk_count := 0
	var gallery_terminal_count := 0
	var addressed_gallery_terminal_count := 0
	for walk: Vector3i in source.walk_cells:
		var bounded_side_count := 0
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			if occupied_owners.has(Vector3i(walk.x + direction.x, walk.y,
					walk.z + direction.y)):
				bounded_side_count += 1
		bounded_walk_count += int(bounded_side_count >= 1)
		two_sided_walk_count += int(bounded_side_count >= 2)
		if primary_walks.has(walk):
			primary_bounded_walk_count += int(bounded_side_count >= 1)
			primary_two_sided_walk_count += int(bounded_side_count >= 2)
			if walk.y == source.envelope.ground_at(Vector2i(walk.x, walk.z)):
				ground_primary_walk_count += 1
				ground_primary_bounded_walk_count += int(bounded_side_count >= 1)
				ground_primary_two_sided_walk_count += int(bounded_side_count >= 2)
		elif ground_arcade_cells.has(walk):
			arcade_walk_count += 1
			arcade_bounded_walk_count += int(bounded_side_count >= 1)
		elif elevated_gallery_cells.has(walk):
			gallery_walk_count += 1
			gallery_bounded_walk_count += int(bounded_side_count >= 1)
			if _walk_transition_degree(walk) == 1:
				gallery_terminal_count += 1
				addressed_gallery_terminal_count += int(
					addressed_walks.has(walk))
	var central_columns := 0
	var deep_open_columns := 0
	for column_value: Variant in source.envelope.height_bands.keys():
		var column := column_value as Vector2i
		if source.envelope.height_at(column) \
				< ceili(float(source.envelope.max_height_bands) * 0.65):
			continue
		central_columns += 1
		var blocked := false
		for y in range(source.envelope.ground_at(column),
				source.envelope.top_at(column)):
			var cell := Vector3i(column.x, y, column.y)
			if retained_mass_cells.has(cell) or source.has_walk(cell):
				blocked = true
				break
		if not blocked:
			deep_open_columns += 1
	var urban_seed_columns: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		for column: Vector2i in parcel.footprint:
			urban_seed_columns[column] = true
	# The short side arcade is already a sealed public branch, but it must not
	# enlarge the upper maze's central hull and thereby manufacture a vertical
	# shaft outside the original city core. Its exact surfaces and buildings are
	# still compiled; only the shaft-domain seed remains the primary journey.
	for walk: Vector3i in source.primary_itinerary:
		urban_seed_columns[Vector2i(walk.x, walk.z)] = true
	var reserved_link_columns := _reserved_link_columns()
	for column_value: Variant in reserved_link_columns.keys():
		urban_seed_columns[column_value as Vector2i] = true
	# Vertical transition spans are real public paths too. Omitting their
	# intermediate columns made the compactness audit mistake reserved stair and
	# ramp corridors for top-to-ground holes, and enlarged the hull around space
	# which construction is explicitly forbidden to fill.
	var route_columns := _public_route_columns()
	for column_value: Variant in route_columns.keys():
		urban_seed_columns[column_value as Vector2i] = true
	urban_core_columns = _orthogonal_interior_hull(urban_seed_columns)
	# Every transition's swept air, primary or not. `route_columns` deliberately
	# covers only the primary itinerary, because the urban hull is seeded from
	# the town's spine -- but a column may not be declared an open daylight void
	# merely because the public ground standing in it belongs to an AUXILIARY
	# transition. WarrenPrunedMassPlan._column_has_building_or_walk applies
	# exactly this test over all transitions and rejects the whole plan when the
	# two disagree, so this is one rule stated twice, not a new one.
	#
	# Latent until secondary lanes existed: an arcade or gallery transition is
	# LEVEL over a run of one, so its swept air only ever covers its two
	# endpoints, and both are walk cells the loop below already blocks on. A
	# lane's STAIR or RAMP is the first non-primary transition to sweep an
	# INTERMEDIATE column, which is real public ground and no walk node. Every
	# route-first plan is unchanged for the same reason it was latent.
	var auxiliary_air_columns := _transition_air_columns()
	var urban_core_open_columns := 0
	for column_value: Variant in urban_core_columns.keys():
		var column := column_value as Vector2i
		var blocked := route_columns.has(column) \
			or auxiliary_air_columns.has(column) \
			or reserved_link_columns.has(column)
		for y in range(source.envelope.ground_at(column),
			source.envelope.top_at(column)):
			var cell := Vector3i(column.x, y, column.y)
			if retained_mass_cells.has(cell) or source.has_walk(cell):
				blocked = true
				break
		if not blocked:
			urban_core_open_columns += 1
			daylight_void_columns[column] = true
	var largest_base_band_count := 0
	for count_value: Variant in base_band_counts.values():
		largest_base_band_count = maxi(largest_base_band_count,
			int(count_value))
	var largest_roof_band_count := 0
	for count_value: Variant in roof_band_counts.values():
		largest_roof_band_count = maxi(largest_roof_band_count,
			int(count_value))
	return {
		"parcel_count": parcels.size(),
		"detached_parcel_count": detached_count,
		"overlapping_parcel_cell_count": 0,
		"transverse_parcel_count": transverse_count,
		"visually_short_parcel_count": visually_short_count,
		"grounded_parcel_count": grounded_count,
		"grounded_parcel_ratio": float(grounded_count) / float(parcels.size()),
		"perimeter_parcel_count": perimeter_count,
		"grounded_perimeter_parcel_count": grounded_perimeter_count,
		"gateway_supported_perimeter_parcel_count":
			gateway_supported_perimeter_count,
		"ungrounded_perimeter_parcel_count": perimeter_count \
			- grounded_perimeter_count,
		"unsupported_perimeter_parcel_count": perimeter_count \
			- grounded_perimeter_count - gateway_supported_perimeter_count,
		"unsupported_perimeter_details": unsupported_perimeter_details,
		"perimeter_gateway_support_records": gateway_support_records,
		"grounded_perimeter_parcel_ratio": 1.0 if perimeter_count == 0 \
			else float(grounded_perimeter_count) / float(perimeter_count),
		"perimeter_load_path_ratio": 1.0 if perimeter_count == 0 else \
			float(grounded_perimeter_count + gateway_supported_perimeter_count) \
				/ float(perimeter_count),
		"base_band_count": base_bands.size(),
		"largest_base_band_count": largest_base_band_count,
		"largest_base_band_ratio": float(largest_base_band_count) \
			/ float(parcels.size()),
		"roof_band_count": roof_bands.size(),
		"largest_roof_band_count": largest_roof_band_count,
		"largest_roof_band_ratio": float(largest_roof_band_count) \
			/ float(parcels.size()),
		"neighboring_parcel_pair_count": neighboring_pairs,
		# A dense town is not merely a set of independently addressed houses.
		# Face-touching footprints form the inhabited mass which makes the public
		# route read as negative space.  Keep that graph explicit so a later court
		# pass cannot disguise scattered perimeter buildings with one broad deck.
		"building_contact_component_count": contact_components.size(),
		"largest_building_contact_component_count":
			largest_contact_component_count,
		"largest_building_contact_component_ratio":
			float(largest_contact_component_count) / float(parcels.size()),
		# The gate reads the CELL-weighted share, not the one above. Dividing by
		# parcel count makes the measurement depend on how finely the same mass
		# happens to be subdivided: splitting one wide house into two adjacent
		# narrow ones changes nothing physical, yet moves a parcel-count ratio.
		# Weighting by footprint cells is invariant under exactly that split,
		# while a town of scattered pavilions still scores low. Kept beside the
		# old ratio because the diagnostics quote both.
		"largest_building_contact_component_cell_count":
			_largest_component_cell_count(contact_components, area_by_id),
		"largest_building_contact_component_cell_ratio":
			largest_contact_cell_ratio(contact_components, area_by_id),
		# Isolates are gated on the same footing and for the same reason: an
		# absolute cap on detached BUILDINGS tightens automatically as a stage
		# subdivides the same mass more finely, so it is measured as the share
		# of built footprint those detached buildings occupy.
		"isolated_building_cell_ratio":
			isolated_cell_ratio(contact_components, area_by_id),
		"isolated_building_count": isolated_building_count,
		"contacted_building_ratio": float(parcels.size() \
			- isolated_building_count) / float(parcels.size()),
		"same_base_neighbor_pair_count": same_base_neighbor_pairs,
		"same_base_neighbor_ratio": 0.0 if neighboring_pairs == 0 else \
			float(same_base_neighbor_pairs) / float(neighboring_pairs),
		"repeated_row_neighbor_pair_count": repeated_row_neighbor_pairs,
		"half_level_neighbor_pair_count": half_level_pairs,
		"stepped_roof_neighbor_pair_count": stepped_roof_pairs,
		"low_roof_terminal_count": low_terminal_ids.size(),
		"tall_parcel_count": tall_parcel_count,
		"stepped_descent_tall_parcel_count": stepped_descent_count,
		"unstepped_tall_parcel_count": tall_parcel_count \
			- stepped_descent_count,
		"elevated_parcel_count": elevated_count,
		"mixed_span_parcel_count": mixed_span_count,
		"occupied_overpass_parcel_count": overpass_count,
		"addressed_walk_count": addressed_walks.size(),
		"bounded_walk_count": bounded_walk_count,
		"all_bounded_walk_ratio": float(bounded_walk_count) \
			/ float(source.walk_cells.size()),
		"bounded_walk_ratio": float(primary_bounded_walk_count) \
			/ float(source.primary_itinerary.size()),
		"two_sided_walk_count": two_sided_walk_count,
		"all_two_sided_walk_ratio": float(two_sided_walk_count) \
			/ float(source.walk_cells.size()),
		"two_sided_walk_ratio": float(primary_two_sided_walk_count) \
			/ float(source.primary_itinerary.size()),
		"ground_primary_walk_count": ground_primary_walk_count,
		"ground_primary_bounded_walk_count": ground_primary_bounded_walk_count,
		"ground_primary_bounded_walk_ratio": 1.0 \
			if ground_primary_walk_count == 0 else \
			float(ground_primary_bounded_walk_count) \
				/ float(ground_primary_walk_count),
		"ground_primary_two_sided_walk_count":
			ground_primary_two_sided_walk_count,
		"ground_primary_two_sided_walk_ratio": 1.0 \
			if ground_primary_walk_count == 0 else \
			float(ground_primary_two_sided_walk_count) \
				/ float(ground_primary_walk_count),
		"ground_arcade_walk_count": arcade_walk_count,
		"ground_arcade_bounded_walk_count": arcade_bounded_walk_count,
		"ground_arcade_bounded_walk_ratio": 1.0 if arcade_walk_count == 0 \
			else float(arcade_bounded_walk_count) / float(arcade_walk_count),
		"elevated_gallery_walk_count": gallery_walk_count,
		"elevated_gallery_bounded_walk_count": gallery_bounded_walk_count,
		"elevated_gallery_bounded_walk_ratio": 1.0 \
			if gallery_walk_count == 0 else float(gallery_bounded_walk_count) \
				/ float(gallery_walk_count),
		"elevated_gallery_terminal_count": gallery_terminal_count,
		"addressed_elevated_gallery_terminal_count":
			addressed_gallery_terminal_count,
		"unaddressed_elevated_gallery_terminal_count":
			gallery_terminal_count - addressed_gallery_terminal_count,
		"footprint_family_count": footprint_families.size(),
		# Density is occupied urban wall, not a raw prefab count. A 2x3 building
		# contributes six useful cells around the public void while a 1x1 tower
		# contributes one; this prevents the visual selector from manufacturing a
		# row of repeated towers merely to satisfy a building-count target.
		"parcel_footprint_cell_count": footprint_cell_count,
		"tower_parcel_count": int(footprint_family_counts.get("1x1", 0)),
		"slim_parcel_count": int(footprint_family_counts.get("1x2", 0)),
		"square_parcel_count": int(footprint_family_counts.get("2x2", 0)),
		"long_parcel_count": int(footprint_family_counts.get("2x3", 0)),
		"largest_footprint_family_count": _largest_count(
			footprint_family_counts),
		"largest_footprint_family_ratio": float(_largest_count(
			footprint_family_counts)) / float(parcels.size()),
		"stacked_parcel_column_count": stacked_columns,
		"retained_mass_cell_count": retained_mass_cells.size(),
		"central_column_count": central_columns,
		"deep_open_column_count": deep_open_columns,
		"deep_open_column_ratio": 0.0 if central_columns == 0 else \
			float(deep_open_columns) / float(central_columns),
		"urban_core_column_count": urban_core_columns.size(),
		"urban_core_open_column_count": urban_core_open_columns,
		"urban_core_open_column_ratio": 0.0 if urban_core_columns.is_empty() else \
			float(urban_core_open_columns) / float(urban_core_columns.size()),
		"planned_skywalk_count": connection_reservations.size(),
	}


static func _largest_count(counts: Dictionary) -> int:
	var result := 0
	for value: Variant in counts.values():
		result = maxi(result, int(value))
	return result


func _contact_components() -> Array[Array]:
	## The structural building graph has exactly two edge types: a shared facade
	## boundary or a sealed occupied-link reservation between its two owners. The
	## latter is inhabited mass crossing the street, so ignoring it made a genuine
	## bridge-house cluster look as scattered as unrelated perimeter buildings.
	## Empty decks, route adjacency, and visual proximity never add graph edges.
	var neighbors: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels:
		neighbors[parcel.stable_id] = [] as Array[StringName]
	for left_index in parcels.size():
		var left := parcels[left_index]
		for right_index in range(left_index + 1, parcels.size()):
			var right := parcels[right_index]
			if not _footprints_neighbor(left, right):
				continue
			(neighbors[left.stable_id] as Array[StringName]).append(
				right.stable_id)
			(neighbors[right.stable_id] as Array[StringName]).append(
				left.stable_id)
	for reservation: Dictionary in connection_reservations:
		var owner_ids := PackedStringArray()
		for owner_value: Variant in reservation.get("owner_parcel_ids", []):
			owner_ids.append(String(owner_value))
		if owner_ids.size() != 2:
			continue
		var left_id := StringName(owner_ids[0])
		var right_id := StringName(owner_ids[1])
		if left_id == right_id or not neighbors.has(left_id) \
				or not neighbors.has(right_id):
			continue
		if not (neighbors[left_id] as Array[StringName]).has(right_id):
			(neighbors[left_id] as Array[StringName]).append(right_id)
		if not (neighbors[right_id] as Array[StringName]).has(left_id):
			(neighbors[right_id] as Array[StringName]).append(left_id)
	var components: Array[Array] = []
	var visited: Dictionary = {}
	var ids: Array[StringName] = []
	ids.assign(neighbors.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for start: StringName in ids:
		if visited.has(start):
			continue
		var component: Array[StringName] = []
		var frontier: Array[StringName] = [start]
		while not frontier.is_empty():
			var current: StringName = frontier.pop_back()
			if visited.has(current):
				continue
			visited[current] = true
			component.append(current)
			for neighbor: StringName in neighbors[current]:
				if not visited.has(neighbor):
					frontier.append(neighbor)
		components.append(component)
	return components


static func _largest_component_size(components: Array[Array]) -> int:
	var result := 0
	for component: Array in components:
		result = maxi(result, component.size())
	return result


static func _largest_component_cell_count(components: Array[Array],
		area_by_id: Dictionary) -> int:
	var result := 0
	for component: Array in components:
		var cells := 0
		for id_value: Variant in component:
			cells += int(area_by_id.get(StringName(id_value), 0))
		result = maxi(result, cells)
	return result


static func largest_contact_cell_ratio(components: Array[Array],
		area_by_id: Dictionary) -> float:
	## Share of the town's built footprint standing in its largest
	## face-connected run of buildings.
	##
	## Deliberately weighted by footprint cells rather than by parcel count, and
	## public so that invariance can be pinned directly: subdividing a parcel
	## into adjacent parcels covering the same columns leaves both the numerator
	## and the denominator untouched, so the ratio cannot drift merely because a
	## partitioner divides the same urban mass more finely. A town of scattered
	## pavilions still scores low, which is the property the gate exists to
	## enforce.
	var total := _total_cells(area_by_id)
	if total <= 0:
		return 0.0
	return float(_largest_component_cell_count(components, area_by_id)) \
		/ float(total)


static func isolated_cell_ratio(components: Array[Array],
		area_by_id: Dictionary) -> float:
	## Share of the town's built footprint standing in buildings that touch
	## nothing at all.
	##
	## Weighted by cells for the same reason as largest_contact_cell_ratio(),
	## and public for the same reason: an absolute cap on detached BUILDINGS
	## grows stricter on its own as a stage divides the same mass more finely,
	## so subdividing one wide isolated house into two adjacent halves would
	## turn one violation into two while leaving the town identical. Splitting a
	## detached house leaves this ratio alone -- the halves touch each other, so
	## they stop being isolated, which is the honest answer -- while a town of
	## scattered pavilions still scores high.
	var total := _total_cells(area_by_id)
	if total <= 0:
		return 0.0
	var isolated := 0
	for component: Array in components:
		if component.size() != 1:
			continue
		isolated += int(area_by_id.get(StringName(component[0]), 0))
	return float(isolated) / float(total)


static func _total_cells(area_by_id: Dictionary) -> int:
	var total := 0
	for area_value: Variant in area_by_id.values():
		total += int(area_value)
	return total


func _walk_transition_degree(walk: Vector3i) -> int:
	var result := 0
	for transition: WarrenVolumeTransition in source.transitions:
		result += int(transition.from_cell == walk or transition.to_cell == walk)
	return result


static func _reaches_low_roof_terminal(start: StringName,
		downhill_neighbors: Dictionary, low_terminal_ids: Dictionary) -> bool:
	var frontier: Array[StringName] = [start]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		var current: StringName = frontier.pop_back()
		if visited.has(current):
			continue
		visited[current] = true
		if current != start and low_terminal_ids.has(current):
			return true
		for next: StringName in downhill_neighbors.get(current,
				[] as Array[StringName]):
			frontier.append(next)
	return false


func _reserved_link_columns() -> Dictionary:
	var out: Dictionary = {}
	for reservation: Dictionary in connection_reservations:
		for cell_value: Variant in (reservation.reserved_cells as Dictionary).keys():
			var cell := cell_value as Vector3i
			out[Vector2i(floori(float(cell.x) / 2.0),
				floori(float(cell.z) / 2.0))] = true
	return out


func _public_route_columns() -> Dictionary:
	var out: Dictionary = {}
	for walk: Vector3i in source.primary_itinerary:
		out[Vector2i(walk.x, walk.z)] = true
	for transition: WarrenVolumeTransition in source.transitions:
		if not _is_primary_transition(transition):
			continue
		for air_cell: Vector3i in transition.swept_air_cells:
			out[Vector2i(air_cell.x, air_cell.z)] = true
	return out


func _transition_air_columns() -> Dictionary:
	## Columns any transition sweeps public air through, primary or auxiliary.
	## Mirrors WarrenPrunedMassPlan._column_has_building_or_walk's first loop.
	var out: Dictionary = {}
	for transition: WarrenVolumeTransition in source.transitions:
		for air_cell: Vector3i in transition.swept_air_cells:
			out[Vector2i(air_cell.x, air_cell.z)] = true
	return out


func _is_primary_transition(transition: WarrenVolumeTransition) -> bool:
	for index in range(source.primary_itinerary.size() - 1):
		var first := source.primary_itinerary[index]
		var second := source.primary_itinerary[index + 1]
		if (transition.from_cell == first and transition.to_cell == second) \
				or (transition.from_cell == second \
					and transition.to_cell == first):
			return true
	return false


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false


static func _footprints_neighbor(a: WarrenBuildingParcel,
		b: WarrenBuildingParcel) -> bool:
	var b_columns: Dictionary = {}
	for column: Vector2i in b.footprint:
		b_columns[column] = true
	for column: Vector2i in a.footprint:
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			if b_columns.has(column + direction):
				return true
	return false


static func _column_key(column: Vector2i) -> String:
	return "%d:%d" % [column.x, column.y]


static func _orthogonal_interior_hull(seed_columns: Dictionary) -> Dictionary:
	var x_bounds_by_z: Dictionary = {}
	var z_bounds_by_x: Dictionary = {}
	for column_value: Variant in seed_columns.keys():
		var column := column_value as Vector2i
		if not x_bounds_by_z.has(column.y):
			x_bounds_by_z[column.y] = Vector2i(column.x, column.x)
		else:
			var x_bounds := x_bounds_by_z[column.y] as Vector2i
			x_bounds_by_z[column.y] = Vector2i(mini(x_bounds.x, column.x),
				maxi(x_bounds.y, column.x))
		if not z_bounds_by_x.has(column.x):
			z_bounds_by_x[column.x] = Vector2i(column.y, column.y)
		else:
			var z_bounds := z_bounds_by_x[column.x] as Vector2i
			z_bounds_by_x[column.x] = Vector2i(mini(z_bounds.x, column.y),
				maxi(z_bounds.y, column.y))
	var row_hull: Dictionary = {}
	for z_value: Variant in x_bounds_by_z.keys():
		var z := int(z_value)
		var bounds := x_bounds_by_z[z] as Vector2i
		for x in range(bounds.x, bounds.y + 1):
			row_hull[Vector2i(x, z)] = true
	var out: Dictionary = seed_columns.duplicate()
	for x_value: Variant in z_bounds_by_x.keys():
		var x := int(x_value)
		var bounds := z_bounds_by_x[x] as Vector2i
		for z in range(bounds.x, bounds.y + 1):
			var column := Vector2i(x, z)
			if row_hull.has(column):
				out[column] = true
	return out
