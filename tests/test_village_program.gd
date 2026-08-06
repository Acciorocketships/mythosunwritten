extends GutTest

func test_default_program_compiles_reviewed_catalog_metrics_and_slots() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	assert_not_null(program)
	assert_not_null(program.massing_program.vertical_profile)
	assert_almost_eq(program.massing_program.vertical_profile.full_level_height,
		12.0, 0.0001,
		"one level clears the complete stackable house, not a terrain storey")
	assert_almost_eq(program.massing_program.vertical_profile.half_level_height,
		6.0, 0.0001)
	assert_eq(program.massing_program.core_asset_id,
		&"sfv.building.interior.blue.001",
		"the terrain datum follows the most compact stackable footprint, not slot order")
	assert_eq(program.massing_program.slots_for_tier(&"village").size(), 10)
	assert_eq(program.massing_program.slots_for_tier(&"town").size(), 15)
	var village_massing_slots := program.massing_program.slots_for_tier(
		&"village")
	assert_eq((village_massing_slots[8] as VillageMassingSlot).asset_id,
		&"sfv.building.interior.blue.006")
	assert_eq((village_massing_slots[9] as VillageMassingSlot).asset_id,
		&"sfv.building.interior.blue.002",
		"distinct accents are additive to the complete compact grammar")
	assert_eq(program.assets.size(), 13)
	var legacy_required: Array[StringName] = [
		&"aws.building.003", &"sfbp.campfire.001",
		&"sfbp.tent.armory.001", &"sfbp.tent.dormitory1.001",
		&"sfbp.tent.dormitory2.001", &"sfbp.tent.forge.001",
		&"sfm.stall.blue.007",
		&"sfm.stall.butcher.001", &"sfm.stall.butcher.003",
		&"sfm.stall.neutral.009", &"sfm.stall.orange.006",
		&"sfm.stall.teal.008",
		&"sfm.table.fishmonger.001",
		&"sft.building.001",
		&"sfv.building.interior.blue.001",
		&"sfv.building.interior.blue.002",
		&"sfv.building.interior.blue.005",
		&"sfv.building.interior.blue.006",
		&"sfv.building.interior.orange.001",
		&"sfv.building.interior.orange.002",
		&"sfv.building.interior.orange.005",
		&"sfv.building.interior.orange.006",
		&"sfv.deck.floor.s.001", &"sfv.deck.pillar.001",
		&"sfv.deck.railing.s.001",
		&"sfv.fence.001", &"sfv.foundation.rock.001",
		&"sfv.quest_board.001", &"sfv.stair.s.001",
		&"sfv.well.001",
	]
	for asset_id: StringName in legacy_required:
		assert_has(program.referenced_asset_ids, asset_id)
	assert_not_null(program.settlement_fabric_program)
	for asset_id: StringName in SettlementFabricProgram.MARKET_STALLS:
		assert_has(program.referenced_asset_ids, asset_id)
		assert_has(EnvironmentCatalog.load_default().descriptor(asset_id).tags,
			&"stocked_market", "production fabric markets must be dressed prefabs")
	assert_eq(program.foundation_asset_id, &"sfv.foundation.rock.001")
	assert_eq(VillageProgram.PRODUCTION_TIERS, [&"village", &"town"],
		"production must select only grammars with an inhabited vertical district")
	assert_eq(VillageProgram.production_tier(0.0), &"village")
	assert_eq(VillageProgram.production_tier(0.8499), &"village")
	assert_eq(VillageProgram.production_tier(0.85), &"town")
	assert_almost_eq(program.foundation_module_width, 1.5, 0.0001)
	assert_almost_eq(program.foundation_module_depth, 0.6638871, 0.0001)
	assert_almost_eq(program.foundation_module_height, 3.0, 0.0001)
	var house := program.assets[&"sfv.building.interior.blue.001"] \
		as VillageAssetSpec
	assert_almost_eq(house.measured_aabb.size.x, 11.6179256, 0.0001)
	assert_almost_eq(house.measured_aabb.size.y, 10.9486065, 0.0001)
	assert_almost_eq(house.measured_aabb.size.z, 16.2636566, 0.0001)
	assert_eq(house.ground_contact_local_rect,
		Rect2(-4.325, -4.785, 9.0, 12.0))
	assert_eq(house.interior_local_rect,
		Rect2(-4.325, -4.785, 9.0, 12.0))
	assert_true(is_equal_approx(fmod(
		house.ground_contact_local_rect.size.x,
		program.foundation_module_width), 0.0))
	assert_true(is_equal_approx(fmod(
		house.ground_contact_local_rect.size.y,
		program.foundation_module_width), 0.0),
		"foundation contacts compile on-grid instead of expanding at runtime")
	assert_eq(house.entrance_local, Vector2(0.222, 6.17),
		"the entrance is the measured opening, not a hand-framed facade point")
	assert_almost_eq(house.entrance_floor_local_y, 0.522, 0.0001,
		"the doorway floor is independent from the prefab's lowest visual vertex")
	assert_eq(house.asset_for_theme(&"blue"),
		&"sfv.building.interior.blue.001")
	assert_eq(house.asset_for_theme(&"orange"),
		&"sfv.building.interior.orange.001")
	assert_eq(program.spec_for_asset(&"sfv.building.interior.orange.001"),
		house, "runtime variants resolve to one planning contract")
	var short_house := program.assets[&"sfv.building.interior.blue.006"] \
		as VillageAssetSpec
	assert_almost_eq(short_house.measured_aabb.size.x, 14.3501492, 0.0001)
	assert_almost_eq(short_house.measured_aabb.size.y, 9.4416008, 0.0001)
	assert_almost_eq(short_house.measured_aabb.size.z, 14.7832165, 0.0001)
	assert_eq(short_house.ground_contact_local_rect,
		Rect2(-4.635, -3.968, 10.5, 10.5))
	assert_eq(short_house.entrance_local, Vector2(0.019, 7.55))
	assert_almost_eq(short_house.entrance_floor_local_y, 0.0, 0.0001)
	assert_eq(short_house.asset_for_theme(&"orange"),
		&"sfv.building.interior.orange.006")
	assert_eq(program.spec_for_asset(&"sfv.building.interior.orange.006"),
		short_house)
	assert_true(short_house.is_stackable())
	var compact_accent := program.assets[
		&"sfv.building.interior.blue.002"] as VillageAssetSpec
	assert_false(compact_accent.is_stackable(),
		"larger accents cannot change the compiled upper-level cadence")
	assert_eq(compact_accent.entrance_local, Vector2(0.024, 5.85))
	assert_eq(compact_accent.ground_contact_local_rect,
		Rect2(-2.267, -1.93, 7.5, 7.5))
	assert_eq(compact_accent.asset_for_theme(&"orange"),
		&"sfv.building.interior.orange.002")
	var grand_accent := program.assets[
		&"sfv.building.interior.blue.005"] as VillageAssetSpec
	assert_false(grand_accent.is_stackable())
	assert_eq(grand_accent.entrance_local, Vector2(-0.65, 8.528))
	assert_eq(grand_accent.ground_contact_local_rect,
		Rect2(-5.15, -5.72, 15.0, 13.5))
	assert_eq(grand_accent.asset_for_theme(&"orange"),
		&"sfv.building.interior.orange.005")
	assert_gt(house.lot_local_rect.size.x,
		house.ground_contact_local_rect.size.x,
		"support contact must not silently inherit roof/eave lot clearance")
	assert_true(house.allowed_in(&"hamlet"))
	assert_true(house.has_enclosed_interior())
	assert_true(house.is_enterable())
	assert_true(house.requires_foundation())
	assert_true(house.is_stackable())
	var shelter := program.assets[&"sfbp.tent.dormitory1.001"] \
		as VillageAssetSpec
	assert_true(shelter.is_enterable())
	assert_false(shelter.is_stackable())
	assert_false(shelter.has_enclosed_interior(),
		"open shelters are approached but never reviewed as sealed rooms")
	for populated_id: StringName in [
		&"sfbp.tent.dormitory1.001", &"sfbp.tent.armory.001",
		&"sfbp.tent.dormitory2.001", &"sfbp.tent.forge.001",
	]:
		assert_true(program.assets.has(populated_id))
		assert_eq((program.assets[populated_id] as VillageAssetSpec).asset_for_theme(
			&"blue"), populated_id)
	for empty_id: StringName in [
		&"sfbp.tent1.001", &"sfbp.tent3.001", &"sfbp.tent4.001",
		&"sfbp.tent6.001",
	]:
		assert_false(program.assets.has(empty_id),
			"empty canvas shelters are excluded from production planning")
	assert_false(program.assets.has(&"sfbp.tent2.001"),
		"the visibly closed front is not declared as an enterable shelter")
	assert_false(program.assets.has(&"sfbp.tent5.001"))
	var market := program.assets[&"sfm.stall.blue.007"] as VillageAssetSpec
	assert_false(market.is_enterable(),
		"a market service front cannot silently become a doorway")
	assert_false(market.requires_foundation())
	assert_false(market.has_enclosed_interior())
	assert_eq(market.asset_for_theme(&"orange"),
		&"sfm.stall.orange.006")
	assert_eq(market.attachments.size(), 1)
	assert_eq(market.attachments[0].asset_id,
		&"sfm.table.fishmonger.001")
	assert_eq(program.market_program.stall_specs.size(), 3)
	assert_eq(program.outskirts_program.shelter_specs.size(), 4)
	assert_eq(program.outskirts_program.target_shelters(&"village"), 1)
	assert_eq(program.outskirts_program.target_shelters(&"town"), 2)
	assert_eq((program.market_program.stall_specs[1] \
		as VillageAssetSpec).asset_id, &"sfm.stall.butcher.001")
	assert_eq((program.market_program.stall_specs[2] \
		as VillageAssetSpec).asset_id, &"sfm.stall.teal.008")
	assert_eq((program.assets[&"sfm.stall.teal.008"] \
		as VillageAssetSpec).asset_for_theme(&"orange"),
		&"sfm.stall.neutral.009")
	assert_eq((program.assets[&"sfm.stall.butcher.001"] \
		as VillageAssetSpec).asset_for_theme(&"orange"),
		&"sfm.stall.butcher.003")
	assert_null(program.spec_for_asset(&"sfm.table.fishmonger.001"),
		"contained components are not misclassified as standalone buildings")
	assert_false((program.assets[&"sft.building.001"] \
		as VillageAssetSpec).allowed_in(&"village"))
	assert_eq(program.slots_for_tier(&"hamlet").size(), 7)
	assert_eq(program.slots_for_tier(&"village").size(), 10)
	assert_eq(program.slots_for_tier(&"town").size(), 15)
	assert_eq(program.streets_for_tier(&"hamlet").size(), 2)
	assert_eq(program.streets_for_tier(&"village").size(), 5)
	assert_eq(program.streets_for_tier(&"town").size(), 6)
	for tier: StringName in VillageProgram.TIERS:
		var street_keys: Dictionary = {}
		for street: VillageStreetSpec in program.streets_for_tier(tier):
			street_keys[street.stable_key] = true
		for slot: VillageSlotSpec in program.slots_for_tier(tier):
			assert_true(street_keys.has(slot.street_key),
				"every lot is constructed from a street frontage")
	assert_eq(program.prop_assets.size(), 4)
	assert_eq(program.prop_slots_for_tier(&"hamlet").size(), 4)
	assert_eq(program.prop_slots_for_tier(&"village").size(), 6)
	assert_eq(program.prop_slots_for_tier(&"town").size(), 8)
	assert_lte(program.max_record_radius, VillageProgram.SETTLEMENT_INSET)

func test_asset_spec_rejects_an_unreviewed_or_unavailable_id() -> void:
	assert_null(VillageProgram.compile({"assets": [{
		"id": &"missing.village.asset",
		"entrance_local": Vector2.ZERO,
		"entrance_outward": Vector2.DOWN,
		"tiers": [&"hamlet"],
	}]}, EnvironmentCatalog.load_default()))
	assert_push_error("missing or lacks the village tag")
