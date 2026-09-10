class_name WarrenRoomCompositionPlanner
extends RefCounted

## Semantic protected-owner token for an exact upper-room support envelope
## which collided with an already-selected hero feature. The composition
## planner owns its meaning: an optional one-storey crown may stop before this
## mass, while a required doorway/market/bridge course makes the proposal fail.
const ROOM_SUPPORT_CLEARANCE_OWNER_ID := \
	&"spatial.room_support.clearance"

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
	&"long", &"building", &"slim", &"row", &"tower",
]
## TASK F2. The authored room kinds as small integers, so the two stamp memos
## can be keyed by a Vector4i instead of a formatted String. Zero is reserved
## for "not a room kind" and is never a stored key -- see `_stamp_slot`.
const KIND_SLOTS: Dictionary = {
	&"tower": 1, &"slim": 2, &"row": 3, &"building": 4, &"long": 5,
}

static var last_failure := ""
static var last_audit: Dictionary = {}
static var last_merge_diagnostic: Dictionary = {}
static var last_variant_diagnostic: Dictionary = {}
static var last_pair_diagnostic: Dictionary = {}
static var diagnostic_trace := false
## The merge/coupling/relief passes revisit the same translated authored room
## footprints many thousands of times. These are output-pure geometry lookups,
## so retain them only for the duration of one solve. Keeping the cache local to
## the transaction avoids cross-town memory growth and cannot affect ordering.
static var _stamp_columns_cache: Dictionary = {}
static var _stamp_cells_cache: Dictionary = {}


static func solve(grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], offsets_by_parcel: Dictionary,
		forced_offsets_by_parcel: Dictionary, market_reservation: Dictionary,
		protected_owners: Dictionary, skywalk_forced_offsets: Dictionary,
		skywalk_reservations: Array[Dictionary], world_seed: int,
		enable_paired_registration_relief: bool = true,
		collect_diagnostics: bool = true) -> Dictionary:
	last_failure = ""
	last_audit = {}
	last_merge_diagnostic = {}
	last_variant_diagnostic = {}
	last_pair_diagnostic = {}
	_stamp_columns_cache.clear()
	_stamp_cells_cache.clear()
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
	var support_clearance_terminated_storeys := 0
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
		# A support course rejected by the exact hero-feature preflight feeds the
		# conflicting upper room back as semantic protected mass. Source records are
		# one storey even though the earlier offset packer works in two-storey bands,
		# so this is the first layer that can preserve a required lower market/door/
		# bridge socket while ending only the optional room above it. Because
		# `required_through` is the last forced source record, resizing here can never
		# orphan a later interface.
		var support_clearance_block := -1
		for block_index in blocks.size():
			var source_block := blocks[block_index] as Dictionary
			for cell: Vector3i in source_block.cells:
				if (protected_owners.get(cell, {}) as Dictionary).has(
						ROOM_SUPPORT_CLEARANCE_OWNER_ID):
					support_clearance_block = block_index
					break
			if support_clearance_block >= 0:
				break
		if support_clearance_block >= 0:
			if support_clearance_block <= required_through:
				last_failure = ("room-support clearance intersects required " \
					+ "source block %s/%d") % [parcel.stable_id,
						support_clearance_block]
				return {}
			support_clearance_terminated_storeys += blocks.size() \
				- support_clearance_block
			blocks.resize(support_clearance_block)
			if blocks.is_empty():
				continue
		# The exact-offset solve may terminate an optional upper crown instead
		# of discarding a valid lower building when a hero feature occupies that
		# residual mass. Count only the complete bands that actually enter this
		# three-dimensional room grammar.
		input_storeys += blocks.size()
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
	var merged_base_count := _merge_base_tower_pairs(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING base_macro_merge ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=",
			merged_base_count)
		_trace_composition_geometry("base_macro", lineages, grid)
		trace_stage = Time.get_ticks_msec()
	var merged_count := _merge_upper_lineages(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING merge ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=", merged_count)
		_trace_composition_geometry("merge", lineages, grid)
		trace_stage = Time.get_ticks_msec()
	var coupled_count := _couple_upper_lineages(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING couple ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=", coupled_count)
		_trace_composition_geometry("couple", lineages, grid)
		trace_stage = Time.get_ticks_msec()
	var expanded_count := _vary_unmerged_lineages(lineages, grid,
		protected_owners, world_seed)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING vary ms=",
			Time.get_ticks_msec() - trace_stage, " accepted=", expanded_count)
		_trace_composition_geometry("vary", lineages, grid)
		trace_stage = Time.get_ticks_msec()
	# Room composition ends after its ordered construction passes. Roof and
	# bearing defects are inspected by tests; completed rooms are never moved,
	# retried, shortened or discarded by a cleanup pass.
	var feature_roof_occupancy := _feature_roof_occupancy(skywalk_reservations)
	last_merge_diagnostic["variant_diagnostic"] = \
		last_variant_diagnostic.duplicate(true)
	# Merges and bounded crown termination may replace the source lineage that
	# an elevated parcel originally named as its bearer.  Geometry support was
	# already recomputed above, but leaving the old identity behind makes the
	# construction DAG point at a block that no longer exists.  Canonicalize the
	# semantic edge from the final occupied plate immediately beneath the child;
	# this is the same final-state fact the support audit just proved.
	var support_identity := _canonicalize_external_support_parents(lineages,
		grid)
	var audit: Dictionary = {}
	if collect_diagnostics:
		audit = _audit(lineages, input_storeys, merged_count,
			coupled_count, expanded_count, 0)
		audit.merge(construction_diagnostics(lineages, grid, feature_roof_occupancy), true)
		audit.merge(_macroscopic_shape_audit(lineages), true)
		audit["unresolved_overlong_tower_run_details"] = _unresolved_overlong_tower_runs(audit)
		audit["unresolved_support_identity_details"] = support_identity.get("details", [])
	audit["room_composition_diagnostics_collected"] = collect_diagnostics
	audit["merged_base_composition_count"] = merged_base_count
	audit["support_parent_rebind_count"] = int(
		support_identity.get("rebound_count", 0))
	audit["retained_support_rebind_count"] = int(
		support_identity.get("retained_support_count", 0))
	audit["support_clearance_terminated_storey_count"] = \
		support_clearance_terminated_storeys
	last_audit = audit.duplicate(true)
	if diagnostic_trace:
		print("ROOM_COMPOSITION_TIMING final_audit ms=",
			Time.get_ticks_msec() - trace_stage, " whole_solve_ms=",
			Time.get_ticks_msec() - trace_started)
	return {"lineages": lineages, "audit": audit}


static func construction_diagnostics(lineages: Dictionary,
		grid: WarrenSpatialGrid, feature_roof_occupancy: Dictionary = {}) -> Dictionary:
	## Read-only inspection of the finished room composition. Reports never
	## decide whether a room or a town exists, and never invoke a repair pass.
	var facts := _lineage_support_audit(lineages, grid)
	facts.merge(_lineage_overlap_audit(lineages), true)
	facts.merge(_unroofable_shoulder_audit(lineages), true)
	facts.merge(_global_exposed_roof_audit(lineages, feature_roof_occupancy), true)
	return facts


static func _merge_base_tower_pairs(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	## Ground/frontage rooms were deliberately excluded from the original upper
	## merge, leaving every route-wall fallback as an individually roofed 2x2
	## prism. Join only exact coplanar tower pairs whose union is one native macro
	## stamp. One participant retains the real authored address and any hero
	## socket; the other becomes private mass behind that address, and every upper
	## continuation/support edge is transferred transactionally.
	var records: Array[Dictionary] = []
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		if blocks.is_empty():
			continue
		var block := blocks[0] as Dictionary
		if StringName(block.kind) != &"tower" \
				or int(block.end_storey) - int(block.start_storey) != 1:
			continue
		records.append({"lineage_id": lineage_id,
			"source_block_index": int(block.source_block_index),
			"block": block, "height": _lineage_storey_count(blocks),
			"key": "%s/%d" % [lineage_id, int(block.source_block_index)]})
	var candidates: Array[Dictionary] = []
	var exact_pair_count := 0
	var address_match_count := 0
	var clear_count := 0
	var resumption_count := 0
	var roofable_count := 0
	for left_index in records.size():
		var left := records[left_index] as Dictionary
		for right_index in range(left_index + 1, records.size()):
			var right := records[right_index] as Dictionary
			var left_block := left.block as Dictionary
			var right_block := right.block as Dictionary
			if (left_block.origin as Vector3i).y \
					!= (right_block.origin as Vector3i).y:
				continue
			var union := (left_block.columns as Dictionary).duplicate()
			var overlaps := false
			for column_value: Variant in (right_block.columns as Dictionary).keys():
				if union.has(column_value):
					overlaps = true
					break
				union[column_value] = true
			if overlaps:
				continue
			var stamps := _exact_non_tower_stamps_for_columns(union,
				(left_block.origin as Vector3i).y)
			if stamps.is_empty():
				continue
			exact_pair_count += 1
			var left_identity := _base_block_has_hero_identity(left_block)
			var right_identity := _base_block_has_hero_identity(right_block)
			if left_identity and right_identity:
				continue
			for stamp: Dictionary in stamps:
				for primary_is_left: bool in [true, false]:
					if left_identity and not primary_is_left \
							or right_identity and primary_is_left:
						continue
					var primary := left if primary_is_left else right
					var secondary := right if primary_is_left else left
					if not _candidate_matches_address(StringName(stamp.kind),
							stamp.origin as Vector3i,
							int(stamp.yaw_quarters),
							primary.block as Dictionary) \
							or not _candidate_matches_constraints(StringName(stamp.kind),
							stamp.origin as Vector3i,
							int(stamp.yaw_quarters),
							primary.block as Dictionary):
						continue
					address_match_count += 1
					var participant_ids: Dictionary = {
						StringName(left.lineage_id): true,
						StringName(right.lineage_id): true,
					}
					var merged := _record(StringName(stamp.kind),
						stamp.origin as Vector3i, int(stamp.yaw_quarters),
						int((primary.block as Dictionary).start_storey),
						int((primary.block as Dictionary).end_storey))
					if merged.is_empty() or not _record_is_clear_for_participants(
							grid, protected_owners, merged, participant_ids):
						continue
					clear_count += 1
					var participants := [left, right] as Array[Dictionary]
					if not _resumptions_overlap(lineages, participants,
							merged.columns as Dictionary):
						continue
					resumption_count += 1
					if not _merge_transitions_are_roofable(lineages,
							participants, merged):
						continue
					roofable_count += 1
					var tie := posmod(Helper._mix64(world_seed \
						^ String(primary.lineage_id).hash() * 31 \
						^ String(secondary.lineage_id).hash() * 47 \
						^ StringName(stamp.kind).hash() * 59 \
						^ int(stamp.yaw_quarters) * 71), 1000003)
					candidates.append({"primary": primary,
						"secondary": secondary, "merged": merged,
						"identity_count": int(left_identity) \
							+ int(right_identity),
						"height": maxi(int(left.height), int(right.height)),
						"tie": tie})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.identity_count) != int(b.identity_count):
			return int(a.identity_count) > int(b.identity_count)
		if int(a.height) != int(b.height):
			return int(a.height) > int(b.height)
		return int(a.tie) < int(b.tie))
	var used: Dictionary = {}
	var remaps: Array[Dictionary] = []
	var selected := 0
	for candidate: Dictionary in candidates:
		var primary_record := candidate.primary as Dictionary
		var secondary_record := candidate.secondary as Dictionary
		var primary_id := StringName(primary_record.lineage_id)
		var secondary_id := StringName(secondary_record.lineage_id)
		if used.has(primary_id) or used.has(secondary_id) \
				or not lineages.has(primary_id) or not lineages.has(secondary_id):
			continue
		var primary := lineages[primary_id] as Dictionary
		var secondary := lineages[secondary_id] as Dictionary
		var primary_blocks := primary.blocks as Array[Dictionary]
		var secondary_blocks := secondary.blocks as Array[Dictionary]
		if primary_blocks.is_empty() or secondary_blocks.is_empty() \
				or int((primary_blocks[0] as Dictionary).source_block_index) \
					!= int(primary_record.source_block_index) \
				or int((secondary_blocks[0] as Dictionary).source_block_index) \
					!= int(secondary_record.source_block_index):
			continue
		var original_primary := primary_blocks[0] as Dictionary
		var merged := candidate.merged as Dictionary
		var replacement := _record(StringName(merged.kind),
			merged.origin as Vector3i, int(merged.yaw_quarters),
			int(original_primary.start_storey), int(original_primary.end_storey))
		replacement["forced"] = true
		replacement["original_kind"] = original_primary.original_kind
		replacement["original_origin"] = original_primary.original_origin
		replacement["original_yaw_quarters"] = \
			original_primary.original_yaw_quarters
		replacement["home_origin"] = original_primary.home_origin
		replacement["home_columns"] = original_primary.home_columns
		replacement["source_block_index"] = original_primary.source_block_index
		replacement["source_offset_block_index"] = original_primary.get(
			"source_offset_block_index", 0)
		replacement["merged"] = true
		replacement["merged_lineage_count"] = 2
		for metadata_key: String in ["address_expandable",
				"address_threshold", "address_frontage",
				"feature_endpoint_constraints", "court_contact_columns",
				"structural_forced", "interface_forced", "bearing_forced",
				"market_forced"]:
			if original_primary.has(metadata_key):
				replacement[metadata_key] = original_primary[metadata_key]
		primary_blocks[0] = replacement
		primary["blocks"] = primary_blocks
		primary["paired_primary"] = true
		var paired_with: Array[StringName] = []
		paired_with.assign(primary.get("paired_with", []) as Array)
		if not paired_with.has(secondary_id):
			paired_with.append(secondary_id)
		primary["paired_with"] = paired_with
		lineages[primary_id] = primary
		var removed_block := secondary_blocks[0] as Dictionary
		secondary_blocks.remove_at(0)
		if secondary_blocks.is_empty():
			lineages.erase(secondary_id)
		else:
			var resumed := secondary_blocks[0] as Dictionary
			resumed["support_parent_lineage_id"] = primary_id
			resumed["support_parent_source_storey"] = \
				int(replacement.end_storey) - 1
			resumed["support_parent_source_block_index"] = \
				int(replacement.source_block_index)
			secondary_blocks[0] = resumed
			secondary["blocks"] = secondary_blocks
			secondary["paired_secondary"] = true
			secondary["paired_with"] = primary_id
			secondary["address_parent_lineage_id"] = primary_id
			secondary["address_parent_source_block_index"] = int(
				replacement.source_block_index)
			lineages[secondary_id] = secondary
		remaps.append({"from_lineage_id": secondary_id,
			"from_source_block_index": int(removed_block.source_block_index),
			"to_lineage_id": primary_id,
			"to_source_block_index": int(replacement.source_block_index),
			"to_source_storey": int(replacement.end_storey) - 1})
		used[primary_id] = true
		used[secondary_id] = true
		selected += 1
	_apply_base_support_remaps(lineages, remaps)
	if diagnostic_trace:
		print("ROOM_BASE_MACRO_DIAGNOSTIC exact_pairs=", exact_pair_count,
			" address=", address_match_count, " clear=", clear_count,
			" resumed=", resumption_count, " roofable=", roofable_count,
			" candidates=", candidates.size(), " selected=", selected)
	return selected


