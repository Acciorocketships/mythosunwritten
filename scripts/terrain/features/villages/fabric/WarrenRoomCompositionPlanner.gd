class_name WarrenRoomCompositionPlanner
extends RefCounted

## Re-partitions the generic parcel envelopes as a genuinely three-dimensional
## room grammar. Parcels still provide exact terrain roots, doors, and feature
## sockets, but they are not treated as immutable vertical prisms: compatible
## narrow columns may hand their upper mass to one wider room lineage, and each
## unforced two-storey band may select a different measured room plate.
##
## Every output plate is a subset of the already-qualified source mass owned by
## one or more input blocks. The planner therefore cannot invent a podium, fill
## public air, or trespass on a hero-feature reservation. A band is solved as a
## joint tiling problem rather than a series of parcel-pair guesses: one measured
## room may consume parts of several optional narrow plates, and every lineage
## that resumes above it names that shared room as its explicit support parent.
const TALL_LINEAGE_STOREYS := 4
const EXTRUDED_LINEAGE_STOREYS := 5
const MAX_UNPAIRED_TOWER_STOREYS := 2
const THREE_STOREY_TOWER_ANNEXES := 1
const TALL_TOWER_ANNEXES := 2
const MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS := 2
const MIN_BEARING_OVERLAP_COLUMNS := 2
const MAX_PAIRED_RELIEF_FRONTIER := 12
const MAX_PAIRED_RELIEF_COLUMN_DISTANCE := 1
const MAX_PAIRED_RELIEF_PAIR_CHECKS := 24
const MAX_STRUCTURAL_VARIANT_FRONTIER := 72

# A changed area is not enough to break a vertical tower silhouette.  A room
# can grow on one side while retaining the other three facade planes exactly,
# which still reads as one extruded shaft.  These costs make the 3D search pay
# for that world-space registration while leaving bearing and exact clearance
# as the hard arbiters of whether an offset is physically valid.
const REGISTERED_FACADE_PLANE_COST := 650
const STRONG_FACADE_REGISTRATION_COST := 1900
const SAME_ADJACENT_ROOM_KIND_COST := 500
const SAME_ADJACENT_RIDGE_AXIS_COST := 300

const ROOM_KINDS: Array[StringName] = [
	&"long", &"building", &"slim", &"tower",
]

static var last_failure := ""
static var last_audit: Dictionary = {}
static var last_merge_diagnostic: Dictionary = {}
static var last_variant_diagnostic: Dictionary = {}
static var last_pair_diagnostic: Dictionary = {}
static var diagnostic_trace := false


