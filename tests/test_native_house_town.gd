extends GutTest
const KitPublicClearance = preload(
	"res://scripts/terrain/features/villages/kit/KitPublicClearance.gd"
)


func test_procedurally_reserved_native_house_survives_kit_substitution_whole() -> void:
	_assert_native_town(211, &"grand")
	_assert_native_town(7, &"standard")


func _assert_native_town(
	seed_value: int,
	profile: StringName,
	required_family: String = "",
	required_asset: StringName = &""
) -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	assert_not_null(program)
	if program == null:
		return
	var spatial := WarrenVolumetricSolver.generate(
		seed_value, {}, program, WarrenVillageScaleProfile.for_id(profile)
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	var kept := KitVillageBuildings.legacy_payload_without(fabric, built.replaced_units)
	var source := SettlementFabricAssembler.payload(fabric)
	var expected_count := 0
	var native_features := 0
	var required_features := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if not KitVillageBuildings._native_landmark(feature):
			continue
		native_features += 1
		if String(feature.audit.landmark_recipe_id).begins_with(required_family):
			required_features += 1
		for mass: BuildingMass in built.houses:
			assert_ne(
				mass.stable_id,
				StringName("kit." + String(feature.stable_id)),
				"Native reservation must not be rebuilt as generic geometry"
			)
	for unit: FabricUnit in fabric.units:
		var recipe := fabric.recipe(unit.recipe_id)
		if not recipe.has_tag(&"native_grammar"):
			continue
		expected_count += recipe.placements.size()
		assert_false(built.replaced_units.has(unit.stable_id))
		assert_true(recipe.sockets.is_empty(), "Do not advertise unsupported roof connections")
	var kit := SuntailBuildingKit.create()
	var public_air := KitPublicClearance.build(spatial, fabric, kit)
	var to_native := KitVillageBuildings.native_to_lattice(kit).affine_inverse()
	var actual_count := 0
	for id in source.asset_ids():
		if not (
			String(id).begins_with("pure_village.native.")
			or String(id).begins_with("pure_village.arcade.")
		):
			continue
		assert_true(kept.batches.has(id))
		if not kept.batches.has(id):
			continue
		assert_eq(
			kept.batches[id],
			source.batches[id],
			"Preserve geometry, transforms, identities and collision flags"
		)
		for pose: Transform3D in kept.batches[id].transforms:
			assert_false(
				KitPublicClearance.intersects_air(
					catalog.descriptor(id).measured_aabb, to_native * pose, public_air
				),
				"Complete native part clears finished public walking air: " + String(id)
			)
		actual_count += kept.batches[id].transforms.size()
	assert_gt(native_features, 0, "This observed production seed exercises native reservation")
	if not required_family.is_empty():
		assert_gt(
			required_features, 0, "The requested native family must be present in the finished town"
		)
	assert_eq(actual_count, expected_count)
	assert_gt(actual_count, 0)
	if not required_asset.is_empty():
		assert_true(
			kept.batches.has(required_asset), "Required native detail survives final assembly"
		)
		if kept.batches.has(required_asset):
			assert_gt(kept.batches[required_asset].transforms.size(), 0)


func test_native_pitched_roof_does_not_accept_a_street_at_its_box_ceiling() -> void:
	var template: Dictionary = (
		preload("res://scripts/terrain/features/villages/grammar/NativeHouseVocabulary.gd")
		. TEMPLATES[0]
	)
	var public_air := {Vector3i(0, template.height_bands, 0): true}
	assert_false(
		WarrenPlotReservations._native_body_clears_street(
			template, Vector2i.ZERO, Vector2i.DOWN, Vector2i.RIGHT, 0, public_air
		)
	)
	var legacy := template.duplicate()
	legacy.kind_id = &"anchor.prefab.fixture"
	assert_true(
		WarrenPlotReservations._native_body_clears_street(
			legacy, Vector2i.ZERO, Vector2i.DOWN, Vector2i.RIGHT, 0, public_air
		),
		"Legacy flat-bearing semantics remain unchanged"
	)


func test_native_raised_site_is_not_reserved_without_a_private_approach_floor() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		61, {}, program, WarrenVillageScaleProfile.for_id(&"grand")
	)
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
	if spatial == null:
		return
	var fabric := spatial.compiled_fabric_cache()
	for unit: FabricUnit in fabric.units:
		var recipe := fabric.recipe(unit.recipe_id)
		if not recipe.has_tag(&"native_grammar"):
			continue
		# This flat-ground seed previously accepted a native house at band one,
		# leaving the arrival and private stair unsupported in the final payload.
		assert_almost_eq(unit.transform().origin.y, 0.0, .001)

