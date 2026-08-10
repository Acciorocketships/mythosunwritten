extends GutTest


func test_classifier_distinguishes_orthogonal_roof_join_families() -> void:
	var centre := _tower(&"centre", Vector3i.ZERO, 0, 2)
	var eave_neighbor := _tower(&"eave", Vector3i(2, 0, 0), 0, 2)
	var ridge_neighbor := _tower(&"ridge", Vector3i(0, 0, 2), 0, 2)
	var perpendicular_neighbor := _tower(&"perpendicular",
		Vector3i(2, 0, 0), 1, 2)
	var stepped_neighbor := _tower(&"stepped", Vector3i(2, 1, 0), 0, 2)

	var parallel := FabricRoofTopologyPlan.build([centre, eave_neighbor])
	assert_not_null(parallel)
	assert_eq(int(parallel.audit.junction_count), 1)
	assert_eq(_only_kind(parallel, &"centre"),
		FabricRoofTopologyPlan.JunctionKind.PARALLEL_VALLEY)

	var continued := FabricRoofTopologyPlan.build([centre, ridge_neighbor])
	assert_not_null(continued)
	assert_eq(_only_kind(continued, &"centre"),
		FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION)

	var perpendicular := FabricRoofTopologyPlan.build(
		[centre, perpendicular_neighbor])
	assert_not_null(perpendicular)
	assert_eq(_only_kind(perpendicular, &"centre"),
		FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY)

	var stepped := FabricRoofTopologyPlan.build([centre, stepped_neighbor])
	assert_not_null(stepped)
	assert_eq(_only_kind(stepped, &"centre"),
		FabricRoofTopologyPlan.JunctionKind.STEPPED_EAVE_WALL)
	assert_true(StringName(stepped.fact(&"centre").signature) != &"isolated")


func test_module_table_covers_every_classifier_kind_explicitly() -> void:
	for kind in FabricRoofTopologyPlan.JunctionKind.values():
		var rule := FabricRoofJunctionModuleTable.policy(kind)
		assert_false(rule.is_empty(), "junction kind %d needs an explicit rule" % kind)
		assert_true(rule.has("strategy"))
		assert_true(rule.has("module_family"))
		assert_true(rule.has("implemented"))
	assert_true(bool(FabricRoofJunctionModuleTable.policy(
		FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY).implemented),
		"perpendicular joins use an atomic bisected-host/open-gable pair")


