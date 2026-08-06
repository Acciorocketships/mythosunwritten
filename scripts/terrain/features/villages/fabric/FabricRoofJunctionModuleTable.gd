class_name FabricRoofJunctionModuleTable
extends RefCounted

## Finite construction table for every relationship classified by
## FabricRoofTopologyPlan.  It is deliberately analogous to the cliff-piece
## table: layout code supplies a sealed local signature, this table selects one
## legal construction treatment, and unsupported signatures are rejected
## before any render placement exists.  Adding a new roof family means adding
## its policy and authored module here rather than repairing individual towns.
enum Strategy {
	CONTINUOUS_RIDGE,
	EAVE_FLASHING,
	BISECTED_VALLEY,
	STEPPED_FLASHING,
	CLOSED_GABLE_ABUTMENT,
}

static var last_failure := ""


static func policy(kind: int) -> Dictionary:
	match kind:
		FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION:
			return {
				"strategy": Strategy.CONTINUOUS_RIDGE,
				"module_family": &"continuous_ridge",
				"implemented": true,
			}
		FabricRoofTopologyPlan.JunctionKind.PARALLEL_VALLEY:
			return {
				"strategy": Strategy.EAVE_FLASHING,
				"module_family": &"eave_seam",
				"implemented": true,
			}
		FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY:
			return {
				"strategy": Strategy.BISECTED_VALLEY,
				"module_family": &"bisected_valley",
				# Eligibility is narrowed further in _bisected_rules(): only a
				# complete modular gable may enter one complete modular eave. The
				# host slope is replaced and the branch gable is omitted atomically.
				"implemented": true,
			}
		FabricRoofTopologyPlan.JunctionKind.STEPPED_EAVE_WALL:
			return {
				"strategy": Strategy.STEPPED_FLASHING,
				"module_family": &"eave_seam",
				"implemented": true,
			}
		FabricRoofTopologyPlan.JunctionKind.STEPPED_GABLE_WALL:
			return {
				"strategy": Strategy.CLOSED_GABLE_ABUTMENT,
				"module_family": &"closed_gable",
				"implemented": true,
			}
		_:
			return {}


static func build(proposals: Array[Dictionary],
		roof_topology: FabricRoofTopologyPlan) -> Dictionary:
	last_failure = ""
	if proposals.is_empty() or roof_topology == null \
			or not roof_topology.is_sealed():
		return _reject("missing proposals or sealed roof topology")
	var by_id: Dictionary = {}
	var rules_by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		var proposal_id := StringName(proposal.get("stable_id", ""))
		if proposal_id.is_empty() or by_id.has(proposal_id):
			return _reject("invalid or duplicate roof proposal")
		by_id[proposal_id] = proposal
		rules_by_id[proposal_id] = [] as Array[Dictionary]
	var ids: Array[StringName] = []
	ids.assign(by_id.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for owner_id: StringName in ids:
		for seam: Dictionary in roof_topology.fact(owner_id).junctions as Array:
			var neighbor_id := StringName(seam.neighbor_id)
			if String(owner_id) >= String(neighbor_id):
				continue
			if not by_id.has(neighbor_id):
				return _reject("roof junction names a missing neighbor")
			var reverse := _reverse_seam(roof_topology, neighbor_id, owner_id)
			if reverse.is_empty():
				return _reject("roof junction lacks a reciprocal signature")
			var pair_rules := _rules_for_pair(owner_id,
				by_id[owner_id] as Dictionary, seam, neighbor_id,
				by_id[neighbor_id] as Dictionary, reverse)
			if pair_rules.is_empty():
				return {}
			for rule: Dictionary in pair_rules:
				(rules_by_id[StringName(rule.owner_id)] \
					as Array[Dictionary]).append(rule)
	for proposal_id: StringName in ids:
		var atomic_count := 0
		for rule: Dictionary in rules_by_id[proposal_id] as Array:
			atomic_count += int(StringName(rule.get("module_family", "")) \
				== &"bisected_valley")
		if atomic_count > 1:
			return _reject("roof %s requires an uncompiled multi-valley recipe" %
				proposal_id)
		(rules_by_id[proposal_id] as Array).sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				if int(a.side) != int(b.side):
					return int(a.side) < int(b.side)
				return String(a.neighbor_id) < String(b.neighbor_id))
	return {
		"rules_by_id": rules_by_id,
		"junction_count": int(roof_topology.audit.junction_count),
	}


