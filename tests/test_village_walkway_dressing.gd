extends GutTest

func test_a_stair_landing_cannot_fall_back_to_planters_in_the_lane() -> void:
	var plan := PublicRealmSurfacePlan.new(&"stair-landing")
	var cells: Array[Vector3i] = []
	for x in 4:
		var cell := Vector3i(x, 4, 0)
		cells.append(cell)
		assert_true(plan.add_claim(cell,
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"volume.courtyard.test"))
	assert_true(plan.add_claim(Vector3i(-1, 3, 0),
		PublicRealmSurfacePlan.SurfaceKind.STAIR, &"stairs-a"))
	assert_true(plan.add_claim(Vector3i(4, 5, 0),
		PublicRealmSurfacePlan.SurfaceKind.STAIR, &"stairs-b"))
	var payload := EnvironmentInstancePayload.new()
	SettlementFabricAssembler._append_courtyard_paving(payload, cells, plan, {})
	assert_false(payload.batches.has(SettlementFabricAssembler.COURTYARD_PLANTER),
		"a narrow route between stairs must stay empty even when no decor corner fits")


func test_stair_claims_are_not_flat_door_approaches() -> void:
	var plan := PublicRealmSurfacePlan.new(&"blocked-door")
	assert_true(plan.add_claim(Vector3i.ZERO,
		PublicRealmSurfacePlan.SurfaceKind.STAIR, &"flight"))
	assert_true(plan.add_claim(Vector3i.RIGHT,
		PublicRealmSurfacePlan.SurfaceKind.STAIR, &"flight"))
	plan._transition_claim_owners[PublicRealmSurfacePlan._cell_key(Vector3i.ZERO)] = &"flight"
	plan._transition_claim_owners[PublicRealmSurfacePlan._cell_key(Vector3i.RIGHT)] = &"flight"
	plan._classify_entrances([{"stable_id": &"door", "landing_cell": Vector3i.ZERO,
		"facing": Vector3i.RIGHT}])
	assert_eq(plan.unserved_entrances.size(), 1,
		"a flight is not a level landing even when both logical cells exist")
	var flat := PublicRealmSurfacePlan.new(&"flat-door")
	assert_true(flat.add_claim(Vector3i.ZERO,
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"court"))
	assert_true(flat.add_claim(Vector3i.RIGHT,
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"court"))
	flat._classify_entrances([{"stable_id": &"door", "landing_cell": Vector3i.ZERO,
		"facing": Vector3i.RIGHT}])
	assert_eq(flat.unserved_entrances.size(), 0, "real level doors remain served")


func test_stairs_may_reach_a_flat_doorstep_through_their_open_end() -> void:
	var plan := PublicRealmSurfacePlan.new(&"end-on-door")
	plan.add_claim(Vector3i.ZERO,
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"landing")
	plan.add_claim(Vector3i.RIGHT,
		PublicRealmSurfacePlan.SurfaceKind.STAIR, &"flight")
	plan._transition_claim_owners[PublicRealmSurfacePlan._cell_key(Vector3i.RIGHT)] = &"flight"
	plan._transition_mesh_payloads.append({"stable_id": &"flight",
		"run_direction": Vector3i.RIGHT})
	assert_true(plan.door_approach_is_clear(Vector3i.ZERO, Vector3i.RIGHT),
		"the flight's open end leads into a flat doorstep")
	plan._transition_mesh_payloads[0].run_direction = Vector3i.FORWARD
	assert_false(plan.door_approach_is_clear(Vector3i.ZERO, Vector3i.RIGHT),
		"the same approach cannot cross a perpendicular flight's side rail")