static func solve(grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], offsets_by_parcel: Dictionary,
		forced_offsets_by_parcel: Dictionary, market_reservation: Dictionary,
		protected_owners: Dictionary, skywalk_forced_offsets: Dictionary,
		skywalk_reservations: Array[Dictionary], world_seed: int,
		enable_paired_registration_relief: bool = true) -> Dictionary:
	last_failure = ""
	last_audit = {}
	last_merge_diagnostic = {}
	last_variant_diagnostic = {}
	last_pair_diagnostic = {}
	var trace_started := Time.get_ticks_msec()
	var trace_stage := trace_started
	if grid == null or volume == null or proposals.is_empty():
		last_failure = "missing grid, volume, or room proposals"
		return {}
	var court_neighbors := _courtyard_neighbor_cells(volume)
	var market_backing := market_reservation.get("backing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var skywalk_constraints := _skywalk_constraints_by_parcel(
		skywalk_reservations)
	var bearing_interface_storeys: Dictionary = {}
	for proposal: Dictionary in proposals:
		var child := proposal.get("parcel") as WarrenBuildingParcel
		if child == null or child.support_parent_parcel_id.is_empty():
			continue
		if not bearing_interface_storeys.has(child.support_parent_parcel_id):
			bearing_interface_storeys[child.support_parent_parcel_id] = {}
		(bearing_interface_storeys[child.support_parent_parcel_id] \
			as Dictionary)[child.support_parent_storey_index] = true
	var lineages: Dictionary = {}
	var input_storeys := 0
	for proposal: Dictionary in proposals:
		var parcel := proposal.get("parcel") as WarrenBuildingParcel
		if parcel == null:
			continue
		var offsets: Array[Vector2i] = []
		offsets.assign(offsets_by_parcel.get(parcel.stable_id, []) as Array)
		if offsets.is_empty():
			continue
		var forced := forced_offsets_by_parcel.get(parcel.stable_id, {}) \
			as Dictionary
		var skywalk_forced := skywalk_forced_offsets.get(parcel.stable_id, {}) \
			as Dictionary
		var blocks := _source_blocks(proposal, offsets, forced,
			skywalk_forced, skywalk_constraints.get(parcel.stable_id, []) as Array,
			court_neighbors, market_backing,
			bearing_interface_storeys.get(parcel.stable_id, {}) as Dictionary)
		if blocks.is_empty():
			continue
		var required_through := -1
		for block_index in blocks.size():
			if bool((blocks[block_index] as Dictionary).forced):
				required_through = block_index
		# The exact-offset solve may terminate an optional upper crown instead
		# of discarding a valid lower building when a hero feature occupies that
		# residual mass. Count only the complete bands that actually enter this
		# three-dimensional room grammar.
		input_storeys += mini(int(proposal.storeys), offsets.size() * 2)
		lineages[parcel.stable_id] = {
			"proposal": proposal,
			"blocks": blocks,
			"required_through_block": required_through,
			"paired_primary": false,
			"paired_secondary": false,
		}
	if lineages.is_empty():
		last_failure = "no source lineage survived exact feature reservations"
		return {}
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING source ms=",
			Time.get_ticks_msec() - trace_stage, " lineages=", lineages.size())
		trace_stage = Time.get_ticks_msec()
	var merged_count := _merge_upper_lineages(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING merge ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=", merged_count)
		trace_stage = Time.get_ticks_msec()
	var coupled_count := _couple_upper_lineages(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING couple ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=", coupled_count)
		trace_stage = Time.get_ticks_msec()
	var expanded_count := _vary_unmerged_lineages(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING vary ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=", expanded_count)
		trace_stage = Time.get_ticks_msec()
	var registration_relief_count := _relieve_registered_lineages(lineages,
		grid, protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING serial_relief ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=",
			registration_relief_count)
		trace_stage = Time.get_ticks_msec()
	var paired_registration_relief_count := 0
	if enable_paired_registration_relief:
		paired_registration_relief_count = \
			_relieve_paired_registered_lineages(lineages, grid,
				protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING paired_relief ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=",
			paired_registration_relief_count, " audit=",
			last_pair_diagnostic)
		trace_stage = Time.get_ticks_msec()
	var crown_termination := _truncate_registered_crowns(lineages, grid)
	var pre_support_lineage_count := lineages.size()
	var support_repair_count := _repair_unsupported_transitions(lineages,
		grid, protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING support_repair ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=",
			support_repair_count)
		trace_stage = Time.get_ticks_msec()
	var support_audit := _lineage_support_audit(lineages, grid)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING support_audit ms=",
			Time.get_ticks_msec() - trace_stage, " total_ms=",
			Time.get_ticks_msec() - trace_started, " unsupported=",
			support_audit.unsupported_transition_count, " details=",
			JSON.stringify(support_audit.unsupported_transition_details))
	if int(support_audit.unsupported_transition_count) > 0:
		last_failure = "3D composition retained %d unsupported room transitions: %s" \
			% [int(support_audit.unsupported_transition_count),
				JSON.stringify(support_audit.unsupported_transition_details)]
		return {}
	var overlap_audit := _lineage_overlap_audit(lineages)
	if int(overlap_audit.overlap_cell_count) > 0:
		last_failure = "composed room lineages overlap in %d cells: %s" % [
			int(overlap_audit.overlap_cell_count),
			JSON.stringify(overlap_audit.conflicts)]
		return {}
	var shoulder_repair := _truncate_unroofable_crowns(lineages)
	var shoulder_audit := _unroofable_shoulder_audit(lineages)
	if int(shoulder_audit.unroofable_shoulder_count) > 0:
		last_failure = "3D composition retained %d arbitrary exposed shoulders after %d bounded crown repairs: %s" \
			% [int(shoulder_audit.unroofable_shoulder_count), shoulder_repair,
				JSON.stringify(shoulder_audit.details)]
		return {}
	last_merge_diagnostic["variant_diagnostic"] = \
		last_variant_diagnostic.duplicate(true)
	var truncated_tower_storeys := _truncate_unpaired_towers(lineages)
	var audit := _audit(lineages, input_storeys, merged_count,
		coupled_count, expanded_count, truncated_tower_storeys)
	audit["registration_relief_recomposition_count"] = \
		registration_relief_count
	audit["paired_registration_relief_count"] = \
		paired_registration_relief_count
	audit["paired_registration_candidate_pair_count"] = int(
		last_pair_diagnostic.get("examined_pair_count", 0))
	audit["paired_registration_peak_frontier_count"] = int(
		last_pair_diagnostic.get("peak_frontier_count", 0))
	audit["terminated_registered_crown_lineage_count"] = int(
		crown_termination.lineage_count)
	audit["terminated_registered_crown_storey_count"] = int(
		crown_termination.storey_count)
	audit["structural_room_repair_count"] = support_repair_count
	audit["structural_yielded_lineage_count"] = maxi(
		pre_support_lineage_count - lineages.size(), 0)
	audit.merge(support_audit, false)
	audit.merge(shoulder_audit, false)
	audit["unroofable_shoulder_crown_repair_count"] = shoulder_repair
	last_audit = audit.duplicate(true)
	var repeated_run := int(audit.get(
		"max_identical_tower_floorplate_run_storeys", 0))
	if repeated_run > MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS:
		var unresolved_runs := _unresolved_overlong_tower_runs(audit)
		audit["unresolved_overlong_tower_run_details"] = unresolved_runs
		last_audit = audit.duplicate(true)
		if not unresolved_runs.is_empty():
			last_failure = ("3D composition retained a %d-storey identical tower " \
				+ "floorplate without an occupied-annex relief contract; " \
				+ "maximum is %d: %s") % [repeated_run,
					MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS,
					JSON.stringify(unresolved_runs)]
			return {}
	return {"lineages": lineages, "audit": audit}


static func _truncate_unroofable_crowns(lineages: Dictionary) -> int:
	## The anti-box gate participates in the composition transaction. If a bad
	## shoulder begins an entirely optional crown, terminate that crown at the
	## lower complete room; never delete a doorway, feature socket, merged room,
	## or bearing record. This is the same architectural operation as the existing
	## registered-shaft truncation, but keyed to roofability rather than repetition.
	var required_bearers: Dictionary = {}
	for lineage_value: Variant in lineages.values():
		for block: Dictionary in (lineage_value as Dictionary).blocks \
				as Array[Dictionary]:
			var parent_id := StringName(block.get("support_parent_lineage_id", &""))
			var parent_block := int(block.get(
				"support_parent_source_block_index", -1))
			if not parent_id.is_empty() and parent_block >= 0:
				required_bearers["%s/%d" % [parent_id, parent_block]] = true
	var repaired := 0
	var changed := true
	while changed:
		changed = false
		var ids: Array[StringName] = []
		ids.assign(lineages.keys())
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		for lineage_id: StringName in ids:
			var lineage := lineages[lineage_id] as Dictionary
			var blocks := lineage.blocks as Array[Dictionary]
			if blocks.size() < 2:
				continue
			for position in range(1, blocks.size()):
				var lower := blocks[position - 1] as Dictionary
				var upper := blocks[position] as Dictionary
				if int(lower.end_storey) != int(upper.start_storey):
					continue
				var exposed: Dictionary = {}
				for column_value: Variant in (lower.columns as Dictionary).keys():
					if not (upper.columns as Dictionary).has(column_value):
						exposed[column_value] = true
				var roofable := true
				for component: Dictionary in _column_components(exposed):
					if not _shoulder_component_is_roofable(component,
							upper.columns as Dictionary,
							(lower.origin as Vector3i).y):
						roofable = false
						break
				if roofable or not _optional_suffix_can_terminate(lineage_id,
						lineage, blocks, position, required_bearers):
					continue
				blocks.resize(position)
				lineage["blocks"] = blocks
				lineages[lineage_id] = lineage
				repaired += 1
				changed = true
				break
			if changed:
				break
	return repaired


static func _optional_suffix_can_terminate(lineage_id: StringName,
		lineage: Dictionary, blocks: Array[Dictionary],
		start_position: int, required_bearers: Dictionary) -> bool:
	if start_position <= 0:
		return false
	for position in range(start_position, blocks.size()):
		var block := blocks[position] as Dictionary
		var source_index := int(block.get("source_block_index", position))
		if bool(block.get("forced", false)) \
				or bool(block.get("structural_forced", false)) \
				or bool(block.get("merged", false)) \
				or source_index <= int(lineage.required_through_block) \
				or required_bearers.has("%s/%d" % [lineage_id, source_index]):
			return false
	return true


static func _unroofable_shoulder_audit(lineages: Dictionary) -> Dictionary:
	## Every lower-room remainder exposed by a changed upper floorplate must itself
	## be a complete standard roof footprint. A disconnected/L-shaped/one-cell
	## strip is the voxel artifact seen as a plank shelf in overview captures.
	var count := 0
	var details: Array[Dictionary] = []
	for lineage_id_value: Variant in lineages.keys():
		var lineage_id := StringName(lineage_id_value)
		var blocks := (lineages[lineage_id] as Dictionary).blocks \
			as Array[Dictionary]
		for position in range(1, blocks.size()):
			var lower := blocks[position - 1] as Dictionary
			var upper := blocks[position] as Dictionary
			if int(lower.end_storey) != int(upper.start_storey):
				continue
			var exposed: Dictionary = {}
			for column_value: Variant in (lower.columns as Dictionary).keys():
				if not (upper.columns as Dictionary).has(column_value):
					exposed[column_value] = true
			for component: Dictionary in _column_components(exposed):
				if _shoulder_component_is_roofable(component,
						upper.columns as Dictionary,
						(lower.origin as Vector3i).y):
					continue
				count += 1
				if details.size() < 16:
					details.append({"lineage_id": lineage_id,
						"lower_source_block": int(lower.source_block_index),
						"upper_source_block": int(upper.source_block_index),
						"cell_count": component.size(),
						"cells": component.keys()})
	return {"unroofable_shoulder_count": count,
		"unroofable_shoulder_details": details, "details": details}


static func _shoulder_component_is_roofable(component: Dictionary,
		upper_columns: Dictionary, y: int) -> bool:
	if not _exact_stamp_for_columns(component, y).is_empty():
		return true
	if _component_has_gabled_partition(component, y):
		return true
	# The only partial footprint admitted is the exact lean-to vocabulary: a
	# straight 3/6/9 m row, one fine cell deep, with one complete long edge bound
	# to the surviving upper room. Corners, branches, and isolated shelves have no
	# authored roof contract and must make the composition candidate fail.
	if component.size() not in [2, 4, 6]:
		return false
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in component.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var along_x := minimum.y == maximum.y \
		and maximum.x - minimum.x + 1 == component.size()
	var along_z := minimum.x == maximum.x \
		and maximum.y - minimum.y + 1 == component.size()
	if not along_x and not along_z:
		return false
	var normals: Array[Vector2i] = []
	if along_x:
		normals.assign([Vector2i.UP, Vector2i.DOWN])
	else:
		normals.assign([Vector2i.LEFT, Vector2i.RIGHT])
	var wall_side_count := 0
	for normal: Vector2i in normals:
		var complete_wall := true
		for column_value: Variant in component.keys():
			if not upper_columns.has((column_value as Vector2i) + normal):
				complete_wall = false
				break
		wall_side_count += int(complete_wall)
	return wall_side_count == 1


static func _component_has_gabled_partition(component: Dictionary,
		y: int) -> bool:
	## Compound L/Z shoulders are valid only when they contain at least one full
	## authored room roof and the remainder is a finite set of straight native
	## cap runs. The compiler uses the same largest-first partition. This admits a
	## real intersecting roof composition without making arbitrary voxel shelves
	## legal again.
	if component.size() < 6:
		return false
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in component.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	for kind: StringName in [&"long", &"building", &"slim", &"tower"]:
		for yaw in 4:
			for x in range(minimum.x - 3, maximum.x + 4):
				for z in range(minimum.y - 3, maximum.y + 4):
					var stamp := _stamp_columns(kind, Vector3i(x, y, z), yaw)
					if stamp.is_empty() or not _is_subset(stamp, component):
						continue
					var remainder := component.duplicate()
					for column_value: Variant in stamp.keys():
						remainder.erase(column_value)
					var valid := true
					for residual: Dictionary in _column_components(remainder):
						if not _component_is_straight_native_row(residual):
							valid = false
							break
					if valid:
						return true
	return false


static func _component_is_straight_native_row(component: Dictionary) -> bool:
	if component.is_empty():
		return true
	if component.size() not in [1, 2, 4, 6]:
		return false
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in component.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	return minimum.y == maximum.y \
		and maximum.x - minimum.x + 1 == component.size() \
		or minimum.x == maximum.x \
			and maximum.y - minimum.y + 1 == component.size()


static func _column_components(columns: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var remaining := columns.duplicate()
	while not remaining.is_empty():
		var start := remaining.keys()[0] as Vector2i
		var component: Dictionary = {start: true}
		var pending: Array[Vector2i] = [start]
		remaining.erase(start)
		while not pending.is_empty():
			var current: Vector2i = pending.pop_back()
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbor := current + direction
				if not remaining.has(neighbor):
					continue
				remaining.erase(neighbor)
				component[neighbor] = true
				pending.append(neighbor)
		out.append(component)
	return out


static func _unresolved_overlong_tower_runs(audit: Dictionary) \
		-> Array[Dictionary]:
	## An overlong identical run is unresolved only when it has no occupied-room
	## relief contract. Three-storey narrow houses intentionally require one
	## annex; taller shafts require two. Comparing both cases to the taller quota
	## rejects the valid three-storey contract before its exact annex transaction
	## gets a chance to prove the architecture.
	var annex_targets := audit.get(
		"tower_relief_annex_target_by_lineage", {}) as Dictionary
	var unresolved: Array[Dictionary] = []
	for detail_value: Variant in audit.get(
			"overlong_tower_run_details", []) as Array:
		var detail := detail_value as Dictionary
		if int(annex_targets.get(StringName(detail.lineage_id), 0)) <= 0:
			unresolved.append(detail)
	return unresolved


static func lineages_are_supported(lineages: Dictionary,
		grid: WarrenSpatialGrid) -> bool:
	## Public final-transaction check for callers that attach additional exact
	## feature sockets after an earlier preflight. It intentionally recomputes
	## bearing from the complete current partition; a cached preflight count is
	## not proof after market/court/skywalk owners have all been committed.
	if lineages.is_empty() or grid == null:
		return false
	return int(_lineage_support_audit(lineages, grid).get(
		"unsupported_transition_count", 1)) == 0


static func _source_blocks(proposal: Dictionary,
		offsets: Array[Vector2i], forced_offsets: Dictionary,
		skywalk_forced_offsets: Dictionary,
		skywalk_constraints: Array, court_neighbors: Dictionary,
		market_backing: Vector3i,
		bearing_interface_storeys: Dictionary = {}) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var source_origin := proposal.origin as Vector3i
	var storeys := int(proposal.storeys)
	var kind := StringName(proposal.kind)
	var yaw := int(proposal.yaw_quarters)
	var parcel := proposal.get("parcel") as WarrenBuildingParcel
	var threshold := WarrenParcelConstruction.threshold_cell(parcel) \
		if parcel != null else Vector3i(2147483647, 2147483647, 2147483647)
	var frontage := Vector3i(parcel.frontage_direction.x, 0,
		parcel.frontage_direction.y) if parcel != null else Vector3i.ZERO
	var addressed_storey := floori(float(threshold.y - source_origin.y) \
		/ float(WarrenSpatialGrid.STOREY_CELLS)) \
		if threshold.x != 2147483647 else -1
	var interface_storeys: Dictionary = {}
	var interface_offset_blocks: Dictionary = {}
	for constraint_value: Variant in skywalk_constraints:
		var endpoint := (constraint_value as Dictionary).cell as Vector3i
		var local_storey := floori(float(endpoint.y - source_origin.y) \
			/ float(WarrenSpatialGrid.STOREY_CELLS))
		if local_storey >= 0:
			interface_storeys[local_storey] = true
			interface_offset_blocks[floori(float(local_storey) / 2.0)] = true
	if addressed_storey >= 0:
		interface_storeys[addressed_storey] = true
		interface_offset_blocks[floori(float(addressed_storey) / 2.0)] = true
	for offset_block in offsets.size():
		var block_start_storey := offset_block * 2
		if block_start_storey >= storeys:
			break
		var block_end_storey := mini(storeys, block_start_storey + 2)
		var offset := offsets[offset_block]
		# A two-storey offset is only a provisional packing convenience. Emit one
		# composition record per actual storey so a doorway, street tunnel, market
		# socket, or skywalk on the lower floor cannot freeze the free floor above
		# into the same narrow prism.
		for storey in range(block_start_storey, block_end_storey):
			var origin := source_origin + Vector3i(offset.x,
				storey * WarrenSpatialGrid.STOREY_CELLS, offset.y)
			var home_origin := source_origin + Vector3i(0,
				storey * WarrenSpatialGrid.STOREY_CELLS, 0)
			var record := _record(kind, origin, yaw, storey, storey + 1)
			if record.is_empty():
				return [] as Array[Dictionary]
			var storey_skywalk_constraints: Array[Dictionary] = []
			for constraint_value: Variant in skywalk_constraints:
				var constraint := constraint_value as Dictionary
				var endpoint := constraint.cell as Vector3i
				if endpoint.y >= origin.y and endpoint.y < origin.y \
						+ WarrenSpatialGrid.STOREY_CELLS:
					storey_skywalk_constraints.append(constraint)
			var addressed := addressed_storey == storey
			# The exact room keeps its transformed public door/skywalk socket. Its
			# preceding storey is protected as a bearer, but the final structural
			# pass may still move that bearer underneath the fixed interface.
			var interface_forced := interface_storeys.has(storey)
			var bearing_forced := interface_storeys.has(storey + 1)
			var structural_forced := storey == 0 \
				or skywalk_forced_offsets.has(offset_block) \
					and not interface_offset_blocks.has(offset_block) \
				or bearing_interface_storeys.has(storey) \
				or parcel != null and storey == 0 \
					and not parcel.support_parent_parcel_id.is_empty()
			var forced := structural_forced or interface_forced \
				or bearing_forced or addressed \
				or not storey_skywalk_constraints.is_empty()
			# A market backing is one exact structural socket. Courtyard frontage is
			# different: only the occupied columns that actually address the court are
			# invariant. Freezing the whole source floorplate because one edge touched
			# the court forced otherwise avoidable three-storey tower extrusions.
			var court_contact_columns: Dictionary = {}
			for cell: Vector3i in record.cells:
				if cell == market_backing:
					forced = true
					structural_forced = true
				if court_neighbors.has(cell):
					court_contact_columns[Vector2i(cell.x, cell.z)] = true
			if not court_contact_columns.is_empty():
				forced = true
			record["forced"] = forced
			record["structural_forced"] = structural_forced
			record["interface_forced"] = interface_forced
			record["bearing_forced"] = bearing_forced
			record["address_expandable"] = addressed and not structural_forced
			record["feature_endpoint_constraints"] = \
				storey_skywalk_constraints
			record["court_contact_columns"] = court_contact_columns
			record["address_threshold"] = threshold
			record["address_frontage"] = frontage
			record["original_kind"] = kind
			record["original_origin"] = origin
			record["original_yaw_quarters"] = yaw
			record["home_origin"] = home_origin
			record["home_columns"] = _stamp_columns(kind, home_origin, yaw)
			# Storey index is the stable unique key now that one provisional
			# two-storey offset can produce two independently composed records.
			record["source_block_index"] = storey
			record["source_offset_block_index"] = offset_block
			if parcel != null and storey == 0 \
					and not parcel.support_parent_parcel_id.is_empty():
				record["support_parent_lineage_id"] = \
					parcel.support_parent_parcel_id
				record["support_parent_source_storey"] = \
					parcel.support_parent_storey_index
				record["support_parent_source_block_index"] = \
					parcel.support_parent_storey_index
			record["merged"] = false
			out.append(record)
	return out


static func _skywalk_constraints_by_parcel(
		reservations: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for reservation: Dictionary in reservations:
		var owner_ids := reservation.get("owner_parcel_ids", []) as Array
		var endpoints := reservation.get("owner_endpoints", []) as Array
		for index in mini(owner_ids.size(), endpoints.size()):
			var parcel_id := StringName(owner_ids[index])
			var endpoint := endpoints[index] as Dictionary
			if parcel_id.is_empty() or not endpoint.has("cell") \
					or not endpoint.has("facing"):
				continue
			if not out.has(parcel_id):
				out[parcel_id] = [] as Array[Dictionary]
			(out[parcel_id] as Array[Dictionary]).append({
				"cell": endpoint.cell as Vector3i,
				"facing": endpoint.facing as Vector3i,
			})
	return out


static func _merge_upper_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	# Index every optional upper source plate by its exact absolute two-storey
	# band.  Different terrain-root phases may overlap in Y without sharing the
	# same floor plane; keeping duration in the key prevents a one-storey cap
	# from being silently swallowed by a two-storey room.
	var ids: Array[StringName] = []
	ids.assign(lineages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var records_by_band: Dictionary = {}
	var eligible_record_count := 0
	var source_claimed_cells: Dictionary = {}
	for lineage_id: StringName in ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		for source_block: Dictionary in blocks:
			for source_cell: Vector3i in source_block.cells:
				source_claimed_cells[source_cell] = true
		for block_position in range(1, blocks.size()):
			var block := blocks[block_position] as Dictionary
			if bool(block.get("structural_forced", false)) \
					or bool(block.forced) and not _block_allows_recomposition(block):
				continue
			var duration := int(block.end_storey) - int(block.start_storey)
			var band_key := "%d/%d" % [(block.origin as Vector3i).y, duration]
			if not records_by_band.has(band_key):
				records_by_band[band_key] = [] as Array[Dictionary]
			(records_by_band[band_key] as Array[Dictionary]).append({
				"lineage_id": lineage_id,
				"block_position": block_position,
				"source_block_index": int(block.source_block_index),
				"block": block,
				"key": "%s/%d" % [lineage_id,
					int(block.source_block_index)],
			})
			eligible_record_count += 1

	var candidates: Array[Dictionary] = []
	var band_count := 0
	var multi_source_stamp_count := 0
	var exact_union_count := 0
	var band_keys := PackedStringArray(records_by_band.keys())
	band_keys.sort()
	for band_key: String in band_keys:
		var records := records_by_band[band_key] as Array[Dictionary]
		if records.size() < 2:
			continue
		band_count += 1
		var column_owner: Dictionary = {}
		var minimum := Vector2i(2147483647, 2147483647)
		var maximum := Vector2i(-2147483648, -2147483648)
		for record: Dictionary in records:
			var block := record.block as Dictionary
			for column_value: Variant in (block.home_columns as Dictionary).keys():
				var column := column_value as Vector2i
				minimum = minimum.min(column)
				maximum = maximum.max(column)
				if not column_owner.has(column):
					column_owner[column] = [] as Array[Dictionary]
				(column_owner[column] as Array[Dictionary]).append(record)
		var y := int(band_key.get_slice("/", 0))
		for kind: StringName in [&"long", &"building", &"slim"]:
			for yaw in 4:
				for x in range(minimum.x - 3, maximum.x + 4):
					for z in range(minimum.y - 3, maximum.y + 4):
						var origin := Vector3i(x, y, z)
						var columns := _stamp_columns(kind, origin, yaw)
						var participants_by_key: Dictionary = {}
						var valid := not columns.is_empty()
						for column_value: Variant in columns.keys():
							var column := column_value as Vector2i
							var claims := column_owner.get(column, []) as Array
							# More than one provisional owner is an earlier partition
							# defect. Zero owners is different: it is genuine residual
							# inhabited massif, and the exact 3D clearance transaction
							# below decides whether a composed room may bridge through it.
							if claims.size() > 1:
								valid = false
								break
							if claims.is_empty():
								continue
							var owner_record := claims[0] as Dictionary
							participants_by_key[String(owner_record.key)] = \
								owner_record
						if not valid or participants_by_key.size() < 2:
							continue
						var participants: Array[Dictionary] = []
						participants.assign(participants_by_key.values())
						participants.sort_custom(func(a: Dictionary,
								b: Dictionary) -> bool:
							return String(a.key) < String(b.key))
						var lineage_set: Dictionary = {}
						var union: Dictionary = {}
						var maximum_single_overlap := 0
						for participant: Dictionary in participants:
							lineage_set[StringName(participant.lineage_id)] = true
							var home := (participant.block as Dictionary) \
								.home_columns as Dictionary
							var overlap := _intersection_size(columns, home)
							if overlap < MIN_BEARING_OVERLAP_COLUMNS:
								valid = false
								break
							maximum_single_overlap = maxi(maximum_single_overlap,
								overlap)
							for value: Variant in home.keys():
								union[value] = true
						if not valid or lineage_set.size() < 2 \
								or columns.size() <= maximum_single_overlap:
							continue
						var constrained_participants: Array[Dictionary] = []
						for participant: Dictionary in participants:
							if _block_has_interface_constraint(
									participant.block as Dictionary):
								constrained_participants.append(participant)
						if constrained_participants.size() > 1:
							continue
						var primary := constrained_participants[0] as Dictionary \
							if constrained_participants.size() == 1 \
							else _primary_participant(lineages, participants,
								columns, world_seed)
						if not constrained_participants.is_empty() \
								and (not _participant_can_bear(lineages, primary,
								columns) or not _candidate_matches_constraints(kind,
								origin, yaw, primary.block as Dictionary)):
							continue
						if primary.is_empty() or not _resumptions_overlap(
								lineages, participants, columns):
							continue
						var primary_block := primary.block as Dictionary
						var merged_stamp := _record(kind, origin, yaw,
							int(primary_block.start_storey),
							int(primary_block.end_storey))
						if merged_stamp.is_empty() or not \
								_record_is_clear_for_participants(grid,
								protected_owners, merged_stamp, lineage_set):
							continue
						multi_source_stamp_count += 1
						exact_union_count += int(_same_set(columns, union))
						var tall_tower_relief := 0
						var maximum_height := 0
						for participant: Dictionary in participants:
							var participant_lineage := lineages[
								StringName(participant.lineage_id)] as Dictionary
							var participant_blocks := participant_lineage.blocks \
								as Array[Dictionary]
							var height := _lineage_storey_count(participant_blocks)
							maximum_height = maxi(maximum_height, height)
							tall_tower_relief += int(height \
								>= EXTRUDED_LINEAGE_STOREYS \
								and _lineage_is_tower_only(participant_blocks))
						var participant_keys := PackedStringArray()
						for participant: Dictionary in participants:
							participant_keys.append(String(participant.key))
						var tie := posmod(Helper._mix64(world_seed \
							^ "/".join(participant_keys).hash() * 31 \
							^ kind.hash() * 47 ^ x * 73856093 \
							^ z * 19349663 ^ yaw * 83492791), 1000003)
						var covered_source_columns := _intersection_size(columns,
							union)
						var repetition := _merged_vertical_repetition_audit(
							lineages, participants, columns)
						candidates.append({
							"primary": primary,
							"participants": participants,
							"merged_stamp": merged_stamp,
							"tall_tower_relief": tall_tower_relief,
							"height": maximum_height,
							"participant_count": participants.size(),
							"area": columns.size(),
							"covered_source_columns": covered_source_columns,
							"residual_bridge_columns": columns.size() \
								- covered_source_columns,
							"displaced_source_columns": union.size() \
								- covered_source_columns,
							"strong_registration_count": int(
								repetition.strong_registration_count),
							"registered_facade_plane_count": int(
								repetition.registered_facade_plane_count),
							"tie": tie,
						})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tall_tower_relief) != int(b.tall_tower_relief):
			return int(a.tall_tower_relief) > int(b.tall_tower_relief)
		if int(a.strong_registration_count) \
				!= int(b.strong_registration_count):
			return int(a.strong_registration_count) \
				< int(b.strong_registration_count)
		if int(a.registered_facade_plane_count) \
				!= int(b.registered_facade_plane_count):
			return int(a.registered_facade_plane_count) \
				< int(b.registered_facade_plane_count)
		if int(a.height) != int(b.height):
			return int(a.height) > int(b.height)
		if int(a.participant_count) != int(b.participant_count):
			return int(a.participant_count) > int(b.participant_count)
		if int(a.covered_source_columns) != int(b.covered_source_columns):
			return int(a.covered_source_columns) > int(b.covered_source_columns)
		if int(a.displaced_source_columns) != int(b.displaced_source_columns):
			return int(a.displaced_source_columns) \
				< int(b.displaced_source_columns)
		if int(a.area) != int(b.area):
			return int(a.area) > int(b.area)
		return int(a.tie) < int(b.tie))
	# A source lineage may legitimately join a different room plate on several
	# height bands. Lock exact source blocks, not whole 2D parcel identities.
	var used_records: Dictionary = {}
	var claimed_cells: Dictionary = {}
	var merged_count := 0
	var merged_lineage_count := 0
	var selected_residual_bridge_count := 0
	for candidate: Dictionary in candidates:
		var participants := candidate.participants as Array[Dictionary]
		var unavailable := false
		for participant: Dictionary in participants:
			if used_records.has(String(participant.key)):
				unavailable = true
				break
		if unavailable:
			continue
		var merged := candidate.merged_stamp as Dictionary
		if not _floorplate_transition_is_structurally_legible(
				merged.columns as Dictionary, {},
				(merged.origin as Vector3i).y, source_claimed_cells, grid):
			continue
		for cell: Vector3i in merged.cells:
			if claimed_cells.has(cell):
				unavailable = true
				break
		if unavailable:
			continue
		var primary_record := candidate.primary as Dictionary
		var primary_id := StringName(primary_record.lineage_id)
		var primary := lineages[primary_id] as Dictionary
		var primary_blocks := primary.blocks as Array[Dictionary]
		var primary_position := _block_position(primary_blocks,
			int(primary_record.source_block_index))
		if primary_position < 1:
			continue
		var original_primary := primary_blocks[primary_position] as Dictionary
		# Candidates were enumerated from one immutable band snapshot. A lower
		# selected merge may have removed one participant block; reject that stale
		# candidate transactionally instead of partially applying it.
		for participant: Dictionary in participants:
			var participant_lineage := lineages[
				StringName(participant.lineage_id)] as Dictionary
			if _block_position(participant_lineage.blocks as Array[Dictionary],
					int(participant.source_block_index)) < 1:
				unavailable = true
				break
		if unavailable:
			continue
		var first := merged
		first = _record(StringName(merged.kind), merged.origin as Vector3i,
			int(merged.yaw_quarters), int(original_primary.start_storey),
			int(original_primary.end_storey))
		first["forced"] = bool(original_primary.forced)
		first["original_kind"] = original_primary.original_kind
		first["original_origin"] = original_primary.original_origin
		first["original_yaw_quarters"] = original_primary.original_yaw_quarters
		first["home_origin"] = original_primary.home_origin
		first["home_columns"] = original_primary.home_columns
		first["source_block_index"] = original_primary.source_block_index
		first["merged"] = true
		first["merged_lineage_count"] = participants.size()
		for metadata_key: String in ["address_expandable",
				"address_threshold", "address_frontage",
				"feature_endpoint_constraints", "court_contact_columns",
				"structural_forced", "interface_forced", "bearing_forced",
				"support_parent_lineage_id",
				"support_parent_source_storey",
				"support_parent_source_block_index"]:
			if original_primary.has(metadata_key):
				first[metadata_key] = original_primary[metadata_key]
		primary_blocks[primary_position] = first
		primary["blocks"] = primary_blocks
		primary["paired_primary"] = true
		var paired_with: Array[StringName] = []
		for participant: Dictionary in participants:
			var participant_id := StringName(participant.lineage_id)
			used_records[String(participant.key)] = true
			if participant_id == primary_id:
				continue
			paired_with.append(participant_id)
			var secondary := lineages[participant_id] as Dictionary
			var secondary_blocks := secondary.blocks as Array[Dictionary]
			var secondary_position := _block_position(secondary_blocks,
				int(participant.source_block_index))
			if secondary_position < 1:
				continue
			secondary_blocks.remove_at(secondary_position)
			if secondary_position < secondary_blocks.size():
				var resumed := secondary_blocks[secondary_position] as Dictionary
				resumed["support_parent_lineage_id"] = primary_id
				resumed["support_parent_source_storey"] = \
					int(first.end_storey) - 1
				resumed["support_parent_source_block_index"] = \
					int(first.source_block_index)
				secondary_blocks[secondary_position] = resumed
			secondary["blocks"] = secondary_blocks
			secondary["paired_secondary"] = true
			secondary["paired_with"] = primary_id
			lineages[participant_id] = secondary
		primary["paired_with"] = paired_with
		lineages[primary_id] = primary
		for cell: Vector3i in first.cells:
			claimed_cells[cell] = true
		merged_count += 1
		merged_lineage_count += participants.size()
		selected_residual_bridge_count += int(
			int(candidate.residual_bridge_columns) > 0)
	last_merge_diagnostic = {
		"eligible_upper_block_count": eligible_record_count,
		"candidate_band_count": band_count,
		"multi_source_stamp_count": multi_source_stamp_count,
		"exact_union_pair_count": exact_union_count,
		"candidate_count": candidates.size(),
		"selected_count": merged_count,
		"merged_lineage_count": merged_lineage_count,
		"selected_residual_bridge_count": selected_residual_bridge_count,
	}
	return merged_count


static func _primary_participant(lineages: Dictionary,
		participants: Array[Dictionary], columns: Dictionary,
		world_seed: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for participant: Dictionary in participants:
		var lineage_id := StringName(participant.lineage_id)
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		var position := _block_position(blocks,
			int(participant.source_block_index))
		if position < 1:
			continue
		var lower := blocks[position - 1] as Dictionary
		var overlap := _intersection_size(columns,
			lower.columns as Dictionary)
		if overlap <= 0:
			continue
		var height := _lineage_storey_count(blocks)
		var tie := posmod(Helper._mix64(world_seed \
			^ String(lineage_id).hash() * 31 \
			^ int(participant.source_block_index) * 0x45d9f3b), 1000003)
		candidates.append({"record": participant, "overlap": overlap,
			"height": height, "tie": tie})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.overlap) != int(b.overlap):
			return int(a.overlap) > int(b.overlap)
		if int(a.height) != int(b.height):
			return int(a.height) > int(b.height)
		return int(a.tie) < int(b.tie))
	return candidates[0].record as Dictionary


static func _participant_can_bear(lineages: Dictionary,
		participant: Dictionary, columns: Dictionary) -> bool:
	if participant.is_empty():
		return false
	var lineage := lineages[StringName(participant.lineage_id)] as Dictionary
	var blocks := lineage.blocks as Array[Dictionary]
	var position := _block_position(blocks,
		int(participant.source_block_index))
	return position >= 1 and _intersection_size(columns,
		(blocks[position - 1] as Dictionary).columns as Dictionary) > 0


static func _merged_vertical_repetition_audit(lineages: Dictionary,
		participants: Array[Dictionary], columns: Dictionary) -> Dictionary:
	## A cross-lineage room is chosen for structural and volumetric reasons, but
	## it is still one visible storey in every lineage it consumes. Count the
	## world-space facade planes it would retain against every surviving lower
	## and upper neighbor before candidate selection; otherwise the greedy merge
	## can create the very registered tower silhouette the later variation pass
	## is unable to revisit.
	var registered_planes := 0
	var strong_registrations := 0
	for participant: Dictionary in participants:
		var lineage := lineages[StringName(participant.lineage_id)] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		var position := _block_position(blocks,
			int(participant.source_block_index))
		if position < 0:
			continue
		var current := blocks[position] as Dictionary
		for neighbor_position in [position - 1, position + 1]:
			if neighbor_position < 0 or neighbor_position >= blocks.size():
				continue
			var neighbor := blocks[neighbor_position] as Dictionary
			var contiguous := int(neighbor.end_storey) \
				== int(current.start_storey) if neighbor_position < position \
				else int(current.end_storey) == int(neighbor.start_storey)
			if not contiguous:
				continue
			var registered := _registered_facade_plane_count(columns,
				neighbor.columns as Dictionary)
			registered_planes += registered
			strong_registrations += int(registered >= 2)
	return {
		"registered_facade_plane_count": registered_planes,
		"strong_registration_count": strong_registrations,
	}


static func _resumptions_overlap(lineages: Dictionary,
		participants: Array[Dictionary], columns: Dictionary) -> bool:
	for participant: Dictionary in participants:
		var lineage := lineages[StringName(participant.lineage_id)] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		var position := _block_position(blocks,
			int(participant.source_block_index))
		if position >= 0 and position + 1 < blocks.size():
			var upper := blocks[position + 1] as Dictionary
			if _intersection_size(columns, upper.columns as Dictionary) <= 0:
				return false
	return true


static func _block_position(blocks: Array[Dictionary],
		source_block_index: int) -> int:
	for position in blocks.size():
		if int((blocks[position] as Dictionary).source_block_index) \
				== source_block_index:
			return position
	return -1


static func _record_is_clear_for_participants(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, record: Dictionary,
		participant_ids: Dictionary) -> bool:
	for cell: Vector3i in record.cells:
		if not grid.contains(cell) \
				or grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE]:
			return false
		for owner_value: Variant in (protected_owners.get(cell, {}) \
				as Dictionary).keys():
			if not participant_ids.has(StringName(owner_value)):
				return false
	return true


static func _bridge_stamp_for_blocks(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, left_id: StringName, right_id: StringName,
		left: Dictionary, right: Dictionary, world_seed: int) -> Dictionary:
	var left_columns := left.home_columns as Dictionary
	var right_columns := right.home_columns as Dictionary
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for source: Dictionary in [left_columns, right_columns]:
		for value: Variant in source.keys():
			var column := value as Vector2i
			minimum = minimum.min(column)
			maximum = maximum.max(column)
	var candidates: Array[Dictionary] = []
	var y := (left.origin as Vector3i).y
	for kind: StringName in [&"long", &"building", &"slim"]:
		for yaw in 4:
			for x in range(minimum.x - 4, maximum.x + 5):
				for z in range(minimum.y - 4, maximum.y + 5):
					var origin := Vector3i(x, y, z)
					var columns := _stamp_columns(kind, origin, yaw)
					var left_overlap := _intersection_size(columns, left_columns)
					var right_overlap := _intersection_size(columns, right_columns)
					if left_overlap < MIN_BEARING_OVERLAP_COLUMNS \
							or right_overlap < MIN_BEARING_OVERLAP_COLUMNS:
						continue
					var trial := _record(kind, origin, yaw,
						int(left.start_storey), int(left.end_storey))
					if trial.is_empty() or not _pair_record_is_clear(grid,
							protected_owners, trial, left_id, right_id):
						continue
					var extra := columns.size() - left_overlap - right_overlap
					var score := (left_overlap + right_overlap) * 160 \
						+ columns.size() * 16 - maxi(extra, 0) * 35
					var tie := posmod(Helper._mix64(world_seed \
						^ String(left_id).hash() * 31 \
						^ String(right_id).hash() * 47 ^ kind.hash() \
						^ x * 73856093 ^ z * 19349663 ^ yaw * 83492791),
						1000003)
					candidates.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"score": score, "tie": tie})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	return candidates[0]