static func _base_block_has_hero_identity(block: Dictionary) -> bool:
	return bool(block.get("market_forced", false)) \
		or not (block.get("feature_endpoint_constraints", []) as Array).is_empty() \
		or not (block.get("court_contact_columns", {}) as Dictionary).is_empty()


static func _exact_non_tower_stamps_for_columns(columns: Dictionary,
		y: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if columns.is_empty():
		return out
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in columns.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var bounds_size := maximum - minimum + Vector2i.ONE
	if columns.size() != bounds_size.x * bounds_size.y:
		return out
	# A 4 x 2 rectangle has two construction meanings. `slim` puts its door on
	# the short gable; `row` puts it on the long street eave. Enumerate both so
	# the exact public threshold, not a post-hoc mesh rotation, selects the form.
	var kinds: Array[StringName] = []
	if bounds_size in [Vector2i(2, 4), Vector2i(4, 2)]:
		kinds.assign([&"slim", &"row"])
	elif bounds_size == Vector2i(4, 4):
		kinds.append(&"building")
	elif bounds_size in [Vector2i(4, 6), Vector2i(6, 4)]:
		kinds.append(&"long")
	for kind: StringName in kinds:
		for yaw in 4:
			var local_minimum := Vector2i(-1, -2) if kind == &"slim" \
				else Vector2i(-2, -1) if kind == &"row" \
				else Vector2i(-2, -2) if kind == &"building" \
				else Vector2i(-2, -3)
			var local_size := Vector2i(2, 4) if kind == &"slim" \
				else Vector2i(4, 2) if kind == &"row" \
				else Vector2i(4, 4) if kind == &"building" \
				else Vector2i(4, 6)
			var world_size := local_size if posmod(yaw, 2) == 0 \
				else Vector2i(local_size.y, local_size.x)
			if world_size != bounds_size:
				continue
			var local_maximum := local_minimum + local_size - Vector2i.ONE
			var origin := Vector3i.ZERO
			match yaw:
				0:
					origin = Vector3i(minimum.x - local_minimum.x, y,
						minimum.y - local_minimum.y)
				1:
					origin = Vector3i(minimum.x - local_minimum.y, y,
						minimum.y + local_maximum.x)
				2:
					origin = Vector3i(minimum.x + local_maximum.x, y,
						minimum.y + local_maximum.y)
				3:
					origin = Vector3i(minimum.x + local_maximum.y, y,
						minimum.y - local_minimum.x)
			var stamp_columns := _stamp_columns(kind, origin, yaw)
			if _same_set(stamp_columns, columns):
				out.append({"kind": kind, "origin": origin,
					"yaw_quarters": yaw, "columns": stamp_columns})
	return out


static func _apply_base_support_remaps(lineages: Dictionary,
		remaps: Array[Dictionary]) -> void:
	if remaps.is_empty():
		return
	for lineage_id_value: Variant in lineages.keys():
		var lineage_id := StringName(lineage_id_value)
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		for block_index in blocks.size():
			var block := blocks[block_index] as Dictionary
			var parent_id := StringName(block.get(
				"support_parent_lineage_id", &""))
			var parent_block := int(block.get(
				"support_parent_source_block_index", -1))
			for remap: Dictionary in remaps:
				if parent_id != StringName(remap.from_lineage_id) \
						or parent_block != int(remap.from_source_block_index):
					continue
				block["support_parent_lineage_id"] = \
					StringName(remap.to_lineage_id)
				block["support_parent_source_block_index"] = int(
					remap.to_source_block_index)
				block["support_parent_source_storey"] = int(
					remap.to_source_storey)
				break
			blocks[block_index] = block
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage


static func _macroscopic_shape_audit(lineages: Dictionary) -> Dictionary:
	## The old anti-tower audit catches repeated vertical extrusion, but it says
	## nothing about a whole lower town made from separate one-storey 2x2 rooms.
	## Measure the actual final 3D decomposition here: exposed tower rooms are the
	## screenshot-visible micro-prisms, while adjacent tower pairs whose exact
	## union is a native slim/building/long footprint are macroscopic covers the
	## planner left on the table. These facts intentionally precede asset choice.
	var entries: Array[Dictionary] = []
	var claimed_cells: Dictionary = {}
	var kind_counts: Dictionary = {}
	var private_cells_by_kind: Dictionary = {}
	var total_private_cells := 0
	var macro_private_cells := 0
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var lineage := lineages[lineage_id] as Dictionary
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
			var kind := StringName(block.kind)
			var entry := {"lineage_id": lineage_id,
				"source_block_index": int(block.source_block_index),
				"kind": kind, "origin": block.origin,
				"start_storey": int(block.start_storey),
				"end_storey": int(block.end_storey),
				"columns": block.columns,
				"cells": block.cells,
				"block": block,
				"forced": bool(block.get("forced", false)),
				"structural_forced": bool(block.get(
					"structural_forced", false)),
				"interface_constrained": _block_has_interface_constraint(block)}
			entries.append(entry)
			var duration := int(block.end_storey) - int(block.start_storey)
			kind_counts[kind] = int(kind_counts.get(kind, 0)) + duration
			var cell_count := (block.cells as Array).size()
			private_cells_by_kind[kind] = int(
				private_cells_by_kind.get(kind, 0)) + cell_count
			total_private_cells += cell_count
			if kind != &"tower":
				macro_private_cells += cell_count
			for cell: Vector3i in block.cells:
				claimed_cells[cell] = "%s/%d" % [lineage_id,
					int(block.source_block_index)]
	var exposed_tower_count := 0
	var optional_exposed_tower_count := 0
	var exposed_tower_side_count := 0
	var exposed_tower_details: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if StringName(entry.kind) != &"tower":
			continue
		var exposed_directions: Array[Vector3i] = []
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var exposed := false
			for cell: Vector3i in entry.cells as Array[Vector3i]:
				if not claimed_cells.has(cell + direction):
					exposed = true
					break
			if exposed:
				exposed_directions.append(direction)
		# One exposed direction reads as the end of a terrace. Two or more make
		# the complete little cuboid legible as an independent box.
		if exposed_directions.size() < 2:
			continue
		exposed_tower_count += 1
		exposed_tower_side_count += exposed_directions.size()
		var optional := not bool(entry.structural_forced) \
			and not bool(entry.interface_constrained)
		optional_exposed_tower_count += int(optional)
		if exposed_tower_details.size() < 24:
			exposed_tower_details.append({"lineage_id": entry.lineage_id,
				"source_block_index": entry.source_block_index,
				"origin": entry.origin, "optional": optional,
				"exposed_directions": exposed_directions})
	var exact_macro_pair_count := 0
	var refused_exact_macro_pair_count := 0
	var exact_macro_disposition_counts: Dictionary = {}
	var exact_macro_pair_details: Array[Dictionary] = []
	for left_index in entries.size():
		var left := entries[left_index] as Dictionary
		if StringName(left.kind) != &"tower":
			continue
		for right_index in range(left_index + 1, entries.size()):
			var right := entries[right_index] as Dictionary
			if StringName(right.kind) != &"tower" \
					or int(left.start_storey) != int(right.start_storey) \
					or int(left.end_storey) != int(right.end_storey):
				continue
			var union := (left.columns as Dictionary).duplicate()
			var overlaps := false
			for column_value: Variant in (right.columns as Dictionary).keys():
				if union.has(column_value):
					overlaps = true
					break
				union[column_value] = true
			if overlaps:
				continue
			var macros := _exact_non_tower_stamps_for_columns(union,
				(left.origin as Vector3i).y)
			if macros.is_empty():
				continue
			var disposition := _exact_macro_pair_disposition(lineages,
				left, right, macros)
			var reason := StringName(disposition.get("reason", &"unresolved"))
			exact_macro_disposition_counts[reason] = int(
				exact_macro_disposition_counts.get(reason, 0)) + 1
			if reason == &"unresolved":
				exact_macro_pair_count += 1
			else:
				refused_exact_macro_pair_count += 1
			if exact_macro_pair_details.size() < 24:
				var macro := macros[0] as Dictionary
				exact_macro_pair_details.append({"left_lineage_id":
					left.lineage_id, "left_source_block": left.source_block_index,
					"left_origin": left.origin,
					"right_lineage_id": right.lineage_id,
					"right_source_block": right.source_block_index,
					"right_origin": right.origin,
					"macro_kind": macro.kind, "macro_origin": macro.origin,
					"macro_yaw_quarters": macro.yaw_quarters,
					"disposition": reason})
	return {"room_storey_kind_counts": kind_counts,
		"private_cell_count_by_room_kind": private_cells_by_kind,
		"macro_private_cell_ratio": float(macro_private_cells) \
			/ float(maxi(1, total_private_cells)),
		"exposed_tower_room_count": exposed_tower_count,
		"optional_exposed_tower_room_count": optional_exposed_tower_count,
		"exposed_tower_side_count": exposed_tower_side_count,
		"exposed_tower_room_details": exposed_tower_details,
		"unclaimed_exact_macro_tower_pair_count": exact_macro_pair_count,
		"refused_exact_macro_tower_pair_count":
			refused_exact_macro_pair_count,
		"exact_macro_tower_pair_disposition_counts":
			exact_macro_disposition_counts,
		"exact_macro_tower_pair_details": exact_macro_pair_details}


static func _trace_composition_geometry(stage: String,
		lineages: Dictionary, grid: WarrenSpatialGrid) -> void:
	## Composition tracing must reveal which transaction creates or removes an
	## exact macro opportunity. A final count alone cannot tell whether the
	## defect came from source parcelization, silhouette variation, or support
	## repair. This stays behind `diagnostic_trace` at every call site.
	var audit := _macroscopic_shape_audit(lineages)
	print("ROOM_SUPPORT_STAGE stage=", stage, " facts=",
		_lineage_support_audit(lineages, grid))
	print("ROOM_ROOF_STAGE stage=", stage, " facts=",
		_global_exposed_roof_audit(lineages))
	var gap_audit := _lineage_interstitial_gap_audit(lineages, grid)
	print("ROOM_MACRO_AUDIT stage=", stage,
		" unresolved=", audit.unclaimed_exact_macro_tower_pair_count,
		" refused=", audit.refused_exact_macro_tower_pair_count,
		" dispositions=", audit.exact_macro_tower_pair_disposition_counts,
		" details=", audit.exact_macro_tower_pair_details,
		" slit_cells=", gap_audit.one_cell_interstitial_gap_cell_count,
		" slit_details=", gap_audit.one_cell_interstitial_gap_details)


static func _lineage_interstitial_gap_audit(lineages: Dictionary,
		grid: WarrenSpatialGrid) -> Dictionary:
	## Find the exact one-cell void courses that will become 1.5 m visual slits
	## after unclaimed massif cells are discarded. Intentional alleys and passages
	## are already PUBLIC_AIR, so only still-ALLOCATABLE cells qualify here.
	var claims: Dictionary = {}
	for lineage_id_value: Variant in lineages.keys():
		var lineage_id := StringName(lineage_id_value)
		for block: Dictionary in (lineages[lineage_id] as Dictionary).blocks \
				as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				claims[cell] = {"lineage_id": lineage_id,
					"source_block_index": int(block.source_block_index)}
	var gaps: Dictionary = {}
	for claimed_cell_value: Variant in claims.keys():
		var claimed_cell := claimed_cell_value as Vector3i
		for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
			var gap := claimed_cell + direction
			if grid != null and grid.use_at(gap) \
					!= WarrenSpatialGrid.Use.ALLOCATABLE:
				continue
			var opposite := gap + direction
			if not claims.has(opposite):
				continue
			var left := claims[claimed_cell] as Dictionary
			var right := claims[opposite] as Dictionary
			if StringName(left.lineage_id) == StringName(right.lineage_id) \
					and int(left.source_block_index) \
						== int(right.source_block_index):
				continue
			gaps[gap] = {"cell": gap,
				"axis": &"x" if direction == Vector3i.RIGHT else &"z",
				"negative_lineage": StringName(left.lineage_id),
				"negative_source_block": int(left.source_block_index),
				"positive_lineage": StringName(right.lineage_id),
				"positive_source_block": int(right.source_block_index)}
	var cells: Array[Vector3i] = []
	cells.assign(gaps.keys())
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.x != b.x:
			return a.x < b.x
		return a.z < b.z)
	var details: Array[Dictionary] = []
	for cell: Vector3i in cells:
		if details.size() >= 16:
			break
		details.append(gaps[cell] as Dictionary)
	return {"one_cell_interstitial_gap_cell_count": gaps.size(),
		"one_cell_interstitial_gap_details": details}


