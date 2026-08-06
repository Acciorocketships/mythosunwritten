class_name VillageOutskirtsProgram
extends RefCounted

## Optional low-density edge grammar. The inhabited market/massing transaction
## remains the village's required core; ground-only shelters can then occupy a
## wider annulus and connect back by a short public lane.
const INNER_RADIUS := 36.0
const OUTER_RADIUS := 60.0
const MAX_CONNECTOR_LENGTH := 30.0
const TARGET_SHELTERS := {
	&"village": 1,
	&"town": 2,
}

var shelter_specs: Array[VillageAssetSpec] = []


static func compile(assets: Dictionary) -> VillageOutskirtsProgram:
	var program := VillageOutskirtsProgram.new()
	for value: Variant in assets.values():
		var spec := value as VillageAssetSpec
		if spec == null or spec.role != VillageAssetSpec.Role.SHELTER:
			continue
		if not spec.is_enterable() or spec.is_stackable() \
				or spec.requires_foundation():
			push_error("Village outskirts require enterable ground-only shelters")
			return null
		program.shelter_specs.append(spec)
	program.shelter_specs.sort_custom(func(a: VillageAssetSpec,
			b: VillageAssetSpec) -> bool:
		return String(a.asset_id) < String(b.asset_id))
	if program.shelter_specs.is_empty():
		push_error("Village outskirts require at least one reviewed shelter")
		return null
	return program


func target_shelters(tier: StringName) -> int:
	return int(TARGET_SHELTERS.get(tier, 0))


func spec_for_slot(settlement_id: StringName,
		slot_index: int) -> VillageAssetSpec:
	assert(not shelter_specs.is_empty() and slot_index >= 0)
	var offset := posmod(String(settlement_id).hash(), shelter_specs.size())
	return shelter_specs[(offset + slot_index) % shelter_specs.size()]