static func _pair_record_is_clear(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, record: Dictionary,
		left_id: StringName, right_id: StringName) -> bool:
	for cell: Vector3i in record.cells:
		if not grid.contains(cell) \
				or grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE]:
			return false
		for owner_value: Variant in (protected_owners.get(cell, {}) \
				as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if owner_id not in [left_id, right_id]:
				return false
	return true


static func _couple_upper_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	## Neighboring provisional plates often cannot form one exact rectangular
	## room because their half-cell phases differ. Solve those cases jointly:
	## two lineages may exchange their provisional mass and nearby unclaimed
	## massif in one transaction, producing two disjoint but differently sized,
	## shifted upper rooms. This is the paired move that a serial per-lineage
	## solver cannot make without temporarily colliding with its neighbor.
	var records_by_band: Dictionary = {}
	var ids: Array[StringName] = []
	ids.assign(lineages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var composed_cells: Dictionary = {}
	for lineage_id: StringName in ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			if bool(block.merged):
				for cell: Vector3i in block.cells:
					composed_cells[cell] = true
			if position < 1 or bool(block.merged) \
					or block.has("support_parent_lineage_id") \
					or bool(block.get("structural_forced", false)) \
					or bool(block.forced) and not _block_allows_recomposition(block):
				continue
			var duration := int(block.end_storey) - int(block.start_storey)
			var key := "%d/%d" % [(block.origin as Vector3i).y, duration]
			if not records_by_band.has(key):
				records_by_band[key] = [] as Array[Dictionary]
			(records_by_band[key] as Array[Dictionary]).append({
				"lineage_id": lineage_id,
				"source_block_index": int(block.source_block_index),
				"key": "%s/%d" % [lineage_id,
					int(block.source_block_index)],
				"current": block,
				"previous": blocks[position - 1],
				"next": blocks[position + 1] if position + 1 < blocks.size() \
					else {},
				"height": _lineage_storey_count(blocks),
			})
	var pair_candidates: Array[Dictionary] = []
	var band_keys := PackedStringArray(records_by_band.keys())
	band_keys.sort()
	for band_key: String in band_keys:
		var records := records_by_band[band_key] as Array[Dictionary]
		for left_index in records.size():
			var left := records[left_index] as Dictionary
			for right_index in range(left_index + 1, records.size()):
				var right := records[right_index] as Dictionary
				if left.lineage_id == right.lineage_id \
						or _minimum_column_distance(
							(left.current as Dictionary).columns as Dictionary,
							(right.current as Dictionary).columns as Dictionary) > 3:
					continue
				var participant_ids: Dictionary = {
					StringName(left.lineage_id): true,
					StringName(right.lineage_id): true,
				}
				var left_variants := _coupled_variants(grid, protected_owners,
					composed_cells, participant_ids, left, world_seed)
				var right_variants := _coupled_variants(grid, protected_owners,
					composed_cells, participant_ids, right, world_seed)
				for left_variant: Dictionary in left_variants:
					for right_variant: Dictionary in right_variants:
						if _intersection_size(left_variant.columns as Dictionary,
								right_variant.columns as Dictionary) > 0:
							continue
						var non_tower_count := int(StringName(left_variant.kind) \
							!= &"tower") + int(StringName(right_variant.kind) \
							!= &"tower")
						if non_tower_count == 0:
							continue
						var diversity := int(StringName(left_variant.kind) \
							!= StringName(right_variant.kind))
						var score := int(left_variant.score) \
							+ int(right_variant.score) + non_tower_count * 2200 \
							+ diversity * 700
						var tie := posmod(Helper._mix64(world_seed \
							^ String(left.key).hash() * 31 \
							^ String(right.key).hash() * 47 \
							^ String(left_variant.kind).hash() * 59 \
							^ String(right_variant.kind).hash() * 71), 1000003)
						pair_candidates.append({"left": left, "right": right,
							"left_variant": left_variant,
							"right_variant": right_variant,
							"tower_relief": int(left_variant.tower_relief) \
								+ int(right_variant.tower_relief),
							"interface_tower_relief": int(
								_block_has_interface_constraint(
									left.current as Dictionary) \
								and StringName((left.current as Dictionary).kind) \
									== &"tower" \
								and StringName(left_variant.kind) != &"tower") \
								+ int(_block_has_interface_constraint(
									right.current as Dictionary) \
								and StringName((right.current as Dictionary).kind) \
									== &"tower" \
								and StringName(right_variant.kind) != &"tower"),
							"strong_registration_count": int(
								left_variant.strong_registration_count) + int(
								right_variant.strong_registration_count),
							"registered_facade_plane_count": int(
								left_variant.registered_facade_plane_count) + int(
								right_variant.registered_facade_plane_count),
							"height": maxi(int(left.height), int(right.height)),
							"score": score, "tie": tie})
	pair_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.interface_tower_relief) != int(b.interface_tower_relief):
			return int(a.interface_tower_relief) \
				> int(b.interface_tower_relief)
		if int(a.tower_relief) != int(b.tower_relief):
			return int(a.tower_relief) > int(b.tower_relief)
		if int(a.strong_registration_count) \
				!= int(b.strong_registration_count):
			return int(a.strong_registration_count) \
				< int(b.strong_registration_count)
		if int(a.registered_facade_plane_count) \
				!= int(b.registered_facade_plane_count):
			return int(a.registered_facade_plane_count) \
				< int(b.registered_facade_plane_count)
		if int(a.height) != int(b.height):
			return int(a.height) > int(b.height)
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	var used_records: Dictionary = {}
	var claimed_cells := composed_cells.duplicate()
	var selected := 0
	for candidate: Dictionary in pair_candidates:
		var left := candidate.left as Dictionary
		var right := candidate.right as Dictionary
		if used_records.has(String(left.key)) \
				or used_records.has(String(right.key)):
			continue
		var left_lineage := lineages[StringName(left.lineage_id)] as Dictionary
		var right_lineage := lineages[StringName(right.lineage_id)] as Dictionary
		var left_blocks := left_lineage.blocks as Array[Dictionary]
		var right_blocks := right_lineage.blocks as Array[Dictionary]
		var left_position := _block_position(left_blocks,
			int(left.source_block_index))
		var right_position := _block_position(right_blocks,
			int(right.source_block_index))
		if left_position < 1 or right_position < 1:
			continue
		var left_replacement := _coupled_replacement(
			left_blocks[left_position] as Dictionary,
			candidate.left_variant as Dictionary)
		var right_replacement := _coupled_replacement(
			right_blocks[right_position] as Dictionary,
			candidate.right_variant as Dictionary)
		if _record_overlaps_claimed(left_replacement, claimed_cells) \
				or _record_overlaps_claimed(right_replacement, claimed_cells):
			continue
		left_blocks[left_position] = left_replacement
		right_blocks[right_position] = right_replacement
		left_lineage["blocks"] = left_blocks
		right_lineage["blocks"] = right_blocks
		lineages[StringName(left.lineage_id)] = left_lineage
		lineages[StringName(right.lineage_id)] = right_lineage
		used_records[String(left.key)] = true
		used_records[String(right.key)] = true
		for record: Dictionary in [left_replacement, right_replacement]:
			for cell: Vector3i in record.cells:
				claimed_cells[cell] = true
		selected += 1
	return selected


static func _coupled_variants(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		participant_ids: Dictionary, record: Dictionary,
		world_seed: int,
		require_new_projection_bearing: bool = false,
		defer_structural_proof: bool = false) -> Array[Dictionary]:
	var current := record.current as Dictionary
	var previous := record.previous as Dictionary
	var next := record.next as Dictionary
	var current_columns := current.columns as Dictionary
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in current_columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var out: Array[Dictionary] = []
	for kind: StringName in ROOM_KINDS:
		for yaw in 4:
			for x in range(minimum.x - 4, maximum.x + 5):
				for z in range(minimum.y - 4, maximum.y + 5):
					var origin := Vector3i(x, (current.origin as Vector3i).y, z)
					var columns := _stamp_columns(kind, origin, yaw)
					if columns.is_empty() or _same_set(columns, current_columns) \
							or _same_set(columns,
								(previous.columns as Dictionary)) \
							or not next.is_empty() and _same_set(columns,
								(next.columns as Dictionary)):
						continue
					if not _candidate_matches_constraints(kind, origin, yaw,
							current):
						continue
					var lower_overlap := _intersection_size(columns,
						(previous.columns as Dictionary))
					if lower_overlap < _required_bearing_overlap(columns):
						continue
					var upper_overlap := 0
					if not next.is_empty():
						upper_overlap = _intersection_size(columns,
							next.columns as Dictionary)
						if upper_overlap <= 0:
							continue
					var trial := _record(kind, origin, yaw,
						int(current.start_storey), int(current.end_storey))
					if trial.is_empty() or _record_overlaps_claimed(trial,
							claimed_cells) or not _record_is_clear_for_participants(
							grid, protected_owners, trial, participant_ids) \
							or not _new_projection_has_clearance(trial,
								current_columns, protected_owners, claimed_cells,
								participant_ids):
						continue
					var difference := _symmetric_difference_size(columns,
						current_columns)
					var tower_relief := int(StringName(current.kind) == &"tower" \
						and kind != &"tower")
					var kind_change := int(kind != StringName(current.kind))
					var expanded := not _is_subset(columns, current_columns)
					var scale_bonus := 260 if kind == &"slim" \
						else 190 if kind == &"building" \
						else 80 if kind == &"long" else 0
					var repetition_cost := _vertical_repetition_cost(kind, yaw,
						columns, previous) + _vertical_repetition_cost(kind, yaw,
						columns, next)
					var registration := _candidate_vertical_registration(
						columns, previous, next)
					var score := tower_relief * 7000 + kind_change * 1800 \
						+ int(expanded) * 700 + difference * 55 \
						+ lower_overlap * 22 + upper_overlap * 12 + scale_bonus \
						- repetition_cost
					var tie := posmod(Helper._mix64(world_seed \
						^ String(record.key).hash() * 31 ^ kind.hash() * 47 \
						^ x * 73856093 ^ z * 19349663 ^ yaw * 83492791),
						1000003)
					out.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"tower_relief": tower_relief, "score": score,
						"strong_registration_count": int(
							registration.strong_registration_count),
						"registered_facade_plane_count": int(
							registration.registered_facade_plane_count),
						"tie": tie})
					# Structural support depends on the final occupied cells beneath
					# the stamp. Keep a bounded visual frontier here, then run the
					# more expensive connectivity/attachment proof only on that
					# frontier below rather than on thousands of losing stamps.
					if out.size() > MAX_STRUCTURAL_VARIANT_FRONTIER * 2:
						out.sort_custom(func(a: Dictionary,
								b: Dictionary) -> bool:
							return _coupled_variant_is_better(a, b))
						out.resize(MAX_STRUCTURAL_VARIANT_FRONTIER)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _coupled_variant_is_better(a, b))
	if out.size() > MAX_STRUCTURAL_VARIANT_FRONTIER:
		out.resize(MAX_STRUCTURAL_VARIANT_FRONTIER)
	var legible: Array[Dictionary] = []
	var legible_limit := MAX_STRUCTURAL_VARIANT_FRONTIER \
		if defer_structural_proof else 18
	for variant: Dictionary in out:
		var columns := variant.columns as Dictionary
		# A paired half-storey transaction may replace the room that physically
		# bears this candidate. Its support cannot be proven until both candidate
		# records exist in one joint claim set; filtering it here recreated a 2D,
		# solve-one-room-at-a-time assumption inside the volumetric repair.
		if not defer_structural_proof and not \
				_floorplate_transition_is_structurally_legible(columns,
					previous.columns as Dictionary,
					(current.origin as Vector3i).y, claimed_cells, grid):
			continue
		if require_new_projection_bearing \
				and not _new_projection_is_directly_borne(grid, columns,
					previous.columns as Dictionary,
					(current.origin as Vector3i).y, claimed_cells):
			continue
		legible.append(variant)
		if legible.size() >= legible_limit:
			break
	return legible