static func _exact_macro_pair_disposition(lineages: Dictionary,
		left: Dictionary, right: Dictionary,
		macros: Array[Dictionary]) -> Dictionary:
	## Geometry alone deliberately cannot call a late merge legal. Explain which
	## semantic or construction proof prevents the exact cover so the anti-box
	## metric reports actionable defects rather than punishing two real homes for
	## retaining two different doors.
	var left_block := left.block as Dictionary
	var right_block := right.block as Dictionary
	# Source-relative storey indices are not world-space elevations. Two parcels
	# rooted on different terrain/support phases can both call a room `storey 0`
	# while their actual floor plates differ by a half-storey. Their projected XZ
	# union resembles a macro in plan view, but moving either occupied volume to a
	# shared Y would corrupt bearing and entrances. This is a typed stepped-wall /
	# stepped-roof join obligation, not an undispositioned macro cover.
	if (left_block.origin as Vector3i).y \
			!= (right_block.origin as Vector3i).y:
		return {"reason": &"vertical_phase_conflict"}
	var left_addressed := _block_has_address_in_band(left_block)
	var right_addressed := _block_has_address_in_band(right_block)
	if left_addressed and right_addressed:
		return {"reason": &"distinct_public_addresses"}
	var left_hero := _block_has_non_address_identity(left_block)
	var right_hero := _block_has_non_address_identity(right_block)
	if int(left_addressed or left_hero) + int(right_addressed or right_hero) > 1:
		return {"reason": &"hero_socket_conflict"}
	var primary := left
	if right_addressed or right_hero:
		primary = right
	var semantic_candidates: Array[Dictionary] = []
	for macro: Dictionary in macros:
		var primary_block := primary.block as Dictionary
		if _block_has_address_in_band(primary_block) \
				and not _candidate_matches_address(StringName(macro.kind),
					macro.origin as Vector3i, int(macro.yaw_quarters),
					primary_block):
			continue
		if not _candidate_matches_constraints(StringName(macro.kind),
				macro.origin as Vector3i, int(macro.yaw_quarters),
				primary_block):
			continue
		semantic_candidates.append(macro)
	if semantic_candidates.is_empty():
		return {"reason": &"public_threshold_conflict"} \
			if left_addressed or right_addressed \
			else {"reason": &"hero_socket_conflict"}
	var participants := [left, right] as Array[Dictionary]
	var bearing_candidate_count := 0
	for macro: Dictionary in semantic_candidates:
		if not _resumptions_overlap(lineages, participants,
				macro.columns as Dictionary):
			continue
		bearing_candidate_count += 1
		var merged := _record(StringName(macro.kind),
			macro.origin as Vector3i, int(macro.yaw_quarters),
			int(left_block.start_storey), int(left_block.end_storey))
		if _merge_transitions_are_roofable(lineages, participants, merged):
			return {"reason": &"unresolved"}
	if bearing_candidate_count == 0:
		return {"reason": &"bearing_conflict"}
	return {"reason": &"roof_transition_conflict"}


