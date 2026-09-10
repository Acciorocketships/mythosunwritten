extends GutTest

func test_reported_path_endpoint_builds_a_supported_town() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,Vector2i(82,-205))
	var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial,"the reported road endpoint must build: " + WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(
			spatial.compiled_fabric_cache()), PackedStringArray(),
			"construction defects must fail this test, never erase a runtime town")

func test_every_source_portal_has_a_production_handoff() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(82, -205))
	var spatial := WarrenVolumetricSolver.solve(seed_value, {}, program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial)
	if spatial == null: return
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	var contacts := VillageWarrenFabricSolver.terrain_contact_specs(spatial,
		spatial.compiled_fabric_cache())
	assert_eq(contacts.size(), source.excavation.portals.size(),
		"a supported gate above band zero still needs its handoff")

func test_a_street_above_the_reserved_roof_band_receives_structural_support() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,Vector2i(-10,-9))
	var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,
		WarrenVillageScaleProfile.select(seed_value))
	assert_not_null(spatial, "a street one support band above a room must not request a gable through that street: " + WarrenVolumetricSolver.last_failure)
	if spatial != null:
		assert_eq(WarrenSpatialFabricCompiler.validation_errors(spatial.compiled_fabric_cache()), PackedStringArray())

func test_runtime_and_diagnostic_generation_construct_the_same_town() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, Vector2i(82, -205))
	var profile := WarrenVillageScaleProfile.select(seed_value)
	var runtime := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
	var diagnostic := WarrenVolumetricSolver.solve(seed_value, {}, program, profile)
	assert_not_null(runtime)
	assert_not_null(diagnostic)
	if runtime == null or diagnostic == null: return
	var runtime_source := runtime.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	var diagnostic_source := diagnostic.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
	assert_false(runtime_source.audit.has("street_floor_gaps"),
		"production must not run the completed source's coverage audit")
	assert_true(diagnostic_source.audit.has("street_floor_gaps"))
	assert_false(runtime.source_volume.audit.has("bore_without_path_count"),
		"production must not revalidate the source-to-volume projection")
	assert_true(diagnostic.source_volume.audit.has("bore_without_path_count"))
	assert_eq(int(runtime.audit.get("room_composition_pass_count", 0)), 1)
	assert_false(runtime.audit.room_composition_diagnostics_collected)
	assert_true(diagnostic.audit.room_composition_diagnostics_collected)
	assert_false(runtime.audit.has("unroofable_global_roof_component_count"))
	assert_true(diagnostic.audit.has("unroofable_global_roof_component_count"))
	for key: String in ["trimmed_mass_component_count",
			"route_overhead_supply_route_cell_count", "maze_plot_mass_cell_count"]:
		assert_false(runtime.audit.has(key),
			"production must not scan the completed mass for %s" % key)
		assert_true(diagnostic.audit.has(key),
			"offline inspection must retain %s" % key)
	var runtime_fabric := runtime.compiled_fabric_cache()
	var diagnostic_fabric := diagnostic.compiled_fabric_cache()
	assert_false(runtime_fabric.audit.construction_diagnostics_collected)
	assert_true(diagnostic_fabric.audit.construction_diagnostics_collected)
	assert_false(runtime_fabric.audit.has("modular_box_unclassified_count"))
	assert_true(diagnostic_fabric.audit.has("modular_box_unclassified_count"))
	assert_eq(runtime_fabric.construction_signature(), diagnostic_fabric.construction_signature())
	assert_eq(runtime_fabric.expanded_placements(), diagnostic_fabric.expanded_placements(),
		"test audits must not change which geometry is built")

	var audit_before := runtime_fabric.audit.duplicate(true)
	var signature_before := runtime_fabric.construction_signature()
	var placements_before := runtime_fabric.expanded_placements()
	var inspection := WarrenSpatialFabricCompiler.construction_diagnostics(
		runtime, runtime_fabric, program)
	assert_true(inspection.construction_diagnostics_collected)
	assert_true(inspection.has("modular_box_unclassified_count"))
	assert_eq(runtime_fabric.audit, audit_before,
		"inspecting a constructed town must not add runtime audit state")
	assert_eq(runtime_fabric.construction_signature(), signature_before)
	assert_eq(runtime_fabric.expanded_placements(), placements_before,
		"inspection must never recompose or repair a town")