static func _new_projection_is_directly_borne(grid: WarrenSpatialGrid,
		candidate_columns: Dictionary, lower_columns: Dictionary, upper_base_y: int,
		claimed_cells: Dictionary) -> bool:
	## Used for an untouched continuation above a paired replacement. The moved
	## room itself may deliberately create a one-bay outcropping because the later
	## town-wide support transaction can choose compatible measured brackets. An
	## unchanged room above it may not acquire a new brace obligation indirectly:
	## every column outside the replacement below must remain directly borne.
	for column_value: Variant in candidate_columns.keys():
		var column := column_value as Vector2i
		if lower_columns.has(column):
			continue
		var below := Vector3i(column.x, upper_base_y - 1, column.y)
		if claimed_cells.has(below):
			continue
		if grid != null and grid.use_at(below) \
				== WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			continue
		return false
	return true


static func _floorplate_transition_is_structurally_legible(
		candidate_columns: Dictionary, lower_columns: Dictionary,
		upper_base_y: int, claimed_cells: Dictionary,
		grid: WarrenSpatialGrid) -> bool:
	## Logical ancestry is not visual bearing. Resolve the exact support under
	## every candidate column, including neighboring inhabited mass, then admit
	## only a fully borne plate or one bracketable room bay. A bracketable bay is
	## one connected one/two-cell-deep strip, leaves at least half the room on
	## direct bearing, and has a straight attachment course that the authored 3 m
	## support pair plus optional one-brace terminal can tile without scaling.
	if candidate_columns.is_empty():
		return false
	var borne: Dictionary = {}
	var unborne: Dictionary = {}
	for column_value: Variant in candidate_columns.keys():
		var column := column_value as Vector2i
		var below := Vector3i(column.x, upper_base_y - 1, column.y)
		if lower_columns.has(column) or claimed_cells.has(below) \
				or grid != null and grid.use_at(below) \
					== WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			borne[column] = true
		else:
			unborne[column] = true
	if unborne.is_empty():
		return true
	if borne.size() * 2 < candidate_columns.size() \
			or not _column_set_is_connected(unborne):
		return false
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i.UP, Vector2i.DOWN]:
		var attachments: Dictionary = {}
		var valid := true
		for column_value: Variant in unborne.keys():
			var column := column_value as Vector2i
			var attached := false
			for depth in range(1, 3):
				var inward := column - direction * depth
				if borne.has(inward):
					attachments[inward] = true
					attached = true
					break
			if not attached:
				valid = false
				break
		if valid and unborne.size() == 1 and attachments.size() == 1:
			return true
		if not valid or attachments.size() < 2:
			continue
		var span := Vector2i(-direction.y, direction.x)
		var ordered: Array[Vector2i] = []
		ordered.assign(attachments.keys())
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
		if valid:
			return true
	return false


static func _column_set_is_connected(columns: Dictionary) -> bool:
	if columns.is_empty():
		return false
	var keys := columns.keys()
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


static func _repair_unsupported_transitions(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	## Earlier composition operators make locally valid choices against a
	## provisional partition. A later merge or offset can remove the mass that
	## made one of those choices look borne. Repair the completed 3D partition,
	## where every occupied cell below a room is now known.
	##
	## This is deliberately a monotone cleanup rather than another town search:
	## one measured room plate is reopened at a time, and a replacement is
	## accepted only when the town-wide unsupported-transition count falls. That
	## prevents a fixed room from merely handing its floating edge to a child.
	var claimed_cells := _claimed_room_cells(lineages)
	var unsupported_count := _unsupported_transition_count(lineages, grid,
		claimed_cells)
	if unsupported_count <= 0:
		return 0
	var accepted := 0
	# A lower repair can transfer one obligation to its formerly supported child.
	# Revisit the ascending frontier until that same-count handoff reaches a cap
	# that can be borne outright. Eight sweeps exceeds the tallest admitted room
	# lineage while keeping the cleanup strictly bounded.
	for sweep in 8:
		var targets: Array[Dictionary] = []
		for id_value: Variant in lineages.keys():
			var lineage_id := StringName(id_value)
			var lineage := lineages[lineage_id] as Dictionary
			var blocks := lineage.blocks as Array[Dictionary]
			for position in blocks.size():
				var block := blocks[position] as Dictionary
				if position == 0 and int(block.start_storey) == 0 \
						and not block.has("support_parent_lineage_id"):
					continue
				if _floorplate_transition_is_structurally_legible(
						block.columns as Dictionary, {},
						(block.origin as Vector3i).y, claimed_cells, grid):
					continue
				targets.append({"lineage_id": lineage_id,
					"source_block_index": int(block.source_block_index),
					"y": (block.origin as Vector3i).y})
		targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.y) != int(b.y):
				return int(a.y) < int(b.y)
			if String(a.lineage_id) != String(b.lineage_id):
				return String(a.lineage_id) < String(b.lineage_id)
			return int(a.source_block_index) < int(b.source_block_index))
		var changed := 0
		for target: Dictionary in targets:
			var lineage_id := StringName(target.lineage_id)
			var lineage := lineages.get(lineage_id, {}) as Dictionary
			if lineage.is_empty():
				continue
			var blocks := lineage.blocks as Array[Dictionary]
			var position := _block_position(blocks,
				int(target.source_block_index))
			if position < 0:
				continue
			var current := blocks[position] as Dictionary
			if _floorplate_transition_is_structurally_legible(
					current.columns as Dictionary, {},
					(current.origin as Vector3i).y, claimed_cells, grid):
				continue
			# A sealed hero backing with no explicit socket contract cannot move:
			# its adjacency, not merely its occupied cells, is the feature fact.
			# Addressed doors and skywalk endpoints are safe to recompose because
			# their exact transformed sockets are re-proved below.
			if bool(current.get("structural_forced", false)) \
					or bool(current.forced) \
					and not bool(current.get("bearing_forced", false)) \
					and not _block_allows_recomposition(current):
				if diagnostic_trace:
					print("ROOM_SUPPORT_REPAIR fixed lineage=", lineage_id,
						" block=", int(current.source_block_index),
						" origin=", current.origin)
				continue
			var candidate := _support_repair_variant(lineages, grid,
				protected_owners, claimed_cells, lineage_id, current,
				position, unsupported_count, world_seed ^ sweep * 0x45d9f3b)
			if candidate.is_empty():
				var parent_repair := _support_repair_parent_variant(lineages,
					grid, protected_owners, claimed_cells, lineage_id,
					current, position, unsupported_count,
					world_seed ^ sweep * 0x6d2b79f)
				if not parent_repair.is_empty():
					var parent_id := StringName(parent_repair.lineage_id)
					var parent_lineage := lineages[parent_id] as Dictionary
					var parent_blocks := parent_lineage.blocks as Array[Dictionary]
					var parent_position := _block_position(parent_blocks,
						int(parent_repair.source_block_index))
					if parent_position >= 0:
						var parent_current := parent_blocks[parent_position] \
							as Dictionary
						var parent_replacement := _support_replacement(
							parent_current, parent_repair.variant as Dictionary)
						for old_cell: Vector3i in parent_current.cells:
							if claimed_cells.get(old_cell, &"") == parent_id:
								claimed_cells.erase(old_cell)
						for new_cell: Vector3i in parent_replacement.cells:
							claimed_cells[new_cell] = parent_id
						parent_blocks[parent_position] = parent_replacement
						parent_lineage["blocks"] = parent_blocks
						lineages[parent_id] = parent_lineage
						unsupported_count = int(
							parent_repair.unsupported_count)
						accepted += 1
						changed += 1
						if diagnostic_trace:
							print("ROOM_SUPPORT_REPAIR parent lineage=",
								parent_id, " block=",
								int(parent_current.source_block_index),
								" origin=", parent_current.origin, " -> ",
								parent_replacement.origin, " bears=",
								lineage_id, "/",
								int(current.source_block_index), " remaining=",
								unsupported_count)
						continue
				# An ordinary source parcel can be addressed from an elevated public
				# street even when later 3D recomposition removes every plausible
				# bearer beneath that threshold. Keeping only its locked doorway storey
				# would create exactly the floating edge house the support audit exists
				# to prevent. If this lineage owns no market/court/skywalk socket and
				# bears no other house, let the complete optional building yield. This
				# removes its door as well as its rooms; topology features never enter
				# this fallback.
				var yield_ids := _optional_yield_lineage_closure(lineages,
					lineage_id)
				if not yield_ids.is_empty():
					for removed_id: StringName in yield_ids:
						var removed := lineages[removed_id] as Dictionary
						for removed_block: Dictionary in removed.blocks \
								as Array[Dictionary]:
							for old_cell: Vector3i in removed_block.cells:
								if claimed_cells.get(old_cell, &"") == removed_id:
									claimed_cells.erase(old_cell)
					for removed_id: StringName in yield_ids:
						lineages.erase(removed_id)
					unsupported_count = _unsupported_transition_count(
						lineages, grid, claimed_cells)
					accepted += yield_ids.size()
					changed += 1
					if diagnostic_trace:
						print("ROOM_SUPPORT_REPAIR omitted_unborne_buildings lineages=",
							yield_ids, " remaining=", unsupported_count)
					continue
				elif diagnostic_trace:
					print("ROOM_SUPPORT_REPAIR building_yield_blocked lineage=",
						lineage_id, " paired=", bool(lineage.get(
							"paired_primary", false)) or bool(lineage.get(
								"paired_secondary", false)), " dependents=",
						_lineage_blocks_have_external_dependents(lineages,
							lineage_id, blocks, 0))
				# Optional crowns are density, not topology. If neither the room nor
				# its bearing parent has a legal measured plate, omit only a terminal
				# unforced crown rather than materializing an unsupported box.
				var droppable_suffix := position > 0
				for suffix_position in range(position, blocks.size()):
					if bool((blocks[suffix_position] as Dictionary).forced):
						droppable_suffix = false
						break
				if droppable_suffix and _lineage_blocks_have_external_dependents(
						lineages, lineage_id, blocks, position):
					droppable_suffix = false
				if droppable_suffix:
					var omitted_count := blocks.size() - position
					for suffix_position in range(position, blocks.size()):
						for old_cell: Vector3i in (blocks[suffix_position] \
								as Dictionary).cells:
							if claimed_cells.get(old_cell, &"") == lineage_id:
								claimed_cells.erase(old_cell)
					blocks.resize(position)
					lineage["blocks"] = blocks
					lineages[lineage_id] = lineage
					unsupported_count = _unsupported_transition_count(
						lineages, grid, claimed_cells)
					accepted += 1
					changed += 1
					if diagnostic_trace:
						print("ROOM_SUPPORT_REPAIR omitted_unborne_crown lineage=",
							lineage_id, " block=",
							int(current.source_block_index), " storeys=",
							omitted_count, " remaining=",
							unsupported_count)
					continue
				if diagnostic_trace:
					print("ROOM_SUPPORT_REPAIR no_candidate lineage=",
						lineage_id, " block=",
						int(current.source_block_index), " origin=",
						current.origin, " unsupported=", unsupported_count)
				continue
			var replacement := _support_replacement(current, candidate)
			for old_cell: Vector3i in current.cells:
				if claimed_cells.get(old_cell, &"") == lineage_id:
					claimed_cells.erase(old_cell)
			for new_cell: Vector3i in replacement.cells:
				claimed_cells[new_cell] = lineage_id
			blocks[position] = replacement
			lineage["blocks"] = blocks
			lineages[lineage_id] = lineage
			unsupported_count = int(candidate.unsupported_count)
			if diagnostic_trace:
				print("ROOM_SUPPORT_REPAIR accepted lineage=", lineage_id,
					" block=", int(current.source_block_index), " origin=",
					current.origin, " -> ", replacement.origin,
					" remaining=", unsupported_count)
			accepted += 1
			changed += 1
			if unsupported_count <= 0:
				return accepted
		if changed == 0:
			break
	return accepted


static func _optional_yield_lineage_closure(lineages: Dictionary,
		root_id: StringName) -> Array[StringName]:
	## A paired merge can make another optional source lineage bear on the house
	## that failed support. Remove that finite dependent component atomically; an
	## individual storey is never cut loose. Exact feature sockets remain a veto.
	var closure: Dictionary = {root_id: true}
	var changed := true
	while changed:
		changed = false
		for other_id_value: Variant in lineages.keys():
			var other_id := StringName(other_id_value)
			if closure.has(other_id):
				continue
			var other := lineages[other_id] as Dictionary
			for block: Dictionary in other.blocks as Array[Dictionary]:
				if closure.has(StringName(block.get(
						"support_parent_lineage_id", &""))):
					closure[other_id] = true
					changed = true
					break
	var ids: Array[StringName] = []
	ids.assign(closure.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in ids:
		var lineage := lineages.get(lineage_id, {}) as Dictionary
		if lineage.is_empty():
			return [] as Array[StringName]
		var blocks := lineage.get("blocks", []) as Array[Dictionary]
		if blocks.is_empty():
			continue
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			if not (block.get("feature_endpoint_constraints", []) \
					as Array).is_empty() or not (block.get(
						"court_contact_columns", {}) as Dictionary).is_empty():
				return [] as Array[StringName]
			if block.has("support_parent_lineage_id") and not closure.has(
					StringName(block.support_parent_lineage_id)):
				return [] as Array[StringName]
			if bool(block.get("structural_forced", false)) \
					and not (position == 0 and int(block.start_storey) == 0):
				return [] as Array[StringName]
	return ids


static func _lineage_blocks_have_external_dependents(lineages: Dictionary,
		lineage_id: StringName, blocks: Array[Dictionary],
		first_position: int) -> bool:
	var removed_source_blocks: Dictionary = {}
	for position in range(first_position, blocks.size()):
		removed_source_blocks[int((blocks[position] \
			as Dictionary).source_block_index)] = true
	for other_id_value: Variant in lineages.keys():
		var other_id := StringName(other_id_value)
		if other_id == lineage_id:
			continue
		var other := lineages[other_id] as Dictionary
		for block: Dictionary in other.blocks as Array[Dictionary]:
			if StringName(block.get("support_parent_lineage_id", &"")) \
					== lineage_id and removed_source_blocks.has(int(block.get(
						"support_parent_source_block_index", -1))):
				return true
	return false


static func _support_repair_variant(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		claimed_cells: Dictionary, lineage_id: StringName,
		current: Dictionary, block_position: int,
		baseline_unsupported_count: int, world_seed: int) -> Dictionary:
	var current_columns := current.columns as Dictionary
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in current_columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var free_claims := claimed_cells.duplicate()
	for old_cell: Vector3i in current.cells:
		if free_claims.get(old_cell, &"") == lineage_id:
			free_claims.erase(old_cell)
	var previous: Dictionary = {}
	var next: Dictionary = {}
	var lineage := lineages[lineage_id] as Dictionary
	var blocks := lineage.blocks as Array[Dictionary]
	if block_position > 0:
		previous = blocks[block_position - 1] as Dictionary
	if block_position + 1 < blocks.size():
		next = blocks[block_position + 1] as Dictionary
	var candidates: Array[Dictionary] = []
	for kind: StringName in ROOM_KINDS:
		for yaw in 4:
			for x in range(minimum.x - 4, maximum.x + 5):
				for z in range(minimum.y - 4, maximum.y + 5):
					var origin := Vector3i(x,
						(current.origin as Vector3i).y, z)
					var columns := _stamp_columns(kind, origin, yaw)
					if columns.is_empty() or _same_set(columns,
							current_columns) or not _candidate_matches_constraints(
							kind, origin, yaw, current):
						continue
					var trial := _record(kind, origin, yaw,
						int(current.start_storey), int(current.end_storey))
					if trial.is_empty() or not _record_is_clear_for_lineage(
							grid, protected_owners, free_claims, trial,
							lineage_id):
						continue
					var overlaps_existing := false
					for cell: Vector3i in trial.cells:
						if free_claims.has(cell):
							overlaps_existing = true
							break
					if overlaps_existing:
						continue
					var trial_claims := free_claims.duplicate()
					for cell: Vector3i in trial.cells:
						trial_claims[cell] = lineage_id
					if not _floorplate_transition_is_structurally_legible(
							columns, {}, origin.y, trial_claims, grid):
						continue
					var unsupported := _unsupported_transition_count(lineages,
						grid, trial_claims, lineage_id,
						int(current.source_block_index), trial)
					# Direct room repair must strictly remove an obligation. Equal-count
					# handoffs are reserved for `_support_repair_parent_variant`, which
					# moves them monotonically downward toward terrain; allowing both
					# directions would let two adjacent storeys trade the same defect.
					if unsupported >= baseline_unsupported_count:
						continue
					var direct_bearing := _direct_bearing_column_count(columns,
						origin.y, trial_claims, grid)
					var registration := _candidate_vertical_registration(columns,
						previous, next)
					var difference := _symmetric_difference_size(columns,
						current_columns)
					var displacement := absi(origin.x \
						- (current.origin as Vector3i).x) + absi(origin.z \
						- (current.origin as Vector3i).z)
					var tie := posmod(Helper._mix64(world_seed \
						^ String(lineage_id).hash() * 31 \
						^ int(current.source_block_index) * 0x45d9f3b \
						^ kind.hash() * 47 ^ x * 73856093 \
						^ z * 19349663 ^ yaw * 83492791), 1000003)
					candidates.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"unsupported_count": unsupported,
						"direct_bearing_count": direct_bearing,
						"fully_borne": direct_bearing == columns.size(),
						"strong_registration_count": int(
							registration.strong_registration_count),
						"registered_facade_plane_count": int(
							registration.registered_facade_plane_count),
						"tower": kind == &"tower",
						"difference": difference,
						"displacement": displacement, "tie": tie})
					if candidates.size() > MAX_STRUCTURAL_VARIANT_FRONTIER * 2:
						candidates.sort_custom(func(a: Dictionary,
								b: Dictionary) -> bool:
							return _support_repair_is_better(a, b))
						candidates.resize(MAX_STRUCTURAL_VARIANT_FRONTIER)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _support_repair_is_better(a, b))
	return candidates[0] as Dictionary if not candidates.is_empty() else {}


