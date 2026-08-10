class_name WarrenRoomCompositionPlanner
extends RefCounted

## Re-partitions the generic parcel envelopes as a genuinely three-dimensional
## room grammar. Parcels still provide exact terrain roots, doors, and feature
## sockets, but they are not treated as immutable vertical prisms: compatible
## narrow columns may hand their upper mass to one wider room lineage, and each
## unforced two-storey band may select a different measured room plate.
##
## Every output plate is a subset of the already-qualified source mass owned by
## one or two input blocks. The planner therefore cannot invent a podium, fill
## public air, or trespass on a hero-feature reservation. Secondary lineages are
## truncated only above their last mandatory interface; the receiving room
## overlaps both lower plates and remains physically borne by the retained mass.
const TALL_LINEAGE_STOREYS := 4
const EXTRUDED_LINEAGE_STOREYS := 5
const MAX_UNPAIRED_TOWER_STOREYS := 4
const MIN_BEARING_OVERLAP_COLUMNS := 2

const ROOM_KINDS: Array[StringName] = [
	&"long", &"building", &"slim", &"tower",
]

static var last_failure := ""
static var last_audit: Dictionary = {}
static var last_merge_diagnostic: Dictionary = {}


static func solve(grid: WarrenSpatialGrid, volume: WarrenVolumePlan,
		proposals: Array[Dictionary], offsets_by_parcel: Dictionary,
		forced_offsets_by_parcel: Dictionary, market_reservation: Dictionary,
		protected_owners: Dictionary, world_seed: int) -> Dictionary:
	last_failure = ""
	last_audit = {}
	last_merge_diagnostic = {}
	if grid == null or volume == null or proposals.is_empty():
		last_failure = "missing grid, volume, or room proposals"
		return {}
	var court_neighbors := _courtyard_neighbor_cells(volume)
	var market_backing := market_reservation.get("backing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
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
		var blocks := _source_blocks(proposal, offsets, forced,
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
	_vary_unmerged_lineages(lineages, world_seed)
	var truncated_tower_storeys := _truncate_unpaired_towers(lineages)
	var audit := _audit(lineages, input_storeys, merged_count,
		truncated_tower_storeys)
	last_audit = audit.duplicate(true)
	return {"lineages": lineages, "audit": audit}


static func _source_blocks(proposal: Dictionary,
		offsets: Array[Vector2i], forced_offsets: Dictionary,
		court_neighbors: Dictionary, market_backing: Vector3i) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var source_origin := proposal.origin as Vector3i
	var storeys := int(proposal.storeys)
	var kind := StringName(proposal.kind)
	var yaw := int(proposal.yaw_quarters)
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
		if not forced:
			for cell: Vector3i in record.cells:
				if cell == market_backing or court_neighbors.has(cell):
					forced = true
					break
		record["forced"] = forced
		record["original_kind"] = kind
		record["original_origin"] = origin
		record["original_yaw_quarters"] = yaw
		record["home_origin"] = home_origin
		record["home_columns"] = _stamp_columns(kind, home_origin, yaw)
		record["source_block_index"] = block
		record["merged"] = false
		out.append(record)
	return out


static func _merge_upper_lineages(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int) -> int:
	var enough_blocks_count := 0
	var unforced_count := 0
	var aligned_y_count := 0
	var exact_union_count := 0
	var gap_bridge_count := 0
	var yielding_count := 0
	var ids: Array[StringName] = []
	ids.assign(lineages.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	var candidates: Array[Dictionary] = []
	for left_index in ids.size():
		for right_index in range(left_index + 1, ids.size()):
			var left_id := ids[left_index]
			var right_id := ids[right_index]
			var left := lineages[left_id] as Dictionary
			var right := lineages[right_id] as Dictionary
			var left_blocks := left.blocks as Array[Dictionary]
			var right_blocks := right.blocks as Array[Dictionary]
			if left_blocks.size() < 2 or right_blocks.size() < 2:
				continue
			enough_blocks_count += 1
			var left_upper := left_blocks[1] as Dictionary
			var right_upper := right_blocks[1] as Dictionary
			if bool(left_upper.forced) or bool(right_upper.forced):
				continue
			unforced_count += 1
			if (left_upper.origin as Vector3i).y \
					!= (right_upper.origin as Vector3i).y:
				continue
			aligned_y_count += 1
			# Pair from the source-mass plates, not from the old one-cell
			# extrusion offsets. Those offsets were only a collision fallback;
			# allowing them to define adjacency makes two cells that really tile
			# one wider room appear diagonally unrelated.
			var left_home := left_upper.home_columns as Dictionary
			var right_home := right_upper.home_columns as Dictionary
			var union := left_home.duplicate()
			for value: Variant in right_home.keys():
				union[value] = true
			if union.size() <= maxi(left_home.size(), right_home.size()):
				continue
			var merged_stamp := _exact_stamp_for_columns(union,
				(left_upper.origin as Vector3i).y)
			if merged_stamp.is_empty():
				merged_stamp = _bridge_stamp_for_blocks(grid, protected_owners,
					left_id, right_id, left_upper, right_upper, world_seed)
				gap_bridge_count += int(not merged_stamp.is_empty())
			if merged_stamp.is_empty():
				continue
			exact_union_count += int(_same_set(
				merged_stamp.columns as Dictionary, union))
			yielding_count += 1
			var primary_id := left_id
			var secondary_id := right_id
			var left_storeys := _lineage_storey_count(left_blocks)
			var right_storeys := _lineage_storey_count(right_blocks)
			if right_storeys > left_storeys or right_storeys == left_storeys \
					and posmod(Helper._mix64(world_seed \
						^ String(left_id).hash() ^ String(right_id).hash()), 2) == 1:
				primary_id = right_id
				secondary_id = left_id
			candidates.append({
				"primary_id": primary_id,
				"secondary_id": secondary_id,
				"merged_stamp": merged_stamp,
				"height": maxi(_lineage_storey_count(left_blocks),
					_lineage_storey_count(right_blocks)),
				"area": union.size(),
				"tie": posmod(Helper._mix64(world_seed \
					^ String(primary_id).hash() * 31 \
					^ String(secondary_id).hash() * 47), 1000003),
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.height) != int(b.height):
			return int(a.height) > int(b.height)
		if int(a.area) != int(b.area):
			return int(a.area) > int(b.area)
		return int(a.tie) < int(b.tie))
	var used: Dictionary = {}
	var merged_count := 0
	for candidate: Dictionary in candidates:
		var primary_id := StringName(candidate.primary_id)
		var secondary_id := StringName(candidate.secondary_id)
		if used.has(primary_id) or used.has(secondary_id):
			continue
		var primary := lineages[primary_id] as Dictionary
		var secondary := lineages[secondary_id] as Dictionary
		var primary_blocks := primary.blocks as Array[Dictionary]
		var secondary_blocks := secondary.blocks as Array[Dictionary]
		var merged := candidate.merged_stamp as Dictionary
		var first := primary_blocks[1] as Dictionary
		first = _record(StringName(merged.kind), merged.origin as Vector3i,
			int(merged.yaw_quarters), int(first.start_storey),
			int(first.end_storey))
		first["forced"] = false
		first["original_kind"] = (primary_blocks[1] as Dictionary).original_kind
		first["original_origin"] = (primary_blocks[1] as Dictionary).original_origin
		first["original_yaw_quarters"] = (primary_blocks[1] \
			as Dictionary).original_yaw_quarters
		first["home_origin"] = (primary_blocks[1] as Dictionary).home_origin
		first["home_columns"] = (primary_blocks[1] \
			as Dictionary).home_columns
		first["source_block_index"] = (primary_blocks[1] \
			as Dictionary).source_block_index
		first["merged"] = true
		primary_blocks[1] = first
		var previous := first
		for block in range(2, primary_blocks.size()):
			var current := primary_blocks[block] as Dictionary
			if bool(current.forced):
				previous = current
				continue
			var allowed := (current.home_columns as Dictionary).duplicate()
			if block < secondary_blocks.size():
				var other := secondary_blocks[block] as Dictionary
				if (other.origin as Vector3i).y == (current.origin as Vector3i).y:
					for value: Variant in (other.home_columns \
							as Dictionary).keys():
						allowed[value] = true
			var variant := _variant_stamp(allowed, previous,
				(current.origin as Vector3i).y, block, world_seed,
				String(primary_id).hash())
			if not variant.is_empty():
				var replacement := _record(StringName(variant.kind),
					variant.origin as Vector3i, int(variant.yaw_quarters),
					int(current.start_storey), int(current.end_storey))
				replacement["forced"] = false
				replacement["original_kind"] = current.original_kind
				replacement["original_origin"] = current.original_origin
				replacement["original_yaw_quarters"] = \
					current.original_yaw_quarters
				replacement["home_origin"] = current.home_origin
				replacement["home_columns"] = current.home_columns
				replacement["source_block_index"] = current.source_block_index
				replacement["merged"] = true
				primary_blocks[block] = replacement
				previous = replacement
		secondary_blocks.remove_at(1)
		if secondary_blocks.size() > 1:
			var resumed := secondary_blocks[1] as Dictionary
			resumed["support_parent_lineage_id"] = primary_id
			resumed["support_parent_source_storey"] = \
				int(first.end_storey) - 1
			resumed["support_parent_source_block_index"] = \
				int(first.source_block_index)
			secondary_blocks[1] = resumed
		primary["blocks"] = primary_blocks
		primary["paired_primary"] = true
		primary["paired_with"] = secondary_id
		secondary["blocks"] = secondary_blocks
		secondary["paired_secondary"] = true
		secondary["paired_with"] = primary_id
		lineages[primary_id] = primary
		lineages[secondary_id] = secondary
		used[primary_id] = true
		used[secondary_id] = true
		merged_count += 1
	last_merge_diagnostic = {
		"enough_blocks_pair_count": enough_blocks_count,
		"unforced_pair_count": unforced_count,
		"aligned_y_pair_count": aligned_y_count,
		"exact_union_pair_count": exact_union_count,
		"gap_bridge_pair_count": gap_bridge_count,
		"yielding_pair_count": yielding_count,
		"candidate_count": candidates.size(),
		"selected_count": merged_count,
	}
	return merged_count


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
				or grid.use_at(cell) != WarrenSpatialGrid.Use.ALLOCATABLE:
			return false
		for owner_value: Variant in (protected_owners.get(cell, {}) \
				as Dictionary).keys():
			var owner_id := StringName(owner_value)
			if owner_id not in [left_id, right_id]:
				return false
	return true


static func _vary_unmerged_lineages(lineages: Dictionary,
		world_seed: int) -> void:
	for id_value: Variant in lineages.keys():
		var lineage_id := StringName(id_value)
		var lineage := lineages[lineage_id] as Dictionary
		if bool(lineage.paired_secondary):
			continue
		var blocks := lineage.blocks as Array[Dictionary]
		if blocks.size() < 2:
			continue
		var previous := blocks[0] as Dictionary
		for block in range(1, blocks.size()):
			var current := blocks[block] as Dictionary
			if bool(current.forced) or bool(current.merged):
				previous = current
				continue
			var variant := _variant_stamp(current.columns as Dictionary,
				previous, (current.origin as Vector3i).y, block, world_seed,
				String(lineage_id).hash())
			if variant.is_empty():
				previous = current
				continue
			var replacement := _record(StringName(variant.kind),
				variant.origin as Vector3i, int(variant.yaw_quarters),
				int(current.start_storey), int(current.end_storey))
			replacement["forced"] = false
			replacement["original_kind"] = current.original_kind
			replacement["original_origin"] = current.original_origin
			replacement["original_yaw_quarters"] = \
				current.original_yaw_quarters
			replacement["home_origin"] = current.home_origin
			replacement["home_columns"] = current.home_columns
			replacement["source_block_index"] = current.source_block_index
			replacement["merged"] = false
			blocks[block] = replacement
			previous = replacement
		lineage["blocks"] = blocks
		lineages[lineage_id] = lineage


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
				or int(lineage.required_through_block) >= 2 \
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
		merged_count: int, truncated_tower_storeys: int) -> Dictionary:
	var output_storeys := 0
	var mixed_tall := 0
	var extruded_tall := 0
	var max_tower_only := 0
	var varied_blocks := 0
	var merged_blocks := 0
	for lineage_value: Variant in lineages.values():
		var lineage := lineage_value as Dictionary
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
		if storeys >= EXTRUDED_LINEAGE_STOREYS and kinds.size() <= 1 \
				and not bool(lineage.paired_primary) \
				and not bool(lineage.paired_secondary):
			extruded_tall += 1
		if _lineage_is_tower_only(blocks) \
				and not bool(lineage.paired_primary) \
				and not bool(lineage.paired_secondary):
			max_tower_only = maxi(max_tower_only, storeys)
	return {
		"source_composition_lineage_count": lineages.size(),
		"input_room_storey_count": input_storeys,
		"output_room_storey_count": output_storeys,
		"merged_upper_composition_count": merged_count,
		"merged_upper_room_block_count": merged_blocks,
		"varied_room_block_count": varied_blocks,
		"mixed_kind_tall_lineage_count": mixed_tall,
		"extruded_tall_lineage_count": extruded_tall,
		"max_tower_only_lineage_storeys": max_tower_only,
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