static func eave_seam_recipe_id(kind: StringName, face_cells: int,
		run_offset_half_steps: int, side: int) -> StringName:
	var owner_run_cells := _ridge_span_for_kind(kind)
	var size_family := "narrow" if kind == &"tower" or kind == &"slim" \
		else "wide" if kind == &"building" or kind == &"long" else ""
	if size_family.is_empty() or face_cells < 2 or face_cells > owner_run_cells \
			or posmod(face_cells, 2) != 0 \
			or side not in [FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
				FabricRoofTopologyPlan.Side.EAVE_POSITIVE]:
		return &""
	var owner_run_m := roundi(float(owner_run_cells) * FabricRecipe.CELL_SIZE)
	var seam_run_m := roundi(float(face_cells) * FabricRecipe.CELL_SIZE)
	var offset_token := "m%d" % absi(run_offset_half_steps) \
		if run_offset_half_steps < 0 else "p%d" % run_offset_half_steps
	var side_name := "negative" \
		if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else "positive"
	return StringName("roof.seam.%s.o%d.s%d.%s.%s" % [size_family,
		owner_run_m, seam_run_m, offset_token, side_name])


static func bisected_valley_recipe_id(kind: StringName, theme: StringName,
		run_offset_half_steps: int, side: int) -> StringName:
	if kind not in [&"building", &"long"] or theme not in [&"blue", &"orange"] \
			or side not in [FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
				FabricRoofTopologyPlan.Side.EAVE_POSITIVE]:
		return &""
	if (kind == &"building" and run_offset_half_steps != 0) \
			or (kind == &"long" and absi(run_offset_half_steps) != 2):
		return &""
	var offset_token := "m%d" % absi(run_offset_half_steps) \
		if run_offset_half_steps < 0 else "p%d" % run_offset_half_steps
	var side_name := "negative" \
		if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else "positive"
	return StringName("roof.%s.%s.valley.%s.%s" % [kind, theme,
		offset_token, side_name])


static func open_gable_recipe_id(kind: StringName, theme: StringName,
		side: int) -> StringName:
	if kind not in [&"building", &"long"] or theme not in [&"blue", &"orange"] \
			or side not in [FabricRoofTopologyPlan.Side.RIDGE_NEGATIVE,
				FabricRoofTopologyPlan.Side.RIDGE_POSITIVE]:
		return &""
	var side_name := "negative" \
		if side == FabricRoofTopologyPlan.Side.RIDGE_NEGATIVE else "positive"
	return StringName("roof.%s.%s.open.%s" % [kind, theme, side_name])


static func _rules_for_pair(left_id: StringName, left: Dictionary,
		left_seam: Dictionary, right_id: StringName, right: Dictionary,
		right_seam: Dictionary) -> Array[Dictionary]:
	var kind := int(left_seam.kind)
	var junction_policy := policy(kind)
	if junction_policy.is_empty():
		_reject("unclassified roof junction kind %d" % kind)
		return []
	if not bool(junction_policy.implemented):
		_reject("roof junction %s--%s requires unimplemented %s modules" % [
			left_id, right_id, StringName(junction_policy.module_family)])
		return []
	if int(junction_policy.strategy) == Strategy.BISECTED_VALLEY:
		return _bisected_rules(left_id, left, left_seam, right_id, right,
			right_seam, junction_policy)
	var left_full := int(left_seam.face_cells) == _side_span(left,
		int(left_seam.side))
	var right_full := int(right_seam.face_cells) == _side_span(right,
		int(right_seam.side))
	var module_owner := &""
	match int(junction_policy.strategy):
		Strategy.CONTINUOUS_RIDGE:
			if not left_full or not right_full:
				_reject("continuous ridge %s--%s is not full-width" % [
					left_id, right_id])
				return []
		Strategy.EAVE_FLASHING:
			# Segment recipes cover every legal native-pitch contact interval.
			# Ownership is canonical because either equal-height slope can carry
			# the flashing; emitting it twice would z-fight.
			module_owner = left_id if String(left_id) < String(right_id) else right_id
		Strategy.STEPPED_FLASHING:
			# Positive delta means the other roof is higher. The lower slope
			# owns the flashing that terminates against that taller wall.
			module_owner = left_id if int(left_seam.height_delta) > 0 \
				else right_id
			# A partial lower eave uses the same finite segment vocabulary rather
			# than pretending a full-width strip fits the contact.
		Strategy.CLOSED_GABLE_ABUTMENT:
			# Both complete roof recipes retain their authored gable closure.
			# Measured visual envelopes remain the authority for clearance.
			pass
	var out: Array[Dictionary] = []
	out.append(_rule(left_id, right_id, left_seam, junction_policy,
		module_owner == left_id, left_full))
	out.append(_rule(right_id, left_id, right_seam, junction_policy,
		module_owner == right_id, right_full))
	return out