static func _block_has_address_in_band(block: Dictionary) -> bool:
	var threshold := block.get("address_threshold",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	if threshold.x == 2147483647:
		return false
	var origin := block.origin as Vector3i
	return threshold.y >= origin.y \
		and threshold.y < origin.y + WarrenSpatialGrid.STOREY_CELLS


static func _block_has_non_address_identity(block: Dictionary) -> bool:
	return bool(block.get("market_forced", false)) \
		or not (block.get("feature_endpoint_constraints", []) as Array).is_empty() \
		or not (block.get("court_contact_columns", {}) as Dictionary).is_empty()


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


static func _feature_roof_occupancy(
		skywalk_reservations: Array[Dictionary]) -> Dictionary:
	var occupied: Dictionary = {}
	for reservation_index in skywalk_reservations.size():
		var reservation := skywalk_reservations[reservation_index]
		var feature_id := StringName(reservation.get("feature_id",
			"spatial.skywalk.%02d" % reservation_index))
		for cell_value: Variant in (reservation.get("reserved_cells", {}) \
				as Dictionary).keys():
			var cell := cell_value as Vector3i
			occupied[cell] = {
				"lineage_id": feature_id,
				"block_position": -1,
				"kind": &"occupied_skywalk",
				"origin": cell,
				"columns": [Vector2i(cell.x, cell.z)],
				"feature_blocker": true,
			}
	return occupied


static func _global_exposed_roof_audit(lineages: Dictionary,
		extra_occupied: Dictionary = {}) -> Dictionary:
	## Prove the exposed top of every individual room against the complete town
	## occupancy. Per-lineage transition checks cannot see an unrelated upper
	## stack covering three quarters of a lower room and leaving one voxel lid.
	var occupied: Dictionary = {}
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var blocks := (lineages[lineage_id] as Dictionary).blocks \
			as Array[Dictionary]
		for position in blocks.size():
			var occupied_block := blocks[position] as Dictionary
			for cell: Vector3i in occupied_block.cells:
				occupied[cell] = {"lineage_id": lineage_id,
					"block_position": position, "kind": occupied_block.kind,
					"origin": occupied_block.origin,
					"columns": (occupied_block.columns as Dictionary).keys()}
	# Feature reservations are admitted only when they do not replace room mass,
	# so room records remain authoritative in the impossible-overlap case. Their
	# exact cells nevertheless count as upper occupied mass for exposed roofs.
	for cell_value: Variant in extra_occupied.keys():
		if not occupied.has(cell_value):
			occupied[cell_value] = extra_occupied[cell_value]
	var count := 0
	var details: Array[Dictionary] = []
	for lineage_id: StringName in lineage_ids:
		var blocks := (lineages[lineage_id] as Dictionary).blocks \
			as Array[Dictionary]
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			var block_origin := block.origin as Vector3i
			for local_storey in range(int(block.end_storey) \
					- int(block.start_storey)):
				var room_origin := Vector3i(block_origin.x,
					block_origin.y + local_storey \
						* WarrenSpatialGrid.STOREY_CELLS,
					block_origin.z)
				var top_y := room_origin.y + WarrenSpatialGrid.STOREY_CELLS - 1
				var exposed_columns: Dictionary = {}
				var covered_by: Dictionary = {}
				for room_cell: Vector3i in WarrenRoomStamp \
						.expected_private_cells(StringName(block.kind), room_origin,
							int(block.yaw_quarters)):
					if room_cell.y != top_y:
						continue
					var above := room_cell + Vector3i.UP
					if not occupied.has(above):
						exposed_columns[Vector2i(room_cell.x, room_cell.z)] = true
						continue
					var blocker := occupied[above] as Dictionary
					var blocker_key := "%s/%d" % [blocker.lineage_id,
						int(blocker.block_position)]
					covered_by[blocker_key] = blocker
				if exposed_columns.is_empty():
					continue
				var upper_columns: Dictionary = {}
				for occupied_cell_value: Variant in occupied.keys():
					var occupied_cell := occupied_cell_value as Vector3i
					if occupied_cell.y == top_y + 1:
						upper_columns[Vector2i(occupied_cell.x,
							occupied_cell.z)] = true
				for component: Dictionary in _column_components(exposed_columns):
					if _shoulder_component_is_roofable(component,
							upper_columns, top_y):
						continue
					count += 1
					if details.size() < 24:
						var component_blockers := covered_by.duplicate()
						for column_value: Variant in component.keys():
							var column := column_value as Vector2i
							for direction: Vector2i in [Vector2i.LEFT,
									Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
								var neighbor := column + direction
								var upper_cell := Vector3i(neighbor.x,
									top_y + 1, neighbor.y)
								if not occupied.has(upper_cell):
									continue
								var adjacent_blocker := occupied[upper_cell] \
									as Dictionary
								var adjacent_key := "%s/%d" % [
									adjacent_blocker.lineage_id,
									int(adjacent_blocker.block_position)]
								component_blockers[adjacent_key] = \
									adjacent_blocker
						details.append({"lineage_id": lineage_id,
							"block_position": position,
							"source_block_index": int(block.source_block_index),
							"local_storey": local_storey,
							"cell_count": component.size(),
							"cells": component.keys(),
							"blockers": component_blockers.values()})
	return {"unroofable_global_roof_component_count": count,
		"unroofable_global_roof_component_details": details,
		"details": details}


static func _shoulder_component_is_roofable(component: Dictionary,
		upper_columns: Dictionary, y: int) -> bool:
	if not _exact_stamp_for_columns(component, y).is_empty():
		return true
	if _component_has_gabled_partition(component, y):
		return true
	# The only partial footprint admitted is the exact sloped-infill vocabulary: a
	# straight 3/6/9 m row, one fine cell deep, with each long edge either open or
	# completely bound to an upper wall. One bound edge is a lean-to; two bound
	# edges form a narrow typed roof trench whose slope joins both masses. Corners,
	# branches, partial wall contacts, and isolated shelves have no authored roof
	# contract and must make the composition candidate fail.
	# A single 3 m by 1.5 m shoulder is the skinny pasted-on cap reported in
	# close review. Although one shallow asset can technically cover it, its
	# complete measured eave has no useful clearance in the dense fabric and it
	# reads as a loose roof fragment. Setbacks begin at 6 m; smaller remainders
	# are absorbed/recomposed by the bounded crown repair above.
	if component.size() not in [4, 6]:
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
	return wall_side_count in [1, 2]

static func _component_has_gabled_partition(component: Dictionary,
		y: int) -> bool:
	## Compound L/Z shoulders are valid only when they contain at least one full
	## authored room roof and the remainder is a finite set of straight native
	## shallow-roof runs. A one-cell remainder has no authored pitched module and
	## is rejected here, before rooms are instantiated; the former acceptance was
	## exactly how a loose square plank survived to the roof compiler. This admits
	## real intersecting roof composition without making voxel shelves legal.
	if component.size() < 6:
		return false
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in component.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	# Room stamps are axis-aligned rectangles. Enumerating the six unique XZ
	# footprints directly avoids constructing four rotated three-dimensional room
	# arrays for every origin around the component--this predicate sits on several
	# hot candidate frontiers.
	for size: Vector2i in [Vector2i(4, 6), Vector2i(6, 4),
			Vector2i(4, 4), Vector2i(2, 4), Vector2i(4, 2),
			Vector2i(2, 2)]:
		if size.x * size.y > component.size():
			continue
		for x in range(minimum.x, maximum.x - size.x + 2):
			for z in range(minimum.y, maximum.y - size.y + 2):
				var stamp: Dictionary = {}
				var contained := true
				for stamp_x in range(x, x + size.x):
					for stamp_z in range(z, z + size.y):
						var column := Vector2i(stamp_x, stamp_z)
						if not component.has(column):
							contained = false
							break
						stamp[column] = true
					if not contained:
						break
				if not contained:
					continue
				var remainder := component.duplicate()
				for column_value: Variant in stamp.keys():
					remainder.erase(column_value)
				var valid := true
				for residual: Dictionary in _column_components(remainder):
					# A complete square/rectangular return is a roof plate in its
					# own right. The compiler partitions its joined edge into the
					# same native gable runs; it is not an isolated one-cell shelf.
					if not _component_is_straight_native_row(residual) \
							and _exact_stamp_for_columns(residual, y).is_empty():
						valid = false
						break
				if valid:
					return true
	return false


static func _component_is_straight_native_row(component: Dictionary) -> bool:
	if component.is_empty():
		return true
	if component.size() not in [4, 6]:
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
			var market_forced := false
			for cell: Vector3i in record.cells:
				if cell == market_backing:
					forced = true
					structural_forced = true
					market_forced = true
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
			record["market_forced"] = market_forced
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
	for lineage_id: StringName in ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
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
		for kind: StringName in [&"long", &"building", &"slim", &"row"]:
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
							"base_y": y,
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
	candidates.sort_custom(_upper_merge_candidate_is_better)
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
		if not _merge_transitions_are_roofable(lineages, participants, merged):
			continue
		# Earlier accepted base/upper transactions may already have removed rooms
		# from the immutable candidate snapshot, so the commit gate must re-prove the
		# merged plate against the CURRENT room graph. Otherwise a visually useful
		# macro can survive on bearing that no longer exists and fail minutes later
		# in the town-wide support audit.
		if not _merge_plate_has_current_bearing(lineages, grid, merged):
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


static func _upper_merge_candidate_is_better(a: Dictionary,
		b: Dictionary) -> bool:
	## Room-bearing ancestry is a DAG. Commit lower floorplates before any child
	## which may bear on them, then retain the existing silhouette/macro ranking
	## within one absolute band. A globally height-first greedy list could accept
	## an upper macro and subsequently remove the lower mass that justified it.
	if int(a.base_y) != int(b.base_y):
		return int(a.base_y) < int(b.base_y)
	if int(a.tall_tower_relief) != int(b.tall_tower_relief):
		return int(a.tall_tower_relief) > int(b.tall_tower_relief)
	if int(a.strong_registration_count) != int(b.strong_registration_count):
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
		return int(a.displaced_source_columns) < int(b.displaced_source_columns)
	if int(a.area) != int(b.area):
		return int(a.area) > int(b.area)
	return int(a.tie) < int(b.tie)


static func _merge_plate_has_current_bearing(lineages: Dictionary,
		grid: WarrenSpatialGrid, merged: Dictionary) -> bool:
	if merged.is_empty():
		return false
	return _floorplate_transition_is_structurally_legible(
		merged.get("columns", {}) as Dictionary, {},
		(merged.get("origin", Vector3i()) as Vector3i).y,
		_claimed_room_cells(lineages), grid)


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
	## A merged macro room becomes the explicit parent of every participant that
	## resumes above it. Mere one-cell contact is not a construction seam: demand
	## the same fully-borne-or-one-authored-bracket-course contract used by the
	## final support proof before accepting the merge.
	for participant: Dictionary in participants:
		var lineage := lineages[StringName(participant.lineage_id)] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		var position := _block_position(blocks,
			int(participant.source_block_index))
		if position < 0:
			return false
		if position + 1 < blocks.size():
			var upper := blocks[position + 1] as Dictionary
			if not _floorplate_transition_is_structurally_legible(
					upper.columns as Dictionary, columns,
					(upper.origin as Vector3i).y, {}, null):
				return false
	return true


static func _merge_transitions_are_roofable(lineages: Dictionary,
		participants: Array[Dictionary], merged: Dictionary) -> bool:
	## Run at the bounded, ranked commit frontier rather than inside raw stamp
	## enumeration: exact roof decomposition is materially more expensive than the
	## simple overlap filters that generate candidates.
	for participant: Dictionary in participants:
		var lineage := lineages[StringName(participant.lineage_id)] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		var position := _block_position(blocks,
			int(participant.source_block_index))
		if position < 0:
			return false
		if position > 0 and _transition_unroofable_shoulder_count(
				blocks[position - 1] as Dictionary, merged) > 0:
			return false
		if position + 1 < blocks.size() and \
				_transition_unroofable_shoulder_count(merged,
					blocks[position + 1] as Dictionary) > 0:
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
		# TASK F2. `not in [A, B]` builds and discards a two-element Array on
		# every cell of every trial record; the composition tests millions of
		# them. Two comparisons, same predicate.
		var use := grid.use_at(cell)
		if not grid.contains(cell) \
				or use != WarrenSpatialGrid.Use.ALLOCATABLE \
				and use != WarrenSpatialGrid.Use.OUTSIDE:
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
	for kind: StringName in [&"long", &"building", &"slim", &"row"]:
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
		# TASK F2. `not in [A, B]` builds and discards a two-element Array on
		# every cell of every trial record; the composition tests millions of
		# them. Two comparisons, same predicate.
		var use := grid.use_at(cell)
		if not grid.contains(cell) \
				or use != WarrenSpatialGrid.Use.ALLOCATABLE \
				and use != WarrenSpatialGrid.Use.OUTSIDE:
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
	# Each construction band consumes its final lower plates. Upper contacts
	# constrain the band before its joint pair domain is formed.
	protected_owners = protected_owners.duplicate(true)
	var bands: Dictionary = {}
	for lineage: Dictionary in lineages.values():
		for block: Dictionary in lineage.blocks:
			bands[(block.origin as Vector3i).y] = true
	var heights: Array = bands.keys()
	heights.sort()
	var selected := 0
	for base_y: int in heights:
		var occupied: Dictionary = {}
		for lineage_id: StringName in lineages:
			for block: Dictionary in (lineages[lineage_id] as Dictionary).blocks:
				for cell: Vector3i in block.cells:
					occupied[cell] = lineage_id
		_reserve_composed_roof_space(lineages, occupied, protected_owners)
		selected += _couple_room_band(lineages, grid, protected_owners,
			world_seed, base_y)
	return selected


static func _couple_room_band(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int, base_y: int) -> int:
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
			if bool(block.merged) or bool(block.get("coupled", false)):
				for cell: Vector3i in block.cells:
					composed_cells[cell] = true
			if (block.origin as Vector3i).y != base_y or position < 1 or bool(block.merged) \
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
	var occupied: Dictionary = {}
	for lineage_id: StringName in ids:
		for block: Dictionary in (lineages[lineage_id] as Dictionary).blocks:
			for cell: Vector3i in block.cells:
				occupied[cell] = true
	for records: Array in records_by_band.values():
		for record: Dictionary in records:
			record["bearing_bounds"] = _occupied_bearing_columns_above(record.current, occupied)
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
	# TASK F2. The same rewrite `_volumetric_variant_stamp` carries, and here
	# with nothing to qualify it: this search publishes no diagnostic counters
	# at all, so an origin that cannot bear is simply not visited. See
	# `_stamp_rect`, `_columns_as_rect` and `_rect_intersection_size` for why
	# each replacement is exact.
	var previous_columns := previous.columns as Dictionary
	var next_columns := (next.columns as Dictionary) if not next.is_empty() \
		else {}
	var current_rect := _columns_as_rect(current_columns)
	var previous_rect := _columns_as_rect(previous_columns)
	var next_rect := _columns_as_rect(next_columns)
	var previous_bounds := _column_bounds(previous_columns)
	var next_bounds := _column_bounds(next_columns)
	var current_bounds := _column_bounds(current_columns)
	# FIX ROUND 1, IMPORTANT 2, as above.
	var previous_is_filled := previous_rect.size.x > 0
	var next_is_filled := next_rect.size.x > 0
	var current_is_filled := current_rect.size.x > 0
	var previous_maximum := previous_bounds.position + previous_bounds.size \
		- Vector2i.ONE
	# FIX ROUND 1, MINOR 3. The De Morgan negation of
	# `_block_has_interface_constraint`, as in `_volumetric_variant_stamp`.
	var constraints_are_free := not _block_has_interface_constraint(current)
	var bearing_bounds: Rect2i = record.get("bearing_bounds", Rect2i())
	var origin_y := (current.origin as Vector3i).y
	if previous_bounds.size.x <= 0:
		return out
	for kind: StringName in ROOM_KINDS:
		for yaw in 4:
			var base_rect := _stamp_rect(kind, Vector3i(0, origin_y, 0), yaw)
			if base_rect.size.x <= 0:
				continue
			var stamp_size := base_rect.size
			var stamp_area := stamp_size.x * stamp_size.y
			var required_overlap := maxi(MIN_BEARING_OVERLAP_COLUMNS,
				ceili(float(stamp_area) * 0.25))
			var x_low := maxi(minimum.x - 4, previous_bounds.position.x \
				- base_rect.position.x - stamp_size.x + 1)
			var x_high := mini(maximum.x + 4,
				previous_maximum.x - base_rect.position.x)
			var z_low := maxi(minimum.y - 4, previous_bounds.position.y \
				- base_rect.position.y - stamp_size.y + 1)
			var z_high := mini(maximum.y + 4,
				previous_maximum.y - base_rect.position.y)
			if bearing_bounds.has_area():
				x_low = maxi(x_low, bearing_bounds.end.x - base_rect.position.x - stamp_size.x)
				x_high = mini(x_high, bearing_bounds.position.x - base_rect.position.x)
				z_low = maxi(z_low, bearing_bounds.end.y - base_rect.position.y - stamp_size.y)
				z_high = mini(z_high, bearing_bounds.position.y - base_rect.position.y)
			for x in range(x_low, x_high + 1):
				for z in range(z_low, z_high + 1):
					var stamp_position := base_rect.position + Vector2i(x, z)
					if current_rect.size.x > 0 \
							and current_rect.position == stamp_position \
							and current_rect.size == stamp_size \
							or previous_rect.size.x > 0 \
							and previous_rect.position == stamp_position \
							and previous_rect.size == stamp_size \
							or next_rect.size.x > 0 \
							and next_rect.position == stamp_position \
							and next_rect.size == stamp_size:
						continue
					var origin := Vector3i(x, origin_y, z)
					if not constraints_are_free \
							and not _candidate_matches_constraints(kind,
								origin, yaw, current):
						continue
					var lower_overlap := _rect_intersection_size(stamp_position,
						stamp_size, previous_columns, previous_bounds,
						previous_is_filled)
					if lower_overlap < required_overlap:
						continue
					var upper_overlap := 0
					if not next.is_empty():
						upper_overlap = _rect_intersection_size(stamp_position,
							stamp_size, next_columns, next_bounds,
							next_is_filled)
						if upper_overlap <= 0:
							continue
					var columns := _stamp_columns(kind, origin, yaw)
					var trial := _record(kind, origin, yaw,
						int(current.start_storey), int(current.end_storey))
					if trial.is_empty() or _record_overlaps_claimed(trial,
							claimed_cells) or not _record_is_clear_for_participants(
							grid, protected_owners, trial, participant_ids) \
							or not _new_projection_has_clearance(trial,
								current_columns, protected_owners, claimed_cells,
								participant_ids):
						continue
					# TASK F2, as in `_volumetric_variant_stamp`: one
					# rectangle count answers both, because the stamp is a
					# filled rectangle of known area.
					var inside_current := _rect_intersection_size(
						stamp_position, stamp_size, current_columns,
						current_bounds, current_is_filled)
					var difference := stamp_area + current_columns.size() \
						- 2 * inside_current
					var tower_relief := int(StringName(current.kind) == &"tower" \
						and kind != &"tower")
					var kind_change := int(kind != StringName(current.kind))
					var expanded := inside_current < stamp_area
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
						# Paired silhouette scoring consumes the lightweight variant
						# directly before the winning pair is expanded into a full
						# record. Preserve its vertical interval so shoulder/roof
						# rules see the same typed transition as _record().
						"start_storey": int(current.start_storey),
						"end_storey": int(current.end_storey),
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
		if not defer_structural_proof:
			var trial := _record(StringName(variant.kind),
				variant.origin as Vector3i, int(variant.yaw_quarters),
				int(current.start_storey), int(current.end_storey))
			if _transition_unroofable_shoulder_count(previous, trial) > 0 \
					or _transition_unroofable_shoulder_count(trial, next) > 0:
				continue
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
	## every candidate column, including neighbouring inhabited mass, then admit
	## only a fully borne plate or one bracketable edge course. This is a cheap
	## composition preflight only: the later feature transaction must classify the
	## result as a measured shallow overhang/outcropping and build every support,
	## otherwise the complete town is rejected.
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
	# A 3 x 3 m tower is already the smallest complete room module. Letting even
	# one of its four columns project makes the entire volume read as a small box
	# glued to the side of another building. Only larger plates may spend a
	# measured shallow overhang; compact towers must sit wholly on real bearing.
	if candidate_columns.size() <= 4:
		return false
	if borne.size() * 2 < candidate_columns.size() \
			or not _column_set_is_connected(unborne):
		return false
	# A deep projection over the carved route is not an ordinary timber jetty.
	# It becomes a four-sided stone arcade in the feature transaction, whose
	# authored shell is exactly one 3 m storey high per course. Reject the room
	# composition here unless its complete 3 x 3 m opening can descend by whole
	# courses to one canonical public floor. Letting a half-level mismatch reach
	# assembly produces either a floating stone base or a shell buried through
	# the route, neither of which is a valid repair.
	if not _public_headroom_projection_has_native_arcade(
			unborne, upper_base_y, grid):
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


static func _public_headroom_projection_has_native_arcade(
		unborne_columns: Dictionary, upper_base_y: int,
		grid: WarrenSpatialGrid) -> bool:
	if grid == null or unborne_columns.is_empty():
		return true
	var crosses_public_headroom := false
	for column_value: Variant in unborne_columns.keys():
		var column := column_value as Vector2i
		if grid.use_at(Vector3i(column.x, upper_base_y - 1, column.y)) \
				== WarrenSpatialGrid.Use.PUBLIC_AIR:
			crosses_public_headroom = true
			break
	if not crosses_public_headroom:
		return true
	# The route-spanning support vocabulary closes one complete 2 x 2 lattice
	# footprint on all four sides. Partial strips are brackets, not arcades, and
	# must never be stretched across public air.
	if unborne_columns.size() != 4:
		return false
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column_value: Variant in unborne_columns.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	if maximum - minimum != Vector2i.ONE:
		return false
	var passage_y := upper_base_y
	while passage_y - WarrenSpatialGrid.STOREY_CELLS >= grid.minimum.y:
		var course_base_y := passage_y - WarrenSpatialGrid.STOREY_CELLS
		var complete_public_course := true
		var complete_public_floor := true
		for column_value: Variant in unborne_columns.keys():
			var column := column_value as Vector2i
			for y in range(course_base_y, passage_y):
				if grid.use_at(Vector3i(column.x, y, column.y)) \
						!= WarrenSpatialGrid.Use.PUBLIC_AIR:
					complete_public_course = false
					break
			if not complete_public_course:
				break
			var floor_cell := Vector3i(column.x, course_base_y, column.y)
			if int(grid.face_claim(floor_cell, Vector3i.DOWN).get(
					"kind", -1)) != WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				complete_public_floor = false
		if not complete_public_course:
			return false
		if complete_public_floor:
			return true
		passage_y = course_base_y
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


static func _claimed_room_cells(lineages: Dictionary) -> Dictionary:
	var claimed_cells: Dictionary = {}
	for id_value: Variant in lineages.keys():
		var lineage_id := StringName(id_value)
		var lineage := lineages[lineage_id] as Dictionary
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				claimed_cells[cell] = lineage_id
	return claimed_cells


static func _canonicalize_external_support_parents(
		lineages: Dictionary, grid: WarrenSpatialGrid) -> Dictionary:
	## The construction graph consumes stable lineage/block identities, whereas
	## the bearing proof consumes final occupied cells.  Keep those two views in
	## lockstep after every operation that can merge or terminate a lineage.
	## Only stale EXTERNAL edges are rewritten; ordinary storeys within one
	## surviving lineage retain their authored parent order.
	var owner_by_cell: Dictionary = {}
	for lineage_id_value: Variant in lineages.keys():
		var lineage_id := StringName(lineage_id_value)
		var lineage := lineages[lineage_id] as Dictionary
		for block: Dictionary in lineage.blocks as Array[Dictionary]:
			for cell: Vector3i in block.cells:
				owner_by_cell[cell] = {"lineage_id": lineage_id,
					"source_block_index": int(block.source_block_index),
					"source_storey": int(block.end_storey) - 1}
	var rebound_count := 0
	var retained_support_count := 0
	var unresolved: Array[Dictionary] = []
	var lineage_ids: Array[StringName] = []
	lineage_ids.assign(lineages.keys())
	lineage_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage_id: StringName in lineage_ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		for position in blocks.size():
			var block := blocks[position] as Dictionary
			var stale_parent_id := StringName(block.get(
				"support_parent_lineage_id", &""))
			if stale_parent_id.is_empty():
				continue
			var stale_parent_block := int(block.get(
				"support_parent_source_block_index", -1))
			if lineages.has(stale_parent_id) and _block_position(
					(lineages[stale_parent_id] as Dictionary).blocks \
						as Array[Dictionary], stale_parent_block) >= 0:
				continue
			var candidate_counts: Dictionary = {}
			var candidate_records: Dictionary = {}
			var base_y := (block.origin as Vector3i).y
			var retained_columns := 0
			for column_value: Variant in (block.columns as Dictionary).keys():
				var column := column_value as Vector2i
				var below := Vector3i(column.x, base_y - 1, column.y)
				var support := owner_by_cell.get(
					below, {}) as Dictionary
				var candidate_id := StringName(support.get("lineage_id", &""))
				if candidate_id.is_empty():
					retained_columns += int(grid != null and grid.use_at(below) \
						== WarrenSpatialGrid.Use.STRUCTURAL_VOLUME)
					continue
				if candidate_id == lineage_id:
					continue
				var candidate_key := "%s/%d" % [candidate_id,
					int(support.source_block_index)]
				candidate_counts[candidate_key] = int(
					candidate_counts.get(candidate_key, 0)) + 1
				candidate_records[candidate_key] = support
			var candidate_keys: Array[String] = []
			for candidate_key_value: Variant in candidate_counts.keys():
				candidate_keys.append(String(candidate_key_value))
			candidate_keys.sort_custom(func(a: String, b: String) -> bool:
				var a_count := int(candidate_counts[a])
				var b_count := int(candidate_counts[b])
				return a_count > b_count if a_count != b_count else a < b)
			if candidate_keys.is_empty():
				if retained_columns == (block.columns as Dictionary).size():
					# The source's retained slab is the real complete bearer after
					# its former room lineage yielded.  Make that root explicit instead
					# of preserving a dangling building edge; downstream foundation and
					# support compilation already share this structural-volume fact.
					block.erase("support_parent_lineage_id")
					block.erase("support_parent_source_block_index")
					block.erase("support_parent_source_storey")
					block["retained_support"] = true
					blocks[position] = block
					retained_support_count += 1
					continue
				if unresolved.size() < 16:
					unresolved.append({"lineage_id": lineage_id,
						"source_block_index": int(block.source_block_index),
						"stale_parent_lineage_id": stale_parent_id,
						"stale_parent_source_block_index": stale_parent_block})
				continue
			var selected := candidate_records[candidate_keys[0]] as Dictionary
			block["support_parent_lineage_id"] = StringName(
				selected.lineage_id)
			block["support_parent_source_block_index"] = int(
				selected.source_block_index)
			block["support_parent_source_storey"] = int(
				selected.source_storey)
			blocks[position] = block
			rebound_count += 1
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
	return {"rebound_count": rebound_count,
		"retained_support_count": retained_support_count,
		"unresolved_count": unresolved.size(), "details": unresolved}


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


static func _reserve_composed_roof_space(lineages: Dictionary,
		claimed_cells: Dictionary, owners: Dictionary) -> void:
	for id_value: Variant in lineages:
		var lineage_id := StringName(id_value)
		for block: Dictionary in lineages[lineage_id].blocks:
			_reserve_block_roof_space(block, lineage_id, claimed_cells, owners)
			_reserve_block_underside_space(block, lineage_id, claimed_cells, owners)


static func _reserve_block_underside_space(block: Dictionary, lineage_id: StringName,
		claimed_cells: Dictionary, owners: Dictionary) -> void:
	# The underside is the other owner of the same vertical interface. A later
	# neighboring lower room cannot grow under one strip of an existing upper
	# room and manufacture a partial roof plate around that strip.
	for cell: Vector3i in block.cells:
		var below := cell - Vector3i.UP
		if claimed_cells.has(below):
			continue
		var cell_owners: Dictionary = owners.get(below, {})
		cell_owners[lineage_id] = true
		owners[below] = cell_owners


static func _reserve_block_roof_space(block: Dictionary, lineage_id: StringName,
		claimed_cells: Dictionary, owners: Dictionary) -> void:
	# Every exposed room plate owns its next band before neighboring upper
	# rooms choose their footprint. A silhouette variation cannot spend another
	# building's roof area and leave an unbuildable sliver behind.
	for cell: Vector3i in block.cells:
		var above := cell + Vector3i.UP
		if claimed_cells.has(above):
			continue
		var cell_owners: Dictionary = owners.get(above, {})
		cell_owners[lineage_id] = true
		owners[above] = cell_owners


static func _vary_unmerged_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	# Tall tower-only lineages get first choice of the residual inhabited mass.
	# This is deterministic, but unlike proposal-order packing it is explicitly
	# ordered by the visual defect the pass exists to remove.
	protected_owners = protected_owners.duplicate(true)
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
	_reserve_composed_roof_space(lineages, claimed_cells, protected_owners)
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
			_reserve_block_roof_space(previous, lineage_id, claimed_cells, protected_owners)
			_reserve_block_roof_space(replacement, lineage_id, claimed_cells, protected_owners)
			_reserve_block_underside_space(replacement, lineage_id, claimed_cells, protected_owners)
			previous = replacement
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
	return expanded_count


static func _paired_relief_candidate_is_better(a: Dictionary,
		b: Dictionary) -> bool:
	for key: String in ["unroofable_shoulder_count",
			"strong_registration_count",
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
	for key: String in ["unroofable_shoulder_count",
			"strong_registration_count",
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
		"unroofable_shoulder_count": \
			_transition_unroofable_shoulder_count(previous, current) \
			+ _transition_unroofable_shoulder_count(current, next),
		"strong_registration_count": int(
			registration.strong_registration_count),
		"registered_facade_plane_count": int(
			registration.registered_facade_plane_count),
		"same_kind_count": same_kind,
		"same_ridge_axis_count": same_axis,
	}


static func _vertical_profile_is_better(candidate: Dictionary,
		current: Dictionary) -> bool:
	for key: String in ["unroofable_shoulder_count",
			"strong_registration_count",
			"registered_facade_plane_count", "same_kind_count",
			"same_ridge_axis_count"]:
		if int(candidate[key]) != int(current[key]):
			return int(candidate[key]) < int(current[key])
	return false


static func _transition_unroofable_shoulder_count(lower: Dictionary,
		upper: Dictionary) -> int:
	## Silhouette relief is part of the architectural composition transaction,
	## not permission to manufacture an arbitrary shelf. Score the exact remainder
	## exposed by a changed floorplate before accepting the move, using the same
	## complete-room/compound-gable/lean-to vocabulary as the final roof gate.
	if lower.is_empty() or upper.is_empty() \
			or int(lower.end_storey) != int(upper.start_storey):
		return 0
	var exposed: Dictionary = {}
	for column_value: Variant in (lower.columns as Dictionary).keys():
		if not (upper.columns as Dictionary).has(column_value):
			exposed[column_value] = true
	var count := 0
	for component: Dictionary in _column_components(exposed):
		count += int(not _shoulder_component_is_roofable(component,
			upper.columns as Dictionary, (lower.origin as Vector3i).y))
	return count


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


static func _occupied_bearing_columns_above(current: Dictionary,
		claimed_cells: Dictionary) -> Rect2i:
	## Contacts are construction ownership, including contacts across parcel
	## identities. Their bounding rectangle constrains a complete authored room.
	var cells := current.cells as Array[Vector3i]
	var top := -2147483648
	for cell: Vector3i in cells:
		top = maxi(top, cell.y)
	var columns: Dictionary = {}
	for cell: Vector3i in cells:
		if cell.y == top and claimed_cells.has(cell + Vector3i.UP):
			columns[Vector2i(cell.x, cell.z)] = true
	return _column_bounds(columns)


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
	# TASK F2. This enumeration is the composition's hot core: five kinds x
	# four yaws x a 13 x 13 origin window is ~3400 candidates, and the four
	# passes that call it (merge, couple, vary, serial relief) run it some four
	# hundred times per town. Every gate up to the bearing test is now decided
	# in integer rectangle arithmetic, and the candidate's column DICTIONARY is
	# built only for the few that reach the exact record.
	#
	# The rewrite is exact, not approximate, and rests on one fact: a stamp's
	# columns are always a FILLED rectangle. So (a) `_same_set(stamp, S)` holds
	# exactly when S is that same filled rectangle, which `_columns_as_rect`
	# decides once per set instead of once per candidate; (b) the stamp's
	# rectangle is `origin.xz` plus a constant that depends only on
	# (kind, yaw), so it is hoisted out of the two inner loops; (c)
	# `_intersection_size(stamp, S)` counts the members of S inside the stamp's
	# rectangle, which is the same cardinality read from the other side. Every
	# counter below therefore increments on exactly the candidates it did
	# before, in the same order.
	var current_rect := _columns_as_rect(current_columns)
	var previous_rect := _columns_as_rect(previous_columns)
	var next_columns := (next.columns as Dictionary) if not next.is_empty() \
		else {}
	var next_rect := _columns_as_rect(next_columns)
	var previous_bounds := _column_bounds(previous_columns)
	var next_bounds := _column_bounds(next_columns)
	var current_bounds := _column_bounds(current_columns)
	# FIX ROUND 1, IMPORTANT 2. A non-degenerate `_columns_as_rect` IS the
	# proof that the set fills its bounding box, which is what lets
	# `_rect_intersection_size` answer in closed form.
	var previous_is_filled := previous_rect.size.x > 0
	var next_is_filled := next_rect.size.x > 0
	var current_is_filled := current_rect.size.x > 0
	var origin_y := (current.origin as Vector3i).y
	# TASK F2, two hoists that depend only on the BLOCK.
	#
	# `records_diagnostic` is the one reason the counters below are observable
	# at all: `last_variant_diagnostic` is written only for a block with an
	# interface constraint, and so is `clearance_failures`. For every other
	# block the counters are computed and thrown away, which is what makes it
	# safe to skip origins that provably cannot bear (see the window below).
	# A constrained block keeps the full enumeration and the full diagnostic.
	#
	# `constraints_are_free` is `_candidate_matches_constraints` answered once:
	# with no expandable address, no endpoint constraint and no court contact,
	# it returns true for every candidate, and it was being called ~3400 times
	# per search to say so.
	var records_diagnostic := _block_has_interface_constraint(current)
	var own_lineage_only: Dictionary = {StringName(lineage_id): true}
	# FIX ROUND 1, MINOR 3. These are the same predicate, by De Morgan:
	# `_block_has_interface_constraint` is `expandable OR endpoints OR court`,
	# so its negation is `not expandable AND no endpoints AND no court`, which
	# is precisely what `_candidate_matches_constraints` needs to be free of to
	# return true for every candidate. Stating it once also makes the coupling
	# visible: the blocks that keep the full enumeration below are exactly the
	# blocks whose constraints are worth asking about.
	var constraints_are_free := not records_diagnostic
	var bearing_bounds := _occupied_bearing_columns_above(current, claimed_cells)
	var previous_maximum := previous_bounds.position + previous_bounds.size \
		- Vector2i.ONE
	for kind: StringName in ROOM_KINDS:
		if not allow_tower_promotion and kind == &"tower" \
				and StringName(current.kind) != &"tower":
			continue
		for yaw in 4:
			# The stamp rectangle for origin (0, y, 0); every other origin in
			# this window translates it, because all four yaw cases add
			# `origin.x` and `origin.z` with coefficient one.
			var base_rect := _stamp_rect(kind, Vector3i(0, origin_y, 0), yaw)
			if base_rect.size.x <= 0:
				continue
			var stamp_size := base_rect.size
			var stamp_area := stamp_size.x * stamp_size.y
			var required_overlap := maxi(MIN_BEARING_OVERLAP_COLUMNS,
				ceili(float(stamp_area) * 0.25))
			var x_low := minimum.x - 4
			var x_high := maximum.x + 4
			var z_low := minimum.y - 4
			var z_high := maximum.y + 4
			if not records_diagnostic:
				# A candidate is admitted only with `required_overlap` >= 2
				# columns of bearing on the block below, so its rectangle must
				# at least MEET the lower block's bounding box. Solving that
				# for the origin gives this window; every origin outside it
				# fails `lower_overlap < required_overlap` and appends nothing.
				if previous_bounds.size.x <= 0:
					continue
				x_low = maxi(x_low, previous_bounds.position.x \
					- base_rect.position.x - stamp_size.x + 1)
				x_high = mini(x_high, previous_maximum.x - base_rect.position.x)
				z_low = maxi(z_low, previous_bounds.position.y \
					- base_rect.position.y - stamp_size.y + 1)
				z_high = mini(z_high, previous_maximum.y - base_rect.position.y)
			# A selected upper plate owns every contact with this room. Shrinking
			# the room's domain around those contacts prevents a later silhouette
			# choice from withdrawing another room's bearing.
			if bearing_bounds.has_area():
				x_low = maxi(x_low, bearing_bounds.end.x - base_rect.position.x - stamp_size.x)
				x_high = mini(x_high, bearing_bounds.position.x - base_rect.position.x)
				z_low = maxi(z_low, bearing_bounds.end.y - base_rect.position.y - stamp_size.y)
				z_high = mini(z_high, bearing_bounds.position.y - base_rect.position.y)
			for x in range(x_low, x_high + 1):
				for z in range(z_low, z_high + 1):
					var stamp_position := base_rect.position + Vector2i(x, z)
					if current_rect.size.x > 0 \
							and current_rect.position == stamp_position \
							and current_rect.size == stamp_size:
						continue
					# Origin/yaw pairs can differ while an even-cell stamp occupies
					# exactly the same world columns. Reject in world space: accepting
					# that coordinate illusion recreated the vertical tower this pass
					# exists to remove.
					if previous_rect.size.x > 0 \
							and previous_rect.position == stamp_position \
							and previous_rect.size == stamp_size \
							or next_rect.size.x > 0 \
							and next_rect.position == stamp_position \
							and next_rect.size == stamp_size:
						continue
					shape_count += 1
					var origin := Vector3i(x, origin_y, z)
					if not constraints_are_free \
							and not _candidate_matches_constraints(kind,
								origin, yaw, current):
						continue
					constraint_match_count += 1
					var lower_overlap := _rect_intersection_size(stamp_position,
						stamp_size, previous_columns, previous_bounds,
						previous_is_filled)
					if lower_overlap < required_overlap:
						continue
					bearing_match_count += 1
					var upper_overlap := 0
					if not next.is_empty():
						upper_overlap = _rect_intersection_size(stamp_position,
							stamp_size, next_columns, next_bounds,
							next_is_filled)
						if upper_overlap <= 0:
							continue
					upper_match_count += 1
					var columns := _stamp_columns(kind, origin, yaw)
					var trial := _record(kind, origin, yaw,
						int(current.start_storey), int(current.end_storey))
					if trial.is_empty() or not _record_is_clear_for_lineage(grid,
							protected_owners, claimed_cells, trial, lineage_id) \
							or not _new_projection_has_clearance(trial,
								current_columns, protected_owners, claimed_cells,
								own_lineage_only):
						if records_diagnostic \
								and clearance_failures.size() < 6:
							clearance_failures.append({"kind": kind,
								"origin": origin, "yaw": yaw,
								"failure": _record_clearance_failure(grid,
									protected_owners, claimed_cells, trial,
									lineage_id)})
						continue
					clear_count += 1
					# TASK F2. Three set walks over the stamp become one
					# rectangle count and two identities, because the stamp is a
					# filled rectangle of known area: it is a subset of the
					# current columns exactly when every one of its cells is in
					# them, and the symmetric difference is the two sizes less
					# twice the intersection.
					var old_inside_new := _rect_intersection_size(stamp_position,
						stamp_size, current_columns, current_bounds,
						current_is_filled)
					var expanded := old_inside_new < stamp_area
					var tower_relief := int(StringName(current.kind) == &"tower" \
						and kind != &"tower")
					var kind_change := int(kind != StringName(current.kind))
					var difference := stamp_area + current_columns.size() \
						- 2 * old_inside_new
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
	if records_diagnostic:
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
	var current_shoulder_count := _transition_unroofable_shoulder_count(
		previous, current) + _transition_unroofable_shoulder_count(current, next)
	for candidate_index in mini(candidates.size(),
			MAX_STRUCTURAL_VARIANT_FRONTIER):
		var candidate := candidates[candidate_index] as Dictionary
		var candidate_record := _record(StringName(candidate.kind),
			candidate.origin as Vector3i, int(candidate.yaw_quarters),
			int(current.start_storey), int(current.end_storey))
		var candidate_shoulder_count := \
			_transition_unroofable_shoulder_count(previous, candidate_record) \
			+ _transition_unroofable_shoulder_count(candidate_record, next)
		# Never trade a roofable macro seam for a stronger silhouette. The
		# roof check stays at this bounded accepted-candidate boundary instead of
		# multiplying the much larger geometric enumeration above.
		if candidate_shoulder_count > current_shoulder_count:
			continue
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
	# TASK F2. `_stamp_columns` is only needed to answer the court-contact
	# question, and almost no block has court contact columns. Deriving the
	# stamp for every one of the ~3400 candidates a variant search enumerates,
	# to then iterate an empty dictionary, was the single most repeated wasted
	# call in the composition.
	var court_columns := current.get("court_contact_columns", {}) as Dictionary
	if court_columns.is_empty():
		return true
	var candidate_columns := _stamp_columns(kind, origin, yaw)
	for column_value: Variant in court_columns.keys():
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
		&"row":
			x_radius = 2
			z_radius = 1
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


static func _cell_is_clear_for_lineage(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		cell: Vector3i, lineage_id: StringName) -> bool:
	# TASK F2. `not in [A, B]` builds and discards a two-element Array on
	# every cell of every trial record; the composition tests millions of
	# them. Two comparisons, same predicate.
	var use := grid.use_at(cell)
	if not grid.contains(cell) \
			or use != WarrenSpatialGrid.Use.ALLOCATABLE \
			and use != WarrenSpatialGrid.Use.OUTSIDE:
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


static func _base_band_is_clear_for_lineage(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		columns: Dictionary, band_y: int, lineage_id: StringName) -> bool:
	## The same test as `_record_is_clear_for_lineage`, applied to the record's
	## lowest band alone.
	##
	## TASK F2. It is a strictly NECESSARY condition -- every cell it looks at
	## is one of the record's own cells -- so a candidate it refuses is one the
	## full test would refuse too, and a candidate it admits is still put
	## through the full test unchanged. The point is that it can be asked
	## BEFORE `_record` allocates a whole cells array, which the two support
	## repairs otherwise do for every one of the ~3400 stamps they enumerate.
	for value: Variant in columns.keys():
		var column := value as Vector2i
		if not _cell_is_clear_for_lineage(grid, protected_owners,
				claimed_cells, Vector3i(column.x, band_y, column.y),
				lineage_id):
			return false
	return true


static func _record_is_clear_for_lineage(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		record: Dictionary, lineage_id: StringName) -> bool:
	for cell: Vector3i in record.cells:
		if not _cell_is_clear_for_lineage(grid, protected_owners,
				claimed_cells, cell, lineage_id):
			return false
	return true


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
	var size := maximum - minimum + Vector2i.ONE
	if columns.size() != size.x * size.y:
		return {}
	for x in range(minimum.x, maximum.x + 1):
		for z in range(minimum.y, maximum.y + 1):
			if not columns.has(Vector2i(x, z)):
				return {}
	var kind := &"tower" if size == Vector2i(2, 2) \
		else &"slim" if size in [Vector2i(2, 4), Vector2i(4, 2)] \
		else &"building" if size == Vector2i(4, 4) \
		else &"long" if size in [Vector2i(4, 6), Vector2i(6, 4)] else &""
	if not kind.is_empty():
		var yaw := int(size.x > size.y)
		var local_minimum := Vector2i(-1, -1) if kind == &"tower" \
			else Vector2i(-1, -2) if kind == &"slim" \
			else Vector2i(-2, -2) if kind == &"building" \
			else Vector2i(-2, -3)
		var local_size := Vector2i(2, 2) if kind == &"tower" \
			else Vector2i(2, 4) if kind == &"slim" \
			else Vector2i(4, 4) if kind == &"building" \
			else Vector2i(4, 6)
		var local_maximum := local_minimum + local_size - Vector2i.ONE
		var origin := Vector3i(minimum.x - local_minimum.x, y,
			minimum.y - local_minimum.y) if yaw == 0 else Vector3i(
			minimum.x - local_minimum.y, y,
			minimum.y + local_maximum.x)
		return {"kind": kind, "origin": origin,
			"yaw_quarters": yaw, "columns": columns}
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
		var cells_key := Vector4i(_stamp_slot(kind, yaw), room_origin.x,
			room_origin.y, room_origin.z)
		if not _stamp_cells_cache.has(cells_key):
			_stamp_cells_cache[cells_key] = WarrenRoomStamp \
				.expected_private_cells(kind, room_origin, yaw)
		cells.append_array(_stamp_cells_cache[cells_key] as Array[Vector3i])
	return {"kind": kind, "origin": origin, "yaw_quarters": yaw,
		"start_storey": start_storey, "end_storey": end_storey,
		"columns": columns, "cells": cells}


static func _stamp_slot(kind: StringName, yaw: int) -> int:
	## The (kind, yaw) half of a memo key as ONE small integer, so the memo can
	## be keyed by a Vector4i instead of a formatted String.
	##
	## TASK F2. `_stamp_columns` is the innermost call of the variant
	## enumeration -- `_volumetric_variant_stamp` walks five kinds x four yaws x
	## a 13 x 13 origin window, some four hundred times per town -- and the old
	## key built and hashed a String on every one of those million-odd probes.
	## The slot is `kind index * 4 + yaw`. Slot 0 means "not a stampable
	## (kind, yaw)" and is never a STORED key: `_stamp_columns` writes its memo
	## only after its own `match kind` and `0 <= yaw <= 3` guards have passed,
	## and `_record` writes its memo only after `_stamp_columns` came back
	## non-empty. A slot-0 probe therefore always misses and falls through to
	## the same empty result the String key produced.
	var index := KIND_SLOTS.get(kind, 0) as int
	if index == 0 or yaw < 0 or yaw > 3:
		return 0
	return index * 4 + yaw


static func _stamp_rect(kind: StringName, origin: Vector3i,
		yaw: int) -> Rect2i:
	## The world rectangle an authored room stamp fills, or a zero-size rect
	## when (kind, yaw) is not stampable.
	##
	## TASK F2. This is the arithmetic `_stamp_columns` always did; it is a
	## function of its own now so the variant enumeration can reason about a
	## candidate's footprint WITHOUT building its column dictionary, and so
	## that the two can never disagree about where a stamp lands. Note every
	## yaw case adds `origin.x` and `origin.z` with coefficient one, which is
	## what lets the enumeration hoist the rect out of its two inner loops.
	var minimum := Vector2i.ZERO
	var size := Vector2i.ZERO
	match kind:
		&"tower":
			minimum = Vector2i(-1, -1)
			size = Vector2i(2, 2)
		&"slim":
			minimum = Vector2i(-1, -2)
			size = Vector2i(2, 4)
		&"row":
			minimum = Vector2i(-2, -1)
			size = Vector2i(4, 2)
		&"building":
			minimum = Vector2i(-2, -2)
			size = Vector2i(4, 4)
		&"long":
			minimum = Vector2i(-2, -3)
			size = Vector2i(4, 6)
		_:
			return Rect2i()
	if yaw < 0 or yaw > 3:
		return Rect2i()
	var maximum := minimum + size - Vector2i.ONE
	var world_minimum := Vector2i.ZERO
	match yaw:
		0:
			world_minimum = Vector2i(origin.x + minimum.x,
				origin.z + minimum.y)
		1:
			world_minimum = Vector2i(origin.x + minimum.y,
				origin.z - maximum.x)
		2:
			world_minimum = Vector2i(origin.x - maximum.x,
				origin.z - maximum.y)
		3:
			world_minimum = Vector2i(origin.x - maximum.y,
				origin.z + minimum.x)
	return Rect2i(world_minimum, size if posmod(yaw, 2) == 0 \
		else Vector2i(size.y, size.x))


static func _columns_as_rect(columns: Dictionary) -> Rect2i:
	## The rectangle a column set fills EXACTLY, or a zero-size rect when the
	## set is empty or leaves a hole. A set whose bounding box has exactly as
	## many cells as the set has members, and every member inside that box,
	## fills it -- so the count test is the whole proof.
	if columns.is_empty():
		return Rect2i()
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var size := maximum - minimum + Vector2i.ONE
	if columns.size() != size.x * size.y:
		return Rect2i()
	return Rect2i(minimum, size)


static func _column_bounds(columns: Dictionary) -> Rect2i:
	## The bounding rectangle of a column set -- no claim that the set fills
	## it. Zero size means empty, which no stamp rectangle can meet.
	if columns.is_empty():
		return Rect2i()
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for value: Variant in columns.keys():
		var column := value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


static func _rect_intersection_size(position: Vector2i, size: Vector2i,
		columns: Dictionary, bounds: Rect2i,
		bounds_is_filled: bool = false) -> int:
	## How many members of `columns` fall inside the rectangle. Identical to
	## `_intersection_size(stamp_columns, columns)` -- the same intersection
	## counted from the other side -- without building the stamp's dictionary
	## or hashing a Vector2i per cell. `bounds` is the set's own bounding box,
	## and a rectangle that misses it intersects nothing.
	##
	## FIX ROUND 1, IMPORTANT 2. `bounds_is_filled` says the caller has already
	## proved with `_columns_as_rect` that the set IS its bounding rectangle,
	## with no hole in it. Two filled rectangles meet in a rectangle, so the
	## count is that overlap's AREA and the walk is not needed at all. This is
	## the same proof `b23c701` and `da264dc` rest on, applied to the other
	## side of the intersection: the walk stays as the fallback for a set that
	## really does have a hole, where the area would over-count.
	if bounds.size.x <= 0:
		return 0
	var maximum := position + size - Vector2i.ONE
	var bounds_maximum := bounds.position + bounds.size - Vector2i.ONE
	var overlap_x := mini(maximum.x, bounds_maximum.x) \
		- maxi(position.x, bounds.position.x) + 1
	var overlap_y := mini(maximum.y, bounds_maximum.y) \
		- maxi(position.y, bounds.position.y) + 1
	if overlap_x <= 0 or overlap_y <= 0:
		return 0
	if bounds_is_filled:
		return overlap_x * overlap_y
	var count := 0
	for value: Variant in columns.keys():
		var column := value as Vector2i
		count += int(column.x >= position.x and column.x <= maximum.x \
			and column.y >= position.y and column.y <= maximum.y)
	return count


static func _stamp_columns(kind: StringName, origin: Vector3i,
		yaw: int) -> Dictionary:
	var cache_key := Vector4i(_stamp_slot(kind, yaw), origin.x, origin.z, 0)
	if _stamp_columns_cache.has(cache_key):
		return _stamp_columns_cache[cache_key] as Dictionary
	var out: Dictionary = {}
	var rect := _stamp_rect(kind, origin, yaw)
	if rect.size.x <= 0:
		return out
	var world_minimum := rect.position
	var world_size := rect.size
	for x in range(world_minimum.x, world_minimum.x + world_size.x):
		for z in range(world_minimum.y, world_minimum.y + world_size.y):
			out[Vector2i(x, z)] = true
	_stamp_columns_cache[cache_key] = out
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