func test_perpendicular_valley_rejects_roofs_without_an_atomic_vocabulary() -> void:
	var proposals: Array[Dictionary] = [
		_tower(&"left", Vector3i.ZERO, 0, 2),
		_tower(&"right", Vector3i(2, 0, 0), 1, 2),
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert_not_null(topology)
	assert_true(FabricRoofJunctionModuleTable.build(proposals, topology).is_empty())
	assert_string_contains(FabricRoofJunctionModuleTable.last_failure,
		"perpendicular valley")


func test_flat_caps_resolve_a_mass_first_crossing_gable_without_fake_seams() \
		-> void:
	var proposals: Array[Dictionary] = [
		_tower(&"left", Vector3i.ZERO, 0, 2),
		_tower(&"right", Vector3i(2, 0, 0), 1, 2),
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert_not_null(topology)
	proposals[0]["flat_roof"] = true
	proposals[1]["flat_roof"] = true
	var construction := FabricRoofJunctionModuleTable.build(proposals, topology)
	assert_false(construction.is_empty(),
		FabricRoofJunctionModuleTable.last_failure)
	assert_eq((construction.rules_by_id[&"left"] as Array).size(), 0)
	assert_eq((construction.rules_by_id[&"right"] as Array).size(), 0,
		"complete flat caps meet at the boundary without pitched-valley modules")


func test_complete_perpendicular_valley_selects_host_and_branch_recipes() -> void:
	var proposals: Array[Dictionary] = [
		_proposal(&"host", &"building", Vector3i.ZERO, 0, 2),
		_proposal(&"branch", &"long", Vector3i(5, 0, -1), 1, 2),
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert_not_null(topology)
	assert_eq(int(topology.audit.perpendicular_valley_count), 1)
	var construction := FabricRoofJunctionModuleTable.build(proposals, topology)
	assert_false(construction.is_empty(),
		FabricRoofJunctionModuleTable.last_failure)
	var host_rule := ((construction.rules_by_id as Dictionary)[&"host"] \
		as Array)[0] as Dictionary
	var branch_rule := ((construction.rules_by_id as Dictionary)[&"branch"] \
		as Array)[0] as Dictionary
	assert_eq(StringName(host_rule.atomic_role), &"host")
	assert_eq(StringName(branch_rule.atomic_role), &"branch")
	assert_false(FabricRoofJunctionModuleTable.bisected_valley_recipe_id(
		&"building", &"blue", int(host_rule.run_offset_half_steps),
		int(host_rule.side)).is_empty())
	assert_false(FabricRoofJunctionModuleTable.open_gable_recipe_id(
		&"long", &"orange", int(branch_rule.side)).is_empty())


func test_clearance_exception_exactly_follows_implemented_junction_table() -> void:
	var centre := _tower(&"centre", Vector3i.ZERO, 0, 2)
	assert_true(StaggeredFabricCompiler.classified_roof_seam_compatible(
		centre, _tower(&"ridge", Vector3i(0, 0, 2), 0, 2)),
		"a continuous ridge is an authored party-wall seam")
	assert_true(StaggeredFabricCompiler.classified_roof_seam_compatible(
		centre, _tower(&"parallel", Vector3i(2, 0, 0), 0, 2)),
		"a parallel valley owns an explicit flashing module")
	assert_true(StaggeredFabricCompiler.classified_roof_seam_compatible(
		centre, _tower(&"stepped_eave", Vector3i(2, 1, 0), 0, 2)),
		"a stepped eave owns an explicit flashing module")
	assert_true(StaggeredFabricCompiler.classified_roof_seam_compatible(
		centre, _tower(&"stepped_gable", Vector3i(0, 1, 2), 0, 2)),
		"a stepped gable keeps its authored closed end")
	assert_false(StaggeredFabricCompiler.classified_roof_seam_compatible(
		centre, _tower(&"perpendicular", Vector3i(2, 0, 0), 1, 2)),
		"a compact roof without a bisected recipe may not bypass clearance")
	assert_true(StaggeredFabricCompiler.classified_roof_seam_compatible(
		_proposal(&"host", &"building", Vector3i.ZERO, 0, 2),
		_proposal(&"branch", &"long", Vector3i(5, 0, -1), 1, 2)),
		"a complete modular T-junction owns an atomic construction pair")


func test_partial_parallel_contact_selects_one_offset_native_pitch_segment() -> void:
	# The slim/long T contact spans only 3 m of each larger eave. It must select
	# an explicit offset segment rather than omit flashing or stretch a full run.
	var proposals: Array[Dictionary] = [
		{
			"stable_id": &"slim", "kind": &"slim",
			"origin": Vector3i(7, 0, 4), "yaw_quarters": 0,
			"storeys": 2, "route_y": 0,
		},
		{
			"stable_id": &"long", "kind": &"long",
			"origin": Vector3i(10, 0, 1), "yaw_quarters": 0,
			"storeys": 2, "route_y": 0,
		},
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert_not_null(topology)
	assert_eq(int(topology.audit.parallel_valley_count), 1)
	var construction := FabricRoofJunctionModuleTable.build(proposals, topology)
	assert_false(construction.is_empty())
	var emitted := 0
	for rules_value: Variant in (construction.rules_by_id as Dictionary).values():
		for rule: Dictionary in rules_value as Array:
			emitted += int(bool(rule.emits_module))
			if bool(rule.emits_module):
				assert_eq(int(rule.face_cells), 2)
				assert_ne(int(rule.run_offset_half_steps), 0)
				assert_false(FabricRoofJunctionModuleTable.eave_seam_recipe_id(
					StringName((proposals[0] as Dictionary).kind)
						if StringName(rule.owner_id) == &"slim" else &"long",
					int(rule.face_cells), int(rule.run_offset_half_steps),
					int(rule.side)).is_empty())
	assert_eq(emitted, 1)


func test_roof_junctions_are_reciprocal_and_style_avoids_repeated_rows() -> void:
	var proposals: Array[Dictionary] = [
		_tower(&"west", Vector3i(-2, 0, 0), 0, 2),
		_tower(&"centre", Vector3i.ZERO, 0, 2),
		_tower(&"east", Vector3i(2, 0, 0), 0, 2),
	]
	var topology := FabricRoofTopologyPlan.build(proposals)
	assert_not_null(topology)
	assert_eq(int(topology.audit.junction_count), 2)
	assert_eq(int(topology.audit.joined_roof_count), 3)
	assert_true(WarrenAssetCompiler._assign_neighborhood_styles(
		proposals, topology, 701))
	var by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		assert_eq((proposal.roof_junction_rules as Array).size(),
			(topology.fact(StringName(proposal.stable_id)).junctions as Array).size())
		by_id[StringName(proposal.stable_id)] = proposal
	for owner_id: StringName in by_id.keys():
		for seam: Dictionary in topology.fact(owner_id).junctions as Array:
			var owner := by_id[owner_id] as Dictionary
			var neighbor := by_id[StringName(seam.neighbor_id)] as Dictionary
			assert_true(StringName(owner.theme) != StringName(neighbor.theme)
				or int(owner.facade_phase) != int(neighbor.facade_phase),
				"adjacent houses may not repeat the same complete appearance")
			assert_eq(StringName(owner.roof_signature),
				StringName(topology.fact(owner_id).signature))
	var trim_count := 0
	for proposal: Dictionary in proposals:
		for component: Dictionary in \
				StaggeredFabricCompiler.proposal_components(proposal):
			trim_count += int(String(component.role).begins_with("roof.trim."))
	assert_eq(trim_count, 2,
		"each complete classified valley receives exactly one trim owner")


static func _only_kind(plan: FabricRoofTopologyPlan,
		proposal_id: StringName) -> int:
	var junctions := plan.fact(proposal_id).junctions as Array
	return -1 if junctions.size() != 1 else int((junctions[0] as Dictionary).kind)


static func _tower(stable_id: StringName, origin: Vector3i, yaw: int,
		storeys: int) -> Dictionary:
	return _proposal(stable_id, &"tower", origin, yaw, storeys)


static func _proposal(stable_id: StringName, kind: StringName,
		origin: Vector3i, yaw: int, storeys: int) -> Dictionary:
	return {
		"stable_id": stable_id,
		"kind": kind,
		"origin": origin,
		"yaw_quarters": yaw,
		"storeys": storeys,
		"route_y": origin.y,
	}
