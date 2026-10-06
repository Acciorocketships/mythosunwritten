extends GutTest

func test_gate_uses_native_curved_header_above_walking_clearance() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id = &"native-gate-study"
	var ctx := {"mass":mass,"out":[],"serial":0}
	var assembler := BuildingKitAssembler.new(kit)
	assembler._emit_gate(ctx,Vector3i(0,0,3),0.0)
	var found := 0
	var catalog := EnvironmentCatalog.load_default()
	for part: Dictionary in ctx.out:
		if part.role!=&"gate.arch": continue
		found += 1
		var descriptor := catalog.descriptor(part.asset_id)
		assert_not_null(descriptor)
		if descriptor==null: continue
		assert_true(descriptor.measured_aabb.size.is_equal_approx(kit.gate_arch_size),
			"the kit adapter uses the measured baked header dimensions")
		var bounds: AABB = part.transform*descriptor.measured_aabb
		assert_gte(bounds.position.y,TraversalEnvelope.MIN_HEADROOM/VillageWorldScale.KIT_WORLD_SCALE,
			"the complete ornamental header stays above the player's envelope")
		assert_lte(bounds.end.y,BuildingKitAssembler.FORT_GATE_RISE+0.01,
			"the arch fits the proved gate height")
	assert_eq(found,1,"a native curved stone header replaces the plain tiled lintel")

func test_low_carried_room_limits_the_gate_header() -> void:
	var kit := SuntailBuildingKit.create()
	var mass := BuildingMass.new()
	mass.stable_id = &"low-gate-study"
	var ctx := {"mass":mass,"out":[],"serial":0}
	var assembler := BuildingKitAssembler.new(kit)
	assembler.overhead_solids = [{"bounds":AABB(Vector3(-4,2, -4),Vector3(12,3,12))}]
	assembler._emit_gate(ctx,Vector3i(0,0,3),0.0)
	assert_eq((ctx.out as Array).size(),0,"an overhead room supplies the header when no independent gate can fit")