static func _support_repair_parent_variant(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		claimed_cells: Dictionary, child_lineage_id: StringName,
		child: Dictionary, child_position: int,
		baseline_unsupported_count: int, world_seed: int) -> Dictionary:
	var parent_lineage_id := child_lineage_id
	var parent_source_block_index := -1
	if child.has("support_parent_lineage_id"):
		parent_lineage_id = StringName(child.support_parent_lineage_id)
		parent_source_block_index = int(child.get(
			"support_parent_source_block_index", -1))
	elif child_position > 0:
		var child_lineage := lineages[child_lineage_id] as Dictionary
		var child_blocks := child_lineage.blocks as Array[Dictionary]
		parent_source_block_index = int((child_blocks[child_position - 1] \
			as Dictionary).source_block_index)
	if parent_source_block_index < 0 or not lineages.has(parent_lineage_id):
		return {}
	var parent_lineage := lineages[parent_lineage_id] as Dictionary
	var parent_blocks := parent_lineage.blocks as Array[Dictionary]
	var parent_position := _block_position(parent_blocks,
		parent_source_block_index)
	if parent_position < 0:
		return {}
	var parent := parent_blocks[parent_position] as Dictionary
	if bool(parent.get("structural_forced", false)) \
			or bool(parent.forced) \
			and not bool(parent.get("bearing_forced", false)) \
			and not _block_allows_recomposition(parent):
		return {}
	var parent_columns := parent.columns as Dictionary
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in parent_columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var free_claims := claimed_cells.duplicate()
	for old_cell: Vector3i in parent.cells:
		if free_claims.get(old_cell, &"") == parent_lineage_id:
			free_claims.erase(old_cell)
	var previous: Dictionary = {}
	var next: Dictionary = {}
	if parent_position > 0:
		previous = parent_blocks[parent_position - 1] as Dictionary
	if parent_position + 1 < parent_blocks.size():
		next = parent_blocks[parent_position + 1] as Dictionary
	var candidates: Array[Dictionary] = []
	for kind: StringName in ROOM_KINDS:
		for yaw in 4:
			for x in range(minimum.x - 4, maximum.x + 5):
				for z in range(minimum.y - 4, maximum.y + 5):
					var origin := Vector3i(x, (parent.origin as Vector3i).y, z)
					var columns := _stamp_columns(kind, origin, yaw)
					if columns.is_empty() or _same_set(columns, parent_columns) \
							or not _candidate_matches_constraints(kind, origin,
								yaw, parent):
						continue
					var trial := _record(kind, origin, yaw,
						int(parent.start_storey), int(parent.end_storey))
					if trial.is_empty() or not _record_is_clear_for_lineage(grid,
							protected_owners, free_claims, trial,
							parent_lineage_id):
						continue
					var overlaps_existing := false
					for cell: Vector3i in trial.cells:
						if free_claims.has(cell):
							overlaps_existing = true
							break
					if overlaps_existing:
						continue
					var trial_claims := free_claims.duplicate()
					for cell: Vector3i in trial.cells:
						trial_claims[cell] = parent_lineage_id
					# The parent may temporarily inherit the one unsupported
					# obligation from its child. A later, lower sweep then moves the
					# grandparent beneath it. This monotone downward handoff is the
					# only way to realign a locked elevated doorway whose whole stack
					# has drifted; it never increases the town-wide defect count.
					if not _floorplate_transition_is_structurally_legible(
								child.columns as Dictionary, {},
								(child.origin as Vector3i).y, trial_claims, grid):
						continue
					var unsupported := _unsupported_transition_count(lineages,
						grid, trial_claims, parent_lineage_id,
						int(parent.source_block_index), trial)
					if unsupported > baseline_unsupported_count:
						continue
					var child_bearing := _direct_bearing_column_count(
						child.columns as Dictionary,
						(child.origin as Vector3i).y, trial_claims, grid)
					var parent_bearing := _direct_bearing_column_count(columns,
						origin.y, trial_claims, grid)
					var registration := _candidate_vertical_registration(columns,
						previous, next)
					var displacement := absi(origin.x \
						- (parent.origin as Vector3i).x) + absi(origin.z \
						- (parent.origin as Vector3i).z)
					var tie := posmod(Helper._mix64(world_seed \
						^ String(parent_lineage_id).hash() * 31 \
						^ int(parent.source_block_index) * 0x45d9f3b \
						^ kind.hash() * 47 ^ x * 73856093 \
						^ z * 19349663 ^ yaw * 83492791), 1000003)
					candidates.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"unsupported_count": unsupported,
						"child_bearing_count": child_bearing,
						"direct_bearing_count": parent_bearing,
						"fully_borne": parent_bearing == columns.size(),
						"strong_registration_count": int(
							registration.strong_registration_count),
						"registered_facade_plane_count": int(
							registration.registered_facade_plane_count),
						"tower": kind == &"tower",
						"difference": _symmetric_difference_size(columns,
							parent_columns), "displacement": displacement,
						"tie": tie})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.unsupported_count) != int(b.unsupported_count):
			return int(a.unsupported_count) < int(b.unsupported_count)
		if int(a.child_bearing_count) != int(b.child_bearing_count):
			return int(a.child_bearing_count) > int(b.child_bearing_count)
		return _support_repair_is_better(a, b))
	if candidates.is_empty():
		return {}
	return {"lineage_id": parent_lineage_id,
		"source_block_index": int(parent.source_block_index),
		"variant": candidates[0],
		"unsupported_count": int((candidates[0] as Dictionary).unsupported_count)}


static func _support_repair_is_better(a: Dictionary,
		b: Dictionary) -> bool:
	if int(a.unsupported_count) != int(b.unsupported_count):
		return int(a.unsupported_count) < int(b.unsupported_count)
	if bool(a.fully_borne) != bool(b.fully_borne):
		return bool(a.fully_borne)
	if int(a.direct_bearing_count) != int(b.direct_bearing_count):
		return int(a.direct_bearing_count) > int(b.direct_bearing_count)
	if int(a.strong_registration_count) \
			!= int(b.strong_registration_count):
		return int(a.strong_registration_count) \
			< int(b.strong_registration_count)
	if int(a.registered_facade_plane_count) \
			!= int(b.registered_facade_plane_count):
		return int(a.registered_facade_plane_count) \
			< int(b.registered_facade_plane_count)
	if bool(a.tower) != bool(b.tower):
		return not bool(a.tower)
	if int(a.difference) != int(b.difference):
		return int(a.difference) > int(b.difference)
	if int(a.displacement) != int(b.displacement):
		return int(a.displacement) < int(b.displacement)
	return int(a.tie) < int(b.tie)


static func _support_replacement(current: Dictionary,
		variant: Dictionary) -> Dictionary:
	var replacement := current.duplicate(true)
	var stamped := _record(StringName(variant.kind),
		variant.origin as Vector3i, int(variant.yaw_quarters),
		int(current.start_storey), int(current.end_storey))
	for key: String in ["kind", "origin", "yaw_quarters", "columns", "cells"]:
		replacement[key] = stamped[key]
	replacement["support_repair"] = true
	return replacement


static func _claimed_room_cells(lineages: Dictionary) -> Dictionary:
	var claimed_cells: Dictionary = {}
	for id_value: Variant in lineages.keys():
		var lineage_id := StringName(id_value)
		var lineage := lineages[lineage_id] as Dictionary
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				claimed_cells[cell] = lineage_id
	return claimed_cells


static func _direct_bearing_column_count(columns: Dictionary,
		upper_base_y: int, claimed_cells: Dictionary,
		grid: WarrenSpatialGrid) -> int:
	var count := 0
	for column_value: Variant in columns.keys():
		var column := column_value as Vector2i
		var below := Vector3i(column.x, upper_base_y - 1, column.y)
		count += int(claimed_cells.has(below) or grid != null \
			and grid.use_at(below) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
	return count


static func _unsupported_transition_count(lineages: Dictionary,
		grid: WarrenSpatialGrid, claimed_cells: Dictionary,
		replacement_lineage_id: StringName = &"",
		replacement_source_block_index: int = -1,
		replacement: Dictionary = {}) -> int:
	var unsupported := 0
	for id_value: Variant in lineages.keys():
		var lineage_id := StringName(id_value)
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			if lineage_id == replacement_lineage_id \
					and int(block.source_block_index) \
						== replacement_source_block_index:
				block = replacement
			if position == 0 and int(block.start_storey) == 0 \
					and not block.has("support_parent_lineage_id"):
				continue
			unsupported += int(not _floorplate_transition_is_structurally_legible(
				block.columns as Dictionary, {},
				(block.origin as Vector3i).y, claimed_cells, grid))
	return unsupported


static func _lineage_support_audit(lineages: Dictionary,
		grid: WarrenSpatialGrid) -> Dictionary:
	var claimed_cells := _claimed_room_cells(lineages)
	var unsupported: Array[Dictionary] = []
	var unsupported_count := 0
	var transition_count := 0
	for id_value: Variant in lineages.keys():
		var lineage_id := StringName(id_value)
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			if position == 0 and int(block.start_storey) == 0 \
					and not block.has("support_parent_lineage_id"):
				continue
			transition_count += 1
			if _floorplate_transition_is_structurally_legible(
					block.columns as Dictionary, {},
					(block.origin as Vector3i).y, claimed_cells, grid):
				continue
			unsupported_count += 1
			if unsupported.size() < 16:
				var support_state := _transition_support_state(
					block.columns as Dictionary,
					(block.origin as Vector3i).y, claimed_cells, grid)
				unsupported.append({"lineage_id": lineage_id,
					"source_block_index": int(block.source_block_index),
					"origin": block.origin, "kind": block.kind,
					"merged": bool(block.get("merged", false)),
					"coupled": bool(block.get("coupled", false)),
					"expanded": bool(block.get("expanded", false)),
					"registration_relief": bool(block.get(
						"registration_relief", false)),
					"paired_registration_relief": bool(block.get(
						"paired_registration_relief", false)),
					"support_repair": bool(block.get("support_repair", false)),
					"forced": bool(block.get("forced", false)),
					"structural_forced": bool(block.get(
						"structural_forced", false)),
					"interface_forced": bool(block.get(
						"interface_forced", false)),
					"bearing_forced": bool(block.get("bearing_forced", false)),
					"recomposable_interface": _block_allows_recomposition(block),
					"borne_columns": support_state.borne_columns,
					"unborne_columns": support_state.unborne_columns,
				})
	return {"room_support_transition_count": transition_count,
		"unsupported_room_transition_count": unsupported_count,
		"unsupported_transition_count": unsupported_count,
		"unsupported_transition_details": unsupported}


static func _transition_support_state(columns: Dictionary,
		upper_base_y: int, claimed_cells: Dictionary,
		grid: WarrenSpatialGrid) -> Dictionary:
	var borne: Array[Vector2i] = []
	var unborne: Array[Vector2i] = []
	for column_value: Variant in columns.keys():
		var column := column_value as Vector2i
		var below := Vector3i(column.x, upper_base_y - 1, column.y)
		if claimed_cells.has(below) or grid != null \
				and grid.use_at(below) \
					== WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			borne.append(column)
		else:
			unborne.append(column)
	for values: Array[Vector2i] in [borne, unborne]:
		values.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x if a.x != b.x else a.y < b.y)
	return {"borne_columns": borne, "unborne_columns": unborne}


static func _coupled_variant_is_better(a: Dictionary,
		b: Dictionary) -> bool:
	if int(a.tower_relief) != int(b.tower_relief):
		return int(a.tower_relief) > int(b.tower_relief)
	if int(a.strong_registration_count) \
			!= int(b.strong_registration_count):
		return int(a.strong_registration_count) \
			< int(b.strong_registration_count)
	if int(a.registered_facade_plane_count) \
			!= int(b.registered_facade_plane_count):
		return int(a.registered_facade_plane_count) \
			< int(b.registered_facade_plane_count)
	if int(a.score) != int(b.score):
		return int(a.score) > int(b.score)
	if int(a.tie) != int(b.tie):
		return int(a.tie) < int(b.tie)
	if String(a.kind) != String(b.kind):
		return String(a.kind) < String(b.kind)
	if int(a.yaw_quarters) != int(b.yaw_quarters):
		return int(a.yaw_quarters) < int(b.yaw_quarters)
	var a_origin := a.origin as Vector3i
	var b_origin := b.origin as Vector3i
	return a_origin.x < b_origin.x if a_origin.x != b_origin.x \
		else a_origin.z < b_origin.z


static func _coupled_replacement(current: Dictionary,
		variant: Dictionary) -> Dictionary:
	var replacement := current.duplicate(true)
	var stamped := _record(StringName(variant.kind),
		variant.origin as Vector3i, int(variant.yaw_quarters),
		int(current.start_storey), int(current.end_storey))
	for key: String in ["kind", "origin", "yaw_quarters", "columns", "cells"]:
		replacement[key] = stamped[key]
	replacement["merged"] = false
	replacement["coupled"] = true
	return replacement


static func _record_overlaps_claimed(record: Dictionary,
		claimed_cells: Dictionary) -> bool:
	for cell: Vector3i in record.cells:
		if claimed_cells.has(cell):
			return true
	return false


static func _minimum_column_distance(left: Dictionary,
		right: Dictionary) -> int:
	var best := 2147483647
	for left_value: Variant in left.keys():
		var a := left_value as Vector2i
		for right_value: Variant in right.keys():
			var b := right_value as Vector2i
			best = mini(best, maxi(absi(a.x - b.x), absi(a.y - b.y)))
	return best


static func _required_bearing_overlap(columns: Dictionary) -> int:
	return maxi(MIN_BEARING_OVERLAP_COLUMNS,
		ceili(float(columns.size()) * 0.25))


static func _vary_unmerged_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	# Tall tower-only lineages get first choice of the residual inhabited mass.
	# This is deterministic, but unlike proposal-order packing it is explicitly
	# ordered by the visual defect the pass exists to remove.
	var ids: Array[StringName] = []
	ids.assign(lineages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var a_blocks := (lineages[a] as Dictionary).blocks as Array[Dictionary]
		var b_blocks := (lineages[b] as Dictionary).blocks as Array[Dictionary]
		var a_tower := int(_lineage_is_tower_only(a_blocks))
		var b_tower := int(_lineage_is_tower_only(b_blocks))
		if a_tower != b_tower:
			return a_tower > b_tower
		var a_height := _lineage_storey_count(a_blocks)
		var b_height := _lineage_storey_count(b_blocks)
		if a_height != b_height:
			return a_height > b_height
		return String(a) < String(b))
	# Begin from the complete result of the merge and coupled-room passes. The
	# former empty map only protected variants selected during this final pass;
	# an outcropping could therefore expand into residual cells already claimed
	# by a coupled room and survive until the grid commit rejected it.
	var claimed_cells: Dictionary = {}
	for existing_id_value: Variant in lineages.keys():
		var existing_id := StringName(existing_id_value)
		var existing := lineages[existing_id] as Dictionary
		for existing_block: Dictionary in existing.blocks as Array[Dictionary]:
			for cell: Vector3i in existing_block.cells:
				if not claimed_cells.has(cell):
					claimed_cells[cell] = existing_id
	var expanded_count := 0
	for lineage_id: StringName in ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		if blocks.size() < 2:
			continue
		var previous := blocks[0] as Dictionary
		for block in range(1, blocks.size()):
			var current := blocks[block] as Dictionary
			if bool(current.get("structural_forced", false)) \
					or bool(current.forced) and not _block_allows_recomposition(
						current) or bool(current.merged) \
					or current.has("support_parent_lineage_id"):
				previous = current
				continue
			var next := blocks[block + 1] as Dictionary \
				if block + 1 < blocks.size() else {}
			var variant := _volumetric_variant_stamp(grid, protected_owners,
				claimed_cells, lineage_id, current, previous, next, block,
				world_seed)
			if variant.is_empty():
				previous = current
				continue
			var replacement := _record(StringName(variant.kind),
				variant.origin as Vector3i, int(variant.yaw_quarters),
				int(current.start_storey), int(current.end_storey))
			replacement["forced"] = bool(current.forced)
			replacement["structural_forced"] = bool(current.get(
				"structural_forced", false))
			replacement["interface_forced"] = bool(current.get(
				"interface_forced", false))
			replacement["bearing_forced"] = bool(current.get(
				"bearing_forced", false))
			replacement["original_kind"] = current.original_kind
			replacement["original_origin"] = current.original_origin
			replacement["original_yaw_quarters"] = \
				current.original_yaw_quarters
			replacement["home_origin"] = current.home_origin
			replacement["home_columns"] = current.home_columns
			replacement["source_block_index"] = current.source_block_index
			replacement["address_expandable"] = bool(current.get(
				"address_expandable", false))
			replacement["address_threshold"] = current.get("address_threshold",
				Vector3i(2147483647, 2147483647, 2147483647))
			replacement["address_frontage"] = current.get("address_frontage",
				Vector3i.ZERO)
			replacement["feature_endpoint_constraints"] = current.get(
				"feature_endpoint_constraints", [])
			replacement["court_contact_columns"] = current.get(
				"court_contact_columns", {}).duplicate()
			replacement["merged"] = false
			replacement["expanded"] = bool(variant.expanded)
			blocks[block] = replacement
			for old_cell: Vector3i in current.cells:
				if claimed_cells.get(old_cell, &"") == lineage_id:
					claimed_cells.erase(old_cell)
			for cell: Vector3i in replacement.cells:
				claimed_cells[cell] = lineage_id
			expanded_count += int(bool(variant.expanded))
			previous = replacement
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
	return expanded_count


