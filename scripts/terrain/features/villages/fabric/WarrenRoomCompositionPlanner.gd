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
const MIN_BEARING_OVERLAP_COLUMNS := 2

const ROOM_KINDS: Array[StringName] = [
	&"long", &"building", &"slim", &"tower",
]

static var last_failure := ""
static var last_audit: Dictionary = {}
static var last_merge_diagnostic: Dictionary = {}
static var last_variant_diagnostic: Dictionary = {}


static func solve(grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], offsets_by_parcel: Dictionary,
		forced_offsets_by_parcel: Dictionary, market_reservation: Dictionary,
		protected_owners: Dictionary, skywalk_forced_offsets: Dictionary,
		skywalk_reservations: Array[Dictionary], world_seed: int) -> Dictionary:
	last_failure = ""
	last_audit = {}
	last_merge_diagnostic = {}
	last_variant_diagnostic = {}
	if grid == null or volume == null or proposals.is_empty():
		last_failure = "missing grid, volume, or room proposals"
		return {}
	var court_neighbors := _courtyard_neighbor_cells(volume)
	var market_backing := market_reservation.get("backing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var skywalk_constraints := _skywalk_constraints_by_parcel(
		skywalk_reservations)
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
			court_neighbors, market_backing)
		if blocks.is_empty():
			continue
		var required_through := -1
		for block_index in blocks.size():
			if bool((blocks[block_index] as Dictionary).forced):
				required_through = block_index
		input_storeys += int(proposal.storeys)
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
	var merged_count := _merge_upper_lineages(lineages, grid,
		protected_owners, world_seed)
	var coupled_count := _couple_upper_lineages(lineages, grid,
		protected_owners, world_seed)
	var expanded_count := _vary_unmerged_lineages(lineages, grid,
		protected_owners, world_seed)
	last_merge_diagnostic["variant_diagnostic"] = \
		last_variant_diagnostic.duplicate(true)
	var truncated_tower_storeys := _truncate_unpaired_towers(lineages)
	var audit := _audit(lineages, input_storeys, merged_count,
		coupled_count, expanded_count, truncated_tower_storeys)
	last_audit = audit.duplicate(true)
	return {"lineages": lineages, "audit": audit}


