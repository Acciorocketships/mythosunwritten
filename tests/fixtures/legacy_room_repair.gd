extends WarrenRoomCompositionPlanner

## Historical repair algorithms retained only for their existing regression
## fixtures. Production constructs complete rooms without these cleanup passes.

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


static func _repair_global_unroofable_exposures(lineages: Dictionary,
		grid: WarrenSpatialGrid, protected_owners: Dictionary,
		world_seed: int, extra_occupied: Dictionary = {}) -> int:
	## First move a complete blocker room to another measured, constraint-preserving
	## stamp when that strictly reduces the final roof defect count. If no such
	## room exists, remove the smallest optional upper suffix. The existing crown
	## predicate protects identities and explicit support parents; the geometric
	## cut proof protects incidental cross-lineage bearing with no formal edge.
	var repaired := 0
	for _iteration in 16:
		var audit := _global_exposed_roof_audit(lineages, extra_occupied)
		var before_count := int(audit.unroofable_global_roof_component_count)
		if before_count == 0:
			break
		var details := audit.details as Array[Dictionary]
		if details.is_empty():
			break
		var blocker_records: Array[Dictionary] = []
		blocker_records.assign(details[0].blockers as Array)
		blocker_records.append({
			"lineage_id": StringName(details[0].lineage_id),
			"block_position": int(details[0].block_position),
		})
		var recomposed := false
		for blocker_value: Variant in blocker_records:
			var blocker := blocker_value as Dictionary
			var blocker_id := StringName(blocker.lineage_id)
			var blocker_position := int(blocker.block_position)
			if not lineages.has(blocker_id):
				continue
			var blocker_lineage := lineages[blocker_id] as Dictionary
			var blocker_blocks := blocker_lineage.blocks as Array[Dictionary]
			if blocker_position < 0 or blocker_position >= blocker_blocks.size():
				continue
			var current := blocker_blocks[blocker_position] as Dictionary
			var previous := blocker_blocks[blocker_position - 1] as Dictionary \
				if blocker_position > 0 else {}
			var next := blocker_blocks[blocker_position + 1] as Dictionary \
				if blocker_position + 1 < blocker_blocks.size() else {}
			if previous.is_empty():
				continue
			var claimed_cells := _claimed_room_cells(lineages)
			for cell: Vector3i in current.cells:
				claimed_cells.erase(cell)
			# Prefer absorbing the exposed shoulder into this upper room when the
			# union is itself one complete authored floorplate. This turns a tiny
			# roof remnant into a larger coherent upper storey without adding a
			# decorative cube or changing the lower building.
			var expanded_columns := (current.columns as Dictionary).duplicate()
			for exposed_value: Variant in details[0].cells as Array:
				expanded_columns[exposed_value as Vector2i] = true
			var expanded_stamp := _exact_stamp_for_columns(expanded_columns,
				(current.origin as Vector3i).y)
			if not expanded_stamp.is_empty() and _candidate_matches_constraints(
					StringName(expanded_stamp.kind),
					expanded_stamp.origin as Vector3i,
					int(expanded_stamp.yaw_quarters), current):
				var expanded_record := _record(StringName(expanded_stamp.kind),
					expanded_stamp.origin as Vector3i,
					int(expanded_stamp.yaw_quarters), int(current.start_storey),
					int(current.end_storey))
				if not expanded_record.is_empty() \
						and not _record_overlaps_claimed(expanded_record,
							claimed_cells) \
						and _record_is_clear_for_participants(grid,
							protected_owners, expanded_record, {blocker_id: true}):
					var expanded_replacement := current.duplicate(true)
					for key: String in ["kind", "origin", "yaw_quarters",
							"columns", "cells"]:
						expanded_replacement[key] = expanded_record[key]
					expanded_replacement["global_roof_repair"] = true
					blocker_blocks[blocker_position] = expanded_replacement
					blocker_lineage["blocks"] = blocker_blocks
					lineages[blocker_id] = blocker_lineage
					var expanded_after := int(_global_exposed_roof_audit(
						lineages, extra_occupied) \
						.unroofable_global_roof_component_count)
					var expanded_valid := int(_lineage_support_audit(lineages,
						grid).unsupported_transition_count) == 0 \
						and int(_lineage_overlap_audit(lineages) \
							.overlap_cell_count) == 0
					if expanded_valid and expanded_after < before_count:
						repaired += 1
						recomposed = true
						break
					blocker_blocks[blocker_position] = current
					blocker_lineage["blocks"] = blocker_blocks
					lineages[blocker_id] = blocker_lineage
			var variant_record := {"current": current, "previous": previous,
				"next": next, "key": "%s/%d/global-roof" % [blocker_id,
					blocker_position]}
			var variants := _coupled_variants(grid, protected_owners,
				claimed_cells, {blocker_id: true}, variant_record, world_seed,
				true, false)
			for variant: Dictionary in variants:
				var replacement := _coupled_replacement(current, variant)
				replacement["global_roof_repair"] = true
				blocker_blocks[blocker_position] = replacement
				blocker_lineage["blocks"] = blocker_blocks
				lineages[blocker_id] = blocker_lineage
				var after_count := int(_global_exposed_roof_audit(lineages,
					extra_occupied) \
					.unroofable_global_roof_component_count)
				var structurally_valid := int(_lineage_support_audit(lineages,
					grid).unsupported_transition_count) == 0 \
					and int(_lineage_overlap_audit(lineages).overlap_cell_count) == 0
				if structurally_valid and after_count < before_count:
					repaired += 1
					recomposed = true
					break
				blocker_blocks[blocker_position] = current
				blocker_lineage["blocks"] = blocker_blocks
				lineages[blocker_id] = blocker_lineage
			if recomposed:
				break
		if recomposed:
			continue
		var required_bearers: Dictionary = {}
		for lineage_value: Variant in lineages.values():
			for block: Dictionary in (lineage_value as Dictionary).blocks \
					as Array[Dictionary]:
				var parent_id := StringName(block.get(
					"support_parent_lineage_id", &""))
				var parent_block := int(block.get(
					"support_parent_source_block_index", -1))
				if not parent_id.is_empty() and parent_block >= 0:
					required_bearers["%s/%d" % [parent_id, parent_block]] = true
		var candidates: Array[Dictionary] = []
		var seen: Dictionary = {}
		var cut_sources: Array[Dictionary] = []
		cut_sources.assign(details[0].blockers as Array)
		# The trapped lower crown can itself be the smallest optional suffix. The
		# former repair considered only the rooms crowding it from above, so a
		# structurally fixed upper socket made an otherwise disposable lower spur
		# impossible to clean up.  Subject the owner to the identical optional-cut
		# and complete bearing proof; required/addressed lineages still cannot move.
		cut_sources.append({
			"lineage_id": StringName(details[0].lineage_id),
			"block_position": int(details[0].block_position),
		})
		for blocker_value: Variant in cut_sources:
			var blocker := blocker_value as Dictionary
			var candidate_id := StringName(blocker.lineage_id)
			var position := int(blocker.block_position)
			var key := "%s/%d" % [candidate_id, position]
			if seen.has(key) or not lineages.has(candidate_id) or position <= 0:
				continue
			seen[key] = true
			var lineage := lineages[candidate_id] as Dictionary
			var blocks := lineage.blocks as Array[Dictionary]
			if position >= blocks.size() or not _optional_suffix_can_terminate(
					candidate_id, lineage, blocks, position, required_bearers):
				continue
			var removed_cells := 0
			for cut_index in range(position, blocks.size()):
				removed_cells += ((blocks[cut_index] as Dictionary).cells as Array).size()
			candidates.append({"lineage_id": candidate_id,
				"position": position, "removed_cells": removed_cells})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.removed_cells) < int(b.removed_cells) \
				if int(a.removed_cells) != int(b.removed_cells) \
				else String(a.lineage_id) < String(b.lineage_id))
		var accepted := false
		for candidate: Dictionary in candidates:
			var candidate_id := StringName(candidate.lineage_id)
			var position := int(candidate.position)
			if not _crown_cut_preserves_bearing(lineages, grid, candidate_id,
					position):
				continue
			var lineage := lineages[candidate_id] as Dictionary
			var original_blocks := (lineage.blocks as Array[Dictionary]).duplicate(
				true) as Array[Dictionary]
			var trial_blocks := original_blocks.duplicate(true) as Array[Dictionary]
			trial_blocks.resize(position)
			lineage["blocks"] = trial_blocks
			lineages[candidate_id] = lineage
			var after_count := int(_global_exposed_roof_audit(lineages,
				extra_occupied) \
				.unroofable_global_roof_component_count)
			if after_count < before_count:
				repaired += 1
				accepted = true
				break
			lineage["blocks"] = original_blocks
			lineages[candidate_id] = lineage
		if not accepted:
			break
	return repaired


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