static func _relieve_registered_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	## The first three composition passes exchange mass between lineages and
	## make indispensable feature-aware choices. A storey selected early in
	## those passes cannot know the final plate above it, so local scoring can
	## accidentally preserve a registered facade after its neighbor moves.
	##
	## Run bounded coordinate descent over that finished 3D partition. A move is
	## accepted only when the actual two adjacent transitions improve
	## lexicographically (strong registrations, then retained facade planes,
	## then repeated room/ridge families). Every accepted move therefore lowers
	## the global vertical-repetition measure; alternating sweep direction lets
	## a middle storey react to both already-final neighbors without oscillation.
	var claimed_cells: Dictionary = {}
	for id_value: Variant in lineages.keys():
		var owner_id := StringName(id_value)
		var owner := lineages[owner_id] as Dictionary
		for block: Dictionary in owner.blocks as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				if not claimed_cells.has(cell):
					claimed_cells[cell] = owner_id
	var ids: Array[StringName] = []
	ids.assign(lineages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var accepted := 0
	for sweep in 4:
		var changed := 0
		var sweep_ids := ids.duplicate()
		if posmod(sweep, 2) == 1:
			sweep_ids.reverse()
		for lineage_id: StringName in sweep_ids:
			var lineage := lineages[lineage_id] as Dictionary
			var blocks := lineage.blocks as Array[Dictionary]
			if blocks.size() < 2:
				continue
			var positions: Array[int] = []
			for position in range(1, blocks.size()):
				positions.append(position)
			if posmod(sweep, 2) == 1:
				positions.reverse()
			for position: int in positions:
				var current := blocks[position] as Dictionary
				if bool(current.get("structural_forced", false)) \
						or bool(current.forced) and not _block_allows_recomposition(
							current) or bool(current.merged) \
						or current.has("support_parent_lineage_id"):
					continue
				var previous := blocks[position - 1] as Dictionary
				var next := blocks[position + 1] as Dictionary \
					if position + 1 < blocks.size() else {}
				var before := _vertical_profile_metric(current, previous, next)
				var variant := _volumetric_variant_stamp(grid,
					protected_owners, claimed_cells, lineage_id, current,
					previous, next, position, world_seed, false)
				if variant.is_empty():
					continue
				var replacement := _variant_replacement(current, variant)
				var after := _vertical_profile_metric(replacement,
					previous, next)
				if not _vertical_profile_is_better(after, before):
					continue
				for old_cell: Vector3i in current.cells:
					if claimed_cells.get(old_cell, &"") == lineage_id:
						claimed_cells.erase(old_cell)
				for cell: Vector3i in replacement.cells:
					claimed_cells[cell] = lineage_id
				blocks[position] = replacement
				changed += 1
				accepted += 1
			lineage["blocks"] = blocks
			lineages[lineage_id] = lineage
		if changed == 0:
			break
	return accepted


static func _relieve_paired_registered_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	## The serial cleanup above deliberately never occupies another lineage's
	## current cells. In a dense party-wall block this can leave two aligned upper
	## rooms mutually locked even though their combined mass has a much better
	## two-room partition. Reopen exactly two vertically overlapping records,
	## enumerate complete
	## measured rooms for both, and commit the disjoint pair atomically.
	##
	## At least one replacement must cross the old inter-lineage seam. Without
	## that requirement this would merely repeat coordinate descent at much higher
	## cost. Every accepted pair still preserves each lineage's lower bearing,
	## upper continuation, exact interface sockets, and protected feature volume.
	last_pair_diagnostic = {}
	var claimed_cells: Dictionary = {}
	for id_value: Variant in lineages.keys():
		var owner_id := StringName(id_value)
		var owner := lineages[owner_id] as Dictionary
		for block: Dictionary in owner.blocks as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				claimed_cells[cell] = owner_id
	var accepted := 0
	var examined_pairs := 0
	var peak_frontier := 0
	var traced_pairs: Array[Dictionary] = []
	# One bounded pass is enough: its inputs are already the fixed point of the
	# serial cleanup. Keeping only a tiny best-first frontier makes this a local
	# repair operator rather than another town-wide search nested inside every
	# hero-feature candidate.
	for sweep in 1:
		var records_by_band: Dictionary = {}
		var ids: Array[StringName] = []
		ids.assign(lineages.keys())
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		for lineage_id: StringName in ids:
			var lineage := lineages[lineage_id] as Dictionary
			var blocks := lineage.blocks as Array[Dictionary]
			for position in range(1, blocks.size()):
				var current := blocks[position] as Dictionary
				if bool(current.get("structural_forced", false)) \
						or bool(current.forced) and not _block_allows_recomposition(
							current) or bool(current.merged) \
						or current.has("support_parent_lineage_id"):
					continue
				var previous := blocks[position - 1] as Dictionary
				var next := blocks[position + 1] as Dictionary \
					if position + 1 < blocks.size() else {}
				var metric := _vertical_profile_metric(current, previous, next)
				if int(metric.strong_registration_count) <= 0:
					continue
				var exact_interface_priority := int(not (current.get(
					"court_contact_columns", {}) as Dictionary).is_empty()) * 100 \
					+ int(_block_has_interface_constraint(current)) * 20 \
					+ int(_same_set(current.columns as Dictionary,
						previous.columns as Dictionary)) * 5 \
					+ int(not next.is_empty() and _same_set(
						current.columns as Dictionary,
						next.columns as Dictionary)) * 5
				var record := {
					"lineage_id": lineage_id,
					"position": position,
					"source_block_index": int(current.source_block_index),
					"key": "%s/%d" % [lineage_id,
						int(current.source_block_index)],
					"current": current,
					"previous": previous,
					"next": next,
					"exact_interface_priority": exact_interface_priority,
				}
				# Adjacent terrain roots may be half a storey out of phase. Index this
				# one-storey record by each occupied fine Y slice, so rooms based at y=2
				# and y=3 can exchange the volume they both occupy at slice 3.
				var base_y := (current.origin as Vector3i).y
				for occupied_y in range(base_y,
						base_y + WarrenSpatialGrid.STOREY_CELLS):
					var band_key := "%d" % occupied_y
					if not records_by_band.has(band_key):
						records_by_band[band_key] = [] as Array[Dictionary]
					(records_by_band[band_key] as Array[Dictionary]).append(record)
		var candidates: Array[Dictionary] = []
		var seen_pair_keys: Dictionary = {}
		var band_keys: Array[String] = []
		for key_value: Variant in records_by_band.keys():
			band_keys.append(String(key_value))
		var band_priority: Dictionary = {}
		for band_key: String in band_keys:
			var priority := 0
			for record: Dictionary in records_by_band[band_key] \
					as Array[Dictionary]:
				priority = maxi(priority, int(record.exact_interface_priority))
			band_priority[band_key] = priority
		band_keys.sort_custom(func(a: String, b: String) -> bool:
			if int(band_priority[a]) != int(band_priority[b]):
				return int(band_priority[a]) > int(band_priority[b])
			return a.to_int() < b.to_int())
		for band_key: String in band_keys:
			if examined_pairs >= MAX_PAIRED_RELIEF_PAIR_CHECKS:
				break
			var records := records_by_band[band_key] as Array[Dictionary]
			# Spend the bounded pair budget on the visually fatal, exact-interface
			# locks first. A court-facing middle storey may have a valid shape only if
			# its party-wall neighbor moves in the same transaction; lexical parcel
			# order must not decide whether that repair is ever examined.
			records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if int(a.exact_interface_priority) \
						!= int(b.exact_interface_priority):
					return int(a.exact_interface_priority) \
						> int(b.exact_interface_priority)
				return String(a.key) < String(b.key))
			for left_index in records.size():
				if examined_pairs >= MAX_PAIRED_RELIEF_PAIR_CHECKS:
					break
				var left := records[left_index] as Dictionary
				for right_index in range(left_index + 1, records.size()):
					if examined_pairs >= MAX_PAIRED_RELIEF_PAIR_CHECKS:
						break
					var right := records[right_index] as Dictionary
					if left.lineage_id == right.lineage_id \
							or _minimum_column_distance(
								(left.current as Dictionary).columns as Dictionary,
								(right.current as Dictionary).columns as Dictionary) \
									> MAX_PAIRED_RELIEF_COLUMN_DISTANCE:
						continue
					var pair_ids := PackedStringArray([
						String(left.key), String(right.key)])
					pair_ids.sort()
					var pair_key := "|".join(pair_ids)
					if seen_pair_keys.has(pair_key):
						continue
					seen_pair_keys[pair_key] = true
					examined_pairs += 1
					var participant_ids: Dictionary = {
						StringName(left.lineage_id): true,
						StringName(right.lineage_id): true,
					}
					var free_claims := claimed_cells.duplicate()
					for participant: Dictionary in [left, right]:
						var participant_id := StringName(participant.lineage_id)
						for cell: Vector3i in (participant.current \
								as Dictionary).cells as Array[Vector3i]:
							if free_claims.get(cell, &"") == participant_id:
								free_claims.erase(cell)
					var left_variants := _coupled_variants(grid,
						protected_owners, free_claims, participant_ids,
						left, world_seed ^ 0x39a75b1, false, true)
					var right_variants := _coupled_variants(grid,
						protected_owners, free_claims, participant_ids,
						right, world_seed ^ 0x6d2b79f, false, true)
					var before := _combined_vertical_profile_metric(
						left.current as Dictionary,
						left.previous as Dictionary,
						left.next as Dictionary,
						right.current as Dictionary,
						right.previous as Dictionary,
						right.next as Dictionary)
					var best_pair: Dictionary = {}
					var disjoint_pair_count := 0
					var borne_pair_count := 0
					var seam_crossing_pair_count := 0
					var improved_pair_count := 0
					for left_variant: Dictionary in left_variants:
						for right_variant: Dictionary in right_variants:
							if _intersection_size(
									left_variant.columns as Dictionary,
									right_variant.columns as Dictionary) > 0:
								continue
							disjoint_pair_count += 1
							var left_trial := _coupled_replacement(
								left.current as Dictionary, left_variant)
							var right_trial := _coupled_replacement(
								right.current as Dictionary, right_variant)
							var joint_claims := free_claims.duplicate()
							for trial_entry: Dictionary in [left_trial, right_trial]:
								for trial_cell: Vector3i in trial_entry.cells:
									joint_claims[trial_cell] = true
							if not _floorplate_transition_is_structurally_legible(
									left_variant.columns as Dictionary,
									(left.previous as Dictionary).columns as Dictionary,
									((left.current as Dictionary).origin as Vector3i).y,
									joint_claims, grid) \
								or not _floorplate_transition_is_structurally_legible(
									right_variant.columns as Dictionary,
									(right.previous as Dictionary).columns as Dictionary,
									((right.current as Dictionary).origin as Vector3i).y,
									joint_claims, grid):
								continue
							if not _paired_upper_continuation_is_borne(grid,
									left.next as Dictionary, left_variant,
									joint_claims) \
									or not _paired_upper_continuation_is_borne(grid,
										right.next as Dictionary, right_variant,
										joint_claims):
								continue
							borne_pair_count += 1
							var crosses_old_seam := _intersection_size(
								left_variant.columns as Dictionary,
								(right.current as Dictionary).columns \
									as Dictionary) > 0 \
								or _intersection_size(
									right_variant.columns as Dictionary,
									(left.current as Dictionary).columns \
										as Dictionary) > 0
							if not crosses_old_seam:
								continue
							seam_crossing_pair_count += 1
							# Variants already contain every field the profile metric
							# reads. Do not stamp full cell arrays for all 18x18
							# combinations; only the one surviving pair receives a
							# complete measured record below.
							var after := _combined_vertical_profile_metric(
								left_variant,
								left.previous as Dictionary,
								left.next as Dictionary,
								right_variant,
								right.previous as Dictionary,
								right.next as Dictionary)
							if not _vertical_profile_is_better(after, before):
								continue
							improved_pair_count += 1
							var tie := posmod(Helper._mix64(world_seed \
								^ String(left.key).hash() * 31 \
								^ String(right.key).hash() * 47 \
								^ String(left_variant.kind).hash() * 59 \
								^ String(right_variant.kind).hash() * 71 \
								^ sweep * 0x45d9f3b), 1000003)
							var pair_candidate := {"left": left, "right": right,
								"left_variant": left_variant,
								"right_variant": right_variant,
								"before": before, "after": after, "tie": tie}
							if best_pair.is_empty() or \
									_paired_relief_candidate_is_better(
										pair_candidate, best_pair):
								best_pair = pair_candidate
					if diagnostic_trace:
						traced_pairs.append({"pair": pair_key,
							"priority": maxi(int(left.exact_interface_priority),
								int(right.exact_interface_priority)),
							"left_variant_count": left_variants.size(),
							"right_variant_count": right_variants.size(),
							"disjoint_pair_count": disjoint_pair_count,
							"borne_pair_count": borne_pair_count,
							"seam_crossing_pair_count": seam_crossing_pair_count,
							"improved_pair_count": improved_pair_count})
					if not best_pair.is_empty():
						candidates.append(best_pair)
						if candidates.size() > MAX_PAIRED_RELIEF_FRONTIER:
							candidates.sort_custom(func(a: Dictionary,
									b: Dictionary) -> bool:
								return _paired_relief_candidate_is_better(a, b))
							candidates.resize(MAX_PAIRED_RELIEF_FRONTIER)
						peak_frontier = maxi(peak_frontier,
							candidates.size())
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _paired_relief_candidate_is_better(a, b))
		var used_records: Dictionary = {}
		var changed := 0
		for candidate: Dictionary in candidates:
			var left := candidate.left as Dictionary
			var right := candidate.right as Dictionary
			if used_records.has(String(left.key)) \
					or used_records.has(String(right.key)):
				continue
			var left_id := StringName(left.lineage_id)
			var right_id := StringName(right.lineage_id)
			var left_lineage := lineages[left_id] as Dictionary
			var right_lineage := lineages[right_id] as Dictionary
			var left_blocks := left_lineage.blocks as Array[Dictionary]
			var right_blocks := right_lineage.blocks as Array[Dictionary]
			var left_position := _block_position(left_blocks,
				int(left.source_block_index))
			var right_position := _block_position(right_blocks,
				int(right.source_block_index))
			if left_position < 1 or right_position < 1:
				continue
			var left_current := left_blocks[left_position] as Dictionary
			var right_current := right_blocks[right_position] as Dictionary
			if not _same_set(left_current.columns as Dictionary,
					(left.current as Dictionary).columns as Dictionary) \
					or not _same_set(right_current.columns as Dictionary,
						(right.current as Dictionary).columns as Dictionary):
				continue
			var free_claims := claimed_cells.duplicate()
			for old_record: Dictionary in [left_current, right_current]:
				var old_id := left_id if old_record == left_current else right_id
				for cell: Vector3i in old_record.cells:
					if free_claims.get(cell, &"") == old_id:
						free_claims.erase(cell)
			var left_replacement := _coupled_replacement(left_current,
				candidate.left_variant as Dictionary)
			var right_replacement := _coupled_replacement(right_current,
				candidate.right_variant as Dictionary)
			if _record_overlaps_claimed(left_replacement, free_claims) \
					or _record_overlaps_claimed(right_replacement, free_claims) \
					or _intersection_size(
						left_replacement.columns as Dictionary,
						right_replacement.columns as Dictionary) > 0:
				continue
			var left_previous := left_blocks[left_position - 1] as Dictionary
			var left_next := left_blocks[left_position + 1] as Dictionary \
				if left_position + 1 < left_blocks.size() else {}
			var right_previous := right_blocks[right_position - 1] as Dictionary
			var right_next := right_blocks[right_position + 1] as Dictionary \
				if right_position + 1 < right_blocks.size() else {}
			var before := _combined_vertical_profile_metric(left_current,
				left_previous, left_next, right_current, right_previous,
				right_next)
			var after := _combined_vertical_profile_metric(left_replacement,
				left_previous, left_next, right_replacement, right_previous,
				right_next)
			if not _vertical_profile_is_better(after, before):
				continue
			for old_record: Dictionary in [left_current, right_current]:
				var old_id := left_id if old_record == left_current else right_id
				for cell: Vector3i in old_record.cells:
					if claimed_cells.get(cell, &"") == old_id:
						claimed_cells.erase(cell)
			left_replacement["paired_registration_relief"] = true
			right_replacement["paired_registration_relief"] = true
			left_blocks[left_position] = left_replacement
			right_blocks[right_position] = right_replacement
			left_lineage["blocks"] = left_blocks
			right_lineage["blocks"] = right_blocks
			lineages[left_id] = left_lineage
			lineages[right_id] = right_lineage
			for record: Dictionary in [left_replacement, right_replacement]:
				var owner_id := left_id if record == left_replacement else right_id
				for cell: Vector3i in record.cells:
					claimed_cells[cell] = owner_id
			used_records[String(left.key)] = true
			used_records[String(right.key)] = true
			changed += 1
			accepted += 1
		if changed == 0:
			break
	last_pair_diagnostic = {
		"examined_pair_count": examined_pairs,
		"peak_frontier_count": peak_frontier,
		"accepted_pair_count": accepted,
	}
	if diagnostic_trace:
		last_pair_diagnostic["traced_pairs"] = traced_pairs
	return accepted


static func _paired_relief_candidate_is_better(a: Dictionary,
		b: Dictionary) -> bool:
	for key: String in ["strong_registration_count",
			"registered_facade_plane_count", "same_kind_count",
			"same_ridge_axis_count"]:
		var a_gain := int((a.before as Dictionary)[key]) \
			- int((a.after as Dictionary)[key])
		var b_gain := int((b.before as Dictionary)[key]) \
			- int((b.after as Dictionary)[key])
		if a_gain != b_gain:
			return a_gain > b_gain
	return int(a.tie) < int(b.tie)


static func _paired_upper_continuation_is_borne(grid: WarrenSpatialGrid,
		next: Dictionary, replacement: Dictionary,
		claimed_cells: Dictionary) -> bool:
	if next.is_empty():
		return true
	return _new_projection_is_directly_borne(grid,
		next.columns as Dictionary, replacement.columns as Dictionary,
		(next.origin as Vector3i).y, claimed_cells)


static func _combined_vertical_profile_metric(left: Dictionary,
		left_previous: Dictionary, left_next: Dictionary,
		right: Dictionary, right_previous: Dictionary,
		right_next: Dictionary) -> Dictionary:
	var left_metric := _vertical_profile_metric(left, left_previous, left_next)
	var right_metric := _vertical_profile_metric(right, right_previous,
		right_next)
	var out: Dictionary = {}
	for key: String in ["strong_registration_count",
			"registered_facade_plane_count", "same_kind_count",
			"same_ridge_axis_count"]:
		out[key] = int(left_metric[key]) + int(right_metric[key])
	return out


static func _variant_replacement(current: Dictionary,
		variant: Dictionary) -> Dictionary:
	var replacement := current.duplicate(true)
	var stamped := _record(StringName(variant.kind),
		variant.origin as Vector3i, int(variant.yaw_quarters),
		int(current.start_storey), int(current.end_storey))
	for key: String in ["kind", "origin", "yaw_quarters", "columns", "cells"]:
		replacement[key] = stamped[key]
	replacement["merged"] = false
	replacement["expanded"] = bool(variant.get("expanded", false))
	replacement["registration_relief"] = true
	return replacement