static func _source_blocks(proposal: Dictionary,
		offsets: Array[Vector2i], forced_offsets: Dictionary,
		skywalk_forced_offsets: Dictionary,
		skywalk_constraints: Array, court_neighbors: Dictionary,
		market_backing: Vector3i) \
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
	for block in offsets.size():
		var start_storey := block * 2
		if start_storey >= storeys:
			break
		var end_storey := mini(storeys, start_storey + 2)
		var offset := offsets[block]
		var origin := source_origin + Vector3i(offset.x,
			start_storey * WarrenSpatialGrid.STOREY_CELLS, offset.y)
		var home_origin := source_origin + Vector3i(0,
			start_storey * WarrenSpatialGrid.STOREY_CELLS, 0)
		var record := _record(kind, origin, yaw, start_storey, end_storey)
		if record.is_empty():
			return [] as Array[Dictionary]
		var forced := forced_offsets.has(block)
		var block_skywalk_constraints: Array[Dictionary] = []
		for constraint_value: Variant in skywalk_constraints:
			var constraint := constraint_value as Dictionary
			var endpoint := constraint.cell as Vector3i
			if endpoint.y >= origin.y \
					and endpoint.y < origin.y + (end_storey - start_storey) \
						* WarrenSpatialGrid.STOREY_CELLS:
				block_skywalk_constraints.append(constraint)
		var structural_forced := block == 0 \
			or skywalk_forced_offsets.has(block) \
				and block_skywalk_constraints.is_empty()
		var addressed := addressed_storey >= start_storey \
			and addressed_storey < end_storey
		for cell: Vector3i in record.cells:
			if cell == market_backing or court_neighbors.has(cell):
				forced = true
				structural_forced = true
				break
		record["forced"] = forced
		record["address_expandable"] = addressed and not structural_forced
		record["feature_endpoint_constraints"] = block_skywalk_constraints
		record["address_threshold"] = threshold
		record["address_frontage"] = frontage
		record["original_kind"] = kind
		record["original_origin"] = origin
		record["original_yaw_quarters"] = yaw
		record["home_origin"] = home_origin
		record["home_columns"] = _stamp_columns(kind, home_origin, yaw)
		record["source_block_index"] = block
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
			if bool(block.forced) and not _block_allows_recomposition(block):
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
							"tie": tie,
						})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.tall_tower_relief) != int(b.tall_tower_relief):
			return int(a.tall_tower_relief) > int(b.tall_tower_relief)
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
				"feature_endpoint_constraints",
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
					or bool(block.forced) and not _block_allows_recomposition(
						block):
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
							"height": maxi(int(left.height), int(right.height)),
							"score": score, "tie": tie})
	pair_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.interface_tower_relief) != int(b.interface_tower_relief):
			return int(a.interface_tower_relief) \
				> int(b.interface_tower_relief)
		if int(a.tower_relief) != int(b.tower_relief):
			return int(a.tower_relief) > int(b.tower_relief)
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
		world_seed: int) -> Array[Dictionary]:
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
					var score := tower_relief * 7000 + kind_change * 1800 \
						+ int(expanded) * 700 + difference * 55 \
						+ lower_overlap * 22 + upper_overlap * 12 + scale_bonus
					var tie := posmod(Helper._mix64(world_seed \
						^ String(record.key).hash() * 31 ^ kind.hash() * 47 \
						^ x * 73856093 ^ z * 19349663 ^ yaw * 83492791),
						1000003)
					out.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"tower_relief": tower_relief, "score": score,
						"tie": tie})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	if out.size() > 18:
		out.resize(18)
	return out


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
	var claimed_cells: Dictionary = {}
	var expanded_count := 0
	for lineage_id: StringName in ids:
		var lineage := lineages[lineage_id] as Dictionary
		var blocks := lineage.blocks as Array[Dictionary]
		if blocks.size() < 2:
			continue
		var previous := blocks[0] as Dictionary
		for block in range(1, blocks.size()):
			var current := blocks[block] as Dictionary
			if bool(current.forced) and not _block_allows_recomposition(
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
			replacement["merged"] = false
			replacement["expanded"] = bool(variant.expanded)
			blocks[block] = replacement
			for cell: Vector3i in replacement.cells:
				claimed_cells[cell] = lineage_id
			expanded_count += int(bool(variant.expanded))
			previous = replacement
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
	return expanded_count


static func _volumetric_variant_stamp(grid: WarrenSpatialGrid,
		protected_owners: Dictionary, claimed_cells: Dictionary,
		lineage_id: StringName, current: Dictionary, previous: Dictionary,
		next: Dictionary, block_index: int, world_seed: int) -> Dictionary:
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
					var score := tower_relief * 6000 + kind_change * 1800 \
						+ int(expanded) * 900 + cap_scale_bonus \
						+ difference * 45 + lower_overlap * 25 \
						+ upper_overlap * 18 + old_inside_new * 6 \
						- maxi(columns.size() - 16, 0) * 30
					var tie := posmod(Helper._mix64(world_seed \
						^ String(lineage_id).hash() * 31 \
						^ block_index * 0x45d9f3b ^ kind.hash() * 47 \
						^ x * 73856093 ^ z * 19349663 ^ yaw * 83492791),
						1000003)
					candidates.append({"kind": kind, "origin": origin,
						"yaw_quarters": yaw, "columns": columns,
						"expanded": expanded, "score": score, "tie": tie})
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
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.tie) < int(b.tie))
	return candidates[0]


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
	## A logical cell is 1.5 m wide, while reviewed facade/eave envelopes can
	## project several decimetres beyond it. New cantilever columns therefore
	## keep one fine-cell broad-phase halo from unrelated provisional rooms.
	## Existing source columns retain their authored party-wall behavior.
	for cell: Vector3i in record.cells:
		if source_columns.has(Vector2i(cell.x, cell.z)):
			continue
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var neighbor := cell + Vector3i(dx, 0, dz)
				if claimed_cells.has(neighbor):
					var claimed_owner: Variant = claimed_cells[neighbor]
					if not (claimed_owner is StringName or claimed_owner is String) \
							or not allowed_owner_ids.has(StringName(claimed_owner)):
						return false
				var owners := protected_owners.get(neighbor, {}) as Dictionary
				for owner_value: Variant in owners.keys():
					var owner_id := StringName(owner_value)
					if allowed_owner_ids.has(owner_id):
						continue
					var allowed := false
					var allowance: Variant = owners[owner_value]
					if allowance is Dictionary:
						for allowed_id_value: Variant in allowed_owner_ids.keys():
							if (allowance as Dictionary).has(StringName(
									allowed_id_value)):
								allowed = true
								break
					if not allowed:
						return false
	return true


