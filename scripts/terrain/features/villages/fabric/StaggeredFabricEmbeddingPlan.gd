class_name StaggeredFabricEmbeddingPlan
extends RefCounted

## Plain-data output of the bounded barrier-placement search. These are not
## render instances: a later structural compilation step must replace each
## proposal with a supported inhabited recipe and re-run the common transaction.
var stable_id: StringName
var barrier_proposals: Array[Dictionary] = []
var covered_obligation_indices: Array[int] = []
var remaining_obligation_indices: Array[int] = []
var initial_bounded_count := 0
var total_obligation_count := 0
## Resource-free upper-bound hint produced by the massing beam. Exact overhead
## geometry still decides admission; zero means no pair of distinct inhabited
## facade owners can possibly face one another at a supported walk datum.
var potential_skywalk_pair_count := 0
var _sealed := false


func _init(p_stable_id: StringName) -> void:
	stable_id = p_stable_id


func seal(proposals: Array[Dictionary], covered: Dictionary,
		open_count: int, p_initial_bounded_count: int,
		p_total_obligation_count: int) -> bool:
	if _sealed or stable_id.is_empty() or open_count < 0 \
			or p_initial_bounded_count < 0 or p_total_obligation_count <= 0:
		return false
	barrier_proposals.assign(proposals)
	initial_bounded_count = p_initial_bounded_count
	total_obligation_count = p_total_obligation_count
	for index in open_count:
		if covered.has(index):
			covered_obligation_indices.append(index)
		else:
			remaining_obligation_indices.append(index)
	_sealed = true
	return true


func validate() -> bool:
	if not _sealed or stable_id.is_empty() or total_obligation_count <= 0:
		return false
	var proposal_ids: Dictionary = {}
	for proposal: Dictionary in barrier_proposals:
		var proposal_id := StringName(proposal.get("stable_id", ""))
		var kind := StringName(proposal.get("kind", ""))
		if proposal_id.is_empty() or proposal_ids.has(proposal_id) \
				or not proposal.has("origin") or not proposal.has("occupied_cells") \
				or (kind != &"building" and kind != &"tower" \
					and kind != &"slim" and kind != &"micro" \
					and kind != &"market") \
				or (kind == &"building" and (int(proposal.get("storeys", 0)) < 1 \
					or int(proposal.get("storeys", 0)) > 4)) \
				or (kind == &"tower" and (int(proposal.get("storeys", 0)) < 1 \
					or int(proposal.get("storeys", 0)) > 4)) \
				or (kind == &"slim" and (int(proposal.get("storeys", 0)) < 1 \
					or int(proposal.get("storeys", 0)) > 4)) \
				or (kind == &"micro" and int(proposal.get("storeys", 0)) != 1) \
				or (kind == &"market" and int(proposal.get("storeys", -1)) != 0) \
				or (kind == &"market" and (int(proposal.get("market_family", -1)) < 0 \
					or int(proposal.get("market_family", -1)) \
						>= SettlementFabricProgram.MARKET_STALLS.size())) \
				or int(proposal.get("yaw_quarters", -1)) < 0 \
				or int(proposal.get("yaw_quarters", -1)) > 3 \
				or (StringName(proposal.get("support_mode", "")) \
					!= &"grounded_stack" \
					and StringName(proposal.get("support_mode", "")) \
					!= &"retained_half_perch"):
			return false
		var origin := proposal.origin as Vector3i
		var support_mode := StringName(proposal.support_mode)
		if (support_mode == &"grounded_stack" and origin.y != 0) \
				or (support_mode == &"retained_half_perch" and origin.y != 1):
			return false
		proposal_ids[proposal_id] = true
	return covered_obligation_indices.size() \
		+ remaining_obligation_indices.size() \
		== total_obligation_count - initial_bounded_count


func is_sealed() -> bool:
	return _sealed


func audit() -> Dictionary:
	var projected_bounded := initial_bounded_count \
		+ covered_obligation_indices.size()
	var base_bands: Dictionary = {}
	var storey_counts: Dictionary = {}
	var market_count := 0
	for proposal: Dictionary in barrier_proposals:
		base_bands[int((proposal.origin as Vector3i).y)] = true
		if StringName(proposal.kind) == &"market":
			market_count += 1
		else:
			storey_counts[int(proposal.storeys)] = true
	var half_level_band_pairs := 0
	for band_value: Variant in base_bands:
		if base_bands.has(int(band_value) + 1):
			half_level_band_pairs += 1
	return {
		"proposed_barrier_count": barrier_proposals.size(),
		"proposed_closed_boundary_count": covered_obligation_indices.size(),
		"proposed_remaining_open_side_count": remaining_obligation_indices.size(),
		"projected_solid_void_frontage_ratio": float(projected_bounded) \
			/ float(maxi(1, total_obligation_count)),
		"proposed_base_band_count": base_bands.size(),
		"proposed_half_level_band_pair_count": half_level_band_pairs,
		"proposed_storey_variant_count": storey_counts.size(),
		"proposed_market_frontage_count": market_count,
		"proposed_skywalk_pair_count": potential_skywalk_pair_count,
	}


func deterministic_signature() -> String:
	var parts := PackedStringArray()
	for proposal: Dictionary in barrier_proposals:
		var origin := proposal.origin as Vector3i
		parts.append("%s@%d,%d,%d/%d/%d" % [proposal.stable_id,
			origin.x, origin.y, origin.z, int(proposal.storeys),
			int(proposal.yaw_quarters)])
	return "|".join(parts)