static func _bisected_rules(left_id: StringName, left: Dictionary,
		left_seam: Dictionary, right_id: StringName, right: Dictionary,
		right_seam: Dictionary, junction_policy: Dictionary) -> Array[Dictionary]:
	var left_is_eave := int(left_seam.side) in [
		FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
		FabricRoofTopologyPlan.Side.EAVE_POSITIVE]
	var right_is_eave := int(right_seam.side) in [
		FabricRoofTopologyPlan.Side.EAVE_NEGATIVE,
		FabricRoofTopologyPlan.Side.EAVE_POSITIVE]
	if left_is_eave == right_is_eave or int(left_seam.height_delta) != 0 \
			or int(left_seam.face_cells) != 4:
		_reject("perpendicular valley %s--%s is not one complete eave-to-gable join" % [
			left_id, right_id])
		return []
	var host_id := left_id if left_is_eave else right_id
	var host := left if left_is_eave else right
	var host_seam := left_seam if left_is_eave else right_seam
	var branch_id := right_id if left_is_eave else left_id
	var branch := right if left_is_eave else left
	var branch_seam := right_seam if left_is_eave else left_seam
	if StringName(host.get("kind", "")) not in [&"building", &"long"] \
			or StringName(branch.get("kind", "")) not in [&"building", &"long"] \
			or int(branch_seam.face_cells) != _side_span(branch,
				int(branch_seam.side)) \
			or bisected_valley_recipe_id(StringName(host.kind), &"blue",
				int(host_seam.run_offset_half_steps), int(host_seam.side)).is_empty() \
			or open_gable_recipe_id(StringName(branch.kind), &"blue",
				int(branch_seam.side)).is_empty():
		_reject("perpendicular valley %s--%s has no atomic modular recipe" % [
			left_id, right_id])
		return []
	var host_rule := _rule(host_id, branch_id, host_seam,
		junction_policy, false, int(host_seam.face_cells) == _side_span(host,
			int(host_seam.side)))
	host_rule["atomic_role"] = &"host"
	var branch_rule := _rule(branch_id, host_id, branch_seam,
		junction_policy, false, true)
	branch_rule["atomic_role"] = &"branch"
	return [host_rule, branch_rule] as Array[Dictionary]


static func _rule(owner_id: StringName, neighbor_id: StringName,
		seam: Dictionary, junction_policy: Dictionary, emits_module: bool,
		full_face: bool) -> Dictionary:
	return {
		"owner_id": owner_id,
		"neighbor_id": neighbor_id,
		"kind": int(seam.kind),
		"side": int(seam.side),
		"height_delta": int(seam.height_delta),
		"face_cells": int(seam.face_cells),
		"run_offset_half_steps": int(seam.get("run_offset_half_steps", 0)),
		"full_face": full_face,
		"strategy": int(junction_policy.strategy),
		"module_family": StringName(junction_policy.module_family),
		"emits_module": emits_module,
	}


static func _reverse_seam(topology: FabricRoofTopologyPlan,
		owner_id: StringName, neighbor_id: StringName) -> Dictionary:
	for seam: Dictionary in topology.fact(owner_id).junctions as Array:
		if StringName(seam.neighbor_id) == neighbor_id:
			return seam
	return {}


static func _side_span(proposal: Dictionary, side: int) -> int:
	var kind := StringName(proposal.get("kind", ""))
	var ridge_span := _ridge_span_for_kind(kind)
	var eave_span := 2 if kind == &"tower" or kind == &"slim" \
		else 4 if kind == &"building" or kind == &"long" else 0
	return eave_span if side == FabricRoofTopologyPlan.Side.RIDGE_NEGATIVE \
		or side == FabricRoofTopologyPlan.Side.RIDGE_POSITIVE else ridge_span


static func _ridge_span_for_kind(kind: StringName) -> int:
	return 2 if kind == &"tower" else 4 if kind == &"slim" \
		or kind == &"building" else 6 if kind == &"long" else 0


static func _reject(reason: String) -> Dictionary:
	last_failure = reason
	return {}
