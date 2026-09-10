extends SceneTree

func _init() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/environment_bake/manifests/fantasy_village_fabric.json"))
	var stock := {}
	for entry: Dictionary in source.assets: stock[StringName(entry.id)] = entry
	var unique := {}
	for pool: Array[StringName] in [SettlementFabricProgram.WOOD_CELL_FACADE_BLUE,
			SettlementFabricProgram.WOOD_CELL_FACADE_ORANGE,SettlementFabricProgram.WOOD_CELL_FACADE_AMBER]:
		for asset: StringName in pool: unique[asset] = true
	var assets: Array = []
	var ids := unique.keys()
	ids.sort()
	for asset: StringName in ids:
		for mask in [1,2]:
			var entry: Dictionary = stock[asset].duplicate(true)
			entry.id = "%s.outcrop_end%d" % [asset,mask]
			entry["facade_end_owner_mask"] = mask
			assets.append(entry)
	var manifest := {"pack":"fantasy_village_outcrop_interfaces","license":source.license,
		"default_scale":source.default_scale,"assets":assets,
		"generated_by":"res://tools/environment_bake/export_outcrop_interface_manifest.gd"}
	FileAccess.open("res://tools/environment_bake/manifests/fantasy_village_outcrop_interfaces.json",FileAccess.WRITE).store_string(JSON.stringify(manifest," ")+"\n")
	print("Outcrop end ownership variants: ",assets.size())
	quit()