static func _candidate_matches_address(kind: StringName, origin: Vector3i,
		yaw: int, current: Dictionary) -> bool:
	var threshold := current.get("address_threshold",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var frontage := current.get("address_frontage", Vector3i.ZERO) as Vector3i
	var local_door := Vector3i.ZERO
	match kind:
		&"tower":
			local_door = Vector3i(0, 0, 0)
		&"slim":
			local_door = Vector3i(0, 0, 1)
		&"building":
			local_door = Vector3i(-1, 0, 1)
		&"long":
			local_door = Vector3i(-1, 0, 2)
		_:
			return false
	if threshold.x == 2147483647:
		return false
	var addressed_origin := Vector3i(origin.x, threshold.y, origin.z)
	return FabricRecipe.transform_cell(local_door, addressed_origin, yaw) \
		== threshold and FabricRecipe.transform_direction(Vector3i.BACK, yaw) \
		== frontage


static func _block_allows_recomposition(block: Dictionary) -> bool:
	return bool(block.get("address_expandable", false)) \
		or not (block.get("feature_endpoint_constraints", []) as Array).is_empty()


static func _block_has_interface_constraint(block: Dictionary) -> bool:
	return bool(block.get("address_expandable", false)) \
		or not (block.get("feature_endpoint_constraints", []) as Array).is_empty()


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
	return true


static func _candidate_has_facade_endpoint(kind: StringName,
		origin: Vector3i, yaw: int, endpoint: Vector3i,
		facing: Vector3i) -> bool:
	var minimum := Vector2i.ZERO
	var size := Vector2i.ZERO
	match kind:
		&"tower":
			minimum = Vector2i(-1, -1)
			size = Vector2i(2, 2)
		&"slim":
			minimum = Vector2i(-1, -2)
			size = Vector2i(2, 4)
		&"building":
			minimum = Vector2i(-2, -2)
			size = Vector2i(4, 4)
		&"long":
			minimum = Vector2i(-2, -3)
			size = Vector2i(4, 6)
		_:
			return false
	var maximum := minimum + size - Vector2i.ONE
	for local_z in range(minimum.y, maximum.y + 1):
		for local_x in range(minimum.x, maximum.x + 1):
			for local_facing: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				var on_side := local_facing == Vector3i.LEFT \
						and local_x == minimum.x \
					or local_facing == Vector3i.RIGHT \
						and local_x == maximum.x \
					or local_facing == Vector3i.FORWARD \
						and local_z == minimum.y \
					or local_facing == Vector3i.BACK \
						and local_z == maximum.y
				if not on_side or FabricRecipe.transform_direction(
						local_facing, yaw) != facing:
					continue
				var local_cell := Vector3i(local_x, 0, local_z)
				var cell_origin := Vector3i(origin.x, endpoint.y, origin.z)
				if FabricRecipe.transform_cell(local_cell, cell_origin, yaw) \
						== endpoint:
					return true
	return false


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
					>= floori(float(MAX_UNPAIRED_TOWER_STOREYS) / 2.0) \
				or not _lineage_is_tower_only(blocks):
			continue
		while not blocks.is_empty() \
				and int((blocks[-1] as Dictionary).start_storey) \
					>= MAX_UNPAIRED_TOWER_STOREYS:
			blocks.pop_back()
		var retained := _lineage_storey_count(blocks)
		truncated += storeys - retained
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage
	return truncated


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
	var four_storey_tower_run_ids: Array[StringName] = []
	var four_storey_tower_run_details: Array[Dictionary] = []
	var max_identical_tower_run := 0
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
		for block: Dictionary in blocks:
			kinds[StringName(block.kind)] = true
			varied_blocks += int(StringName(block.kind) \
				!= StringName(block.original_kind) \
				or block.origin != block.original_origin \
				or int(block.yaw_quarters) \
					!= int(block.original_yaw_quarters))
			merged_blocks += int(bool(block.merged))
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
			if storeys >= TALL_LINEAGE_STOREYS:
				tall_tower_only_ids.append(lineage_id)
			var identical_run := _longest_identical_floorplate_run(blocks)
			max_identical_tower_run = maxi(max_identical_tower_run,
				identical_run)
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
		"four_storey_tower_run_lineage_ids": four_storey_tower_run_ids,
		"four_storey_tower_run_details": four_storey_tower_run_details,
		"max_identical_tower_floorplate_run_storeys": \
			max_identical_tower_run,
		"truncated_tower_storey_count": truncated_tower_storeys,
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
