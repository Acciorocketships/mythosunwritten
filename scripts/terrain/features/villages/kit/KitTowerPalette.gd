extends RefCounted
## A cap inherits the adjoining roof's material family, not its asset pack.
## Variant bakes change only RoofTiles; timber undersides keep their own trim.


static func apply(candidate: Dictionary) -> void:
	for part: Dictionary in candidate.parts:
		part.asset_id = StringName(String(part.asset_id).get_slice(".finish_", 0))
	_apply_roof(candidate)
	var kit: BuildingKit = candidate.kit
	if kit.frame_palette != &"native":
		for part: Dictionary in candidate.parts:
			# This native support contains stone only; no timber finish variant.
			if part.asset_id == &"pure_village.roof_turret.support": continue
			part.asset_id = preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd").variant_id(part.asset_id, kit.frame_palette)

static func _apply_roof(candidate: Dictionary) -> void:
	var host: BuildingMass = candidate.host
	var kit: BuildingKit = candidate.kit
	var indices: Array = candidate.host_plan.wings.keys()
	indices.sort()
	if indices.is_empty():
		return
	var roof: Dictionary = host.roofs[indices[0]]
	var colour := String(roof.get("colour", "blue"))
	var role := StringName("roof.%s.eave" % colour)
	if not kit.has_role(role):
		return
	if String(kit.asset(role)).begins_with("pure_village."):
		if kit.roof_palette != &"blue":
			for part: Dictionary in candidate.parts:
				if part.role == &"tower.roof":
					var base := String(part.asset_id).get_slice(".wood_", 0).trim_suffix(".sage")
					part.asset_id = StringName("%s.%s" % [base, kit.roof_palette])
		return
	if not String(kit.asset(role)).begins_with("suntail."):
		return
	for part: Dictionary in candidate.parts:
		if part.role == &"tower.roof":
			part.asset_id = StringName(String(part.asset_id).get_slice(".wood_", 0) + ".wood_" + colour)