static func _vertical_profile_metric(current: Dictionary,
		previous: Dictionary, next: Dictionary) -> Dictionary:
	var registration := _candidate_vertical_registration(
		current.columns as Dictionary, previous, next)
	var same_kind := 0
	var same_axis := 0
	for adjacent: Dictionary in [previous, next]:
		if adjacent.is_empty():
			continue
		same_kind += int(StringName(current.kind) == StringName(adjacent.kind))
		same_axis += int(posmod(int(current.yaw_quarters), 2) \
			== posmod(int(adjacent.yaw_quarters), 2))
	return {
		"strong_registration_count": int(
			registration.strong_registration_count),
		"registered_facade_plane_count": int(
			registration.registered_facade_plane_count),
		"same_kind_count": same_kind,
		"same_ridge_axis_count": same_axis,
	}


static func _vertical_profile_is_better(candidate: Dictionary,
		current: Dictionary) -> bool:
	for key: String in ["strong_registration_count",
			"registered_facade_plane_count", "same_kind_count",
			"same_ridge_axis_count"]:
		if int(candidate[key]) != int(current[key]):
			return int(candidate[key]) < int(current[key])
	return false


static func _lineage_overlap_audit(lineages: Dictionary) -> Dictionary:
	var owner_by_cell: Dictionary = {}
	var overlap_cells: Dictionary = {}
	var conflicts: Array[Dictionary] = []
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var lineage := lineages[lineage_id] as Dictionary
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				if not owner_by_cell.has(cell):
					owner_by_cell[cell] = lineage_id
					continue
				var prior := StringName(owner_by_cell[cell])
				if prior == lineage_id:
					continue
				overlap_cells[cell] = true
				if conflicts.size() < 12:
					conflicts.append({"cell": cell, "left": prior,
						"right": lineage_id})
	return {"overlap_cell_count": overlap_cells.size(),
		"conflicts": conflicts}


static func _volumetric_variant_stamp(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		lineage_id: StringName, current: Dictionary, previous: Dictionary,
		next: Dictionary, block_index: int, world_seed: int,
		allow_tower_promotion: bool = true) -> Dictionary:
	var current_columns := current.columns as Dictionary
	var previous_columns := previous.columns as Dictionary
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in current_columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var candidates: Array[Dictionary] = []
	var shape_count := 0
	var constraint_match_count := 0
	var bearing_match_count := 0
	var upper_match_count := 0
	var clear_count := 0
	var clearance_failures: Array[Dictionary] = []
	for kind: StringName in ROOM_KINDS:
		if not allow_tower_promotion and kind == &"tower" \
				and StringName(current.kind) != &"tower":
			continue
		for yaw in 4:
			for x in range(minimum.x - 4, maximum.x + 5):
				for z in range(minimum.y - 4, maximum.y + 5):
					var origin := Vector3i(x, (current.origin as Vector3i).y, z)
					var columns := _stamp_columns(kind, origin, yaw)
					if columns.is_empty() or _same_set(columns, current_columns):
						continue
					# Origin/yaw pairs can differ while an even-cell stamp occupies
					# exactly the same world columns. Reject in world space: accepting
					# that coordinate illusion recreated the vertical tower this pass
					# exists to remove.
					if _same_set(columns, previous_columns) \
							or not next.is_empty() and _same_set(columns,
								next.columns as Dictionary):
						continue
					shape_count += 1
					if not _candidate_matches_constraints(kind, origin, yaw,
							current):
						continue
					constraint_match_count += 1
					var lower_overlap := _intersection_size(columns,
						previous_columns)
					if lower_overlap < _required_bearing_overlap(columns):
						continue
					bearing_match_count += 1
					var upper_overlap := 0
					if not next.is_empty():
						upper_overlap = _intersection_size(columns,
							next.columns as Dictionary)
						if upper_overlap <= 0:
							continue
					upper_match_count += 1
					var trial := _record(kind, origin, yaw,
						int(current.start_storey), int(current.end_storey))
					if trial.is_empty() or not _record_is_clear_for_lineage(grid,
							protected_owners, claimed_cells, trial, lineage_id) \
							or not _new_projection_has_clearance(trial,
								current_columns, protected_owners, claimed_cells,
								{StringName(lineage_id): true}):
						if _block_has_interface_constraint(current) \
								and clearance_failures.size() < 6:
							clearance_failures.append({"kind": kind,
								"origin": origin, "yaw": yaw,
								"failure": _record_clearance_failure(grid,
									protected_owners, claimed_cells, trial,
									lineage_id)})
						continue
					clear_count += 1
					var old_inside_new := _intersection_size(columns,
						current_columns)
					var expanded := not _is_subset(columns, current_columns)
					var tower_relief := int(StringName(current.kind) == &"tower" \
						and kind != &"tower")
					var kind_change := int(kind != StringName(current.kind))
					var difference := _symmetric_difference_size(columns,
						current_columns)
					# A slim or building room is a more plausible tower cap than a
					# full long hall. Long rooms remain available where the residual
					# massif genuinely supports them.
					var cap_scale_bonus := 180 if kind == &"slim" \
						else 120 if kind == &"building" else 20
					var repetition_cost := _vertical_repetition_cost(kind, yaw,
						columns, previous) + _vertical_repetition_cost(kind, yaw,
						columns, next)
					var registration := _candidate_vertical_registration(
						columns, previous, next)
					var score := tower_relief * 6000 + kind_change * 1800 \
						+ int(expanded) * 900 + cap_scale_bonus \
						+ difference * 45 + lower_overlap * 25 \
						+ upper_overlap * 18 + old_inside_new * 6 \
						- maxi(columns.size() - 16, 0) * 30 \
						- repetition_cost
					var tie := posmod(Helper._mix64(world_seed \
						^ String(lineage_id).hash() * 31 \
						^ block_index * 0x45d9f3b ^ kind.hash() * 47 \
						^ x * 73856093 ^ z * 19349663 ^ yaw * 83492791),
						1000003)
					candidates.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"expanded": expanded, "score": score,
						"tower_relief": tower_relief,
						"strong_registration_count": int(
							registration.strong_registration_count),
						"registered_facade_plane_count": int(
							registration.registered_facade_plane_count),
						"tie": tie})
	if _block_has_interface_constraint(current):
		last_variant_diagnostic["%s/%d" % [lineage_id, block_index]] = {
			"shape_count": shape_count,
			"constraint_match_count": constraint_match_count,
			"bearing_match_count": bearing_match_count,
			"upper_match_count": upper_match_count,
			"clear_count": clear_count,
			"candidate_count": candidates.size(),
			"clearance_failures": clearance_failures,
		}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tower_relief) != int(b.tower_relief):
			return int(a.tower_relief) > int(b.tower_relief)
		if int(a.strong_registration_count) \
				!= int(b.strong_registration_count):
			return int(a.strong_registration_count) \
				< int(b.strong_registration_count)
		if int(a.registered_facade_plane_count) \
				!= int(b.registered_facade_plane_count):
			return int(a.registered_facade_plane_count) \
				< int(b.registered_facade_plane_count)
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	for candidate_index in mini(candidates.size(),
			MAX_STRUCTURAL_VARIANT_FRONTIER):
		var candidate := candidates[candidate_index] as Dictionary
		if _floorplate_transition_is_structurally_legible(
				candidate.columns as Dictionary, previous_columns,
				(current.origin as Vector3i).y, claimed_cells, grid):
			return candidate
	return {}


static func _record_clearance_failure(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		record: Dictionary, lineage_id: StringName) -> Dictionary:
	for cell: Vector3i in record.get("cells", []) as Array[Vector3i]:
		if not grid.contains(cell):
			return {"cell": cell, "reason": &"outside_grid"}
		if grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
				WarrenSpatialGrid.Use.OUTSIDE]:
			return {"cell": cell, "reason": &"occupied_use",
				"use": grid.use_at(cell),
				"owner": grid.owner_name_at(cell)}
		if claimed_cells.has(cell) and claimed_cells[cell] != lineage_id:
			return {"cell": cell, "reason": &"composed_claim",
				"owner": claimed_cells[cell]}
		var owners := protected_owners.get(cell, {}) as Dictionary
		for owner_value: Variant in owners.keys():
			var owner_id := StringName(owner_value)
			if owner_id == lineage_id:
				continue
			var allowance: Variant = owners[owner_value]
			if allowance is Dictionary \
					and (allowance as Dictionary).has(lineage_id):
				continue
			return {"cell": cell, "reason": &"protected_owner",
				"owner": owner_id}
	return {"reason": &"unknown"}


static func _new_projection_has_clearance(record: Dictionary,
		source_columns: Dictionary, protected_owners: Dictionary,
		claimed_cells: Dictionary, allowed_owner_ids: Dictionary) -> bool:
	## Cell overlap and hero-feature reservations are proven by the exact grid
	## checks immediately before this call. Neighbor distance is not clearance:
	## dense cardinal contact becomes a typed PARTY_WALL, while diagonal/eave
	## compatibility is decided later from the actual selected recipe envelopes.
	## A blanket fine-cell halo (1.5 m) erased the negative-space street fabric
	## and made the only legal upper construction a repeated vertical shaft.
	return true


static func _candidate_matches_address(kind: StringName, origin: Vector3i,
		yaw: int, current: Dictionary) -> bool:
	var threshold := current.get("address_threshold",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var frontage := current.get("address_frontage", Vector3i.ZERO) as Vector3i
	if threshold.x == 2147483647:
		return false
	# Generated room recipes own two measured door phases on the same facade.
	# Recomposition must accept both: forcing phase zero here kept an addressed
	# narrow room registered vertically even when shifting it one fine cell would
	# preserve the exact public threshold and select the authored phase-one shell.
	var addressed_origin := Vector3i(origin.x, threshold.y, origin.z)
	return WarrenParcelConstruction.address_door_phase_for_room(kind,
		addressed_origin, yaw, threshold, frontage) >= 0


static func _block_allows_recomposition(block: Dictionary) -> bool:
	return bool(block.get("address_expandable", false)) \
		or bool(block.get("bearing_forced", false)) \
		or not (block.get("feature_endpoint_constraints", []) as Array).is_empty() \
		or not (block.get("court_contact_columns", {}) as Dictionary).is_empty()


static func _block_has_interface_constraint(block: Dictionary) -> bool:
	return bool(block.get("address_expandable", false)) \
		or not (block.get("feature_endpoint_constraints", []) as Array).is_empty() \
		or not (block.get("court_contact_columns", {}) as Dictionary).is_empty()


static func _candidate_matches_constraints(kind: StringName,
		origin: Vector3i, yaw: int, current: Dictionary) -> bool:
	if bool(current.get("address_expandable", false)) \
			and not _candidate_matches_address(kind, origin, yaw, current):
		return false
	var constraints := current.get("feature_endpoint_constraints", []) as Array
	for constraint_value: Variant in constraints:
		var constraint := constraint_value as Dictionary
		if not _candidate_has_facade_endpoint(kind, origin, yaw,
				constraint.cell as Vector3i,
				constraint.facing as Vector3i):
			return false
	var candidate_columns := _stamp_columns(kind, origin, yaw)
	for column_value: Variant in (current.get("court_contact_columns", {}) \
			as Dictionary).keys():
		if not candidate_columns.has(column_value):
			return false
	return true


static func _candidate_has_facade_endpoint(kind: StringName,
		origin: Vector3i, yaw: int, endpoint: Vector3i,
		facing: Vector3i) -> bool:
	var x_radius := 0
	var z_radius := 0
	match kind:
		&"tower":
			x_radius = 1
			z_radius = 1
		&"slim":
			x_radius = 1
			z_radius = 2
		&"building":
			x_radius = 2
			z_radius = 2
		&"long":
			x_radius = 2
			z_radius = 3
		_:
			return false
	# Authored room recipes expose one non-corner socket at the centre of each
	# facade.  Preserving an arbitrary perimeter cell is insufficient: the
	# compiled bridge would then have no legal room/bearing bond even though its
	# logical endpoint still touched private volume.
	var local_facing := FabricRecipe.transform_direction(facing, -yaw)
	var local_cell := Vector3i.ZERO
	match local_facing:
		Vector3i.LEFT:
			local_cell = Vector3i(-x_radius, 0, 0)
		Vector3i.RIGHT:
			local_cell = Vector3i(x_radius - 1, 0, 0)
		Vector3i.FORWARD:
			local_cell = Vector3i(0, 0, -z_radius)
		Vector3i.BACK:
			local_cell = Vector3i(0, 0, z_radius - 1)
		_:
			return false
	var cell_origin := Vector3i(origin.x, endpoint.y, origin.z)
	return FabricRecipe.transform_cell(local_cell, cell_origin, yaw) == endpoint


static func _record_is_clear_for_lineage(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		record: Dictionary, lineage_id: StringName) -> bool:
	for cell: Vector3i in record.cells:
		if not grid.contains(cell) \
				or grid.use_at(cell) not in [WarrenSpatialGrid.Use.ALLOCATABLE,
					WarrenSpatialGrid.Use.OUTSIDE]:
			return false
		if claimed_cells.has(cell) and claimed_cells[cell] != lineage_id:
			return false
		var owners := protected_owners.get(cell, {}) as Dictionary
		for owner_value: Variant in owners.keys():
			var owner_id := StringName(owner_value)
			if owner_id == lineage_id:
				continue
			var allowance: Variant = owners[owner_value]
			if allowance is Dictionary \
					and (allowance as Dictionary).has(lineage_id):
				continue
			return false
	return true


static func _truncate_unpaired_towers(lineages: Dictionary) -> int:
	var truncated := 0
	for id_value: Variant in lineages.keys():
		var lineage_id := StringName(id_value)
		var lineage := lineages[lineage_id] as Dictionary
		if bool(lineage.paired_primary) or bool(lineage.paired_secondary):
			continue
		var blocks := lineage.blocks as Array[Dictionary]
		var storeys := _lineage_storey_count(blocks)
		if storeys <= MAX_UNPAIRED_TOWER_STOREYS \
				or int(lineage.required_through_block) \
					>= MAX_UNPAIRED_TOWER_STOREYS \
				or not _lineage_is_tower_only(blocks):
			continue
		# Source records used to span two storeys, so this comparison divided the
		# retained height by two. Records are now one storey each: a forced second
		# storey has index 1 and is fully preserved by the two-storey cap, while a
		# genuinely required third storey has index 2 and must prevent truncation.
		while not blocks.is_empty() \
				and int((blocks[-1] as Dictionary).start_storey) \
					>= MAX_UNPAIRED_TOWER_STOREYS:
			blocks.pop_back()
		var retained := _lineage_storey_count(blocks)
		truncated += storeys - retained
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
	return truncated


static func _truncate_registered_crowns(lineages: Dictionary,
		grid: WarrenSpatialGrid = null) -> Dictionary:
	## Recomposition is preferred: merge neighboring upper rooms, exchange mass,
	## or move one complete room laterally. In dense pockets those moves can all
	## be unavailable. Retaining the untouched optional suffix would turn that
	## failed search into a centered shaft, so terminate it as a real roofline.
	##
	## Only a suffix above the second storey may be removed. Exact interfaces,
	## merged cross-lineage rooms, and records that bear another lineage are hard
	## blockers. This keeps the fallback architectural: it makes a stepped crown
	## from already-qualified mass rather than disguising a tower with props.
	var required_bearers: Dictionary = {}
	for lineage_value: Variant in lineages.values():
		var lineage := lineage_value as Dictionary
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
			var parent_id := StringName(block.get(
				"support_parent_lineage_id", &""))
			if parent_id.is_empty():
				continue
			var parent_block := int(block.get(
				"support_parent_source_block_index", -1))
			if parent_block >= 0:
				required_bearers["%s/%d" % [parent_id, parent_block]] = true
	var ids: Array[StringName] = []
	ids.assign(lineages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var terminated_lineages := 0
	var terminated_storeys := 0
	for lineage_id: StringName in ids:
		var lineage := lineages[lineage_id] as Dictionary
		if bool(lineage.paired_primary) or bool(lineage.paired_secondary):
			continue
		var blocks := lineage.blocks as Array[Dictionary]
		if _lineage_storey_count(blocks) <= MAX_UNPAIRED_TOWER_STOREYS:
			continue
		var cut_position := -1
		for position in range(2, blocks.size()):
			var lower := blocks[position - 1] as Dictionary
			var upper := blocks[position] as Dictionary
			if int(lower.end_storey) != int(upper.start_storey):
				continue
			if _registered_facade_plane_count(
					lower.columns as Dictionary,
					upper.columns as Dictionary) >= 2:
				cut_position = position
				break
		if cut_position < 0:
			continue
		var removable := true
		var removed_storeys := 0
		for position in range(cut_position, blocks.size()):
			var block := blocks[position] as Dictionary
			var source_block_index := int(block.get(
				"source_block_index", position))
			if bool(block.get("forced", false)) \
					or bool(block.get("structural_forced", false)) \
					or bool(block.get("merged", false)) \
					or source_block_index <= int(
						lineage.required_through_block) \
					or required_bearers.has("%s/%d" % [lineage_id,
						source_block_index]):
				removable = false
				break
			removed_storeys += int(block.end_storey) \
				- int(block.start_storey)
		if not removable or removed_storeys <= 0:
			continue
		if not _crown_cut_preserves_bearing(lineages, grid, lineage_id,
				cut_position):
			continue
		blocks.resize(cut_position)
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
		terminated_lineages += 1
		terminated_storeys += removed_storeys
	return {"lineage_count": terminated_lineages,
		"storey_count": terminated_storeys}


static func _crown_cut_preserves_bearing(lineages: Dictionary,
		grid: WarrenSpatialGrid, cut_lineage_id: StringName,
		cut_position: int) -> bool:
	## Cross-lineage bearing is also a geometric fact. A neighboring upper room
	## need not name a formal support parent when the completed partition already
	## gives it enough occupied cells below. Test the actual pre/post volume so a
	## silhouette repair cannot quietly turn that room into a floating block.
	var before_claims := _claimed_room_cells(lineages)
	var after_claims := before_claims.duplicate()
	var cut_lineage := lineages[cut_lineage_id] as Dictionary
	var cut_blocks := cut_lineage.blocks as Array[Dictionary]
	for position in range(cut_position, cut_blocks.size()):
		for cell: Vector3i in (cut_blocks[position] as Dictionary).cells:
			if after_claims.get(cell, &"") == cut_lineage_id:
				after_claims.erase(cell)
	for lineage_id_value: Variant in lineages.keys():
		var lineage_id := StringName(lineage_id_value)
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			if lineage_id == cut_lineage_id and position >= cut_position:
				continue
			if position == 0 and int(block.start_storey) == 0 \
					and not block.has("support_parent_lineage_id"):
				continue
			var was_borne := _floorplate_transition_is_structurally_legible(
				block.columns as Dictionary, {},
				(block.origin as Vector3i).y, before_claims, grid)
			if was_borne and not _floorplate_transition_is_structurally_legible(
					block.columns as Dictionary, {},
					(block.origin as Vector3i).y, after_claims, grid):
				return false
	return true


static func _variant_stamp(allowed: Dictionary, previous: Dictionary,
		y: int, block: int, world_seed: int, lineage_hash: int) -> Dictionary:
	if allowed.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in allowed.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var previous_columns := previous.columns as Dictionary
	for kind: StringName in ROOM_KINDS:
		for yaw in 4:
			for x in range(minimum.x - 3, maximum.x + 4):
				for z in range(minimum.y - 3, maximum.y + 4):
					var origin := Vector3i(x, y, z)
					var columns := _stamp_columns(kind, origin, yaw)
					if columns.is_empty() or not _is_subset(columns, allowed):
						continue
					var overlap := _intersection_size(columns, previous_columns)
					if overlap < maxi(MIN_BEARING_OVERLAP_COLUMNS,
							ceili(float(mini(columns.size(),
							previous_columns.size())) * 0.5)):
						continue
					if _same_set(columns, previous_columns):
						continue
					var difference := _symmetric_difference_size(columns,
						previous_columns)
					var kind_change := int(kind != StringName(previous.kind))
					var target_ratio := 0.67 if posmod(block, 3) == 1 \
						else 0.42 if posmod(block, 3) == 2 else 0.75
					var area_ratio := float(columns.size()) \
						/ float(maxi(allowed.size(), 1))
					var score := kind_change * 1000 + difference * 80 \
						- int(absf(area_ratio - target_ratio) * 300.0) \
						+ columns.size() * 4
					var tie := posmod(Helper._mix64(world_seed ^ lineage_hash \
						^ block * 0x45d9f3b ^ kind.hash() * 31 \
						^ x * 73856093 ^ z * 19349663 ^ yaw * 83492791),
						1000003)
					candidates.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"score": score, "tie": tie})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	return candidates[0]


