extends RefCounted
## A roof family is selected once for a merged building. Native geometry and
## UVs stay unchanged; only the roof material surfaces differ in these bakes.
const FAMILIES: Array[StringName] = [&"blue", &"wood_red", &"wood_blue", &"sage"]


static func choose(seed_value: int, house_id: StringName) -> StringName:
	var roll := posmod(hash([seed_value, String(house_id), "roof.material.family"]), 10)
	return FAMILIES[0 if roll < 4 else 1 + (roll - 4) / 2]


static func apply(kit: BuildingKit, family: StringName) -> void:
	assert(family in FAMILIES)
	assert(kit.roof_palette == &"blue", "Apply one family to a fresh native kit")
	kit.roof_palette = family
	if family == &"blue":
		return
	for role: StringName in kit.roles:
		var replacements: Array[StringName] = []
		for id: StringName in kit.roles[role]:
			if not String(id).begins_with("pure_village.roof."):
				replacements.append(id)
				continue
			var variant := StringName("%s.%s" % [id, family])
			replacements.append(variant)
			if kit.roof_cap_x_bounds.has(id):
				kit.roof_cap_x_bounds[variant] = kit.roof_cap_x_bounds[id]
			if kit.asset_anchors.has(id):
				kit.asset_anchors[variant] = kit.asset_anchors[id]
		kit.roles[role] = replacements


static func asset_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for family: StringName in FAMILIES:
		if family == &"blue":
			continue
		var kit := (
			preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
			. roof_study()
		)
		apply(kit, family)
		for id: StringName in kit.all_asset_ids():
			if String(id).begins_with("pure_village.roof."):
				result.append(id)
	return result