static func _exact_stamp_for_columns(columns: Dictionary, y: int) -> Dictionary:
	if columns.is_empty():
		return {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	for kind: StringName in ROOM_KINDS:
		for yaw in 4:
			for x in range(minimum.x - 3, maximum.x + 4):
				for z in range(minimum.y - 3, maximum.y + 4):
					var origin := Vector3i(x, y, z)
					var candidate := _stamp_columns(kind, origin, yaw)
					if _same_set(candidate, columns):
						return {"kind": kind, "origin": origin,
							"yaw_quarters": yaw, "columns": candidate}
	return {}


static func _record(kind: StringName, origin: Vector3i, yaw: int,
		start_storey: int, end_storey: int) -> Dictionary:
	var columns := _stamp_columns(kind, origin, yaw)
	if columns.is_empty() or start_storey < 0 or end_storey <= start_storey:
		return {}
	var cells: Array[Vector3i] = []
	for storey in range(start_storey, end_storey):
		var room_origin := Vector3i(origin.x,
			origin.y + (storey - start_storey) \
				* WarrenSpatialGrid.STOREY_CELLS, origin.z)
		cells.append_array(WarrenRoomStamp.expected_private_cells(kind,
			room_origin, yaw))
	return {"kind": kind, "origin": origin, "yaw_quarters": yaw,
		"start_storey": start_storey, "end_storey": end_storey,
		"columns": columns, "cells": cells}


static func _stamp_columns(kind: StringName, origin: Vector3i,
		yaw: int) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in WarrenRoomStamp.expected_private_cells(kind,
		Vector3i(origin.x, 0, origin.z), yaw):
		out[Vector2i(cell.x, cell.z)] = true
	return out


static func _courtyard_neighbor_cells(volume: WarrenVolumePlan) -> Dictionary:
	var floors: Dictionary = {}
	for macro: Vector3i in volume.courtyard_cells:
		for floor: Vector3i in WarrenVolumetricSolver._fine_square(macro):
			floors[floor] = true
	var out: Dictionary = {}
	for floor_value: Variant in floors.keys():
		var floor := floor_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if floors.has(floor + direction):
				continue
			for y_offset in WarrenSpatialGrid.STOREY_CELLS:
				out[floor + direction + Vector3i.UP * y_offset] = true
	return out


static func _audit(lineages: Dictionary, input_storeys: int,
		merged_count: int, coupled_count: int, expanded_count: int,
		truncated_tower_storeys: int) -> Dictionary:
	var output_storeys := 0
	var mixed_tall := 0
	var extruded_tall := 0
	var max_tower_only := 0
	var varied_blocks := 0
	var merged_blocks := 0
	var extruded_ids: Array[StringName] = []
	var tower_only_ids: Array[StringName] = []
	var tall_tower_only_ids: Array[StringName] = []
	var relieved_tall_tower_only_ids: Array[StringName] = []
	var annex_relieved_tall_tower_only_ids: Array[StringName] = []
	var tower_relief_annex_target_by_lineage: Dictionary = {}
	var tall_tower_only_details: Array[Dictionary] = []
	var four_storey_tower_run_ids: Array[StringName] = []
	var four_storey_tower_run_details: Array[Dictionary] = []
	var overlong_tower_run_ids: Array[StringName] = []
	var overlong_tower_run_details: Array[Dictionary] = []
	var max_identical_tower_run := 0
	var consecutive_floorplate_pair_count := 0
	var registered_facade_plane_count := 0
	var strongly_registered_floorplate_pair_count := 0
	var same_kind_floorplate_pair_count := 0
	var same_ridge_axis_floorplate_pair_count := 0
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		var storeys := _lineage_storey_count(blocks)
		output_storeys += storeys
		var kinds: Dictionary = {}
		for block_index in blocks.size():
			var block := blocks[block_index] as Dictionary
			kinds[StringName(block.kind)] = true
			varied_blocks += int(StringName(block.kind) \
				!= StringName(block.original_kind) \
				or block.origin != block.original_origin \
				or int(block.yaw_quarters) \
					!= int(block.original_yaw_quarters))
			merged_blocks += int(bool(block.merged))
			if block_index <= 0:
				continue
			var previous := blocks[block_index - 1] as Dictionary
			if int(previous.end_storey) != int(block.start_storey):
				continue
			var registered := _registered_facade_plane_count(
				previous.columns as Dictionary, block.columns as Dictionary)
			consecutive_floorplate_pair_count += 1
			registered_facade_plane_count += registered
			strongly_registered_floorplate_pair_count += int(registered >= 2)
			same_kind_floorplate_pair_count += int(StringName(previous.kind) \
				== StringName(block.kind))
			same_ridge_axis_floorplate_pair_count += int(
				posmod(int(previous.yaw_quarters), 2) \
				== posmod(int(block.yaw_quarters), 2))
		if storeys >= TALL_LINEAGE_STOREYS and kinds.size() > 1:
			mixed_tall += 1
		if storeys >= EXTRUDED_LINEAGE_STOREYS \
				and _lineage_is_repeated_extrusion(blocks) \
				and not bool(lineage.paired_primary) \
				and not bool(lineage.paired_secondary):
			extruded_tall += 1
			extruded_ids.append(lineage_id)
		if _lineage_is_tower_only(blocks) \
				and not bool(lineage.paired_primary) \
				and not bool(lineage.paired_secondary):
			max_tower_only = maxi(max_tower_only, storeys)
			tower_only_ids.append(lineage_id)
			var identical_run := _longest_identical_floorplate_run(blocks)
			# A complete three-storey narrow house can be structurally valid yet
			# still read as a tower at village scale. It receives one occupied,
			# roofed side-room event even when its top room has shifted. Taller
			# shafts retain the stronger two-annex repair below.
			if storeys == TALL_LINEAGE_STOREYS - 1:
				tower_relief_annex_target_by_lineage[lineage_id] = \
					THREE_STOREY_TOWER_ANNEXES
			if storeys >= TALL_LINEAGE_STOREYS:
				var relief_transition_count := \
					_silhouette_relief_transition_count(blocks)
				var transition_count := _contiguous_transition_count(blocks)
				var is_silhouette_relieved := relief_transition_count >= 1 \
					and identical_run <= MAX_UNPAIRED_TOWER_STOREYS
				if is_silhouette_relieved:
					relieved_tall_tower_only_ids.append(lineage_id)
				else:
					tower_relief_annex_target_by_lineage[lineage_id] = \
						TALL_TOWER_ANNEXES
					# Dense exact feature sockets can pin an otherwise repeated
					# shaft more tightly than the room-only pass can move it. Such a
					# lineage is not accepted undecorated: it receives a hard quota
					# of occupied, roofed room annexes below. The feature transaction
					# rejects the complete town if even one annex cannot seal, so this
					# is an architectural relief contract rather than a cosmetic
					# waiver of the anti-tower rule.
					annex_relieved_tall_tower_only_ids.append(lineage_id)
				var block_details: Array[Dictionary] = []
				for block: Dictionary in blocks:
					block_details.append({
						"storey": int(block.source_block_index),
						"origin": block.origin,
						"forced": bool(block.forced),
						"address_expandable": bool(block.get(
							"address_expandable", false)),
						"feature_endpoint_count": (block.get(
							"feature_endpoint_constraints", []) as Array).size(),
						"support_parent": StringName(block.get(
							"support_parent_lineage_id", &"")),
					})
				tall_tower_only_details.append({
					"lineage_id": lineage_id,
					"silhouette_relieved": is_silhouette_relieved,
					"relief_transition_count": relief_transition_count,
					"transition_count": transition_count,
					"required_through_block": int(
						lineage.required_through_block),
					"blocks": block_details,
				})
			max_identical_tower_run = maxi(max_identical_tower_run,
				identical_run)
			if identical_run > MAX_IDENTICAL_TOWER_FLOORPLATE_RUN_STOREYS:
				overlong_tower_run_ids.append(lineage_id)
				var overlong_blocks: Array[Dictionary] = []
				for block: Dictionary in blocks:
					overlong_blocks.append({"source_block_index": int(
						block.source_block_index), "start": int(block.start_storey),
						"end": int(block.end_storey), "forced": bool(block.forced),
						"address_expandable": bool(block.get(
							"address_expandable", false)), "origin": block.origin})
				overlong_tower_run_details.append({"lineage_id": lineage_id,
					"identical_run": identical_run,
					"required_through_block": int(lineage.required_through_block),
					"blocks": overlong_blocks})
			if identical_run >= 4:
				four_storey_tower_run_ids.append(lineage_id)
				var block_details: Array[Dictionary] = []
				for block: Dictionary in blocks:
					block_details.append({"source_block_index": int(
						block.source_block_index), "start": int(block.start_storey),
						"end": int(block.end_storey), "forced": bool(block.forced),
						"address_expandable": bool(block.get(
							"address_expandable", false)), "origin": block.origin})
				four_storey_tower_run_details.append({"lineage_id": lineage_id,
					"required_through_block": int(lineage.required_through_block),
					"blocks": block_details})
	return {
		"source_composition_lineage_count": lineages.size(),
		"input_room_storey_count": input_storeys,
		"output_room_storey_count": output_storeys,
		"merged_upper_composition_count": merged_count,
		"coupled_upper_composition_count": coupled_count,
		"expanded_upper_composition_count": expanded_count,
		"upper_recomposition_count": merged_count + coupled_count * 2 \
			+ expanded_count,
		"merged_upper_room_block_count": merged_blocks,
		"varied_room_block_count": varied_blocks,
		"mixed_kind_tall_lineage_count": mixed_tall,
		"extruded_tall_lineage_count": extruded_tall,
		"extruded_tall_lineage_ids": extruded_ids,
		"max_tower_only_lineage_storeys": max_tower_only,
		"tower_only_lineage_ids": tower_only_ids,
		"tall_tower_only_lineage_ids": tall_tower_only_ids,
		"relieved_tall_tower_only_lineage_ids": \
			relieved_tall_tower_only_ids,
		"annex_relieved_tall_tower_only_lineage_ids": \
			annex_relieved_tall_tower_only_ids,
		"tower_relief_annex_target_by_lineage": \
			tower_relief_annex_target_by_lineage,
		"tall_tower_only_lineage_details": tall_tower_only_details,
		"four_storey_tower_run_lineage_ids": four_storey_tower_run_ids,
		"four_storey_tower_run_details": four_storey_tower_run_details,
		"overlong_tower_run_lineage_ids": overlong_tower_run_ids,
		"overlong_tower_run_details": overlong_tower_run_details,
		"max_identical_tower_floorplate_run_storeys": \
			max_identical_tower_run,
		"truncated_tower_storey_count": truncated_tower_storeys,
		"consecutive_floorplate_pair_count": consecutive_floorplate_pair_count,
		"registered_facade_plane_count": registered_facade_plane_count,
		"strongly_registered_floorplate_pair_count": \
			strongly_registered_floorplate_pair_count,
		"same_kind_floorplate_pair_count": same_kind_floorplate_pair_count,
		"same_ridge_axis_floorplate_pair_count": \
			same_ridge_axis_floorplate_pair_count,
	}


static func _lineage_storey_count(blocks: Array[Dictionary]) -> int:
	var count := 0
	for block: Dictionary in blocks:
		count += int(block.end_storey) - int(block.start_storey)
	return count


static func _lineage_is_tower_only(blocks: Array[Dictionary]) -> bool:
	if blocks.is_empty():
		return false
	for block: Dictionary in blocks:
		if StringName(block.kind) != &"tower":
			return false
	return true


static func _lineage_is_repeated_extrusion(blocks: Array[Dictionary]) -> bool:
	if blocks.size() < 2:
		return false
	var first := blocks[0] as Dictionary
	var first_columns := first.columns as Dictionary
	for block_index in range(1, blocks.size()):
		var block := blocks[block_index] as Dictionary
		if StringName(block.kind) != StringName(first.kind) \
				or not _same_set(block.columns as Dictionary, first_columns):
			return false
	return true


static func _longest_identical_floorplate_run(blocks: Array[Dictionary]) -> int:
	var longest := 0
	var run := 0
	var previous_columns: Dictionary = {}
	for block: Dictionary in blocks:
		var columns := block.columns as Dictionary
		var storeys := int(block.end_storey) - int(block.start_storey)
		if not previous_columns.is_empty() \
				and _same_set(columns, previous_columns):
			run += storeys
		else:
			run = storeys
		longest = maxi(longest, run)
		previous_columns = columns
	return longest


static func _registered_facade_plane_count(left: Dictionary,
		right: Dictionary) -> int:
	## Count exact world-space facade planes retained across a vertical room
	## transition. Two rectangles can have different areas and therefore evade
	## the old identical-floorplate audit while still sharing both street-facing
	## planes, which reads as one extruded tower from that axis. Bounding planes
	## are the relevant silhouette fact; internal party-wall cells are not.
	if left.is_empty() or right.is_empty():
		return 0
	var left_min := Vector2i(2147483647, 2147483647)
	var left_max := Vector2i(-2147483648, -2147483648)
	for value: Variant in left.keys():
		var column := value as Vector2i
		left_min = left_min.min(column)
		left_max = left_max.max(column)
	var right_min := Vector2i(2147483647, 2147483647)
	var right_max := Vector2i(-2147483648, -2147483648)
	for value: Variant in right.keys():
		var column := value as Vector2i
		right_min = right_min.min(column)
		right_max = right_max.max(column)
	return int(left_min.x == right_min.x) + int(left_max.x == right_max.x) \
		+ int(left_min.y == right_min.y) + int(left_max.y == right_max.y)


static func _contiguous_transition_count(blocks: Array[Dictionary]) -> int:
	var count := 0
	for block_index in range(1, blocks.size()):
		var lower := blocks[block_index - 1] as Dictionary
		var upper := blocks[block_index] as Dictionary
		count += int(int(lower.end_storey) == int(upper.start_storey))
	return count


static func _silhouette_relief_transition_count(
		blocks: Array[Dictionary]) -> int:
	## A small room family is not automatically a vertical tower. A complete
	## upper room shifted far enough to release at least two of the lower room's
	## four facade planes is a whole-room outcropping/setback in the actual
	## occupied volume. One such break is sufficient only when no floorplate then
	## repeats for three storeys; this admits a deliberate 2+2 stepped house while
	## retaining the hard rejection of a shaft with a token cap offset.
	var count := 0
	for block_index in range(1, blocks.size()):
		var lower := blocks[block_index - 1] as Dictionary
		var upper := blocks[block_index] as Dictionary
		if int(lower.end_storey) != int(upper.start_storey):
			continue
		var lower_columns := lower.columns as Dictionary
		var upper_columns := upper.columns as Dictionary
		if not _same_set(lower_columns, upper_columns) \
				and _registered_facade_plane_count(lower_columns,
					upper_columns) <= 2:
			count += 1
	return count


static func _vertical_repetition_cost(kind: StringName, yaw: int,
		columns: Dictionary, adjacent: Dictionary) -> int:
	if adjacent.is_empty():
		return 0
	var registered := _registered_facade_plane_count(columns,
		adjacent.columns as Dictionary)
	var cost := registered * REGISTERED_FACADE_PLANE_COST
	if registered >= 2:
		cost += STRONG_FACADE_REGISTRATION_COST
	if kind == StringName(adjacent.kind):
		cost += SAME_ADJACENT_ROOM_KIND_COST
	if posmod(yaw, 2) == posmod(int(adjacent.yaw_quarters), 2):
		cost += SAME_ADJACENT_RIDGE_AXIS_COST
	return cost


static func _candidate_vertical_registration(columns: Dictionary,
		previous: Dictionary, next: Dictionary) -> Dictionary:
	var registered_planes := 0
	var strong_registrations := 0
	for adjacent: Dictionary in [previous, next]:
		if adjacent.is_empty():
			continue
		var registered := _registered_facade_plane_count(columns,
			adjacent.columns as Dictionary)
		registered_planes += registered
		strong_registrations += int(registered >= 2)
	return {
		"registered_facade_plane_count": registered_planes,
		"strong_registration_count": strong_registrations,
	}


static func _is_subset(left: Dictionary, right: Dictionary) -> bool:
	for value: Variant in left.keys():
		if not right.has(value):
			return false
	return true


static func _intersection_size(left: Dictionary, right: Dictionary) -> int:
	var count := 0
	for value: Variant in left.keys():
		count += int(right.has(value))
	return count


static func _symmetric_difference_size(left: Dictionary,
		right: Dictionary) -> int:
	var count := 0
	for value: Variant in left.keys():
		count += int(not right.has(value))
	for value: Variant in right.keys():
		count += int(not left.has(value))
	return count


static func _same_set(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	return _is_subset(left, right)
